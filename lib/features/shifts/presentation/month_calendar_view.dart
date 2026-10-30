import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_math.dart';
import '../../calendar_events/domain/calendar_event_model.dart';
import '../../projects/domain/project_model.dart';
import '../../tasks/domain/project_task_model.dart';
import '../../tasks/domain/task_assignment_model.dart';
import '../../tasks/presentation/task_detail_screen.dart';
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
    this.taskAssignments = const [],
    this.showProjectBars = true,
    this.people = const [],
    this.isOwner = false,
    this.events = const [],
    this.onAddEvent,
    this.onEventTap,
    this.focusDate,
    this.onFocusChanged,
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final List<ProjectTaskModel> tasks;
  final List<TaskAssignmentModel> taskAssignments;

  /// Off on a single project's own calendar, where the project-color strip
  /// and legend would just repeat its name.
  final bool showProjectBars;
  final List<CalendarPerson> people;
  final bool isOwner;
  final List<CalendarEventModel> events;
  final ValueChanged<DateTime>? onAddEvent;
  final ValueChanged<CalendarEventModel>? onEventTap;

  /// The date shared with the other calendar views (see ScheduleCalendar).
  final DateTime? focusDate;
  final ValueChanged<DateTime>? onFocusChanged;

  @override
  State<MonthCalendarView> createState() => _MonthCalendarViewState();
}

class _MonthCalendarViewState extends State<MonthCalendarView> {
  late DateTime _month;
  final _hiddenPersonIds = <String>{};

  /// The tasks left after switching people off in the legend.
  List<ProjectTaskModel> get _tasksShown => tasksForVisiblePeople(
    widget.tasks,
    shifts: widget.shifts,
    assignments: widget.taskAssignments,
    hiddenIds: _hiddenPersonIds,
  );

  @override
  void initState() {
    super.initState();
    final start = widget.focusDate ?? DateTime.now();
    _month = DateTime(start.year, start.month, 1);
  }

  @override
  void didUpdateWidget(MonthCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focusDate;
    if (focus == null || focus == oldWidget.focusDate) return;
    if (focus.year != _month.year || focus.month != _month.month) {
      _month = DateTime(focus.year, focus.month, 1);
    }
  }

  /// Moves to [month] and tells the other views: today when the month is the
  /// current one (so the week view lands on this week), else its first day.
  void _goToMonth(DateTime month) {
    setState(() => _month = month);
    final today = dateOnly(DateTime.now());
    widget.onFocusChanged?.call(
      month.year == today.year && month.month == today.month ? today : month,
    );
  }

