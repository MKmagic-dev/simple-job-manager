import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Holds the async state of the sign-in submission (idle / loading / error).
/// The login screen watches this to show a spinner and surface errors,
/// while the actual "am I logged in" state lives in [authStateChangesProvider].
class LoginController extends StateNotifier<AsyncValue<void>> {
  LoginController(this._authRepository) : super(const AsyncValue.data(null));

  final AuthRepository _authRepository;

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authRepository.signInWithPassword(email: email, password: password),
    );
  }
}

final loginControllerProvider =
    StateNotifierProvider.autoDispose<LoginController, AsyncValue<void>>((ref) {
  return LoginController(ref.watch(authRepositoryProvider));
});
