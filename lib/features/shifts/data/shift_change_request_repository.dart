import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/unread/last_seen_controller.dart';
import '../domain/shift_change_request_model.dart';

class ShiftChangeRequestRepository {
  ShiftChangeRequestRepository(this._client);

  final SupabaseClient _client;

  /// RLS restricts this automatically: an owner sees every request in
  /// their company (shift_change_requests_owner_all), an employee only
  /// sees their own (shift_change_requests_employee_select) — same shared
  /// pattern as shifts/instructions.
  Future<List<ShiftChangeRequestModel>> fetchChangeRequests() async {
    final data = await _client
        .from('shift_change_requests')
        .select()
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map(
          (row) =>
              ShiftChangeRequestModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> submitChangeRequest({
    required String shiftId,
    required String message,
  }) async {
    await _client.from('shift_change_requests').insert({
      'shift_id': shiftId,
      'employee_id': _client.auth.currentUser!.id,
      'message': message,
    });
  }

  /// Owner action once they've fixed the shift — there's no "resolved"
  /// flag, dismissing just removes the note.
  Future<void> dismissChangeRequest(String id) {
    return _client.from('shift_change_requests').delete().eq('id', id);
  }
}

final shiftChangeRequestRepositoryProvider =
    Provider<ShiftChangeRequestRepository>((ref) {
      return ShiftChangeRequestRepository(ref.watch(supabaseClientProvider));
    });

/// Call `ref.invalidate(shiftChangeRequestListProvider)` after submitting
/// or dismissing a request to refresh it.
final shiftChangeRequestListProvider =
    FutureProvider.autoDispose<List<ShiftChangeRequestModel>>((ref) {
      return ref
          .watch(shiftChangeRequestRepositoryProvider)
          .fetchChangeRequests();
    });

/// How many requests arrived since the boss last opened the requests
/// screen on this device — drives the badge on its home-screen tile.
final unreadRequestsCountProvider = Provider.autoDispose<int>((ref) {
  final requests =
      ref.watch(shiftChangeRequestListProvider).valueOrNull ?? const [];
  final lastSeen = ref.watch(lastSeenRequestsProvider);
  if (lastSeen == null) return requests.length;
  return requests.where((r) => r.createdAt.isAfter(lastSeen)).length;
});
