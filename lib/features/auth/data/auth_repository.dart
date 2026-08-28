import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Self-registration: creates a brand new company and its first owner
  /// account. Calls the public `register-company` Edge Function (see
  /// supabase/functions/register-company/index.ts for why creating a login
  /// can't happen directly from the app). Doesn't sign the new owner in —
  /// they sign in normally afterwards with the credentials they just chose.
  Future<void> registerCompany({
    required String companyName,
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      await _client.functions.invoke(
        'register-company',
        body: {
          'company_name': companyName,
          'owner_email': email,
          'owner_password': password,
          'owner_full_name': fullName,
        },
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw Exception(message ?? 'Could not register company.');
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
