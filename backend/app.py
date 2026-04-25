from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from backend.file_storage import InMemoryFileStorage
from backend.state_store import SQLiteStateStore


API_PREFIX = "/api/v1"
PRODUCT_ID = "coach_sprint_pack_01"
SESSION_PACK_CREDITS = 5


class APIError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400, details: dict[str, Any] | None = None):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details or {}


@dataclass
class APIReply:
    status_code: int
    body: dict[str, Any]


@dataclass
class IdempotencyRecord:
    signature: str
    status_code: int
    body: dict[str, Any]


@dataclass
class ResumeRecord:
    resume_id: str
    file_name: str
    status: str = "ready"
    profile_quality_status: str = "usable"
    source_language: str = "en"
    deleted: bool = False
    storage_key: str | None = None


@dataclass
class TrainingSessionRecord:
    session_id: str
    training_focus: str
    question_text: str
    status: str = "question_generating"
    follow_up_text: str | None = None
    feedback: dict[str, Any] | None = None
    redo_review: dict[str, Any] | None = None
    completion_reason: str | None = None
    completed_at: str | None = None
    credit_state: str = "reserved"
    billing_source: str = "free"
    reserved_credit_source: str | None = "free"
    redo_submitted: bool = False
    deleted: bool = False
    audio_storage_keys: dict[str, str] = field(default_factory=dict)


@dataclass
class AppUser:
    app_user_id: str
    installation_id: str
    access_token: str
    app_account_token: str
    free_session_credits_remaining: int = 2
    paid_session_credits_remaining: int = 0
    reserved_session_credits: int = 0
    active_resume_id: str | None = None
    active_session_id: str | None = None
    resumes: dict[str, ResumeRecord] = field(default_factory=dict)
    sessions: dict[str, TrainingSessionRecord] = field(default_factory=dict)
    purchases: dict[str, dict[str, Any]] = field(default_factory=dict)


class MockResumeParser:
    def parse(self, file_name: str, source_language: str, raw_body: bytes) -> dict[str, str]:
        return {
            "status": "ready",
            "profile_quality_status": "usable",
        }


class MockTrainingContentProvider:
    def question_for_focus(self, focus: str) -> str:
        return question_for_focus(focus)

    def follow_up_for_focus(self, focus: str) -> str:
        return follow_up_for_focus(focus)

    def feedback(self) -> dict[str, Any]:
        return feedback_payload()

    def redo_review(self) -> dict[str, str]:
        return redo_review_payload()


class MockAudioTranscriber:
    def transcribe(self, stage: str, raw_body: bytes, duration_seconds: float | None) -> dict[str, Any]:
        return {
            "text": "",
            "duration_seconds": duration_seconds,
        }


class MockPurchaseVerifier:
    def verify(self, payload: dict[str, Any]) -> dict[str, Any]:
        if payload.get("product_id") != PRODUCT_ID:
            raise APIError("APPLE_PURCHASE_VERIFICATION_FAILED", "The product id is not recognized.", 400)
        return {
            "product_id": PRODUCT_ID,
            "transaction_id": str(payload.get("transaction_id") or ""),
            "session_credits": SESSION_PACK_CREDITS,
        }


@dataclass
class BackendProviders:
    resume_parser: Any = field(default_factory=MockResumeParser)
    training_content: Any = field(default_factory=MockTrainingContentProvider)
    audio_transcriber: Any = field(default_factory=MockAudioTranscriber)
    purchase_verifier: Any = field(default_factory=MockPurchaseVerifier)
    file_storage: Any = field(default_factory=InMemoryFileStorage)


