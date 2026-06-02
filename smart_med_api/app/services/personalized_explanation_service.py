from __future__ import annotations

import asyncio
import itertools
import json
import logging
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from openai import APIConnectionError, APIError, APIStatusError, APITimeoutError

from app.core.config import get_settings
from app.core.xai_client import get_xai_client, response_output_text
from app.models.personalized_explanation_models import (
    DraftMedicationInput,
    EvidenceItem,
    ExplanationAlertItem,
    ExplanationMedicationItem,
    PersonalizedExplanationRequest,
    PersonalizedExplanationResponse,
)
from app.services.firebase_admin_service import VerifiedFirebaseUser, get_firestore_client
from app.services.medication_safety_rules import (
    build_medication_badges,
    build_overall_severity,
    build_profile_completeness,
    build_quick_summary,
    build_safer_behavior_tips,
)

PROMPT_VERSION = "grounded-firestore-v2"
logger = logging.getLogger(__name__)


@dataclass
class MedicationContext:
    medication_id: str
    medication: dict[str, Any]
    drug_id: str | None
    drug: dict[str, Any] | None
    source_ids: list[str] = field(default_factory=list)


@dataclass
class GroundedFacts:
    quick_summary: str
    overall_severity: str
    caution_count: int
    interaction_count: int
    safer_behavior_tips: list[str]
    medication_badges: list[Any]
    profile_completeness: Any
    overview: str
    medication_explanations: list[ExplanationMedicationItem]
    interaction_alerts: list[ExplanationAlertItem]
    personalized_risks: list[ExplanationAlertItem]
    questions_for_clinician: list[str]
    missing_information: list[str]
    evidence: list[EvidenceItem]
    model_payload: dict[str, Any]


def _model_dump(value: Any) -> dict[str, Any]:
    if hasattr(value, "model_dump"):
        return value.model_dump()

    if hasattr(value, "dict"):
        return value.dict()

    raise TypeError(f"Unsupported model dump value: {type(value)!r}")


def _normalize_text(value: Any) -> str:
    return " ".join(str(value or "").lower().replace("-", " ").replace("/", " ").split())


def _clean_text(value: Any) -> str | None:
    if value is None:
        return None

    text = str(value).strip()
    return text or None


def _string_list(value: Any) -> list[str]:
    if value is None:
        return []

    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]

    if isinstance(value, tuple):
        return [str(item).strip() for item in value if str(item).strip()]

    text = str(value).strip()
    return [text] if text else []


def _unique_strings(values: list[str]) -> list[str]:
    results: list[str] = []
    seen: set[str] = set()

    for value in values:
        cleaned = value.strip()
        if not cleaned:
            continue

        key = cleaned.lower()
        if key in seen:
            continue

        seen.add(key)
        results.append(cleaned)

    return results


def _detail_from_parts(parts: list[str | None]) -> str:
    cleaned = [part.strip() for part in parts if part and part.strip()]
    return " ".join(cleaned)


def _profile_boolean(profile: dict[str, Any], field_name: str) -> bool:
    medical_info = profile.get("medicalInfo")
    if isinstance(medical_info, dict) and medical_info.get(field_name) is not None:
        return bool(medical_info.get(field_name))

    return bool(profile.get(field_name))


def _term_overlaps(term: str, candidates: set[str]) -> bool:
    for candidate in candidates:
        if term == candidate:
            return True
        if len(term) >= 3 and len(candidate) >= 3:
            if term in candidate or candidate in term:
                return True
    return False


def _profile_summary(profile: dict[str, Any]) -> str:
    medical_info = (
        profile.get("medicalInfo")
        if isinstance(profile.get("medicalInfo"), dict)
        else {}
    )
    age = profile.get("age")
    biological_sex = profile.get("biologicalSex") or medical_info.get("biologicalSex")
    is_pregnant = bool(profile.get("isPregnant") or medical_info.get("isPregnant"))
    is_breastfeeding = bool(
        profile.get("isBreastfeeding") or medical_info.get("isBreastfeeding"),
    )

    parts = [
        f"Age: {age}." if age is not None else None,
        f"Biological sex: {biological_sex}." if biological_sex else None,
        "Pregnant." if is_pregnant else None,
        "Breastfeeding." if is_breastfeeding else None,
    ]
    return _detail_from_parts(parts) or "Profile data loaded from Firestore."


