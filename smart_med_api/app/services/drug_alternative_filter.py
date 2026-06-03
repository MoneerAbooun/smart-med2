from __future__ import annotations

import re
from collections.abc import Iterable

from app.models.drug_models import DrugAlternativeItem

RELATED_TERM_TYPES = ["SCD", "SBD", "GPCK", "BPCK", "BN"]

CATEGORY_BY_TERM_TYPE = {
    "SCD": "Generic drug",
    "SBD": "Brand drug",
    "GPCK": "Generic pack",
    "BPCK": "Brand pack",
    "BN": "Brand name",
}

GENERIC_PRODUCT_TERM_TYPES = {"SCD", "GPCK"}
BRAND_PRODUCT_TERM_TYPES = {"SBD", "BPCK", "BN"}

DOSE_AND_FORM_WORDS = {
    "actuat",
    "aerosol",
    "cap",
    "capsule",
    "chewable",
    "cream",
    "delayed",
    "dose",
    "dr",
    "ec",
    "er",
    "extended",
    "film",
    "g",
    "gel",
    "hr",
    "im",
    "inhalant",
    "injection",
    "ir",
    "iu",
    "iv",
    "mcg",
    "mg",
    "ml",
    "oral",
    "patch",
    "powder",
    "release",
    "solution",
    "sublingual",
    "suspension",
    "syrup",
    "tab",
    "tablet",
    "topical",
    "xr",
}


def normalized_text(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.lower().split())


def preferred_name(concept: dict[str, str]) -> str:
    synonym = concept.get("synonym", "").strip()
    name = concept.get("name", "").strip()
    return synonym or name


def collect_alternatives(
    related: dict[str, list[dict[str, str]]],
    query: str,
    matched_name: str | None,
    *,
    reference_names: Iterable[str | None] = (),
    limit: int = 12,
) -> list[DrugAlternativeItem]:
    alternatives: list[DrugAlternativeItem] = []
    seen: set[str] = {normalized_text(query), normalized_text(matched_name)}
    normalized_references = _normalized_reference_names(
        (query, matched_name, *reference_names)
    )
    normalized_searched_names = _normalized_reference_names((query, matched_name))

    for term_type in RELATED_TERM_TYPES:
        for concept in related.get(term_type, []):
            name = preferred_name(concept)
            key = normalized_text(name)
            concept_term_type = (concept.get("tty") or term_type).strip().upper()

            if not name or not key or key in seen:
                continue

            if _is_same_medicine_alternative(
                name,
                concept_term_type,
                normalized_references,
                normalized_searched_names,
            ):
                continue

            seen.add(key)
            alternatives.append(
                DrugAlternativeItem(
                    name=name,
                    rxcui=concept.get("rxcui") or None,
                    term_type=concept.get("tty") or term_type,
                    category=CATEGORY_BY_TERM_TYPE.get(
                        concept_term_type,
                        CATEGORY_BY_TERM_TYPE.get(term_type, "Alternative"),
                    ),
                )
            )

            if len(alternatives) >= limit:
                return alternatives

    return alternatives


def _normalized_reference_names(values: Iterable[str | None]) -> set[str]:
    return {
        normalized
        for value in values
        if (normalized := _normalized_drug_name(value or ""))
    }


def _is_same_medicine_alternative(
    name: str,
    term_type: str,
    reference_names: set[str],
    searched_names: set[str],
) -> bool:
    normalized_name = _normalized_drug_name(name)
    if not normalized_name:
        return False

    if term_type in GENERIC_PRODUCT_TERM_TYPES:
        return any(
            _names_refer_to_same_medicine(normalized_name, reference_name)
            for reference_name in reference_names
        )

    if term_type in BRAND_PRODUCT_TERM_TYPES:
        return any(
            _names_refer_to_same_medicine(normalized_name, searched_name)
            for searched_name in searched_names
        )

    return any(
        _names_refer_to_same_medicine(normalized_name, reference_name)
        for reference_name in reference_names
    )


def _names_refer_to_same_medicine(left: str, right: str) -> bool:
    if left == right:
        return True

    left_tokens = {token for token in left.split(" ") if token}
    right_tokens = {token for token in right.split(" ") if token}

    if not left_tokens or not right_tokens:
        return False

    return left_tokens.issuperset(right_tokens) or right_tokens.issuperset(left_tokens)


def _normalized_drug_name(value: str) -> str:
    normalized = re.sub(r"\([^)]*\)", " ", value.lower())
    normalized = re.sub(r"[^a-z0-9]+", " ", normalized)

    tokens = [
        token
        for token in normalized.split()
        if not token.isdigit() and token not in DOSE_AND_FORM_WORDS
    ]
    return " ".join(tokens)
