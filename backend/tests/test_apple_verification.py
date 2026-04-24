from types import SimpleNamespace

import pytest

from backend.app import APIError
from backend.apple_verification import AppleAppStorePurchaseVerifier


def test_apple_verifier_maps_verified_signed_transaction_to_credit_grant():
    signed_data_verifier = RecordingSignedDataVerifier(
        SimpleNamespace(
            productId="coach_sprint_pack_01",
            transactionId="apple_transaction_id",
            originalTransactionId="apple_original_transaction_id",
            appAccountToken="11111111-1111-4111-8111-111111111111",
            rawEnvironment="Sandbox",
        )
    )
    verifier = AppleAppStorePurchaseVerifier(
        signed_data_verifier=signed_data_verifier,
        product_credit_map={"coach_sprint_pack_01": 5},
    )

    verification = verifier.verify(
        {
            "product_id": "coach_sprint_pack_01",
            "transaction_id": "client_transaction_id",
            "app_account_token": "11111111-1111-4111-8111-111111111111",
            "signed_transaction_info": "signed-jws",
        }
    )

    assert signed_data_verifier.signed_transactions == ["signed-jws"]
    assert verification == {
        "product_id": "coach_sprint_pack_01",
        "transaction_id": "apple_transaction_id",
        "original_transaction_id": "apple_original_transaction_id",
        "app_account_token": "11111111-1111-4111-8111-111111111111",
        "environment": "Sandbox",
        "session_credits": 5,
    }


def test_apple_verifier_rejects_transaction_product_mismatch():
    signed_data_verifier = RecordingSignedDataVerifier(
        SimpleNamespace(
            productId="other_product",
            transactionId="apple_transaction_id",
            originalTransactionId="apple_original_transaction_id",
            appAccountToken="11111111-1111-4111-8111-111111111111",
        )
    )
    verifier = AppleAppStorePurchaseVerifier(
        signed_data_verifier=signed_data_verifier,
        product_credit_map={"coach_sprint_pack_01": 5},
    )

    with pytest.raises(APIError) as error:
        verifier.verify(
            {
                "product_id": "coach_sprint_pack_01",
                "app_account_token": "11111111-1111-4111-8111-111111111111",
                "signed_transaction_info": "signed-jws",
            }
        )

    assert error.value.code == "APPLE_PURCHASE_VERIFICATION_FAILED"


def test_apple_verifier_allows_missing_optional_transaction_fields():
    signed_data_verifier = RecordingSignedDataVerifier(
        SimpleNamespace(
            productId="coach_sprint_pack_01",
            transactionId="apple_transaction_id",
            originalTransactionId="apple_original_transaction_id",
        )
    )
    verifier = AppleAppStorePurchaseVerifier(
        signed_data_verifier=signed_data_verifier,
        product_credit_map={"coach_sprint_pack_01": 5},
    )

    verification = verifier.verify(
        {
            "product_id": "coach_sprint_pack_01",
            "signed_transaction_info": "signed-jws",
        }
    )

    assert verification["app_account_token"] is None
    assert verification["environment"] is None


def test_apple_verifier_from_certificate_files_requires_official_library(tmp_path, monkeypatch):
    certificate_path = tmp_path / "apple-root.cer"
    certificate_path.write_bytes(b"certificate")
    original_import = __import__

    def blocked_import(name, *args, **kwargs):
        if name.startswith("appstoreserverlibrary"):
            raise ImportError("missing library")
        return original_import(name, *args, **kwargs)

    monkeypatch.setattr("builtins.__import__", blocked_import)

    with pytest.raises(RuntimeError, match="app-store-server-library"):
        AppleAppStorePurchaseVerifier.from_certificate_files(
            root_certificate_paths=[str(certificate_path)],
            bundle_id="com.example.app",
            environment="sandbox",
        )


class RecordingSignedDataVerifier:
    def __init__(self, decoded_transaction):
        self.decoded_transaction = decoded_transaction
        self.signed_transactions = []

    def verify_and_decode_signed_transaction(self, signed_transaction):
        self.signed_transactions.append(signed_transaction)
        return self.decoded_transaction
