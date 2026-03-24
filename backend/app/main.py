from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .database import init_db
from .routes import auth_routes, token_routes, sync_routes, dashboard

app = FastAPI(
    title="OfflinePay API",
    description="AI-powered offline payment system backend",
    version="1.0.0",
)

# CORS - allow all origins for hackathon
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_routes.router)
app.include_router(token_routes.router)
app.include_router(sync_routes.router)
app.include_router(dashboard.router)


@app.on_event("startup")
def startup_event():
    """Initialize database and train ML model on startup."""
    init_db()
    print("Database initialized.")

    # Try to train ML model if not already trained
    from .config import ML_MODEL_PATH
    import os
    if not os.path.exists(ML_MODEL_PATH):
        try:
            from .ml.train_model import train_model
            train_model()
            print("ML risk model trained successfully.")
        except Exception as e:
            print(f"Warning: Could not train ML model: {e}")
            print("Using heuristic risk scoring as fallback.")


@app.get("/")
def root():
    return {
        "name": "OfflinePay API",
        "version": "1.0.0",
        "description": "AI-powered offline payment system",
        "docs": "/docs",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/api/public-key")
def get_public_key():
    """Get the Ed25519 public key for offline token verification."""
    from .config import PUBLIC_KEY_HEX
    return {"public_key": PUBLIC_KEY_HEX}
