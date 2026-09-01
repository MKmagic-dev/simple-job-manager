import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/profile_model.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _avatarBucket = 'avatars';

  Future<ProfileModel?> fetchCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  /// Editing your own name/phone is a plain self-update — the
  /// profiles_update_owner_or_self policy already allows it for any role,
  /// and the privilege-escalation trigger only blocks role/company_id
  /// changes, not these fields.
  Future<void> updateMyProfile({String? fullName, String? phone}) async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('profiles')
        .update({'full_name': ?fullName, 'phone': phone})
        .eq('id', userId);
  }

  /// Uploads a new avatar image and updates the caller's own profile row to
  /// point at it. Returns the public URL so the caller can show it right
  /// away without waiting for a re-fetch.
  Future<String> uploadMyAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final userId = _client.auth.currentUser!.id;
    // A fixed filename per user (not a timestamped one, unlike work photos)
    // so re-uploading just replaces the old avatar instead of accumulating
    // orphaned files in storage.
    final path = '$userId/avatar.$fileExtension';

    await _client.storage
        .from(_avatarBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage.from(_avatarBucket).getPublicUrl(path);
    // Cache-bust so the new photo shows immediately instead of a stale
    // cached copy at the same URL.
    final bustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    await _client
        .from('profiles')
        .update({'avatar_url': bustedUrl})
        .eq('id', userId);

    return bustedUrl;
  }

  /// Null for an admin (not tied to any company) or if the company was
  /// deleted out from under them.
  Future<String?> fetchMyCompanyName(String companyId) async {
    final data = await _client
        .from('companies')
        .select('name')
        .eq('id', companyId)
        .maybeSingle();
    return data?['name'] as String?;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's profile row, refetched whenever the auth state
/// changes (sign in / sign out).
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(profileRepositoryProvider).fetchCurrentProfile();
});

final myCompanyNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, companyId) {
      return ref.watch(profileRepositoryProvider).fetchMyCompanyName(companyId);
    });
