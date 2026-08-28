import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/instruction_repository.dart';

class PickedAttachment {
  const PickedAttachment({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class AddInstructionController extends StateNotifier<AsyncValue<void>> {
  AddInstructionController(this._ref, this._instructionRepository) : super(const AsyncValue.data(null));

  final Ref _ref;
  final InstructionRepository _instructionRepository;

  Future<bool> submit({
    required String companyId,
    required String employeeId,
    required String title,
    String? content,
    List<PickedAttachment> attachments = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final instructionId = await _instructionRepository.createInstruction(
        companyId: companyId,
        employeeId: employeeId,
        title: title,
        content: content,
      );

      for (final attachment in attachments) {
        await _instructionRepository.uploadAttachment(
          companyId: companyId,
          instructionId: instructionId,
          fileName: attachment.fileName,
          bytes: attachment.bytes,
        );
      }
    });

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
