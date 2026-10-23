/// One person assigned to one task (chosen in the task form).
class TaskAssignmentModel {
  const TaskAssignmentModel({required this.taskId, required this.employeeId});

  final String taskId;
  final String employeeId;

  factory TaskAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TaskAssignmentModel(
      taskId: json['task_id'] as String,
      employeeId: json['employee_id'] as String,
    );
  }
}
