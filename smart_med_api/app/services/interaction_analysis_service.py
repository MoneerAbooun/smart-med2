from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class InteractionResult:
    severity: str
    summary: str
    mechanism: str | None
    warnings: list[str]
    recommendations: list[str]
    evidence: list[str]


@dataclass(frozen=True)
class CuratedRule:
    group_a: set[str]
    group_b: set[str]
    severity: str
    summary: str
    mechanism: str
    warnings: list[str]
    recommendations: list[str]


def _normalize_name(value: str) -> str:
    return " ".join(value.lower().replace("-", " ").replace("/", " ").split())


def _clean_aliases(values: Iterable[str | None]) -> set[str]:
    aliases: set[str] = set()
    for value in values:
        if not value:
            continue
        normalized = _normalize_name(value)
        if normalized:
            aliases.add(normalized)
            aliases.update(
                part.strip()
                for part in normalized.replace(";", ",").split(",")
                if part.strip()
            )
    return aliases


def _text_mentions_alias(text: str, aliases: set[str]) -> list[str]:
    mentions: list[str] = []
    for alias in aliases:
        if len(alias) < 3:
            continue
        if alias in text:
            mentions.append(alias)
    return sorted(set(mentions))


def _has_group(aliases: set[str], group: set[str]) -> bool:
    return bool(aliases & group)


CURATED_RULES: list[CuratedRule] = [
    CuratedRule(
        group_a={"warfarin"},
        group_b={"ibuprofen", "naproxen", "diclofenac", "aspirin", "ketorolac", "meloxicam", "celecoxib"},
        severity="High",
        summary="This combination can increase bleeding risk.",
        mechanism="Concurrent anticoagulant and NSAID therapy can increase gastrointestinal and other bleeding.",
        warnings=[
            "Watch closely for bruising, black stools, unusual bleeding, or dizziness.",
            "This combination often needs clinician review before routine use.",
        ],
        recommendations=[
            "Avoid self-starting this combination without clinician advice.",
            "If it is prescribed, monitoring and a safer pain-relief plan may be needed.",
        ],
    ),
    CuratedRule(
        group_a={"ibuprofen", "naproxen", "diclofenac", "ketorolac", "meloxicam", "celecoxib"},
        group_b={"ibuprofen", "naproxen", "diclofenac", "ketorolac", "meloxicam", "celecoxib"},
        severity="Moderate",
        summary="Using two NSAID-type pain medicines together can raise stomach, kidney, and bleeding risks.",
        mechanism="NSAIDs can overlap in side effects without usually adding enough benefit to justify combining them.",
        warnings=[
            "Stomach irritation, ulcers, kidney stress, and bleeding risk can increase.",
        ],
        recommendations=[
            "Avoid combining two NSAIDs unless a clinician specifically instructed you to do so.",
            "Use only one NSAID product at a time unless you have professional advice.",
        ],
    ),
    CuratedRule(
        group_a={"sildenafil", "tadalafil", "vardenafil", "avanafil"},
        group_b={"nitroglycerin", "isosorbide mononitrate", "isosorbide dinitrate"},
        severity="High",
        summary="This combination can cause a dangerous drop in blood pressure.",
        mechanism="PDE-5 inhibitors and nitrates both increase vasodilation and can cause severe hypotension together.",
        warnings=[
            "This is generally treated as a major contraindicated combination.",
        ],
        recommendations=[
            "Do not combine these medicines unless a clinician explicitly instructs you to do so.",
            "Seek urgent medical help if severe dizziness, fainting, or chest symptoms occur.",
        ],
    ),
    CuratedRule(
        group_a={"diazepam", "lorazepam", "alprazolam", "clonazepam", "temazepam"},
        group_b={"morphine", "oxycodone", "hydrocodone", "tramadol", "fentanyl", "codeine"},
        severity="High",
        summary="This combination can cause excessive sedation and breathing problems.",
        mechanism="Benzodiazepines and opioids both suppress the central nervous system and respiratory drive.",
        warnings=[
            "Sleepiness, confusion, slowed breathing, and overdose risk can increase.",
        ],
        recommendations=[
            "Use only if a prescriber knows about both medicines and has decided the combination is necessary.",
            "Avoid alcohol and other sedating medicines while taking this combination.",
        ],
    ),
]


def _match_curated_rule(first_aliases: set[str], second_aliases: set[str]) -> CuratedRule | None:
    for rule in CURATED_RULES:
        direct = _has_group(first_aliases, rule.group_a) and _has_group(second_aliases, rule.group_b)
        reverse = _has_group(first_aliases, rule.group_b) and _has_group(second_aliases, rule.group_a)
        if direct or reverse:
            return rule
    return None


