import os
import re
import uuid
import hashlib
from typing import Any, Literal
from urllib.parse import quote

import boto3
import firebase_admin
from botocore.config import Config
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import auth, firestore
from pydantic import BaseModel, Field

from . import solana_sponsor


BUCKET = os.environ.get("NEON_BUCKET", "")
MAX_FILE_BYTES = int(os.environ.get("MAX_FILE_BYTES", str(100 * 1024 * 1024)))
URL_TTL_SECONDS = int(os.environ.get("SIGNED_URL_TTL_SECONDS", "600"))
RECORD_ID = re.compile(r"^[A-Za-z0-9_-]{10,40}$")

if not firebase_admin._apps:
    firebase_admin.initialize_app()

app = FastAPI(title="OriginChain API", version="0.1.0")
origins = [value.strip() for value in os.environ.get("CORS_ORIGINS", "").split(",") if value.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type", "X-Firebase-AppCheck"],
)


def s3_client():
    required = ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_ENDPOINT_URL_S3", "AWS_REGION"]
    missing = [name for name in required if not os.environ.get(name)]
    if not BUCKET or missing:
        raise HTTPException(status_code=503, detail="Neon Object Storage is not configured.")
    return boto3.client(
        "s3",
        endpoint_url=os.environ["AWS_ENDPOINT_URL_S3"],
        region_name=os.environ["AWS_REGION"],
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def require_user(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Firebase sign-in is required.")
    try:
        return auth.verify_id_token(authorization.removeprefix("Bearer "))
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid Firebase session.") from exc


def get_record(record_id: str):
    if not RECORD_ID.fullmatch(record_id):
        raise HTTPException(status_code=400, detail="Invalid share record ID.")
    snapshot = firestore.client().collection("sharedRecords").document(record_id).get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Share record not found.")
    return snapshot.reference, snapshot.to_dict()


class UploadRequest(BaseModel):
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    sizeBytes: int = Field(gt=0)
    contentType: str = Field(min_length=1, max_length=255)


class SponsoredTransactionRequest(BaseModel):
    operation: Literal["register_asset", "append_version"]
    publisher: str = Field(min_length=32, max_length=44)
    assetId: str = Field(pattern=r"^[0-9a-f]{64}$")
    versionId: str = Field(pattern=r"^[0-9a-f]{64}$")
    contentHash: str = Field(pattern=r"^[0-9a-f]{64}$")
    manifestHash: str = Field(pattern=r"^[0-9a-f]{64}$")
    parentVersionId: str | None = Field(default=None, pattern=r"^[0-9a-f]{64}$")


class SponsoredSubmissionRequest(SponsoredTransactionRequest):
    transactionBase64: str = Field(min_length=1, max_length=20000)


class PublicSolanaVerificationRequest(SponsoredTransactionRequest):
    transactionSignature: str = Field(min_length=80, max_length=100)


def _sponsored_args(body: SponsoredTransactionRequest):
    if body.operation == "append_version" and not body.parentVersionId:
        raise HTTPException(status_code=422, detail="parentVersionId is required for a new version.")
    return {
        "publisher": body.publisher,
        "assetId": body.assetId,
        "versionId": body.versionId,
        "contentHash": body.contentHash,
        "manifestHash": body.manifestHash,
        "parentVersionId": body.parentVersionId,
    }


@app.get("/health")
def health():
    try:
        solana_sponsor._fee_payer()
        sponsor_ready = True
    except HTTPException:
        sponsor_ready = False
    return {
        "status": "ok",
        "solana": {
            "cluster": "devnet" if "devnet" in solana_sponsor.RPC_URL else "custom",
            "programId": str(solana_sponsor.PROGRAM_ID),
            "sponsorshipConfigured": sponsor_ready,
        },
    }


@app.post("/v1/solana/transactions")
def create_sponsored_transaction(body: SponsoredTransactionRequest, user=Depends(require_user)):
    solana_sponsor.reserve_sponsor_attempt(
        user["uid"],
        int(os.environ.get("SOLANA_USER_DAILY_LIMIT", "10")),
        int(os.environ.get("SOLANA_GLOBAL_DAILY_LIMIT", "100")),
    )
    encoded, signer_index = solana_sponsor.create_transaction(
        body.operation, _sponsored_args(body)
    )
    return {
        "transactionBase64": encoded,
        "feePayer": str(solana_sponsor._fee_payer().pubkey()),
        "publisherSignerIndex": signer_index,
    }


@app.post("/v1/solana/transactions/submit")
def submit_sponsored_transaction(body: SponsoredSubmissionRequest, user=Depends(require_user)):
    signature = solana_sponsor.submit_transaction(
        body.operation, _sponsored_args(body), body.transactionBase64
    )
    return {"signature": signature, "cluster": "devnet"}


@app.post("/v1/solana/verify")
def verify_public_solana_record(body: PublicSolanaVerificationRequest):
    return solana_sponsor.verify_transaction(
        body.transactionSignature, body.operation, _sponsored_args(body)
    )


@app.post("/v1/shares/{record_id}/upload-url")
def create_upload_url(record_id: str, body: UploadRequest, user=Depends(require_user)):
    reference, record = get_record(record_id)
    if record.get("ownerUid") != user["uid"]:
        raise HTTPException(status_code=403, detail="You do not own this share record.")
    if record.get("fileStorage"):
        raise HTTPException(status_code=409, detail="A file is already attached to this record.")
    manifest = record.get("manifest", {})
    file_data = manifest.get("file", {})
    if file_data.get("hash") != body.sha256 or file_data.get("sizeBytes") != body.sizeBytes:
        raise HTTPException(status_code=422, detail="File details do not match the signed manifest.")
    if body.sizeBytes > MAX_FILE_BYTES:
        raise HTTPException(status_code=413, detail=f"File exceeds {MAX_FILE_BYTES} bytes.")

    key = f"uploads/{user['uid']}/{record_id}/{uuid.uuid4().hex}"
    filename = quote(os.path.basename(file_data.get("name", "shared-file")).encode("utf-8"), safe="")
    disposition = f"attachment; filename*=UTF-8''{filename}"
    params = {
        "Bucket": BUCKET,
        "Key": key,
        "ContentType": body.contentType,
        "Metadata": {"sha256": body.sha256, "record-id": record_id},
        "ContentDisposition": disposition,
    }
    client = s3_client()
    upload_url = client.generate_presigned_url(
        "put_object", Params=params, ExpiresIn=URL_TTL_SECONDS, HttpMethod="PUT"
    )
    return {
        "uploadUrl": upload_url,
        "objectKey": key,
        "expiresInSeconds": URL_TTL_SECONDS,
        "headers": {
            "Content-Type": body.contentType,
            "x-amz-meta-sha256": body.sha256,
            "x-amz-meta-record-id": record_id,
            "Content-Disposition": disposition,
        },
    }


@app.post("/v1/shares/{record_id}/finalize")
def finalize_upload(record_id: str, body: UploadRequest, objectKey: str, user=Depends(require_user)):
    reference, record = get_record(record_id)
    if record.get("ownerUid") != user["uid"]:
        raise HTTPException(status_code=403, detail="You do not own this share record.")
    if not objectKey.startswith(f"uploads/{user['uid']}/{record_id}/"):
        raise HTTPException(status_code=400, detail="Invalid object reference.")
    if record.get("manifest", {}).get("file", {}).get("hash") != body.sha256:
        raise HTTPException(status_code=422, detail="Hash does not match the signed manifest.")
    try:
        client = s3_client()
        stored = client.head_object(Bucket=BUCKET, Key=objectKey)
    except Exception as exc:
        raise HTTPException(status_code=422, detail="Uploaded object was not found.") from exc
    if (
        stored.get("ContentLength") != body.sizeBytes
        or stored.get("Metadata", {}).get("record-id") != record_id
    ):
        raise HTTPException(status_code=422, detail="Uploaded object does not match the manifest.")
    response = client.get_object(Bucket=BUCKET, Key=objectKey)
    digest = hashlib.sha256()
    for chunk in response["Body"].iter_chunks(chunk_size=1024 * 1024):
        digest.update(chunk)
    response["Body"].close()
    if digest.hexdigest() != body.sha256:
        client.delete_object(Bucket=BUCKET, Key=objectKey)
        raise HTTPException(status_code=422, detail="Uploaded bytes do not match the signed fingerprint.")
    reference.update({
        "fileStorage": {
            "provider": "neon",
            "objectKey": objectKey,
            "sizeBytes": body.sizeBytes,
            "contentType": body.contentType,
        }
    })
    return {"attached": True}


@app.get("/v1/shares/{record_id}/download-url")
def create_download_url(record_id: str):
    _, record = get_record(record_id)
    storage = record.get("fileStorage") or {}
    if storage.get("provider") != "neon" or not storage.get("objectKey"):
        raise HTTPException(status_code=404, detail="No file is attached to this record.")
    client = s3_client()
    url = client.generate_presigned_url(
        "get_object",
        Params={
            "Bucket": BUCKET,
            "Key": storage["objectKey"],
            "ResponseContentDisposition": f"attachment; filename*=UTF-8''{quote(os.path.basename(record.get('manifest', {}).get('file', {}).get('name', 'shared-file')).encode('utf-8'), safe='')}",
        },
        ExpiresIn=URL_TTL_SECONDS,
    )
    return {"downloadUrl": url, "expiresInSeconds": URL_TTL_SECONDS}

