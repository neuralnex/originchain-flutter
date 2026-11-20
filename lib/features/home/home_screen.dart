import 'package:flutter/material.dart';

import '../../data/local/fingerprint_entry.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.lastFingerprint,
    required this.onRegisterTap,
    required this.onVerifyTap,
    super.key,
  });

  final FingerprintEntry? lastFingerprint;
  final VoidCallback onRegisterTap;
  final VoidCallback onVerifyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 128),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.all_inclusive_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'ORIGINCHAIN',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Open verification',
                    onPressed: onVerifyTap,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      backgroundColor: theme.colorScheme.surface,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Your work,\nwith a clear origin.',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Keep a record of what you create and the proof behind it.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _OverviewCard(onRegisterTap: onRegisterTap),
              const SizedBox(height: 26),
              Row(
                children: [
                  Text('Recent activity', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    lastFingerprint == null ? '0 items' : '1 item',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (lastFingerprint == null)
                _EmptyActivity(onRegisterTap: onRegisterTap)
              else
                _FingerprintActivity(fingerprint: lastFingerprint!),
              const SizedBox(height: 24),
              _PrivacyNote(),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.onRegisterTap});

  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? const [Color(0xFF3C2922), Color(0xFF30211B)]
              : const [Color(0xFFF0DED5), Color(0xFFEBD7CB)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start with a fingerprint',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Create a local SHA-256 fingerprint for a file.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.auto_awesome_rounded,
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRegisterTap,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Fingerprint a file'),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.onRegisterTap});

  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your activity will appear here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Register an asset',
              onPressed: onRegisterTap,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerprintActivity extends StatelessWidget {
  const _FingerprintActivity({required this.fingerprint});

  final FingerprintEntry fingerprint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fingerprint.fileName, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Local · ${fingerprint.sha256.substring(0, 16)}…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.check_circle_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 19,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your original files stay on your device unless you choose to share or store them.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
