from __future__ import annotations

import json
from typing import Any

import httpx


DEFAULT_OPENAI_GENERATION_MODEL = "gpt-5"
DEFAULT_OPENAI_BASE_URL = "https://api.openai.com/v1"

INTERNAL_SCORE_FIELDS = [
    "question_fit",
    "resume_grounding",
    "story_selection",
    "structure",
    "action_specificity",
    "ownership_judgment",
    "decision_logic",
    "evidence_metrics",
    "outcome_reflection",
    "followup_robustness",
]

VISIBLE_ASSESSMENT_DIMENSIONS = {
    "answered_the_question": ["question_fit", "structure"],
    "story_fit": ["resume_grounding", "story_selection"],
    "personal_ownership": ["action_specificity", "ownership_judgment", "decision_logic"],
    "evidence_and_outcome": ["evidence_metrics", "outcome_reflection"],
    "holds_up_under_follow_up": ["followup_robustness"],
}

TRAINING_FOCUS_VALUES = [
    "ownership",
    "prioritization",
    "cross_functional_influence",
    "conflict_handling",
    "failure_learning",
    "ambiguity",
]


class OpenAITrainingContentProvider:
    def __init__(
        self,
        api_key: str,
        model: str = DEFAULT_OPENAI_GENERATION_MODEL,
        base_url: str = DEFAULT_OPENAI_BASE_URL,
        http_client: Any | None = None,
        timeout_seconds: float = 60.0,
    ):
        self.api_key = api_key
        self.model = model
        self.base_url = base_url.rstrip("/")
        self.http_client = http_client or httpx
        self.timeout_seconds = timeout_seconds

    def question_for_focus(self, focus: str) -> str:
        payload = self.create_structured_response(
            schema_name="question_payload",
            schema=QUESTION_SCHEMA,
            instructions=(
                "Generate exactly one English behavioral interview question. "
                "Use one interrogative only and return JSON only."
            ),
            user_input=f"TRAINING FOCUS: {focus}",
        )
        return str(payload["question_text"])

    def follow_up_for_focus(self, focus: str) -> str:
        payload = self.create_structured_response(
            schema_name="follow_up_payload",
            schema=FOLLOW_UP_SCHEMA,
            instructions=(
                "Generate exactly one English follow-up question targeting one answer gap. "
                "Use exactly one question mark and return JSON only."
            ),
            user_input=f"TRAINING FOCUS: {focus}",
        )
        return str(payload["follow_up_text"])

    def feedback(self) -> dict[str, Any]:
        payload = self.create_structured_response(
            schema_name="feedback_payload",
            schema=FEEDBACK_SCHEMA,
            instructions=(
                "Generate structured behavioral interview feedback. "
                "Return internal_scores and narrative fields only."
            ),
            user_input="Generate feedback for the completed answer sequence.",
        )
        return feedback_response_payload(payload)

    def redo_review(self) -> dict[str, str]:
        payload = self.create_structured_response(
            schema_name="redo_review_payload",
            schema=REDO_REVIEW_SCHEMA,
            instructions="Evaluate the redo answer and return JSON only.",
            user_input="Generate the redo review payload.",
        )
        redo_review = payload["redo_review"]
        return {
            "improvement_status": str(redo_review["improvement_status"]),
            "headline": str(redo_review["what_improved"]),
            "still_missing": str(redo_review["still_missing"]),
            "next_attempt": str(redo_review["next_practice_priority"]),
        }

    def create_structured_response(
        self,
        schema_name: str,
        schema: dict[str, Any],
        instructions: str,
        user_input: str,
    ) -> dict[str, Any]:
        response = self.http_client.post(
            f"{self.base_url}/responses",
            headers={"Authorization": f"Bearer {self.api_key}"},
            json={
                "model": self.model,
                "instructions": instructions,
                "input": user_input,
                "text": {
                    "format": {
                        "type": "json_schema",
                        "name": schema_name,
                        "strict": True,
                        "schema": schema,
                    }
                },
            },
            timeout=self.timeout_seconds,
        )
        response.raise_for_status()
        return json.loads(response_output_text(response.json()))


def response_output_text(response_payload: dict[str, Any]) -> str:
    output_text = response_payload.get("output_text")
    if isinstance(output_text, str):
        return output_text

    for output_item in response_payload.get("output", []):
        for content_item in output_item.get("content", []):
            text = content_item.get("text")
            if isinstance(text, str):
                return text

    raise RuntimeError("OpenAI response did not include output text.")


