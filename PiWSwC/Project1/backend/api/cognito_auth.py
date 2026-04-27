import json
import os
import time
import logging
from typing import Optional, Dict, Any

import jwt
import requests
from jwt.algorithms import RSAAlgorithm

logger = logging.getLogger(__name__)

JWKS_CACHE: Dict[str, Any] = {"expires_at": 0, "jwks": None}


def _get_jwks(issuer: str) -> dict:
    now = int(time.time())
    if JWKS_CACHE["jwks"] is not None and now < JWKS_CACHE["expires_at"]:
        return JWKS_CACHE["jwks"]

    try:
        url = issuer.rstrip("/") + "/.well-known/jwks.json"
        r = requests.get(url, timeout=5)
        r.raise_for_status()
        jwks = r.json()
        JWKS_CACHE["jwks"] = jwks
        JWKS_CACHE["expires_at"] = now + 3600
        return jwks
    except Exception as e:
        logger.error(f"JWKS fetch failed: {e}")
        return {"keys": []}


def verify_cognito_jwt(token: str) -> Optional[dict]:
    """
    Weryfikuje token. Jeśli jest zły, wygasł lub brakuje konfigu - zwraca None zamiast rzucać błędem.
    """
    issuer = os.environ.get("COGNITO_ISSUER")
    app_client_id = os.environ.get("COGNITO_APP_CLIENT_ID")

    if not issuer or not app_client_id:
        logger.error("Missing COGNITO_ISSUER or COGNITO_APP_CLIENT_ID")
        return None

    try:
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")

        jwks = _get_jwks(issuer)
        key_dict = next((k for k in jwks.get("keys", []) if k.get("kid") == kid), None)

        if not key_dict:
            return None

        public_key = RSAAlgorithm.from_jwk(json.dumps(key_dict))

        # Próbujemy pełnej weryfikacji
        unverified_payload = jwt.decode(token, options={"verify_signature": False})
        token_use = unverified_payload.get("token_use")

        decode_params = {
            "key": public_key,
            "algorithms": ["RS256"],
            "issuer": issuer,
        }

        if token_use == "access":
            payload = jwt.decode(token, options={"verify_aud": False}, **decode_params)
            if payload.get("client_id") != app_client_id:
                return None
        else:
            payload = jwt.decode(token, audience=app_client_id, **decode_params)

        return payload
    except Exception as e:
        logger.warning(f"Token verification failed: {e}")
        return None


def get_payload_from_request(request) -> Optional[dict]:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None

    token = auth.split(" ", 1)[1].strip()
    if not token:
        return None

    return verify_cognito_jwt(token)


def get_sender_from_request(request) -> Optional[str]:
    payload = get_payload_from_request(request)
    if not payload:
        return None
    return payload.get("email") or payload.get("username") or payload.get("sub")