def _medication_terms(medication: dict[str, Any], drug: dict[str, Any] | None) -> set[str]:
    drug_map = drug or {}
    values = [
        medication.get("name"),
        medication.get("genericName"),
        medication.get("brandName"),
        *_string_list(drug_map.get("brandNames")),
        *_string_list(drug_map.get("activeIngredients")),
        drug_map.get("name"),
        drug_map.get("genericName"),
    ]

    terms: set[str] = set()
    for value in values:
        normalized = _normalize_text(value)
        if normalized:
            terms.add(normalized)
    return terms


def _safe_title_case(value: str) -> str:
    return value[:1].upper() + value[1:] if value else value


def _severity_label(value: Any, fallback: str = "Info") -> str:
    cleaned = _clean_text(value)
    if not cleaned:
        return fallback

    normalized = cleaned.lower()
    if normalized == "major":
        normalized = "high"

    return _safe_title_case(normalized)


def _add_unique_evidence(evidence_items: list[EvidenceItem], item: EvidenceItem) -> None:
    if any(existing.id == item.id for existing in evidence_items):
        return
    evidence_items.append(item)


def _alert_signature(alert: ExplanationAlertItem) -> tuple[str, str, str]:
    return (
        alert.severity.lower(),
        alert.title.lower(),
        alert.detail.lower(),
    )


def _add_unique_alert(alerts: list[ExplanationAlertItem], alert: ExplanationAlertItem) -> None:
    signature = _alert_signature(alert)
    if any(_alert_signature(existing) == signature for existing in alerts):
        return
    alerts.append(alert)


def _question_from_alert(alert: ExplanationAlertItem) -> str:
    severity = alert.severity.lower()
    if severity in {"high", "severe", "major"}:
        return f"Should I review this high-risk issue with my clinician: {alert.title}?"

    return f"Do I need guidance about this issue: {alert.title}?"


def _select_medications(
    medications: list[dict[str, Any]],
    medication_ids: list[str],
    include_inactive: bool,
) -> list[dict[str, Any]]:
    selected_ids = {item.strip() for item in medication_ids if item.strip()}
    selected: list[dict[str, Any]] = []

    for medication in medications:
        medication_id = str(medication.get("id") or "").strip()
        status_value = _normalize_text(medication.get("status") or "active")
        is_active = status_value in {"", "active", "current"}

        if selected_ids and medication_id not in selected_ids:
            continue
        if not include_inactive and not is_active:
            continue

        selected.append(medication)

    return selected


def _lookup_drug_by_exact_field(
    *,
    collection: Any,
    field_name: str,
    candidate: str | None,
) -> tuple[str | None, dict[str, Any] | None]:
    if not candidate:
        return None, None

    query = collection.where(field_name, "==", candidate).limit(1).stream()
    for doc in query:
        if not doc.exists:
            continue
        return doc.id, doc.to_dict() or {}

    return None, None


def _resolve_drug_for_medication(
    *,
    drug_catalog_collection: Any,
    medication: dict[str, Any],
) -> tuple[str | None, dict[str, Any] | None]:
    drug_catalog_id = _clean_text(medication.get("drugCatalogId"))
    if drug_catalog_id:
        snapshot = drug_catalog_collection.document(drug_catalog_id).get()
        if snapshot.exists:
            return snapshot.id, snapshot.to_dict() or {}

    for field_name, candidate in (
        ("name", _clean_text(medication.get("name"))),
        ("genericName", _clean_text(medication.get("genericName"))),
        ("name", _clean_text(medication.get("brandName"))),
    ):
        matched_id, matched_doc = _lookup_drug_by_exact_field(
            collection=drug_catalog_collection,
            field_name=field_name,
            candidate=candidate,
        )
        if matched_doc is not None:
            return matched_id, matched_doc

    return None, None


