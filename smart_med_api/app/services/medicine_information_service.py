from __future__ import annotations

from fastapi import HTTPException

from app.ml.drug_name_model import predict_generic_name
from app.models.drug_models import DrugAlternativeItem
from app.models.medicine_models import MedicineInformationResponse
from app.services.dailymed_service import get_spl_by_rxcui
from app.services.openfda_service import extract_label_sections, get_label_by_generic_or_brand_name
from app.services.rxnorm_service import get_related_concepts_by_type, resolve_drug_name

RELATED_TERM_TYPES = ["SCD", "SBD", "GPCK", "BPCK", "BN"]
MIN_PREDICTED_GENERIC_CONFIDENCE = 0.65

CATEGORY_BY_TERM_TYPE = {
    "SCD": "Generic drug",
    "SBD": "Brand drug",
    "GPCK": "Generic pack",
    "BPCK": "Brand pack",
    "BN": "Brand name",
}


def _normalized_text(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.lower().split())


def _preferred_name(concept: dict[str, str]) -> str:
    synonym = concept.get("synonym", "").strip()
    name = concept.get("name", "").strip()
    return synonym or name


def _unique_strings(values: list[str]) -> list[str]:
    seen: set[str] = set()
    results: list[str] = []

    for value in values:
        cleaned = " ".join(str(value).split()).strip()
        if not cleaned:
            continue

        key = cleaned.lower()
        if key in seen:
            continue

        seen.add(key)
        results.append(cleaned)

    return results


def _collect_alternatives(
    related: dict[str, list[dict[str, str]]],
    query: str,
    matched_name: str | None,
    limit: int = 12,
) -> list[DrugAlternativeItem]:
    alternatives: list[DrugAlternativeItem] = []
    seen: set[str] = {_normalized_text(query), _normalized_text(matched_name)}

    for term_type in RELATED_TERM_TYPES:
        for concept in related.get(term_type, []):
            name = _preferred_name(concept)
            key = _normalized_text(name)

            if not name or not key or key in seen:
                continue

            seen.add(key)
            alternatives.append(
                DrugAlternativeItem(
                    name=name,
                    rxcui=concept.get("rxcui") or None,
                    term_type=concept.get("tty") or term_type,
                    category=CATEGORY_BY_TERM_TYPE.get(term_type, "Alternative"),
                )
            )

            if len(alternatives) >= limit:
                return alternatives

    return alternatives


def _build_warning_items(sections: dict[str, list[str]]) -> list[str]:
    contraindications = [
        f"Contraindication: {item}"
        for item in sections.get("contraindications", [])
    ]
    return _unique_strings(sections.get("warnings", []) + contraindications)


def _build_disclaimer_items(sections: dict[str, list[str]]) -> list[str]:
    items = _unique_strings(sections.get("disclaimer", []))
    items.append(
        "This information comes from public medication references and is not a substitute for advice from a doctor or pharmacist."
    )
    return _unique_strings(items)


def _predicted_generic_query(query: str) -> str | None:
    try:
        prediction = predict_generic_name(query)
    except (FileNotFoundError, ValueError):
        return None

    predicted_generic_name = str(
        prediction.get("predicted_generic_name") or ""
    ).strip()
    if not predicted_generic_name:
        return None

    confidence = prediction.get("confidence")
    if confidence is None or confidence < MIN_PREDICTED_GENERIC_CONFIDENCE:
        return None

    if _normalized_text(predicted_generic_name) == _normalized_text(query):
        return None

    return predicted_generic_name


async def _resolve_label_and_identity(
    query: str,
) -> tuple[str, str | None, dict[str, list[str]], str | None]:
    rxcui, matched_name = await resolve_drug_name(query)
    resolved_query = query

    if rxcui is None:
        predicted_generic_name = _predicted_generic_query(query)
        if predicted_generic_name is not None:
            rxcui, matched_name = await resolve_drug_name(predicted_generic_name)
            if rxcui is not None:
                resolved_query = predicted_generic_name

    if rxcui is None:
        raise HTTPException(status_code=404, detail="Drug not found in RxNorm")

    spl = await get_spl_by_rxcui(rxcui)
    set_id = spl.get("setid") if isinstance(spl, dict) else None

    lookup_name = matched_name or resolved_query
    label_record = await get_label_by_generic_or_brand_name(lookup_name)

    if (
        label_record is None
        and matched_name
        and matched_name.lower() != resolved_query.lower()
    ):
        label_record = await get_label_by_generic_or_brand_name(resolved_query)

    sections = extract_label_sections(label_record or {})
    return rxcui, matched_name, sections, set_id


async def lookup_medicine_information(
    *,
    query: str,
) -> MedicineInformationResponse:
    normalized_query = query.strip()
    if not normalized_query:
        raise HTTPException(status_code=400, detail="Drug name is required")

    rxcui, matched_name, sections, set_id = await _resolve_label_and_identity(normalized_query)
    generic_name = sections["generic_name"][0] if sections["generic_name"] else None
    active_ingredients = (
        sections["active_ingredients"]
        or ([generic_name] if generic_name else ([matched_name] if matched_name else []))
    )
    related = await get_related_concepts_by_type(rxcui, RELATED_TERM_TYPES)
    alternatives = _collect_alternatives(related, normalized_query, matched_name)

    return MedicineInformationResponse(
        query=normalized_query,
        medicine_name=matched_name or normalized_query,
        matched_name=matched_name,
        generic_name=generic_name,
        brand_names=_unique_strings(sections["brand_names"]),
        active_ingredients=_unique_strings(active_ingredients),
        used_for=_unique_strings(sections["uses"]),
        dose=_unique_strings(sections["dosage_notes"]),
        warnings=_build_warning_items(sections),
        side_effects=_unique_strings(sections["side_effects"]),
        interactions=_unique_strings(sections["interactions"]),
        alternatives=alternatives,
        storage=_unique_strings(sections["storage"]),
        disclaimer=_build_disclaimer_items(sections),
        rxcui=rxcui,
        set_id=set_id,
    )
