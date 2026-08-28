class InstructionAttachmentModel {
  const InstructionAttachmentModel({
    required this.id,
    required this.instructionId,
    required this.storagePath,
    required this.createdAt,
  });

  final String id;
  final String instructionId;
  final String storagePath;
  final DateTime createdAt;

  /// The original filename, recovered from the storage path (everything
  /// after the last `/`, with the leading upload timestamp stripped).
  String get fileName {
    final lastSegment = storagePath.split('/').last;
    final underscoreIndex = lastSegment.indexOf('_');
    return underscoreIndex == -1 ? lastSegment : lastSegment.substring(underscoreIndex + 1);
  }

  factory InstructionAttachmentModel.fromJson(Map<String, dynamic> json) {
    return InstructionAttachmentModel(
      id: json['id'] as String,
      instructionId: json['instruction_id'] as String,
      storagePath: json['storage_path'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
