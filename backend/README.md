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

## Verify

```bash
python3 -m pytest backend/tests/test_api_contract.py -q
```

## Current scope

- In-memory anonymous users, resumes, sessions, idempotency records, and purchase state by default.
- Optional SQLite state snapshot persistence for local restart testing and backend provider wiring.
- iOS-compatible envelope responses: `request_id`, `data`, `error`.
- Covered flows: bootstrap, home, resume upload/status/delete, training session lifecycle, billing stubs, and delete-all-data.
- Mock AI, ASR, resume parsing, Apple verification, and file storage providers.

The next backend step is replacing the SQLite snapshot and mock providers with production dependencies: Postgres, object storage, Apple App Store Server verification, ASR, and AI generation.
