import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
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
                          selected: {themeMode},
                          onSelectionChanged: (selected) =>
                              onThemeModeChanged(selected.first),
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
              const _SettingRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet connection',
                detail: 'Optional · no wallet connected',
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
