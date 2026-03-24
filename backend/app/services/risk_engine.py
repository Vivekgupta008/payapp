import os
import numpy as np
from ..config import ML_MODEL_PATH, MAX_OFFLINE_LIMIT, MIN_OFFLINE_LIMIT

# Try to load the trained model; fall back to heuristic if not available
_model = None


def _load_model():
    global _model
    if _model is None and os.path.exists(ML_MODEL_PATH):
        try:
            import joblib
            _model = joblib.load(ML_MODEL_PATH)
        except Exception as e:
            print(f"Warning: Could not load ML model: {e}")
    return _model


def compute_risk_score(user_features: dict) -> tuple:
    """
    Compute a risk score for a user.

    Features expected:
        - transaction_count: int
        - avg_transaction_amount: float
        - kyc_tier: int (0-3)
        - device_trust_score: float (0-1)
        - days_since_registration: int
        - fraud_flags: int
        - total_spent: float

    Returns: (risk_score: float, risk_factors: dict)
    """
    model = _load_model()

    features = np.array([[
        user_features.get("transaction_count", 0),
        user_features.get("avg_transaction_amount", 0),
        user_features.get("kyc_tier", 1),
        user_features.get("device_trust_score", 0.5),
        user_features.get("days_since_registration", 0),
        user_features.get("fraud_flags", 0),
        user_features.get("total_spent", 0),
    ]])

    risk_factors = {}

    if model is not None:
        # Use ML model
        try:
            risk_score = float(model.predict_proba(features)[0][1])
            # Get feature importances for explainability
            feature_names = [
                "transaction_count", "avg_transaction_amount", "kyc_tier",
                "device_trust_score", "days_since_registration", "fraud_flags",
                "total_spent",
            ]
            if hasattr(model, "feature_importances_"):
                importances = model.feature_importances_
                for name, imp in zip(feature_names, importances):
                    risk_factors[name] = round(float(imp), 4)
        except Exception:
            risk_score = _heuristic_risk_score(user_features, risk_factors)
    else:
        # Fallback: heuristic model
        risk_score = _heuristic_risk_score(user_features, risk_factors)

    return round(risk_score, 4), risk_factors


def _heuristic_risk_score(features: dict, risk_factors: dict) -> float:
    """Simple heuristic risk scoring when ML model is unavailable."""
    score = 0.5  # Base risk

    # KYC tier reduces risk
    kyc = features.get("kyc_tier", 1)
    kyc_adjustment = (3 - kyc) * 0.1
    score += kyc_adjustment
    risk_factors["kyc_tier"] = round(-kyc_adjustment, 4)

    # Device trust reduces risk
    trust = features.get("device_trust_score", 0.5)
    trust_adjustment = (0.5 - trust) * 0.2
    score += trust_adjustment
    risk_factors["device_trust_score"] = round(-trust_adjustment, 4)

    # More transactions = more trusted
    tx_count = features.get("transaction_count", 0)
    tx_adjustment = min(tx_count / 100, 0.15)
    score -= tx_adjustment
    risk_factors["transaction_count"] = round(-tx_adjustment, 4)

    # Days since registration
    days = features.get("days_since_registration", 0)
    days_adjustment = min(days / 365, 0.1)
    score -= days_adjustment
    risk_factors["days_since_registration"] = round(-days_adjustment, 4)

    # Fraud flags increase risk significantly
    fraud = features.get("fraud_flags", 0)
    fraud_adjustment = fraud * 0.25
    score += fraud_adjustment
    risk_factors["fraud_flags"] = round(fraud_adjustment, 4)

    return max(0.0, min(1.0, score))


def compute_offline_limit(risk_score: float) -> float:
    """Map a risk score to an offline spending limit."""
    if risk_score >= 0.9:
        return 0.0  # Denied
    elif risk_score >= 0.8:
        return MIN_OFFLINE_LIMIT  # 100
    elif risk_score >= 0.6:
        return 500.0
    elif risk_score >= 0.4:
        return 1500.0
    elif risk_score >= 0.2:
        return 3000.0
    else:
        return MAX_OFFLINE_LIMIT  # 5000


def get_risk_level(risk_score: float) -> str:
    """Get human-readable risk level."""
    if risk_score < 0.2:
        return "very_low"
    elif risk_score < 0.4:
        return "low"
    elif risk_score < 0.6:
        return "medium"
    elif risk_score < 0.8:
        return "high"
    else:
        return "very_high"
