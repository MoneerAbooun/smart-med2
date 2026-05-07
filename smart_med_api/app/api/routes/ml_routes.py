from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.ml.drug_name_model import predict_generic_name

router = APIRouter(tags=["ml"])


class DrugNamePredictionRequest(BaseModel):
    input_text: str = Field(..., min_length=1)


class DrugNamePredictionResponse(BaseModel):
    input_text: str
    predicted_generic_name: str
    confidence: float | None = None


@router.post("/ml/predict-drug-name", response_model=DrugNamePredictionResponse)
async def predict_drug_name(
    request: DrugNamePredictionRequest,
) -> DrugNamePredictionResponse:
    # This endpoint calls the trained scikit-learn Pipeline saved by the
    # training script; it is intentionally separate from the rule/API logic.
    try:
        prediction = predict_generic_name(request.input_text)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return DrugNamePredictionResponse(**prediction)
