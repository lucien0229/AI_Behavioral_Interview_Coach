from __future__ import annotations

import re
from pathlib import Path


class InMemoryFileStorage:
    def __init__(self):
        self.objects: dict[str, bytes] = {}

    def save_upload(
        self,
        kind: str,
        owner_id: str,
        object_id: str,
        file_name: str,
        data: bytes,
        content_type: str | None = None,
    ) -> str:
        key = storage_key(kind, owner_id, object_id, file_name)
        self.objects[key] = data
        return key

    def read(self, key: str) -> bytes:
        return self.objects[key]

    def exists(self, key: str) -> bool:
        return key in self.objects

    def delete(self, key: str) -> None:
        self.objects.pop(key, None)


class LocalFileStorage:
    def __init__(self, root_path: str):
        self.root_path = Path(root_path)

    def save_upload(
        self,
        kind: str,
        owner_id: str,
        object_id: str,
        file_name: str,
        data: bytes,
        content_type: str | None = None,
    ) -> str:
        key = storage_key(kind, owner_id, object_id, file_name)
        path = self.root_path / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return key

    def read(self, key: str) -> bytes:
        return (self.root_path / key).read_bytes()

    def exists(self, key: str) -> bool:
        return (self.root_path / key).exists()

    def delete(self, key: str) -> None:
        path = self.root_path / key
        if path.exists():
            path.unlink()


class S3FileStorage:
    def __init__(self, bucket_name: str, s3_client, key_prefix: str = ""):
        self.bucket_name = bucket_name
        self.s3_client = s3_client
        self.key_prefix = key_prefix.strip("/")

    def save_upload(
        self,
        kind: str,
        owner_id: str,
        object_id: str,
        file_name: str,
        data: bytes,
        content_type: str | None = None,
    ) -> str:
        key = self.full_key(storage_key(kind, owner_id, object_id, file_name))
        kwargs = {
            "Bucket": self.bucket_name,
            "Key": key,
            "Body": data,
        }
        if content_type:
            kwargs["ContentType"] = content_type
        self.s3_client.put_object(**kwargs)
        return key

    def read(self, key: str) -> bytes:
        body = self.s3_client.get_object(Bucket=self.bucket_name, Key=key)["Body"]
        return body.read()

    def exists(self, key: str) -> bool:
        try:
            self.s3_client.head_object(Bucket=self.bucket_name, Key=key)
        except KeyError:
            return False
        except Exception as error:
            if is_s3_not_found_error(error):
                return False
            raise
        return True

    def delete(self, key: str) -> None:
        self.s3_client.delete_object(Bucket=self.bucket_name, Key=key)

    def full_key(self, key: str) -> str:
        if not self.key_prefix:
            return key
        return f"{self.key_prefix}/{key}"


def storage_key(kind: str, owner_id: str, object_id: str, file_name: str) -> str:
    return "/".join(
        [
            safe_segment(kind),
            safe_segment(owner_id),
            safe_segment(object_id),
            safe_segment(file_name),
        ]
    )


def safe_segment(value: str) -> str:
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip())
    return sanitized.strip(".-") or "object"


def is_s3_not_found_error(error) -> bool:
    response = getattr(error, "response", None)
    if not isinstance(response, dict):
        return False
    code = str(response.get("Error", {}).get("Code", ""))
    status = response.get("ResponseMetadata", {}).get("HTTPStatusCode")
    return code in {"404", "NoSuchKey", "NotFound"} or status == 404
