/// The three roles supported by the app. Maps to the `role` column on the
/// `profiles` table, a Postgres enum (`user_role`) with values
/// `owner` / `employee` / `admin` — confirmed against the live schema.
///
/// `admin` isn't tied to any single company (see [ProfileModel.companyId])
/// and can manage every company in this shared database — see
/// project memory / the admin migration for why the app moved from
/// one-Supabase-project-per-client to a single shared multi-tenant database.
enum UserRole { boss, worker, admin }

UserRole _roleFromString(String raw) {
  switch (raw) {
    case 'owner':
      return UserRole.boss;
    case 'employee':
      return UserRole.worker;
    case 'admin':
      return UserRole.admin;
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

  /// Null only for [UserRole.admin] — every boss/worker profile always
  /// belongs to exactly one company.
  final String? companyId;
  final UserRole role;
  final String fullName;
  final String? phone;
  final String? avatarUrl;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String?,
      role: _roleFromString(json['role'] as String),
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
