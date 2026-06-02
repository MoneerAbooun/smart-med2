from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class DraftMedicationInput(BaseModel):
    existing_medication_id: str | None = None
    name: str
    generic_name: str | None = None
    brand_name: str | None = None
    dose_amount: float | None = None
    dose_unit: str | None = None
    frequency_per_day: int | None = None
    reminder_times: list[str] = Field(default_factory=list)
    start_date: datetime | None = None
    instructions: str | None = None
    notes: str | None = None
    form: str | None = None
    status: str = "active"
    reminders_enabled: bool = True


class PersonalizedExplanationRequest(BaseModel):
    view: Literal["detail", "brief", "preview"] = "detail"
    medication_ids: list[str] = Field(default_factory=list)
    include_inactive: bool = False
    simple_language: bool = True
    draft_medication: DraftMedicationInput | None = None


class ExplanationMedicationItem(BaseModel):
    medication_id: str
    name: str
    generic_name: str | None = None
    explanation: str
    source_ids: list[str] = Field(default_factory=list)


class ExplanationAlertItem(BaseModel):
    severity: str
    title: str
    detail: str
    source_ids: list[str] = Field(default_factory=list)


class EvidenceItem(BaseModel):
    id: str
    source_type: str
    title: str
    detail: str


class MedicationBadgeItem(BaseModel):
    medication_id: str
    label: str
    severity: str


class ProfileCompletenessItem(BaseModel):
    is_complete: bool = False
    missing_fields: list[str] = Field(default_factory=list)
    summary: str = "Profile completeness was not calculated."


class PersonalizedExplanationResponse(BaseModel):
    generated_at: datetime
    source: str = "firestore+xai"
    model: str | None = None
    prompt_version: str = "grounded-firestore-v2"
    grounded_only: bool = False
    quick_summary: str = ""
    overall_severity: str = "Low"
    caution_count: int = 0
    interaction_count: int = 0
    safer_behavior_tips: list[str] = Field(default_factory=list)
    medication_badges: list[MedicationBadgeItem] = Field(default_factory=list)
    profile_completeness: ProfileCompletenessItem = Field(
        default_factory=ProfileCompletenessItem,
    )
    overview: str
    medication_explanations: list[ExplanationMedicationItem] = Field(
        default_factory=list,
    )
    interaction_alerts: list[ExplanationAlertItem] = Field(default_factory=list)
    personalized_risks: list[ExplanationAlertItem] = Field(default_factory=list)
    questions_for_clinician: list[str] = Field(default_factory=list)
    missing_information: list[str] = Field(default_factory=list)
    evidence: list[EvidenceItem] = Field(default_factory=list)