def _draft_medication_to_record(
    *,
    user_id: str,
    draft: DraftMedicationInput,
) -> dict[str, Any]:
    dose_value = None
    if draft.dose_amount is not None:
        amount = draft.dose_amount
        dose_value = (
            f"{int(amount)}"
            if float(amount).is_integer()
            else str(amount)
        )

    dosage = " ".join(
        item
        for item in [dose_value, _clean_text(draft.dose_unit)]
        if item
    )
    frequency = None
    if draft.frequency_per_day is not None and draft.frequency_per_day > 0:
        suffix = "time" if draft.frequency_per_day == 1 else "times"
        frequency = f"{draft.frequency_per_day} {suffix} per day"

    return {
        "id": draft.existing_medication_id or "__preview__",
        "userId": user_id,
        "name": draft.name,
        "genericName": draft.generic_name,
        "brandName": draft.brand_name,
        "doseAmount": draft.dose_amount,
        "doseUnit": draft.dose_unit,
        "dosage": dosage,
        "frequencyPerDay": draft.frequency_per_day,
        "frequency": frequency,
        "reminderTimes": draft.reminder_times,
        "startDate": draft.start_date.isoformat() if draft.start_date else None,
        "instructions": draft.instructions,
        "notes": draft.notes,
        "form": draft.form,
        "status": draft.status or "active",
        "remindersEnabled": draft.reminders_enabled,
    }


def _fetch_user_context(
    *,
    user: VerifiedFirebaseUser,
    request: PersonalizedExplanationRequest,
) -> tuple[dict[str, Any], list[MedicationContext], list[str], list[str], list[dict[str, Any]]]:
    settings = get_settings()
    firestore_client = get_firestore_client()
    user_ref = firestore_client.collection(settings.firestore_users_collection).document(
        user.uid,
    )

    user_snapshot = user_ref.get()
    if not user_snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile was not found in Firestore.",
        )

    profile = user_snapshot.to_dict() or {}
    profile["authUid"] = user.uid

    medication_docs: list[dict[str, Any]] = []
    for doc in user_ref.collection("medications").stream():
        payload = doc.to_dict() or {}
        payload["id"] = doc.id
        medication_docs.append(payload)

    if request.view == "preview":
        if request.draft_medication is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A draft medication is required for preview mode.",
            )

        existing_medication_id = request.draft_medication.existing_medication_id
        if existing_medication_id:
            medication_docs = [
                item
                for item in medication_docs
                if str(item.get("id") or "") != existing_medication_id
            ]

        medication_docs.append(
            _draft_medication_to_record(
                user_id=user.uid,
                draft=request.draft_medication,
            ),
        )

    selected_medications = _select_medications(
        medications=medication_docs,
        medication_ids=request.medication_ids,
        include_inactive=request.include_inactive or request.view == "preview",
    )
    if not selected_medications:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No matching medications were found for this user.",
        )

    allergies = [
        _clean_text((doc.to_dict() or {}).get("name")) or ""
        for doc in user_ref.collection("allergies").stream()
    ]
    conditions = [
        _clean_text((doc.to_dict() or {}).get("name")) or ""
        for doc in user_ref.collection("medical_conditions").stream()
    ]

    allergies = _unique_strings(allergies + _string_list(profile.get("allergyNames")))
    conditions = _unique_strings(
        conditions + _string_list(profile.get("medicalConditionNames")),
    )

    drug_catalog_collection = firestore_client.collection(
        settings.firestore_drug_catalog_collection,
    )
    medication_contexts: list[MedicationContext] = []

    for medication in selected_medications:
        drug_id, drug = _resolve_drug_for_medication(
            drug_catalog_collection=drug_catalog_collection,
            medication=medication,
        )
        medication_contexts.append(
            MedicationContext(
                medication_id=str(medication["id"]),
                medication=medication,
                drug_id=drug_id,
                drug=drug,
            ),
        )

    interaction_docs: list[dict[str, Any]] = []
    interactions_collection = firestore_client.collection(
        settings.firestore_drug_interactions_collection,
    )

    seen_pairs: set[str] = set()
    for first, second in itertools.combinations(medication_contexts, 2):
        if not first.drug_id or not second.drug_id:
            continue

        pair_key = "__".join(sorted([first.drug_id, second.drug_id]))
        if pair_key in seen_pairs:
            continue

        seen_pairs.add(pair_key)
        snapshot = interactions_collection.document(pair_key).get()
        if not snapshot.exists:
            continue

        payload = snapshot.to_dict() or {}
        payload["id"] = snapshot.id
        payload["linkedMedicationIds"] = [first.medication_id, second.medication_id]
        payload["linkedMedicationNames"] = [
            _clean_text(first.medication.get("name")) or first.medication_id,
            _clean_text(second.medication.get("name")) or second.medication_id,
        ]
        interaction_docs.append(payload)

    return profile, medication_contexts, allergies, conditions, interaction_docs


