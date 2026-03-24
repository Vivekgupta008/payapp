"""
Seed script to populate the database with demo data.
Run: python seed.py
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal, init_db
from app.models import User, UserRole
from app.auth import hash_password


def seed_database():
    """Create demo users for the hackathon."""
    init_db()
    db = SessionLocal()

    try:
        # Check if already seeded
        existing = db.query(User).first()
        if existing:
            print("Database already seeded. Skipping.")
            return

        # Demo Users
        users = [
            User(
                email="alice@demo.com",
                password_hash=hash_password("password123"),
                full_name="Alice Johnson",
                phone="+919876543210",
                role=UserRole.USER,
                kyc_tier=3,
                device_trust_score=0.85,
                balance=10000.0,
                transaction_count=45,
                avg_transaction_amount=250.0,
            ),
            User(
                email="bob@demo.com",
                password_hash=hash_password("password123"),
                full_name="Bob Smith",
                phone="+919876543211",
                role=UserRole.USER,
                kyc_tier=2,
                device_trust_score=0.65,
                balance=5000.0,
                transaction_count=12,
                avg_transaction_amount=150.0,
            ),
            User(
                email="charlie@demo.com",
                password_hash=hash_password("password123"),
                full_name="Charlie Kumar",
                phone="+919876543212",
                role=UserRole.USER,
                kyc_tier=1,
                device_trust_score=0.40,
                balance=2000.0,
                transaction_count=3,
                avg_transaction_amount=80.0,
                fraud_flags=1,
            ),
        ]

        # Demo Merchants
        merchants = [
            User(
                email="shopkeeper@demo.com",
                password_hash=hash_password("password123"),
                full_name="Ravi's General Store",
                phone="+919876543220",
                role=UserRole.MERCHANT,
                kyc_tier=2,
                device_trust_score=0.70,
                balance=0.0,
            ),
            User(
                email="chai@demo.com",
                password_hash=hash_password("password123"),
                full_name="Priya's Chai Point",
                phone="+919876543221",
                role=UserRole.MERCHANT,
                kyc_tier=2,
                device_trust_score=0.80,
                balance=0.0,
            ),
            User(
                email="pharmacy@demo.com",
                password_hash=hash_password("password123"),
                full_name="MedPlus Pharmacy",
                phone="+919876543222",
                role=UserRole.MERCHANT,
                kyc_tier=3,
                device_trust_score=0.90,
                balance=0.0,
            ),
        ]

        for user in users + merchants:
            db.add(user)

        db.commit()
        print(f"Seeded {len(users)} users and {len(merchants)} merchants.")
        print("\nDemo Credentials:")
        print("  Users:")
        print("    alice@demo.com / password123  (High trust, KYC 3)")
        print("    bob@demo.com / password123    (Medium trust, KYC 2)")
        print("    charlie@demo.com / password123 (Low trust, KYC 1, 1 fraud flag)")
        print("  Merchants:")
        print("    shopkeeper@demo.com / password123")
        print("    chai@demo.com / password123")
        print("    pharmacy@demo.com / password123")

    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
