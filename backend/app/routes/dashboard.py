from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from ..database import get_db
from ..models import User, Transaction, TransactionStatus, OfflineToken, TokenStatus
from ..schemas import (
    UserResponse, UserDashboard, MerchantDashboard, TransactionItem,
)
from ..auth import get_current_user

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])


def _user_response(user: User) -> UserResponse:
    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        phone=user.phone,
        role=user.role.value,
        kyc_tier=user.kyc_tier,
        balance=user.balance,
        offline_limit=user.offline_limit,
        offline_limit_used=user.offline_limit_used,
        device_trust_score=user.device_trust_score,
        is_active=user.is_active,
        created_at=user.created_at,
    )


def _tx_to_item(tx: Transaction, user_id: str, db: Session) -> TransactionItem:
    if tx.sender_id == user_id:
        # Outgoing
        counterparty = tx.merchant_name
        if not counterparty and tx.receiver_id:
            receiver = db.query(User).filter(User.id == tx.receiver_id).first()
            counterparty = receiver.full_name if receiver else "Unknown"
    else:
        # Incoming
        sender = db.query(User).filter(User.id == tx.sender_id).first()
        counterparty = sender.full_name if sender else "Unknown"

    return TransactionItem(
        id=tx.id,
        token_id=tx.token_id,
        amount=tx.amount,
        status=tx.status.value,
        counterparty_name=counterparty,
        created_at=tx.created_at,
        settled_at=tx.settled_at,
    )


@router.get("/user", response_model=UserDashboard)
def get_user_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the user dashboard with balance, transactions, and token info."""
    # Recent transactions (sent)
    recent_txs = db.query(Transaction).filter(
        Transaction.sender_id == current_user.id,
    ).order_by(Transaction.created_at.desc()).limit(20).all()

    # Active tokens count
    active_tokens = db.query(OfflineToken).filter(
        OfflineToken.user_id == current_user.id,
        OfflineToken.status == TokenStatus.ACTIVE,
    ).count()

    # Total spent
    total_spent = db.query(func.sum(Transaction.amount)).filter(
        Transaction.sender_id == current_user.id,
        Transaction.status == TransactionStatus.SETTLED,
    ).scalar() or 0.0

    # Total offline spent
    total_offline = db.query(func.sum(Transaction.amount)).filter(
        Transaction.sender_id == current_user.id,
        Transaction.status.in_([
            TransactionStatus.SETTLED,
            TransactionStatus.SYNCED,
            TransactionStatus.PENDING_OFFLINE,
        ]),
    ).scalar() or 0.0

    return UserDashboard(
        user=_user_response(current_user),
        recent_transactions=[_tx_to_item(tx, current_user.id, db) for tx in recent_txs],
        active_tokens_count=active_tokens,
        offline_limit_remaining=max(0, current_user.offline_limit - current_user.offline_limit_used),
        total_spent=total_spent,
        total_offline_spent=total_offline,
    )


@router.get("/merchant", response_model=MerchantDashboard)
def get_merchant_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the merchant dashboard with received payments and settlement info."""
    if current_user.role.value != "merchant":
        raise HTTPException(status_code=403, detail="Merchant access only")

    # Recent received transactions
    recent_txs = db.query(Transaction).filter(
        Transaction.receiver_id == current_user.id,
    ).order_by(Transaction.created_at.desc()).limit(20).all()

    # Pending settlement
    pending_txs = db.query(Transaction).filter(
        Transaction.receiver_id == current_user.id,
        Transaction.status.in_([
            TransactionStatus.PENDING_OFFLINE,
            TransactionStatus.SYNCED,
        ]),
    ).all()

    pending_amount = sum(tx.amount for tx in pending_txs)

    # Total received (settled)
    total_received = db.query(func.sum(Transaction.amount)).filter(
        Transaction.receiver_id == current_user.id,
        Transaction.status == TransactionStatus.SETTLED,
    ).scalar() or 0.0

    # Today's received
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    today_received = db.query(func.sum(Transaction.amount)).filter(
        Transaction.receiver_id == current_user.id,
        Transaction.status == TransactionStatus.SETTLED,
        Transaction.settled_at >= today_start,
    ).scalar() or 0.0

    return MerchantDashboard(
        user=_user_response(current_user),
        recent_transactions=[_tx_to_item(tx, current_user.id, db) for tx in recent_txs],
        pending_settlement_count=len(pending_txs),
        pending_settlement_amount=pending_amount,
        total_received=total_received,
        today_received=today_received,
    )
