import asyncio

from app.services import rxnorm_service


def test_best_approximate_rxcui_rejects_low_scores():
    assert (
        rxnorm_service._best_approximate_rxcui(
            [{"rxcui": "25255", "score": "1.7991000000000001"}]
        )
        is None
    )


def test_best_approximate_rxcui_accepts_high_scores():
    assert (
        rxnorm_service._best_approximate_rxcui(
            [{"rxcui": "5640", "score": "8.71348762512207"}]
        )
        == "5640"
    )


def test_approximate_match_skips_non_latin_terms():
    arabic_paracetamol = "\u0628\u0627\u0631\u0627\u0633\u064a\u062a\u0627\u0645\u0648\u0644"

    result = asyncio.run(rxnorm_service.get_approximate_match(arabic_paracetamol))

    assert result is None
