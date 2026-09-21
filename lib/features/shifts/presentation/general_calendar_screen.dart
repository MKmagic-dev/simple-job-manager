import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../projects/data/project_repository.dart';
import '../data/shift_repository.dart';
import 'add_shift_screen.dart';
import 'calendar_shared.dart';
import 'schedule_calendar.dart';

/// The boss's whole-company calendar. A row of project chips above it lets
/// them pick which projects are shown (all on by default; tap to hide or
/// show one). Only shifts appear here — tasks live inside their project.
class GeneralCalendarScreen extends ConsumerStatefulWidget {
  const GeneralCalendarScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<GeneralCalendarScreen> createState() =>
      _GeneralCalendarScreenState();
}

class _GeneralCalendarScreenState extends ConsumerState<GeneralCalendarScreen> {
  final _hiddenProjectIds = <String>{};
  bool _hideNoProject = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projects = ref.watch(projectListProvider).valueOrNull ?? const [];
    final allShifts = ref.watch(shiftListProvider).valueOrNull ?? const [];
    final employees = ref.watch(employeeListProvider).valueOrNull ?? const [];
    final shiftsLoading = ref.watch(shiftListProvider).isLoading;

    final hasShiftsWithoutProject = allShifts.any((s) => s.projectId == null);
    final visibleProjects = projects
        .where((p) => !_hiddenProjectIds.contains(p.id))
        .toList();
    final shifts = allShifts
        .where(
          (s) => s.projectId == null
              ? !_hideNoProject
              : !_hiddenProjectIds.contains(s.projectId),
        )
        .toList();
    final people = [
      for (final employee in employees)
        CalendarPerson(
          id: employee.id,
          name: employee.fullName,
          avatarUrl: employee.avatarUrl,
        ),
    ];
    final allVisible = _hiddenProjectIds.isEmpty && !_hideNoProject;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(l10n.allProjectsOption),
                    selected: allVisible,
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      if (allVisible) {
                        _hiddenProjectIds.addAll(projects.map((p) => p.id));
                        _hideNoProject = true;
                      } else {
                        _hiddenProjectIds.clear();
                        _hideNoProject = false;
                      }
                    }),
                  ),
                ),
                for (final project in projects)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: colorForProject(project),
                      ),
                      label: Text(project.name),
                      selected: !_hiddenProjectIds.contains(project.id),
                      showCheckmark: false,
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _hiddenProjectIds.remove(project.id);
                        } else {
                          _hiddenProjectIds.add(project.id);
                        }
                      }),
                    ),
                  ),
                if (hasShiftsWithoutProject)
                  FilterChip(
                    label: Text(l10n.noProjectOption),
                    selected: !_hideNoProject,
                    showCheckmark: false,
                    onSelected: (selected) =>
                        setState(() => _hideNoProject = !selected),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shiftsLoading && allShifts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ScheduleCalendar(
                    shifts: shifts,
                    projects: visibleProjects,
                    people: people,
                    isOwner: true,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addShiftTooltip,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddShiftScreen(companyId: widget.companyId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
