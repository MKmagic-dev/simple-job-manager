class InstructionModel {
  const InstructionModel({
    required this.id,
    required this.companyId,
    this.employeeId,
    this.projectId,
    this.shiftId,
    required this.title,
    this.content,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String? employeeId;
  final String? projectId;
  final String? shiftId;
  final String title;
  final String? content;
  final DateTime createdAt;

  factory InstructionModel.fromJson(Map<String, dynamic> json) {
    return InstructionModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      employeeId: json['employee_id'] as String?,
      projectId: json['project_id'] as String?,
      shiftId: json['shift_id'] as String?,
      title: json['title'] as String,
      content: json['content'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
