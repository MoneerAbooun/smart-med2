from __future__ import annotations

import httpx

RXNORM_BASE_URL = "https://rxnav.nlm.nih.gov/REST"


def _as_list(value: object) -> list[object]:
    if isinstance(value, list):
        return value
    if value is None:
        return []
    return [value]


async def find_rxcui_by_string(name: str) -> str | None:
    params = {"name": name}
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.get(f"{RXNORM_BASE_URL}/rxcui.json", params=params)
        response.raise_for_status()
        data = response.json()

    ids = data.get("idGroup", {}).get("rxnormId", [])
    return ids[0] if ids else None


async def get_approximate_match(name: str) -> str | None:
    params = {"term": name, "maxEntries": 1}
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.get(f"{RXNORM_BASE_URL}/approximateTerm.json", params=params)
        response.raise_for_status()
        data = response.json()

    candidates = data.get("approximateGroup", {}).get("candidate", [])
    if not candidates:
        return None

    return candidates[0].get("rxcui")


async def get_display_name(rxcui: str) -> str | None:
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.get(f"{RXNORM_BASE_URL}/rxcui/{rxcui}/properties.json")
        response.raise_for_status()
        data = response.json()

    return data.get("properties", {}).get("name")


async def resolve_drug_name(name: str) -> tuple[str | None, str | None]:
    rxcui = await find_rxcui_by_string(name)
    if rxcui is None:
        rxcui = await get_approximate_match(name)

    if rxcui is None:
        return None, None

    display_name = await get_display_name(rxcui)
    return rxcui, display_name


async def get_related_concepts_by_type(
    rxcui: str,
    term_types: list[str],
) -> dict[str, list[dict[str, str]]]:
    params = {"tty": " ".join(term_types)}

    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.get(
            f"{RXNORM_BASE_URL}/rxcui/{rxcui}/related.json",
            params=params,
        )
        response.raise_for_status()
        data = response.json()

    related_group = data.get("relatedGroup", {})
    concept_groups = _as_list(related_group.get("conceptGroup"))

    related: dict[str, list[dict[str, str]]] = {}

    for group in concept_groups:
        if not isinstance(group, dict):
            continue

        term_type = str(group.get("tty") or "").strip()
        concepts: list[dict[str, str]] = []

        for concept in _as_list(group.get("conceptProperties")):
            if not isinstance(concept, dict):
                continue

            concepts.append(
                {
                    "rxcui": str(concept.get("rxcui") or "").strip(),
                    "name": str(concept.get("name") or "").strip(),
                    "synonym": str(concept.get("synonym") or "").strip(),
                    "tty": str(concept.get("tty") or term_type).strip(),
                }
            )

        related[term_type] = concepts

    return related
