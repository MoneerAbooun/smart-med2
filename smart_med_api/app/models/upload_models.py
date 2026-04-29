from __future__ import annotations

from pydantic import BaseModel


class UploadedImageResponse(BaseModel):
    image_url: str
    relative_path: str
    content_type: str
