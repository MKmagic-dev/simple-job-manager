import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../calendar_events/domain/calendar_event_model.dart';
import '../../projects/domain/project_model.dart';
import '../../tasks/domain/project_task_model.dart';
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
                    task.hasHours
                        ? '${formatTime(task.startTime!)}–${formatTime(task.endTime!)}'
                        : l10n.taskWholeDayLabel,
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
