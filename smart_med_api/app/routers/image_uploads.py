from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status

from app.core.config import get_settings
from app.models.upload_models import UploadedImageResponse
from app.services.firebase_admin_service import VerifiedFirebaseUser, verify_firebase_user

router = APIRouter(tags=["image-uploads"])

settings = get_settings()

_ALLOWED_IMAGE_CONTENT_TYPES = {
    "image/heic": "heic",
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}
_ALLOWED_IMAGE_EXTENSIONS = {"heic", "jpeg", "jpg", "png", "webp"}


@router.post(
    "/api/uploads/profile-image",
    response_model=UploadedImageResponse,
)
async def upload_profile_image(
    request: Request,
    image: UploadFile = File(...),
    user: VerifiedFirebaseUser = Depends(verify_firebase_user),
) -> UploadedImageResponse:
    return await _store_image(
        request=request,
        image=image,
        user=user,
        category="profiles",
    )


@router.post(
    "/api/uploads/medication-image",
    response_model=UploadedImageResponse,
)
async def upload_medication_image(
    request: Request,
    image: UploadFile = File(...),
    user: VerifiedFirebaseUser = Depends(verify_firebase_user),
) -> UploadedImageResponse:
    return await _store_image(
        request=request,
        image=image,
        user=user,
        category="medications",
    )


async def _store_image(
    *,
    request: Request,
    image: UploadFile,
    user: VerifiedFirebaseUser,
    category: Literal["medications", "profiles"],
) -> UploadedImageResponse:
    file_name = image.filename or ""
    content_type = (image.content_type or "").strip().lower()
    extension = _normalized_extension(file_name, content_type)

    if extension is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPG, PNG, WEBP, and HEIC images are supported.",
        )

    try:
        file_bytes = await image.read()
    finally:
        await image.close()

    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The uploaded image is empty.",
        )

    if len(file_bytes) > settings.upload_max_image_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image is too large. Maximum allowed size is {settings.upload_max_image_bytes // (1024 * 1024)} MB.",
        )

    timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S%f")
    stored_file_name = f"{timestamp}_{uuid4().hex}.{extension}"
    relative_path = Path(category) / user.uid / stored_file_name
    destination = settings.upload_root_dir / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(file_bytes)

    return UploadedImageResponse(
        image_url=str(request.url_for("uploads", path=relative_path.as_posix())),
        relative_path=relative_path.as_posix(),
        content_type=_normalized_content_type(content_type, extension),
    )


def _normalized_extension(file_name: str, content_type: str) -> str | None:
    suffix = Path(file_name).suffix.lower().lstrip(".")
    if suffix in _ALLOWED_IMAGE_EXTENSIONS:
        return "jpg" if suffix == "jpeg" else suffix

    if content_type in _ALLOWED_IMAGE_CONTENT_TYPES:
        return _ALLOWED_IMAGE_CONTENT_TYPES[content_type]

    return None


def _normalized_content_type(content_type: str, extension: str) -> str:
    if content_type in _ALLOWED_IMAGE_CONTENT_TYPES:
        return content_type

    return {
        "heic": "image/heic",
        "jpg": "image/jpeg",
        "png": "image/png",
        "webp": "image/webp",
    }[extension]
