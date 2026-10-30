/// A note the boss keeps, optionally shared with chosen employees.
class NoteModel {
  const NoteModel({
    required this.id,
    required this.companyId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.content,
  });

  final String id;
  final String companyId;
  final String title;
  final String? content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// One employee a note is shared with.
class NoteRecipientModel {
  const NoteRecipientModel({required this.noteId, required this.employeeId});

  final String noteId;
  final String employeeId;

  factory NoteRecipientModel.fromJson(Map<String, dynamic> json) {
    return NoteRecipientModel(
      noteId: json['note_id'] as String,
      employeeId: json['employee_id'] as String,
    );
  }
}
