from __future__ import annotations

import os

from backend.app import PRODUCT_ID, SESSION_PACK_CREDITS, BackendProviders
from backend.apple_verification import AppleAppStorePurchaseVerifier
from backend.audio_transcription import DEFAULT_OPENAI_TRANSCRIPTION_MODEL, OpenAIAudioTranscriber
from backend.file_storage import LocalFileStorage, S3FileStorage
from backend.state_store import SQLAlchemyStateStore, SQLiteStateStore


def create_providers_from_environment() -> BackendProviders:
    providers = BackendProviders()
    local_file_storage_root = os.getenv("AIBIC_LOCAL_FILE_STORAGE_ROOT")
    if local_file_storage_root:
        providers.file_storage = LocalFileStorage(local_file_storage_root)

    s3_bucket = os.getenv("AIBIC_S3_BUCKET")
    if s3_bucket:
        providers.file_storage = S3FileStorage(
            bucket_name=s3_bucket,
            s3_client=create_s3_client(
                endpoint_url=os.getenv("AIBIC_S3_ENDPOINT_URL"),
                region_name=os.getenv("AIBIC_S3_REGION"),
                aws_access_key_id=os.getenv("AIBIC_S3_ACCESS_KEY_ID"),
                aws_secret_access_key=os.getenv("AIBIC_S3_SECRET_ACCESS_KEY"),
            ),
            key_prefix=os.getenv("AIBIC_S3_KEY_PREFIX", ""),
        )

    asr_provider = os.getenv("AIBIC_ASR_PROVIDER", "").lower()
    if asr_provider == "openai":
        providers.audio_transcriber = OpenAIAudioTranscriber(
            api_key=required_env("AIBIC_OPENAI_API_KEY"),
            model=os.getenv("AIBIC_OPENAI_TRANSCRIPTION_MODEL", DEFAULT_OPENAI_TRANSCRIPTION_MODEL),
            base_url=os.getenv("AIBIC_OPENAI_BASE_URL", "https://api.openai.com/v1"),
        )
    elif asr_provider:
        raise RuntimeError("AIBIC_ASR_PROVIDER must be 'openai' when set.")

    root_certificate_paths = split_paths(os.getenv("AIBIC_APPLE_ROOT_CERT_PATHS", ""))
    bundle_id = os.getenv("AIBIC_IOS_BUNDLE_ID")
    environment = os.getenv("AIBIC_APPLE_ENVIRONMENT")

    if root_certificate_paths and bundle_id and environment:
        providers.purchase_verifier = AppleAppStorePurchaseVerifier.from_certificate_files(
            root_certificate_paths=root_certificate_paths,
            bundle_id=bundle_id,
            environment=environment,
            app_apple_id=optional_int(os.getenv("AIBIC_APPLE_APP_ID")),
            product_credit_map={PRODUCT_ID: SESSION_PACK_CREDITS},
        )

    return providers


def create_state_store_from_environment():
    database_url = os.getenv("AIBIC_DATABASE_URL")
    if database_url:
        return SQLAlchemyStateStore(database_url)

    sqlite_database_path = os.getenv("AIBIC_SQLITE_DATABASE_PATH")
    if sqlite_database_path:
        return SQLiteStateStore(sqlite_database_path)

    return None


def split_paths(raw_paths: str) -> list[str]:
    return [path for path in raw_paths.split(":") if path]


def optional_int(raw_value: str | None) -> int | None:
    if not raw_value:
        return None
    return int(raw_value)


def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"{name} is required.")
    return value


def create_s3_client(**kwargs):
    try:
        import boto3
    except ImportError as error:
        raise RuntimeError("Install boto3 to enable S3-compatible file storage.") from error

    filtered_kwargs = {key: value for key, value in kwargs.items() if value}
    return boto3.client("s3", **filtered_kwargs)
