import 'dart:typed_data';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/shift_attachment_model.dart';
import '../domain/shift_model.dart';

class ShiftRepository {
  ShiftRepository(this._client);

  final SupabaseClient _client;

  static const _attachmentBucket = 'shift-attachments';

  /// RLS restricts this automatically: an owner sees every shift in their
  /// company (shifts_owner_all), an employee only sees their own
  /// (shifts_employee_select_own) — so this single method serves both the
  /// boss's full schedule screen and the worker's "my shifts" screen.
  Future<List<ShiftModel>> fetchShifts() async {
    final data = await _client
        .from('shifts')
        .select()
        .order('work_date', ascending: true)
        .order('start_time', ascending: true);

    return (data as List<dynamic>)
        .map((row) => ShiftModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the new shift's id so attachments can be uploaded against it
  /// right after.
  Future<String> createShift({
    required String companyId,
    required String employeeId,
    String? projectId,
    required DateTime workDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? notes,
  }) async {
    final row = await _client
        .from('shifts')
        .insert({
          'company_id': companyId,
          'employee_id': employeeId,
          'project_id': ?projectId,
          'work_date': _dateOnly(workDate),
          'start_time': _timeOnly(startTime),
          'end_time': _timeOnly(endTime),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'created_by': _client.auth.currentUser!.id,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Owner-only in practice: shifts_owner_all is the only RLS policy that
  /// permits an update, and it's scoped to the caller's own company.
  Future<void> updateShift({
    required String shiftId,
    required String employeeId,
    String? projectId,
    required DateTime workDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? notes,
  }) async {
    await _client
        .from('shifts')
        .update({
          'employee_id': employeeId,
          'project_id': projectId,
          'work_date': _dateOnly(workDate),
          'start_time': _timeOnly(startTime),
          'end_time': _timeOnly(endTime),
          'notes': notes != null && notes.isNotEmpty ? notes : null,
        })
        .eq('id', shiftId);
  }

  /// Owner-only in practice, same as [updateShift].
  Future<void> deleteShift(String shiftId) {
    return _client.from('shifts').delete().eq('id', shiftId);
  }

  /// RLS restricts this automatically: an owner sees every attachment on a
  /// shift in their company, an employee only on their own shift.
  Future<List<ShiftAttachmentModel>> fetchAttachments(String shiftId) async {
    final data = await _client
        .from('shift_attachments')
        .select()
        .eq('shift_id', shiftId)
        .order('created_at');

    return (data as List<dynamic>)
        .map(
          (row) => ShiftAttachmentModel.fromJson(row as Map<String, dynamic>),
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
    required String shiftId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    // Storage RLS requires the first path segment to be the company id and
    // the second the shift id (see
    // supabase/migrations/20260830110000_shift_attachments.sql).
    final path =
        '$companyId/$shiftId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from(_attachmentBucket).uploadBinary(path, bytes);

    await _client.from('shift_attachments').insert({
      'shift_id': shiftId,
      'storage_path': path,
      'uploaded_by': _client.auth.currentUser!.id,
    });
  }

  /// Owner-only in practice: shift_attachments_owner_all is the only RLS
  /// policy that permits a delete.
  Future<void> deleteAttachment(String id, String storagePath) async {
    await _client.storage.from(_attachmentBucket).remove([storagePath]);
    await _client.from('shift_attachments').delete().eq('id', id);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _timeOnly(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
}

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepository(ref.watch(supabaseClientProvider));
});

/// Call `ref.invalidate(shiftListProvider)` after adding a shift to refresh it.
final shiftListProvider = FutureProvider.autoDispose<List<ShiftModel>>((ref) {
  return ref.watch(shiftRepositoryProvider).fetchShifts();
});

final shiftAttachmentsProvider = FutureProvider.autoDispose
    .family<List<ShiftAttachmentModel>, String>((ref, shiftId) {
      return ref.watch(shiftRepositoryProvider).fetchAttachments(shiftId);
    });

/// Cached per storage path so re-opening the same attachment doesn't
/// re-request a signed URL every time.
final shiftAttachmentSignedUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, storagePath) {
      return ref
          .watch(shiftRepositoryProvider)
          .getAttachmentSignedUrl(storagePath);
    });
