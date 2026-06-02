from __future__ import annotations

from typing import Any, Iterable

from app.models.personalized_explanation_models import (
    ExplanationAlertItem,
    MedicationBadgeItem,
    ProfileCompletenessItem,
)

_SEVERITY_RANK = {
    "info": 0,
    "low": 1,
    "moderate": 2,
    "major": 3,
    "high": 3,
    "severe": 3,
}


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


def _unique_strings(values: Iterable[str]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()

    for value in values:
        cleaned = value.strip()
        if not cleaned:
            continue

        lookup_key = cleaned.lower()
        if lookup_key in seen:
            continue

        seen.add(lookup_key)
        result.append(cleaned)

    return result


def severity_rank(value: str | None) -> int:
    return _SEVERITY_RANK.get((value or "").strip().lower(), 0)


def normalize_severity(value: str | None) -> str:
    cleaned = _clean_text(value)
    if not cleaned:
        return "Low"

    normalized = cleaned.lower()
    if normalized == "major":
        return "High"

    return normalized[:1].upper() + normalized[1:]


def build_overall_severity(alerts: Iterable[ExplanationAlertItem]) -> str:
    highest_rank = 1
    highest_label = "Low"

    for alert in alerts:
        alert_rank = severity_rank(alert.severity)
        if alert_rank > highest_rank:
            highest_rank = alert_rank
            highest_label = normalize_severity(alert.severity)

    return highest_label


def build_profile_completeness(
    *,
    profile: dict[str, Any],
    allergies: list[str],
    conditions: list[str],
) -> ProfileCompletenessItem:
    medical_info = profile.get("medicalInfo")
    if not isinstance(medical_info, dict):
        medical_info = {}

    biological_sex = _clean_text(
        profile.get("biologicalSex") or medical_info.get("biologicalSex"),
    )
    missing_fields: list[str] = []

    if profile.get("age") is None:
        missing_fields.append("age")
    if not biological_sex:
        missing_fields.append("biological_sex")
    if not allergies:
        missing_fields.append("allergies")
    if not conditions:
        missing_fields.append("conditions")

    systolic = profile.get("systolicPressure")
    if systolic is None:
        systolic = medical_info.get("systolicPressure")

    diastolic = profile.get("diastolicPressure")
    if diastolic is None:
        diastolic = medical_info.get("diastolicPressure")

    if systolic is None or diastolic is None:
        missing_fields.append("blood_pressure")

    weight = profile.get("weightKg")
    if weight is None:
        weight = medical_info.get("weightKg")
    if weight is None:
        missing_fields.append("weight")

    if biological_sex and biological_sex.lower() == "female":
        has_pregnancy = (
            "isPregnant" in profile
            or "isPregnant" in medical_info
        )
        has_breastfeeding = (
            "isBreastfeeding" in profile
            or "isBreastfeeding" in medical_info
        )
        if not has_pregnancy:
            missing_fields.append("pregnancy_status")
        if not has_breastfeeding:
            missing_fields.append("breastfeeding_status")

    missing_fields = _unique_strings(missing_fields)
    is_complete = not missing_fields

    if is_complete:
        summary = "Profile is complete enough for stronger medication safety checks."
    else:
        summary = (
            "Some AI safety checks are limited because these profile details are "
            f"missing: {', '.join(missing_fields)}."
        )

    return ProfileCompletenessItem(
        is_complete=is_complete,
        missing_fields=missing_fields,
        summary=summary,
    )


def build_quick_summary(
    *,
    medication_count: int,
    interaction_count: int,
    caution_count: int,
    overall_severity: str,
    profile_completeness: ProfileCompletenessItem,
    is_preview: bool,
) -> str:
    if interaction_count == 0 and caution_count == 0:
        prefix = (
            "Safety preview looks clear so far."
            if is_preview
            else "No major stored interaction or profile-based cautions were found."
        )
    else:
        parts: list[str] = []
        if interaction_count:
            noun = "interaction alert" if interaction_count == 1 else "interaction alerts"
            parts.append(f"{interaction_count} {noun}")
        if caution_count:
            noun = "profile-based caution" if caution_count == 1 else "profile-based cautions"
            parts.append(f"{caution_count} {noun}")

        prefix = (
            "Safety preview found "
            if is_preview
            else "You have "
        ) + " and ".join(parts) + "."

    if medication_count == 1 and interaction_count == 0 and caution_count == 0:
        prefix = (
            "This medication has no stored major interaction or profile-based caution."
            if not is_preview
            else prefix
        )

    if profile_completeness.missing_fields:
        return (
            f"{prefix} Overall severity: {overall_severity}. "
            "Some checks are limited because profile details are missing."
        )

    return f"{prefix} Overall severity: {overall_severity}."


def build_medication_badges(
    *,
    medications: list[dict[str, str]],
    interaction_alerts: list[ExplanationAlertItem],
    personalized_risks: list[ExplanationAlertItem],
    profile_completeness: ProfileCompletenessItem,
) -> list[MedicationBadgeItem]:
    interaction_counts: dict[str, int] = {}
    caution_counts: dict[str, int] = {}
    severity_by_medication: dict[str, str] = {}

    def apply_alert(alert: ExplanationAlertItem, target_counts: dict[str, int]) -> None:
        medication_ids = {
            source_id.split(":", 1)[1]
            for source_id in alert.source_ids
            if source_id.startswith("medication:")
        }
        for medication_id in medication_ids:
            target_counts[medication_id] = target_counts.get(medication_id, 0) + 1
            current_severity = severity_by_medication.get(medication_id, "Low")
            if severity_rank(alert.severity) > severity_rank(current_severity):
                severity_by_medication[medication_id] = normalize_severity(alert.severity)

    for alert in interaction_alerts:
        apply_alert(alert, interaction_counts)

    for alert in personalized_risks:
        apply_alert(alert, caution_counts)

    badges: list[MedicationBadgeItem] = []
    for medication in medications:
        medication_id = medication["medication_id"]
        interaction_count = interaction_counts.get(medication_id, 0)
        caution_count = caution_counts.get(medication_id, 0)
        severity = severity_by_medication.get(medication_id, "Low")

        if severity_rank(severity) >= 3:
            label = "High caution"
        elif interaction_count > 0:
            label = "Interaction risk" if interaction_count == 1 else f"{interaction_count} interactions"
        elif caution_count > 0:
            label = "1 caution" if caution_count == 1 else f"{caution_count} cautions"
        elif not profile_completeness.is_complete:
            label = "Needs profile info"
            severity = "Info"
        else:
            label = "Explained"

        badges.append(
            MedicationBadgeItem(
                medication_id=medication_id,
                label=label,
                severity=severity,
            ),
        )

    return badges


def build_safer_behavior_tips(
    *,
    interaction_docs: list[dict[str, Any]],
    interaction_alerts: list[ExplanationAlertItem],
    personalized_risks: list[ExplanationAlertItem],
    profile_completeness: ProfileCompletenessItem,
) -> list[str]:
    tips: list[str] = []

    def add_tip(value: str | None) -> None:
        cleaned = _clean_text(value)
        if cleaned:
            tips.append(cleaned)

    for interaction in interaction_docs:
        for recommendation in _string_list(interaction.get("recommendations")):
            add_tip(recommendation)

    if any(severity_rank(alert.severity) >= 3 for alert in [*interaction_alerts, *personalized_risks]):
        add_tip(
            "Review any high-risk warning with a clinician or pharmacist before making medication changes.",
        )

    if any("allergy overlap" in alert.title.lower() for alert in personalized_risks):
        add_tip(
            "Do not ignore possible allergy overlaps, especially if you notice rash, swelling, or breathing symptoms.",
        )

    if any("duplicate therapy" in alert.title.lower() for alert in interaction_alerts):
        add_tip(
            "Check labels and active ingredients so you do not take two versions of the same medicine.",
        )

    if profile_completeness.missing_fields:
        missing = ", ".join(profile_completeness.missing_fields)
        add_tip(
            f"Complete missing profile details to improve warning quality: {missing}.",
        )

    if not tips:
        add_tip(
            "Keep your medication list current and review new prescription or over-the-counter medicines against it.",
        )

    return _unique_strings(tips)[:5]
