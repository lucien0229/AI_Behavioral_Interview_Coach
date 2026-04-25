from fastapi.testclient import TestClient

from backend.app import create_configured_app
from backend.config import create_state_store_from_environment
from backend.state_store import SQLAlchemyStateStore, SQLiteStateStore
from backend.tests.test_api_contract import bootstrap, data


def test_sqlalchemy_state_store_persists_snapshot(tmp_path):
    database_url = f"sqlite:///{tmp_path / 'state.db'}"
    snapshot = {
        "counters": {"req": 2, "usr": 1},
        "users": [{"app_user_id": "usr_1", "installation_id": "install-1"}],
        "idempotency_records": [
            {
                "scope": "usr_1",
                "key": "idem-key",
                "signature": "POST /api/v1/example abc123",
                "status_code": 200,
                "body": {"request_id": "req_1", "data": {"ok": True}, "error": None},
            }
        ],
    }

    SQLAlchemyStateStore(database_url).save(snapshot)

    assert SQLAlchemyStateStore(database_url).load() == snapshot


def test_configured_app_uses_database_url_for_state_and_idempotency(tmp_path, monkeypatch):
    database_url = f"sqlite:///{tmp_path / 'api.db'}"
    monkeypatch.setenv("AIBIC_DATABASE_URL", database_url)
    first_client = TestClient(create_configured_app())
    _, auth = bootstrap(first_client)

    resume = data(
        first_client.post(
            "/api/v1/resumes",
            files={"file": ("alex_resume.pdf", b"%PDF synthetic resume", "application/pdf")},
            data={"source_language": "en"},
            headers={**auth, "Idempotency-Key": "idem-resume"},
        )
    )
    created = data(
        first_client.post(
            "/api/v1/training-sessions",
            json={"training_focus": "ownership"},
            headers={**auth, "Idempotency-Key": "idem-create"},
        )
    )

    restarted_client = TestClient(create_configured_app())
    home = data(restarted_client.get("/api/v1/home", headers=auth))
    repeated_create = data(
        restarted_client.post(
            "/api/v1/training-sessions",
            json={"training_focus": "ownership"},
            headers={**auth, "Idempotency-Key": "idem-create"},
        )
    )

    assert home["active_resume"]["resume_id"] == resume["resume_id"]
    assert home["active_session"]["session_id"] == created["session_id"]
    assert repeated_create == created


def test_state_store_config_prefers_database_url(tmp_path, monkeypatch):
    monkeypatch.setenv("AIBIC_DATABASE_URL", "postgresql+psycopg://user:pass@db.example.test/app")
    monkeypatch.setenv("AIBIC_SQLITE_DATABASE_PATH", str(tmp_path / "ignored.sqlite3"))

    store = create_state_store_from_environment()

    assert isinstance(store, SQLAlchemyStateStore)
    assert store.database_url == "postgresql+psycopg://user:pass@db.example.test/app"


def test_state_store_config_keeps_sqlite_path_fallback(tmp_path, monkeypatch):
    database_path = tmp_path / "state.sqlite3"
    monkeypatch.setenv("AIBIC_SQLITE_DATABASE_PATH", str(database_path))

    store = create_state_store_from_environment()

    assert isinstance(store, SQLiteStateStore)
    assert store.database_path == str(database_path)
