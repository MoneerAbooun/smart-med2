from __future__ import annotations

from fastapi import APIRouter, Depends

from app.models.personalized_explanation_models import (
    PersonalizedExplanationRequest,
    PersonalizedExplanationResponse,
)
from app.services.firebase_admin_service import VerifiedFirebaseUser, verify_firebase_user
from app.services.personalized_explanation_service import (
    generate_personalized_explanation,
)

router = APIRouter(tags=["personalized-explanation"])


@router.post(
    "/personalized-explanation",
    response_model=PersonalizedExplanationResponse,
)
async def create_personalized_explanation(
    request: PersonalizedExplanationRequest,
    user: VerifiedFirebaseUser = Depends(verify_firebase_user),
) -> PersonalizedExplanationResponse:
    return await generate_personalized_explanation(user=user, request=request)
