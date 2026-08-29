import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../employees/data/employee_repository.dart';
import '../../employees/presentation/employee_list_screen.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/presentation/my_account_screen.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/presentation/project_list_screen.dart';
import '../../shifts/data/shift_change_request_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../shifts/presentation/schedule_screen.dart';
import '../../shifts/presentation/team_requests_screen.dart';
import '../../work_photos/data/work_photo_repository.dart';
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
    final unreadRequests = ref.watch(unreadRequestsCountProvider);
    final unreadPhotos = ref.watch(unreadWorkPhotosCountProvider);
    final employees = ref.watch(employeeListProvider).valueOrNull ?? const [];
    final people = [
      for (final employee in employees)
        CalendarPerson(
          id: employee.id,
          name: employee.fullName,
          avatarUrl: employee.avatarUrl,
        ),
    ];
    final projects = ref.watch(projectListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: l10n.myAccountTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MyAccountScreen(profile: profile),
                ),
              );
            },
          ),
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
              title: Text(l10n.teamTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EmployeeListScreen(),
                  ),
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
                    builder: (context) =>
                        ProjectListScreen(companyId: companyId),
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
              leading: Badge(
                label: Text('$unreadPhotos'),
                isLabelVisible: unreadPhotos > 0,
                child: const Icon(Icons.photo_camera_back_outlined),
              ),
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
          Card(
            child: ListTile(
              leading: Badge(
                label: Text('$unreadRequests'),
                isLabelVisible: unreadRequests > 0,
                child: const Icon(Icons.forum_outlined),
              ),
              title: Text(l10n.changeRequestsSectionLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        TeamRequestsScreen(people: people, projects: projects),
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
