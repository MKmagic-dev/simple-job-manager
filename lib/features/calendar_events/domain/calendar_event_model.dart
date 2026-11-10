import 'package:flutter/material.dart' show TimeOfDay;

/// A personal calendar entry / reminder, not tied to any project: a title, an
/// optional note, a date range, and either a time of day or "all day".
class CalendarEventModel {
  const CalendarEventModel({
    required this.id,
    required this.companyId,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.notes,
    this.startTime,
    this.endTime,
    this.remindSameDay = false,
    this.remindDayBefore = false,
  });

  final String id;
  final String companyId;
  final String title;
  final String? notes;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  /// Remind on the day the event starts.
  final bool remindSameDay;

  /// Remind on the day before the event starts. Both can be on at once.
  final bool remindDayBefore;

  bool get hasTime => startTime != null;
  bool get isMultiDay => endDate.isAfter(startDate);

  /// The days this event reminds on (none, one or two).
  List<DateTime> get reminderDays {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    return [
      if (remindDayBefore) DateTime(s.year, s.month, s.day - 1),
      if (remindSameDay) s,
    ];
  }

  /// Whether the event touches [day] (date only, time ignored).
  bool isOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      startTime: _parseTime(json['start_time'] as String?),
      endTime: _parseTime(json['end_time'] as String?),
      remindSameDay: json['remind_same_day'] as bool? ?? false,
      remindDayBefore: json['remind_day_before'] as bool? ?? false,
    );
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

/// One reminder that is due: the event and the day it shows on.
class ReminderDue {
  const ReminderDue(this.event, this.day);

  final CalendarEventModel event;
  final DateTime day;

  /// Identifies this reminder for the "closed" set (see [reminderKey]).
  String get key => reminderKey(event.id, day);
}

/// Identifies one reminder occurrence: the event and the day it is shown on.
String reminderKey(String eventId, DateTime day) =>
    '$eventId|${day.year}-${day.month}-${day.day}';

/// The reminders to show on [day]: each event reminder that falls on that day
/// and that the user has not closed yet.
List<ReminderDue> remindersOn(
  DateTime day,
  Iterable<CalendarEventModel> events,
  Set<String> acknowledged,
) {
  final d = DateTime(day.year, day.month, day.day);
  return [
    for (final event in events)
      if (event.reminderDays.contains(d) &&
          !acknowledged.contains(reminderKey(event.id, d)))
        ReminderDue(event, d),
  ];
}
