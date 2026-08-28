import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

class RegisterCompanyController extends StateNotifier<AsyncValue<void>> {
  RegisterCompanyController(this._authRepository) : super(const AsyncValue.data(null));

  final AuthRepository _authRepository;

  Future<bool> submit({
    required String companyName,
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authRepository.registerCompany(
        companyName: companyName,
        email: email,
        password: password,
        fullName: fullName,
      ),
    );
    return !state.hasError;
  }
}

final registerCompanyControllerProvider =
    StateNotifierProvider.autoDispose<RegisterCompanyController, AsyncValue<void>>((ref) {
  return RegisterCompanyController(ref.watch(authRepositoryProvider));
});