class BackendState:
    def __init__(self, store: Any | None = None) -> None:
        self.store = store
        self.users_by_installation: dict[str, AppUser] = {}
        self.users_by_token: dict[str, AppUser] = {}
        self.idempotency_records: dict[tuple[str, str], IdempotencyRecord] = {}
        self.counters: dict[str, int] = {}
        if self.store:
            self.restore(self.store.load())

    def next_id(self, prefix: str) -> str:
        self.counters[prefix] = self.counters.get(prefix, 0) + 1
        return f"{prefix}_{self.counters[prefix]:06d}"

    def request_id(self) -> str:
        return self.next_id("req")

    def success(self, data: Any, status_code: int = 200) -> APIReply:
        return APIReply(
            status_code=status_code,
            body={
                "request_id": self.request_id(),
                "data": data,
                "error": None,
            },
        )

    def failure(self, error: APIError) -> APIReply:
        return APIReply(
            status_code=error.status_code,
            body={
                "request_id": self.request_id(),
                "data": None,
                "error": {
                    "code": error.code,
                    "message": error.message,
                    "details": error.details,
                },
            },
        )

    def as_response(self, reply: APIReply) -> JSONResponse:
        return JSONResponse(status_code=reply.status_code, content=reply.body)

    def error_response(
        self,
        code: str,
        message: str,
        status_code: int = 400,
        details: dict[str, Any] | None = None,
    ) -> JSONResponse:
        return self.as_response(self.failure(APIError(code, message, status_code, details)))

    async def idempotent(
        self,
        request: Request,
        scope: str,
        action: Callable[[bytes], APIReply],
    ) -> JSONResponse:
        key = request.headers.get("Idempotency-Key")
        if not key:
            return self.error_response("IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key header is required.", 400)

        raw_body = await request.body()
        signature = self.idempotency_signature(request, raw_body)
        record_key = (scope, key)
        existing = self.idempotency_records.get(record_key)
        if existing:
            if existing.signature != signature:
                return self.error_response(
                    "IDEMPOTENCY_CONFLICT",
                    "The same Idempotency-Key was reused for a different write request.",
                    409,
                )
            return JSONResponse(status_code=existing.status_code, content=existing.body)

        try:
            reply = action(raw_body)
        except APIError as error:
            reply = self.failure(error)

        self.idempotency_records[record_key] = IdempotencyRecord(
            signature=signature,
            status_code=reply.status_code,
            body=reply.body,
        )
        self.persist()
        return self.as_response(reply)

    def idempotency_signature(self, request: Request, raw_body: bytes) -> str:
        digest = hashlib.sha256(raw_body).hexdigest()
        return f"{request.method.upper()} {request.url.path} {digest}"

    def authenticate(self, request: Request) -> AppUser:
        authorization = request.headers.get("Authorization", "")
        prefix = "Bearer "
        if not authorization.startswith(prefix):
            raise APIError("UNAUTHORIZED", "A bearer access token is required.", 401)
        token = authorization[len(prefix):]
        user = self.users_by_token.get(token)
        if not user:
            raise APIError("UNAUTHORIZED", "The bearer access token is invalid or expired.", 401)
        return user

    def get_or_create_user(self, installation_id: str) -> AppUser:
        if installation_id in self.users_by_installation:
            return self.users_by_installation[installation_id]

        user_number = self.counters.get("usr", 0) + 1
        app_user_id = self.next_id("usr")
        user = AppUser(
            app_user_id=app_user_id,
            installation_id=installation_id,
            access_token=f"access_token_{app_user_id}",
            app_account_token=f"11111111-1111-4111-8111-{user_number:012d}",
        )
        self.users_by_installation[installation_id] = user
        self.users_by_token[user.access_token] = user
        return user

    def persist(self) -> None:
        if self.store:
            self.store.save(self.snapshot())

    def snapshot(self) -> dict[str, Any]:
        return {
            "counters": self.counters,
            "users": [serialize_user(user) for user in self.users_by_installation.values()],
            "idempotency_records": [
                {
                    "scope": scope,
                    "key": key,
                    "signature": record.signature,
                    "status_code": record.status_code,
                    "body": record.body,
                }
                for (scope, key), record in self.idempotency_records.items()
            ],
        }

    def restore(self, snapshot: dict[str, Any] | None) -> None:
        if not snapshot:
            return

        self.counters = {key: int(value) for key, value in snapshot.get("counters", {}).items()}
        for raw_user in snapshot.get("users", []):
            user = deserialize_user(raw_user)
            self.users_by_installation[user.installation_id] = user
            self.users_by_token[user.access_token] = user

        for raw_record in snapshot.get("idempotency_records", []):
            self.idempotency_records[(raw_record["scope"], raw_record["key"])] = IdempotencyRecord(
                signature=raw_record["signature"],
                status_code=int(raw_record["status_code"]),
                body=raw_record["body"],
            )


def serialize_user(user: AppUser) -> dict[str, Any]:
    return {
        "app_user_id": user.app_user_id,
        "installation_id": user.installation_id,
        "access_token": user.access_token,
        "app_account_token": user.app_account_token,
        "free_session_credits_remaining": user.free_session_credits_remaining,
        "paid_session_credits_remaining": user.paid_session_credits_remaining,
        "reserved_session_credits": user.reserved_session_credits,
        "active_resume_id": user.active_resume_id,
        "active_session_id": user.active_session_id,
        "resumes": {resume_id: vars(resume) for resume_id, resume in user.resumes.items()},
        "sessions": {session_id: vars(session) for session_id, session in user.sessions.items()},
        "purchases": user.purchases,
    }


