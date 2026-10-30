import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_math.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../calendar_events/domain/calendar_event_model.dart';
import '../../projects/domain/project_model.dart';
import '../../tasks/domain/project_task_model.dart';
import '../domain/shift_model.dart';
import 'calendar_shared.dart';
import 'day_shifts_sheet.dart';

/// A year overview: 12 month cards with readable day numbers. Each task is a
/// colored bar under the days it covers (its own color), each event a small
/// dot, each shift a round dot; with [showProjectBars] projects get a thin bar
/// too. Tap a day for its details, or a month's name to open that month.
class YearCalendarView extends StatefulWidget {
  const YearCalendarView({
    super.key,
    required this.shifts,
    required this.projects,
    this.tasks = const [],
    this.events = const [],
    this.showProjectBars = true,
    this.people = const [],
    this.isOwner = false,
    this.focusDate,
    this.onFocusChanged,
    this.onOpenMonth,
    this.onAddEvent,
    this.onEventTap,
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final List<ProjectTaskModel> tasks;
  final List<CalendarEventModel> events;
  final bool showProjectBars;
  final List<CalendarPerson> people;
  final bool isOwner;

  /// The date shared with the other calendar views (see ScheduleCalendar).
  final DateTime? focusDate;
  final ValueChanged<DateTime>? onFocusChanged;

  /// Called with the first day of a month when its name is tapped.
  final ValueChanged<DateTime>? onOpenMonth;
  final ValueChanged<DateTime>? onAddEvent;
  final ValueChanged<CalendarEventModel>? onEventTap;

  @override
  State<YearCalendarView> createState() => _YearCalendarViewState();
}

class _YearCalendarViewState extends State<YearCalendarView> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = (widget.focusDate ?? DateTime.now()).year;
  }

  @override
  void didUpdateWidget(YearCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focusDate;
    if (focus != null && focus != oldWidget.focusDate) _year = focus.year;
  }

