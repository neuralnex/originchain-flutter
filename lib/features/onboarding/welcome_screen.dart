import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 44,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(15),
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
                      ],
                    ),
                    const SizedBox(height: 40),
                    Container(
                      width: double.infinity,
                      height: 235,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: theme.brightness == Brightness.dark
                              ? const [Color(0xFF3C2922), Color(0xFF211916)]
                              : const [Color(0xFFF0DED5), Color(0xFFEBD7CB)],
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            right: 8,
                            top: 4,
                            child: Icon(
                              Icons.blur_on_rounded,
                              size: 190,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.09,
                              ),
                            ),
                          ),
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(
                                alpha: 0.72,
                              ),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              size: 56,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Give your work\na clear origin.',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create a record of your digital assets and make their history easier to verify.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _WelcomePoint(
                      icon: Icons.lock_outline_rounded,
                      title: 'Your files stay private',
                      detail: 'Fingerprints are created on your device.',
                    ),
                    const SizedBox(height: 12),
                    _WelcomePoint(
                      icon: Icons.payments_outlined,
                      title: 'No SOL needed',
                      detail:
                          'OriginChain covers network and transaction fees.',
                    ),
                    const Spacer(),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onContinue,
                        child: const Text('Continue as a guest'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'You can verify shared records without an account.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePoint extends StatelessWidget {
  const _WelcomePoint({
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
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
