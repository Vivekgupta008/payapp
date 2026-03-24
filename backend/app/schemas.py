from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime


# ─── Auth Schemas ────────────────────────────────────────────────────

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    phone: Optional[str] = None
    role: str = "user"  # "user" or "merchant"


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: str
    email: str
    full_name: str
    phone: Optional[str]
    role: str
    kyc_tier: int
    balance: float
    offline_limit: float
    offline_limit_used: float
    device_trust_score: float
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


# ─── Token Schemas ───────────────────────────────────────────────────

class TokenRequest(BaseModel):
    requested_amount: Optional[float] = None  # If None, use computed limit


class OfflineTokenData(BaseModel):
    token_id: str
    user_id: str
    amount: float
    issued_at: str
    expires_at: str
    nonce: str
    signature: str


class TokenResponse(BaseModel):
    tokens: List[OfflineTokenData]
    offline_limit: float
    offline_limit_remaining: float
    public_key: str  # Hex-encoded Ed25519 public key for verification
    risk_score: float
    risk_factors: dict


# ─── Sync Schemas ────────────────────────────────────────────────────

class TransactionSync(BaseModel):
    token_id: str
    sender_id: str
    receiver_id: Optional[str] = None
    receiver_name: Optional[str] = None
    amount: float
    nonce: str
    signature: str
    device_timestamp: str


class SyncRequest(BaseModel):
    transactions: List[TransactionSync]


class SyncResultItem(BaseModel):
    token_id: str
    nonce: str
    status: str  # "settled", "failed", "duplicate", "fraud_flagged"
    message: str


class SyncResponse(BaseModel):
    results: List[SyncResultItem]
    settled_count: int
    failed_count: int


# ─── Dashboard Schemas ──────────────────────────────────────────────

class TransactionItem(BaseModel):
    id: str
    token_id: str
    amount: float
    status: str
    counterparty_name: Optional[str]
    created_at: datetime
    settled_at: Optional[datetime]

    class Config:
        from_attributes = True


class UserDashboard(BaseModel):
    user: UserResponse
    recent_transactions: List[TransactionItem]
    active_tokens_count: int
    offline_limit_remaining: float
    total_spent: float
    total_offline_spent: float


class MerchantDashboard(BaseModel):
    user: UserResponse
    recent_transactions: List[TransactionItem]
    pending_settlement_count: int
    pending_settlement_amount: float
    total_received: float
    today_received: float
