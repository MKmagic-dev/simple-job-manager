import 'package:flutter/material.dart' show TimeOfDay;

class ShiftModel {
  const ShiftModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    this.projectId,
    required this.workDate,
    required this.startTime,
    required this.endTime,
    this.notes,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String? projectId;
  final DateTime workDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? notes;

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      employeeId: json['employee_id'] as String,
      projectId: json['project_id'] as String?,
      workDate: DateTime.parse(json['work_date'] as String),
      startTime: _parseTime(json['start_time'] as String),
      endTime: _parseTime(json['end_time'] as String),
      notes: json['notes'] as String?,
    );
  }

  static TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
