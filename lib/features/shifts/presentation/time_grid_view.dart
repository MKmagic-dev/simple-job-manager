import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_math.dart';
import '../../calendar_events/domain/calendar_event_model.dart';
import '../../projects/domain/project_model.dart';
import '../../tasks/domain/project_task_model.dart';
import '../../tasks/presentation/task_detail_screen.dart';
import '../domain/shift_model.dart';
import 'calendar_shared.dart';
import 'shift_details_dialog.dart';

/// A Google-Calendar-style time grid: a time axis down the side, one column
/// per day (either 1 for the day view or 7 for the week view), shift blocks
/// positioned by start/end time (split into side-by-side lanes if more than
/// one employee has an overlapping shift that day), and a row above the
/// grid showing which projects are active during the visible range as
/// spanning bars.
///
/// Pass an empty [people] list for a single-person view (the worker's own
/// schedule) — blocks then all use one color and skip showing whose shift
/// it is, since it's always "you". Otherwise a legend is shown above the
/// grid letting the boss tap a person to hide/show their shifts.
class TimeGridView extends StatefulWidget {
  const TimeGridView({
    super.key,
    required this.shifts,
    required this.projects,
    this.tasks = const [],
    this.showProjectBars = true,
    this.people = const [],
    this.daySpan = 7,
    this.isOwner = false,
    this.events = const [],
    this.onEventTap,
    this.focusDate,
    this.onFocusChanged,
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;

  /// Tasks are date-range items without a time of day, so they're drawn as
  /// spanning bars in a strip above the hour grid (like all-day events).
  final List<ProjectTaskModel> tasks;

  /// Whether to draw the "project is active" bars. Off on a single
  /// project's own calendar, where they'd just repeat its name.
  final bool showProjectBars;
  final List<CalendarPerson> people;

  /// 7 for the week view, 1 for the day view.
  final int daySpan;

  /// Whether the shift-detail dialog should offer edit/delete (owner) or a
  /// "request a change" button (employee viewing their own shift).
  final bool isOwner;

  /// Personal events: all-day / multi-day ones become bars in the strip above
  /// the hour grid, single-day timed ones become blocks in the grid.
  final List<CalendarEventModel> events;
  final ValueChanged<CalendarEventModel>? onEventTap;

  /// The date shared with the other calendar views: this view shows the
  /// day/week containing it, and reports navigation through [onFocusChanged].
  final DateTime? focusDate;
  final ValueChanged<DateTime>? onFocusChanged;

  @override
  State<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends State<TimeGridView> {
  static const _startHour = 6;
  static const _endHour = 24;
  static const _minHourHeight = 32.0;
  static const _gutterWidth = 36.0;
  static const _projectBarHeight = 22.0;

  late DateTime _rangeStart;
  final _hiddenPersonIds = <String>{};

  @override
  void initState() {
    super.initState();
    _rangeStart = _anchorFor(widget.focusDate ?? DateTime.now());
  }

  @override
  void didUpdateWidget(TimeGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focusDate;
    if (focus == null || focus == oldWidget.focusDate) return;
    // Already showing the focused date? Stay put (e.g. we caused the change).
    final inRange = _days.any((day) => isSameDate(day, focus));
    if (!inRange) _rangeStart = _anchorFor(focus);
  }

  void _goTo(DateTime rangeStart) {
    setState(() => _rangeStart = rangeStart);
    widget.onFocusChanged?.call(rangeStart);
  }

  DateTime _anchorFor(DateTime date) {
    final d = dateOnly(date);
    return widget.daySpan == 1 ? d : addDays(d, -(d.weekday - 1));
  }

  List<DateTime> get _days =>
      List.generate(widget.daySpan, (i) => addDays(_rangeStart, i));

  int _minutesSinceMidnight(TimeOfDay time) => time.hour * 60 + time.minute;

  /// Greedy interval-partitioning: packs a day's shifts into the minimum
  /// number of side-by-side lanes such that no two shifts in the same lane
  /// overlap in time.
  List<List<ShiftModel>> _packIntoLanes(List<ShiftModel> dayShifts) {
    final sorted = [...dayShifts]
      ..sort(
        (a, b) => _minutesSinceMidnight(
          a.startTime,
        ).compareTo(_minutesSinceMidnight(b.startTime)),
      );
    final lanes = <List<ShiftModel>>[];
    for (final shift in sorted) {
      final lane = lanes.firstWhere(
        (lane) =>
            _minutesSinceMidnight(lane.last.endTime) <=
            _minutesSinceMidnight(shift.startTime),
        orElse: () {
          final newLane = <ShiftModel>[];
          lanes.add(newLane);
          return newLane;
        },
      );
      lane.add(shift);
    }
    return lanes;
  }

  String _headerLabel(BuildContext context, List<DateTime> days) {
    final locale = Localizations.localeOf(context).languageCode;
    if (widget.daySpan == 1) {
      return DateFormat.yMMMEd(locale).format(days.first);
    }
    return '${DateFormat.MMMd(locale).format(days.first)} – ${DateFormat.MMMd(locale).format(days.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final days = _days;
    final singlePerson = widget.people.isEmpty;

    return Column(
      children: [
        CalendarNavHeader(
          label: _headerLabel(context, days),
          onPrevious: () => _goTo(addDays(_rangeStart, -widget.daySpan)),
          onNext: () => _goTo(addDays(_rangeStart, widget.daySpan)),
          onToday: () {
            final today = dateOnly(DateTime.now());
            setState(() => _rangeStart = _anchorFor(today));
            widget.onFocusChanged?.call(today);
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
        Row(
          children: [
            const SizedBox(width: _gutterWidth),
            for (final day in days)
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSameDate(day, DateTime.now())
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    border: Border(
                      left: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat.E(locale).format(day),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text('${day.day}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (widget.tasks.isNotEmpty) _buildTaskStrip(context, days),
        _buildEventStrip(context, days),
        if (widget.showProjectBars)
          Builder(
            builder: (context) {
              final activeProjectsThisRange = widget.projects
                  .where(
                    (project) =>
                        days.any((day) => isProjectActiveOn(project, day)),
                  )
                  .toList();

              if (activeProjectsThisRange.isEmpty) {
                return const SizedBox.shrink();
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final columnWidth =
                      (constraints.maxWidth - _gutterWidth) / widget.daySpan;
                  return SizedBox(
                    height: _projectBarHeight * activeProjectsThisRange.length,
                    child: Stack(
                      children: [
                        for (
                          var row = 0;
                          row < activeProjectsThisRange.length;
                          row++
                        )
                          ..._buildProjectBarSegments(
                            activeProjectsThisRange[row],
                            days,
                            columnWidth,
                            row,
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columnWidth =
                  (constraints.maxWidth - _gutterWidth) / widget.daySpan;
              final totalHours = _endHour - _startHour;
              // Fit the whole range into the available space when it comfortably
              // fits (no need to scroll a half-empty grid); fall back to a
              // readable minimum row height — and scrolling — once it doesn't.
              final hourHeight = (constraints.maxHeight / totalHours).clamp(
                _minHourHeight,
                double.infinity,
              );
              final gridHeight = totalHours * hourHeight;

              final grid = SizedBox(
                height: gridHeight,
                child: Stack(
                  children: [
                    for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                      if (isSameDate(days[dayIndex], DateTime.now()) ||
                          days[dayIndex].weekday == DateTime.saturday ||
                          days[dayIndex].weekday == DateTime.sunday)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: _gutterWidth + dayIndex * columnWidth,
                          width: columnWidth,
                          child: ColoredBox(
                            color: isSameDate(days[dayIndex], DateTime.now())
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.06)
                                : Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.12),
                          ),
                        ),
                    for (var hour = _startHour; hour <= _endHour; hour++)
                      Positioned(
                        top: (hour - _startHour) * hourHeight,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            SizedBox(
                              width: _gutterWidth,
                              child: Text(
                                '$hour:00',
                                style: Theme.of(context).textTheme.labelSmall,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                height: 1,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (var dayIndex = 0; dayIndex <= days.length; dayIndex++)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: _gutterWidth + dayIndex * columnWidth,
                        width: 1,
                        child: ColoredBox(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.4),
                        ),
                      ),
                    for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                      ..._buildDayShiftBlocks(
                        days[dayIndex],
                        dayIndex,
                        columnWidth,
                        singlePerson,
                        hourHeight,
                      ),
                    for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                      ..._buildDayEventBlocks(
                        days[dayIndex],
                        dayIndex,
                        columnWidth,
                        hourHeight,
                      ),
                  ],
                ),
              );

              return gridHeight > constraints.maxHeight
                  ? SingleChildScrollView(child: grid)
                  : grid;
            },
          ),
        ),
      ],
    );
  }

  /// Tasks that touch the visible days, packed into as few rows as possible
  /// (two tasks share a row only if their visible spans don't overlap).
  Widget _buildTaskStrip(BuildContext context, List<DateTime> days) {
    final visible =
        widget.tasks.where((task) => days.any(task.isActiveOn)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    if (visible.isEmpty) return const SizedBox.shrink();

    final rowEnds = <int>[];
    final placements = <({ProjectTaskModel task, int row, int from, int to})>[];
    for (final task in visible) {
      final from = days.indexWhere(task.isActiveOn);
      final to = days.lastIndexWhere(task.isActiveOn);
      var row = rowEnds.indexWhere((end) => end < from);
      if (row == -1) {
        rowEnds.add(to);
        row = rowEnds.length - 1;
      } else {
        rowEnds[row] = to;
      }
      placements.add((task: task, row: row, from: from, to: to));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth =
            (constraints.maxWidth - _gutterWidth) / widget.daySpan;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: SizedBox(
            height: rowEnds.length * _projectBarHeight,
            child: Stack(
              children: [
                for (final placement in placements)
                  _buildTaskBar(context, placement, columnWidth),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskBar(
    BuildContext context,
    ({ProjectTaskModel task, int row, int from, int to}) placement,
    double columnWidth,
  ) {
    final task = placement.task;
    final color = colorForTask(task, widget.tasks);
    final textColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Positioned(
      top: placement.row * _projectBarHeight,
      left: _gutterWidth + placement.from * columnWidth,
      width: (placement.to - placement.from + 1) * columnWidth,
      height: _projectBarHeight - 2,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                TaskDetailScreen(task: task, isOwner: widget.isOwner),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            task.title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  bool _isStripEvent(CalendarEventModel event) =>
      !event.hasTime || event.isMultiDay || event.endTime == null;

  /// All-day and multi-day events as spanning bars, packed into rows.
  Widget _buildEventStrip(BuildContext context, List<DateTime> days) {
    final visible =
        widget.events
            .where((event) => _isStripEvent(event) && days.any(event.isOn))
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    if (visible.isEmpty) return const SizedBox.shrink();

    final rowEnds = <int>[];
    final placements =
        <({CalendarEventModel event, int row, int from, int to})>[];
    for (final event in visible) {
      final from = days.indexWhere(event.isOn);
      final to = days.lastIndexWhere(event.isOn);
      var row = rowEnds.indexWhere((end) => end < from);
      if (row == -1) {
        rowEnds.add(to);
        row = rowEnds.length - 1;
      } else {
        rowEnds[row] = to;
      }
      placements.add((event: event, row: row, from: from, to: to));
    }

    final color = Theme.of(context).colorScheme.secondary;
    final textColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth =
            (constraints.maxWidth - _gutterWidth) / widget.daySpan;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: SizedBox(
            height: rowEnds.length * _projectBarHeight,
            child: Stack(
              children: [
                for (final placement in placements)
                  Positioned(
                    top: placement.row * _projectBarHeight,
                    left: _gutterWidth + placement.from * columnWidth,
                    width: (placement.to - placement.from + 1) * columnWidth,
                    height: _projectBarHeight - 2,
                    child: GestureDetector(
                      onTap: widget.onEventTap == null
                          ? null
                          : () => widget.onEventTap!(placement.event),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          placement.event.title,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Single-day timed events as blocks on the hour grid, side by side when
  /// they overlap.
  List<Widget> _buildDayEventBlocks(
    DateTime day,
    int dayIndex,
    double columnWidth,
    double hourHeight,
  ) {
    final dayEvents =
        widget.events
            .where((event) => !_isStripEvent(event) && event.isOn(day))
            .toList()
          ..sort(
            (a, b) => _minutesSinceMidnight(
              a.startTime!,
            ).compareTo(_minutesSinceMidnight(b.startTime!)),
          );
    if (dayEvents.isEmpty) return const [];

    final lanes = <List<CalendarEventModel>>[];
    for (final event in dayEvents) {
      final lane = lanes.firstWhere(
        (lane) =>
            _minutesSinceMidnight(lane.last.endTime!) <=
            _minutesSinceMidnight(event.startTime!),
        orElse: () {
          final newLane = <CalendarEventModel>[];
          lanes.add(newLane);
          return newLane;
        },
      );
      lane.add(event);
    }
    final laneWidth = columnWidth / lanes.length;
    final color = Theme.of(context).colorScheme.secondary;
    final textColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return [
      for (var laneIndex = 0; laneIndex < lanes.length; laneIndex++)
        for (final event in lanes[laneIndex])
          Positioned(
            top:
                (_minutesSinceMidnight(event.startTime!) - _startHour * 60) /
                60 *
                hourHeight,
            left: _gutterWidth + dayIndex * columnWidth + laneIndex * laneWidth,
            width: laneWidth,
            height:
                ((_minutesSinceMidnight(event.endTime!) -
                            _minutesSinceMidnight(event.startTime!)) /
                        60 *
                        hourHeight)
                    .clamp(18.0, double.infinity),
            child: GestureDetector(
              onTap: widget.onEventTap == null
                  ? null
                  : () => widget.onEventTap!(event),
              child: Container(
                margin: const EdgeInsets.all(1),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${formatTime(event.startTime!)} ${event.title}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ),
            ),
          ),
    ];
  }

  List<Widget> _buildProjectBarSegments(
    ProjectModel project,
    List<DateTime> days,
    double columnWidth,
    int row,
  ) {
    final activeIndices = <int>[
      for (var i = 0; i < days.length; i++)
        if (isProjectActiveOn(project, days[i])) i,
    ];

    // Group consecutive active day-indices into contiguous runs so a
    // multi-day project renders as one spanning bar, not one per day.
    final runs = <List<int>>[];
    for (final index in activeIndices) {
      if (runs.isNotEmpty && runs.last.last == index - 1) {
        runs.last.add(index);
      } else {
        runs.add([index]);
      }
    }

    final color = colorForProject(project);

    return [
      for (final run in runs)
        Positioned(
          top: row * _projectBarHeight,
          left: _gutterWidth + run.first * columnWidth,
          width: run.length * columnWidth,
          height: _projectBarHeight - 2,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color),
            ),
            child: Text(
              project.name,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildDayShiftBlocks(
    DateTime day,
    int dayIndex,
    double columnWidth,
    bool singlePerson,
    double hourHeight,
  ) {
    final dayShifts = widget.shifts
        .where(
          (shift) =>
              isSameDate(shift.workDate, day) &&
              !_hiddenPersonIds.contains(shift.employeeId),
        )
        .toList();
    if (dayShifts.isEmpty) return const [];

    final lanes = _packIntoLanes(dayShifts);
    final laneWidth = columnWidth / lanes.length;

    return [
      for (var laneIndex = 0; laneIndex < lanes.length; laneIndex++)
        for (final shift in lanes[laneIndex])
          Positioned(
            top:
                (_minutesSinceMidnight(shift.startTime) - _startHour * 60) /
                60 *
                hourHeight,
            left: _gutterWidth + dayIndex * columnWidth + laneIndex * laneWidth,
            width: laneWidth,
            height:
                (_minutesSinceMidnight(shift.endTime) -
                    _minutesSinceMidnight(shift.startTime)) /
                60 *
                hourHeight,
            child: GestureDetector(
              onTap: () => showShiftDetailsDialog(
                context,
                shift,
                widget.people,
                widget.projects,
                isOwner: widget.isOwner,
              ),
              child: _ShiftBlock(
                singlePerson: singlePerson,
                startTimeLabel: formatTime(shift.startTime),
                person: singlePerson
                    ? null
                    : personById(widget.people, shift.employeeId),
                color: singlePerson
                    ? null
                    : colorForPerson(widget.people, shift.employeeId),
                height:
                    (_minutesSinceMidnight(shift.endTime) -
                        _minutesSinceMidnight(shift.startTime)) /
                    60 *
                    hourHeight,
              ),
            ),
          ),
    ];
  }
}

/// One shift's block on the grid. For a single-person view it's a solid
/// brand-colored block showing the start time. Otherwise it's tinted with
/// that employee's legend color and shows their photo (if the block is tall
/// enough and they have one) or their initials.
class _ShiftBlock extends StatelessWidget {
  const _ShiftBlock({
    required this.singlePerson,
    required this.startTimeLabel,
    required this.person,
    required this.color,
    required this.height,
  });

  final bool singlePerson;
  final String startTimeLabel;
  final CalendarPerson? person;
  final MaterialColor? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (singlePerson) {
      return Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          startTimeLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      );
    }

    final swatch = color!;
    final name = person?.name ?? '?';
    final avatarUrl = person?.avatarUrl;
    final showAvatar = avatarUrl != null && height >= 28;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      decoration: BoxDecoration(
        color: swatch.shade50,
        border: Border(left: BorderSide(color: swatch.shade400, width: 3)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
      ),
      alignment: Alignment.center,
      child: showAvatar
          ? ClipOval(
              child: Image.network(
                avatarUrl,
                width: 18,
                height: 18,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _initials(swatch, name),
              ),
            )
          : _initials(swatch, name),
    );
  }

  Widget _initials(MaterialColor swatch, String name) {
    return Text(
      initialsOf(name),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: swatch.shade900,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
