import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/note_model.dart';

class NoteRepository {
  NoteRepository(this._client);

  final SupabaseClient _client;

  /// RLS restricts this: a boss sees every note of the company, an employee
  /// only the notes shared with them.
  Future<List<NoteModel>> fetchNotes() async {
    final data = await _client
        .from('notes')
        .select()
        .order('created_at', ascending: false);
    return (data as List<dynamic>)
        .map((row) => NoteModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Who each note is shared with (a boss sees all of it; an employee only
  /// their own rows).
  Future<List<NoteRecipientModel>> fetchRecipients() async {
    final data = await _client.from('note_recipients').select();
    return (data as List<dynamic>)
        .map((row) => NoteRecipientModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the new note's id.
  Future<String> createNote({
    required String companyId,
    required String title,
    String? content,
  }) async {
    final row = await _client
        .from('notes')
        .insert({
          'company_id': companyId,
          'created_by': _client.auth.currentUser!.id,
          'title': title,
          'content': content != null && content.isNotEmpty ? content : null,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateNote({
    required String noteId,
    required String title,
    String? content,
  }) async {
    await _client
        .from('notes')
        .update({
          'title': title,
          'content': content != null && content.isNotEmpty ? content : null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', noteId);
  }

  Future<void> deleteNote(String noteId) {
    return _client.from('notes').delete().eq('id', noteId);
  }

  /// Makes [employeeIds] exactly the people the note is shared with.
  Future<void> setRecipients({
    required String noteId,
    required String companyId,
    required Set<String> employeeIds,
  }) async {
    final current = await _client
        .from('note_recipients')
        .select('employee_id')
        .eq('note_id', noteId);
    final existing = {
      for (final row in current as List<dynamic>)
        (row as Map<String, dynamic>)['employee_id'] as String,
    };

    final toRemove = existing.difference(employeeIds);
    if (toRemove.isNotEmpty) {
      await _client
          .from('note_recipients')
          .delete()
          .eq('note_id', noteId)
          .inFilter('employee_id', toRemove.toList());
    }
    final toAdd = employeeIds.difference(existing);
    if (toAdd.isNotEmpty) {
      await _client.from('note_recipients').insert([
        for (final id in toAdd)
          {'note_id': noteId, 'employee_id': id, 'company_id': companyId},
      ]);
    }
  }
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(supabaseClientProvider));
});

/// Call `ref.invalidate(noteListProvider)` after adding/editing/deleting.
final noteListProvider = FutureProvider.autoDispose<List<NoteModel>>((ref) {
  return ref.watch(noteRepositoryProvider).fetchNotes();
});

final noteRecipientsProvider =
    FutureProvider.autoDispose<List<NoteRecipientModel>>((ref) {
      return ref.watch(noteRepositoryProvider).fetchRecipients();
    });
