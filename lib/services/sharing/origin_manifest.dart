import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;

class OriginManifest {
  const OriginManifest({
    required this.assetId,
    required this.versionId,
    required this.fileName,
    required this.fileSize,
    required this.sha256,
    required this.createdAt,
    required this.publisherKey,
    required this.signature,
  });

  final String assetId;
  final String versionId;
  final String fileName;
  final int fileSize;
  final String sha256;
  final DateTime createdAt;
  final String publisherKey;
  final String signature;

  Map<String, Object?> payload() => {
    'schema': 'originchain.manifest.v1',
    'assetId': assetId,
    'versionId': versionId,
    'file': {
      'name': fileName,
      'sizeBytes': fileSize,
      'hashAlgorithm': 'sha256',
      'hash': sha256,
    },
    'createdAt': createdAt.toUtc().toIso8601String(),
    'publisher': {'ed25519PublicKey': publisherKey},
  };

  String canonicalPayload() => jsonEncode(payload());

  Map<String, Object?> toJson() => {
    ...payload(),
    'signature': {'algorithm': 'ed25519', 'value': signature},
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory OriginManifest.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['schema'] != 'originchain.manifest.v1') {
      throw const FormatException('Unsupported OriginChain manifest.');
    }
    final file = value['file'];
    final publisher = value['publisher'];
    final signature = value['signature'];
    if (file is! Map<String, dynamic> ||
        publisher is! Map<String, dynamic> ||
        signature is! Map<String, dynamic> ||
        signature['algorithm'] != 'ed25519') {
      throw const FormatException('The manifest is incomplete.');
    }
    final parsed = OriginManifest(
      assetId: _requiredString(value, 'assetId'),
      versionId: _requiredString(value, 'versionId'),
      fileName: _requiredString(file, 'name'),
      fileSize: _requiredInt(file, 'sizeBytes'),
      sha256: _requiredString(file, 'hash'),
      createdAt: DateTime.parse(_requiredString(value, 'createdAt')).toUtc(),
      publisherKey: _requiredString(publisher, 'ed25519PublicKey'),
      signature: _requiredString(signature, 'value'),
    );
    if (file['hashAlgorithm'] != 'sha256' ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(parsed.sha256)) {
      throw const FormatException('The file fingerprint is invalid.');
    }
    return parsed;
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing manifest field: $key');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int || value < 0) {
      throw FormatException('Invalid manifest field: $key');
    }
    return value;
  }

  static String makeVersionId(Map<String, Object?> payload) {
    final versionPayload = Map<String, Object?>.from(payload)
      ..['versionId'] = '';
    return hash.sha256
        .convert(utf8.encode(jsonEncode(versionPayload)))
        .toString();
  }
}
