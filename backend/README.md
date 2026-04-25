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
        file_storage=file_storage,
    ),
)
```

For the default ASGI entrypoint (`uvicorn backend.app:app`), SQLAlchemy-backed state persistence, local/S3-compatible file storage, and Apple purchase verification are enabled when these environment variables are present:

```bash
export AIBIC_DATABASE_URL="postgresql+psycopg://user:password@postgres.example.com/aibic"
export AIBIC_RESUME_PARSER_PROVIDER="openai"
export AIBIC_ASR_PROVIDER="openai"
export AIBIC_AI_PROVIDER="openai"
export AIBIC_OPENAI_API_KEY="..."
export AIBIC_OPENAI_RESUME_MODEL="gpt-5"
export AIBIC_OPENAI_TRANSCRIPTION_MODEL="gpt-4o-mini-transcribe"
export AIBIC_OPENAI_GENERATION_MODEL="gpt-5"
export AIBIC_LOCAL_FILE_STORAGE_ROOT="/var/lib/aibic/objects"
export AIBIC_S3_BUCKET="aibic-objects"
export AIBIC_S3_KEY_PREFIX="prod"
export AIBIC_S3_ENDPOINT_URL="https://s3.example.com"
export AIBIC_S3_REGION="us-west-2"
export AIBIC_S3_ACCESS_KEY_ID="..."
export AIBIC_S3_SECRET_ACCESS_KEY="..."
export AIBIC_APPLE_ROOT_CERT_PATHS="/path/to/AppleRootCA-G3.cer"
export AIBIC_IOS_BUNDLE_ID="com.example.app"
export AIBIC_APPLE_ENVIRONMENT="sandbox" # or production
export AIBIC_APPLE_APP_ID="1234567890"   # required by Apple for production
```

## Verify

```bash
python3 -m pytest backend/tests/test_api_contract.py -q
```

For a live backend smoke test against a local or deployed API:

```bash
export AIBIC_SMOKE_API_BASE_URL="http://127.0.0.1:8000/api/v1"
export AIBIC_SMOKE_RESUME_PATH="/path/to/resume.pdf"
python3 -m backend.smoke
```

## Current scope

- In-memory anonymous users, resumes, sessions, idempotency records, and purchase state by default.
- Optional SQLite state snapshot persistence for local restart testing and backend provider wiring.
- Optional SQLAlchemy-backed state snapshot persistence through `AIBIC_DATABASE_URL`, including Postgres with `psycopg`.
- Injectable provider bundle for resume parsing, training content generation, audio transcription, and Apple purchase verification.
- Local file storage provider for resume and audio uploads, with storage keys persisted in backend state and files deleted during user data deletion.
- S3-compatible file storage provider using `boto3`, configured through `AIBIC_S3_*` environment variables.
- OpenAI resume parsing provider, explicitly enabled with `AIBIC_RESUME_PARSER_PROVIDER=openai`.
- OpenAI audio transcription provider, explicitly enabled with `AIBIC_ASR_PROVIDER=openai`.
- OpenAI training content generation provider, explicitly enabled with `AIBIC_AI_PROVIDER=openai`.
- Apple App Store signed transaction verification provider using Apple's App Store Server Python library.
- Live smoke-test runner for bootstrap, resume upload, training creation, and first training-session read.
- iOS-compatible envelope responses: `request_id`, `data`, `error`.
- Covered flows: bootstrap, home, resume upload/status/delete, training session lifecycle, billing stubs, and delete-all-data.
- Default mock AI, ASR, resume parsing, purchase verification, and file storage providers; resume parsing, AI generation, ASR, and Apple purchase verification can be enabled through environment configuration.

The next backend step is running the smoke test with production provider environment variables and real credentials.
