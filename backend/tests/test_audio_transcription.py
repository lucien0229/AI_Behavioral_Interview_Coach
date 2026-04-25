from fastapi.testclient import TestClient

from backend.app import BackendProviders, create_app
from backend.audio_transcription import OpenAIAudioTranscriber
from backend.config import create_providers_from_environment
from backend.tests.test_api_contract import bootstrap, data


def test_provider_config_builds_openai_audio_transcriber(monkeypatch):
    monkeypatch.setenv("AIBIC_ASR_PROVIDER", "openai")
    monkeypatch.setenv("AIBIC_OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("AIBIC_OPENAI_TRANSCRIPTION_MODEL", "gpt-4o-transcribe")
    monkeypatch.setenv("AIBIC_OPENAI_BASE_URL", "https://api.example.test/v1")

    providers = create_providers_from_environment()

    assert isinstance(providers.audio_transcriber, OpenAIAudioTranscriber)
    assert providers.audio_transcriber.api_key == "test-key"
    assert providers.audio_transcriber.model == "gpt-4o-transcribe"
    assert providers.audio_transcriber.base_url == "https://api.example.test/v1"


def test_openai_audio_transcriber_posts_audio_file_and_normalizes_result():
    http_client = RecordingHTTPClient({"text": "I led the launch.", "language": "en"})
    transcriber = OpenAIAudioTranscriber(
        api_key="test-key",
        model="gpt-4o-mini-transcribe",
        base_url="https://api.example.test/v1",
        http_client=http_client,
    )

    result = transcriber.transcribe(
        "first_answer",
        multipart_audio_body(file_name="answer.m4a", content_type="audio/mp4", body=b"audio-bytes"),
        3.25,
    )

    assert http_client.calls == [
        {
            "url": "https://api.example.test/v1/audio/transcriptions",
            "headers": {"Authorization": "Bearer test-key"},
            "data": {"model": "gpt-4o-mini-transcribe", "response_format": "json"},
            "files": {"file": ("answer.m4a", b"audio-bytes", "audio/mp4")},
            "timeout": 60.0,
        }
    ]
    assert result == {
        "text": "I led the launch.",
        "duration_seconds": 3.25,
        "transcript_status": "completed",
        "transcript_quality_status": "usable",
        "detected_language": "en",
        "word_count": 4,
    }


def test_non_usable_transcript_keeps_session_ready_for_rerecording():
    client = TestClient(
        create_app(
            providers=BackendProviders(
                audio_transcriber=QualityAudioTranscriber("too_short", detected_language="en"),
            )
        )
    )
    _, auth = bootstrap(client)
    data(
        client.post(
            "/api/v1/resumes",
            files={"file": ("alex_resume.pdf", b"%PDF synthetic resume", "application/pdf")},
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
    data(client.get(f"/api/v1/training-sessions/{created['session_id']}", headers=auth))

    retry = data(
        client.post(
            f"/api/v1/training-sessions/{created['session_id']}/first-answer",
            files={"audio_file": ("first.m4a", b"audio", "audio/mp4")},
            data={"duration_seconds": "3.25"},
            headers={**auth, "Idempotency-Key": "idem-first"},
        )
    )
    session = data(client.get(f"/api/v1/training-sessions/{created['session_id']}", headers=auth))

    assert retry == {
        "session_id": created["session_id"],
        "status": "waiting_first_answer",
        "transcript_status": "completed",
        "transcript_quality_status": "too_short",
        "error_code": "TRANSCRIPT_QUALITY_TOO_LOW",
        "detected_language": "en",
    }
    assert session["status"] == "waiting_first_answer"
    assert session["follow_up"] is None


def multipart_audio_body(file_name: str, content_type: str, body: bytes) -> bytes:
    return b"".join(
        [
            b"--boundary\r\n",
            f'Content-Disposition: form-data; name="audio_file"; filename="{file_name}"\r\n'.encode("utf-8"),
            f"Content-Type: {content_type}\r\n\r\n".encode("utf-8"),
            body,
            b"\r\n--boundary--\r\n",
        ]
    )


class RecordingHTTPClient:
    def __init__(self, json_body):
        self.json_body = json_body
        self.calls = []

    def post(self, url, headers, data, files, timeout):
        self.calls.append(
            {
                "url": url,
                "headers": headers,
                "data": data,
                "files": files,
                "timeout": timeout,
            }
        )
        return RecordingHTTPResponse(self.json_body)


class RecordingHTTPResponse:
    def __init__(self, json_body):
        self.json_body = json_body

    def raise_for_status(self):
        return None

    def json(self):
        return self.json_body


class QualityAudioTranscriber:
    def __init__(self, quality_status, detected_language=None):
        self.quality_status = quality_status
        self.detected_language = detected_language

    def transcribe(self, stage, raw_body, duration_seconds):
        transcript_status = "failed" if self.quality_status == "failed" else "completed"
        return {
            "duration_seconds": duration_seconds,
            "transcript_status": transcript_status,
            "transcript_quality_status": self.quality_status,
            "detected_language": self.detected_language,
        }
