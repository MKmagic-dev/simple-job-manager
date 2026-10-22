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
  });

  final String id;
  final String companyId;
  final String title;
  final String? notes;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  bool get hasTime => startTime != null;
  bool get isMultiDay => endDate.isAfter(startDate);

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
    );
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
