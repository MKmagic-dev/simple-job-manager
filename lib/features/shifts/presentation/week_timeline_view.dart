import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/domain/project_model.dart';
import '../domain/shift_model.dart';

const _employeeColors = <MaterialColor>[
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.brown,
];

/// A person shown on the calendar's legend and used to color/label their
/// shift blocks. [avatarUrl] is optional — when present and a block is tall
/// enough, their photo is shown instead of initials.
class CalendarPerson {
  const CalendarPerson({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;
}

int _minutesSinceMidnight(TimeOfDay time) => time.hour * 60 + time.minute;

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _initialsOf(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// A Google-Calendar-style week view: a time axis down the side, one column
/// per day, shift blocks positioned by start/end time (split into
/// side-by-side lanes if more than one employee has an overlapping shift
/// that day), and a row above the grid showing which projects are active
/// during the visible week as spanning bars.
///
/// Pass an empty [people] list for a single-person view (the worker's own
/// schedule) — blocks then all use one color and skip showing whose shift
/// it is, since it's always "you". Otherwise a legend is shown above the
/// grid letting the boss tap a person to hide/show their shifts.
class WeekTimelineView extends StatefulWidget {
  const WeekTimelineView({
    super.key,
    required this.shifts,
    required this.projects,
    this.people = const [],
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final List<CalendarPerson> people;

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
  final _hiddenPersonIds = <String>{};

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
  }

  CalendarPerson? _personById(String id) => widget.people.where((p) => p.id == id).firstOrNull;

  MaterialColor _colorForPerson(String id) {
    final index = widget.people.indexWhere((p) => p.id == id);
    return _employeeColors[(index < 0 ? 0 : index) % _employeeColors.length];
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
    final employeeName = _personById(shift.employeeId)?.name;
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
    final singlePerson = widget.people.isEmpty;

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
        if (!singlePerson) _buildLegend(context),
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

  Widget _buildLegend(BuildContext context) {
    if (widget.people.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final person in widget.people)
            _LegendChip(
              name: person.name,
              color: _colorForPerson(person.id),
              hidden: _hiddenPersonIds.contains(person.id),
              onTap: () => setState(() {
                if (!_hiddenPersonIds.add(person.id)) {
                  _hiddenPersonIds.remove(person.id);
                }
              }),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildDayShiftBlocks(
    DateTime day,
    int dayIndex,
    double columnWidth,
    bool singlePerson,
  ) {
    final dayShifts = widget.shifts
        .where((shift) => _isSameDate(shift.workDate, day) && !_hiddenPersonIds.contains(shift.employeeId))
        .toList();
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
              child: _ShiftBlock(
                singlePerson: singlePerson,
                startTimeLabel: _formatTime(shift.startTime),
                person: singlePerson ? null : _personById(shift.employeeId),
                color: singlePerson ? null : _colorForPerson(shift.employeeId),
                height: (_minutesSinceMidnight(shift.endTime) - _minutesSinceMidnight(shift.startTime)) /
                    60 *
                    _hourHeight,
              ),
            ),
          ),
    ];
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.name,
    required this.color,
    required this.hidden,
    required this.onTap,
  });

  final String name;
  final MaterialColor color;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hidden ? null : color.shade50,
          border: Border.all(color: hidden ? Theme.of(context).dividerColor : color.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hidden ? Colors.transparent : color,
                border: hidden ? Border.all(color: color) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                color: hidden ? Theme.of(context).disabledColor : null,
                decoration: hidden ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
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
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
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
                errorBuilder: (context, error, stackTrace) => _initials(swatch, name),
              ),
            )
          : _initials(swatch, name),
    );
  }

  Widget _initials(MaterialColor swatch, String name) {
    return Text(
      _initialsOf(name),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: swatch.shade900),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
