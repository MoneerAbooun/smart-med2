import pytest

from app.services.firebase_admin_service import _service_account_info_from_env


def test_service_account_info_from_env_returns_parsed_json(monkeypatch):
    monkeypatch.setenv(
        "FIREBASE_SERVICE_ACCOUNT_JSON",
        '{"type":"service_account","project_id":"smart-med"}',
    )

    assert _service_account_info_from_env() == {
        "type": "service_account",
        "project_id": "smart-med",
    }


def test_service_account_info_from_env_rejects_invalid_json(monkeypatch):
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", "not-json")

    with pytest.raises(RuntimeError, match="must contain valid JSON"):
        _service_account_info_from_env()


def test_service_account_info_from_env_is_optional(monkeypatch):
    monkeypatch.delenv("FIREBASE_SERVICE_ACCOUNT_JSON", raising=False)

    assert _service_account_info_from_env() is None
