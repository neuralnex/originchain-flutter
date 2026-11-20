import 'package:flutter/material.dart';

class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 128),
          sliver: SliverList.list(
            children: [
              Text('Verify', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Check a shared record or compare a file with its provenance.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 212,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -24,
                      top: -32,
                      child: Icon(
                        Icons.blur_on_rounded,
                        size: 190,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.76,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 42,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'What verification checks',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const _VerifyDetail(
                icon: Icons.fingerprint_rounded,
                title: 'File fingerprint',
                body: 'Whether the selected content matches the fingerprint in a record.',
              ),
              const SizedBox(height: 10),
              const _VerifyDetail(
                icon: Icons.draw_outlined,
                title: 'Publisher signature',
                body: 'Whether the record was signed by the identity it names.',
              ),
              const SizedBox(height: 10),
              const _VerifyDetail(
                icon: Icons.link_rounded,
                title: 'Solana commitment',
                body: 'Whether the provenance commitment can be found and checked on-chain.',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Public verification is account-free. The verification service will connect in a later phase.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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
}

class _VerifyDetail extends StatelessWidget {
  const _VerifyDetail({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(body),
        isThreeLine: true,
      ),
    );
  }
}
