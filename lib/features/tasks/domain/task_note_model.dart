/// A note an employee wrote to the boss about one task.
class TaskNoteModel {
  const TaskNoteModel({
    required this.id,
    required this.taskId,
    required this.companyId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String taskId;
  final String companyId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  /// When the boss read it; null while it is still unread.
  final DateTime? readAt;

  factory TaskNoteModel.fromJson(Map<String, dynamic> json) {
    return TaskNoteModel(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      companyId: json['company_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
    );
  }
}
