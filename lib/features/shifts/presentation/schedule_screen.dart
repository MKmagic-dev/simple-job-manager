import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_model.dart';
import '../data/shift_repository.dart';
import 'add_shift_screen.dart';
import 'calendar_shared.dart';
import 'schedule_calendar.dart';

/// Pass [project] to show only that project's shifts (and only its own bar
/// on the calendar) instead of the whole company's schedule.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key, required this.companyId, this.project});

  final String companyId;
  final ProjectModel? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shiftsAsync = ref.watch(shiftListProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(project?.name ?? l10n.scheduleTitle)),
      body: shiftsAsync.when(
        data: (allShifts) {
          final shifts = project == null
              ? allShifts
              : allShifts
                    .where((shift) => shift.projectId == project!.id)
                    .toList();

          if (shifts.isEmpty) {
            return Center(child: Text(l10n.noShiftsScheduledYet));
          }

          // Scoped to a single project: only show people actually assigned
          // to it on the calendar (via a shift), not the whole roster.
          final assignedEmployeeIds = project == null
              ? null
              : {for (final shift in shifts) shift.employeeId};
          final people = [
            for (final employee in employeesAsync.valueOrNull ?? const [])
              if (assignedEmployeeIds == null ||
                  assignedEmployeeIds.contains(employee.id))
                CalendarPerson(
                  id: employee.id,
                  name: employee.fullName,
                  avatarUrl: employee.avatarUrl,
                ),
          ];

          return ScheduleCalendar(
            shifts: shifts,
            projects: project != null
                ? [project!]
                : (projectsAsync.valueOrNull ?? []),
            people: people,
            isOwner: true,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addShiftTooltip,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddShiftScreen(
                companyId: companyId,
                preselectedProjectId: project?.id,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
