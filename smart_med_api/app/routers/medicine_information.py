from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Query
from app.models.medicine_models import MedicineInformationResponse
from app.services.medicine_information_service import lookup_medicine_information

router = APIRouter(tags=["medicine-information"])


@router.get("/medicine-information", response_model=MedicineInformationResponse)
async def get_medicine_information(
    name: str = Query(..., min_length=2, description="Medicine name typed by the user"),
) -> Any:
    return await lookup_medicine_information(query=name)
