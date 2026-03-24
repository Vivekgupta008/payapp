import requests
import json
import uuid
import time
import nacl.signing

BASE_URL = "http://127.0.0.1:8000"

def test_full_flow():
    # 1. Login as user and get token
    res = requests.post(f"{BASE_URL}/api/auth/login", json={"email": "alice@demo.com", "password": "password123"})
    assert res.status_code == 200, res.text
    user_token = res.json()["access_token"]
    user_id = res.json()["user"]["id"]
    
    # 2. Login as merchant and get token
    res = requests.post(f"{BASE_URL}/api/auth/login", json={"email": "shopkeeper@demo.com", "password": "password123"})
    assert res.status_code == 200, res.text
    merchant_token = res.json()["access_token"]
    merchant_id = res.json()["user"]["id"]
    
    # 3. User requests tokens
    res = requests.post(f"{BASE_URL}/api/tokens/request", 
                        headers={"Authorization": f"Bearer {user_token}"},
                        json={})
    assert res.status_code == 200, res.text
    tokens = res.json()["tokens"]
    assert len(tokens) > 0
    t = tokens[0]
    
    # 4. User signs a payment offline
    # In flutter:
    # return OfflineTransaction(
    #     tokenId: paymentData['token_id'],
    #     senderId: paymentData['user_id'],
    #     receiverId: merchantId,
    #     receiverName: merchantName,
    #     amount: (paymentData['amount'] as num).toDouble(),
    #     nonce: paymentData['nonce'],
    #     signature: paymentData['signature'],
    
    # For sync, the sender does not have receiver ID
    sender_sync_data = {
        "transactions": [{
            "token_id": t["token_id"],
            "sender_id": t["user_id"],
            "receiver_id": None,
            "receiver_name": "Merchant",
            "amount": 5.0,
            "nonce": t["nonce"],
            "signature": "client-signature-xyz",  # not validated by backend right now, wait
            "device_timestamp": "2026-03-22T10:00:00Z"
        }]
    }
    
    # Merchant scanned it and got it, sends with receiver ID
    merchant_sync_data = {
        "transactions": [{
            "token_id": t["token_id"],
            "sender_id": t["user_id"],
            "receiver_id": merchant_id,
            "receiver_name": "Ravi's General Store",
            "amount": 5.0,
            "nonce": t["nonce"],
            "signature": "client-signature-xyz",
            "device_timestamp": "2026-03-22T10:00:00Z"
        }]
    }

    # Sequence A: Sender syncs first
    res = requests.post(f"{BASE_URL}/api/sync/transactions",
                        headers={"Authorization": f"Bearer {user_token}"},
                        json=sender_sync_data)
    assert res.status_code == 200, res.text
    assert res.json()["results"][0]["status"] == "settled"

    # Then Merchant syncs
    res = requests.post(f"{BASE_URL}/api/sync/transactions",
                        headers={"Authorization": f"Bearer {merchant_token}"},
                        json=merchant_sync_data)
    assert res.status_code == 200, res.text
    assert res.json()["results"][0]["status"] == "settled"
    
    print("Test passed!")

if __name__ == "__main__":
    test_full_flow()
