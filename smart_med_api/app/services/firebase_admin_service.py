from __future__ import annotations

import json
import os
import threading
from dataclasses import dataclass
from typing import Any

import firebase_admin
from fastapi import Header, HTTPException, status
from firebase_admin import auth, credentials, firestore


@dataclass(frozen=True)
class VerifiedFirebaseUser:
    uid: str
    email: str | None = None


_initialize_lock = threading.Lock()


def _service_account_info_from_env() -> dict[str, Any] | None:
    raw_value = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    if not raw_value:
        return None

    try:
        parsed_value = json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            "FIREBASE_SERVICE_ACCOUNT_JSON must contain valid JSON."
        ) from exc

    if not isinstance(parsed_value, dict):
        raise RuntimeError(
            "FIREBASE_SERVICE_ACCOUNT_JSON must contain a JSON object."
        )

    return parsed_value


def _ensure_initialized() -> None:
    try:
        firebase_admin.get_app()
        return
    except ValueError:
        pass

    with _initialize_lock:
        try:
            firebase_admin.get_app()
            return
        except ValueError:
            pass

        service_account_info = _service_account_info_from_env()
        service_account_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

        try:
            if service_account_info is not None:
                cred = credentials.Certificate(service_account_info)
                firebase_admin.initialize_app(cred)
            elif service_account_path:
                cred = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(cred)
            else:
                firebase_admin.initialize_app()
        except ValueError as exc:
            if "already exists" in str(exc).lower():
                return
            raise RuntimeError(
                "Firebase Admin initialization failed. "
                "Check FIREBASE_SERVICE_ACCOUNT_JSON or "
                "GOOGLE_APPLICATION_CREDENTIALS."
            ) from exc
        except Exception as exc:
            raise RuntimeError(
                "Firebase Admin initialization failed. "
                "Check FIREBASE_SERVICE_ACCOUNT_JSON or "
                "GOOGLE_APPLICATION_CREDENTIALS."
            ) from exc


def get_firestore_client() -> firestore.Client:
    _ensure_initialized()
    return firestore.client()


def verify_firebase_user(
    authorization: str | None = Header(default=None),
) -> VerifiedFirebaseUser:
    if authorization is None or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Firebase bearer token.",
        )

    token = authorization.split(" ", 1)[1].strip()

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Firebase bearer token.",
        )

    _ensure_initialized()

    try:
        decoded_token = auth.verify_id_token(token)
    except Exception as exc:
        print("Firebase token verification failed:", exc)

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token.",
        ) from exc

    return VerifiedFirebaseUser(
        uid=str(decoded_token["uid"]),
        email=decoded_token.get("email"),
    )
