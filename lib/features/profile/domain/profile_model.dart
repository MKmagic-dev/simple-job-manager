/// The two roles supported by the app. Maps to the `role` column on the
/// `profiles` table, which is a Postgres enum (`user_role`) with exactly
/// these two values — confirmed against the live schema on 2026-07-13.
enum UserRole { boss, worker }

UserRole _roleFromString(String raw) {
  switch (raw) {
    case 'owner':
      return UserRole.boss;
    case 'employee':
      return UserRole.worker;
    default:
      throw ArgumentError.value(raw, 'raw', 'Unknown profiles.role value');
  }
}

class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.companyId,
    required this.role,
    required this.fullName,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String companyId;
  final UserRole role;
  final String fullName;
  final String? phone;
  final String? avatarUrl;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      role: _roleFromString(json['role'] as String),
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
