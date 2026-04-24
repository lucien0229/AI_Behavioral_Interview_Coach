from fastapi.testclient import TestClient

from backend.app import create_app


def data(response):
    body = response.json()
    assert body["request_id"].startswith("req_")
    assert body["error"] is None
    return body["data"]


def error(response):
    body = response.json()
    assert body["request_id"].startswith("req_")
    assert body["data"] is None
    return body["error"]


def bootstrap(client, key="idem-bootstrap"):
    response = client.post(
        "/api/v1/app-users/bootstrap",
        json={
            "installation_id": "install-123",
            "platform": "ios",
            "locale": "en-US",
            "app_version": "1.0",
        },
        headers={"Idempotency-Key": key},
    )
    assert response.status_code == 200
    payload = data(response)
    return payload, {"Authorization": f"Bearer {payload['access_token']}"}


def test_bootstrap_is_idempotent_and_home_matches_ios_contract():
    client = TestClient(create_app())

    first, auth = bootstrap(client)
    second, _ = bootstrap(client)
    home = data(client.get("/api/v1/home", headers=auth))

    assert first["app_user_id"].startswith("usr_")
    assert first == second
    assert first["usage_balance"] == {
        "free_session_credits_remaining": 2,
        "paid_session_credits_remaining": 0,
        "reserved_session_credits": 0,
    }
    assert home["app_user_id"] == first["app_user_id"]
    assert home["active_resume"] is None
    assert home["active_session"] is None
    assert home["last_training_summary"] is None


def test_sqlite_store_persists_state_and_idempotency_across_app_restarts(tmp_path):
    database_path = tmp_path / "api.sqlite3"
    first_client = TestClient(create_app(database_path=str(database_path)))
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

    restarted_client = TestClient(create_app(database_path=str(database_path)))
    home = data(restarted_client.get("/api/v1/home", headers=auth))
    repeated_create = data(
        restarted_client.post(
            "/api/v1/training-sessions",
            json={"training_focus": "ownership"},
            headers={**auth, "Idempotency-Key": "idem-create"},
        )
    )
    question = data(restarted_client.get(f"/api/v1/training-sessions/{created['session_id']}", headers=auth))

    second_restart_client = TestClient(create_app(database_path=str(database_path)))
    home_after_read = data(second_restart_client.get("/api/v1/home", headers=auth))

    assert home["active_resume"]["resume_id"] == resume["resume_id"]
    assert home["active_session"]["session_id"] == created["session_id"]
    assert home["usage_balance"]["free_session_credits_remaining"] == 1
    assert home["usage_balance"]["reserved_session_credits"] == 1
    assert repeated_create == created
    assert question["status"] == "waiting_first_answer"
    assert home_after_read["active_session"]["status"] == "waiting_first_answer"


def test_resume_upload_and_redo_training_flow_match_ios_remote_contract():
    client = TestClient(create_app())
    _, auth = bootstrap(client)

    resume = data(
        client.post(
            "/api/v1/resumes",
            files={"file": ("alex_resume.pdf", b"%PDF synthetic resume", "application/pdf")},
            data={"source_language": "en"},
            headers={**auth, "Idempotency-Key": "idem-resume"},
        )
    )
    assert resume["status"] == "ready"
    assert resume["profile_quality_status"] == "usable"
    fetched_resume = data(client.get(f"/api/v1/resumes/{resume['resume_id']}", headers=auth))
    assert fetched_resume["resume_id"] == resume["resume_id"]

    created = data(
        client.post(
            "/api/v1/training-sessions",
            json={"training_focus": "ownership"},
            headers={**auth, "Idempotency-Key": "idem-create"},
        )
    )
    assert created["status"] == "question_generating"
    assert created["credit_state"] == "reserved"

    session_id = created["session_id"]
    question = data(client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))
    assert question["status"] == "waiting_first_answer"
    assert question["question"]["question_text"]
    assert question["question"]["training_focus"] == "ownership"

    first_answer = data(
        client.post(
            f"/api/v1/training-sessions/{session_id}/first-answer",
            files={"audio_file": ("first.m4a", b"audio", "audio/mp4")},
            data={"duration_seconds": "3.25"},
            headers={**auth, "Idempotency-Key": "idem-first"},
        )
    )
    assert first_answer["status"] == "first_answer_processing"

    follow_up = data(client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))
    assert follow_up["status"] == "waiting_followup_answer"
    assert follow_up["follow_up"]["follow_up_text"]

    second_answer = data(
        client.post(
            f"/api/v1/training-sessions/{session_id}/follow-up-answer",
            files={"audio_file": ("follow.m4a", b"audio", "audio/mp4")},
            data={"duration_seconds": "4.5"},
            headers={**auth, "Idempotency-Key": "idem-follow"},
        )
    )
    assert second_answer["status"] == "followup_answer_processing"

    feedback = data(client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))
    assert feedback["status"] == "redo_available"
    assert feedback["feedback"]["visible_assessments"]["personal_ownership"] in {"Strong", "Mixed", "Weak"}

    redo = data(
        client.post(
            f"/api/v1/training-sessions/{session_id}/redo",
            files={"audio_file": ("redo.m4a", b"audio", "audio/mp4")},
            data={"duration_seconds": "5.0"},
            headers={**auth, "Idempotency-Key": "idem-redo"},
        )
    )
    assert redo["status"] == "redo_processing"

    completed = data(client.get(f"/api/v1/training-sessions/{session_id}", headers=auth))
    assert completed["status"] == "completed"
    assert completed["completion_reason"] == "redo_review_generated"
    assert completed["redo_review"]["improvement_status"] == "partially_improved"

    home = data(client.get("/api/v1/home", headers=auth))
    history = data(client.get("/api/v1/training-sessions/history?limit=10", headers=auth))
    assert home["active_session"] is None
    assert home["last_training_summary"]["session_id"] == session_id
    assert history["items"][0]["session_id"] == session_id