def _build_medication_detail(medication: dict[str, Any], drug: dict[str, Any] | None) -> str:
    dose = _clean_text(medication.get("dosage"))
    frequency = _clean_text(medication.get("frequency"))
    generic_name = _clean_text(
        medication.get("genericName") or (drug or {}).get("genericName"),
    )
    description = _clean_text((drug or {}).get("description"))
    active_ingredients = _string_list((drug or {}).get("activeIngredients"))

    parts = [
        f"Saved dose: {dose}." if dose else None,
        f"Saved frequency: {frequency}." if frequency else None,
        f"Generic name: {generic_name}." if generic_name else None,
        (
            f"Active ingredients: {', '.join(active_ingredients)}."
            if active_ingredients
            else None
        ),
        f"Catalog description: {description}" if description else None,
    ]
    return _detail_from_parts(parts) or "Medication data loaded from Firestore."


def _build_default_medication_explanation(
    medication: dict[str, Any],
    drug: dict[str, Any] | None,
) -> str:
    name = _clean_text(medication.get("name")) or "This medication"
    generic_name = _clean_text(
        medication.get("genericName") or (drug or {}).get("genericName"),
    )
    dose = _clean_text(medication.get("dosage"))
    frequency = _clean_text(medication.get("frequency"))
    description = _clean_text((drug or {}).get("description"))
    ingredients = _string_list((drug or {}).get("activeIngredients"))

    parts = [f"{name} is saved in your medication list."]
    if generic_name:
        parts.append(f"It is linked to the generic name {generic_name}.")
    if dose or frequency:
        schedule_parts = []
        if dose:
            schedule_parts.append(f"dose {dose}")
        if frequency:
            schedule_parts.append(f"frequency {frequency}")
        parts.append(f"Your saved schedule shows {' and '.join(schedule_parts)}.")
    if ingredients:
        parts.append(
            "Firestore drug data lists active ingredients: "
            f"{', '.join(ingredients)}."
        )
    if description:
        parts.append(f"Catalog description: {description}")
    if len(parts) == 1:
        parts.append("There is limited catalog detail available for this medication.")
    return " ".join(parts)


