from datetime import datetime
from sqlalchemy.orm import Session
from ..models import (
    Transaction, TransactionStatus, OfflineToken, TokenStatus,
    User, LedgerEntry, generate_uuid,
)
from .token_service import verify_token_signature
from .fraud import check_fraud_signals, flag_user_for_fraud


def reconcile_transaction(db: Session, tx_data: dict) -> dict:
    """
    Reconcile a single offline transaction.

    Steps:
    1. Check for duplicates (idempotency)
    2. Verify token signature
    3. Validate token status and expiry
    4. Run fraud checks
    5. Settle the transaction (debit sender, credit receiver)
    6. Update ledger entries

    Returns: {"status": str, "message": str}
    """
    token_id = tx_data["token_id"]
    nonce = tx_data["nonce"]
    sender_id = tx_data["sender_id"]
    receiver_id = tx_data.get("receiver_id")
    amount = tx_data["amount"]
    signature = tx_data["signature"]

    # 1. Idempotency check - skip if already processed or credit receiver if we now know who it is
    existing_tx = db.query(Transaction).filter(
        Transaction.token_id == token_id,
        Transaction.nonce == nonce,
    ).first()
    if existing_tx:
        # If the transaction was synced by sender first (no receiver_id),
        # but now the merchant is syncing (has receiver_id), we need to credit them!
        if existing_tx.receiver_id is None and receiver_id:
            receiver = db.query(User).filter(User.id == receiver_id).first()
            if receiver:
                receiver.balance += amount
                existing_tx.receiver_id = receiver_id
                existing_tx.merchant_name = tx_data.get("receiver_name") or existing_tx.merchant_name
                
                credit_entry = LedgerEntry(
                    user_id=receiver_id,
                    transaction_id=existing_tx.id,
                    entry_type="credit",
                    amount=amount,
                    balance_after=receiver.balance,
                )
                db.add(credit_entry)
                db.commit()
                return {
                    "status": "settled",
                    "message": "Transaction updated with merchant info",
                    "transaction_id": existing_tx.id,
                }
                
        return {
            "status": "duplicate",
            "message": "Transaction already processed",
            "transaction_id": existing_tx.id,
        }

    # 2. Verify token signature
    payload = {
        "token_id": token_id,
        "user_id": sender_id,
        "amount": amount,
        "issued_at": tx_data.get("issued_at", ""),
        "expires_at": tx_data.get("expires_at", ""),
        "nonce": nonce,
    }

    # Look up original token for full payload
    original_token = db.query(OfflineToken).filter(
        OfflineToken.token_id == token_id,
    ).first()

    if not original_token:
        return {"status": "failed", "message": "Original token not found"}

    payload = {
        "token_id": original_token.token_id,
        "user_id": original_token.user_id,
        "amount": original_token.amount,
        "issued_at": original_token.issued_at.isoformat(),
        "expires_at": original_token.expires_at.isoformat(),
        "nonce": original_token.nonce,
    }

    if not verify_token_signature(payload, original_token.signature):
        return {"status": "failed", "message": "Token signature verification failed"}

    # 3. Validate token status
    if original_token.status == TokenStatus.CONSUMED:
        return {"status": "failed", "message": "Token already consumed"}
    if original_token.status == TokenStatus.REVOKED:
        return {"status": "failed", "message": "Token has been revoked"}
    if amount > original_token.amount:
        return {"status": "failed", "message": f"Amount {amount} exceeds token limit {original_token.amount}"}

    # 4. Fraud checks
    is_suspicious, fraud_reasons = check_fraud_signals(db, sender_id, amount, nonce)

    if is_suspicious:
        # Create transaction but flag it
        tx = Transaction(
            token_id=token_id,
            sender_id=sender_id,
            receiver_id=receiver_id,
            amount=amount,
            nonce=nonce,
            status=TransactionStatus.FRAUD_FLAGGED,
            device_signature=signature,
            merchant_name=tx_data.get("receiver_name"),
            synced_at=datetime.utcnow(),
        )
        db.add(tx)
        flag_user_for_fraud(db, sender_id, "; ".join(fraud_reasons))
        db.commit()
        return {
            "status": "fraud_flagged",
            "message": f"Transaction flagged: {'; '.join(fraud_reasons)}",
        }

    # 5. Settle the transaction
    sender = db.query(User).filter(User.id == sender_id).first()
    if not sender:
        return {"status": "failed", "message": "Sender not found"}

    # Debit sender
    if sender.balance < amount:
        return {"status": "failed", "message": "Insufficient balance"}

    sender.balance -= amount
    sender.offline_limit_used += amount
    sender.transaction_count += 1
    # Update running average
    total_spent = sender.avg_transaction_amount * (sender.transaction_count - 1) + amount
    sender.avg_transaction_amount = total_spent / sender.transaction_count

    # Credit receiver if known
    receiver = None
    if receiver_id:
        receiver = db.query(User).filter(User.id == receiver_id).first()
        if receiver:
            receiver.balance += amount

    # Create transaction record
    tx = Transaction(
        token_id=token_id,
        sender_id=sender_id,
        receiver_id=receiver_id,
        amount=amount,
        nonce=nonce,
        status=TransactionStatus.SETTLED,
        device_signature=signature,
        merchant_name=tx_data.get("receiver_name"),
        synced_at=datetime.utcnow(),
        settled_at=datetime.utcnow(),
    )
    db.add(tx)
    db.flush()

    # 6. Ledger entries
    debit_entry = LedgerEntry(
        user_id=sender_id,
        transaction_id=tx.id,
        entry_type="debit",
        amount=amount,
        balance_after=sender.balance,
    )
    db.add(debit_entry)

    if receiver:
        credit_entry = LedgerEntry(
            user_id=receiver_id,
            transaction_id=tx.id,
            entry_type="credit",
            amount=amount,
            balance_after=receiver.balance,
        )
        db.add(credit_entry)

    # Mark token as consumed
    if original_token:
        original_token.status = TokenStatus.CONSUMED
        original_token.consumed_at = datetime.utcnow()

    db.commit()

    return {
        "status": "settled",
        "message": "Transaction settled successfully",
        "transaction_id": tx.id,
    }


def process_sync_batch(db: Session, transactions: list) -> list:
    """Process a batch of offline transactions for reconciliation."""
    results = []
    for tx_data in transactions:
        result = reconcile_transaction(db, tx_data)
        result["token_id"] = tx_data["token_id"]
        result["nonce"] = tx_data["nonce"]
        results.append(result)
    return results
