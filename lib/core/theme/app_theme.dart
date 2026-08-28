import 'package:flutter/material.dart';

import '../config/branding_config.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: BrandingConfig.seedColor).copyWith(
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
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2421),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }
}
