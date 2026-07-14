import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/work_photo_repository.dart';

class AddWorkPhotoController extends StateNotifier<AsyncValue<void>> {
  AddWorkPhotoController(this._ref, this._workPhotoRepository) : super(const AsyncValue.data(null));

  final Ref _ref;
  final WorkPhotoRepository _workPhotoRepository;

  Future<bool> submit({
    required String companyId,
    required String employeeId,
    String? shiftId,
    String? caption,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _workPhotoRepository.uploadWorkPhoto(
        companyId: companyId,
        employeeId: employeeId,
        shiftId: shiftId,
        caption: caption,
        bytes: bytes,
        fileExtension: fileExtension,
      ),
    );

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(workPhotoListProvider);
    }
    return success;
  }
}

final addWorkPhotoControllerProvider =
    StateNotifierProvider.autoDispose<AddWorkPhotoController, AsyncValue<void>>((ref) {
  return AddWorkPhotoController(ref, ref.watch(workPhotoRepositoryProvider));
});
