import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/employee_repository.dart';

class AddEmployeeController extends StateNotifier<AsyncValue<void>> {
  AddEmployeeController(this._ref, this._employeeRepository)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  final EmployeeRepository _employeeRepository;

  /// Returns the new employee's id on success, or null on failure.
  Future<String?> submit({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    String? newEmployeeId;
    state = await AsyncValue.guard(() async {
      newEmployeeId = await _employeeRepository.createEmployee(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
    });

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(employeeListProvider);
    }
    return success ? newEmployeeId : null;
  }
}

final addEmployeeControllerProvider =
    StateNotifierProvider.autoDispose<AddEmployeeController, AsyncValue<void>>((
      ref,
    ) {
      return AddEmployeeController(ref, ref.watch(employeeRepositoryProvider));
    });