def _build_grounded_facts(
    *,
    request: PersonalizedExplanationRequest,
    profile: dict[str, Any],
    medication_contexts: list[MedicationContext],
    allergies: list[str],
    conditions: list[str],
    interaction_docs: list[dict[str, Any]],
) -> GroundedFacts:
    evidence: list[EvidenceItem] = []
    interaction_alerts: list[ExplanationAlertItem] = []
    personalized_risks: list[ExplanationAlertItem] = []
    missing_information: list[str] = []
    questions_for_clinician: list[str] = []
    medication_explanations: list[ExplanationMedicationItem] = []

    profile_evidence = EvidenceItem(
        id="profile",
        source_type="profile",
        title="User profile",
        detail=_profile_summary(profile),
    )
    _add_unique_evidence(evidence, profile_evidence)

    allergy_terms = {_normalize_text(item) for item in allergies if _normalize_text(item)}
    condition_terms = {
        _normalize_text(item) for item in conditions if _normalize_text(item)
    }

    pregnancy_flag = _profile_boolean(profile, "isPregnant")
    breastfeeding_flag = _profile_boolean(profile, "isBreastfeeding")

    grouped_keys: dict[str, list[str]] = defaultdict(list)
    model_medications: list[dict[str, Any]] = []
    medication_summaries: list[dict[str, str]] = []

    for context in medication_contexts:
        medication = context.medication
        drug = context.drug
        medication_name = _clean_text(medication.get("name")) or "Unknown medication"
        generic_name = _clean_text(
            medication.get("genericName") or (drug or {}).get("genericName"),
        )

        medication_evidence_id = f"medication:{context.medication_id}"
        medication_detail = _build_medication_detail(medication, drug)
        _add_unique_evidence(
            evidence,
            EvidenceItem(
                id=medication_evidence_id,
                source_type="medication",
                title=f"Medication: {medication_name}",
                detail=medication_detail,
            ),
        )
        context.source_ids.append(medication_evidence_id)

        if context.drug_id and drug:
            drug_evidence_id = f"drug:{context.drug_id}"
            _add_unique_evidence(
                evidence,
                EvidenceItem(
                    id=drug_evidence_id,
                    source_type="drug_catalog",
                    title=f"Drug catalog: {drug.get('name') or medication_name}",
                    detail=_build_medication_detail(medication, drug),
                ),
            )
            context.source_ids.append(drug_evidence_id)
        else:
            missing_information.append(
                f"No Firestore drug catalog entry is linked to {medication_name}.",
            )

        duplicate_key = context.drug_id or _normalize_text(generic_name or medication_name)
        if duplicate_key:
            grouped_keys[duplicate_key].append(medication_name)

        terms = _medication_terms(medication, drug)
        matched_allergies = sorted(
            allergy
            for allergy in allergy_terms
            if allergy and _term_overlaps(allergy, terms)
        )
        if matched_allergies:
            alert = ExplanationAlertItem(
                severity="High",
                title=f"Recorded allergy overlap for {medication_name}",
                detail=(
                    "Your Firestore allergy list overlaps with this medication: "
                    f"{', '.join(matched_allergies)}."
                ),
                source_ids=["profile", *context.source_ids],
            )
            _add_unique_alert(personalized_risks, alert)

        contraindicated_conditions = {
            _normalize_text(item)
            for item in _string_list((drug or {}).get("contraindicatedConditions"))
        }
        condition_warnings = {
            _normalize_text(item)
            for item in _string_list((drug or {}).get("conditionWarnings"))
        }
        matched_conditions = sorted(
            item
            for item in condition_terms
            if item in contraindicated_conditions or item in condition_warnings
        )
        if matched_conditions:
            alert = ExplanationAlertItem(
                severity="Moderate",
                title=f"Condition-specific caution for {medication_name}",
                detail=(
                    "Firestore drug data includes condition warnings that overlap with "
                    f"your profile: {', '.join(matched_conditions)}."
                ),
                source_ids=["profile", *context.source_ids],
            )
            _add_unique_alert(personalized_risks, alert)

        if pregnancy_flag:
            pregnancy_warnings = _string_list((drug or {}).get("pregnancyWarnings"))
            if pregnancy_warnings:
                alert = ExplanationAlertItem(
                    severity="Moderate",
                    title=f"Pregnancy caution for {medication_name}",
                    detail=(
                        "Firestore drug data includes pregnancy-related warnings for this "
                        "medication."
                    ),
                    source_ids=["profile", *context.source_ids],
                )
                _add_unique_alert(personalized_risks, alert)

        if breastfeeding_flag:
            breastfeeding_warnings = _string_list(
                (drug or {}).get("breastfeedingWarnings"),
            )
            if breastfeeding_warnings:
                alert = ExplanationAlertItem(
                    severity="Moderate",
                    title=f"Breastfeeding caution for {medication_name}",
                    detail=(
                        "Firestore drug data includes breastfeeding-related warnings for "
                        "this medication."
                    ),
                    source_ids=["profile", *context.source_ids],
                )
                _add_unique_alert(personalized_risks, alert)

        medication_explanations.append(
            ExplanationMedicationItem(
                medication_id=context.medication_id,
                name=medication_name,
                generic_name=generic_name,
                explanation=_build_default_medication_explanation(medication, drug),
                source_ids=_unique_strings(context.source_ids),
            ),
        )

        medication_summaries.append(
            {
                "medication_id": context.medication_id,
                "name": medication_name,
            },
        )

        model_medications.append(
            {
                "medication_id": context.medication_id,
                "name": medication_name,
                "generic_name": generic_name,
                "dose": _clean_text(medication.get("dosage")),
                "frequency": _clean_text(medication.get("frequency")),
                "facts": _unique_strings(
                    [
                        medication_detail,
                        *[
                            f"Instruction: {item}"
                            for item in _string_list(medication.get("instructions"))
                        ],
                        *[
                            f"Note: {item}"
                            for item in _string_list(medication.get("notes"))
                        ],
                    ],
                ),
                "source_ids": _unique_strings(context.source_ids),
            },
        )

    for _, names in grouped_keys.items():
        if len(names) < 2:
            continue

        alert = ExplanationAlertItem(
            severity="High",
            title="Possible duplicate therapy",
            detail=(
                "Multiple saved medications may refer to the same or equivalent drug: "
                f"{', '.join(sorted(names))}."
            ),
            source_ids=[
                item.id
                for item in evidence
                if item.id.startswith("medication:")
                and any(name in item.title for name in names)
            ],
        )
        _add_unique_alert(interaction_alerts, alert)

    for interaction in interaction_docs:
        pair_names = _string_list(interaction.get("drugNames"))
        pair_ids = _string_list(interaction.get("drugIds"))
        pair_label = (
            " + ".join(pair_names)
            if pair_names
            else " + ".join(pair_ids)
            if pair_ids
            else interaction.get("id") or "interaction"
        )
        evidence_id = f"interaction:{interaction.get('id') or pair_label}"
        linked_medication_ids = _string_list(interaction.get("linkedMedicationIds"))
        linked_sources = [f"medication:{item}" for item in linked_medication_ids if item]
        detail = _detail_from_parts(
            [
                _clean_text(interaction.get("summary")),
                (
                    f"Warnings: {', '.join(_string_list(interaction.get('warnings')))}."
                    if _string_list(interaction.get("warnings"))
                    else None
                ),
                (
                    "Recommendations: "
                    f"{', '.join(_string_list(interaction.get('recommendations')))}."
                    if _string_list(interaction.get("recommendations"))
                    else None
                ),
            ],
        ) or "Firestore interaction data loaded."

        _add_unique_evidence(
            evidence,
            EvidenceItem(
                id=evidence_id,
                source_type="interaction",
                title=f"Drug interaction: {pair_label}",
                detail=detail,
            ),
        )
        _add_unique_alert(
            interaction_alerts,
            ExplanationAlertItem(
                severity=_severity_label(interaction.get("severity"), fallback="Moderate"),
                title=_clean_text(interaction.get("title"))
                or f"Interaction between {pair_label}",
                detail=detail,
                source_ids=_unique_strings([evidence_id, *linked_sources]),
            ),
        )

    profile_completeness = build_profile_completeness(
        profile=profile,
        allergies=allergies,
        conditions=conditions,
    )
    if profile_completeness.missing_fields:
        missing_information.append(profile_completeness.summary)

    for alert in [*interaction_alerts, *personalized_risks]:
        question = _question_from_alert(alert)
        if question not in questions_for_clinician:
            questions_for_clinician.append(question)

    for item in _unique_strings(missing_information):
        question = (
            "Can a clinician or admin complete the missing Firestore drug data for: "
            f"{item.replace('No Firestore drug catalog entry is linked to ', '').rstrip('.')}"
        )
        if question not in questions_for_clinician:
            questions_for_clinician.append(question)

    overview_parts = [
        f"Loaded {len(medication_contexts)} medication"
        f"{'' if len(medication_contexts) == 1 else 's'} from Firestore.",
        (
            f"Found {len(interaction_alerts)} interaction alert"
            f"{'' if len(interaction_alerts) == 1 else 's'}."
            if interaction_alerts
            else "No stored interaction alerts were found in Firestore for this selection."
        ),
        (
            f"Found {len(personalized_risks)} profile-specific risk"
            f"{'' if len(personalized_risks) == 1 else 's'}."
            if personalized_risks
            else "No profile-specific risks were matched from the available Firestore facts."
        ),
        (
            f"Missing data: {len(_unique_strings(missing_information))} gap"
            f"{'' if len(_unique_strings(missing_information)) == 1 else 's'}."
            if missing_information
            else "The selected medications all have linked Firestore drug catalog data."
        ),
    ]

    overall_severity = build_overall_severity([*interaction_alerts, *personalized_risks])
    medication_badges = build_medication_badges(
        medications=medication_summaries,
        interaction_alerts=interaction_alerts,
        personalized_risks=personalized_risks,
        profile_completeness=profile_completeness,
    )
    safer_behavior_tips = build_safer_behavior_tips(
        interaction_docs=interaction_docs,
        interaction_alerts=interaction_alerts,
        personalized_risks=personalized_risks,
        profile_completeness=profile_completeness,
    )
    quick_summary = build_quick_summary(
        medication_count=len(medication_contexts),
        interaction_count=len(interaction_alerts),
        caution_count=len(personalized_risks),
        overall_severity=overall_severity,
        profile_completeness=profile_completeness,
        is_preview=request.view == "preview",
    )

    model_payload = {
        "view": request.view,
        "simple_language": request.simple_language,
        "patient_context": {
            "age": profile.get("age"),
            "biological_sex": _clean_text(
                profile.get("biologicalSex")
                or (profile.get("medicalInfo") or {}).get("biologicalSex")
                if isinstance(profile.get("medicalInfo"), dict)
                else None,
            ),
            "is_pregnant": pregnancy_flag,
            "is_breastfeeding": breastfeeding_flag,
            "conditions": conditions,
            "drug_allergies": allergies,
        },
        "summary": {
            "quick_summary": quick_summary,
            "overall_severity": overall_severity,
            "interaction_count": len(interaction_alerts),
            "caution_count": len(personalized_risks),
            "profile_completeness": _model_dump(profile_completeness),
            "safer_behavior_tips": safer_behavior_tips,
            "medication_badges": [_model_dump(item) for item in medication_badges],
        },
        "medications": model_medications,
        "interaction_alerts": [_model_dump(item) for item in interaction_alerts],
        "personalized_risks": [_model_dump(item) for item in personalized_risks],
        "missing_information": _unique_strings(missing_information),
    }

    return GroundedFacts(
        quick_summary=quick_summary,
        overall_severity=overall_severity,
        caution_count=len(personalized_risks),
        interaction_count=len(interaction_alerts),
        safer_behavior_tips=safer_behavior_tips,
        medication_badges=medication_badges,
        profile_completeness=profile_completeness,
        overview=" ".join(overview_parts),
        medication_explanations=medication_explanations,
        interaction_alerts=interaction_alerts,
        personalized_risks=personalized_risks,
        questions_for_clinician=questions_for_clinician,
        missing_information=_unique_strings(missing_information),
        evidence=evidence,
        model_payload=model_payload,
    )