def test_abandon_before_feedback_releases_reserved_credit():
    client = TestClient(create_app())
    _, auth = bootstrap(client)
    data(
        client.post(
            "/api/v1/resumes",
            files={"file": ("alex_resume.pdf", b"%PDF synthetic resume", "application/pdf")},
            data={"source_language": "en"},
            headers={**auth, "Idempotency-Key": "idem-resume"},
        )
    )
    session = data(
        client.post(
            "/api/v1/training-sessions",
            json={"training_focus": "ownership"},
            headers={**auth, "Idempotency-Key": "idem-create"},
        )
    )

    abandoned = data(
        client.post(
            f"/api/v1/training-sessions/{session['session_id']}/abandon",
            headers={**auth, "Idempotency-Key": "idem-abandon"},
        )
    )
    home = data(client.get("/api/v1/home", headers=auth))

    assert abandoned["status"] == "abandoned"
    assert abandoned["credit_state"] == "released"
    assert home["active_session"] is None
    assert home["usage_balance"]["free_session_credits_remaining"] == 2
    assert home["usage_balance"]["reserved_session_credits"] == 0


def test_billing_stubs_and_delete_all_data_match_ios_contract():
    client = TestClient(create_app())
    _, auth = bootstrap(client)

    entitlement = data(client.get("/api/v1/billing/entitlement", headers=auth))
    assert entitlement["products"][0]["product_id"] == "coach_sprint_pack_01"
    assert entitlement["app_account_token"]

    verified = data(
        client.post(
            "/api/v1/billing/apple/verify",
            json={
                "product_id": "coach_sprint_pack_01",
                "transaction_id": "apple_transaction_id",
                "original_transaction_id": "apple_original_transaction_id",
                "app_account_token": entitlement["app_account_token"],
                "signed_transaction_info": "sandbox-jws",
                "environment": "sandbox",
            },
            headers={**auth, "Idempotency-Key": "idem-verify"},
        )
    )
    assert verified["status"] == "verified"
    assert verified["usage_balance"]["paid_session_credits_remaining"] == 5

    restored = data(
        client.post(
            "/api/v1/billing/apple/restore",
            headers={**auth, "Idempotency-Key": "idem-restore"},
        )
    )
    assert restored["restored_purchase_count"] == 1

    deleted = data(
        client.delete(
            "/api/v1/app-users/me/data",
            headers={**auth, "Idempotency-Key": "idem-delete-all"},
        )
    )
    assert deleted["deleted"] is True


def test_reusing_idempotency_key_on_different_write_returns_conflict():
    client = TestClient(create_app())
    _, auth = bootstrap(client)

    data(
        client.post(
            "/api/v1/billing/apple/restore",
            headers={**auth, "Idempotency-Key": "idem-shared"},
        )
    )
    response = client.post(
        "/api/v1/billing/apple/verify",
        json={
            "product_id": "coach_sprint_pack_01",
            "transaction_id": "apple_transaction_id",
            "original_transaction_id": "apple_original_transaction_id",
            "app_account_token": "00000000-0000-4000-8000-000000000000",
            "signed_transaction_info": "sandbox-jws",
            "environment": "sandbox",
        },
        headers={**auth, "Idempotency-Key": "idem-shared"},
    )

    assert response.status_code == 409
    assert error(response)["code"] == "IDEMPOTENCY_CONFLICT"
