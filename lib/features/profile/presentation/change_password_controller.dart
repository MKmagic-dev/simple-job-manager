import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';

class ChangePasswordController extends StateNotifier<AsyncValue<void>> {
  ChangePasswordController(this._authRepository) : super(const AsyncValue.data(null));

  final AuthRepository _authRepository;

  Future<bool> submit(String newPassword) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.updatePassword(newPassword));
    return !state.hasError;
  }
}

final changePasswordControllerProvider =
    StateNotifierProvider.autoDispose<ChangePasswordController, AsyncValue<void>>((ref) {
  return ChangePasswordController(ref.watch(authRepositoryProvider));
});
