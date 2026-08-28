import 'package:flutter/material.dart';

/// Everything that changes when this app is white-labeled for a different
/// client company. To deploy a new client build, this is the only file that
/// should need editing (plus swapping the logo asset and the `.env` file).
class BrandingConfig {
  BrandingConfig._();

  static const String appName = 'Simple Job Manager';

  static const Color seedColor = Color(0xFF4C8B14);

  /// The neon-green brand accent used for primary buttons, the FAB, and
  /// selected states — kept separate from [seedColor] (which drives the
  /// rest of the Material 3 tonal palette) because it's more saturated
  /// than a seed color should be.
  static const Color accentColor = Color(0xFFB6F04A);
  static const Color onAccentColor = Color(0xFF1F3403);

  static const Color secondaryAccentColor = Color(0xFFFFD84D);
  static const Color onSecondaryAccentColor = Color(0xFF3A2E00);

  /// Path to the logo asset, relative to the project root. Must also be
  /// listed under `flutter.assets` in pubspec.yaml.
  static const String logoAssetPath = 'assets/logo.png';
}
