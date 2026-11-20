import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/local/fingerprint_entry.dart';
import 'origin_manifest.dart';

class PublisherIdentityService {
  PublisherIdentityService._();

  static final instance = PublisherIdentityService._();
  static const _keyName = 'originchain.publisher.ed25519.seed.v1';
  static const _secureStorage = FlutterSecureStorage();
  static final _algorithm = Ed25519();

  Future<OriginManifest> createManifest(FingerprintEntry fingerprint) async {
    final pair = await _loadOrCreateKeyPair();
    final publicKey = await pair.extractPublicKey();
    final publicKeyBase64 = base64Encode(publicKey.bytes);
    final createdAt = fingerprint.createdAtUtc.toUtc();
    final basePayload = <String, Object?>{
      'schema': 'originchain.manifest.v1',
      'assetId': '',
      'versionId': '',
      'file': {
        'name': fingerprint.fileName,
        'sizeBytes': fingerprint.sizeBytes,
        'hashAlgorithm': 'sha256',
        'hash': fingerprint.sha256,
      },
      'createdAt': createdAt.toIso8601String(),
      'publisher': {'ed25519PublicKey': publicKeyBase64},
    };
    final assetId = _sha256('$publicKeyBase64:${fingerprint.sha256}');
    basePayload['assetId'] = assetId;
    basePayload['versionId'] = OriginManifest.makeVersionId(basePayload);

    final unsigned = OriginManifest(
      assetId: assetId,
      versionId: basePayload['versionId']! as String,
      fileName: fingerprint.fileName,
      fileSize: fingerprint.sizeBytes,
      sha256: fingerprint.sha256,
      createdAt: createdAt,
      publisherKey: publicKeyBase64,
      signature: '',
    );
    final signature = await _algorithm.sign(
      utf8.encode('originchain:manifest:v1\n${unsigned.canonicalPayload()}'),
      keyPair: pair,
    );
    return OriginManifest(
      assetId: unsigned.assetId,
      versionId: unsigned.versionId,
      fileName: unsigned.fileName,
      fileSize: unsigned.fileSize,
      sha256: unsigned.sha256,
      createdAt: unsigned.createdAt,
      publisherKey: unsigned.publisherKey,
      signature: base64Encode(signature.bytes),
    );
  }

  Future<bool> verify(OriginManifest manifest) async {
    try {
      final publicKey = SimplePublicKey(
        base64Decode(manifest.publisherKey),
        type: KeyPairType.ed25519,
      );
      final valid = await _algorithm.verify(
        utf8.encode('originchain:manifest:v1\n${manifest.canonicalPayload()}'),
        signature: Signature(
          base64Decode(manifest.signature),
          publicKey: publicKey,
        ),
      );
      if (!valid) return false;
      final expectedAssetId = _sha256(
        '${manifest.publisherKey}:${manifest.sha256}',
      );
      return manifest.assetId == expectedAssetId &&
          manifest.versionId ==
              OriginManifest.makeVersionId(manifest.payload());
    } catch (_) {
      return false;
    }
  }

  Future<SimpleKeyPair> _loadOrCreateKeyPair() async {
    final stored = await _secureStorage.read(key: _keyName);
    if (stored != null) {
      return _algorithm.newKeyPairFromSeed(base64Decode(stored));
    }
    final pair = await _algorithm.newKeyPair();
    await _secureStorage.write(
      key: _keyName,
      value: base64Encode(await pair.extractPrivateKeyBytes()),
    );
    return pair;
  }

  String _sha256(String value) =>
      // The hash format here is part of the manifest v1 identifier rule.
      crypto.sha256.convert(utf8.encode(value)).toString();
}
