from fastapi.testclient import TestClient

from app.api.routes import ml_routes
from app.main import app


def test_predict_drug_name_route(monkeypatch):
    def fake_predict_generic_name(input_text: str):
        assert input_text == "advil"
        return {
            "input_text": input_text,
            "predicted_generic_name": "ibuprofen",
            "confidence": 0.91,
        }

    monkeypatch.setattr(ml_routes, "predict_generic_name", fake_predict_generic_name)

    client = TestClient(app)
    response = client.post("/ml/predict-drug-name", json={"input_text": "advil"})

    assert response.status_code == 200
    assert response.json() == {
        "input_text": "advil",
        "predicted_generic_name": "ibuprofen",
        "confidence": 0.91,
    }
