class WorkPhotoModel {
  const WorkPhotoModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    this.shiftId,
    required this.storagePath,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String? shiftId;
  final String storagePath;
  final String? caption;
  final DateTime createdAt;

  factory WorkPhotoModel.fromJson(Map<String, dynamic> json) {
    return WorkPhotoModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      employeeId: json['employee_id'] as String,
      shiftId: json['shift_id'] as String?,
      storagePath: json['storage_path'] as String,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
