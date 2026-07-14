class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.address,
    this.description,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String companyId;
  final String name;
  final String? address;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      description: json['description'] as String?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
    );
  }
}
