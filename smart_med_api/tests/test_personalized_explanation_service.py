import asyncio
from types import SimpleNamespace

import httpx
from fastapi import HTTPException, status
from openai import APIConnectionError

from app.models.personalized_explanation_models import (
    ExplanationMedicationItem,
    PersonalizedExplanationRequest,
    ProfileCompletenessItem,
)
from app.services.firebase_admin_service import _ensure_initialized
from app.services.personalized_explanation_service import (
    GroundedFacts,
    _generate_with_xai,
)


def _grounded_facts() -> GroundedFacts:
    return GroundedFacts(
        quick_summary="Grounded summary",
        overall_severity="Low",
        caution_count=0,
        interaction_count=0,
        safer_behavior_tips=["Take it as recorded."],
        medication_badges=[],
        profile_completeness=ProfileCompletenessItem(),
        overview="Grounded overview",
        medication_explanations=[
            ExplanationMedicationItem(
                medication_id="med-1",
                name="Ibuprofen",
                generic_name="Ibuprofen",
                explanation="Grounded medication explanation",
                source_ids=["medication:med-1"],
            ),
        ],
        interaction_alerts=[],
        personalized_risks=[],
        questions_for_clinician=["Do I need a follow-up?"],
        missing_information=[],
        evidence=[],
        model_payload={"medications": [{"medication_id": "med-1", "name": "Ibuprofen"}]},
    )


def test_generate_with_xai_falls_back_when_provider_request_fails(monkeypatch):
    request = PersonalizedExplanationRequest()
    grounded = _grounded_facts()
    fake_request = httpx.Request("POST", "https://api.x.ai/v1/responses")

    class FakeResponses:
        def create(self, **kwargs):
            raise APIConnectionError(message="network down", request=fake_request)

    class FakeClient:
        responses = FakeResponses()

    monkeypatch.setattr(
        "app.services.personalized_explanation_service.get_settings",
        lambda: SimpleNamespace(xai_model="grok-4.20-reasoning"),
    )
    monkeypatch.setattr(
        "app.services.personalized_explanation_service.get_xai_client",
        lambda: FakeClient(),
    )

    response = asyncio.run(_generate_with_xai(request=request, grounded=grounded))

    assert response.grounded_only is True
    assert response.source == "firestore+rules"
    assert response.quick_summary == grounded.quick_summary
    assert response.medication_explanations == grounded.medication_explanations


def test_generate_with_xai_falls_back_when_client_configuration_is_missing(monkeypatch):
    request = PersonalizedExplanationRequest()
    grounded = _grounded_facts()

    monkeypatch.setattr(
        "app.services.personalized_explanation_service.get_settings",
        lambda: SimpleNamespace(xai_model="grok-4.20-reasoning"),
    )
    monkeypatch.setattr(
        "app.services.personalized_explanation_service.get_xai_client",
        lambda: (_ for _ in ()).throw(
            HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="XAI_API_KEY is not configured.",
            ),
        ),
    )

    response = asyncio.run(_generate_with_xai(request=request, grounded=grounded))

    assert response.grounded_only is True
    assert response.source == "firestore+rules"


def test_ensure_initialized_ignores_duplicate_default_app_race(monkeypatch):
    monkeypatch.setattr(
        "app.services.firebase_admin_service.firebase_admin.get_app",
        lambda: (_ for _ in ()).throw(ValueError("no default app")),
    )
    monkeypatch.setattr(
        "app.services.firebase_admin_service.os.getenv",
        lambda name: "C:\\fake-service-account.json",
    )
    monkeypatch.setattr(
        "app.services.firebase_admin_service.credentials.Certificate",
        lambda path: object(),
    )
    monkeypatch.setattr(
        "app.services.firebase_admin_service.firebase_admin.initialize_app",
        lambda *args, **kwargs: (_ for _ in ()).throw(
            ValueError("The default Firebase app already exists.")
        ),
    )

    _ensure_initialized()
