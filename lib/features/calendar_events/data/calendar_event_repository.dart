import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/calendar_event_model.dart';

class CalendarEventRepository {
  CalendarEventRepository(this._client);

  final SupabaseClient _client;

  /// RLS restricts this to the caller's own events.
  Future<List<CalendarEventModel>> fetchEvents() async {
    final data = await _client
        .from('calendar_events')
        .select()
        .order('start_date')
        .order('start_time', ascending: true, nullsFirst: true);
    return (data as List<dynamic>)
        .map((row) => CalendarEventModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> createEvent({
    required String companyId,
    required String title,
    String? notes,
    required DateTime startDate,
    required DateTime endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    await _client.from('calendar_events').insert({
      'company_id': companyId,
      'created_by': _client.auth.currentUser!.id,
      ..._fields(title, notes, startDate, endDate, startTime, endTime),
    });
  }

  Future<void> updateEvent({
    required String eventId,
    required String title,
    String? notes,
    required DateTime startDate,
    required DateTime endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    await _client
        .from('calendar_events')
        .update(_fields(title, notes, startDate, endDate, startTime, endTime))
        .eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) {
    return _client.from('calendar_events').delete().eq('id', eventId);
  }

  Map<String, dynamic> _fields(
    String title,
    String? notes,
    DateTime startDate,
    DateTime endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  ) {
    final timed = startTime != null && endTime != null;
    return {
      'title': title,
      'notes': notes != null && notes.isNotEmpty ? notes : null,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'start_time': timed ? _timeOnly(startTime) : null,
      'end_time': timed ? _timeOnly(endTime) : null,
    };
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _timeOnly(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
}

final calendarEventRepositoryProvider = Provider<CalendarEventRepository>((
  ref,
) {
  return CalendarEventRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's own events. Call
/// `ref.invalidate(calendarEventListProvider)` after adding/editing/deleting.
final calendarEventListProvider =
    FutureProvider.autoDispose<List<CalendarEventModel>>((ref) {
      return ref.watch(calendarEventRepositoryProvider).fetchEvents();
    });
