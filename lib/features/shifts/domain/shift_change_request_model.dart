class ShiftChangeRequestModel {
  const ShiftChangeRequestModel({
    required this.id,
    required this.shiftId,
    required this.employeeId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String shiftId;
  final String employeeId;
  final String message;
  final DateTime createdAt;

  factory ShiftChangeRequestModel.fromJson(Map<String, dynamic> json) {
    return ShiftChangeRequestModel(
      id: json['id'] as String,
      shiftId: json['shift_id'] as String,
      employeeId: json['employee_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
