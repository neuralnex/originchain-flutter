import 'package:flutter/material.dart';

import '../../services/solana/origin_solana_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _walletAddress = OriginSolanaService.instance.connectedAddress;
  bool _walletBusy = false;

  bool get _supportsMwa =>
      OriginSolanaService.instance.supportsMobileWalletAdapter;

  Future<void> _connectWallet() async {
    setState(() => _walletBusy = true);
    try {
      final address = await OriginSolanaService.instance.connectWallet();
      if (!mounted) return;
      setState(() => _walletAddress = address);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Devnet wallet connected.')));
    } on WalletConnectionCancelled {
      // A wallet cancellation is an expected user choice.
    } on UnsupportedError catch (error) {
      _showWalletError(error.message ?? 'Wallet connection is unavailable.');
    } on StateError catch (error) {
      _showWalletError(error.message);
    } catch (_) {
      _showWalletError('Could not connect to a wallet. Please try again.');
    } finally {
      if (mounted) setState(() => _walletBusy = false);
    }
  }

  Future<void> _disconnectWallet() async {
    setState(() => _walletBusy = true);
    try {
      await OriginSolanaService.instance.disconnectWallet();
      if (mounted) setState(() => _walletAddress = null);
    } catch (_) {
      _showWalletError('Could not disconnect the wallet. Please try again.');
    } finally {
      if (mounted) setState(() => _walletBusy = false);
    }
  }

  void _showWalletError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 128),
          sliver: SliverList.list(
            children: [
              Text('Profile', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Your identity, wallet, and app preferences.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.primary,
                    child: const Icon(Icons.person_outline_rounded),
                  ),
                  title: const Text('Guest profile'),
                  subtitle: const Text('You can explore without an account.'),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('Appearance', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode_outlined),
                            ),
                          ],
                          selected: {widget.themeMode},
                          onSelectionChanged: (selected) =>
                              widget.onThemeModeChanged(selected.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('Identity & wallet', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              const _SettingRow(
                icon: Icons.verified_user_outlined,
                title: 'Publisher identity',
                detail: 'Set up after authentication is connected.',
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(
                    _walletAddress == null
                        ? 'Wallet connection'
                        : 'Connected · Devnet',
                  ),
                  subtitle: Text(
                    _walletAddress == null
                        ? (_supportsMwa
                              ? 'Connect an Android MWA wallet. OriginChain never holds your keys.'
                              : 'Wallet connection is not available on this platform yet.')
                        : _shortAddress(_walletAddress!),
                  ),
                  trailing: _walletBusy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _walletAddress == null
                              ? (_supportsMwa ? _connectWallet : null)
                              : _disconnectWallet,
                          child: Text(
                            _walletAddress == null ? 'Connect' : 'Disconnect',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 22),
              Text('Privacy & fees', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              const _SettingRow(
                icon: Icons.lock_outline_rounded,
                title: 'Your files stay yours',
                detail: 'Original content is never uploaded automatically.',
              ),
              const SizedBox(height: 10),
              const _SettingRow(
                icon: Icons.payments_outlined,
                title: 'Network fees are covered',
                detail: 'OriginChain pays Solana transaction fees for you.',
              ),
              const SizedBox(height: 22),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('About OriginChain'),
                  subtitle: const Text('Mobile foundation · early access'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _shortAddress(String address) =>
      '${address.substring(0, 5)}…${address.substring(address.length - 5)}';
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(detail),
        isThreeLine: true,
      ),
    );
  }
}
