import os
import base64
from nacl.signing import SigningKey, VerifyKey

# JWT Settings
SECRET_KEY = os.getenv("SECRET_KEY", "hackathon-offline-pay-secret-2024")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

# Database
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./offline_pay.db")

# Ed25519 Key Management
KEYS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "keys")
PRIVATE_KEY_FILE = os.path.join(KEYS_DIR, "ed25519.key")
PUBLIC_KEY_FILE = os.path.join(KEYS_DIR, "ed25519.pub")


def load_or_create_signing_keys():
    """Load existing Ed25519 keys or generate new ones."""
    os.makedirs(KEYS_DIR, exist_ok=True)

    if os.path.exists(PRIVATE_KEY_FILE):
        with open(PRIVATE_KEY_FILE, "rb") as f:
            signing_key = SigningKey(f.read())
    else:
        signing_key = SigningKey.generate()
        with open(PRIVATE_KEY_FILE, "wb") as f:
            f.write(bytes(signing_key))
        with open(PUBLIC_KEY_FILE, "wb") as f:
            f.write(bytes(signing_key.verify_key))

    return signing_key


SIGNING_KEY = load_or_create_signing_keys()
VERIFY_KEY = SIGNING_KEY.verify_key
PUBLIC_KEY_HEX = VERIFY_KEY.encode().hex()

# Offline Limits
MAX_OFFLINE_LIMIT = 5000.0
MIN_OFFLINE_LIMIT = 100.0
DEFAULT_TOKEN_EXPIRY_HOURS = 24
MAX_TOKENS_PER_REQUEST = 10
TOKEN_DENOMINATIONS = [50.0, 100.0, 200.0, 500.0, 1000.0]

# ML Model
ML_MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ml_model")
ML_MODEL_PATH = os.path.join(ML_MODEL_DIR, "risk_model.joblib")
