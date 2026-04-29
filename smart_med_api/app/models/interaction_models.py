from pydantic import BaseModel, Field


class DrugInteractionResponse(BaseModel):
    first_query: str
    second_query: str
    first_drug: str
    second_drug: str
    first_generic_name: str | None = None
    second_generic_name: str | None = None
    first_rxcui: str | None = None
    second_rxcui: str | None = None
    first_set_id: str | None = None
    second_set_id: str | None = None
    severity: str
    summary: str
    mechanism: str | None = None
    warnings: list[str] = Field(default_factory=list)
    recommendations: list[str] = Field(default_factory=list)
    evidence: list[str] = Field(default_factory=list)
    source: str = "rxnorm+openfda+dailymed+heuristic"
