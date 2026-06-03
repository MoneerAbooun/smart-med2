from fastapi.testclient import TestClient

from app.main import app
from app.routers import drug_alternatives as drug_alternatives_router


def test_drug_alternatives_route_keeps_distinct_brand_records(monkeypatch):
    async def fake_resolve_drug_name(name: str):
        assert name == "warfarin"
        return "11289", "warfarin"

    async def fake_get_spl_by_rxcui(rxcui: str):
        assert rxcui == "11289"
        return {"setid": "set-warfarin"}

    async def fake_get_label_by_generic_or_brand_name(name: str):
        assert name == "warfarin"
        return {
            "openfda": {
                "generic_name": ["WARFARIN SODIUM"],
                "brand_name": ["Coumadin"],
                "substance_name": ["WARFARIN SODIUM"],
            }
        }

    async def fake_get_related_concepts_by_type(rxcui: str, term_types: list[str]):
        assert rxcui == "11289"
        assert term_types == ["SCD", "SBD", "GPCK", "BPCK", "BN"]
        return {
            "SCD": [
                {
                    "rxcui": "855332",
                    "name": "warfarin sodium 5 MG Oral Tablet",
                    "synonym": "",
                    "tty": "SCD",
                }
            ],
            "BN": [
                {
                    "rxcui": "202421",
                    "name": "Coumadin",
                    "synonym": "",
                    "tty": "BN",
                },
                {
                    "rxcui": "202422",
                    "name": "Jantoven",
                    "synonym": "",
                    "tty": "BN",
                }
            ],
        }

    monkeypatch.setattr(
        drug_alternatives_router,
        "resolve_drug_name",
        fake_resolve_drug_name,
    )
    monkeypatch.setattr(
        drug_alternatives_router,
        "get_spl_by_rxcui",
        fake_get_spl_by_rxcui,
    )
    monkeypatch.setattr(
        drug_alternatives_router,
        "get_label_by_generic_or_brand_name",
        fake_get_label_by_generic_or_brand_name,
    )
    monkeypatch.setattr(
        drug_alternatives_router,
        "get_related_concepts_by_type",
        fake_get_related_concepts_by_type,
    )

    client = TestClient(app)
    response = client.get("/drug-alternatives", params={"name": "warfarin"})

    assert response.status_code == 200
    payload = response.json()
    assert [alternative["name"] for alternative in payload["alternatives"]] == [
        "Coumadin",
        "Jantoven",
    ]
