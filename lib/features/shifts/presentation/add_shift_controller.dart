import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shift_repository.dart';

class AddShiftController extends StateNotifier<AsyncValue<void>> {
  AddShiftController(this._ref, this._shiftRepository) : super(const AsyncValue.data(null));

  final Ref _ref;
  final ShiftRepository _shiftRepository;

  Future<bool> submit({
    required String companyId,
    required String employeeId,
    String? projectId,
    required DateTime workDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _shiftRepository.createShift(
        companyId: companyId,
        employeeId: employeeId,
        projectId: projectId,
        workDate: workDate,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      ),
    );

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(shiftListProvider);
    }
    return success;
  }
}

final addShiftControllerProvider =
    StateNotifierProvider.autoDispose<AddShiftController, AsyncValue<void>>((ref) {
  return AddShiftController(ref, ref.watch(shiftRepositoryProvider));
});
