class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.address,
    this.description,
    this.startDate,
    this.endDate,
    this.color,
  });

  final String id;
  final String companyId;
  final String name;
  final String? address;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Hex string like `#1E88E5`, or null for the automatic color derived
  /// from [id] (see `colorForProject` in calendar_shared.dart).
  final String? color;

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      description: json['description'] as String?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      color: json['color'] as String?,
    );
  }
}
