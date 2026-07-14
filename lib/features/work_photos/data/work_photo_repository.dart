import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/work_photo_model.dart';

class WorkPhotoRepository {
  WorkPhotoRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'work-photos';

  /// RLS restricts this automatically: an owner sees every work photo row in
  /// their company (work_photos_owner_select), an employee only sees their
  /// own (work_photos_employee_select_own) — same shared pattern as shifts
  /// and instructions. Note this only returns *metadata rows*; the actual
  /// image file needs a signed URL (see [getSignedUrl]) since the storage
  /// bucket is private.
  Future<List<WorkPhotoModel>> fetchWorkPhotos() async {
    final data = await _client.from('work_photos').select().order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((row) => WorkPhotoModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// The bucket is private, so every display of a photo needs a fresh,
  /// time-limited signed URL rather than a plain public link.
  Future<String> getSignedUrl(String storagePath) {
    return _client.storage.from(_bucket).createSignedUrl(storagePath, 3600);
  }

  Future<void> uploadWorkPhoto({
    required String companyId,
    required String employeeId,
    String? shiftId,
    String? caption,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    // Storage RLS requires the first path segment to be the uploader's own
    // user id (see supabase/migrations/20260714090000_work_photos_storage.sql).
    final path = '$employeeId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _client.storage.from(_bucket).uploadBinary(path, bytes);

    await _client.from('work_photos').insert({
      'company_id': companyId,
      'employee_id': employeeId,
      'shift_id': ?shiftId,
      'storage_path': path,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });
  }
}

final workPhotoRepositoryProvider = Provider<WorkPhotoRepository>((ref) {
  return WorkPhotoRepository(ref.watch(supabaseClientProvider));
});

/// Call `ref.invalidate(workPhotoListProvider)` after uploading a photo to
/// refresh it.
final workPhotoListProvider = FutureProvider.autoDispose<List<WorkPhotoModel>>((ref) {
  return ref.watch(workPhotoRepositoryProvider).fetchWorkPhotos();
});

/// Cached per storage path so scrolling a photo list doesn't re-request a
/// signed URL for every rebuild.
final workPhotoSignedUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, storagePath) {
  return ref.watch(workPhotoRepositoryProvider).getSignedUrl(storagePath);
});
