from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

from joblib import load

PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = PROJECT_ROOT / "models" / "drug_name_model.joblib"

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.ml.drug_name_model import EXACT_MATCH_CONFIDENCE, normalize_text

TEST_INPUTS = [
    "اكامول",
    "أكانول",
    "بنادول",
    "تروقين",
    "بروفين",
    "اسبرين",
    "أموكسيسيلين",
    "ميتفورمين",
    "اوميبرازول",
    "سيرترالين",
    "كلاريتين",
    "سالبيوتامول",
]

RTL_ISOLATE = "\u2067"
POP_DIRECTIONAL_ISOLATE = "\u2069"


def display_input_text(input_text: str) -> str:
    return f"{RTL_ISOLATE}{input_text}{POP_DIRECTIONAL_ISOLATE}"


def predict_with_confidence(model: Any, input_text: str) -> tuple[str, float | None]:
    normalized_text = normalize_text(input_text)
    if isinstance(model, dict):
        exact_matches = model.get("exact_matches", {})
        if isinstance(exact_matches, dict) and normalized_text in exact_matches:
            return str(exact_matches[normalized_text]), EXACT_MATCH_CONFIDENCE

        model = model["pipeline"]

    predicted_generic_name = str(model.predict([normalized_text])[0])

    confidence: float | None = None
    if hasattr(model, "predict_proba"):
        probabilities = model.predict_proba([normalized_text])[0]
        confidence = float(max(probabilities))

    return predicted_generic_name, confidence


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            "Drug name ML model is missing. Run "
            "`python scripts/train_drug_name_model.py` first."
        )

    model = load(MODEL_PATH)
    for input_text in TEST_INPUTS:
        predicted_generic_name, confidence = predict_with_confidence(model, input_text)
        confidence_text = "n/a" if confidence is None else f"{confidence:.3f}"
        print(
            f"{display_input_text(input_text)} -> "
            f"{predicted_generic_name} -> {confidence_text}"
        )


if __name__ == "__main__":
    main()
