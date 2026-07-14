import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/project_model.dart';

class ProjectRepository {
  ProjectRepository(this._client);

  final SupabaseClient _client;

  /// RLS restricts this to the caller's own company (see projects_owner_all
  /// / projects_employee_select policies) — no explicit company_id filter
  /// is needed here, the database enforces it either way.
  Future<List<ProjectModel>> fetchProjects() async {
    final data = await _client.from('projects').select().order('name');

    return (data as List<dynamic>)
        .map((row) => ProjectModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> createProject({
    required String companyId,
    required String name,
    String? address,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _client.from('projects').insert({
      'company_id': companyId,
      'name': name,
      if (address != null && address.isNotEmpty) 'address': address,
      if (description != null && description.isNotEmpty) 'description': description,
      if (startDate != null) 'start_date': _dateOnly(startDate),
      if (endDate != null) 'end_date': _dateOnly(endDate),
      'created_by': _client.auth.currentUser!.id,
    });
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(supabaseClientProvider));
});

/// The current company's project list. Call `ref.invalidate(projectListProvider)`
/// after adding a project to refresh it.
final projectListProvider = FutureProvider.autoDispose<List<ProjectModel>>((ref) {
  return ref.watch(projectRepositoryProvider).fetchProjects();
});