def analyze_interaction(
    *,
    first_display_name: str,
    second_display_name: str,
    first_aliases: set[str],
    second_aliases: set[str],
    first_profile: dict[str, object],
    second_profile: dict[str, object],
) -> InteractionResult:
    rule = _match_curated_rule(first_aliases, second_aliases)
    if rule is not None:
        return InteractionResult(
            severity=rule.severity,
            summary=rule.summary,
            mechanism=rule.mechanism,
            warnings=rule.warnings,
            recommendations=rule.recommendations,
            evidence=[
                f"Curated safety rule matched for {first_display_name} and {second_display_name}.",
            ],
        )

    first_text = str(first_profile.get("searchable_text") or "")
    second_text = str(second_profile.get("searchable_text") or "")

    first_contras = " ".join(first_profile.get("contraindications", []) or []).lower()
    second_contras = " ".join(second_profile.get("contraindications", []) or []).lower()
    first_interactions = " ".join(first_profile.get("drug_interactions", []) or []).lower()
    second_interactions = " ".join(second_profile.get("drug_interactions", []) or []).lower()
    first_warnings = " ".join(first_profile.get("warnings", []) or []).lower()
    second_warnings = " ".join(second_profile.get("warnings", []) or []).lower()

    direct_contra = _text_mentions_alias(first_contras, second_aliases) + _text_mentions_alias(second_contras, first_aliases)
    if direct_contra:
        return InteractionResult(
            severity="High",
            summary="A direct contraindication mention was found in public labeling for this pair.",
            mechanism="The public labeling suggests this combination should be avoided or used only with specialist guidance.",
            warnings=[
                "One medicine appears by name in the other medicine's contraindication text.",
            ],
            recommendations=[
                "Treat this as a high-priority clinician review before taking the two medicines together.",
            ],
            evidence=[f"Direct contraindication mention: {', '.join(direct_contra)}."],
        )

    direct_interaction = _text_mentions_alias(first_interactions, second_aliases) + _text_mentions_alias(second_interactions, first_aliases)
    if direct_interaction:
        return InteractionResult(
            severity="Moderate",
            summary="A direct drug-interaction mention was found in public labeling for this pair.",
            mechanism="The public labeling flags a named interaction that may require caution, dose adjustment, or monitoring.",
            warnings=[
                "One medicine appears by name in the other medicine's interaction section.",
            ],
            recommendations=[
                "Review this combination with a clinician or pharmacist before routine use.",
                "Follow label instructions and monitoring advice if the combination is prescribed.",
            ],
            evidence=[f"Direct drug-interaction mention: {', '.join(direct_interaction)}."],
        )

    direct_warning = _text_mentions_alias(first_warnings, second_aliases) + _text_mentions_alias(second_warnings, first_aliases)
    if direct_warning:
        return InteractionResult(
            severity="Moderate",
            summary="A named warning mention was found in public labeling for this pair.",
            mechanism="The public labeling suggests caution with the named medicine, even if it is not framed as a formal contraindication.",
            warnings=[
                "One medicine appears by name in the other medicine's warning text.",
            ],
            recommendations=[
                "Use this combination only with label-aware caution and clinician advice when needed.",
            ],
            evidence=[f"Direct warning mention: {', '.join(direct_warning)}."],
        )

    if first_text or second_text:
        return InteractionResult(
            severity="No specific interaction found",
            summary="No direct pair-specific interaction signal was found in the free public sources checked for this pair.",
            mechanism="This result comes from free public labeling sources and rule-based comparison, not from a dedicated clinical interaction database.",
            warnings=[
                "Absence of a signal here does not guarantee the combination is risk-free.",
            ],
            recommendations=[
                "Still check dose limits, overlapping ingredients, and patient-specific risks such as pregnancy, kidney disease, liver disease, and allergies.",
                "Escalate to a clinician or pharmacist for uncertain or high-risk cases.",
            ],
            evidence=[
                "No direct pair-specific name match was found in contraindications, interaction sections, or warnings from the public labels reviewed.",
            ],
        )

    return InteractionResult(
        severity="Unknown",
        summary="Interaction analysis could not be completed from the available public records.",
        mechanism="At least one drug did not return enough public labeling data for a meaningful free-source comparison.",
        warnings=[
            "This is an incomplete result rather than a clean negative interaction check.",
        ],
        recommendations=[
            "Try a more specific drug name or use a clinician/pharmacist review for safety-critical decisions.",
        ],
        evidence=[
            "Public labeling data was incomplete for at least one of the queried medicines.",
        ],
    )


def build_aliases(*values: object) -> set[str]:
    flattened: list[str | None] = []
    for value in values:
        if isinstance(value, str) or value is None:
            flattened.append(value)
        elif isinstance(value, list):
            flattened.extend(str(item) for item in value if item)
    return _clean_aliases(flattened)
