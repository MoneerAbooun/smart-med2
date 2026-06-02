from app.models.personalized_explanation_models import ExplanationAlertItem
from app.services.medication_safety_rules import (
    build_medication_badges,
    build_overall_severity,
    build_profile_completeness,
    build_quick_summary,
)


def test_build_profile_completeness_reports_missing_fields():
    profile = {
        "age": 41,
        "medicalInfo": {
            "biologicalSex": "male",
        },
    }

    completeness = build_profile_completeness(
        profile=profile,
        allergies=[],
        conditions=["hypertension"],
    )

    assert completeness.is_complete is False
    assert "allergies" in completeness.missing_fields
    assert "blood_pressure" in completeness.missing_fields
    assert "weight" in completeness.missing_fields


def test_build_badges_and_summary_use_alert_severity():
    interaction_alert = ExplanationAlertItem(
        severity="High",
        title="Interaction warning",
        detail="Important interaction",
        source_ids=["interaction:pair", "medication:med-1", "medication:med-2"],
    )
    personalized_risk = ExplanationAlertItem(
        severity="Moderate",
        title="Condition caution",
        detail="Profile-specific risk",
        source_ids=["profile", "medication:med-2"],
    )

    completeness = build_profile_completeness(
        profile={
            "age": 30,
            "medicalInfo": {
                "biologicalSex": "male",
                "systolicPressure": 120,
                "diastolicPressure": 80,
                "weightKg": 70,
            },
        },
        allergies=["penicillin"],
        conditions=["hypertension"],
    )

    badges = build_medication_badges(
        medications=[
            {"medication_id": "med-1", "name": "Drug A"},
            {"medication_id": "med-2", "name": "Drug B"},
        ],
        interaction_alerts=[interaction_alert],
        personalized_risks=[personalized_risk],
        profile_completeness=completeness,
    )

    severity = build_overall_severity([interaction_alert, personalized_risk])
    summary = build_quick_summary(
        medication_count=2,
        interaction_count=1,
        caution_count=1,
        overall_severity=severity,
        profile_completeness=completeness,
        is_preview=False,
    )

    assert severity == "High"
    assert badges[0].label == "High caution"
    assert badges[1].severity == "High"
    assert "1 interaction alert" in summary
    assert "1 profile-based caution" in summary
