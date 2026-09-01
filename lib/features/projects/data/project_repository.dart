import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/project_attachment_model.dart';
import '../domain/project_completion_notice_model.dart';
import '../domain/project_model.dart';

class ProjectRepository {
  ProjectRepository(this._client);

  final SupabaseClient _client;

  static const _attachmentBucket = 'project-attachments';

  /// RLS restricts this to the caller's own company (see projects_owner_all
  /// / projects_employee_select policies) — no explicit company_id filter
  /// is needed here, the database enforces it either way.
  Future<List<ProjectModel>> fetchProjects() async {
    final data = await _client.from('projects').select().order('name');

    return (data as List<dynamic>)
        .map((row) => ProjectModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the new project's id so attachments can be uploaded against
  /// it right after.
  Future<String> createProject({
    required String companyId,
    required String name,
    String? address,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
  }) async {
    final row = await _client
        .from('projects')
        .insert({
          'company_id': companyId,
          'name': name,
          if (address != null && address.isNotEmpty) 'address': address,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (startDate != null) 'start_date': _dateOnly(startDate),
          if (endDate != null) 'end_date': _dateOnly(endDate),
          'color': ?color,
          'created_by': _client.auth.currentUser!.id,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Owner-only in practice: projects_owner_all is the only RLS policy that
  /// permits an update, and it's scoped to the caller's own company.
  Future<void> updateProject({
    required String projectId,
    required String name,
    String? address,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
  }) async {
    await _client
        .from('projects')
        .update({
          'name': name,
          'address': address != null && address.isNotEmpty ? address : null,
          'description': description != null && description.isNotEmpty
              ? description
              : null,
          'start_date': startDate != null ? _dateOnly(startDate) : null,
          'end_date': endDate != null ? _dateOnly(endDate) : null,
          'color': color,
        })
        .eq('id', projectId);
  }

  /// Owner-only in practice, same as [updateProject].
  Future<void> deleteProject(String projectId) {
    return _client.from('projects').delete().eq('id', projectId);
  }

  Future<List<ProjectAttachmentModel>> fetchAttachments(
    String projectId,
  ) async {
    final data = await _client
        .from('project_attachments')
        .select()
        .eq('project_id', projectId)
        .order('created_at');

    return (data as List<dynamic>)
        .map(
          (row) => ProjectAttachmentModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  /// The bucket is private, so every open of an attachment needs a fresh,
  /// time-limited signed URL rather than a plain public link.
  Future<String> getAttachmentSignedUrl(String storagePath) {
    return _client.storage
        .from(_attachmentBucket)
        .createSignedUrl(storagePath, 3600);
  }

  Future<void> uploadAttachment({
    required String companyId,
    required String projectId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    // Storage RLS requires the first path segment to be the company id (see
    // supabase/migrations/20260830100000_project_attachments.sql).
    final path =
        '$companyId/$projectId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from(_attachmentBucket).uploadBinary(path, bytes);

    await _client.from('project_attachments').insert({
      'project_id': projectId,
      'storage_path': path,
      'uploaded_by': _client.auth.currentUser!.id,
    });
  }

  Future<void> deleteAttachment(String id, String storagePath) async {
    await _client.storage.from(_attachmentBucket).remove([storagePath]);
    await _client.from('project_attachments').delete().eq('id', id);
  }

  /// RLS restricts this automatically: an owner sees every notice on a
  /// project in their company, an employee only their own.
  Future<List<ProjectCompletionNoticeModel>> fetchCompletionNotices() async {
    final data = await _client
        .from('project_completion_notices')
        .select()
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map(
          (row) => ProjectCompletionNoticeModel.fromJson(
            row as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> submitCompletionNotice(String projectId) async {
    await _client.from('project_completion_notices').insert({
      'project_id': projectId,
      'employee_id': _client.auth.currentUser!.id,
    });
  }

  /// Owner action once they've acknowledged it — there's no "resolved"
  /// flag, dismissing just removes the notice.
  Future<void> dismissCompletionNotice(String id) {
    return _client.from('project_completion_notices').delete().eq('id', id);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(supabaseClientProvider));
});

/// The current company's project list. Call `ref.invalidate(projectListProvider)`
/// after adding a project to refresh it.
final projectListProvider = FutureProvider.autoDispose<List<ProjectModel>>((
  ref,
) {
  return ref.watch(projectRepositoryProvider).fetchProjects();
});

final projectAttachmentsProvider = FutureProvider.autoDispose
    .family<List<ProjectAttachmentModel>, String>((ref, projectId) {
      return ref.watch(projectRepositoryProvider).fetchAttachments(projectId);
    });

/// Cached per storage path so re-opening the same attachment doesn't
/// re-request a signed URL every time.
final projectAttachmentSignedUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, storagePath) {
      return ref
          .watch(projectRepositoryProvider)
          .getAttachmentSignedUrl(storagePath);
    });

/// Call `ref.invalidate(projectCompletionNoticeListProvider)` after
/// submitting or dismissing a notice to refresh it.
final projectCompletionNoticeListProvider =
    FutureProvider.autoDispose<List<ProjectCompletionNoticeModel>>((ref) {
      return ref.watch(projectRepositoryProvider).fetchCompletionNotices();
    });
