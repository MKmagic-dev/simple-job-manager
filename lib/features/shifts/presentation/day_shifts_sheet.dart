import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../calendar_events/domain/calendar_event_model.dart';
import '../../projects/domain/project_model.dart';
import '../../tasks/domain/project_task_model.dart';
import '../../tasks/domain/task_assignment_model.dart';
import '../../tasks/presentation/task_detail_screen.dart';
import '../domain/shift_model.dart';
import 'calendar_shared.dart';
import 'shift_details_dialog.dart';

/// Opens a bottom sheet listing every shift on [day], for use from the
/// month/year grid views where a single cell is too small to show shift
/// blocks directly. Tapping a row opens the same shift-detail dialog the
/// time-grid view uses.
void showDayShiftsSheet(
  BuildContext rootContext, {
  required DateTime day,
  required List<ShiftModel> shifts,
  List<ProjectTaskModel> tasks = const [],
  List<TaskAssignmentModel> taskAssignments = const [],
  required List<CalendarPerson> people,
  required List<ProjectModel> projects,
  required bool isOwner,
  List<CalendarEventModel> events = const [],
  ValueChanged<DateTime>? onAddEvent,
  ValueChanged<CalendarEventModel>? onEventTap,
}) {
  final l10n = AppLocalizations.of(rootContext)!;
  final locale = Localizations.localeOf(rootContext).languageCode;
  final dayTasks = tasks.where((task) => task.isActiveOn(day)).toList();
  final dayShifts =
      shifts.where((shift) => isSameDate(shift.workDate, day)).toList()..sort(
        (a, b) => (a.startTime.hour * 60 + a.startTime.minute).compareTo(
          b.startTime.hour * 60 + b.startTime.minute,
        ),
      );
  // When and who, per task, for this day: the task's own hours, or the hours
  // of the shifts people have on it (hours are usually set per person).
  int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;
  String clock(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  final taskLines = <String, List<String>>{};
  final taskFirstMinute = <String, int>{};
  for (final task in dayTasks) {
    final ranges = <(int, int), Set<String>>{};
    final assignedNames = [
      for (final person in people)
        if (task.assigneeIdsFrom(shifts, taskAssignments).contains(person.id))
          person.name,
    ];
    if (task.hasHours) {
      ranges[(minutesOf(task.startTime!), minutesOf(task.endTime!))] = {
        ...assignedNames,
      };
    }
    for (final shift in dayShifts.where((s) => s.taskId == task.id)) {
      final names = ranges.putIfAbsent((
        minutesOf(shift.startTime),
        minutesOf(shift.endTime),
      ), () => <String>{});
      final name = personById(people, shift.employeeId)?.name;
      if (name != null) names.add(name);
    }
    final sorted = ranges.keys.toList()
      ..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
    taskFirstMinute[task.id] = sorted.isEmpty ? 24 * 60 : sorted.first.$1;
    taskLines[task.id] = [
      for (final range in sorted)
        ranges[range]!.isEmpty
            ? '${clock(range.$1)}–${clock(range.$2)}'
            : '${clock(range.$1)}–${clock(range.$2)} · ${ranges[range]!.join(', ')}',
    ];
  }
  dayTasks.sort((a, b) {
    final byTime = taskFirstMinute[a.id]!.compareTo(taskFirstMinute[b.id]!);
    return byTime != 0 ? byTime : a.title.compareTo(b.title);
  });
  final dayProjects = projects
      .where((project) => isProjectActiveOn(project, day))
      .toList();
  final singlePerson = people.isEmpty;

  showModalBottomSheet<void>(
    context: rootContext,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMMEEEEd(locale).format(day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (events.isNotEmpty || onAddEvent != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.eventsSectionLabel,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (onAddEvent != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(rootContext).pop();
                        onAddEvent(day);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addEventButton),
                    ),
                ],
              ),
              if (events.isEmpty)
                Text(
                  l10n.noEventsThisDay,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                for (final event in events)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      Icons.event_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(event.title),
                    subtitle: Text(
                      [
                        event.hasTime
                            ? '${formatTime(event.startTime!)}–${formatTime(event.endTime!)}'
                            : l10n.eventAllDayLabel,
                        if (event.notes != null && event.notes!.isNotEmpty)
                          event.notes!,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: onEventTap == null
                        ? null
                        : () {
                            Navigator.of(rootContext).pop();
                            onEventTap(event);
                          },
                  ),
            ],
            if (dayProjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.activeProjectsSectionLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final project in dayProjects)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: colorForProject(project),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project.address != null
                              ? '${project.name} · ${project.address}'
                              : project.name,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (dayTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.tasksTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final task in dayTasks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Container(
                    width: 10,
                    height: 10,
                    color: colorForTask(task, tasks),
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                    taskLines[task.id]!.isEmpty
                        ? l10n.taskWholeDayLabel
                        : taskLines[task.id]!.join('\n'),
                  ),
                  onTap: () {
                    Navigator.of(rootContext).pop();
                    Navigator.of(rootContext).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            TaskDetailScreen(task: task, isOwner: isOwner),
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: 12),
            if (dayShifts.isEmpty && dayTasks.isEmpty && events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l10n.noShiftsThisDayLabel),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: dayShifts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final shift = dayShifts[index];
                    final person = singlePerson
                        ? null
                        : personById(people, shift.employeeId);
                    final projectName = shift.projectId == null
                        ? null
                        : projects
                              .where((p) => p.id == shift.projectId)
                              .map((p) => p.name)
                              .firstOrNull;
                    final color = singlePerson
                        ? null
                        : colorForPerson(people, shift.employeeId);

                    return ListTile(
                      leading: singlePerson
                          ? const Icon(Icons.schedule)
                          : CircleAvatar(
                              backgroundColor: color!.shade50,
                              foregroundColor: color.shade900,
                              backgroundImage: person?.avatarUrl != null
                                  ? NetworkImage(person!.avatarUrl!)
                                  : null,
                              child: person?.avatarUrl == null
                                  ? Text(initialsOf(person?.name ?? '?'))
                                  : null,
                            ),
                      title: Text(
                        '${formatTime(shift.startTime)}–${formatTime(shift.endTime)}',
                      ),
                      subtitle: () {
                        final parts = <String>[?person?.name, ?projectName];
                        return parts.isEmpty ? null : Text(parts.join(' · '));
                      }(),
                      onTap: () {
                        Navigator.of(rootContext).pop();
                        showShiftDetailsDialog(
                          rootContext,
                          shift,
                          people,
                          projects,
                          isOwner: isOwner,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