def _explanation_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "quick_summary": {"type": "string"},
            "overview": {"type": "string"},
            "safer_behavior_tips": {
                "type": "array",
                "items": {"type": "string"},
            },
            "medication_explanations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "medication_id": {"type": "string"},
                        "name": {"type": "string"},
                        "generic_name": {"type": ["string", "null"]},
                        "explanation": {"type": "string"},
                        "source_ids": {
                            "type": "array",
                            "items": {"type": "string"},
                        },
                    },
                    "required": [
                        "medication_id",
                        "name",
                        "generic_name",
                        "explanation",
                        "source_ids",
                    ],
                    "additionalProperties": False,
                },
            },
            "questions_for_clinician": {
                "type": "array",
                "items": {"type": "string"},
            },
        },
        "required": [
            "quick_summary",
            "overview",
            "safer_behavior_tips",
            "medication_explanations",
            "questions_for_clinician",
        ],
        "additionalProperties": False,
    }


def _fallback_response(grounded: GroundedFacts) -> PersonalizedExplanationResponse:
    return PersonalizedExplanationResponse(
        generated_at=datetime.now(timezone.utc),
        source="firestore+rules",
        model=None,
        prompt_version=PROMPT_VERSION,
        grounded_only=True,
        quick_summary=grounded.quick_summary,
        overall_severity=grounded.overall_severity,
        caution_count=grounded.caution_count,
        interaction_count=grounded.interaction_count,
        safer_behavior_tips=grounded.safer_behavior_tips,
        medication_badges=grounded.medication_badges,
        profile_completeness=grounded.profile_completeness,
        overview=grounded.overview,
        medication_explanations=grounded.medication_explanations,
        interaction_alerts=grounded.interaction_alerts,
        personalized_risks=grounded.personalized_risks,
        questions_for_clinician=grounded.questions_for_clinician,
        missing_information=grounded.missing_information,
        evidence=grounded.evidence,
    )


