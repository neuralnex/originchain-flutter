import 'dart:convert';

import 'package:cryptography/cryptography.dart'
    show KeyPairType, Signature, SimplePublicKey;
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

import '../sharing/origin_manifest.dart';
import '../sharing/publisher_identity_service.dart';

class OriginSolanaService {
  OriginSolanaService._();

  static final OriginSolanaService instance = OriginSolanaService._();

  static const cluster = 'devnet';
  static const _apiUrl = String.fromEnvironment(
    'ORIGINCHAIN_API_URL',
    defaultValue: 'https://originchain-flutter.onrender.com',
  );
  static const programId = 'EbePt3vR4pp9WRuY6hAfhchTfAPs1nNVsJYyurXajUPB';
  static final SolanaClient _client = SolanaClient(
    rpcUrl: Uri.parse('https://api.devnet.solana.com'),
    websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
  );

  String? _authToken;
  String? connectedAddress;
  final Dio _api = Dio();

  bool get supportsMobileWalletAdapter =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<String> connectWallet() async {
    if (!supportsMobileWalletAdapter) {
      throw UnsupportedError(
        'Solana Mobile Wallet Adapter is currently available on Android only.',
      );
    }
    if (!await LocalAssociationScenario.isAvailable()) {
      throw StateError('No compatible Solana wallet is installed.');
    }

    final scenario = await LocalAssociationScenario.create();
    try {
      await scenario.startActivityForResult(null);
      final wallet = await scenario.start();
      final authorization = await wallet.authorize(
        identityName: 'OriginChain',
        cluster: cluster,
      );
      if (authorization == null) {
        throw const WalletConnectionCancelled();
      }

      _authToken = authorization.authToken;
      connectedAddress = Ed25519HDPublicKey(authorization.publicKey).toBase58();
      return connectedAddress!;
    } finally {
      await scenario.close();
    }
  }

  Future<void> disconnectWallet() async {
    final authToken = _authToken;
    _authToken = null;
    connectedAddress = null;
    if (authToken == null || !supportsMobileWalletAdapter) return;

    final scenario = await LocalAssociationScenario.create();
    try {
      await scenario.startActivityForResult(null);
      final wallet = await scenario.start();
      await wallet.deauthorize(authToken: authToken);
    } finally {
      await scenario.close();
    }
  }

  Future<int> getBalanceLamports(String address) async {
    return (await _client.rpcClient.getBalance(address)).value;
  }

  Future<String> commitManifest(OriginManifest manifest) async {
    final publisherKey = await PublisherIdentityService.instance.solanaAddress;
    if (base58encode(base64Decode(manifest.publisherKey)) != publisherKey) {
      throw StateError(
        'The manifest publisher key does not match this device identity.',
      );
    }
    final args = _manifestArgs(manifest);
    final headers = await _authHeaders();
    final prepared = await _api.post<Map<String, dynamic>>(
      '$_apiUrl/v1/solana/transactions',
      data: args,
      options: Options(headers: headers),
    );
    final response = prepared.data!;
    final transaction = SignedTx.fromBytes(
      base64Decode(response['transactionBase64'] as String),
    );
    final signerIndex = response['publisherSignerIndex'] as int;
    if (transaction.signatures.length != 2 || signerIndex != 1) {
      throw StateError('The sponsor returned an unexpected signer layout.');
    }
    if (transaction.compiledMessage.accountKeys.first.toBase58() !=
        response['feePayer']) {
      throw StateError('The sponsored transaction has an unexpected fee payer.');
    }
    final publicKey = transaction.compiledMessage.accountKeys[signerIndex];
    if (publicKey.toBase58() != publisherKey) {
      throw StateError(
        'The sponsored transaction targets a different publisher key.',
      );
    }
    final message = transaction.compiledMessage.toByteArray().toList();
    final signedMessage = await PublisherIdentityService.instance
        .signSolanaMessage(message);
    final signatures = List<Signature>.from(transaction.signatures);
    signatures[signerIndex] = Signature(
      signedMessage,
      publicKey: SimplePublicKey(publicKey.bytes, type: KeyPairType.ed25519),
    );
    final signedTransaction = transaction.copyWith(signatures: signatures);
    final submitted = await _api.post<Map<String, dynamic>>(
      '$_apiUrl/v1/solana/transactions/submit',
      data: {
        ...args,
        'transactionBase64': base64Encode(
          signedTransaction.toByteArray().toList(),
        ),
      },
      options: Options(headers: headers),
    );
    return submitted.data!['signature'] as String;
  }

  Future<Map<String, dynamic>> verifyManifestReceipt(
    OriginManifest manifest,
    String transactionSignature,
  ) async {
    final response = await _api.post<Map<String, dynamic>>(
      '$_apiUrl/v1/solana/verify',
      data: {
        ..._manifestArgs(manifest),
        'transactionSignature': transactionSignature,
      },
    );
    return response.data!;
  }

  Map<String, Object?> _manifestArgs(OriginManifest manifest) => {
    'operation': 'register_asset',
    'publisher': base58encode(base64Decode(manifest.publisherKey)),
    'assetId': manifest.assetId,
    'versionId': manifest.versionId,
    'contentHash': manifest.sha256,
    'manifestHash': crypto.sha256
        .convert(utf8.encode(jsonEncode(manifest.toJson())))
        .toString(),
  };

  Future<Map<String, String>> _authHeaders() async {
    if (_apiUrl.isEmpty) {
      throw StateError(
        'The OriginChain API is not configured for Solana registration.',
      );
    }
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) throw StateError('Could not start a publisher session.');
    final token = await user.getIdToken();
    if (token == null) {
      throw StateError('Could not authenticate the registration.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}

class WalletConnectionCancelled implements Exception {
  const WalletConnectionCancelled();
}
