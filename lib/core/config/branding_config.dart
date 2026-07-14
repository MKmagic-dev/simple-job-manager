import 'package:flutter/material.dart';

/// Everything that changes when this app is white-labeled for a different
/// client company. To deploy a new client build, this is the only file that
/// should need editing (plus swapping the logo asset and the `.env` file).
class BrandingConfig {
  BrandingConfig._();

  static const String appName = 'Simple Job Manager';

  static const Color seedColor = Color(0xFF2E5C4E);

  /// Path to the logo asset, relative to the project root. Must also be
  /// listed under `flutter.assets` in pubspec.yaml.
  static const String logoAssetPath = 'assets/logo.png';
}
