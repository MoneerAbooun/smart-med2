from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.core.config import get_settings
from app.routers.drug_alternatives import router as drug_alternatives_router
from app.routers.drug_details import router as drug_details_router
from app.routers.drug_interaction import router as drug_interaction_router
from app.routers.image_uploads import router as image_uploads_router
from app.routers.medicine_information import router as medicine_information_router

settings = get_settings()
settings.upload_root_dir.mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title="Smart Med API",
    version="0.4.0",
    description="Drug details and interaction backend for Smart Med.",
)

app.mount(
    settings.upload_base_path,
    StaticFiles(directory=settings.upload_root_dir),
    name="uploads",
)

app.include_router(drug_alternatives_router)
app.include_router(drug_details_router)
app.include_router(drug_interaction_router)
app.include_router(image_uploads_router)
app.include_router(medicine_information_router)


@app.get("/")
async def root() -> dict[str, str]:
    return {"message": "Smart Med API is running"}
