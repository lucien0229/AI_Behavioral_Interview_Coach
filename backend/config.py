from __future__ import annotations

import os

from backend.app import PRODUCT_ID, SESSION_PACK_CREDITS, BackendProviders
from backend.apple_verification import AppleAppStorePurchaseVerifier


def create_providers_from_environment() -> BackendProviders:
    providers = BackendProviders()
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


def split_paths(raw_paths: str) -> list[str]:
    return [path for path in raw_paths.split(":") if path]


def optional_int(raw_value: str | None) -> int | None:
    if not raw_value:
        return None
    return int(raw_value)
