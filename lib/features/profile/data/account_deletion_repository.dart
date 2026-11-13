import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// Deleting a whole company: the owner gets a one-time code by e-mail, types it
/// in, and only then the company and every login in it are removed.
class AccountDeletionRepository {
  AccountDeletionRepository(this._client);

  final SupabaseClient _client;

  String? get _email => _client.auth.currentUser?.email;

  /// Sends a 6-digit code to the owner's e-mail. Never creates an account.
  Future<void> sendCode() async {
    final email = _email;
    if (email == null) throw Exception('This account has no e-mail address.');
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  /// Checks the code that was e-mailed.
  Future<void> confirmCode(String code) async {
    final email = _email;
    if (email == null) throw Exception('This account has no e-mail address.');
    await _client.auth.verifyOTP(
      type: OtpType.email,
      token: code,
      email: email,
    );
  }

  /// Deletes the company and its logins on the server, then signs out here.
  /// Call only after [confirmCode] succeeded.
  Future<void> deleteCompany() async {
    try {
      await _client.functions.invoke('delete-company');
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw Exception(message ?? 'Could not delete the company.');
    }
    await _client.auth.signOut();
  }
}

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((
  ref,
) {
  return AccountDeletionRepository(ref.watch(supabaseClientProvider));
});
