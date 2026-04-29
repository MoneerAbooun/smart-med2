from __future__ import annotations

import httpx

OPENFDA_BASE_URL = "https://api.fda.gov/drug/label.json"


def _first_list_value(record: dict, key: str) -> list[str]:
    value = record.get(key, [])
    if isinstance(value, list):
        return [_normalize_whitespace(str(item)) for item in value if str(item).strip()]
    return []


def _normalize_whitespace(value: str) -> str:
    return " ".join(value.split())


def _to_text_list(record: dict, *keys: str) -> list[str]:
    items: list[str] = []
    for key in keys:
        items.extend(_first_list_value(record, key))
    return [_normalize_whitespace(item) for item in items if str(item).strip()]


async def get_label_by_generic_or_brand_name(name: str) -> dict | None:
    query = f'openfda.generic_name:"{name}" OR openfda.brand_name:"{name}"'
    params = {"search": query, "limit": 1}

    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.get(OPENFDA_BASE_URL, params=params)
        if response.status_code == 404:
            return None
        response.raise_for_status()
        data = response.json()

    results = data.get("results", [])
    return results[0] if results else None


def extract_label_sections(record: dict) -> dict[str, list[str]]:
    openfda = record.get("openfda", {}) if isinstance(record, dict) else {}

    generic_name = _first_list_value(openfda, "generic_name")
    brand_names = _first_list_value(openfda, "brand_name")
    active_ingredients = (
        _first_list_value(record, "active_ingredient")
        or _first_list_value(openfda, "substance_name")
        or _first_list_value(openfda, "generic_name")
    )
    uses = _first_list_value(record, "indications_and_usage") or _first_list_value(record, "purpose")
    warnings = (
        _first_list_value(record, "warnings")
        or _first_list_value(record, "boxed_warning")
        or _first_list_value(record, "warnings_and_cautions")
    )
    side_effects = _first_list_value(record, "adverse_reactions") or _first_list_value(record, "stop_use")
    dosage_notes = _first_list_value(record, "dosage_and_administration") or _first_list_value(record, "dosage_forms_and_strengths")
    contraindications = _first_list_value(record, "contraindications")
    interactions = _to_text_list(record, "drug_interactions", "drug_interactions_table")
    storage = _to_text_list(record, "storage_and_handling", "how_supplied")
    disclaimer = _to_text_list(
        record,
        "keep_out_of_reach_of_children",
        "ask_doctor",
        "ask_doctor_or_pharmacist",
        "questions",
        "pregnancy_or_breast_feeding",
    )

    return {
        "generic_name": generic_name,
        "brand_names": brand_names,
        "active_ingredients": active_ingredients,
        "uses": uses,
        "warnings": warnings,
        "side_effects": side_effects,
        "dosage_notes": dosage_notes,
        "contraindications": contraindications,
        "interactions": interactions,
        "storage": storage,
        "disclaimer": disclaimer,
    }


def extract_interaction_profile(record: dict) -> dict[str, object]:
    openfda = record.get("openfda", {}) if isinstance(record, dict) else {}

    generic_name = _first_list_value(openfda, "generic_name")
    brand_names = _first_list_value(openfda, "brand_name")
    substance_names = _first_list_value(openfda, "substance_name")
    active_ingredients = (
        _first_list_value(record, "active_ingredient")
        or substance_names
        or generic_name
    )

    drug_interactions = _to_text_list(record, "drug_interactions", "drug_interactions_table")
    contraindications = _to_text_list(record, "contraindications")
    warnings = _to_text_list(record, "warnings", "warnings_and_cautions", "boxed_warning")

    searchable_text = " ".join(drug_interactions + contraindications + warnings).lower()

    return {
        "generic_name": generic_name[0] if generic_name else None,
        "brand_names": brand_names,
        "substance_names": substance_names,
        "active_ingredients": active_ingredients,
        "drug_interactions": drug_interactions,
        "contraindications": contraindications,
        "warnings": warnings,
        "searchable_text": searchable_text,
    }
