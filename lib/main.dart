import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/theme/origin_theme.dart';
import 'data/local/fingerprint_entry.dart';
import 'data/local/local_fingerprint_store.dart';
import 'firebase_options.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/registration/register_screen.dart';
import 'features/verification/verify_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  await LocalFingerprintStore.instance.initialize();
  runApp(const OriginChainApp());
}

class OriginChainApp extends StatefulWidget {
  const OriginChainApp({super.key});

  @override
  State<OriginChainApp> createState() => _OriginChainAppState();
}

class _OriginChainAppState extends State<OriginChainApp> {
  ThemeMode _themeMode = ThemeMode.system;
  FingerprintEntry? _lastFingerprint;

  @override
  void initState() {
    super.initState();
    _restoreLocalState();
  }

  Future<void> _restoreLocalState() async {
    final store = LocalFingerprintStore.instance;
    final entry = await store.latest();
    final savedMode = await store.preference('theme_mode');
    if (!mounted) return;
    setState(() {
      _lastFingerprint = entry;
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => ThemeMode.system,
      );
    });
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    unawaited(
      LocalFingerprintStore.instance.savePreference('theme_mode', mode.name),
    );
  }

  Future<void> _saveFingerprint(FingerprintEntry entry) async {
    await LocalFingerprintStore.instance.save(entry);
    if (mounted) setState(() => _lastFingerprint = entry);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OriginChain',
      debugShowCheckedModeBanner: false,
      theme: OriginTheme.light,
      darkTheme: OriginTheme.dark,
      themeMode: _themeMode,
      home: OriginGate(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
        lastFingerprint: _lastFingerprint,
        onFingerprintReady: _saveFingerprint,
      ),
    );
  }
}

class OriginGate extends StatefulWidget {
  const OriginGate({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.lastFingerprint,
    required this.onFingerprintReady,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final FingerprintEntry? lastFingerprint;
  final Future<void> Function(FingerprintEntry) onFingerprintReady;

  @override
  State<OriginGate> createState() => _OriginGateState();
}

class _OriginGateState extends State<OriginGate> {
  bool? _hasSeenWelcome;

  @override
  void initState() {
    super.initState();
    LocalFingerprintStore.instance.preference('welcome_seen').then((value) {
      if (mounted) setState(() => _hasSeenWelcome = value == 'true');
    });
  }

  Future<void> _continueAsGuest() async {
    await LocalFingerprintStore.instance.savePreference('welcome_seen', 'true');
    if (mounted) setState(() => _hasSeenWelcome = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenWelcome == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasSeenWelcome!) {
      return WelcomeScreen(onContinue: _continueAsGuest);
    }
    return OriginShell(
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
      lastFingerprint: widget.lastFingerprint,
      onFingerprintReady: widget.onFingerprintReady,
    );
  }
}

class OriginShell extends StatefulWidget {
  const OriginShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.lastFingerprint,
    required this.onFingerprintReady,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final FingerprintEntry? lastFingerprint;
  final Future<void> Function(FingerprintEntry) onFingerprintReady;

  @override
  State<OriginShell> createState() => _OriginShellState();
}

class _OriginShellState extends State<OriginShell> {
  int _selectedIndex = kIsWeb && Uri.base.queryParameters.containsKey('record')
      ? 3
      : 0;

  static const _destinations = [
    _Destination('Home', Icons.home_outlined, Icons.home_rounded),
    _Destination('Library', Icons.folder_outlined, Icons.folder_rounded),
    _Destination('Register', Icons.add_circle_outline, Icons.add_circle),
    _Destination('Verify', Icons.verified_outlined, Icons.verified_rounded),
    _Destination('Profile', Icons.person_outline, Icons.person_rounded),
  ];

  void _select(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        lastFingerprint: widget.lastFingerprint,
        onRegisterTap: () => _select(2),
        onVerifyTap: () => _select(3),
      ),
      LibraryScreen(onRegisterTap: () => _select(2)),
      RegisterScreen(onFingerprintReady: widget.onFingerprintReady),
      VerifyScreen(
        recordId: kIsWeb ? Uri.base.queryParameters['record'] : null,
      ),
      ProfileScreen(
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];
    final reduceTransparency = MediaQuery.highContrastOf(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      extendBody: !isWide,
      body: SafeArea(
        top: true,
        bottom: isWide,
        child: Row(
          children: [
            if (isWide)
              _DesktopNavigation(
                destinations: _destinations,
                selectedIndex: _selectedIndex,
                onSelected: _select,
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: IndexedStack(index: _selectedIndex, children: pages),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: reduceTransparency
                      ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                      : ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface
                          .withValues(alpha: reduceTransparency ? 1 : 0.82),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline
                            .withValues(alpha: reduceTransparency ? 1 : 0.65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.18
                                : 0.08,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: List.generate(_destinations.length, (index) {
                        final destination = _destinations[index];
                        final selected = index == _selectedIndex;
                        final color = selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label: destination.label,
                            child: InkWell(
                              onTap: () => _select(index),
                              borderRadius: BorderRadius.circular(24),
                              child: SizedBox(
                                height: 68,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      selected
                                          ? destination.active
                                          : destination.icon,
                                      size: 22,
                                      color: color,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      destination.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: color,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 28),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.all_inclusive_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'OriginChain',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < destinations.length; index++) ...[
            _DesktopNavigationItem(
              destination: destinations[index],
              selected: selectedIndex == index,
              onPressed: () => onSelected(index),
            ),
            if (index < destinations.length - 1) const SizedBox(height: 6),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'OriginChain covers Solana network fees.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    selected ? destination.active : destination.icon,
                    size: 21,
                    color: color,
                  ),
                  const SizedBox(width: 13),
                  Text(
                    destination.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.active);

  final String label;
  final IconData icon;
  final IconData active;
}
