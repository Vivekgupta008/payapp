from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, OfflineToken, TokenStatus
from ..schemas import TokenRequest, TokenResponse, OfflineTokenData
from ..auth import get_current_user
from ..services.token_service import generate_offline_tokens
from ..services.risk_engine import compute_risk_score, compute_offline_limit
from ..config import PUBLIC_KEY_HEX, MAX_TOKENS_PER_REQUEST

router = APIRouter(prefix="/api/tokens", tags=["Offline Tokens"])


@router.post("/request", response_model=TokenResponse)
def request_offline_tokens(
    request: TokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Request offline payment tokens. The backend computes a risk score,
    determines the offline limit, and issues signed tokens.
    """
    if current_user.role.value != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only users can request offline tokens",
        )

    # Compute user features for risk model
    days_since_reg = (datetime.utcnow() - current_user.created_at).days
    user_features = {
        "transaction_count": current_user.transaction_count,
        "avg_transaction_amount": current_user.avg_transaction_amount,
        "kyc_tier": current_user.kyc_tier,
        "device_trust_score": current_user.device_trust_score,
        "days_since_registration": days_since_reg,
        "fraud_flags": current_user.fraud_flags,
        "total_spent": current_user.avg_transaction_amount * current_user.transaction_count,
    }

    # Compute risk score and offline limit
    risk_score, risk_factors = compute_risk_score(user_features)
    limit = compute_offline_limit(risk_score)

    if limit <= 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Offline payments denied due to high risk score",
        )

    # Cap limit by balance
    limit = min(limit, current_user.balance)

    # Use requested amount if provided and within limit
    if request.requested_amount:
        limit = min(request.requested_amount, limit)

    # Revoke any existing active tokens
    db.query(OfflineToken).filter(
        OfflineToken.user_id == current_user.id,
        OfflineToken.status == TokenStatus.ACTIVE,
    ).update({"status": TokenStatus.REVOKED})

    # Reset offline limit usage
    current_user.offline_limit = limit
    current_user.offline_limit_used = 0.0

    # Generate signed tokens
    token_data_list = generate_offline_tokens(
        user_id=current_user.id,
        total_limit=limit,
        max_tokens=MAX_TOKENS_PER_REQUEST,
    )

    # Store tokens in database
    db_tokens = []
    response_tokens = []
    for td in token_data_list:
        db_token = OfflineToken(
            token_id=td["token_id"],
            user_id=current_user.id,
            amount=td["amount"],
            issued_at=datetime.fromisoformat(td["issued_at"]),
            expires_at=datetime.fromisoformat(td["expires_at"]),
            nonce=td["nonce"],
            signature=td["signature"],
            status=TokenStatus.ACTIVE,
        )
        db_tokens.append(db_token)
        response_tokens.append(OfflineTokenData(**td))

    db.add_all(db_tokens)
    db.commit()

    return TokenResponse(
        tokens=response_tokens,
        offline_limit=limit,
        offline_limit_remaining=limit,
        public_key=PUBLIC_KEY_HEX,
        risk_score=risk_score,
        risk_factors=risk_factors,
    )


@router.get("/active")
def get_active_tokens(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all active (unused) tokens for the current user."""
    tokens = db.query(OfflineToken).filter(
        OfflineToken.user_id == current_user.id,
        OfflineToken.status == TokenStatus.ACTIVE,
    ).all()

    # Filter out expired tokens
    active_tokens = []
    for t in tokens:
        if t.expires_at > datetime.utcnow():
            active_tokens.append(OfflineTokenData(
                token_id=t.token_id,
                user_id=t.user_id,
                amount=t.amount,
                issued_at=t.issued_at.isoformat(),
                expires_at=t.expires_at.isoformat(),
                nonce=t.nonce,
                signature=t.signature,
            ))
        else:
            t.status = TokenStatus.EXPIRED
    db.commit()

    return {
        "tokens": active_tokens,
        "count": len(active_tokens),
        "offline_limit": current_user.offline_limit,
        "offline_limit_used": current_user.offline_limit_used,
        "public_key": PUBLIC_KEY_HEX,
    }


@router.post("/revoke")
def revoke_all_tokens(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Revoke all active tokens for the current user."""
    count = db.query(OfflineToken).filter(
        OfflineToken.user_id == current_user.id,
        OfflineToken.status == TokenStatus.ACTIVE,
    ).update({"status": TokenStatus.REVOKED})
    db.commit()

    return {"message": f"Revoked {count} tokens", "revoked_count": count}