  void _goToYear(int year) {
    setState(() => _year = year);
    final today = DateTime.now();
    widget.onFocusChanged?.call(
      year == today.year ? today : DateTime(year, 1, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CalendarNavHeader(
          label: '$_year',
          onPrevious: () => _goToYear(_year - 1),
          onNext: () => _goToYear(_year + 1),
          onToday: () => _goToYear(DateTime.now().year),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const padding = 10.0;
              const spacing = 10.0;
              final columns = constraints.maxWidth >= 1000
                  ? 4
                  : (constraints.maxWidth >= 640 ? 3 : 2);
              final cardWidth =
                  (constraints.maxWidth -
                      2 * padding -
                      spacing * (columns - 1)) /
                  columns;
              // Square-ish day cells, never too small to read or tap.
              final cellWidth = (cardWidth - 12) / 7;
              final cellHeight = cellWidth.clamp(24.0, 46.0);
              final cardHeight = 12 + 24 + 14 + 6 * cellHeight + 4;

              return GridView.builder(
                padding: const EdgeInsets.all(padding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: cardHeight,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                ),
                itemCount: 12,
                itemBuilder: (context, index) => _MiniMonth(
                  month: DateTime(_year, index + 1, 1),
                  cellHeight: cellHeight,
                  shifts: widget.shifts,
                  projects: widget.showProjectBars ? widget.projects : const [],
                  tasks: widget.tasks,
                  events: widget.events,
                  onOpenMonth: widget.onOpenMonth == null
                      ? null
                      : () =>
                            widget.onOpenMonth!(DateTime(_year, index + 1, 1)),
                  onDayTap: (day) => showDayShiftsSheet(
                    context,
                    day: day,
                    shifts: widget.shifts,
                    tasks: widget.tasks,
                    people: widget.people,
                    projects: widget.projects,
                    isOwner: widget.isOwner,
                    events: [
                      for (final event in widget.events)
                        if (event.isOn(day)) event,
                    ],
                    onAddEvent: widget.onAddEvent,
                    onEventTap: widget.onEventTap,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.month,
    required this.cellHeight,
    required this.shifts,
    required this.projects,
    required this.tasks,
    required this.events,
    required this.onDayTap,
    this.onOpenMonth,
  });

  final DateTime month;
  final double cellHeight;
  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final List<ProjectTaskModel> tasks;
  final List<CalendarEventModel> events;
  final void Function(DateTime day) onDayTap;
  final VoidCallback? onOpenMonth;

  static const _maxLanes = 3;
  static const _barHeight = 3.0;

  /// Contiguous runs of days (within one grid row, this month only) for which
  /// [active] holds, so a multi-day task draws as one bar.
  List<List<int>> _runsInRow(
    bool Function(DateTime day) active,
    List<DateTime> rowDays,
  ) {
    final columns = <int>[
      for (var c = 0; c < 7; c++)
        if (rowDays[c].month == month.month && active(rowDays[c])) c,
    ];
    final runs = <List<int>>[];
    for (final c in columns) {
      if (runs.isNotEmpty && runs.last.last == c - 1) {
        runs.last.add(c);
      } else {
        runs.add([c]);
      }
    }
    return runs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final firstGridDay = addDays(month, -(month.weekday - 1));
    final days = List.generate(42, (i) => addDays(firstGridDay, i));
    final monthName = toBeginningOfSentenceCase(
      DateFormat.MMMM(locale).format(month),
    );
    final weekdayLetters = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(days[i]).characters.first.toUpperCase(),
    ];
    final bars = <({Color color, bool Function(DateTime) active})>[
      for (final task in tasks)
        (
          color: colorForTask(task, tasks),
          active: (DateTime day) => task.isActiveOn(day),
        ),
      for (final project in projects)
        (
          color: colorForProject(project),
          active: (DateTime day) => isProjectActiveOn(project, day),
        ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Tooltip(
            message: AppLocalizations.of(context)!.openMonthTooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onOpenMonth,
              child: SizedBox(
                height: 24,
                width: double.infinity,
                child: Center(
                  child: Text(
                    monthName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final letter in weekdayLetters)
                  Expanded(
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var row = 0; row < 6; row++)
            SizedBox(
              height: cellHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / 7;
                  final rowDays = days.sublist(row * 7, row * 7 + 7);

                  // Pack this row's bars into at most _maxLanes lanes.
                  final laneEnds = <int>[];
                  final placed =
                      <({Color color, int from, int to, int lane})>[];
                  final runs = <({Color color, int from, int to})>[
                    for (final bar in bars)
                      for (final run in _runsInRow(bar.active, rowDays))
                        (color: bar.color, from: run.first, to: run.last),
                  ]..sort((a, b) => a.from.compareTo(b.from));
                  for (final run in runs) {
                    var lane = laneEnds.indexWhere((end) => end < run.from);
                    if (lane == -1) {
                      if (laneEnds.length >= _maxLanes) continue;
                      laneEnds.add(run.to);
                      lane = laneEnds.length - 1;
                    } else {
                      laneEnds[lane] = run.to;
                    }
                    placed.add((
                      color: run.color,
                      from: run.from,
                      to: run.to,
                      lane: lane,
                    ));
                  }

                  return Stack(
                    children: [
                      for (var c = 0; c < 7; c++)
                        if (rowDays[c].month == month.month)
                          Positioned(
                            left: c * cellWidth,
                            top: 0,
                            width: cellWidth,
                            height: cellHeight,
                            child: _DayCell(
                              day: rowDays[c],
                              hasShift: shifts.any(
                                (s) => isSameDate(s.workDate, rowDays[c]),
                              ),
                              hasEvent: events.any((e) => e.isOn(rowDays[c])),
                              onTap: () => onDayTap(rowDays[c]),
                            ),
                          ),
                      for (final p in placed)
                        Positioned(
                          left: p.from * cellWidth + 1,
                          width: (p.to - p.from + 1) * cellWidth - 2,
                          bottom: 1 + p.lane * (_barHeight + 1),
                          height: _barHeight,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: p.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasShift,
    required this.hasEvent,
    required this.onTap,
  });

  final DateTime day;
  final bool hasShift;
  final bool hasEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = isSameDate(day, DateTime.now());
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.55),
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? theme.colorScheme.primary : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: isToday
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (hasEvent)
            Positioned(
              top: 2,
              right: 3,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          if (hasShift)
            Positioned(
              top: 2,
              left: 3,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
