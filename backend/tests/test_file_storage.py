from fastapi.testclient import TestClient

from backend.app import BackendProviders, create_app
from backend.file_storage import LocalFileStorage
from backend.tests.test_api_contract import bootstrap, data


def test_local_file_storage_persists_resume_and_audio_uploads_across_restarts(tmp_path):
    database_path = tmp_path / "api.sqlite3"
    storage_root = tmp_path / "objects"
    storage = LocalFileStorage(str(storage_root))
    first_client = TestClient(
        create_app(
            database_path=str(database_path),
            providers=BackendProviders(file_storage=storage),
        )
    )
    _, auth = bootstrap(first_client)

    resume = data(
        first_client.post(
            "/api/v1/resumes",
            files={"file": ("alex_resume.pdf", b"%PDF stored resume", "application/pdf")},
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
    session_id = created["session_id"]
    data(first_client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))

    data(
        first_client.post(
            f"/api/v1/training-sessions/{session_id}/first-answer",
            files={"audio_file": ("first.m4a", b"first-audio", "audio/mp4")},
            data={"duration_seconds": "3.25"},
            headers={**auth, "Idempotency-Key": "idem-first"},
        )
    )
    data(first_client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))
    data(
        first_client.post(
            f"/api/v1/training-sessions/{session_id}/follow-up-answer",
            files={"audio_file": ("follow.m4a", b"follow-audio", "audio/mp4")},
            data={"duration_seconds": "4.5"},
            headers={**auth, "Idempotency-Key": "idem-follow"},
        )
    )
    data(first_client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))
    data(
        first_client.post(
            f"/api/v1/training-sessions/{session_id}/redo",
            files={"audio_file": ("redo.m4a", b"redo-audio", "audio/mp4")},
            data={"duration_seconds": "5.0"},
            headers={**auth, "Idempotency-Key": "idem-redo"},
        )
    )
    completed = data(first_client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))

    assert storage.read(resume["storage_key"]) == b"%PDF stored resume"
    assert storage.read(completed["audio_storage_keys"]["first_answer"]) == b"first-audio"
    assert storage.read(completed["audio_storage_keys"]["follow_up_answer"]) == b"follow-audio"
    assert storage.read(completed["audio_storage_keys"]["redo"]) == b"redo-audio"

    restarted_client = TestClient(
        create_app(
            database_path=str(database_path),
            providers=BackendProviders(file_storage=LocalFileStorage(str(storage_root))),
        )
    )
    fetched_resume = data(restarted_client.get(f"/api/v1/resumes/{resume['resume_id']}", headers=auth))
    fetched_session = data(restarted_client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))

    assert fetched_resume["storage_key"] == resume["storage_key"]
    assert fetched_session["audio_storage_keys"] == completed["audio_storage_keys"]


def test_delete_all_data_removes_stored_resume_and_audio_files(tmp_path):
    storage_root = tmp_path / "objects"
    storage = LocalFileStorage(str(storage_root))
    client = TestClient(create_app(providers=BackendProviders(file_storage=storage)))
    _, auth = bootstrap(client)

    resume = data(
        client.post(
            "/api/v1/resumes",
            files={"file": ("alex_resume.pdf", b"%PDF stored resume", "application/pdf")},
            data={"source_language": "en"},
            headers={**auth, "Idempotency-Key": "idem-resume"},
        )
    )
    created = data(
        client.post(
            "/api/v1/training-sessions",
            json={"training_focus": "ownership"},
            headers={**auth, "Idempotency-Key": "idem-create"},
        )
    )
    session_id = created["session_id"]
    data(client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))
    data(
        client.post(
            f"/api/v1/training-sessions/{session_id}/first-answer",
            files={"audio_file": ("first.m4a", b"first-audio", "audio/mp4")},
            data={"duration_seconds": "3.25"},
            headers={**auth, "Idempotency-Key": "idem-first"},
        )
    )
    session = data(client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))

    client.delete(
        "/api/v1/app-users/me/data",
        headers={**auth, "Idempotency-Key": "idem-delete-all"},
    )

    assert not storage.exists(resume["storage_key"])
    assert not storage.exists(session["audio_storage_keys"]["first_answer"])
