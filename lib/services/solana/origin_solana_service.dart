import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

class OriginSolanaService {
  OriginSolanaService._();

  static final OriginSolanaService instance = OriginSolanaService._();

  static const cluster = 'devnet';
  static final SolanaClient _client = SolanaClient(
    rpcUrl: Uri.parse('https://api.devnet.solana.com'),
    websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
  );

  String? _authToken;
  String? connectedAddress;

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
}

class WalletConnectionCancelled implements Exception {
  const WalletConnectionCancelled();
}
