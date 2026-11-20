"""Build and submit tightly scoped OriginChain registry transactions."""

import base64
import json
import os
import time
from urllib.request import Request, urlopen

from fastapi import HTTPException
from solders.hash import Hash
from solders.instruction import AccountMeta, Instruction
from solders.keypair import Keypair
from solders.message import Message
from solders.pubkey import Pubkey
from solders.transaction import Transaction


PROGRAM_ID = Pubkey.from_string(
    os.environ.get("ORIGINCHAIN_PROGRAM_ID", "EbePt3vR4pp9WRuY6hAfhchTfAPs1nNVsJYyurXajUPB")
)
RPC_URL = os.environ.get("SOLANA_RPC_URL", "https://api.devnet.solana.com")
SYSTEM_PROGRAM = Pubkey.from_string("11111111111111111111111111111111")
REGISTER_DISCRIMINATOR = bytes([21, 80, 155, 149, 117, 207, 235, 16])
APPEND_DISCRIMINATOR = bytes([7, 3, 240, 156, 51, 90, 85, 219])


def _fee_payer() -> Keypair:
    secret = os.environ.get("SOLANA_FEE_PAYER_SECRET_KEY", "").strip()
    if not secret:
        raise HTTPException(status_code=503, detail="Solana sponsorship is not configured.")
    try:
        if secret.startswith("["):
            return Keypair.from_bytes(bytes(json.loads(secret)))
        return Keypair.from_base58_string(secret)
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Solana sponsor key is invalid.") from exc


def _rpc(method: str, params: list):
    request = Request(
        RPC_URL,
        data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=20) as response:
            payload = json.loads(response.read())
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Solana RPC is unavailable.") from exc
    if "error" in payload:
        raise HTTPException(status_code=502, detail="Solana RPC rejected the request.")
    return payload["result"]


def _digest(value: str, field: str) -> bytes:
    if len(value) != 64:
        raise HTTPException(status_code=422, detail=f"{field} must be a 32-byte hex digest.")
    try:
        raw = bytes.fromhex(value)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=f"{field} must be a 32-byte hex digest.") from exc
    if len(raw) != 32 or raw == bytes(32):
        raise HTTPException(status_code=422, detail=f"{field} must be a non-zero 32-byte digest.")
    return raw


def _build_instruction(operation: str, args: dict, payer: Pubkey):
    try:
        publisher = Pubkey.from_string(args["publisher"])
        asset_id = _digest(args["assetId"], "assetId")
        version_id = _digest(args["versionId"], "versionId")
        content_hash = _digest(args["contentHash"], "contentHash")
        manifest_hash = _digest(args["manifestHash"], "manifestHash")
    except (KeyError, ValueError) as exc:
        raise HTTPException(status_code=422, detail="Invalid registry transaction fields.") from exc

    origin, _ = Pubkey.find_program_address([b"origin", bytes(publisher), asset_id], PROGRAM_ID)
    if operation == "register_asset":
        data = REGISTER_DISCRIMINATOR + asset_id + version_id + content_hash + manifest_hash
        version, _ = Pubkey.find_program_address([b"version", bytes(origin), version_id], PROGRAM_ID)
        accounts = [
            AccountMeta(payer, True, True),
            AccountMeta(publisher, True, False),
            AccountMeta(origin, False, True),
            AccountMeta(version, False, True),
            AccountMeta(SYSTEM_PROGRAM, False, False),
        ]
    elif operation == "append_version":
        parent_version_id = _digest(args.get("parentVersionId", ""), "parentVersionId")
        parent, _ = Pubkey.find_program_address(
            [b"version", bytes(origin), parent_version_id], PROGRAM_ID
        )
        version, _ = Pubkey.find_program_address([b"version", bytes(origin), version_id], PROGRAM_ID)
        data = APPEND_DISCRIMINATOR + version_id + content_hash + manifest_hash
        accounts = [
            AccountMeta(payer, True, True),
            AccountMeta(publisher, True, False),
            AccountMeta(origin, False, True),
            AccountMeta(parent, False, False),
            AccountMeta(version, False, True),
            AccountMeta(SYSTEM_PROGRAM, False, False),
        ]
    else:
        raise HTTPException(status_code=422, detail="Unsupported registry operation.")

    return publisher, Instruction(PROGRAM_ID, data, accounts)


