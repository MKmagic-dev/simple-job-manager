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
