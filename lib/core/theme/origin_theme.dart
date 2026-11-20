import 'package:flutter/material.dart';

abstract final class OriginColors {
  static const lightBackground = Color(0xFFF8F3ED);
  static const lightSurface = Color(0xFFFFFCF8);
  static const lightPrimary = Color(0xFF91452F);
  static const lightPrimarySoft = Color(0xFFD28B6E);
  static const lightForeground = Color(0xFF281C17);
  static const lightMuted = Color(0xFF69564D);
  static const lightBorder = Color(0xFFE6D9CF);

  static const darkBackground = Color(0xFF171311);
  static const darkSurface = Color(0xFF221B17);
  static const darkPrimary = Color(0xFFDDA28D);
  static const darkPrimarySoft = Color(0xFFE7B8A7);
  static const darkForeground = Color(0xFFF7EEE8);
  static const darkMuted = Color(0xFFC5B4AA);
  static const darkBorder = Color(0xFF493A32);
}

abstract final class OriginTheme {
  static final light = _buildTheme(Brightness.light);
  static final dark = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? OriginColors.darkBackground
        : OriginColors.lightBackground;
    final surface = isDark
        ? OriginColors.darkSurface
        : OriginColors.lightSurface;
    final foreground = isDark
        ? OriginColors.darkForeground
        : OriginColors.lightForeground;
    final primary = isDark
        ? OriginColors.darkPrimary
        : OriginColors.lightPrimary;
    final muted = isDark ? OriginColors.darkMuted : OriginColors.lightMuted;
    final border = isDark ? OriginColors.darkBorder : OriginColors.lightBorder;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF91452F),
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: isDark ? const Color(0xFF2A1711) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF513126)
              : const Color(0xFFF0DED5),
          onPrimaryContainer: isDark
              ? OriginColors.darkForeground
              : OriginColors.lightForeground,
          secondary: isDark
              ? OriginColors.darkPrimarySoft
              : OriginColors.lightPrimarySoft,
          onSecondary: isDark
              ? const Color(0xFF2A1711)
              : OriginColors.lightForeground,
          surface: surface,
          onSurface: foreground,
          surfaceContainerHighest: isDark
              ? const Color(0xFF302722)
              : const Color(0xFFF0E8E0),
          onSurfaceVariant: muted,
          outline: border,
          outlineVariant: border,
          error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
          onError: isDark ? const Color(0xFF690005) : Colors.white,
        );

    final baseText = ThemeData(brightness: brightness).textTheme;
    final textTheme = baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.12,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.18,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: foreground),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: isDark
            ? const Color(0xFF513126)
            : const Color(0xFFF0DED5),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primary : muted,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
    );
  }
}
