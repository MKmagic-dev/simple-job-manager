import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/shift_model.dart';

class ShiftRepository {
  ShiftRepository(this._client);

  final SupabaseClient _client;

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

  Future<void> createShift({
    required String companyId,
    required String employeeId,
    String? projectId,
    required DateTime workDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? notes,
  }) async {
    await _client.from('shifts').insert({
      'company_id': companyId,
      'employee_id': employeeId,
      'project_id': ?projectId,
      'work_date': _dateOnly(workDate),
      'start_time': _timeOnly(startTime),
      'end_time': _timeOnly(endTime),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'created_by': _client.auth.currentUser!.id,
    });
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
