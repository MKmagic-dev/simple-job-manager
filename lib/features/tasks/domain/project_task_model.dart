import 'package:flutter/material.dart' show TimeOfDay;

/// A piece of work inside a project (e.g. "wylewanie fundamentów"): a date
/// range with optional working hours, and the employees assigned to it.
class ProjectTaskModel {
  const ProjectTaskModel({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    required this.assigneeIds,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<String> assigneeIds;
  final DateTime createdAt;

  bool get hasHours => startTime != null && endTime != null;

  int get dayCount => endDate.difference(startDate).inDays + 1;

  bool isActiveOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  /// Where this task stands relative to [today], purely from its dates.
  TaskPhase phaseOn(DateTime today) {
    final d = DateTime(today.year, today.month, today.day);
    if (d.isBefore(startDate)) return TaskPhase.upcoming;
    if (d.isAfter(endDate)) return TaskPhase.done;
    return TaskPhase.active;
  }

  factory ProjectTaskModel.fromJson(Map<String, dynamic> json) {
    final assignees = (json['task_assignees'] as List<dynamic>? ?? const [])
        .map((row) => (row as Map<String, dynamic>)['employee_id'] as String)
        .toList();

    return ProjectTaskModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      startTime: _parseTime(json['start_time'] as String?),
      endTime: _parseTime(json['end_time'] as String?),
      assigneeIds: assignees,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

enum TaskPhase { upcoming, active, done }
