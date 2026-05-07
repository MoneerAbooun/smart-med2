import asyncio

import pytest
from fastapi import HTTPException

from app.services import medicine_information_service as service


def test_lookup_medicine_information_uses_high_confidence_ml_fallback(monkeypatch):
    arabic_paracetamol = "\u0628\u0627\u0631\u0627\u0633\u064a\u062a\u0627\u0645\u0648\u0644"
    resolve_calls: list[str] = []

    async def fake_resolve_drug_name(name: str):
        resolve_calls.append(name)
        if name == "acetaminophen":
            return "161", "acetaminophen"
        return None, None

    async def fake_get_spl_by_rxcui(rxcui: str):
        return {"setid": "set-1"}

    async def fake_get_label_by_generic_or_brand_name(name: str):
        assert name == "acetaminophen"
        return {
            "openfda": {
                "generic_name": ["ACETAMINOPHEN"],
                "brand_name": ["Tylenol"],
                "substance_name": ["ACETAMINOPHEN"],
            },
            "indications_and_usage": ["Pain relief"],
        }

    async def fake_get_related_concepts_by_type(rxcui: str, term_types: list[str]):
        return {}

    monkeypatch.setattr(service, "resolve_drug_name", fake_resolve_drug_name)
    monkeypatch.setattr(
        service,
        "predict_generic_name",
        lambda query: {
            "input_text": query,
            "predicted_generic_name": "acetaminophen",
            "confidence": 1.0,
        },
    )
    monkeypatch.setattr(service, "get_spl_by_rxcui", fake_get_spl_by_rxcui)
    monkeypatch.setattr(
        service,
        "get_label_by_generic_or_brand_name",
        fake_get_label_by_generic_or_brand_name,
    )
    monkeypatch.setattr(
        service,
        "get_related_concepts_by_type",
        fake_get_related_concepts_by_type,
    )

    result = asyncio.run(
        service.lookup_medicine_information(query=arabic_paracetamol)
    )

    assert resolve_calls == [arabic_paracetamol, "acetaminophen"]
    assert result.query == arabic_paracetamol
    assert result.medicine_name == "acetaminophen"
    assert result.generic_name == "ACETAMINOPHEN"
    assert result.brand_names == ["Tylenol"]


def test_lookup_medicine_information_ignores_low_confidence_ml_fallback(monkeypatch):
    arabic_unknown = "\u063a\u064a\u0631\u0645\u0639\u0631\u0648\u0641"
    resolve_calls: list[str] = []

    async def fake_resolve_drug_name(name: str):
        resolve_calls.append(name)
        return None, None

    monkeypatch.setattr(service, "resolve_drug_name", fake_resolve_drug_name)
    monkeypatch.setattr(
        service,
        "predict_generic_name",
        lambda query: {
            "input_text": query,
            "predicted_generic_name": "formoterol",
            "confidence": 0.08,
        },
    )

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(service.lookup_medicine_information(query=arabic_unknown))

    assert exc_info.value.status_code == 404
    assert resolve_calls == [arabic_unknown]
