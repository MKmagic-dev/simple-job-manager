import 'package:flutter/material.dart' show TimeOfDay;

import '../../../core/utils/date_math.dart';
import '../../shifts/domain/shift_model.dart';
import 'task_assignment_model.dart';

/// A piece of work inside a project (e.g. "wylewanie fundamentów"): a date
/// range with optional working hours.
///
/// Who's on a task isn't stored on the task — an employee is put on it by
/// getting a shift with this task chosen (see [ShiftModel.taskId]); use
/// [assigneeIdsFrom] to list them.
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
    required this.createdAt,
    this.archivedAt,
    this.color,
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
  final DateTime createdAt;

  /// When the task was archived, or null while it's active.
  final DateTime? archivedAt;

  /// Hex string like `#1E88E5`, or null for the automatic color (see
  /// `colorForTask`).
  final String? color;

  bool get isArchived => archivedAt != null;

  bool get hasHours => startTime != null && endTime != null;

  int get dayCount => daysBetween(startDate, endDate) + 1;

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

  /// The employees on this task: those chosen as its assignees plus anyone
  /// who has a shift with this task.
  Set<String> assigneeIdsFrom(
    Iterable<ShiftModel> shifts, [
    Iterable<TaskAssignmentModel> assignments = const [],
  ]) => {
    for (final assignment in assignments)
      if (assignment.taskId == id) assignment.employeeId,
    for (final shift in shifts)
      if (shift.taskId == id) shift.employeeId,
  };

  factory ProjectTaskModel.fromJson(Map<String, dynamic> json) {
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
      createdAt: DateTime.parse(json['created_at'] as String),
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      color: json['color'] as String?,
    );
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

enum TaskPhase { upcoming, active, done }
