from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from ..models import Transaction, TransactionStatus, User


def check_fraud_signals(
    db: Session,
    sender_id: str,
    amount: float,
    token_nonce: str,
) -> tuple:
    """
    Check for fraud signals in a transaction.
    Returns (is_suspicious: bool, reasons: list[str]).
    """
    reasons = []

    # 1. Check for duplicate nonce (replay attack)
    existing = db.query(Transaction).filter(
        Transaction.nonce == token_nonce,
        Transaction.status != TransactionStatus.FAILED,
    ).first()
    if existing:
        reasons.append("Duplicate nonce detected (potential replay attack)")
        return True, reasons

    # 2. Check velocity - too many transactions in short period
    one_hour_ago = datetime.utcnow() - timedelta(hours=1)
    recent_count = db.query(Transaction).filter(
        Transaction.sender_id == sender_id,
        Transaction.created_at >= one_hour_ago,
    ).count()
    if recent_count > 20:
        reasons.append(f"Velocity check failed: {recent_count} transactions in last hour")

    # 3. Check if amount exceeds typical pattern
    user = db.query(User).filter(User.id == sender_id).first()
    if user:
        if user.avg_transaction_amount > 0 and amount > user.avg_transaction_amount * 5:
            reasons.append(f"Amount {amount} significantly exceeds average {user.avg_transaction_amount}")

        # 4. Check if user has fraud flags
        if user.fraud_flags > 2:
            reasons.append(f"User has {user.fraud_flags} fraud flags")

        # 5. Check if offline limit would be exceeded
        if user.offline_limit_used + amount > user.offline_limit * 1.1:  # 10% buffer
            reasons.append("Transaction would exceed offline limit")

    # 6. Suspicious amount patterns (round numbers, max amounts)
    if amount > 4500:
        reasons.append("High-value offline transaction")

    is_suspicious = len(reasons) >= 2  # Flag if multiple signals
    return is_suspicious, reasons


def flag_user_for_fraud(db: Session, user_id: str, reason: str):
    """Increment fraud flags for a user."""
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.fraud_flags += 1
        db.commit()
