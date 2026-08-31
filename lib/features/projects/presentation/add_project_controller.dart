import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_repository.dart';

class PickedProjectAttachment {
  const PickedProjectAttachment({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class AddProjectController extends StateNotifier<AsyncValue<void>> {
  AddProjectController(this._ref, this._projectRepository)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  final ProjectRepository _projectRepository;

  Future<bool> submit({
    required String companyId,
    required String name,
    String? address,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    List<PickedProjectAttachment> attachments = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final projectId = await _projectRepository.createProject(
        companyId: companyId,
        name: name,
        address: address,
        description: description,
        startDate: startDate,
        endDate: endDate,
        color: color,
      );

      for (final attachment in attachments) {
        await _projectRepository.uploadAttachment(
          companyId: companyId,
          projectId: projectId,
          fileName: attachment.fileName,
          bytes: attachment.bytes,
        );
      }
    });

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(projectListProvider);
    }
    return success;
  }

  Future<bool> update({
    required String companyId,
    required String projectId,
    required String name,
    String? address,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    List<PickedProjectAttachment> attachments = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _projectRepository.updateProject(
        projectId: projectId,
        name: name,
        address: address,
        description: description,
        startDate: startDate,
        endDate: endDate,
        color: color,
      );

      for (final attachment in attachments) {
        await _projectRepository.uploadAttachment(
          companyId: companyId,
          projectId: projectId,
          fileName: attachment.fileName,
          bytes: attachment.bytes,
        );
      }
    });

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(projectListProvider);
      _ref.invalidate(projectAttachmentsProvider(projectId));
    }
    return success;
  }
}

final addProjectControllerProvider =
    StateNotifierProvider.autoDispose<AddProjectController, AsyncValue<void>>((
      ref,
    ) {
      return AddProjectController(ref, ref.watch(projectRepositoryProvider));
    });
