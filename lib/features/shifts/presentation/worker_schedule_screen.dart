import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../calendar_events/data/calendar_event_repository.dart';
import '../../calendar_events/presentation/event_form_screen.dart';
import '../../home/data/my_work_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../projects/data/project_repository.dart';
import 'calendar_shared.dart';
import 'schedule_calendar.dart';

/// The employee's own calendar (week by default, plus day/month/year), with an
/// optional filter to one project.
///
/// RLS already restricts these results to this employee's own shifts
/// (shifts_employee_select_own) and to the projects they have a shift on
/// (projects_employee_select), so the filter only ever lists their projects.
class WorkerScheduleScreen extends ConsumerStatefulWidget {
  const WorkerScheduleScreen({super.key});

  @override
  ConsumerState<WorkerScheduleScreen> createState() =>
      _WorkerScheduleScreenState();
}

class _WorkerScheduleScreenState extends ConsumerState<WorkerScheduleScreen> {
  // null = no filter, show every shift of mine.
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shiftsAsync = ref.watch(myShiftsProvider);
    final projects = ref.watch(projectListProvider).valueOrNull ?? const [];
    final events = ref.watch(calendarEventListProvider).valueOrNull ?? const [];
    final companyId = ref.watch(currentProfileProvider).valueOrNull?.companyId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.workerScheduleTitle)),
      floatingActionButton: companyId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openEventForm(context, companyId: companyId),
              icon: const Icon(Icons.add),
              label: Text(l10n.addEventButton),
            ),
      body: shiftsAsync.when(
        data: (shifts) {
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
              if (projects.length > 1)
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(l10n.allMyShiftsOption),
                          selected: _selectedProjectId == null,
                          onSelected: (_) =>
                              setState(() => _selectedProjectId = null),
                        ),
                      ),
                      for (final project in projects)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: CircleAvatar(
                              radius: 5,
                              backgroundColor: colorForProject(project),
                            ),
                            label: Text(project.name),
                            selected: _selectedProjectId == project.id,
                            onSelected: (_) =>
                                setState(() => _selectedProjectId = project.id),
                          ),
                        ),
                    ],
                  ),
                ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Expanded(
                child: ScheduleCalendar(
                  shifts: filteredShifts,
                  projects: filteredProjects,
                  events: events,
                  onAddEvent: companyId == null
                      ? null
                      : (day) => openEventForm(
                          context,
                          companyId: companyId,
                          initialDate: day,
                        ),
                  onEventTap: companyId == null
                      ? null
                      : (event) => openEventForm(
                          context,
                          companyId: companyId,
                          existing: event,
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(friendlyError(context, error))),
      ),
    );
  }
}
