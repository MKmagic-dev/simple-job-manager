import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../calendar_events/domain/calendar_event_model.dart';
import '../../projects/domain/project_model.dart';
import '../../tasks/domain/project_task_model.dart';
import '../domain/shift_model.dart';
import 'calendar_shared.dart';
import 'day_shifts_sheet.dart';

/// A month grid, like a paper wall calendar: each day cell shows a small
/// colored dot per person with a shift that day (or a single brand-colored
/// dot in the single-person worker view). Tapping a day opens the
/// day-shifts sheet with the full list.
class MonthCalendarView extends StatefulWidget {
  const MonthCalendarView({
    super.key,
    required this.shifts,
    required this.projects,
    this.tasks = const [],
    this.showProjectBars = true,
    this.people = const [],
    this.isOwner = false,
    this.events = const [],
    this.onAddEvent,
    this.onEventTap,
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final List<ProjectTaskModel> tasks;

  /// Off on a single project's own calendar, where the project-color strip
  /// and legend would just repeat its name.
  final bool showProjectBars;
  final List<CalendarPerson> people;
  final bool isOwner;
  final List<CalendarEventModel> events;
  final ValueChanged<DateTime>? onAddEvent;
  final ValueChanged<CalendarEventModel>? onEventTap;

  @override
  State<MonthCalendarView> createState() => _MonthCalendarViewState();
}

class _MonthCalendarViewState extends State<MonthCalendarView> {
  late DateTime _month;
  final _hiddenPersonIds = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  List<DateTime> get _gridDays {
    final firstOfMonth = _month;
    final firstGridDay = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - 1),
    );
    return List.generate(42, (i) => firstGridDay.add(Duration(days: i)));
  }

  List<ShiftModel> _shiftsOn(DateTime day) => widget.shifts
      .where(
        (shift) =>
            isSameDate(shift.workDate, day) &&
            !_hiddenPersonIds.contains(shift.employeeId),
      )
      .toList();

  List<ProjectModel> _projectsOn(DateTime day) => widget.projects
      .where((project) => isProjectActiveOn(project, day))
      .toList();

  List<ProjectTaskModel> _tasksOn(DateTime day) =>
      widget.tasks.where((task) => task.isActiveOn(day)).toList();

  List<CalendarEventModel> _eventsOn(DateTime day) =>
      widget.events.where((event) => event.isOn(day)).toList();

  Color _taskColor(ProjectTaskModel task) {
    final project = widget.projects
        .where((p) => p.id == task.projectId)
        .firstOrNull;
    return project == null ? Colors.blueGrey : colorForProject(project);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final singlePerson = widget.people.isEmpty;
    final days = _gridDays;

    return Column(
      children: [
        CalendarNavHeader(
          label: DateFormat.yMMMM(locale).format(_month),
          onPrevious: () => setState(
            () => _month = DateTime(_month.year, _month.month - 1, 1),
          ),
          onNext: () => setState(
            () => _month = DateTime(_month.year, _month.month + 1, 1),
          ),
          onToday: () {
            final now = DateTime.now();
            setState(() => _month = DateTime(now.year, now.month, 1));
          },
        ),
        if (!singlePerson)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final person in widget.people)
                  LegendChip(
                    name: person.name,
                    color: colorForPerson(widget.people, person.id),
                    hidden: _hiddenPersonIds.contains(person.id),
                    onTap: () => setState(() {
                      if (!_hiddenPersonIds.add(person.id)) {
                        _hiddenPersonIds.remove(person.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
        if (widget.showProjectBars &&
            widget.projects.isNotEmpty &&
            widget.projects.length <= 6)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final project in widget.projects)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    avatar: CircleAvatar(
                      backgroundColor: colorForProject(project),
                    ),
                    label: Text(
                      project.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat.E(locale).format(days[i]),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  // Rows fill the available height exactly (6 weeks tall)
                  // instead of defaulting to square cells that either
                  // overflow into a scroll or leave dead space below.
                  mainAxisExtent: constraints.maxHeight / 6,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final inMonth = day.month == _month.month;
                  final dayShifts = _shiftsOn(day);
                  final peopleWithShifts = <String>{
                    for (final shift in dayShifts) shift.employeeId,
                  };
                  final dayProjects = widget.showProjectBars
                      ? _projectsOn(day)
                      : const <ProjectModel>[];
                  final dayTasks = _tasksOn(day);
                  final dayEvents = _eventsOn(day);
                  final cellHeight = constraints.maxHeight / 6;
                  final maxTaskChips = cellHeight >= 76 ? 2 : 1;

                  return InkWell(
                    onTap: () => showDayShiftsSheet(
                      context,
                      day: day,
                      shifts: widget.shifts,
                      tasks: widget.tasks,
                      people: widget.people,
                      projects: widget.projects,
                      isOwner: widget.isOwner,
                      events: _eventsOn(day),
                      onAddEvent: widget.onAddEvent,
                      onEventTap: widget.onEventTap,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.18),
                          ),
                          bottom: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dayProjects.isNotEmpty)
                            Row(
                              children: [
                                for (final project in dayProjects.take(3))
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      margin: const EdgeInsets.only(right: 1),
                                      color: colorForProject(project),
                                    ),
                                  ),
                              ],
                            ),
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSameDate(day, DateTime.now())
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            child: Text(
                              '${day.day}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isSameDate(day, DateTime.now())
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : inMonth
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.45),
                                    fontWeight: isSameDate(day, DateTime.now())
                                        ? FontWeight.w600
                                        : null,
                                  ),
                            ),
                          ),
                          if (dayTasks.isNotEmpty || dayEvents.isNotEmpty)
                            Builder(
                              builder: (context) {
                                // Events first, then tasks, sharing the cell's
                                // limited chip slots.
                                final chips = <({String label, Color color})>[
                                  for (final event in dayEvents)
                                    (
                                      label: event.hasTime
                                          ? '${formatTime(event.startTime!)} ${event.title}'
                                          : event.title,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                  for (final task in dayTasks)
                                    (
                                      label: task.title,
                                      color: _taskColor(task),
                                    ),
                                ];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final chip in chips.take(
                                        maxTaskChips,
                                      ))
                                        Container(
                                          height: 13,
                                          margin: const EdgeInsets.only(
                                            bottom: 1,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          decoration: BoxDecoration(
                                            color: chip.color,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            chip.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  chip.color
                                                          .computeLuminance() >
                                                      0.5
                                                  ? Colors.black87
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      if (chips.length > maxTaskChips)
                                        Text(
                                          '+${chips.length - maxTaskChips}',
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const Spacer(),
                          if (singlePerson && dayShifts.isNotEmpty)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          else if (peopleWithShifts.isNotEmpty)
                            Wrap(
                              spacing: 2,
                              runSpacing: 2,
                              children: [
                                for (final id in peopleWithShifts.take(4))
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorForPerson(widget.people, id),
                                    ),
                                  ),
                                if (peopleWithShifts.length > 4)
                                  Text(
                                    '+${peopleWithShifts.length - 4}',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
