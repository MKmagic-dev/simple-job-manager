import 'dart:typed_data';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shift_repository.dart';

class PickedShiftAttachment {
  const PickedShiftAttachment({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class AddShiftController extends StateNotifier<AsyncValue<void>> {
  AddShiftController(this._ref, this._shiftRepository)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  final ShiftRepository _shiftRepository;

  /// Creates a shift for every chosen employee on every day from
  /// [startDate] to [endDate]. [attachments] are only uploaded when that
  /// produces exactly one shift (otherwise the same file would be stored
  /// once per shift).
  Future<bool> submit({
    required String companyId,
    required List<String> employeeIds,
    String? projectId,
    String? taskId,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? notes,
    List<PickedShiftAttachment> attachments = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final shiftIds = await _shiftRepository.createShifts(
        companyId: companyId,
        employeeIds: employeeIds,
        projectId: projectId,
        taskId: taskId,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );

      if (shiftIds.length == 1) {
        for (final attachment in attachments) {
          await _shiftRepository.uploadAttachment(
            companyId: companyId,
            shiftId: shiftIds.single,
            fileName: attachment.fileName,
            bytes: attachment.bytes,
          );
        }
      }
    });

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(shiftListProvider);
    }
    return success;
  }

  Future<bool> update({
    required String companyId,
    required String shiftId,
    required String employeeId,
    String? projectId,
    String? taskId,
    required DateTime workDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? notes,
    List<PickedShiftAttachment> attachments = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _shiftRepository.updateShift(
        shiftId: shiftId,
        employeeId: employeeId,
        projectId: projectId,
        taskId: taskId,
        workDate: workDate,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );

      for (final attachment in attachments) {
        await _shiftRepository.uploadAttachment(
          companyId: companyId,
          shiftId: shiftId,
          fileName: attachment.fileName,
          bytes: attachment.bytes,
        );
      }
    });

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(shiftListProvider);
      _ref.invalidate(shiftAttachmentsProvider(shiftId));
    }
    return success;
  }
}

final addShiftControllerProvider =
    StateNotifierProvider.autoDispose<AddShiftController, AsyncValue<void>>((
      ref,
    ) {
      return AddShiftController(ref, ref.watch(shiftRepositoryProvider));
    });
