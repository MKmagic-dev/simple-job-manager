import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/instruction_model.dart';

class InstructionRepository {
  InstructionRepository(this._client);

  final SupabaseClient _client;

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
  Future<void> createInstruction({
    required String companyId,
    required String employeeId,
    required String title,
    String? content,
  }) async {
    await _client.from('instructions').insert({
      'company_id': companyId,
      'employee_id': employeeId,
      'title': title,
      if (content != null && content.isNotEmpty) 'content': content,
      'created_by': _client.auth.currentUser!.id,
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
