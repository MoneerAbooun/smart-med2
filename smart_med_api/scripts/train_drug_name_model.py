from __future__ import annotations

import csv
import sys
from collections import Counter
from pathlib import Path

from joblib import dump
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = PROJECT_ROOT / "data" / "drug_name_training.csv"
MODEL_PATH = PROJECT_ROOT / "models" / "drug_name_model.joblib"
REQUIRED_COLUMNS = {"input_text", "generic_name", "brand_name"}
MODEL_ARTIFACT_VERSION = 2

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.ml.drug_name_model import normalize_text


def load_training_data(
    data_path: Path = DATA_PATH,
) -> tuple[list[str], list[str], dict[str, str]]:
    with data_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        missing_columns = REQUIRED_COLUMNS.difference(reader.fieldnames or [])
        if missing_columns:
            missing = ", ".join(sorted(missing_columns))
            raise ValueError(f"Training data is missing required columns: {missing}")

        input_texts: list[str] = []
        generic_names: list[str] = []
        exact_matches: dict[str, str] = {}
        for row in reader:
            input_text = normalize_text(row["input_text"])
            generic_name = normalize_text(row["generic_name"])
            if input_text and generic_name:
                input_texts.append(input_text)
                generic_names.append(generic_name)
                exact_matches[input_text] = generic_name

    if not input_texts:
        raise ValueError(f"No usable training rows found in {data_path}")

    return input_texts, generic_names, exact_matches


def build_pipeline() -> Pipeline:
    # This is a real trained ML model: character n-grams let sklearn learn
    # spelling, brand-name, and typo patterns instead of using exact rules.
    return Pipeline(
        steps=[
            (
                "tfidf",
                TfidfVectorizer(
                    analyzer="char_wb",
                    ngram_range=(2, 5),
                    lowercase=False,
                ),
            ),
            (
                "classifier",
                LogisticRegression(
                    class_weight="balanced",
                    C=5.0,
                    max_iter=1000,
                    random_state=42,
                ),
            ),
        ]
    )


def main() -> None:
    input_texts, generic_names, exact_matches = load_training_data()
    class_counts = Counter(generic_names)
    if len(class_counts) < 2:
        raise ValueError("At least two generic_name classes are required to train.")
    if min(class_counts.values()) < 2:
        raise ValueError("Each generic_name class needs at least two examples.")

    x_train, x_test, y_train, y_test = train_test_split(
        input_texts,
        generic_names,
        test_size=0.4,
        random_state=42,
        stratify=generic_names,
    )

    evaluation_model = build_pipeline()
    evaluation_model.fit(x_train, y_train)
    y_pred = evaluation_model.predict(x_test)
    print(classification_report(y_test, y_pred, zero_division=0))

    final_model = build_pipeline()
    final_model.fit(input_texts, generic_names)

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    dump(
        {
            "artifact_version": MODEL_ARTIFACT_VERSION,
            "pipeline": final_model,
            "exact_matches": exact_matches,
        },
        MODEL_PATH,
    )
    print(
        f"Saved trained drug name ML model to {MODEL_PATH} "
        f"with {len(exact_matches)} exact matches"
    )


if __name__ == "__main__":
    main()
