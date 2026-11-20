import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({required this.onRegisterTap, super.key});

  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 128),
          sliver: SliverList.list(
            children: [
              Text('Library', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Your registered files and provenance records.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Nothing registered yet',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start with a local fingerprint. Your original file stays on this device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onRegisterTap,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Choose a file'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('What belongs here', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              const _LibraryHint(
                icon: Icons.photo_outlined,
                title: 'Your registered assets',
                body: 'Photos, videos, audio, documents, and creative work.',
              ),
              const SizedBox(height: 10),
              const _LibraryHint(
                icon: Icons.account_tree_outlined,
                title: 'Version history',
                body: 'Changes and branches linked to each asset.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryHint extends StatelessWidget {
  const _LibraryHint({
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
        minLeadingWidth: 26,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }
}
