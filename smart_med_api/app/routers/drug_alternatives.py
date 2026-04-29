from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query

from app.models.drug_models import DrugAlternativeItem, DrugAlternativesResponse
from app.services.dailymed_service import get_spl_by_rxcui
from app.services.openfda_service import extract_label_sections, get_label_by_generic_or_brand_name
from app.services.rxnorm_service import get_related_concepts_by_type, resolve_drug_name

router = APIRouter(tags=["drug-alternatives"])

RELATED_TERM_TYPES = ["SCD", "SBD", "GPCK", "BPCK", "BN"]

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


def _collect_alternatives(
    related: dict[str, list[dict[str, str]]],
    query: str,
    matched_name: str | None,
    limit: int = 16,
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


@router.get("/drug-alternatives", response_model=DrugAlternativesResponse)
async def get_drug_alternatives(
    name: str = Query(..., min_length=2, description="Medicine name typed by the user"),
) -> Any:
    query = name.strip()
    if not query:
        raise HTTPException(status_code=400, detail="Drug name is required")

    rxcui, matched_name = await resolve_drug_name(query)
    if rxcui is None:
        raise HTTPException(status_code=404, detail="Drug not found in RxNorm")

    spl = await get_spl_by_rxcui(rxcui)
    set_id = spl.get("setid") if isinstance(spl, dict) else None

    lookup_name = matched_name or query
    label_record = await get_label_by_generic_or_brand_name(lookup_name)

    if label_record is None and matched_name and matched_name.lower() != query.lower():
        label_record = await get_label_by_generic_or_brand_name(query)

    sections = extract_label_sections(label_record or {})
    generic_name = sections["generic_name"][0] if sections["generic_name"] else None
    active_ingredients = (
        sections["active_ingredients"]
        or ([generic_name] if generic_name else ([matched_name] if matched_name else []))
    )

    related = await get_related_concepts_by_type(rxcui, RELATED_TERM_TYPES)
    alternatives = _collect_alternatives(related, query, matched_name)

    notes = [
        "Alternatives are related RxNorm medicines, usually products or brands that share the resolved ingredient or drug concept.",
        "Ask a clinician or pharmacist before switching, because dose, form, allergies, pregnancy status, and release type can change safety.",
    ]

    if not alternatives:
        notes.insert(
            0,
            "No related alternative products were found in the public RxNorm data checked.",
        )

    return DrugAlternativesResponse(
        query=query,
        matched_name=matched_name,
        generic_name=generic_name,
        active_ingredients=active_ingredients,
        alternatives=alternatives,
        notes=notes,
        rxcui=rxcui,
        set_id=set_id,
    )
