import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../projects/domain/project_model.dart';
import '../domain/shift_model.dart';
import 'calendar_shared.dart';
import 'day_shifts_sheet.dart';

/// A year overview: 12 small month grids, each with a Gantt-style colored
/// bar per project spanning its active days (own color if set, otherwise
/// automatic), plus a round dot on any day with a shift. Tapping a day
/// opens the day-shifts sheet for the details.
class YearCalendarView extends StatefulWidget {
  const YearCalendarView({
    super.key,
    required this.shifts,
    required this.projects,
    this.people = const [],
    this.isOwner = false,
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final List<CalendarPerson> people;
  final bool isOwner;

  @override
  State<YearCalendarView> createState() => _YearCalendarViewState();
}

class _YearCalendarViewState extends State<YearCalendarView> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CalendarNavHeader(
          label: '$_year',
          onPrevious: () => setState(() => _year -= 1),
          onNext: () => setState(() => _year += 1),
          onToday: () => setState(() => _year = DateTime.now().year),
        ),
        if (widget.projects.isNotEmpty)
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 700
                  ? 4
                  : (constraints.maxWidth >= 420 ? 3 : 2);
              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) => _MiniMonth(
                  month: DateTime(_year, index + 1, 1),
                  shifts: widget.shifts,
                  projects: widget.projects,
                  onDayTap: (day) => showDayShiftsSheet(
                    context,
                    day: day,
                    shifts: widget.shifts,
                    people: widget.people,
                    projects: widget.projects,
                    isOwner: widget.isOwner,
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
    required this.shifts,
    required this.projects,
    required this.onDayTap,
  });

  final DateTime month;
  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final void Function(DateTime day) onDayTap;

  static const _maxStackedBars = 2;
  static const _barHeight = 2.0;

  bool _hasShiftsOn(DateTime day) =>
      shifts.any((shift) => isSameDate(shift.workDate, day));

  /// Contiguous runs of active days (within a single grid row) for [project],
  /// so a multi-day project draws as one spanning bar instead of one segment
  /// per day.
  List<List<int>> _runsInRow(ProjectModel project, List<DateTime> rowDays) {
    final activeColumns = <int>[
      for (var c = 0; c < 7; c++)
        if (rowDays[c].month == month.month &&
            isProjectActiveOn(project, rowDays[c]))
          c,
    ];
    final runs = <List<int>>[];
    for (final c in activeColumns) {
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
    final locale = Localizations.localeOf(context).languageCode;
    final firstGridDay = month.subtract(Duration(days: month.weekday - 1));
    final days = List.generate(42, (i) => firstGridDay.add(Duration(days: i)));
    final monthProjects = projects
        .where(
          (project) => days.any(
            (day) =>
                day.month == month.month && isProjectActiveOn(project, day),
          ),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            DateFormat.MMMM(locale).format(month),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 2),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = constraints.maxWidth / 7;
                final cellHeight = constraints.maxHeight / 6;
                final barsAreaHeight = _maxStackedBars * (_barHeight + 1);

                return Stack(
                  children: [
                    for (var i = 0; i < 42; i++)
                      if (days[i].month == month.month)
                        Positioned(
                          left: (i % 7) * cellWidth,
                          top: (i ~/ 7) * cellHeight,
                          width: cellWidth,
                          height: cellHeight,
                          child: GestureDetector(
                            onTap: () => onDayTap(days[i]),
                            child: Container(
                              alignment: Alignment.topCenter,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSameDate(days[i], DateTime.now())
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : null,
                              ),
                              margin: const EdgeInsets.all(1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${days[i].day}',
                                    style: const TextStyle(fontSize: 8),
                                  ),
                                  if (_hasShiftsOn(days[i]))
                                    Container(
                                      width: 3,
                                      height: 3,
                                      margin: const EdgeInsets.only(top: 1),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    for (
                      var projectIndex = 0;
                      projectIndex < monthProjects.length;
                      projectIndex++
                    )
                      for (var row = 0; row < 6; row++)
                        for (final run in _runsInRow(
                          monthProjects[projectIndex],
                          days.sublist(row * 7, row * 7 + 7),
                        ))
                          Positioned(
                            left: run.first * cellWidth + 1,
                            top:
                                row * cellHeight +
                                cellHeight -
                                barsAreaHeight +
                                (projectIndex % _maxStackedBars) *
                                    (_barHeight + 1),
                            width: run.length * cellWidth - 2,
                            height: _barHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colorForProject(
                                  monthProjects[projectIndex],
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
