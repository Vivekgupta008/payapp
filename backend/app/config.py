import os
import base64
from nacl.signing import SigningKey

# JWT 
SECRET_KEY = os.getenv("SECRET_KEY", "hackathon-offline-pay-secret-2024")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

# Database 
# Render injects DATABASE_URL as postgres://...  SQLAlchemy needs postgresql://
_raw_db_url = os.getenv("DATABASE_URL", "sqlite:///./offline_pay.db")
DATABASE_URL = _raw_db_url.replace("postgres://", "postgresql://", 1)

# Ed25519 Key Management 
# On Render the filesystem is ephemeral, so keys are stored as env vars
# (base64-encoded raw bytes). Falls back to file-based for local dev.

def load_or_create_signing_keys() -> SigningKey:
    # 1. Try env var (production on Render)
    key_b64 = os.getenv("ED25519_PRIVATE_KEY_B64")
    if key_b64:
        return SigningKey(base64.b64decode(key_b64))

    # 2. Try local key file (development)
    keys_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "keys")
    key_file = os.path.join(keys_dir, "ed25519.key")
    if os.path.exists(key_file):
        with open(key_file, "rb") as f:
            return SigningKey(f.read())

    # 3. Generate fresh keys (first run / ephemeral env without env var set)
    signing_key = SigningKey.generate()
    os.makedirs(keys_dir, exist_ok=True)
    with open(key_file, "wb") as f:
        f.write(bytes(signing_key))
    pub_file = os.path.join(keys_dir, "ed25519.pub")
    with open(pub_file, "wb") as f:
        f.write(bytes(signing_key.verify_key))

    # Print the base64 value so the operator can paste it into Render env vars
    print("=== NEW ED25519 KEY GENERATED ===")
    print("Set this as ED25519_PRIVATE_KEY_B64 in your Render env vars:")
    print(base64.b64encode(bytes(signing_key)).decode())
    print("=================================")
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
