from __future__ import annotations

import httpx

DAILYMED_BASE_URL = "https://dailymed.nlm.nih.gov/dailymed/services/v2"


async def get_spl_by_rxcui(rxcui: str) -> dict | None:
    params = {"rxcui": rxcui, "pagesize": 1, "page": 1}
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.get(f"{DAILYMED_BASE_URL}/spls.json", params=params)
        response.raise_for_status()
        data = response.json()

    items = data.get("data", [])
    return items[0] if items else None
