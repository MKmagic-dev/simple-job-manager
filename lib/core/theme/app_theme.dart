import 'package:flutter/material.dart';

import '../config/branding_config.dart';

class AppTheme {
  AppTheme._();

  /// Near-black "ink" — the black in the cream/black/neon-green palette.
  /// Used for the app bar and for button/border text that would otherwise
  /// default to the neon green primary color, which reads too faint on the
  /// cream background (fine as a big block of color, weak as small text).
  /// Public so other widgets (e.g. the boss sidebar) can match it.
  static const ink = Color(0xFF14181C);
  static const _ink = ink;

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(seedColor: BrandingConfig.seedColor).copyWith(
          primary: BrandingConfig.accentColor,
          onPrimary: BrandingConfig.onAccentColor,
          primaryContainer: BrandingConfig.accentColor,
          onPrimaryContainer: BrandingConfig.onAccentColor,
          secondary: BrandingConfig.secondaryAccentColor,
          onSecondary: BrandingConfig.onSecondaryAccentColor,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8F3),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _ink,
        foregroundColor: Color(0xFFF7F8F3),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: BrandingConfig.accentColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: _ink, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _ink),
      ),
    );
  }

  /// The app's look: near-black surfaces, dark-grey cards and neon-lime
  /// accents (filled lime buttons with dark text, lime outlines and
  /// highlights).
  static ThemeData get dark {
    const background = Color(0xFF0E1114);
    const card = Color(0xFF171B20);
    const onSurface = Color(0xFFEDEFE8);
    final accent = BrandingConfig.accentColor;
    final onAccent = BrandingConfig.onAccentColor;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: BrandingConfig.seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          primaryContainer: accent,
          onPrimaryContainer: onAccent,
          secondary: BrandingConfig.secondaryAccentColor,
          onSecondary: BrandingConfig.onSecondaryAccentColor,
          secondaryContainer: const Color(0xFF2B3A14),
          onSecondaryContainer: accent,
          surface: card,
          onSurface: onSurface,
          onSurfaceVariant: const Color(0xFF9BA5A0),
          surfaceContainerLowest: background,
          surfaceContainerLow: card,
          surfaceContainer: const Color(0xFF1B2025),
          surfaceContainerHigh: const Color(0xFF20262C),
          surfaceContainerHighest: const Color(0xFF272E35),
          outline: const Color(0xFF5E6963),
          outlineVariant: const Color(0xFF2E363C),
          error: const Color(0xFFFF7A7A),
          onError: const Color(0xFF2A0000),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: colorScheme.outlineVariant,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: accent),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _ink,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.55)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: const TextStyle(color: onSurface),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    );
  }
}
