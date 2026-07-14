import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/domain/project_model.dart';
import '../domain/shift_model.dart';

const _employeeColors = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.brown,
];

int _minutesSinceMidnight(TimeOfDay time) => time.hour * 60 + time.minute;

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A Google-Calendar-style week view: a time axis down the side, one column
/// per day, shift blocks positioned by start/end time (split into
/// side-by-side lanes if more than one employee has an overlapping shift
/// that day), and a row above the grid showing which projects are active
/// during the visible week as spanning bars.
///
/// Pass an empty [employeeNames] map for a single-person view (the worker's
/// own schedule) — blocks then all use one color and skip showing whose
/// shift it is, since it's always "you".
class WeekTimelineView extends StatefulWidget {
  const WeekTimelineView({
    super.key,
    required this.shifts,
    required this.projects,
    this.employeeNames = const {},
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final Map<String, String> employeeNames;

  @override
  State<WeekTimelineView> createState() => _WeekTimelineViewState();
}

class _WeekTimelineViewState extends State<WeekTimelineView> {
  static const _startHour = 6;
  static const _endHour = 20;
  static const _hourHeight = 60.0;
  static const _gutterWidth = 36.0;
  static const _projectBarHeight = 22.0;

  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
  }

  DateTime _mondayOf(DateTime date) {
    final d = _dateOnly(date);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> get _days => List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  bool _isProjectActiveOn(ProjectModel project, DateTime day) {
    final afterStart = project.startDate == null || !day.isBefore(_dateOnly(project.startDate!));
    final beforeEnd = project.endDate == null || !day.isAfter(_dateOnly(project.endDate!));
    return afterStart && beforeEnd;
  }

  /// Greedy interval-partitioning: packs a day's shifts into the minimum
  /// number of side-by-side lanes such that no two shifts in the same lane
  /// overlap in time.
  List<List<ShiftModel>> _packIntoLanes(List<ShiftModel> dayShifts) {
    final sorted = [...dayShifts]
      ..sort((a, b) => _minutesSinceMidnight(a.startTime).compareTo(_minutesSinceMidnight(b.startTime)));
    final lanes = <List<ShiftModel>>[];
    for (final shift in sorted) {
      final lane = lanes.firstWhere(
        (lane) => _minutesSinceMidnight(lane.last.endTime) <= _minutesSinceMidnight(shift.startTime),
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

  void _showShiftDetails(ShiftModel shift) {
    final l10n = AppLocalizations.of(context)!;
    final employeeName = widget.employeeNames[shift.employeeId];
    final projectName = shift.projectId == null
        ? null
        : widget.projects.where((p) => p.id == shift.projectId).map((p) => p.name).firstOrNull;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.shiftDetailsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(shift.workDate)}  '
              '${_formatTime(shift.startTime)}–${_formatTime(shift.endTime)}',
            ),
            if (employeeName != null) ...[
              const SizedBox(height: 8),
              Text('${l10n.employeeLabel}: $employeeName'),
            ],
            if (projectName != null) ...[
              const SizedBox(height: 8),
              Text('${l10n.projectLabel}: $projectName'),
            ],
            if (shift.notes != null && shift.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(shift.notes!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final days = _days;
    final singlePerson = widget.employeeNames.isEmpty;
    final orderedEmployeeIds = widget.employeeNames.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.previousWeekTooltip,
                onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${DateFormat.MMMd(locale).format(days.first)} '
                    '– ${DateFormat.MMMd(locale).format(days.last)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.nextWeekTooltip,
                onPressed: () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7))),
              ),
              TextButton(
                onPressed: () => setState(() => _weekStart = _mondayOf(DateTime.now())),
                child: Text(l10n.todayButtonLabel),
              ),
            ],
          ),
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
                    color: _isSameDate(day, DateTime.now())
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
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
        Builder(
          builder: (context) {
            final activeProjectsThisWeek = widget.projects
                .where((project) => days.any((day) => _isProjectActiveOn(project, day)))
                .toList();

            if (activeProjectsThisWeek.isEmpty) {
              return const SizedBox.shrink();
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = (constraints.maxWidth - _gutterWidth) / 7;
                return SizedBox(
                  height: _projectBarHeight * activeProjectsThisWeek.length,
                  child: Stack(
                    children: [
                      for (var row = 0; row < activeProjectsThisWeek.length; row++)
                        ..._buildProjectBarSegments(
                          activeProjectsThisWeek[row],
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
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = (constraints.maxWidth - _gutterWidth) / 7;
                final gridHeight = (_endHour - _startHour) * _hourHeight;
                return SizedBox(
                  height: gridHeight,
                  child: Stack(
                    children: [
                      for (var hour = _startHour; hour <= _endHour; hour++)
                        Positioned(
                          top: (hour - _startHour) * _hourHeight,
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
                                child: Divider(height: 1, color: Theme.of(context).dividerColor),
                              ),
                            ],
                          ),
                        ),
                      for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                        ..._buildDayShiftBlocks(
                          days[dayIndex],
                          dayIndex,
                          columnWidth,
                          singlePerson,
                          orderedEmployeeIds,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProjectBarSegments(
    ProjectModel project,
    List<DateTime> days,
    double columnWidth,
    int row,
  ) {
    final activeIndices = <int>[
      for (var i = 0; i < days.length; i++)
        if (_isProjectActiveOn(project, days[i])) i,
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

    final color = _employeeColors[project.id.hashCode.abs() % _employeeColors.length];

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
    List<String> orderedEmployeeIds,
  ) {
    final dayShifts = widget.shifts.where((shift) => _isSameDate(shift.workDate, day)).toList();
    if (dayShifts.isEmpty) return const [];

    final lanes = _packIntoLanes(dayShifts);
    final laneWidth = columnWidth / lanes.length;

    return [
      for (var laneIndex = 0; laneIndex < lanes.length; laneIndex++)
        for (final shift in lanes[laneIndex])
          Positioned(
            top: (_minutesSinceMidnight(shift.startTime) - _startHour * 60) / 60 * _hourHeight,
            left: _gutterWidth + dayIndex * columnWidth + laneIndex * laneWidth,
            width: laneWidth,
            height: (_minutesSinceMidnight(shift.endTime) - _minutesSinceMidnight(shift.startTime)) /
                60 *
                _hourHeight,
            child: GestureDetector(
              onTap: () => _showShiftDetails(shift),
              child: Container(
                margin: const EdgeInsets.all(1),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: (singlePerson
                          ? Theme.of(context).colorScheme.primary
                          : _employeeColors[
                              orderedEmployeeIds.indexOf(shift.employeeId) % _employeeColors.length])
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  singlePerson
                      ? _formatTime(shift.startTime)
                      : (widget.employeeNames[shift.employeeId] ?? '?'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
          ),
    ];
  }
}
