from pathlib import Path
from uuid import uuid4

from app.core.config import _load_dotenv_file, _setting_value


def test_load_dotenv_file_parses_comments_and_quotes():
    dotenv_path = Path(__file__).resolve().parent / f".tmp-config-{uuid4().hex}.env"
    try:
        dotenv_path.write_text(
            "\n".join(
                [
                    "# comment",
                    "FIRESTORE_USERS_COLLECTION='users'",
                    'UPLOAD_BASE_PATH="/uploads"',
                ]
            ),
            encoding="utf-8",
        )

        values = _load_dotenv_file(dotenv_path)

        assert values["FIRESTORE_USERS_COLLECTION"] == "users"
        assert values["UPLOAD_BASE_PATH"] == "/uploads"
    finally:
        dotenv_path.unlink(missing_ok=True)


def test_setting_value_prefers_process_environment(monkeypatch):
    monkeypatch.setenv("UPLOAD_BASE_PATH", "/from-env")

    assert (
        _setting_value(
            "UPLOAD_BASE_PATH",
            {"UPLOAD_BASE_PATH": "/from-dotenv"},
            "fallback",
        )
        == "/from-env"
    )
