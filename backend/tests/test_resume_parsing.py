import base64
import json

from fastapi.testclient import TestClient

from backend.app import BackendProviders, create_app
from backend.config import create_providers_from_environment
from backend.resume_parsing import OpenAIResumeParser
from backend.tests.test_api_contract import bootstrap, data, error


def test_provider_config_builds_openai_resume_parser(monkeypatch):
    monkeypatch.setenv("AIBIC_RESUME_PARSER_PROVIDER", "openai")
    monkeypatch.setenv("AIBIC_OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("AIBIC_OPENAI_RESUME_MODEL", "gpt-5.5")
    monkeypatch.setenv("AIBIC_OPENAI_BASE_URL", "https://api.example.test/v1")

    providers = create_providers_from_environment()

    assert isinstance(providers.resume_parser, OpenAIResumeParser)
    assert providers.resume_parser.api_key == "test-key"
    assert providers.resume_parser.model == "gpt-5.5"
    assert providers.resume_parser.base_url == "https://api.example.test/v1"


def test_openai_resume_parser_posts_file_as_strict_schema_request():
    profile = resume_profile(["exp_001", "exp_002"])
    http_client = RecordingHTTPClient(profile)
    parser = OpenAIResumeParser(
        api_key="test-key",
        model="gpt-5",
        base_url="https://api.example.test/v1",
        http_client=http_client,
    )

    parsed = parser.parse(
        "resume.pdf",
        "en",
        multipart_resume_body(file_name="resume.pdf", content_type="application/pdf", body=b"%PDF resume bytes"),
    )

    request = http_client.calls[0]
    content = request["json"]["input"][0]["content"]
    assert parsed["status"] == "ready"
    assert parsed["profile_quality_status"] == "usable"
    assert parsed["profile"] == profile
    assert request["url"] == "https://api.example.test/v1/responses"
    assert request["headers"] == {"Authorization": "Bearer test-key"}
    assert request["json"]["model"] == "gpt-5"
    assert request["json"]["text"]["format"]["type"] == "json_schema"
    assert request["json"]["text"]["format"]["strict"] is True
    assert request["json"]["text"]["format"]["name"] == "resume_profile"
    assert "experience_units" in request["json"]["text"]["format"]["schema"]["required"]
    assert content[0] == {
        "type": "input_file",
        "filename": "resume.pdf",
        "file_data": base64.b64encode(b"%PDF resume bytes").decode("ascii"),
    }
    assert "SOURCE LANGUAGE: en" in content[1]["text"]


def test_unusable_resume_blocks_training_session_creation():
    client = TestClient(
        create_app(
            providers=BackendProviders(
                resume_parser=StaticResumeParser({"status": "ready", "profile_quality_status": "unusable"}),
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

    response = client.post(
        "/api/v1/training-sessions",
        json={"training_focus": "ownership"},
        headers={**auth, "Idempotency-Key": "idem-create"},
    )

    assert response.status_code == 409
    assert error(response)["code"] == "RESUME_PROFILE_UNUSABLE"


def resume_profile(anchor_ids):
    return {
        "candidate_summary": "Product leader with launch experience.",
        "likely_role_track": ["Product Manager"],
        "likely_seniority": "senior",
        "top_strength_signals": ["ownership"],
        "experience_units": [
            {
                "experience_id": experience_id,
                "company": "ExampleCo",
                "title": "Product Manager",
                "time_range": "2021-2024",
                "context_summary": "Led an ambiguous launch.",
                "candidate_actions": ["Prioritized scope."],
                "outcomes": ["Launched on time."],
                "metrics": ["20% adoption lift"],
                "stakeholders": ["Engineering"],
                "behavioral_signals": ["ownership"],
                "questionability": "high",
                "source_snippets": ["Led ambiguous launch."],
            }
            for experience_id in anchor_ids
        ],
        "recommended_anchor_experience_ids": anchor_ids,
        "global_signal_gaps": [],
    }


def multipart_resume_body(file_name: str, content_type: str, body: bytes) -> bytes:
    return b"".join(
        [
            b"--boundary\r\n",
            f'Content-Disposition: form-data; name="file"; filename="{file_name}"\r\n'.encode("utf-8"),
            f"Content-Type: {content_type}\r\n\r\n".encode("utf-8"),
            body,
            b"\r\n--boundary--\r\n",
        ]
    )


class RecordingHTTPClient:
    def __init__(self, response_payload):
        self.response_payload = response_payload
        self.calls = []

    def post(self, url, headers, json, timeout):
        self.calls.append(
            {
                "url": url,
                "headers": headers,
                "json": json,
                "timeout": timeout,
            }
        )
        return RecordingHTTPResponse({"output_text": json_dumps(self.response_payload)})


class RecordingHTTPResponse:
    def __init__(self, json_body):
        self.json_body = json_body

    def raise_for_status(self):
        return None

    def json(self):
        return self.json_body


class StaticResumeParser:
    def __init__(self, parsed_resume):
        self.parsed_resume = parsed_resume

    def parse(self, file_name, source_language, raw_body):
        return self.parsed_resume


def json_dumps(value):
    return json.dumps(value)
