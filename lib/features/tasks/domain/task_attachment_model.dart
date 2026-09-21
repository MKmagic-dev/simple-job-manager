class TaskAttachmentModel {
  const TaskAttachmentModel({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.uploadedBy,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String storagePath;
  final String? uploadedBy;
  final DateTime createdAt;

  /// The original filename, recovered from the storage path (everything
  /// after the last `/`, with the leading upload timestamp stripped).
  String get fileName {
    final lastSegment = storagePath.split('/').last;
    final underscoreIndex = lastSegment.indexOf('_');
    return underscoreIndex == -1
        ? lastSegment
        : lastSegment.substring(underscoreIndex + 1);
  }

  bool get isImage {
    final ext = fileName.split('.').last.toLowerCase();
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
  }

  factory TaskAttachmentModel.fromJson(Map<String, dynamic> json) {
    return TaskAttachmentModel(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      storagePath: json['storage_path'] as String,
      uploadedBy: json['uploaded_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
