import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/presentation/my_account_screen.dart';
import '../../projects/data/project_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/schedule_calendar.dart';
import '../../work_photos/presentation/work_photo_list_screen.dart';

class WorkerHomeScreen extends ConsumerStatefulWidget {
  const WorkerHomeScreen({super.key, required this.profile});

  final ProfileModel profile;

  @override
  ConsumerState<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends ConsumerState<WorkerHomeScreen> {
  // null = no filter, show every shift of mine.
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final l10n = AppLocalizations.of(context)!;
    final title = '${l10n.workerScheduleTitle} — ${profile.fullName}';
    // Safe: WorkerHomeScreen is only ever built for UserRole.worker, and
    // only UserRole.admin profiles have a null companyId.
    final companyId = profile.companyId!;
    final shiftsAsync = ref.watch(shiftListProvider);
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: l10n.instructionsTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InstructionListScreen(
                    companyId: companyId,
                    isOwner: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.photo_camera_back_outlined),
            tooltip: l10n.workPhotosTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WorkPhotoListScreen(
                    companyId: companyId,
                    employeeId: profile.id,
                    isOwner: false,
                  ),
                ),
              );
            },
          ),
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
      // Note: RLS already restricts these results to this employee's own
      // shifts (shifts_employee_select_own) and, for projects, to only the
      // ones they actually have a shift on (projects_employee_select) —
      // so the dropdown below only ever lists projects they're assigned to.
      body: shiftsAsync.when(
        data: (shifts) {
          if (shifts.isEmpty) {
            return Center(child: Text(l10n.noShiftsYet));
          }

          final projects = projectsAsync.valueOrNull ?? const [];
          final filteredShifts = _selectedProjectId == null
              ? shifts
              : shifts
                    .where((shift) => shift.projectId == _selectedProjectId)
                    .toList();
          final filteredProjects = _selectedProjectId == null
              ? projects
              : projects
                    .where((project) => project.id == _selectedProjectId)
                    .toList();

          return Column(
            children: [
              if (projects.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<String?>(
                      value: _selectedProjectId,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.allMyShiftsOption),
                        ),
                        for (final project in projects)
                          DropdownMenuItem(
                            value: project.id,
                            child: Text(project.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedProjectId = value),
                    ),
                  ),
                ),
              Expanded(
                child: filteredShifts.isEmpty
                    ? Center(child: Text(l10n.noShiftsYet))
                    : ScheduleCalendar(
                        shifts: filteredShifts,
                        projects: filteredProjects,
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}
