/// One person on one project. Being on a project is what lets the boss give
/// them shifts/tasks in it, and what lets an employee see it. A [isManager]
/// member is also an administrator of that project (and only that project).
class ProjectMemberModel {
  const ProjectMemberModel({
    required this.projectId,
    required this.employeeId,
    this.isManager = false,
  });

  final String projectId;
  final String employeeId;
  final bool isManager;

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      projectId: json['project_id'] as String,
      employeeId: json['employee_id'] as String,
      isManager: json['role'] == 'manager',
    );
  }
}
