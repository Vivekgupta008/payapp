You are helping build an AI-powered offline payment feature into an existing Flutter + Python app located at github.com/ashmita-web/payapp_

STEP 0 — BEFORE WRITING ANY CODE:
1. Use the GitHub MCP to traverse the full repo. Read every file in /mobile/lib and /backend. Understand the existing folder structure, state management approach, existing screens, navigation, API client setup, and any models already defined.
2. List what already exists: screens, services, models, routes, backend endpoints.
3. Identify what state management is being used (Bloc, Provider, Riverpod, GetX, setState).
4. Identify the existing API base URL and how HTTP calls are made.
5. Do NOT write any code until you have confirmed your understanding back to me.

---

PROJECT CONTEXT:

This is a Paytm-like payment app. We are adding an OFFLINE PAYMENT feature. Here is the complete design:

CORE CONCEPT:
- Decouple payment capture from payment settlement
- Two payment paths: online API (direct bank debit) and offline API (deduct from offline credit limit, sync later)
- Offline credit limit is AI/ML-assigned per user, dynamic, not static

PAYMENT BLOB STRUCTURE (define this as a Dart model first):
{
  id: uuid,
  senderId: string,
  receiverId: string,
  amount: double,
  timestamp: DateTime,
  nonce: string,           // for replay protection later
  deviceSignature: string, // placeholder for now, fill with dummy value
  status: enum [pending_sync, synced, rejected],
  isOffline: bool,
  offlineLimitAtTime: double  // what the user's limit was when payment was made
}

THREE CASES TO IMPLEMENT (in this order):

CASE 1 — ONLY SENDER IS OFFLINE, RECEIVER IS ONLINE:
- Sender scans receiver's QR code (QR contains only receiverId)
- Sender enters amount
- App detects no internet (connectivity_plus package)
- App checks local offline credit limit (stored in SharedPreferences or SQLite)
- If amount <= available offline limit: deduct from local limit, create payment blob, store in local SQLite queue, show "Payment sent (offline)" to sender
- Receiver's app gets notified via normal online API call — since receiver IS online, sender's app attempts a direct HTTP call; if that fails (sender offline), fall through to Case 3
- Show sender: "Payment completed - will sync when you're back online"

CASE 2 — ONLY RECEIVER IS OFFLINE, SENDER IS ONLINE:
- Sender scans QR, enters amount
- Sender IS online: normal payment deducted from bank immediately via online API
- Receiver is offline: backend holds the credit, marks it as "pending receiver sync"
- When receiver comes online: background sync hits backend, fetches pending credits, updates local balance and shows notification
- Show receiver: "You received ₹X (settled)"

CASE 3 — BOTH SENDER AND RECEIVER ARE OFFLINE (hardest case):
- Sender scans QR (QR contains receiverId + a BLE advertisement UUID)
- App detects offline mode
- App initiates BLE connection to receiver's device using the UUID from the QR
- Sender's app sends the signed payment blob over BLE to receiver's app
- Receiver's app receives blob, stores it in its own local SQLite queue, shows "₹X received (pending settlement)"
- Sender's app marks blob as sent_via_ble, deducts from local offline limit
- When EITHER party comes online: they submit their blob to the backend for reconciliation
- Backend deduplicates using (senderId + receiverId + nonce + timestamp) composite key

SYNC ENGINE (implement after the 3 cases):
- Background service that wakes up when connectivity is restored
- Submits all pending blobs from SQLite queue to backend via idempotent POST /api/offline/sync
- Backend responds with: accepted / rejected / adjusted (if fraud detected)
- On accepted: mark blob as synced, deduct from user's actual bank balance
- On rejected: reverse the local offline limit deduction, notify user
- Clear settled blobs from queue after 7 days

OFFLINE CREDIT LIMIT:
- Fetched from backend when user is online and cached locally
- Stored in: SharedPreferences key 'offline_limit' (double) and 'offline_limit_expiry' (DateTime)
- Limit expires after 24 hours — if expired and user is offline, limit becomes ₹0
- After each offline payment, remaining limit is decremented locally
- When user syncs, backend recalculates limit using ML model and pushes new limit
- Display limit prominently on home screen: "Offline limit: ₹1,450 available"

BACKEND (Python):
- POST /api/offline/sync — accepts array of payment blobs, returns status per blob
- GET /api/user/offline-limit — returns {limit: float, expiry: ISO8601 string}
- POST /api/payments/online — existing or new, direct bank debit
- Simple ML model for limit calculation: use a scoring function based on (transaction_count_last_30_days, avg_transaction_value, account_age_days, kyc_tier) — return a limit between ₹0 and ₹5000. Use sklearn LogisticRegression or a simple rule-based scoring for now.

FLUTTER PACKAGES TO ADD (check pubspec.yaml first, add only what's missing):
- connectivity_plus: ^6.0.0       # detect online/offline
- sqflite: ^2.3.0                  # local SQLite queue
- flutter_blue_plus: ^1.31.0       # BLE for Case 3
- shared_preferences: ^2.2.0       # cache offline limit
- uuid: ^4.0.0                     # generate blob IDs
- path_provider: ^2.1.0            # SQLite file path

IMPLEMENTATION ORDER:
1. Create PaymentBlob model with full serialization
2. Create OfflineLimitService (SharedPrefs-backed)
3. Create OfflineQueueService (SQLite-backed)  
4. Create ConnectivityService (stream-based, use connectivity_plus)
5. Implement Case 1 (sender offline only) end to end
6. Implement Case 2 (receiver offline only) end to end
7. Create BLEService with advertise + scan + blob transfer
8. Implement Case 3 (both offline) end to end
9. Implement SyncEngine
10. Wire backend endpoints in Python
11. Add OfflineLimitBadge to home screen

IMPORTANT RULES FOR YOU (the agent):
- After reading the codebase, match the existing code style exactly (same state management, same folder conventions, same naming)
- Do not introduce a new state management system if one already exists
- Ask me before adding any package not in the list above
- For BLE in Case 3, use flutter_blue_plus. The BLE UUID embedded in QR should be generated fresh per session by the receiver's app
- All SQLite operations must be async
- Connectivity check must be a Stream, not a one-time check, so UI reacts live
- Show me each service/file after you write it before moving to the next
- Do NOT write all files at once — go one at a time and confirm with me

Start by reading the repo and reporting back what you find.

ONLY DO THE NECESSARY CHANGES - DO NOT RUN AROUND MAKING RANDOM CHANGES AND WHATEVER YOU DO, VERIFY IT ON APP USING THE MCP TOOL GIVEN