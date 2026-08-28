import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../employees/presentation/employee_list_screen.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../projects/presentation/project_list_screen.dart';
import '../../shifts/presentation/schedule_screen.dart';
import '../../work_photos/presentation/work_photo_list_screen.dart';

class BossHomeScreen extends ConsumerWidget {
  const BossHomeScreen({super.key, required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final title = '${l10n.bossPanelTitle} — ${profile.fullName}';
    // Safe: BossHomeScreen is only ever built for UserRole.boss, and only
    // UserRole.admin profiles have a null companyId.
    final companyId = profile.companyId!;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOutTooltip,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(l10n.employeesTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const EmployeeListScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.work_outline),
              title: Text(l10n.projectsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProjectListScreen(companyId: companyId),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(l10n.scheduleTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ScheduleScreen(companyId: companyId),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.instructionsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InstructionListScreen(
                      companyId: companyId,
                      isOwner: true,
                    ),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.photo_camera_back_outlined),
              title: Text(l10n.workPhotosTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => WorkPhotoListScreen(
                      companyId: companyId,
                      employeeId: profile.id,
                      isOwner: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
