import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../profile/domain/profile_model.dart';

class EmployeeRepository {
  EmployeeRepository(this._client);

  final SupabaseClient _client;

  /// RLS already restricts this to the caller's own company (see
  /// profiles_select policy), so no explicit company_id filter is needed
  /// here — the database enforces it either way.
  Future<List<ProfileModel>> fetchEmployees() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('role', 'employee')
        .order('full_name');

    return (data as List<dynamic>)
        .map((row) => ProfileModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Calls the `create-employee` Edge Function, which does the privileged
  /// work of creating the employee's login (see
  /// supabase/functions/create-employee/index.ts for why that can't happen
  /// directly from the app).
  Future<void> createEmployee({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      await _client.functions.invoke(
        'create-employee',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw Exception(message ?? 'Could not create employee.');
    }
  }
}

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(supabaseClientProvider));
});

/// The current company's employee list. Call `ref.invalidate(employeeListProvider)`
/// after adding an employee to refresh it.
final employeeListProvider = FutureProvider.autoDispose<List<ProfileModel>>((ref) {
  return ref.watch(employeeRepositoryProvider).fetchEmployees();
});
