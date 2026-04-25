from fastapi.testclient import TestClient

from backend.app import PRODUCT_ID
from backend.config import create_providers_from_environment
from backend.tests.test_api_contract import bootstrap, data


def test_provider_config_builds_apple_verifier_from_environment(tmp_path, monkeypatch):
    certificate_path = tmp_path / "apple-root.cer"
    certificate_path.write_bytes(b"certificate")
    monkeypatch.setenv("AIBIC_APPLE_ROOT_CERT_PATHS", str(certificate_path))
    monkeypatch.setenv("AIBIC_IOS_BUNDLE_ID", "com.example.app")
    monkeypatch.setenv("AIBIC_APPLE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("AIBIC_APPLE_APP_ID", "1234567890")
    monkeypatch.setattr(
        "backend.apple_verification.AppleAppStorePurchaseVerifier.from_certificate_files",
        RecordingAppleVerifierFactory.from_certificate_files,
    )

    providers = create_providers_from_environment()

    assert providers.purchase_verifier == RecordingAppleVerifierFactory.verifier
    assert RecordingAppleVerifierFactory.calls == [
        {
            "root_certificate_paths": [str(certificate_path)],
            "bundle_id": "com.example.app",
            "environment": "sandbox",
            "app_apple_id": 1234567890,
            "product_credit_map": {PRODUCT_ID: 5},
        }
    ]


def test_configured_app_uses_environment_provider_bundle(tmp_path, monkeypatch):
    from backend.app import create_configured_app

    certificate_path = tmp_path / "apple-root.cer"
    certificate_path.write_bytes(b"certificate")
    monkeypatch.setenv("AIBIC_APPLE_ROOT_CERT_PATHS", str(certificate_path))
    monkeypatch.setenv("AIBIC_IOS_BUNDLE_ID", "com.example.app")
    monkeypatch.setenv("AIBIC_APPLE_ENVIRONMENT", "sandbox")
    monkeypatch.setattr(
        "backend.apple_verification.AppleAppStorePurchaseVerifier.from_certificate_files",
        ConfiguredAppleVerifierFactory.from_certificate_files,
    )
    client = TestClient(create_configured_app())
    _, auth = bootstrap(client)
    entitlement = data(client.get("/api/v1/billing/entitlement", headers=auth))

    verified = data(
        client.post(
            "/api/v1/billing/apple/verify",
            json={
                "product_id": "coach_sprint_pack_01",
                "transaction_id": "client_transaction_id",
                "original_transaction_id": "client_original_transaction_id",
                "app_account_token": entitlement["app_account_token"],
                "signed_transaction_info": "signed-jws",
                "environment": "sandbox",
            },
            headers={**auth, "Idempotency-Key": "idem-verify"},
        )
    )

    assert ConfiguredAppleVerifierFactory.verifier.signed_transactions == ["signed-jws"]
    assert verified["usage_balance"]["paid_session_credits_remaining"] == 5


def test_provider_config_builds_local_file_storage_from_environment(tmp_path, monkeypatch):
    storage_root = tmp_path / "objects"
    monkeypatch.setenv("AIBIC_LOCAL_FILE_STORAGE_ROOT", str(storage_root))

    providers = create_providers_from_environment()
    key = providers.file_storage.save_upload(
        kind="resumes",
        owner_id="usr_1",
        object_id="res_1",
        file_name="resume.pdf",
        data=b"stored",
    )

    assert providers.file_storage.read(key) == b"stored"
    assert (storage_root / key).read_bytes() == b"stored"


class RecordingAppleVerifierFactory:
    verifier = object()
    calls = []

    @classmethod
    def from_certificate_files(
        cls,
        root_certificate_paths,
        bundle_id,
        environment,
        app_apple_id=None,
        product_credit_map=None,
        **kwargs,
    ):
        cls.calls = [
            {
                "root_certificate_paths": root_certificate_paths,
                "bundle_id": bundle_id,
                "environment": environment,
                "app_apple_id": app_apple_id,
                "product_credit_map": product_credit_map,
            }
        ]
        return cls.verifier


class ConfiguredAppleVerifierFactory:
    verifier = None

    @classmethod
    def from_certificate_files(cls, **kwargs):
        cls.verifier = ConfiguredAppleVerifier()
        return cls.verifier


class ConfiguredAppleVerifier:
    def __init__(self):
        self.signed_transactions = []

    def verify(self, payload):
        self.signed_transactions.append(payload["signed_transaction_info"])
        return {
            "transaction_id": "apple_transaction_id",
            "product_id": "coach_sprint_pack_01",
            "session_credits": 5,
        }
