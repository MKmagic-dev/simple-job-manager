class ProjectCompletionNoticeModel {
  const ProjectCompletionNoticeModel({
    required this.id,
    required this.projectId,
    required this.employeeId,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String employeeId;
  final DateTime createdAt;

  factory ProjectCompletionNoticeModel.fromJson(Map<String, dynamic> json) {
    return ProjectCompletionNoticeModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      employeeId: json['employee_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
