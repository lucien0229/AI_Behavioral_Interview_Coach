from __future__ import annotations

import re
from typing import Any

import httpx


DEFAULT_OPENAI_BASE_URL = "https://api.openai.com/v1"
DEFAULT_OPENAI_TRANSCRIPTION_MODEL = "gpt-4o-mini-transcribe"


class OpenAIAudioTranscriber:
    def __init__(
        self,
        api_key: str,
        model: str = DEFAULT_OPENAI_TRANSCRIPTION_MODEL,
        base_url: str = DEFAULT_OPENAI_BASE_URL,
        http_client: Any | None = None,
        timeout_seconds: float = 60.0,
    ):
        self.api_key = api_key
        self.model = model
        self.base_url = base_url.rstrip("/")
        self.http_client = http_client or httpx
        self.timeout_seconds = timeout_seconds

    def transcribe(self, stage: str, raw_body: bytes, duration_seconds: float | None) -> dict[str, Any]:
        file_name, content_type, audio_bytes = multipart_file(raw_body, "audio_file")
        try:
            response = self.http_client.post(
                f"{self.base_url}/audio/transcriptions",
                headers={"Authorization": f"Bearer {self.api_key}"},
                data={"model": self.model, "response_format": "json"},
                files={"file": (file_name, audio_bytes, content_type)},
                timeout=self.timeout_seconds,
            )
            response.raise_for_status()
            payload = response.json()
        except httpx.HTTPError:
            return {
                "duration_seconds": duration_seconds,
                "transcript_status": "failed",
                "transcript_quality_status": "failed",
                "detected_language": None,
            }

        text = str(payload.get("text") or "").strip()
        quality_status = "usable" if text else "silent"
        return {
            "text": text,
            "duration_seconds": duration_seconds,
            "transcript_status": "completed",
            "transcript_quality_status": quality_status,
            "detected_language": payload.get("language"),
            "word_count": len(text.split()) if text else 0,
        }


def multipart_file(raw_body: bytes, field_name: str) -> tuple[str, str, bytes]:
    text = raw_body.decode("latin1", errors="ignore")
    disposition = re.search(rf'name="{re.escape(field_name)}"; filename="([^"]+)"', text)
    if not disposition:
        return f"{field_name}.m4a", "application/octet-stream", b""

    content_type = "application/octet-stream"
    content_type_match = re.search(
        rf'name="{re.escape(field_name)}"; filename="[^"]+"\r\nContent-Type: ([^\r\n]+)',
        text,
    )
    if content_type_match:
        content_type = content_type_match.group(1)

    body_start = re.search(
        rf'name="{re.escape(field_name)}"; filename="[^"]+"\r\nContent-Type: [^\r\n]+\r\n\r\n',
        text,
    )
    if not body_start:
        return disposition.group(1), content_type, b""

    boundary = text.split("\r\n", 1)[0]
    body_end = text.find(f"\r\n{boundary}", body_start.end())
    if body_end == -1:
        body_end = len(text)

    return disposition.group(1), content_type, text[body_start.end():body_end].encode("latin1")
