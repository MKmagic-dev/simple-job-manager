import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_controller.dart';
import '../../home/presentation/auth_gate.dart';
import '../../language/presentation/language_select_screen.dart';

/// Root of the app: shows the language picker on first launch (no saved
/// locale yet), then hands off to [AuthGate] once a language is chosen.
class AppStartupGate extends ConsumerWidget {
  const AppStartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeAsync = ref.watch(localeControllerProvider);

    return localeAsync.when(
      data: (locale) =>
          locale == null ? const LanguageSelectScreen() : const AuthGate(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => const LanguageSelectScreen(),
    );
  }
}
