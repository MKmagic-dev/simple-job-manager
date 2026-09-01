import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';

class UpdateProfileController extends StateNotifier<AsyncValue<void>> {
  UpdateProfileController(this._ref, this._profileRepository)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  final ProfileRepository _profileRepository;

  Future<bool> saveDetails({required String fullName, String? phone}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () =>
          _profileRepository.updateMyProfile(fullName: fullName, phone: phone),
    );
    final success = !state.hasError;
    if (success) {
      _ref.invalidate(currentProfileProvider);
    }
    return success;
  }

  Future<bool> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _profileRepository.uploadMyAvatar(
        bytes: bytes,
        fileExtension: fileExtension,
      ),
    );
    final success = !state.hasError;
    if (success) {
      _ref.invalidate(currentProfileProvider);
    }
    return success;
  }
}

final updateProfileControllerProvider =
    StateNotifierProvider.autoDispose<
      UpdateProfileController,
      AsyncValue<void>
    >((ref) {
      return UpdateProfileController(ref, ref.watch(profileRepositoryProvider));
    });