def deserialize_user(raw_user: dict[str, Any]) -> AppUser:
    user = AppUser(
        app_user_id=raw_user["app_user_id"],
        installation_id=raw_user["installation_id"],
        access_token=raw_user["access_token"],
        app_account_token=raw_user["app_account_token"],
        free_session_credits_remaining=int(raw_user.get("free_session_credits_remaining", 2)),
        paid_session_credits_remaining=int(raw_user.get("paid_session_credits_remaining", 0)),
        reserved_session_credits=int(raw_user.get("reserved_session_credits", 0)),
        active_resume_id=raw_user.get("active_resume_id"),
        active_session_id=raw_user.get("active_session_id"),
        purchases=raw_user.get("purchases", {}),
    )
    user.resumes = {
        resume_id: ResumeRecord(
            resume_id=resume["resume_id"],
            file_name=resume["file_name"],
            status=resume.get("status", "ready"),
            profile_quality_status=resume.get("profile_quality_status", "usable"),
            source_language=resume.get("source_language", "en"),
            deleted=bool(resume.get("deleted", False)),
            storage_key=resume.get("storage_key"),
        )
        for resume_id, resume in raw_user.get("resumes", {}).items()
    }
    user.sessions = {
        session_id: TrainingSessionRecord(
            session_id=session["session_id"],
            training_focus=session["training_focus"],
            question_text=session["question_text"],
            status=session.get("status", "question_generating"),
            follow_up_text=session.get("follow_up_text"),
            feedback=session.get("feedback"),
            redo_review=session.get("redo_review"),
            completion_reason=session.get("completion_reason"),
            completed_at=session.get("completed_at"),
            credit_state=session.get("credit_state", "reserved"),
            billing_source=session.get("billing_source", "free"),
            reserved_credit_source=session.get("reserved_credit_source"),
            redo_submitted=bool(session.get("redo_submitted", False)),
            deleted=bool(session.get("deleted", False)),
            audio_storage_keys=session.get("audio_storage_keys", {}),
        )
        for session_id, session in raw_user.get("sessions", {}).items()
    }
    return user


