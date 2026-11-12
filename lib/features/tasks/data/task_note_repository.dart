import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/task_note_model.dart';

class TaskNoteRepository {
  TaskNoteRepository(this._client);

  final SupabaseClient _client;

  /// RLS decides what comes back: the boss sees every note of the task, an
  /// employee only the ones they wrote.
  Future<List<TaskNoteModel>> fetchNotes(String taskId) async {
    final data = await _client
        .from('task_notes')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: false);
    return data.map(TaskNoteModel.fromJson).toList();
  }

  /// How many notes are still unread, per task (the boss sees all of them).
  Future<Map<String, int>> fetchUnreadCounts() async {
    final data = await _client
        .from('task_notes')
        .select('task_id')
        .isFilter('read_at', null);
    final counts = <String, int>{};
    for (final row in data) {
      final taskId = row['task_id'] as String;
      counts[taskId] = (counts[taskId] ?? 0) + 1;
    }
    return counts;
  }

  /// The boss opened the task: its notes are read now.
  Future<void> markRead(String taskId) async {
    await _client
        .from('task_notes')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('task_id', taskId)
        .isFilter('read_at', null);
  }

  Future<void> addNote({
    required String companyId,
    required String taskId,
    required String content,
  }) async {
    await _client.from('task_notes').insert({
      'task_id': taskId,
      'company_id': companyId,
      'author_id': _client.auth.currentUser!.id,
      'content': content.trim(),
    });
  }

  Future<void> deleteNote(String noteId) {
    return _client.from('task_notes').delete().eq('id', noteId);
  }
}

final taskNoteRepositoryProvider = Provider<TaskNoteRepository>((ref) {
  return TaskNoteRepository(ref.watch(supabaseClientProvider));
});

/// Call `ref.invalidate(taskNoteListProvider(taskId))` after adding/deleting.
final taskNoteListProvider = FutureProvider.autoDispose
    .family<List<TaskNoteModel>, String>((ref, taskId) {
      return ref.watch(taskNoteRepositoryProvider).fetchNotes(taskId);
    });

/// Unread employee notes per task id. Call
/// `ref.invalidate(unreadTaskNotesProvider)` after marking some as read.
final unreadTaskNotesProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) {
  return ref.watch(taskNoteRepositoryProvider).fetchUnreadCounts();
});
