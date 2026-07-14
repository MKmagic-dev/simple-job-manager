import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/instruction_repository.dart';

class AddInstructionController extends StateNotifier<AsyncValue<void>> {
  AddInstructionController(this._ref, this._instructionRepository) : super(const AsyncValue.data(null));

  final Ref _ref;
  final InstructionRepository _instructionRepository;

  Future<bool> submit({
    required String companyId,
    required String employeeId,
    required String title,
    String? content,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _instructionRepository.createInstruction(
        companyId: companyId,
        employeeId: employeeId,
        title: title,
        content: content,
      ),
    );

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(instructionListProvider);
    }
    return success;
  }
}

final addInstructionControllerProvider =
    StateNotifierProvider.autoDispose<AddInstructionController, AsyncValue<void>>((ref) {
  return AddInstructionController(ref, ref.watch(instructionRepositoryProvider));
});
