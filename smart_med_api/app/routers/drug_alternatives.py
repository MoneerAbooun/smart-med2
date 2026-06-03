from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query

from app.models.drug_models import DrugAlternativesResponse
from app.services.dailymed_service import get_spl_by_rxcui
from app.services.drug_alternative_filter import RELATED_TERM_TYPES, collect_alternatives
from app.services.openfda_service import extract_label_sections, get_label_by_generic_or_brand_name
from app.services.rxnorm_service import get_related_concepts_by_type, resolve_drug_name

router = APIRouter(tags=["drug-alternatives"])


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
    alternatives = collect_alternatives(
        related,
        query,
        matched_name,
        reference_names=[
            generic_name,
            *sections["brand_names"],
            *active_ingredients,
        ],
        limit=16,
    )

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
