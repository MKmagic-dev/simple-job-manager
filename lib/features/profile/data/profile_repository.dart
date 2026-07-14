import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/profile_model.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

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
