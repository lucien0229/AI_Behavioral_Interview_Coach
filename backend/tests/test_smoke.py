from backend.smoke import run_smoke


def test_smoke_runner_exercises_resume_and_training_flow(tmp_path):
    resume_path = tmp_path / "resume.pdf"
    resume_path.write_bytes(b"%PDF smoke resume")
    client = RecordingHTTPClient(
        [
            envelope({"access_token": "token_1"}),
            envelope({"resume_id": "res_1", "status": "ready", "profile_quality_status": "usable"}),
            envelope({"session_id": "ses_1", "status": "question_generating"}),
            envelope(
                {
                    "session_id": "ses_1",
                    "status": "waiting_first_answer",
                    "question": {"question_text": "Tell me about a launch?", "training_focus": "ownership"},
                }
            ),
        ]
    )

    result = run_smoke(
        base_url="https://api.example.test/api/v1",
        resume_path=str(resume_path),
        client=client,
        installation_id="smoke-installation",
        idempotency_prefix="smoke-run",
    )

    assert result == {
        "resume_id": "res_1",
        "resume_status": "ready",
        "profile_quality_status": "usable",
        "session_id": "ses_1",
        "session_status": "waiting_first_answer",
    }
    assert client.calls == [
        {
            "method": "POST",
            "url": "https://api.example.test/api/v1/app-users/bootstrap",
            "json": {
                "installation_id": "smoke-installation",
                "platform": "ios",
                "locale": "en-US",
                "app_version": "smoke",
            },
            "headers": {"Idempotency-Key": "smoke-run-bootstrap"},
        },
        {
            "method": "POST",
            "url": "https://api.example.test/api/v1/resumes",
            "data": {"source_language": "en"},
            "files": {"file": ("resume.pdf", b"%PDF smoke resume", "application/pdf")},
            "headers": {"Authorization": "Bearer token_1", "Idempotency-Key": "smoke-run-resume"},
        },
        {
            "method": "POST",
            "url": "https://api.example.test/api/v1/training-sessions",
            "json": {"training_focus": "ownership"},
            "headers": {"Authorization": "Bearer token_1", "Idempotency-Key": "smoke-run-training"},
        },
        {
            "method": "GET",
            "url": "https://api.example.test/api/v1/training-sessions/ses_1",
            "headers": {"Authorization": "Bearer token_1"},
        },
    ]


class RecordingHTTPClient:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []

    def post(self, url, **kwargs):
        self.calls.append({"method": "POST", "url": url, **kwargs})
        return RecordingHTTPResponse(self.responses.pop(0))

    def get(self, url, **kwargs):
        self.calls.append({"method": "GET", "url": url, **kwargs})
        return RecordingHTTPResponse(self.responses.pop(0))


class RecordingHTTPResponse:
    def __init__(self, body):
        self.body = body

    def raise_for_status(self):
        return None

    def json(self):
        return self.body


def envelope(data):
    return {"request_id": "req_1", "data": data, "error": None}
