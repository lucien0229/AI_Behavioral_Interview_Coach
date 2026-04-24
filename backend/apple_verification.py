from __future__ import annotations

from pathlib import Path
from typing import Any

from backend.app import APIError, PRODUCT_ID, SESSION_PACK_CREDITS


MISSING = object()


class AppleAppStorePurchaseVerifier:
    def __init__(
        self,
        signed_data_verifier: Any,
        product_credit_map: dict[str, int] | None = None,
    ):
        self.signed_data_verifier = signed_data_verifier
        self.product_credit_map = product_credit_map or {PRODUCT_ID: SESSION_PACK_CREDITS}

    @classmethod
    def from_certificate_files(
        cls,
        root_certificate_paths: list[str],
        bundle_id: str,
        environment: str,
        app_apple_id: int | None = None,
        enable_online_checks: bool = True,
        product_credit_map: dict[str, int] | None = None,
    ) -> "AppleAppStorePurchaseVerifier":
        root_certificates = [Path(path).read_bytes() for path in root_certificate_paths]
        return cls.from_root_certificates(
            root_certificates=root_certificates,
            bundle_id=bundle_id,
            environment=environment,
            app_apple_id=app_apple_id,
            enable_online_checks=enable_online_checks,
            product_credit_map=product_credit_map,
        )

    @classmethod
    def from_root_certificates(
        cls,
        root_certificates: list[bytes],
        bundle_id: str,
        environment: str,
        app_apple_id: int | None = None,
        enable_online_checks: bool = True,
        product_credit_map: dict[str, int] | None = None,
    ) -> "AppleAppStorePurchaseVerifier":
        try:
            from appstoreserverlibrary.models.Environment import Environment
            from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
        except ImportError as error:
            raise RuntimeError(
                "Install app-store-server-library to enable Apple App Store purchase verification."
            ) from error

        signed_data_verifier = SignedDataVerifier(
            root_certificates,
            enable_online_checks,
            apple_environment(environment, Environment),
            bundle_id,
            app_apple_id,
        )
        return cls(signed_data_verifier=signed_data_verifier, product_credit_map=product_credit_map)

    def verify(self, payload: dict[str, Any]) -> dict[str, Any]:
        signed_transaction_info = payload.get("signed_transaction_info")
        if not signed_transaction_info:
            raise verification_error("signed_transaction_info is required.")

        decoded_transaction = self.decode_signed_transaction(str(signed_transaction_info))
        product_id = transaction_field(decoded_transaction, "productId", "product_id")
        request_product_id = payload.get("product_id")
        if request_product_id and product_id != request_product_id:
            raise verification_error("The signed transaction product does not match the requested product.")

        if product_id not in self.product_credit_map:
            raise verification_error("The signed transaction product is not recognized.")

        app_account_token = transaction_field(decoded_transaction, "appAccountToken", "app_account_token", default=None)
        request_app_account_token = payload.get("app_account_token")
        if app_account_token and request_app_account_token:
            if str(app_account_token).lower() != str(request_app_account_token).lower():
                raise verification_error("The signed transaction app account token does not match the current user.")

        transaction_id = transaction_field(decoded_transaction, "transactionId", "transaction_id")
        return {
            "product_id": product_id,
            "transaction_id": str(transaction_id),
            "original_transaction_id": str(
                transaction_field(decoded_transaction, "originalTransactionId", "original_transaction_id")
            ),
            "app_account_token": str(app_account_token) if app_account_token else None,
            "environment": transaction_field(decoded_transaction, "rawEnvironment", "environment", default=None),
            "session_credits": self.product_credit_map[product_id],
        }

    def decode_signed_transaction(self, signed_transaction_info: str) -> Any:
        try:
            return self.signed_data_verifier.verify_and_decode_signed_transaction(signed_transaction_info)
        except Exception as error:
            raise verification_error("The signed transaction could not be verified.") from error


def apple_environment(environment: str, environment_type: Any) -> Any:
    normalized = environment.lower()
    if normalized == "production":
        return environment_type.PRODUCTION
    if normalized == "sandbox":
        return environment_type.SANDBOX
    raise ValueError("environment must be 'sandbox' or 'production'")


def transaction_field(transaction: Any, *names: str, default: Any = MISSING) -> Any:
    for name in names:
        if isinstance(transaction, dict) and name in transaction:
            return transaction[name]
        if hasattr(transaction, name):
            return getattr(transaction, name)
    if default is not MISSING:
        return default
    raise verification_error(f"The signed transaction is missing {names[0]}.")


def verification_error(message: str) -> APIError:
    return APIError("APPLE_PURCHASE_VERIFICATION_FAILED", message, 400)
