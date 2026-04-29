from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query

from app.models.drug_models import DrugDetailsResponse
from app.services.dailymed_service import get_spl_by_rxcui
from app.services.openfda_service import extract_label_sections, get_label_by_generic_or_brand_name
from app.services.rxnorm_service import resolve_drug_name

router = APIRouter(tags=["drug-details"])


@router.get("/drug-details", response_model=DrugDetailsResponse)
async def get_drug_details(
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

    return DrugDetailsResponse(
        query=query,
        matched_name=matched_name,
        generic_name=generic_name,
        brand_names=sections["brand_names"],
        active_ingredients=(sections["active_ingredients"] or ([generic_name] if generic_name else ([matched_name] if matched_name else []))),
        uses=sections["uses"],
        warnings=sections["warnings"],
        side_effects=sections["side_effects"],
        dosage_notes=sections["dosage_notes"],
        contraindications=sections["contraindications"],
        rxcui=rxcui,
        set_id=set_id,
    )
