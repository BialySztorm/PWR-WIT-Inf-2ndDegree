import json
import os
import time
from typing import Optional, Dict, Any

import jwt  # PyJWT
import requests
from jwt.algorithms import RSAAlgorithm

JWKS_CACHE: Dict[str, Any] = {"expires_at": 0, "jwks": None}

def _get_jwks(issuer: str) -> dict:
    now = int(time.time())
    if JWKS_CACHE["jwks"] is not None and now < JWKS_CACHE["expires_at"]:
        return JWKS_CACHE["jwks"]

    url = issuer.rstrip("/") + "/.well-known/jwks.json"
    r = requests.get(url, timeout=10)
    r.raise_for_status()
    jwks = r.json()

    JWKS_CACHE["jwks"] = jwks
    JWKS_CACHE["expires_at"] = now + 6 * 60 * 60
    return jwks

def verify_cognito_jwt(token: str) -> dict:
    issuer = os.environ.get("COGNITO_ISSUER")
    app_client_id = os.environ.get("COGNITO_APP_CLIENT_ID")

    if not issuer or not app_client_id:
        raise RuntimeError("Missing COGNITO_ISSUER or COGNITO_APP_CLIENT_ID env vars")

    unverified_header = jwt.get_unverified_header(token)
    kid = unverified_header.get("kid")
    if not kid:
        raise jwt.InvalidTokenError("Missing kid in token header")

    jwks = _get_jwks(issuer)
    key_dict = next((k for k in jwks.get("keys", []) if k.get("kid") == kid), None)
    if not key_dict:
        raise jwt.InvalidTokenError("Public key not found in JWKS")

    public_key = RSAAlgorithm.from_jwk(json.dumps(key_dict))

    # Najpierw decode bez aud, żeby zobaczyć token_use i dobrać walidację
    unverified_payload = jwt.decode(
        token,
        options={"verify_signature": False, "verify_exp": False},
    )
    token_use = unverified_payload.get("token_use")  # "access" albo "id"

    common_kwargs = dict(
        key=public_key,
        algorithms=["RS256"],
        issuer=issuer,
        options={"require": ["exp", "iat", "iss"]},
    )

    if token_use == "id":
        # ID token powinien mieć aud == client_id
        payload = jwt.decode(
            token,
            audience=app_client_id,
            **common_kwargs,
        )
        return payload

    if token_use == "access":
        # Access token często NIE ma 'aud' – zamiast tego ma 'client_id'
        payload = jwt.decode(
            token,
            options={"require": ["exp", "iat", "iss", "token_use"]},
            issuer=issuer,
            key=public_key,
            algorithms=["RS256"],
        )
        if payload.get("client_id") != app_client_id:
            raise jwt.InvalidTokenError("Invalid client_id in access token")
        return payload

    # fallback: spróbuj jak id_token
    payload = jwt.decode(
        token,
        audience=app_client_id,
        **common_kwargs,
    )
    return payload

def get_sender_from_request(request) -> Optional[str]:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None

    token = auth.split(" ", 1)[1].strip()
    if not token:
        return None

    payload = verify_cognito_jwt(token)

    # sender:
    return payload.get("email") or payload.get("cognito:username") or payload.get("username") or payload.get("sub")

def get_payload_from_request(request) -> Optional[dict]:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth.split(" ", 1)[1].strip()
    if not token:
        return None
    return verify_cognito_jwt(token)