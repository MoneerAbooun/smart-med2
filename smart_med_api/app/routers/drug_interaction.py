from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query

from app.models.interaction_models import DrugInteractionResponse
from app.services.dailymed_service import get_spl_by_rxcui
from app.services.interaction_analysis_service import analyze_interaction, build_aliases
from app.services.openfda_service import extract_interaction_profile, get_label_by_generic_or_brand_name
from app.services.rxnorm_service import resolve_drug_name

router = APIRouter(tags=["drug-interaction"])


def _normalized_text(value: str | None) -> str:
    return (value or "").strip().lower()


def _build_duplicate_therapy_response(
    *,
    first_query: str,
    second_query: str,
    first_display: str,
    second_display: str,
    first_generic_name: str | None,
    second_generic_name: str | None,
    first_rxcui: str | None,
    second_rxcui: str | None,
    first_set_id: str | None,
    second_set_id: str | None,
    evidence: list[str],
) -> DrugInteractionResponse:
    return DrugInteractionResponse(
        first_query=first_query,
        second_query=second_query,
        first_drug=first_display,
        second_drug=second_display,
        first_generic_name=first_generic_name,
        second_generic_name=second_generic_name,
        first_rxcui=first_rxcui,
        second_rxcui=second_rxcui,
        first_set_id=first_set_id,
        second_set_id=second_set_id,
        severity="High",
        summary="These medicines appear to refer to the same or equivalent active medicine. Taking both may duplicate therapy and increase overdose or side-effect risk.",
        mechanism="The two names resolved to the same normalized medicine or to the same generic ingredient in the public drug sources checked.",
        warnings=[
            "Using two names for the same medicine can accidentally double the dose.",
        ],
        recommendations=[
            "Do not combine them unless a clinician clearly confirmed they are meant to be taken together.",
            "Check the active ingredient and total daily dose carefully.",
        ],
        evidence=evidence,
    )


@router.get("/drug-interaction", response_model=DrugInteractionResponse)
async def get_drug_interaction(
    drug1: str = Query(..., min_length=2, description="First medicine name"),
    drug2: str = Query(..., min_length=2, description="Second medicine name"),
) -> Any:
    first_query = drug1.strip()
    second_query = drug2.strip()

    if not first_query or not second_query:
        raise HTTPException(status_code=400, detail="Both medicine names are required")

    if first_query.lower() == second_query.lower():
        raise HTTPException(status_code=400, detail="Please enter two different medicines")

    first_rxcui, first_matched = await resolve_drug_name(first_query)
    second_rxcui, second_matched = await resolve_drug_name(second_query)

    if first_rxcui is None or second_rxcui is None:
        raise HTTPException(status_code=404, detail="One or both medicines could not be resolved in RxNorm")

    first_spl = await get_spl_by_rxcui(first_rxcui)
    second_spl = await get_spl_by_rxcui(second_rxcui)

    first_lookup = first_matched or first_query
    second_lookup = second_matched or second_query

    first_label = await get_label_by_generic_or_brand_name(first_lookup)
    if first_label is None and first_lookup.lower() != first_query.lower():
        first_label = await get_label_by_generic_or_brand_name(first_query)

    second_label = await get_label_by_generic_or_brand_name(second_lookup)
    if second_label is None and second_lookup.lower() != second_query.lower():
        second_label = await get_label_by_generic_or_brand_name(second_query)

    first_profile = extract_interaction_profile(first_label or {})
    second_profile = extract_interaction_profile(second_label or {})

    first_generic_name = first_profile.get("generic_name")
    second_generic_name = second_profile.get("generic_name")

    same_rxcui = first_rxcui == second_rxcui and first_rxcui is not None
    same_generic = (
        _normalized_text(str(first_generic_name) if first_generic_name else None)
        and _normalized_text(str(first_generic_name) if first_generic_name else None)
        == _normalized_text(str(second_generic_name) if second_generic_name else None)
    )

    if same_rxcui or same_generic:
        evidence = []
        if same_rxcui:
            evidence.append(f"Both names resolved to the same RXCUI: {first_rxcui}.")
        if same_generic and first_generic_name:
            evidence.append(f"Both records point to the same generic ingredient: {first_generic_name}.")
        return _build_duplicate_therapy_response(
            first_query=first_query,
            second_query=second_query,
            first_display=first_matched or first_query,
            second_display=second_matched or second_query,
            first_generic_name=str(first_generic_name) if first_generic_name else None,
            second_generic_name=str(second_generic_name) if second_generic_name else None,
            first_rxcui=first_rxcui,
            second_rxcui=second_rxcui,
            first_set_id=first_spl.get("setid") if isinstance(first_spl, dict) else None,
            second_set_id=second_spl.get("setid") if isinstance(second_spl, dict) else None,
            evidence=evidence,
        )

    first_aliases = build_aliases(
        first_query,
        first_matched,
        first_generic_name,
        first_profile.get("brand_names"),
        first_profile.get("active_ingredients"),
        first_profile.get("substance_names"),
    )
    second_aliases = build_aliases(
        second_query,
        second_matched,
        second_generic_name,
        second_profile.get("brand_names"),
        second_profile.get("active_ingredients"),
        second_profile.get("substance_names"),
    )

    analysis = analyze_interaction(
        first_display_name=first_matched or first_query,
        second_display_name=second_matched or second_query,
        first_aliases=first_aliases,
        second_aliases=second_aliases,
        first_profile=first_profile,
        second_profile=second_profile,
    )

    return DrugInteractionResponse(
        first_query=first_query,
        second_query=second_query,
        first_drug=first_matched or first_query,
        second_drug=second_matched or second_query,
        first_generic_name=str(first_generic_name) if first_generic_name else None,
        second_generic_name=str(second_generic_name) if second_generic_name else None,
        first_rxcui=first_rxcui,
        second_rxcui=second_rxcui,
        first_set_id=first_spl.get("setid") if isinstance(first_spl, dict) else None,
        second_set_id=second_spl.get("setid") if isinstance(second_spl, dict) else None,
        severity=analysis.severity,
        summary=analysis.summary,
        mechanism=analysis.mechanism,
        warnings=analysis.warnings,
        recommendations=analysis.recommendations,
        evidence=analysis.evidence,
    )