def create_transaction(operation: str, args: dict) -> tuple[str, int]:
    payer = _fee_payer()
    publisher, instruction = _build_instruction(operation, args, payer.pubkey())
    try:
        blockhash = Hash.from_string(_rpc("getLatestBlockhash", [{"commitment": "confirmed"}])["value"]["blockhash"])
        message = Message.new_with_blockhash([instruction], payer.pubkey(), blockhash)
        transaction = Transaction.new_unsigned(message)
        transaction.partial_sign([payer], blockhash)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Could not prepare the sponsored transaction.") from exc

    # The mobile app signs the publisher slot. The backend supplies the fee payer slot.
    signer_index = list(transaction.message.account_keys).index(publisher)
    return base64.b64encode(bytes(transaction)).decode("ascii"), signer_index


def submit_transaction(operation: str, args: dict, encoded_transaction: str) -> str:
    payer = _fee_payer()
    publisher, instruction = _build_instruction(operation, args, payer.pubkey())
    try:
        transaction = Transaction.from_bytes(base64.b64decode(encoded_transaction, validate=True))
        transaction_message = transaction.message
    except Exception as exc:
        raise HTTPException(status_code=422, detail="Malformed Solana transaction.") from exc

    # Recompile from server-approved fields, preventing clients from using the
    # sponsor signer for arbitrary transfers or other program calls.
    expected_message = Message.new_with_blockhash(
        [instruction], payer.pubkey(), transaction_message.recent_blockhash
    )
    if bytes(transaction_message) != bytes(expected_message):
        raise HTTPException(status_code=422, detail="Transaction does not match the approved registry action.")
    try:
        transaction.verify()
    except Exception as exc:
        raise HTTPException(status_code=422, detail="Publisher or sponsor signature is invalid.") from exc

    result = _rpc(
        "sendTransaction",
        [base64.b64encode(bytes(transaction)).decode("ascii"), {"encoding": "base64", "preflightCommitment": "confirmed"}],
    )
    return result


def verify_transaction(signature: str, operation: str, args: dict) -> dict:
    result = _rpc(
        "getTransaction",
        [signature, {"encoding": "base64", "commitment": "confirmed", "maxSupportedTransactionVersion": 0}],
    )
    if result is None or result.get("meta", {}).get("err") is not None:
        return {"verified": False, "reason": "Transaction is missing or failed."}
    try:
        encoded = result["transaction"][0]
        transaction = Transaction.from_bytes(base64.b64decode(encoded, validate=True))
        if str(transaction.signatures[0]) != signature:
            raise ValueError("signature mismatch")
        transaction.verify()
        payer = transaction.message.account_keys[0]
        _, instruction = _build_instruction(operation, args, payer)
        expected_message = Message.new_with_blockhash(
            [instruction], payer, transaction.message.recent_blockhash
        )
        if bytes(transaction.message) != bytes(expected_message):
            raise ValueError("message mismatch")
    except Exception:
        return {"verified": False, "reason": "Transaction does not prove this manifest."}
    return {
        "verified": True,
        "signature": signature,
        "slot": result.get("slot"),
        "blockTime": result.get("blockTime"),
        "cluster": "devnet",
        "programId": str(PROGRAM_ID),
    }


def reserve_sponsor_attempt(uid: str, limit_per_user_per_day: int = 10, global_limit_per_day: int = 100):
    """Atomically cap sponsored transactions to protect the platform fee wallet."""
    from firebase_admin import firestore

    day = time.strftime("%Y-%m-%d", time.gmtime())
    db = firestore.client()
    user_ref = db.collection("sponsorUsage").document(f"{day}_{uid}")
    global_ref = db.collection("sponsorUsage").document(f"{day}_global")
    transaction = db.transaction()

    @firestore.transactional
    def reserve(txn):
        user_snapshot = user_ref.get(transaction=txn)
        global_snapshot = global_ref.get(transaction=txn)
        user_count = int((user_snapshot.to_dict() or {}).get("count", 0))
        global_count = int((global_snapshot.to_dict() or {}).get("count", 0))
        if user_count >= limit_per_user_per_day or global_count >= global_limit_per_day:
            raise HTTPException(status_code=429, detail="Daily sponsored registration limit reached.")
        txn.set(user_ref, {"count": user_count + 1, "day": day})
        txn.set(global_ref, {"count": global_count + 1, "day": day})

    reserve(transaction)
