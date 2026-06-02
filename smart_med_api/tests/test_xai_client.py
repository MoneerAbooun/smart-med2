from fastapi import HTTPException
import pytest

from app.core.xai_client import get_xai_client, response_output_text


def test_get_xai_client_requires_xai_api_key(monkeypatch):
    monkeypatch.setattr("app.core.xai_client.os.getenv", lambda name: None)

    with pytest.raises(HTTPException) as exc:
        get_xai_client()

    assert exc.value.status_code == 500
    assert "XAI_API_KEY" in exc.value.detail


def test_response_output_text_reads_sdk_model_dump():
    class FakeResponse:
        def model_dump(self) -> dict[str, object]:
            return {
                "output": [
                    {
                        "content": [
                            {
                                "type": "output_text",
                                "text": "{\"ok\":true}",
                            }
                        ]
                    }
                ]
            }

    assert response_output_text(FakeResponse()) == "{\"ok\":true}"
