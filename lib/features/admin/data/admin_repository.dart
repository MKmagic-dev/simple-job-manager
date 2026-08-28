import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../profile/domain/profile_model.dart';
import '../domain/company_model.dart';

/// Only usable by an admin — every method here relies on the
/// companies_admin_all / profiles_admin_all RLS policies (see
/// supabase/migrations/20260716100100_admin_role_step2_schema_and_policies.sql)
/// to see and touch every company, not just the caller's own.
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<List<CompanyModel>> fetchCompanies() async {
    final data = await _client.from('companies').select().order('name');
    return (data as List<dynamic>)
        .map((row) => CompanyModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProfileModel>> fetchCompanyMembers(String companyId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('company_id', companyId)
        .order('full_name');
    return (data as List<dynamic>)
        .map((row) => ProfileModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Deletes a company and, via ON DELETE CASCADE, everything tied to it
  /// (profiles, projects, shifts, instructions, photos). Note: this does
  /// NOT remove the deleted members' underlying login accounts (that needs
  /// the admin API from a trusted server context, not a plain RLS-scoped
  /// delete) — they're left as logins with no profile, harmless but not a
  /// fully clean deletion. Revisit with an Edge Function if that matters.
  Future<void> deleteCompany(String companyId) async {
    await _client.from('companies').delete().eq('id', companyId);
  }

  /// Removes a single member from a company without deleting the whole
  /// company. Same login-account caveat as [deleteCompany].
  Future<void> deleteProfile(String profileId) async {
    await _client.from('profiles').delete().eq('id', profileId);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

final companyListProvider = FutureProvider.autoDispose<List<CompanyModel>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchCompanies();
});

final companyMembersProvider =
    FutureProvider.autoDispose.family<List<ProfileModel>, String>((ref, companyId) {
  return ref.watch(adminRepositoryProvider).fetchCompanyMembers(companyId);
});
