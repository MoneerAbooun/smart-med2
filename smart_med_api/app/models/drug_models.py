from pydantic import BaseModel, Field


class DrugDetailsResponse(BaseModel):
    query: str
    matched_name: str | None = None
    generic_name: str | None = None
    brand_names: list[str] = Field(default_factory=list)
    active_ingredients: list[str] = Field(default_factory=list)
    uses: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    side_effects: list[str] = Field(default_factory=list)
    dosage_notes: list[str] = Field(default_factory=list)
    contraindications: list[str] = Field(default_factory=list)
    source: str = "rxnorm+dailymed+openfda"
    rxcui: str | None = None
    set_id: str | None = None


class DrugAlternativeItem(BaseModel):
    name: str
    rxcui: str | None = None
    term_type: str | None = None
    category: str = "Alternative"


class DrugAlternativesResponse(BaseModel):
    query: str
    matched_name: str | None = None
    generic_name: str | None = None
    active_ingredients: list[str] = Field(default_factory=list)
    alternatives: list[DrugAlternativeItem] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)
    source: str = "rxnorm+openfda"
    rxcui: str | None = None
    set_id: str | None = None
