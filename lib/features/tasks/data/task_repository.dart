import 'dart:typed_data';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/project_task_model.dart';
import '../domain/task_attachment_model.dart';
import '../domain/task_completion_notice_model.dart';

class TaskRepository {
  TaskRepository(this._client);

  final SupabaseClient _client;

  static const _attachmentBucket = 'task-attachments';

  /// RLS restricts this automatically: an owner sees every task in their
  /// company, an employee only the tasks they have a shift on.
  Future<List<ProjectTaskModel>> fetchTasks() async {
    final data = await _client
        .from('project_tasks')
        .select()
        .order('start_date', ascending: true)
        .order('created_at', ascending: true);

    return (data as List<dynamic>)
        .map((row) => ProjectTaskModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the new task's id so attachments can be uploaded against it
  /// right after.
  Future<String> createTask({
    required String companyId,
    required String projectId,
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    final row = await _client
        .from('project_tasks')
        .insert({
          'company_id': companyId,
          'project_id': projectId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'start_date': _dateOnly(startDate),
          'end_date': _dateOnly(endDate),
          if (startTime != null && endTime != null) ...{
            'start_time': _timeOnly(startTime),
            'end_time': _timeOnly(endTime),
          },
          'created_by': _client.auth.currentUser!.id,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateTask({
    required String taskId,
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    await _client
        .from('project_tasks')
        .update({
          'title': title,
          'description': description != null && description.isNotEmpty
              ? description
              : null,
          'start_date': _dateOnly(startDate),
          'end_date': _dateOnly(endDate),
          'start_time': startTime != null && endTime != null
              ? _timeOnly(startTime)
              : null,
          'end_time': startTime != null && endTime != null
              ? _timeOnly(endTime)
              : null,
        })
        .eq('id', taskId);
  }

  /// Archives or restores a task (owner-only in practice). Archiving also
  /// clears the "this task is done" notices on it.
  Future<void> setArchived(String taskId, {required bool archived}) async {
    await _client
        .from('project_tasks')
        .update({
          'archived_at': archived
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        })
        .eq('id', taskId);
    if (archived) {
      await _client
          .from('task_completion_notices')
          .delete()
          .eq('task_id', taskId);
    }
  }

  /// RLS restricts this automatically: an owner sees every notice in their
  /// company, an employee only their own.
  Future<List<TaskCompletionNoticeModel>> fetchCompletionNotices() async {
    final data = await _client
        .from('task_completion_notices')
        .select()
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map(
          (row) =>
              TaskCompletionNoticeModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> submitCompletionNotice(String taskId) async {
    await _client.from('task_completion_notices').insert({
      'task_id': taskId,
      'employee_id': _client.auth.currentUser!.id,
    });
  }

  /// Also removes the task's stored files — the attachment rows go away with
  /// the task via ON DELETE CASCADE, but the files in the bucket would
  /// otherwise be orphaned.
  Future<void> deleteTask(String taskId) async {
    final attachments = await fetchAttachments(taskId);
    if (attachments.isNotEmpty) {
      await _client.storage.from(_attachmentBucket).remove([
        for (final attachment in attachments) attachment.storagePath,
      ]);
    }
    await _client.from('project_tasks').delete().eq('id', taskId);
  }

  Future<List<TaskAttachmentModel>> fetchAttachments(String taskId) async {
    final data = await _client
        .from('task_attachments')
        .select()
        .eq('task_id', taskId)
        .order('created_at');

    return (data as List<dynamic>)
        .map((row) => TaskAttachmentModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Every attachment on every task of [projectId] — for the project's
  /// combined gallery.
  Future<List<TaskAttachmentModel>> fetchAttachmentsForProject(
    String projectId,
  ) async {
    final data = await _client
        .from('task_attachments')
        .select('*, project_tasks!inner(project_id)')
        .eq('project_tasks.project_id', projectId)
        .order('created_at');

    return (data as List<dynamic>)
        .map((row) => TaskAttachmentModel.fromJson(row as Map<String, dynamic>))
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
    required String taskId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    // Storage RLS requires <company id>/<task id>/ as the first two path
    // segments (see supabase/migrations/20260921100000_project_tasks.sql).
    final path =
        '$companyId/$taskId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from(_attachmentBucket).uploadBinary(path, bytes);

    await _client.from('task_attachments').insert({
      'task_id': taskId,
      'company_id': companyId,
      'storage_path': path,
      'uploaded_by': _client.auth.currentUser!.id,
    });
  }

  Future<void> deleteAttachment(String id, String storagePath) async {
    await _client.storage.from(_attachmentBucket).remove([storagePath]);
    await _client.from('task_attachments').delete().eq('id', id);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _timeOnly(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(supabaseClientProvider));
});

/// Call `ref.invalidate(taskListProvider)` after adding/editing/deleting a
/// task to refresh it.
final taskListProvider = FutureProvider.autoDispose<List<ProjectTaskModel>>((
  ref,
) {
  return ref.watch(taskRepositoryProvider).fetchTasks();
});

final taskAttachmentsProvider = FutureProvider.autoDispose
    .family<List<TaskAttachmentModel>, String>((ref, taskId) {
      return ref.watch(taskRepositoryProvider).fetchAttachments(taskId);
    });

final projectTaskAttachmentsProvider = FutureProvider.autoDispose
    .family<List<TaskAttachmentModel>, String>((ref, projectId) {
      return ref
          .watch(taskRepositoryProvider)
          .fetchAttachmentsForProject(projectId);
    });

/// Cached per storage path so re-opening the same attachment doesn't
/// re-request a signed URL every time.
final taskAttachmentSignedUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, storagePath) {
      return ref
          .watch(taskRepositoryProvider)
          .getAttachmentSignedUrl(storagePath);
    });

/// Call `ref.invalidate(taskCompletionNoticeListProvider)` after an employee
/// reports a task done or the boss archives it.
final taskCompletionNoticeListProvider =
    FutureProvider.autoDispose<List<TaskCompletionNoticeModel>>((ref) {
      return ref.watch(taskRepositoryProvider).fetchCompletionNotices();
    });
