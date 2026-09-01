import 'package:flutter/material.dart';

import '../config/branding_config.dart';

class AppTheme {
  AppTheme._();

  /// Near-black "ink" — the black in the cream/black/neon-green palette.
  /// Used for the app bar and for button/border text that would otherwise
  /// default to the neon green primary color, which reads too faint on the
  /// cream background (fine as a big block of color, weak as small text).
  static const _ink = Color(0xFF14181C);

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
}
