from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

from app.models.drug_models import DrugAlternativeItem


class MedicineInformationResponse(BaseModel):
    query: str
    search_mode: Literal["name", "image"] = "name"
    medicine_name: str
    matched_name: str | None = None
    generic_name: str | None = None
    brand_names: list[str] = Field(default_factory=list)
    active_ingredients: list[str] = Field(default_factory=list)
    used_for: list[str] = Field(default_factory=list)
    dose: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    side_effects: list[str] = Field(default_factory=list)
    interactions: list[str] = Field(default_factory=list)
    alternatives: list[DrugAlternativeItem] = Field(default_factory=list)
    storage: list[str] = Field(default_factory=list)
    disclaimer: list[str] = Field(default_factory=list)
    identification_reason: str | None = None
    source: str = "rxnorm+dailymed+openfda"
    rxcui: str | None = None
    set_id: str | None = None
