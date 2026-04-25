from __future__ import annotations

import mimetypes
import os
import time
from typing import Any

import httpx


DEFAULT_BASE_URL = "http://127.0.0.1:8000/api/v1"


def run_smoke(
    base_url: str,
    resume_path: str,
    client: Any | None = None,
    installation_id: str | None = None,
    idempotency_prefix: str | None = None,
    training_focus: str = "ownership",
    source_language: str = "en",
) -> dict[str, Any]:
    client = client or httpx.Client(timeout=120.0)
    installation_id = installation_id or f"smoke-{int(time.time())}"
    idempotency_prefix = idempotency_prefix or installation_id
    base_url = base_url.rstrip("/")

    bootstrap = unwrap(
        client.post(
            f"{base_url}/app-users/bootstrap",
            json={
                "installation_id": installation_id,
                "platform": "ios",
                "locale": "en-US",
                "app_version": "smoke",
            },
            headers={"Idempotency-Key": f"{idempotency_prefix}-bootstrap"},
        )
    )
    auth = {"Authorization": f"Bearer {bootstrap['access_token']}"}

    with open(resume_path, "rb") as resume_file:
        resume_bytes = resume_file.read()

    resume_file_name = os.path.basename(resume_path)
    resume = unwrap(
        client.post(
            f"{base_url}/resumes",
            data={"source_language": source_language},
            files={
                "file": (
                    resume_file_name,
                    resume_bytes,
                    mimetypes.guess_type(resume_file_name)[0] or "application/octet-stream",
                )
            },
            headers={**auth, "Idempotency-Key": f"{idempotency_prefix}-resume"},
        )
    )

    created = unwrap(
        client.post(
            f"{base_url}/training-sessions",
            json={"training_focus": training_focus},
            headers={**auth, "Idempotency-Key": f"{idempotency_prefix}-training"},
        )
    )
    session = unwrap(
        client.get(
            f"{base_url}/training-sessions/{created['session_id']}",
            headers=auth,
        )
    )

    return {
        "resume_id": resume["resume_id"],
        "resume_status": resume["status"],
        "profile_quality_status": resume["profile_quality_status"],
        "session_id": session["session_id"],
        "session_status": session["status"],
    }


def unwrap(response) -> dict[str, Any]:
    response.raise_for_status()
    body = response.json()
    if body.get("error"):
        error = body["error"]
        raise RuntimeError(f"{error.get('code')}: {error.get('message')}")
    return body["data"]


def main() -> None:
    resume_path = os.getenv("AIBIC_SMOKE_RESUME_PATH")
    if not resume_path:
        raise RuntimeError("AIBIC_SMOKE_RESUME_PATH is required.")

    result = run_smoke(
        base_url=os.getenv("AIBIC_SMOKE_API_BASE_URL", DEFAULT_BASE_URL),
        resume_path=resume_path,
        installation_id=os.getenv("AIBIC_SMOKE_INSTALLATION_ID"),
        idempotency_prefix=os.getenv("AIBIC_SMOKE_IDEMPOTENCY_PREFIX"),
        training_focus=os.getenv("AIBIC_SMOKE_TRAINING_FOCUS", "ownership"),
        source_language=os.getenv("AIBIC_SMOKE_SOURCE_LANGUAGE", "en"),
    )
    print(result)


if __name__ == "__main__":
    main()
