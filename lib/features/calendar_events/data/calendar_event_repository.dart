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
    String reminder = 'none',
  }) async {
    await _client.from('calendar_events').insert({
      'company_id': companyId,
      'created_by': _client.auth.currentUser!.id,
      ..._fields(
        title,
        notes,
        startDate,
        endDate,
        startTime,
        endTime,
        reminder,
      ),
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
    String reminder = 'none',
  }) async {
    await _client
        .from('calendar_events')
        .update(
          _fields(
            title,
            notes,
            startDate,
            endDate,
            startTime,
            endTime,
            reminder,
          ),
        )
        .eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) {
    return _client.from('calendar_events').delete().eq('id', eventId);
  }

  /// The reminders the signed-in user has already closed, as keys (see
  /// [reminderKey]).
  Future<Set<String>> fetchAcknowledged() async {
    final data = await _client
        .from('calendar_event_acks')
        .select('event_id, reminder_date');
    return {
      for (final row in data as List<dynamic>)
        reminderKey(
          (row as Map<String, dynamic>)['event_id'] as String,
          DateTime.parse(row['reminder_date'] as String),
        ),
    };
  }

  /// Marks these reminders as closed, so they stop showing up.
  Future<void> acknowledge(Iterable<CalendarEventModel> reminders) async {
    final rows = [
      for (final event in reminders)
        if (event.reminderDate != null)
          {
            'event_id': event.id,
            'user_id': _client.auth.currentUser!.id,
            'reminder_date': _dateOnly(event.reminderDate!),
          },
    ];
    if (rows.isEmpty) return;
    await _client
        .from('calendar_event_acks')
        .upsert(rows, onConflict: 'event_id,user_id,reminder_date');
  }

  Map<String, dynamic> _fields(
    String title,
    String? notes,
    DateTime startDate,
    DateTime endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String reminder,
  ) {
    final timed = startTime != null && endTime != null;
    return {
      'title': title,
      'notes': notes != null && notes.isNotEmpty ? notes : null,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'start_time': timed ? _timeOnly(startTime) : null,
      'end_time': timed ? _timeOnly(endTime) : null,
      'reminder': reminder,
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

/// The reminders the user has closed. Call
/// `ref.invalidate(reminderAcksProvider)` after acknowledging some.
final reminderAcksProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(calendarEventRepositoryProvider).fetchAcknowledged();
});
