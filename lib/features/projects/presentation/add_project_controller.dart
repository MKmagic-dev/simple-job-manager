import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_repository.dart';

class AddProjectController extends StateNotifier<AsyncValue<void>> {
  AddProjectController(this._ref, this._projectRepository) : super(const AsyncValue.data(null));

  final Ref _ref;
  final ProjectRepository _projectRepository;

  Future<bool> submit({
    required String companyId,
    required String name,
    String? address,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _projectRepository.createProject(
        companyId: companyId,
        name: name,
        address: address,
        description: description,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(projectListProvider);
    }
    return success;
  }

  Future<bool> update({
    required String projectId,
    required String name,
    String? address,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _projectRepository.updateProject(
        projectId: projectId,
        name: name,
        address: address,
        description: description,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    final success = !state.hasError;
    if (success) {
      _ref.invalidate(projectListProvider);
    }
    return success;
  }
}

final addProjectControllerProvider =
    StateNotifierProvider.autoDispose<AddProjectController, AsyncValue<void>>((ref) {
  return AddProjectController(ref, ref.watch(projectRepositoryProvider));
});
