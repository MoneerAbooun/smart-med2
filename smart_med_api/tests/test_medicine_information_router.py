from fastapi.testclient import TestClient

from app.main import app
from app.models.medicine_models import MedicineInformationResponse
from app.routers import medicine_information as medicine_information_router


def test_get_medicine_information_route(monkeypatch):
    async def fake_lookup_medicine_information(*, query: str, **_: object):
        assert query == "ibuprofen"
        return MedicineInformationResponse(
            query="ibuprofen",
            search_mode="name",
            medicine_name="Ibuprofen",
            generic_name="ibuprofen",
            used_for=["Pain relief"],
            dose=["200 mg every 4 to 6 hours"],
            warnings=["Avoid if allergic to NSAIDs."],
            side_effects=["Upset stomach"],
            interactions=["May interact with anticoagulants."],
            storage=["Store at room temperature."],
            disclaimer=["Talk to a clinician for personal advice."],
        )

    monkeypatch.setattr(
        medicine_information_router,
        "lookup_medicine_information",
        fake_lookup_medicine_information,
    )

    client = TestClient(app)
    response = client.get("/medicine-information", params={"name": "ibuprofen"})

    assert response.status_code == 200
    assert response.json()["medicine_name"] == "Ibuprofen"
    assert response.json()["generic_name"] == "ibuprofen"
