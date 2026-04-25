import json

from backend.ai_generation import OpenAITrainingContentProvider
from backend.config import create_providers_from_environment


def test_provider_config_builds_openai_training_content_provider(monkeypatch):
    monkeypatch.setenv("AIBIC_AI_PROVIDER", "openai")
    monkeypatch.setenv("AIBIC_OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("AIBIC_OPENAI_GENERATION_MODEL", "gpt-5.5")
    monkeypatch.setenv("AIBIC_OPENAI_BASE_URL", "https://api.example.test/v1")

    providers = create_providers_from_environment()

    assert isinstance(providers.training_content, OpenAITrainingContentProvider)
    assert providers.training_content.api_key == "test-key"
    assert providers.training_content.model == "gpt-5.5"
    assert providers.training_content.base_url == "https://api.example.test/v1"


def test_openai_training_content_provider_posts_strict_json_schema_request():
    http_client = RecordingHTTPClient(
        {
            "question_id": "q_001",
            "anchor_experience_ids": ["exp_001"],
            "training_focus": "ownership",
            "resume_anchor_hint": "Recent product launch",
            "question_text": "Tell me about a time you owned an ambiguous product decision?",
            "internal_rationale": "The focus asks for ownership.",
            "expected_signal_targets": ["ownership_judgment"],
        }
    )
    provider = OpenAITrainingContentProvider(
        api_key="test-key",
        model="gpt-5",
        base_url="https://api.example.test/v1",
        http_client=http_client,
    )

    question = provider.question_for_focus("ownership")

    request = http_client.calls[0]
    assert question == "Tell me about a time you owned an ambiguous product decision?"
    assert request["url"] == "https://api.example.test/v1/responses"
    assert request["headers"] == {"Authorization": "Bearer test-key"}
    assert request["json"]["model"] == "gpt-5"
    assert request["json"]["text"]["format"]["type"] == "json_schema"
    assert request["json"]["text"]["format"]["strict"] is True
    assert request["json"]["text"]["format"]["name"] == "question_payload"
    assert "question_text" in request["json"]["text"]["format"]["schema"]["required"]


def test_openai_training_content_provider_maps_feedback_scores_to_visible_assessments():
    http_client = RecordingHTTPClient(
        {
            "internal_scores": {
                "question_fit": 5,
                "resume_grounding": 4,
                "story_selection": 3,
                "structure": 4,
                "action_specificity": 2,
                "ownership_judgment": 3,
                "decision_logic": 2,
                "evidence_metrics": 5,
                "outcome_reflection": 5,
                "followup_robustness": 1,
            },
            "strongest_signal": "The answer names a real launch.",
            "biggest_gap": "The personal decision is still vague.",
            "why_it_matters": "Interviewers need to see individual judgment.",
            "redo_priority": "Name the decision and tradeoff first.",
            "redo_outline": ["Set context.", "Name the decision.", "Quantify the result."],
        }
    )
    provider = OpenAITrainingContentProvider(
        api_key="test-key",
        model="gpt-5",
        base_url="https://api.example.test/v1",
        http_client=http_client,
    )

    feedback = provider.feedback()

    assert feedback["visible_assessments"] == {
        "answered_the_question": "Strong",
        "story_fit": "Mixed",
        "personal_ownership": "Weak",
        "evidence_and_outcome": "Strong",
        "holds_up_under_follow_up": "Weak",
    }
    assert "internal_scores" not in feedback
    assert feedback["redo_outline"] == ["Set context.", "Name the decision.", "Quantify the result."]


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
        return RecordingHTTPResponse({"output_text": json_module_dumps(self.response_payload)})


class RecordingHTTPResponse:
    def __init__(self, json_body):
        self.json_body = json_body

    def raise_for_status(self):
        return None

    def json(self):
        return self.json_body


def json_module_dumps(value):
    return json.dumps(value)
