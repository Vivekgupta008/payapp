import json
import uuid
from datetime import datetime, timedelta
from nacl.signing import SigningKey
from nacl.encoding import HexEncoder
from ..config import SIGNING_KEY, VERIFY_KEY, DEFAULT_TOKEN_EXPIRY_HOURS, TOKEN_DENOMINATIONS


def sign_token_payload(payload: dict) -> str:
    """Sign a token payload with Ed25519 and return hex-encoded signature."""
    payload_bytes = json.dumps(payload, sort_keys=True).encode("utf-8")
    signed = SIGNING_KEY.sign(payload_bytes)
    return signed.signature.hex()


def verify_token_signature(payload: dict, signature_hex: str) -> bool:
    """Verify an Ed25519 signature against a token payload."""
    try:
        payload_bytes = json.dumps(payload, sort_keys=True).encode("utf-8")
        signature_bytes = bytes.fromhex(signature_hex)
        VERIFY_KEY.verify(payload_bytes, signature_bytes)
        return True
    except Exception:
        return False


def generate_offline_tokens(user_id: str, total_limit: float, max_tokens: int = 10) -> list:
    """
    Generate a set of offline payment tokens for a user.
    Tokens are created in standard denominations to fill the limit.
    """
    tokens = []
    remaining = total_limit
    denominations = sorted(TOKEN_DENOMINATIONS, reverse=True)

    while remaining > 0 and len(tokens) < max_tokens:
        # Find the largest denomination that fits
        denomination = None
        for d in denominations:
            if d <= remaining:
                denomination = d
                break

        if denomination is None:
            # Remaining amount is less than smallest denomination
            if remaining >= 10:  # Minimum token value
                denomination = remaining
            else:
                break

        token_id = str(uuid.uuid4())
        nonce = uuid.uuid4().hex
        now = datetime.utcnow()
        expires = now + timedelta(hours=DEFAULT_TOKEN_EXPIRY_HOURS)

        payload = {
            "token_id": token_id,
            "user_id": user_id,
            "amount": denomination,
            "issued_at": now.isoformat(),
            "expires_at": expires.isoformat(),
            "nonce": nonce,
        }

        signature = sign_token_payload(payload)

        token_data = {
            **payload,
            "signature": signature,
        }

        tokens.append(token_data)
        remaining -= denomination

    return tokens


def is_token_expired(expires_at_str: str) -> bool:
    """Check if a token has expired."""
    try:
        expires_at = datetime.fromisoformat(expires_at_str)
        return datetime.utcnow() > expires_at
    except Exception:
        return True


def validate_token_for_payment(token_data: dict) -> tuple:
    """
    Validate a token for payment use.
    Returns (is_valid, error_message).
    """
    required_fields = ["token_id", "user_id", "amount", "issued_at", "expires_at", "nonce", "signature"]
    for field in required_fields:
        if field not in token_data:
            return False, f"Missing field: {field}"

    # Check expiry
    if is_token_expired(token_data["expires_at"]):
        return False, "Token has expired"

    # Verify signature
    signature = token_data.pop("signature", None)
    if not signature:
        return False, "No signature"

    payload = {k: v for k, v in token_data.items() if k != "signature"}
    if not verify_token_signature(payload, signature):
        return False, "Invalid signature"

    token_data["signature"] = signature  # Restore
    return True, "Valid"