def _merge_medication_explanations(
    original_items: list[ExplanationMedicationItem],
    generated_items: list[dict[str, Any]],
) -> list[ExplanationMedicationItem]:
    generated_by_id = {
        str(item.get("medication_id")): item
        for item in generated_items
        if item.get("medication_id")
    }
    merged: list[ExplanationMedicationItem] = []

    for item in original_items:
        generated = generated_by_id.get(item.medication_id)
        if generated is None:
            merged.append(item)
            continue

        explanation = _clean_text(generated.get("explanation")) or item.explanation
        merged.append(
            ExplanationMedicationItem(
                medication_id=item.medication_id,
                name=_clean_text(generated.get("name")) or item.name,
                generic_name=generated.get("generic_name")
                if generated.get("generic_name") is None
                else _clean_text(generated.get("generic_name")) or item.generic_name,
                explanation=explanation,
                source_ids=_unique_strings(
                    _string_list(generated.get("source_ids")) or item.source_ids,
                ),
            ),
        )

    return merged


async def _generate_with_xai(
    *,
    request: PersonalizedExplanationRequest,
    grounded: GroundedFacts,
) -> PersonalizedExplanationResponse:
    settings = get_settings()

    brevity_instruction = (
        "Use very simple language and short sentences."
        if request.simple_language
        else "Use clear patient-friendly language."
    )
    view_instruction = {
        "brief": "Focus on the quick summary and safer behavior tips. Keep it compact.",
        "preview": "Frame the answer as a safety preview for a medication that has not been saved yet.",
        "detail": "Provide a concise overview plus short explanations for each medication.",
    }[request.view]

    system_prompt = (
        "You write patient-friendly medication explanations for Smart Med. "
        "Use only the Firestore facts provided in the user payload. "
        "Do not invent interactions, side effects, diagnoses, instructions, or missing "
        "drug facts. If something is unknown, say it is unknown. "
        "Do not tell the user to start, stop, or change medication. "
        f"{brevity_instruction} {view_instruction}"
    )

    try:
        client = get_xai_client()
    except HTTPException as exc:
        logger.warning(
            "Falling back to grounded personalized explanation because the xAI "
            "client is unavailable: %s",
            exc.detail,
        )
        return _fallback_response(grounded)

    try:
        response = await asyncio.to_thread(
            client.responses.create,
            model=settings.xai_model,
            input=[
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": json.dumps(grounded.model_payload, ensure_ascii=False),
                },
            ],
            text={
                "format": {
                    "type": "json_schema",
                    "name": "smart_med_grounded_explanation",
                    "schema": _explanation_schema(),
                    "strict": True,
                },
            },
            store=False,
        )
    except (APIConnectionError, APITimeoutError, APIStatusError, APIError) as exc:
        logger.warning(
            "Falling back to grounded personalized explanation because the xAI "
            "request failed.",
            exc_info=exc,
        )
        return _fallback_response(grounded)

    try:
        output_text = response_output_text(response)
        if not output_text:
            logger.warning(
                "Falling back to grounded personalized explanation because the xAI "
                "response did not include output text.",
            )
            return _fallback_response(grounded)

        parsed = json.loads(output_text)
    except (ValueError, TypeError, json.JSONDecodeError):
        logger.warning(
            "Falling back to grounded personalized explanation because the xAI "
            "response could not be parsed as JSON.",
        )
        return _fallback_response(grounded)

    overview = _clean_text(parsed.get("overview")) or grounded.overview
    quick_summary = _clean_text(parsed.get("quick_summary")) or grounded.quick_summary
    safer_behavior_tips = _unique_strings(
        _string_list(parsed.get("safer_behavior_tips")) or grounded.safer_behavior_tips,
    )
    medication_explanations = _merge_medication_explanations(
        grounded.medication_explanations,
        parsed.get("medication_explanations", []),
    )
    generated_questions = _unique_strings(
        _string_list(parsed.get("questions_for_clinician")),
    )
    questions_for_clinician = _unique_strings(
        generated_questions + grounded.questions_for_clinician,
    )

    return PersonalizedExplanationResponse(
        generated_at=datetime.now(timezone.utc),
        source="firestore+xai",
        model=settings.xai_model,
        prompt_version=PROMPT_VERSION,
        grounded_only=False,
        quick_summary=quick_summary,
        overall_severity=grounded.overall_severity,
        caution_count=grounded.caution_count,
        interaction_count=grounded.interaction_count,
        safer_behavior_tips=safer_behavior_tips,
        medication_badges=grounded.medication_badges,
        profile_completeness=grounded.profile_completeness,
        overview=overview,
        medication_explanations=medication_explanations,
        interaction_alerts=grounded.interaction_alerts,
        personalized_risks=grounded.personalized_risks,
        questions_for_clinician=questions_for_clinician,
        missing_information=grounded.missing_information,
        evidence=grounded.evidence,
    )


async def generate_personalized_explanation(
    *,
    user: VerifiedFirebaseUser,
    request: PersonalizedExplanationRequest,
) -> PersonalizedExplanationResponse:
    profile, medication_contexts, allergies, conditions, interaction_docs = (
        _fetch_user_context(user=user, request=request)
    )
    grounded = _build_grounded_facts(
        request=request,
        profile=profile,
        medication_contexts=medication_contexts,
        allergies=allergies,
        conditions=conditions,
        interaction_docs=interaction_docs,
    )
    return await _generate_with_xai(request=request, grounded=grounded)
