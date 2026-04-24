# Backend API MVP

This directory contains a local FastAPI implementation of the iOS remote API contract.

## Run locally

```bash
python3 -m pip install -r backend/requirements.txt
uvicorn backend.app:app --reload --host 127.0.0.1 --port 8000
```

Use `http://127.0.0.1:8000/api/v1` as the iOS API base URL.

For persistent local smoke tests, instantiate the app with a SQLite database path:

```python
from backend.app import create_app

app = create_app(database_path="local-api.sqlite3")
```

For production provider wiring, pass a `BackendProviders` bundle:

```python
from backend.app import BackendProviders, create_app

app = create_app(
    database_path="local-api.sqlite3",
    providers=BackendProviders(
        resume_parser=resume_parser,
        training_content=training_content_provider,
        audio_transcriber=audio_transcriber,
        purchase_verifier=apple_purchase_verifier,
    ),
)
```

For the default ASGI entrypoint (`uvicorn backend.app:app`), Apple purchase verification is enabled when these environment variables are present:

```bash
export AIBIC_APPLE_ROOT_CERT_PATHS="/path/to/AppleRootCA-G3.cer"
export AIBIC_IOS_BUNDLE_ID="com.example.app"
export AIBIC_APPLE_ENVIRONMENT="sandbox" # or production
export AIBIC_APPLE_APP_ID="1234567890"   # required by Apple for production
```

## Verify

```bash
python3 -m pytest backend/tests/test_api_contract.py -q
```

## Current scope

- In-memory anonymous users, resumes, sessions, idempotency records, and purchase state by default.
- Optional SQLite state snapshot persistence for local restart testing and backend provider wiring.
- Injectable provider bundle for resume parsing, training content generation, audio transcription, and Apple purchase verification.
- Apple App Store signed transaction verification provider using Apple's App Store Server Python library.
- iOS-compatible envelope responses: `request_id`, `data`, `error`.
- Covered flows: bootstrap, home, resume upload/status/delete, training session lifecycle, billing stubs, and delete-all-data.
- Default mock AI, ASR, resume parsing, purchase verification, and file storage providers; Apple purchase verification can be enabled through environment configuration.

The next backend step is replacing the SQLite snapshot and remaining default mock providers with production dependencies: Postgres, object storage, ASR, and AI generation.
