import os
import numpy as np

_model = None
_MODEL_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "ml_model",
    "risk_model.joblib",
)


def load_model():
    """Load the trained risk model."""
    global _model
    if _model is None and os.path.exists(_MODEL_PATH):
        try:
            import joblib
            _model = joblib.load(_MODEL_PATH)
            print("ML risk model loaded successfully.")
        except Exception as e:
            print(f"Warning: Could not load ML model: {e}")
    return _model


def predict_risk(features: np.ndarray) -> float:
    """
    Predict risk score for given features.

    Features (7-dimensional):
        [transaction_count, avg_transaction_amount, kyc_tier,
         device_trust_score, days_since_registration, fraud_flags,
         total_spent]

    Returns: risk probability (0.0 = safe, 1.0 = risky)
    """
    model = load_model()
    if model is None:
        return 0.5  # Default risk score if model is unavailable

    try:
        if features.ndim == 1:
            features = features.reshape(1, -1)
        proba = model.predict_proba(features)
        return float(proba[0][1])
    except Exception:
        return 0.5


def get_feature_importance() -> dict:
    """Get feature importance from the trained model."""
    model = load_model()
    if model is None:
        return {}

    feature_names = [
        "transaction_count",
        "avg_transaction_amount",
        "kyc_tier",
        "device_trust_score",
        "days_since_registration",
        "fraud_flags",
        "total_spent",
    ]

    try:
        importances = model.feature_importances_
        return {name: round(float(imp), 4) for name, imp in zip(feature_names, importances)}
    except Exception:
        return {}
