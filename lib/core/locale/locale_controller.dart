import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsLocaleKey = 'locale_code';

/// The user's chosen app language.
///
/// `AsyncValue.data(null)` means "no language chosen yet" (first launch) —
/// that's the signal [main.dart]'s startup gate uses to show the language
/// picker instead of the app. Once chosen, the value is persisted so it
/// survives app restarts.
class LocaleController extends StateNotifier<AsyncValue<Locale?>> {
  LocaleController() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsLocaleKey);
    state = AsyncValue.data(code == null ? null : Locale(code));
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLocaleKey, locale.languageCode);
    state = AsyncValue.data(locale);
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, AsyncValue<Locale?>>((ref) {
      return LocaleController();
    });