def feedback_response_payload(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "visible_assessments": visible_assessments_from_scores(payload["internal_scores"]),
        "strongest_signal": payload["strongest_signal"],
        "biggest_gap": payload["biggest_gap"],
        "why_it_matters": payload["why_it_matters"],
        "redo_priority": payload["redo_priority"],
        "redo_outline": payload["redo_outline"],
    }


def visible_assessments_from_scores(internal_scores: dict[str, int]) -> dict[str, str]:
    assessments = {}
    for name, fields in VISIBLE_ASSESSMENT_DIMENSIONS.items():
        average = sum(int(internal_scores[field]) for field in fields) / len(fields)
        assessments[name] = visible_assessment_status(average)
    return assessments


def visible_assessment_status(score: float) -> str:
    if score >= 4.5:
        return "Strong"
    if score >= 3.0:
        return "Mixed"
    return "Weak"


SCORE_SCHEMA = {"type": "integer", "minimum": 1, "maximum": 5}

INTERNAL_SCORES_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": INTERNAL_SCORE_FIELDS,
    "properties": {field: SCORE_SCHEMA for field in INTERNAL_SCORE_FIELDS},
}

QUESTION_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": [
        "question_id",
        "anchor_experience_ids",
        "training_focus",
        "resume_anchor_hint",
        "question_text",
        "internal_rationale",
        "expected_signal_targets",
    ],
    "properties": {
        "question_id": {"type": "string"},
        "anchor_experience_ids": {"type": "array", "items": {"type": "string"}, "minItems": 1},
        "training_focus": {"enum": TRAINING_FOCUS_VALUES},
        "resume_anchor_hint": {"type": "string", "minLength": 1, "maxLength": 120},
        "question_text": {"type": "string", "minLength": 1, "maxLength": 220},
        "internal_rationale": {"type": "string", "minLength": 1, "maxLength": 600},
        "expected_signal_targets": {"type": "array", "items": {"type": "string"}, "minItems": 1},
    },
}

FOLLOW_UP_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["follow_up_id", "target_gap", "follow_up_text", "internal_rationale"],
    "properties": {
        "follow_up_id": {"type": "string"},
        "target_gap": {
            "enum": [
                "question_fit",
                "action_specificity",
                "ownership_judgment",
                "decision_logic",
                "evidence_metrics",
            ]
        },
        "follow_up_text": {"type": "string", "minLength": 1, "maxLength": 180},
        "internal_rationale": {"type": "string", "minLength": 1, "maxLength": 600},
    },
}

FEEDBACK_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": [
        "internal_scores",
        "strongest_signal",
        "biggest_gap",
        "why_it_matters",
        "redo_priority",
        "redo_outline",
    ],
    "properties": {
        "internal_scores": INTERNAL_SCORES_SCHEMA,
        "strongest_signal": {"type": "string", "minLength": 1, "maxLength": 500},
        "biggest_gap": {"type": "string", "minLength": 1, "maxLength": 500},
        "why_it_matters": {"type": "string", "minLength": 1, "maxLength": 600},
        "redo_priority": {"type": "string", "minLength": 1, "maxLength": 700},
        "redo_outline": {"type": "array", "items": {"type": "string"}, "minItems": 3, "maxItems": 5},
    },
}

REDO_REVIEW_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["redo_review"],
    "properties": {
        "redo_review": {
            "type": "object",
            "additionalProperties": False,
            "required": [
                "improvement_status",
                "updated_internal_scores",
                "what_improved",
                "still_missing",
                "final_takeaway",
                "next_practice_priority",
            ],
            "properties": {
                "improvement_status": {
                    "enum": ["improved", "partially_improved", "not_improved", "regressed"],
                },
                "updated_internal_scores": INTERNAL_SCORES_SCHEMA,
                "what_improved": {"type": "string", "minLength": 1, "maxLength": 500},
                "still_missing": {"type": "string", "minLength": 1, "maxLength": 500},
                "final_takeaway": {"type": "string", "minLength": 1, "maxLength": 500},
                "next_practice_priority": {"type": "string", "minLength": 1, "maxLength": 500},
            },
        }
    },
}
