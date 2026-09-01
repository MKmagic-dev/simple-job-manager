import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_controller.dart';

/// First-launch language picker. Shown once, before login, when no language
/// preference has been saved yet (see [LocaleController]).
///
/// Deliberately has no translated strings of its own: every label here is a
/// language's own native name, so it reads correctly no matter which
/// language the device/user ends up picking.
class LanguageSelectScreen extends ConsumerWidget {
  const LanguageSelectScreen({super.key});

  static const _options = [
    (locale: Locale('en'), label: 'English'),
    (locale: Locale('es'), label: 'Español'),
    (locale: Locale('fr'), label: 'Français'),
    (locale: Locale('pl'), label: 'Polski'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.language_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose your language\nElige tu idioma\nChoisissez votre langue\nWybierz język',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  for (final option in _options) ...[
                    OutlinedButton(
                      onPressed: () {
                        ref
                            .read(localeControllerProvider.notifier)
                            .setLocale(option.locale);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(option.label),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
