"""
Train the risk scoring ML model using synthetic data.

Run: python -m app.ml.train_model
"""
import os
import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, roc_auc_score
import joblib

MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ml_model")
MODEL_PATH = os.path.join(MODEL_DIR, "risk_model.joblib")


def generate_synthetic_data(n_samples: int = 5000) -> pd.DataFrame:
    """
    Generate synthetic user data for training the risk model.

    Features:
        - transaction_count: Number of past transactions
        - avg_transaction_amount: Average transaction amount
        - kyc_tier: KYC verification level (0-3)
        - device_trust_score: Device trustworthiness (0-1)
        - days_since_registration: Account age in days
        - fraud_flags: Number of past fraud flags
        - total_spent: Total amount spent historically

    Target:
        - is_risky: 1 if user is risky, 0 if safe
    """
    np.random.seed(42)

    data = {
        "transaction_count": np.random.poisson(50, n_samples),
        "avg_transaction_amount": np.random.lognormal(5, 1, n_samples),
        "kyc_tier": np.random.choice([0, 1, 2, 3], n_samples, p=[0.05, 0.30, 0.40, 0.25]),
        "device_trust_score": np.clip(np.random.beta(5, 2, n_samples), 0, 1),
        "days_since_registration": np.random.exponential(180, n_samples).astype(int),
        "fraud_flags": np.random.choice([0, 0, 0, 0, 0, 1, 1, 2, 3], n_samples),
        "total_spent": np.random.lognormal(8, 1.5, n_samples),
    }

    df = pd.DataFrame(data)

    # Generate target based on logical rules with noise
    risk_score = (
        - 0.15 * df["kyc_tier"]               # Higher KYC = lower risk
        - 0.20 * df["device_trust_score"]      # Higher trust = lower risk
        - 0.10 * np.log1p(df["transaction_count"]) / 5  # More txns = trusted
        - 0.05 * np.log1p(df["days_since_registration"]) / 7  # Older account = trusted
        + 0.40 * df["fraud_flags"]             # Fraud flags = HIGH risk
        + 0.10 * (df["avg_transaction_amount"] > 500).astype(float)  # High amounts
        + np.random.normal(0, 0.15, n_samples)  # Noise
    )

    # Normalize to 0-1 and threshold
    risk_score = (risk_score - risk_score.min()) / (risk_score.max() - risk_score.min())
    df["is_risky"] = (risk_score > 0.55).astype(int)

    # Ensure ~25% are risky for realistic class distribution
    risky_pct = df["is_risky"].mean()
    print(f"Generated {n_samples} samples, {risky_pct:.1%} risky")

    return df


def train_model():
    """Train and save the risk scoring model."""
    print("Generating synthetic training data...")
    df = generate_synthetic_data(5000)

    feature_cols = [
        "transaction_count", "avg_transaction_amount", "kyc_tier",
        "device_trust_score", "days_since_registration", "fraud_flags",
        "total_spent",
    ]

    X = df[feature_cols].values
    y = df["is_risky"].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y,
    )

    print("Training Gradient Boosting Classifier...")
    model = GradientBoostingClassifier(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        subsample=0.8,
        random_state=42,
    )
    model.fit(X_train, y_train)

    # Evaluate
    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]

    print("\n=== Model Evaluation ===")
    print(classification_report(y_test, y_pred, target_names=["Safe", "Risky"]))
    print(f"ROC AUC Score: {roc_auc_score(y_test, y_proba):.4f}")

    # Feature importances
    print("\n=== Feature Importances ===")
    for name, imp in sorted(
        zip(feature_cols, model.feature_importances_),
        key=lambda x: -x[1],
    ):
        print(f"  {name:30s}: {imp:.4f}")

    # Save model
    os.makedirs(MODEL_DIR, exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    print(f"\nModel saved to {MODEL_PATH}")

    return model


if __name__ == "__main__":
    train_model()
