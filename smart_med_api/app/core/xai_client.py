from __future__ import annotations

import os
from typing import Any

import httpx
from fastapi import HTTPException, status
from openai import OpenAI

from app.core.config import get_settings

_MISSING_XAI_API_KEY_DETAIL = (
    "XAI_API_KEY is not configured on the API server. "
    "Set it in smart_med_api/.env or the server environment, then restart the API."
)


def get_xai_client() -> OpenAI:
    settings = get_settings()
    api_key = os.getenv("XAI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=_MISSING_XAI_API_KEY_DETAIL,
        )

    return OpenAI(
        api_key=api_key,
        base_url=settings.xai_base_url,
        timeout=httpx.Timeout(settings.xai_timeout_seconds),
    )


def response_output_text(response: Any) -> str | None:
    direct_output_text = getattr(response, "output_text", None)
    if isinstance(direct_output_text, str) and direct_output_text.strip():
        return direct_output_text

    if hasattr(response, "model_dump"):
        payload = response.model_dump()
    elif isinstance(response, dict):
        payload = response
    else:
        payload = {}

    direct_output_text = payload.get("output_text")
    if isinstance(direct_output_text, str) and direct_output_text.strip():
        return direct_output_text

    for item in payload.get("output", []):
        if not isinstance(item, dict):
            continue
        for content_item in item.get("content", []):
            if not isinstance(content_item, dict):
                continue

            text = content_item.get("text")
            if isinstance(text, str) and text.strip():
                return text

    return None