  List<DateTime> get _gridDays {
    final firstOfMonth = _month;
    final firstGridDay = addDays(firstOfMonth, -(firstOfMonth.weekday - 1));
    return List.generate(42, (i) => addDays(firstGridDay, i));
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

  List<CalendarEventModel> _eventsOn(DateTime day) =>
      widget.events.where((event) => event.isOn(day)).toList();

  Color _taskColor(ProjectTaskModel task) => colorForTask(task, widget.tasks);

  static const _numberAreaHeight = 26.0;
  static const _lanePitch = 15.0;
  static const _barHeight = 14.0;
  static const _maxLanes = 4;

  /// One week of the grid: seven day cells, with each task drawn on top as ONE
  /// continuous colored bar across the days it covers (one lane per overlapping
  /// task), so a multi-day task reads as a single block instead of a repeated
  /// label.
  Widget _buildWeek(BuildContext context, List<DateTime> weekDays) {
    final segments = <({ProjectTaskModel task, int from, int to})>[];
    for (final task in _tasksShown) {
      final from = weekDays.indexWhere(task.isActiveOn);
      if (from == -1) continue;
      segments.add((
        task: task,
        from: from,
        to: weekDays.lastIndexWhere(task.isActiveOn),
      ));
    }
    segments.sort((a, b) {
      final byStart = a.from.compareTo(b.from);
      return byStart != 0 ? byStart : (b.to - b.from).compareTo(a.to - a.from);
    });

    final laneEnds = <int>[];
    final placed = <({ProjectTaskModel task, int from, int to, int lane})>[];
    for (final segment in segments) {
      var lane = laneEnds.indexWhere((end) => end < segment.from);
      if (lane == -1) {
        laneEnds.add(segment.to);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = segment.to;
      }
      placed.add((
        task: segment.task,
        from: segment.from,
        to: segment.to,
        lane: lane,
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final hasEvents = weekDays.any((day) => _eventsOn(day).isNotEmpty);
        // How many lanes fit above the day's events and dots.
        final roomForLanes =
            (constraints.maxHeight -
                _numberAreaHeight -
                12 -
                (hasEvents ? 14 : 0)) /
            _lanePitch;
        final visibleLanes = laneEnds.isEmpty
            ? 0
            : roomForLanes
                  .floor()
                  .clamp(1, _maxLanes)
                  .clamp(0, laneEnds.length);

        int hiddenOn(int column) => placed
            .where(
              (p) =>
                  p.lane >= visibleLanes && p.from <= column && column <= p.to,
            )
            .length;

        return Stack(
          children: [
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _buildDayCell(
                      context,
                      weekDays[column],
                      reservedForBars: visibleLanes * _lanePitch,
                      hiddenTasks: hiddenOn(column),
                    ),
                  ),
              ],
            ),
            for (final p in placed)
              if (p.lane < visibleLanes)
                Positioned(
                  left: p.from * cellWidth + 1,
                  width: (p.to - p.from + 1) * cellWidth - 2,
                  top: _numberAreaHeight + p.lane * _lanePitch,
                  height: _barHeight,
                  child: _buildTaskBar(context, p.task, p.from, p.to, weekDays),
                ),
          ],
        );
      },
    );
  }

  Widget _buildTaskBar(
    BuildContext context,
    ProjectTaskModel task,
    int from,
    int to,
    List<DateTime> weekDays,
  ) {
    final color = _taskColor(task);
    final startsHere = isSameDate(weekDays[from], task.startDate);
    final endsHere = isSameDate(weekDays[to], task.endDate);
    const radius = Radius.circular(5);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              TaskDetailScreen(task: task, isOwner: widget.isOwner),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.horizontal(
            left: startsHere ? radius : Radius.zero,
            right: endsHere ? radius : Radius.zero,
          ),
        ),
        child: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color.computeLuminance() > 0.5
                ? Colors.black87
                : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day, {
    required double reservedForBars,
    required int hiddenTasks,
  }) {
    final theme = Theme.of(context);
    final singlePerson = widget.people.isEmpty;
    final inMonth = day.month == _month.month;
    final isToday = isSameDate(day, DateTime.now());
    final dayShifts = _shiftsOn(day);
    final peopleWithShifts = <String>{
      for (final shift in dayShifts) shift.employeeId,
    };
    final dayProjects = widget.showProjectBars
        ? _projectsOn(day)
        : const <ProjectModel>[];
    final dayEvents = _eventsOn(day);
    final lineColor = theme.colorScheme.primary.withValues(alpha: 0.18);

    return InkWell(
      onTap: () => showDayShiftsSheet(
        context,
        day: day,
        shifts: widget.shifts,
        tasks: _tasksShown,
        people: widget.people,
        projects: widget.projects,
        isOwner: widget.isOwner,
        events: dayEvents,
        onAddEvent: widget.onAddEvent,
        onEventTap: widget.onEventTap,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: lineColor),
            bottom: BorderSide(color: lineColor),
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday ? theme.colorScheme.primary : null,
                      ),
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isToday
                              ? theme.colorScheme.onPrimary
                              : inMonth
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.45,
                                ),
                          fontWeight: isToday ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    // Room for the task bars drawn over this cell.
                    SizedBox(height: 2 + reservedForBars),
                    if (hiddenTasks > 0)
                      Text(
                        '+$hiddenTasks',
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (dayEvents.isNotEmpty)
                      Container(
                        height: 13,
                        margin: const EdgeInsets.only(bottom: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          dayEvents.first.hasTime
                              ? '${formatTime(dayEvents.first.startTime!)} ${dayEvents.first.title}'
                              : dayEvents.first.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color:
                                theme.colorScheme.secondary.computeLuminance() >
                                    0.5
                                ? Colors.black87
                                : Colors.white,
                          ),
                        ),
                      ),
                    if (dayEvents.length > 1)
                      Text(
                        '+${dayEvents.length - 1}',
                        style: const TextStyle(fontSize: 9),
                      ),
                    const SizedBox(height: 2),
                    if (singlePerson && dayShifts.isNotEmpty)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
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
            ),
            if (dayProjects.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
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
              ),
          ],
        ),
      ),
    );
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
          onPrevious: () =>
              _goToMonth(DateTime(_month.year, _month.month - 1, 1)),
          onNext: () => _goToMonth(DateTime(_month.year, _month.month + 1, 1)),
          onToday: () {
            final now = DateTime.now();
            _goToMonth(DateTime(now.year, now.month, 1));
          },
        ),
        if (!singlePerson)
          PeopleLegend(
            people: widget.people,
            hiddenIds: _hiddenPersonIds,
            onToggle: (id) => setState(() {
              if (!_hiddenPersonIds.add(id)) _hiddenPersonIds.remove(id);
            }),
            onShowAll: () => setState(_hiddenPersonIds.clear),
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
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Expanded(
                  child: _buildWeek(
                    context,
                    days.sublist(week * 7, week * 7 + 7),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
