class ShiftAttachmentModel {
  const ShiftAttachmentModel({
    required this.id,
    required this.shiftId,
    required this.storagePath,
    required this.uploadedBy,
    required this.createdAt,
  });

  final String id;
  final String shiftId;
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

  factory ShiftAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ShiftAttachmentModel(
      id: json['id'] as String,
      shiftId: json['shift_id'] as String,
      storagePath: json['storage_path'] as String,
      uploadedBy: json['uploaded_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
