/// An employee telling the boss "this task is done" — the boss then archives
/// the task (which clears the notice).
class TaskCompletionNoticeModel {
  const TaskCompletionNoticeModel({
    required this.id,
    required this.taskId,
    required this.employeeId,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String employeeId;
  final DateTime createdAt;

  factory TaskCompletionNoticeModel.fromJson(Map<String, dynamic> json) {
    return TaskCompletionNoticeModel(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      employeeId: json['employee_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
