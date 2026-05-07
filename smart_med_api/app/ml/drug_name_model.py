from __future__ import annotations

import re
import unicodedata
from pathlib import Path
from threading import Lock
from typing import Any, TypedDict

PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODEL_PATH = PROJECT_ROOT / "models" / "drug_name_model.joblib"

_MODEL: Any | None = None
_MODEL_LOCK = Lock()
EXACT_MATCH_CONFIDENCE = 1.0


class DrugNamePrediction(TypedDict):
    input_text: str
    predicted_generic_name: str
    confidence: float | None


def normalize_text(value: str) -> str:
    text = str(value).strip().lower()

    text = "".join(
        char
        for char in unicodedata.normalize("NFKD", text)
        if not unicodedata.combining(char)
    )

    text = text.replace("أ", "ا")
    text = text.replace("إ", "ا")
    text = text.replace("آ", "ا")
    text = text.replace("ى", "ي")
    text = text.replace("ة", "ه")
    text = text.replace("ؤ", "و")
    text = text.replace("ئ", "ي")

    text = re.sub(r"\s+", " ", text)

    return text


def normalize_drug_text(input_text: str) -> str:
    """Normalize noisy medication text before vectorization."""
    return normalize_text(input_text)


def _load_model(model_path: Path = MODEL_PATH) -> Any:
    """Load the trained scikit-learn model only when prediction is requested."""
    global _MODEL

    if _MODEL is None:
        with _MODEL_LOCK:
            if _MODEL is None:
                if not model_path.exists():
                    raise FileNotFoundError(
                        "Drug name ML model is missing. Run "
                        "`python scripts/train_drug_name_model.py` from smart_med_api "
                        "to create models/drug_name_model.joblib."
                    )

                from joblib import load

                _MODEL = load(model_path)

    return _MODEL


def _get_pipeline(model_artifact: Any) -> Any:
    if isinstance(model_artifact, dict) and "pipeline" in model_artifact:
        return model_artifact["pipeline"]

    return model_artifact


def _get_exact_matches(model_artifact: Any) -> dict[str, str]:
    if isinstance(model_artifact, dict):
        exact_matches = model_artifact.get("exact_matches", {})
        if isinstance(exact_matches, dict):
            return {str(key): str(value) for key, value in exact_matches.items()}

    return {}


def predict_generic_name(input_text: str) -> DrugNamePrediction:
    """Predict the normalized generic name using a real trained ML model."""
    normalized_text = normalize_drug_text(input_text)
    if not normalized_text:
        raise ValueError("input_text must contain at least one letter or number.")

    model_artifact = _load_model()
    exact_matches = _get_exact_matches(model_artifact)
    exact_generic_name = exact_matches.get(normalized_text)
    if exact_generic_name is not None:
        return {
            "input_text": input_text,
            "predicted_generic_name": exact_generic_name,
            "confidence": EXACT_MATCH_CONFIDENCE,
        }

    model = _get_pipeline(model_artifact)
    predicted_generic_name = str(model.predict([normalized_text])[0])
    confidence: float | None = None

    if hasattr(model, "predict_proba"):
        probabilities = model.predict_proba([normalized_text])[0]
        confidence = float(max(probabilities))

    return {
        "input_text": input_text,
        "predicted_generic_name": predicted_generic_name,
        "confidence": confidence,
    }
