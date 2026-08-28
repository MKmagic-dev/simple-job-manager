import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/instruction_attachment_model.dart';
import '../domain/instruction_model.dart';

class InstructionRepository {
  InstructionRepository(this._client);

  final SupabaseClient _client;

  static const _attachmentBucket = 'instruction-attachments';

  /// RLS restricts this automatically: an owner sees every instruction in
  /// their company (instructions_owner_all), an employee only sees ones
  /// addressed to them directly or via one of their own shifts
  /// (instructions_employee_select) — so this single method serves both
  /// the boss's and the worker's instructions screens.
  Future<List<InstructionModel>> fetchInstructions() async {
    final data = await _client.from('instructions').select().order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((row) => InstructionModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Targets a specific employee directly. Other targeting modes (by shift
  /// or by whole project) exist in the schema but aren't wired up in the UI
  /// yet — see the schema notes on why employee targeting is the only one
  /// guaranteed to actually be visible to the employee right now.
  ///
  /// Returns the new instruction's id so attachments can be uploaded
  /// against it right after.
  Future<String> createInstruction({
    required String companyId,
    required String employeeId,
    required String title,
    String? content,
  }) async {
    final row = await _client
        .from('instructions')
        .insert({
          'company_id': companyId,
          'employee_id': employeeId,
          'title': title,
          if (content != null && content.isNotEmpty) 'content': content,
          'created_by': _client.auth.currentUser!.id,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// RLS restricts this the same way as [fetchInstructions]: an owner sees
  /// every attachment on an instruction in their company, an employee only
  /// on instructions addressed to them.
  Future<List<InstructionAttachmentModel>> fetchAttachments(String instructionId) async {
    final data = await _client
        .from('instruction_photos')
        .select()
        .eq('instruction_id', instructionId)
        .order('created_at');

    return (data as List<dynamic>)
        .map((row) => InstructionAttachmentModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// The bucket is private, so every open of an attachment needs a fresh,
  /// time-limited signed URL rather than a plain public link.
  Future<String> getAttachmentSignedUrl(String storagePath) {
    return _client.storage.from(_attachmentBucket).createSignedUrl(storagePath, 3600);
  }

  Future<void> uploadAttachment({
    required String companyId,
    required String instructionId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    // Storage RLS requires the first path segment to be the company id (see
    // supabase/migrations/20260828100000_instruction_attachments_storage.sql).
    final path = '$companyId/$instructionId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from(_attachmentBucket).uploadBinary(path, bytes);

    await _client.from('instruction_photos').insert({
      'instruction_id': instructionId,
      'storage_path': path,
      'uploaded_by': _client.auth.currentUser!.id,
    });
  }
}

final instructionRepositoryProvider = Provider<InstructionRepository>((ref) {
  return InstructionRepository(ref.watch(supabaseClientProvider));
});

/// Call `ref.invalidate(instructionListProvider)` after adding an
/// instruction to refresh it.
final instructionListProvider = FutureProvider.autoDispose<List<InstructionModel>>((ref) {
  return ref.watch(instructionRepositoryProvider).fetchInstructions();
});

final instructionAttachmentsProvider =
    FutureProvider.autoDispose.family<List<InstructionAttachmentModel>, String>((ref, instructionId) {
  return ref.watch(instructionRepositoryProvider).fetchAttachments(instructionId);
});

/// Cached per storage path so re-opening the same attachment doesn't
/// re-request a signed URL every time.
final instructionAttachmentSignedUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, storagePath) {
  return ref.watch(instructionRepositoryProvider).getAttachmentSignedUrl(storagePath);
});
