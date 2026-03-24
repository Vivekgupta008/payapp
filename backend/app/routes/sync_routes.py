from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User
from ..schemas import SyncRequest, SyncResponse, SyncResultItem
from ..auth import get_current_user
from ..services.reconciliation import process_sync_batch

router = APIRouter(prefix="/api/sync", tags=["Sync & Reconciliation"])


@router.post("/transactions", response_model=SyncResponse)
def sync_transactions(
    sync_data: SyncRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Submit offline transactions for reconciliation.
    This endpoint is idempotent -- resubmitting the same transaction
    (same token_id + nonce) returns 'duplicate' without side effects.
    """
    tx_dicts = []
    for tx in sync_data.transactions:
        tx_dict = {
            "token_id": tx.token_id,
            "sender_id": tx.sender_id,
            "receiver_id": tx.receiver_id,
            "receiver_name": tx.receiver_name,
            "amount": tx.amount,
            "nonce": tx.nonce,
            "signature": tx.signature,
            "device_timestamp": tx.device_timestamp,
        }
        tx_dicts.append(tx_dict)

    results = process_sync_batch(db, tx_dicts)

    settled = sum(1 for r in results if r["status"] == "settled")
    failed = sum(1 for r in results if r["status"] in ("failed", "fraud_flagged"))

    return SyncResponse(
        results=[
            SyncResultItem(
                token_id=r["token_id"],
                nonce=r["nonce"],
                status=r["status"],
                message=r["message"],
            )
            for r in results
        ],
        settled_count=settled,
        failed_count=failed,
    )


@router.get("/status")
def get_sync_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the current sync status for the user."""
    from ..models import Transaction, TransactionStatus, OfflineToken, TokenStatus

    # Count transactions by status
    pending = db.query(Transaction).filter(
        Transaction.sender_id == current_user.id,
        Transaction.status == TransactionStatus.PENDING_OFFLINE,
    ).count()

    settled = db.query(Transaction).filter(
        Transaction.sender_id == current_user.id,
        Transaction.status == TransactionStatus.SETTLED,
    ).count()

    flagged = db.query(Transaction).filter(
        Transaction.sender_id == current_user.id,
        Transaction.status == TransactionStatus.FRAUD_FLAGGED,
    ).count()

    active_tokens = db.query(OfflineToken).filter(
        OfflineToken.user_id == current_user.id,
        OfflineToken.status == TokenStatus.ACTIVE,
    ).count()

    return {
        "pending_transactions": pending,
        "settled_transactions": settled,
        "flagged_transactions": flagged,
        "active_tokens": active_tokens,
        "offline_limit": current_user.offline_limit,
        "offline_limit_used": current_user.offline_limit_used,
        "balance": current_user.balance,
    }