def create_app(
    database_path: str | None = None,
    providers: BackendProviders | None = None,
    state_store: Any | None = None,
) -> FastAPI:
    if state_store is None and database_path:
        state_store = SQLiteStateStore(database_path)
    state = BackendState(store=state_store)
    providers = providers or BackendProviders()
    app = FastAPI(title="AI Behavioral Interview Coach API", version="1.1.0-mvp")

    @app.post(f"{API_PREFIX}/app-users/bootstrap")
    async def bootstrap(request: Request) -> JSONResponse:
        def action(raw_body: bytes) -> APIReply:
            payload = json_payload(raw_body)
            installation_id = payload.get("installation_id")
            if not installation_id:
                raise APIError("VALIDATION_FAILED", "installation_id is required.", 422)

            user = state.get_or_create_user(str(installation_id))
            return state.success(bootstrap_payload(user))

        return await state.idempotent(request, "bootstrap", action)

    @app.get(f"{API_PREFIX}/home")
    async def home(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
            return state.as_response(state.success(home_payload(user)))
        except APIError as error:
            return state.as_response(state.failure(error))

    @app.post(f"{API_PREFIX}/resumes")
    async def upload_resume(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(raw_body: bytes) -> APIReply:
            file_name = multipart_file_name(raw_body, "file") or "resume.pdf"
            source_language = multipart_field_value(raw_body, "source_language") or "en"
            extension = file_name.rsplit(".", 1)[-1].lower() if "." in file_name else ""
            if extension not in {"pdf", "docx"}:
                raise APIError("UNSUPPORTED_FILE_TYPE", "Only PDF and DOCX resumes are supported.", 415)

            parsed_resume = providers.resume_parser.parse(file_name, source_language, raw_body)
            resume_id = state.next_id("res")
            storage_key = providers.file_storage.save_upload(
                kind="resumes",
                owner_id=user.app_user_id,
                object_id=resume_id,
                file_name=file_name,
                data=multipart_file_bytes(raw_body, "file"),
                content_type=multipart_file_content_type(raw_body, "file"),
            )
            resume = ResumeRecord(
                resume_id=resume_id,
                file_name=file_name,
                status=str(provider_field(parsed_resume, "status", "ready")),
                profile_quality_status=str(provider_field(parsed_resume, "profile_quality_status", "usable")),
                source_language=source_language,
                storage_key=storage_key,
            )
            user.resumes[resume.resume_id] = resume
            user.active_resume_id = resume.resume_id
            return state.success(resume_payload(resume))

        return await state.idempotent(request, user.app_user_id, action)

    @app.get(f"{API_PREFIX}/resumes/active")
    async def get_active_resume(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
            resume = active_resume(user)
            if not resume:
                raise APIError("ACTIVE_RESUME_REQUIRED", "No active resume exists.", 404)
            return state.as_response(state.success(resume_payload(resume)))
        except APIError as error:
            return state.as_response(state.failure(error))

    @app.delete(f"{API_PREFIX}/resumes/active")
    async def delete_active_resume(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(raw_body: bytes) -> APIReply:
            payload = json_payload(raw_body) if raw_body else {}
            delete_mode = payload.get("delete_mode", "resume_only_redacted_history")
            if user.active_resume_id and user.active_resume_id in user.resumes:
                delete_storage_keys(providers.file_storage, [user.resumes[user.active_resume_id].storage_key])
                user.resumes[user.active_resume_id].deleted = True
            user.active_resume_id = None

            if delete_mode == "resume_and_linked_training":
                for session in user.sessions.values():
                    delete_storage_keys(providers.file_storage, session.audio_storage_keys.values())
                    if session.credit_state == "reserved":
                        release_reserved_credit(user, session)
                    session.deleted = True
                user.active_session_id = None

            return state.success({"deleted": True})

        return await state.idempotent(request, user.app_user_id, action)

    @app.get(f"{API_PREFIX}/resumes/{{resume_id}}")
    async def get_resume(resume_id: str, request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
            resume = user.resumes.get(resume_id)
            if not resume or resume.deleted:
                raise APIError("RESUME_NOT_FOUND", "Resume was not found.", 404)
            return state.as_response(state.success(resume_payload(resume)))
        except APIError as error:
            return state.as_response(state.failure(error))

    @app.post(f"{API_PREFIX}/training-sessions")
    async def create_training_session(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(raw_body: bytes) -> APIReply:
            resume = active_resume(user)
            if not resume:
                raise APIError("ACTIVE_RESUME_REQUIRED", "A ready resume is required before training.", 409)
            if resume.profile_quality_status == "unusable":
                raise APIError("RESUME_PROFILE_UNUSABLE", "The active resume does not contain enough trainable evidence.", 409)
            if resume.status != "ready":
                raise APIError("RESUME_NOT_READY", "The active resume is not ready for training.", 409)
            if current_active_session(user):
                raise APIError("ACTIVE_SESSION_EXISTS", "An active training session already exists.", 409)

            payload = json_payload(raw_body) if raw_body else {}
            focus = str(payload.get("training_focus") or "ownership")
            billing_source = reserve_credit(user)
            session = TrainingSessionRecord(
                session_id=state.next_id("ses"),
                training_focus=focus,
                question_text=providers.training_content.question_for_focus(focus),
                billing_source=billing_source,
                reserved_credit_source=billing_source,
            )
            user.sessions[session.session_id] = session
            user.active_session_id = session.session_id
            return state.success(session_mutation_payload(session))

        return await state.idempotent(request, user.app_user_id, action)

    @app.get(f"{API_PREFIX}/training-sessions/history")
    async def training_history(request: Request, limit: int = 10) -> JSONResponse:
        try:
            user = state.authenticate(request)
            items = [history_item_payload(session) for session in history_sessions(user)[: max(1, min(limit, 50))]]
            return state.as_response(state.success({"items": items}))
        except APIError as error:
            return state.as_response(state.failure(error))

    @app.get(f"{API_PREFIX}/training-sessions/{{session_id}}")
    async def get_training_session(session_id: str, request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
            session = require_session(user, session_id)
            advance_session_on_read(user, session, providers)
            state.persist()
            return state.as_response(state.success(session_detail_payload(session)))
        except APIError as error:
            return state.as_response(state.failure(error))

    @app.delete(f"{API_PREFIX}/training-sessions/{{session_id}}")
    async def delete_training_session(session_id: str, request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(_: bytes) -> APIReply:
            session = require_session(user, session_id)
            if session.credit_state == "reserved":
                release_reserved_credit(user, session)
            delete_storage_keys(providers.file_storage, session.audio_storage_keys.values())
            session.deleted = True
            if user.active_session_id == session.session_id:
                user.active_session_id = None
            return state.success({"deleted": True})

        return await state.idempotent(request, user.app_user_id, action)

    @app.post(f"{API_PREFIX}/training-sessions/{{session_id}}/first-answer")
    async def submit_first_answer(session_id: str, request: Request) -> JSONResponse:
        return await mutate_session_with_audio(
            state,
            request,
            session_id,
            expected_status="waiting_first_answer",
            next_status="first_answer_processing",
            providers=providers,
        )

    @app.post(f"{API_PREFIX}/training-sessions/{{session_id}}/follow-up-answer")
    async def submit_follow_up_answer(session_id: str, request: Request) -> JSONResponse:
        return await mutate_session_with_audio(
            state,
            request,
            session_id,
            expected_status="waiting_followup_answer",
            next_status="followup_answer_processing",
            providers=providers,
        )

    @app.post(f"{API_PREFIX}/training-sessions/{{session_id}}/redo")
    async def submit_redo(session_id: str, request: Request) -> JSONResponse:
        return await mutate_session_with_audio(
            state,
            request,
            session_id,
            expected_status="redo_available",
            next_status="redo_processing",
            mark_redo_submitted=True,
            providers=providers,
        )

    @app.post(f"{API_PREFIX}/training-sessions/{{session_id}}/skip-redo")
    async def skip_redo(session_id: str, request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(_: bytes) -> APIReply:
            session = require_session(user, session_id)
            advance_session_on_read(user, session, providers)
            if session.status != "redo_available":
                raise APIError("TRAINING_SESSION_NOT_READY", "Redo can only be skipped after feedback is ready.", 409)
            session.status = "completed"
            session.completion_reason = "redo_skipped"
            session.completed_at = utc_now()
            session.redo_submitted = False
            if user.active_session_id == session.session_id:
                user.active_session_id = None
            return state.success(session_mutation_payload(session))

        return await state.idempotent(request, user.app_user_id, action)

    @app.post(f"{API_PREFIX}/training-sessions/{{session_id}}/abandon")
    async def abandon_session(session_id: str, request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(_: bytes) -> APIReply:
            session = require_session(user, session_id)
            if session.status in {"redo_available", "redo_processing", "completed", "abandoned", "failed"}:
                raise APIError("TRAINING_SESSION_NOT_READY", "Only pre-feedback sessions can be abandoned.", 409)
            if session.credit_state == "reserved":
                release_reserved_credit(user, session)
            session.status = "abandoned"
            session.completion_reason = None
            if user.active_session_id == session.session_id:
                user.active_session_id = None
            return state.success(session_mutation_payload(session))

        return await state.idempotent(request, user.app_user_id, action)

    @app.get(f"{API_PREFIX}/billing/entitlement")
    async def billing_entitlement(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
            return state.as_response(
                state.success(
                    {
                        "app_account_token": user.app_account_token,
                        "usage_balance": usage_balance_payload(user),
                        "products": [
                            {
                                "product_id": PRODUCT_ID,
                                "session_credits": SESSION_PACK_CREDITS,
                                "display_name": "Sprint Pack",
                            }
                        ],
                    }
                )
            )
        except APIError as error:
            return state.as_response(state.failure(error))

    @app.post(f"{API_PREFIX}/billing/apple/verify")
    async def verify_purchase(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(raw_body: bytes) -> APIReply:
            payload = json_payload(raw_body)
            verification = providers.purchase_verifier.verify(payload)

            transaction_id = str(provider_field(verification, "transaction_id", payload.get("transaction_id") or state.next_id("txn")))
            session_credits = int(provider_field(verification, "session_credits", SESSION_PACK_CREDITS))
            purchase = user.purchases.get(transaction_id)
            if not purchase:
                purchase = {
                    "purchase_id": state.next_id("pur"),
                    "transaction_id": transaction_id,
                    "product_id": PRODUCT_ID,
                    "verified_at": utc_now(),
                }
                user.purchases[transaction_id] = purchase
                user.paid_session_credits_remaining += session_credits

            return state.success(
                {
                    "purchase_id": purchase["purchase_id"],
                    "status": "verified",
                    "usage_balance": usage_balance_payload(user),
                }
            )

        return await state.idempotent(request, user.app_user_id, action)

    @app.post(f"{API_PREFIX}/billing/apple/restore")
    async def restore_purchase(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(_: bytes) -> APIReply:
            return state.success(
                {
                    "restored_purchase_count": len(user.purchases),
                    "usage_balance": usage_balance_payload(user),
                }
            )

        return await state.idempotent(request, user.app_user_id, action)

    @app.delete(f"{API_PREFIX}/app-users/me/data")
    async def delete_all_data(request: Request) -> JSONResponse:
        try:
            user = state.authenticate(request)
        except APIError as error:
            return state.as_response(state.failure(error))

        def action(_: bytes) -> APIReply:
            delete_storage_keys(providers.file_storage, user_storage_keys(user))
            user.resumes.clear()
            user.sessions.clear()
            user.purchases.clear()
            user.active_resume_id = None
            user.active_session_id = None
            user.free_session_credits_remaining = 2
            user.paid_session_credits_remaining = 0
            user.reserved_session_credits = 0
            return state.success({"deleted": True})

        return await state.idempotent(request, user.app_user_id, action)

    return app


async def mutate_session_with_audio(
    state: BackendState,
    request: Request,
    session_id: str,
    expected_status: str,
    next_status: str,
    providers: BackendProviders,
    mark_redo_submitted: bool = False,
) -> JSONResponse:
    try:
        user = state.authenticate(request)
    except APIError as error:
        return state.as_response(state.failure(error))

    def action(raw_body: bytes) -> APIReply:
        session = require_session(user, session_id)
        advance_session_on_read(user, session, providers)
        if session.status != expected_status:
            raise APIError("TRAINING_SESSION_NOT_READY", "The training session is not ready for this upload.", 409)
        transcription = providers.audio_transcriber.transcribe(
            audio_stage_for_status(next_status),
            raw_body,
            parse_duration_seconds(raw_body),
        )
        if not transcript_is_usable(transcription):
            return state.success(transcript_retry_payload(session, expected_status, transcription))

        audio_stage = audio_stage_for_status(next_status)
        audio_file_name = multipart_file_name(raw_body, "audio_file") or f"{audio_stage}.m4a"
        session.audio_storage_keys[audio_stage] = providers.file_storage.save_upload(
            kind="audio",
            owner_id=user.app_user_id,
            object_id=f"{session.session_id}-{audio_stage}",
            file_name=audio_file_name,
            data=multipart_file_bytes(raw_body, "audio_file"),
            content_type=multipart_file_content_type(raw_body, "audio_file"),
        )
        session.status = next_status
        if mark_redo_submitted:
            session.redo_submitted = True
        return state.success(session_mutation_payload(session))

    return await state.idempotent(request, user.app_user_id, action)


def transcript_is_usable(transcription: Any) -> bool:
    return provider_field(transcription, "transcript_quality_status", "usable") == "usable"


def transcript_retry_payload(
    session: TrainingSessionRecord,
    retry_status: str,
    transcription: Any,
) -> dict[str, Any]:
    quality_status = str(provider_field(transcription, "transcript_quality_status", "failed"))
    transcript_status = str(
        provider_field(
            transcription,
            "transcript_status",
            "failed" if quality_status == "failed" else "completed",
        )
    )
    return {
        "session_id": session.session_id,
        "status": retry_status,
        "transcript_status": transcript_status,
        "transcript_quality_status": quality_status,
        "error_code": transcript_error_code(quality_status),
        "detected_language": provider_field(transcription, "detected_language", None),
    }


def transcript_error_code(quality_status: str) -> str:
    if quality_status == "failed":
        return "TRANSCRIPTION_FAILED"
    return "TRANSCRIPT_QUALITY_TOO_LOW"


def json_payload(raw_body: bytes) -> dict[str, Any]:
    if not raw_body:
        return {}
    try:
        payload = json.loads(raw_body.decode("utf-8"))
    except json.JSONDecodeError as error:
        raise APIError("INVALID_JSON", "Request body must be valid JSON.", 400) from error
    if not isinstance(payload, dict):
        raise APIError("INVALID_JSON", "Request body must be a JSON object.", 400)
    return payload


def multipart_file_name(raw_body: bytes, field_name: str) -> str | None:
    text = raw_body.decode("latin1", errors="ignore")
    match = re.search(rf'name="{re.escape(field_name)}"; filename="([^"]+)"', text)
    return match.group(1) if match else None


def multipart_file_content_type(raw_body: bytes, field_name: str) -> str | None:
    text = raw_body.decode("latin1", errors="ignore")
    match = re.search(
        rf'name="{re.escape(field_name)}"; filename="[^"]+"\r\nContent-Type: ([^\r\n]+)',
        text,
    )
    return match.group(1) if match else None


def multipart_file_bytes(raw_body: bytes, field_name: str) -> bytes:
    text = raw_body.decode("latin1", errors="ignore")
    match = re.search(
        rf'name="{re.escape(field_name)}"; filename="[^"]+"\r\nContent-Type: [^\r\n]+\r\n\r\n',
        text,
    )
    if not match:
        return b""
    boundary = text.split("\r\n", 1)[0]
    end = text.find(f"\r\n{boundary}", match.end())
    if end == -1:
        end = len(text)
    return text[match.end():end].encode("latin1")


def multipart_field_value(raw_body: bytes, field_name: str) -> str | None:
    text = raw_body.decode("latin1", errors="ignore")
    match = re.search(rf'name="{re.escape(field_name)}"\r\n\r\n([^\r\n]*)', text)
    return match.group(1) if match else None


def provider_field(result: Any, field_name: str, default: Any) -> Any:
    if isinstance(result, dict):
        return result.get(field_name, default)
    return getattr(result, field_name, default)


def user_storage_keys(user: AppUser) -> list[str | None]:
    keys: list[str | None] = []
    for resume in user.resumes.values():
        keys.append(resume.storage_key)
    for session in user.sessions.values():
        keys.extend(session.audio_storage_keys.values())
    return keys


def delete_storage_keys(file_storage: Any, keys: Any) -> None:
    for key in keys:
        if key:
            file_storage.delete(key)


def parse_duration_seconds(raw_body: bytes) -> float | None:
    raw_duration = multipart_field_value(raw_body, "duration_seconds")
    if raw_duration is None:
        return None
    try:
        return float(raw_duration)
    except ValueError:
        return None


def audio_stage_for_status(next_status: str) -> str:
    if next_status == "first_answer_processing":
        return "first_answer"
    if next_status == "followup_answer_processing":
        return "follow_up_answer"
    if next_status == "redo_processing":
        return "redo"
    return next_status


def bootstrap_payload(user: AppUser) -> dict[str, Any]:
    return {
        "app_user_id": user.app_user_id,
        "access_token": user.access_token,
        "expires_at": "2099-01-01T00:00:00Z",
        "app_account_token": user.app_account_token,
        "usage_balance": usage_balance_payload(user),
        "active_resume": resume_payload(active_resume(user)) if active_resume(user) else None,
        "active_session": session_summary_payload(current_active_session(user)) if current_active_session(user) else None,
    }


def home_payload(user: AppUser) -> dict[str, Any]:
    history = history_sessions(user)
    return {
        "app_user_id": user.app_user_id,
        "usage_balance": usage_balance_payload(user),
        "active_resume": resume_payload(active_resume(user)) if active_resume(user) else None,
        "active_session": session_summary_payload(current_active_session(user)) if current_active_session(user) else None,
        "last_training_summary": history_item_payload(history[0]) if history else None,
    }


def usage_balance_payload(user: AppUser) -> dict[str, int]:
    return {
        "free_session_credits_remaining": user.free_session_credits_remaining,
        "paid_session_credits_remaining": user.paid_session_credits_remaining,
        "reserved_session_credits": user.reserved_session_credits,
    }


def active_resume(user: AppUser) -> ResumeRecord | None:
    if not user.active_resume_id:
        return None
    resume = user.resumes.get(user.active_resume_id)
    if not resume or resume.deleted:
        user.active_resume_id = None
        return None
    return resume


def resume_payload(resume: ResumeRecord | None) -> dict[str, Any] | None:
    if resume is None:
        return None
    return {
        "resume_id": resume.resume_id,
        "status": resume.status,
        "profile_quality_status": resume.profile_quality_status,
        "file_name": resume.file_name,
        "source_language": resume.source_language,
        "storage_key": resume.storage_key,
    }


def current_active_session(user: AppUser) -> TrainingSessionRecord | None:
    if not user.active_session_id:
        return None
    session = user.sessions.get(user.active_session_id)
    if not session or session.deleted or session.status in {"completed", "abandoned", "failed"}:
        user.active_session_id = None
        return None
    return session


def require_session(user: AppUser, session_id: str) -> TrainingSessionRecord:
    session = user.sessions.get(session_id)
    if not session or session.deleted:
        raise APIError("TRAINING_SESSION_NOT_FOUND", "Training session was not found.", 404)
    return session


def reserve_credit(user: AppUser) -> str:
    if user.free_session_credits_remaining > 0:
        user.free_session_credits_remaining -= 1
        user.reserved_session_credits += 1
        return "free"
    if user.paid_session_credits_remaining > 0:
        user.paid_session_credits_remaining -= 1
        user.reserved_session_credits += 1
        return "paid"
    raise APIError("INSUFFICIENT_SESSION_CREDITS", "No session credits are available.", 402)


def release_reserved_credit(user: AppUser, session: TrainingSessionRecord) -> None:
    if session.credit_state != "reserved":
        return
    user.reserved_session_credits = max(0, user.reserved_session_credits - 1)
    if session.reserved_credit_source == "paid":
        user.paid_session_credits_remaining += 1
    else:
        user.free_session_credits_remaining += 1
    session.credit_state = "released"
    session.reserved_credit_source = None


def consume_reserved_credit(user: AppUser, session: TrainingSessionRecord) -> None:
    if session.credit_state != "reserved":
        return
    user.reserved_session_credits = max(0, user.reserved_session_credits - 1)
    session.credit_state = "consumed"
    session.reserved_credit_source = None


def advance_session_on_read(user: AppUser, session: TrainingSessionRecord, providers: BackendProviders) -> None:
    if session.status == "question_generating":
        session.status = "waiting_first_answer"
        return
    if session.status == "first_answer_processing":
        session.status = "waiting_followup_answer"
        session.follow_up_text = providers.training_content.follow_up_for_focus(session.training_focus)
        return
    if session.status == "followup_answer_processing":
        consume_reserved_credit(user, session)
        session.status = "redo_available"
        session.feedback = providers.training_content.feedback()
        return
    if session.status == "redo_processing":
        session.status = "completed"
        session.completion_reason = "redo_review_generated"
        session.completed_at = utc_now()
        session.redo_review = providers.training_content.redo_review()
        session.redo_submitted = True
        if user.active_session_id == session.session_id:
            user.active_session_id = None


def session_mutation_payload(session: TrainingSessionRecord) -> dict[str, Any]:
    return {
        "session_id": session.session_id,
        "status": session.status,
        "completion_reason": session.completion_reason,
        "training_focus": session.training_focus,
        "question_text": session.question_text,
        "credit_state": session.credit_state,
        "billing_source": session.billing_source,
    }


def session_summary_payload(session: TrainingSessionRecord | None) -> dict[str, Any] | None:
    if session is None:
        return None
    return {
        "session_id": session.session_id,
        "status": session.status,
        "training_focus": session.training_focus,
        "question_text": session.question_text,
    }


def session_detail_payload(session: TrainingSessionRecord) -> dict[str, Any]:
    return {
        "session_id": session.session_id,
        "status": session.status,
        "completion_reason": session.completion_reason,
        "training_focus": session.training_focus,
        "credit_state": session.credit_state,
        "billing_source": session.billing_source,
        "question": {
            "question_text": session.question_text,
            "training_focus": session.training_focus,
        },
        "follow_up": {"follow_up_text": session.follow_up_text} if session.follow_up_text else None,
        "feedback": session.feedback,
        "redo_review": session.redo_review,
        "completed_at": session.completed_at,
        "audio_storage_keys": session.audio_storage_keys,
    }


def history_sessions(user: AppUser) -> list[TrainingSessionRecord]:
    sessions = [
        session
        for session in user.sessions.values()
        if not session.deleted and session.status == "completed" and session.completed_at
    ]
    return sorted(sessions, key=lambda session: session.completed_at or "", reverse=True)


def history_item_payload(session: TrainingSessionRecord) -> dict[str, Any]:
    redo_improvement_status = None
    if session.redo_review:
        redo_improvement_status = session.redo_review.get("improvement_status")

    return {
        "session_id": session.session_id,
        "completed_at": session.completed_at,
        "training_focus": session.training_focus,
        "question_text": session.question_text,
        "completion_reason": session.completion_reason,
        "redo_submitted": session.redo_submitted,
        "redo_improvement_status": redo_improvement_status,
        "final_visible_assessments": (session.feedback or {}).get("visible_assessments"),
    }


def question_for_focus(focus: str) -> str:
    questions = {
        "ownership": "Tell me about a time you took ownership of an ambiguous product problem and drove it to a clear outcome.",
        "prioritization": "Tell me about a time you made a high-stakes prioritization decision with incomplete information.",
        "cross_functional_influence": "Tell me about a time you influenced a cross-functional partner without direct authority.",
        "conflict_handling": "Tell me about a time you handled a serious disagreement with a teammate or stakeholder.",
        "failure_learning": "Tell me about a failure that changed how you work.",
        "ambiguity": "Tell me about a time you brought structure to an ambiguous situation.",
    }
    return questions.get(focus, questions["ownership"])


def follow_up_for_focus(focus: str) -> str:
    if focus == "ownership":
        return "What specific decision did you personally make, and what changed because of it?"
    return "What was your specific personal contribution, and how did you know it worked?"


def feedback_payload() -> dict[str, Any]:
    return {
        "visible_assessments": {
            "answered_the_question": "Strong",
            "story_fit": "Strong",
            "personal_ownership": "Weak",
            "evidence_and_outcome": "Mixed",
            "holds_up_under_follow_up": "Weak",
        },
        "strongest_signal": "You picked a relevant example with real business context.",
        "biggest_gap": "You still did not make your personal ownership explicit enough.",
        "why_it_matters": "Interviewers must see what you personally decided or drove.",
        "redo_priority": "Name your decision, tradeoff, and result before adding team context.",
        "redo_outline": [
            "Set context in one sentence.",
            "State the decision you owned.",
            "Explain the tradeoff.",
            "Close with the result.",
        ],
    }


def redo_review_payload() -> dict[str, str]:
    return {
        "improvement_status": "partially_improved",
        "headline": "Clearer ownership, but the result still needs sharper evidence.",
        "still_missing": "Quantify the outcome and name the decision point earlier.",
        "next_attempt": "Lead with the tradeoff, then use one metric to prove impact.",
    }


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def create_configured_app() -> FastAPI:
    from backend.config import create_providers_from_environment, create_state_store_from_environment

    return create_app(
        state_store=create_state_store_from_environment(),
        providers=create_providers_from_environment(),
    )


app = create_configured_app()
