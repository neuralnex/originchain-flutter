import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/origin_auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.walletAddress,
    required this.walletBusy,
    required this.supportsWallet,
    required this.onConnectWallet,
    required this.onDisconnectWallet,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? walletAddress;
  final bool walletBusy;
  final bool supportsWallet;
  final VoidCallback onConnectWallet;
  final VoidCallback onDisconnectWallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 128),
          sliver: SliverList.list(
            children: [
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                initialData: FirebaseAuth.instance.currentUser,
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final signedIn = user != null && !user.isAnonymous;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.primary,
                            child: Icon(
                              signedIn ? Icons.person_rounded : Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  signedIn ? user.email ?? 'OriginChain account' : 'Guest workspace',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  signedIn ? 'Synced account' : 'Create an account to keep access to your work',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (signedIn)
                            IconButton(
                              tooltip: 'Sign out',
                              onPressed: () => _signOut(context),
                              icon: const Icon(Icons.logout_rounded),
                            )
                          else
                            IconButton.filledTonal(
                              tooltip: 'Create account or sign in',
                              onPressed: () => _showAccountDialog(context, user),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Publisher wallet', style: theme.textTheme.titleMedium),
                          ),
                          if (walletAddress != null)
                            Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        walletAddress == null
                            ? 'Sign provenance with your wallet. OriginChain covers the Solana fee.'
                            : '${_shortAddress(walletAddress!)} · Devnet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: walletBusy
                              ? null
                              : walletAddress == null
                              ? onConnectWallet
                              : onDisconnectWallet,
                          icon: walletBusy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(walletAddress == null ? Icons.link_rounded : Icons.link_off_rounded),
                          label: Text(
                            walletBusy
                                ? 'Connecting…'
                                : walletAddress == null
                                ? 'Connect wallet'
                                : 'Disconnect wallet',
                          ),
                        ),
                      ),
                      if (!supportsWallet && walletAddress == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Android wallet signing is supported now. Other platforms use your secure device signing key.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Appearance', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {themeMode},
                onSelectionChanged: (selected) => onThemeModeChanged(selected.first),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.lock_outline_rounded),
                      title: Text('Files stay on your device until you share them'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.payments_outlined),
                      title: Text('OriginChain pays Solana fees'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAccountDialog(BuildContext context, User? user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(isGuest: user?.isAnonymous == true),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign in again to access this account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirm == true) await OriginAuthService.instance.signOut();
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.isGuest});
  final bool isGuest;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = true;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_create && widget.isGuest) {
      final switchAccount = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Switch account?'),
          content: const Text('Your guest work remains public by link, but it will not move into the account you sign in to.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay guest')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
          ],
        ),
      );
      if (switchAccount != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_create) {
        await OriginAuthService.instance.createAccount(_email.text, _password.text);
      } else {
        await OriginAuthService.instance.signIn(_email.text, _password.text);
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _authMessage(error.code));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not complete account setup. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    try {
      await OriginAuthService.instance.sendPasswordReset(_email.text);
      if (mounted) setState(() => _error = 'Password reset email sent.');
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _authMessage(error.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_create ? 'Keep your work' : 'Welcome back'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                autofillHints: [_create ? AutofillHints.newPassword : AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  ),
                ),
                validator: (value) => value == null || value.length < 8 ? 'Use at least 8 characters.' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (!_create)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _busy ? null : _resetPassword, child: const Text('Reset password')),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => setState(() { _create = !_create; _error = null; }),
          child: Text(_create ? 'Sign in instead' : 'Create account'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_create ? 'Create account' : 'Sign in'),
        ),
      ],
    );
  }
}

String _authMessage(String code) => switch (code) {
  'email-already-in-use' || 'credential-already-in-use' => 'That email already has an account. Sign in instead.',
  'invalid-email' => 'Enter a valid email address.',
  'weak-password' => 'Choose a stronger password.',
  'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
  'network-request-failed' => 'Connection lost. Check your internet and try again.',
  'operation-not-allowed' => 'Email and password sign-in is not enabled in Firebase yet.',
  _ => 'Could not complete account setup. Try again.',
};

String _shortAddress(String address) =>
    '${address.substring(0, 5)}…${address.substring(address.length - 5)}';
