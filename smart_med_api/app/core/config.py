from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import dotenv_values, load_dotenv


@dataclass(frozen=True)
class Settings:
    firestore_users_collection: str
    firestore_drug_catalog_collection: str
    firestore_drug_interactions_collection: str
    upload_root_dir: Path
    upload_base_path: str
    upload_max_image_bytes: int


def _load_dotenv_file(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}

    parsed_values = dotenv_values(path)
    return {
        str(key): value
        for key, value in parsed_values.items()
        if key and value is not None
    }


def _setting_value(
    name: str,
    dotenv_values: dict[str, str],
    default: str | None = None,
) -> str | None:
    if name in os.environ:
        return os.environ[name]

    if name in dotenv_values:
        return dotenv_values[name]

    return default


def get_settings() -> Settings:
    project_root = Path(__file__).resolve().parents[2]
    default_upload_root = project_root / "uploads"
    dotenv_path = project_root / ".env"
    load_dotenv(dotenv_path, override=False)
    dotenv_file_values = _load_dotenv_file(dotenv_path)

    return Settings(
        firestore_users_collection=_setting_value(
            "FIRESTORE_USERS_COLLECTION",
            dotenv_file_values,
            "users",
        )
        or "users",
        firestore_drug_catalog_collection=_setting_value(
            "FIRESTORE_DRUG_CATALOG_COLLECTION",
            dotenv_file_values,
            "drug_catalog",
        )
        or "drug_catalog",
        firestore_drug_interactions_collection=_setting_value(
            "FIRESTORE_DRUG_INTERACTIONS_COLLECTION",
            dotenv_file_values,
            "drug_interactions",
        )
        or "drug_interactions",
        upload_root_dir=Path(
            _setting_value(
                "UPLOAD_ROOT_DIR",
                dotenv_file_values,
                str(default_upload_root),
            )
            or str(default_upload_root),
        ),
        upload_base_path=_setting_value(
            "UPLOAD_BASE_PATH",
            dotenv_file_values,
            "/uploads",
        )
        or "/uploads",
        upload_max_image_bytes=int(
            _setting_value(
                "UPLOAD_MAX_IMAGE_BYTES",
                dotenv_file_values,
                str(5 * 1024 * 1024),
            )
            or str(5 * 1024 * 1024),
        ),
    )
