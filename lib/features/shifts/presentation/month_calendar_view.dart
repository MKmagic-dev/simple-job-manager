import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../projects/domain/project_model.dart';
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
    this.people = const [],
    this.isOwner = false,
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final List<CalendarPerson> people;
  final bool isOwner;

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
    final firstGridDay = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
    return List.generate(42, (i) => firstGridDay.add(Duration(days: i)));
  }

  List<ShiftModel> _shiftsOn(DateTime day) => widget.shifts
      .where((shift) => isSameDate(shift.workDate, day) && !_hiddenPersonIds.contains(shift.employeeId))
      .toList();

  List<ProjectModel> _projectsOn(DateTime day) =>
      widget.projects.where((project) => isProjectActiveOn(project, day)).toList();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final singlePerson = widget.people.isEmpty;
    final days = _gridDays;

    return Column(
      children: [
        CalendarNavHeader(
          label: DateFormat.yMMMM(locale).format(_month),
          onPrevious: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
          onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
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
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final inMonth = day.month == _month.month;
              final dayShifts = _shiftsOn(day);
              final peopleWithShifts = <String>{for (final shift in dayShifts) shift.employeeId};
              final dayProjects = _projectsOn(day);

              return InkWell(
                onTap: () => showDayShiftsSheet(
                  context,
                  day: day,
                  shifts: widget.shifts,
                  people: widget.people,
                  projects: widget.projects,
                  isOwner: widget.isOwner,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
                    color: isSameDate(day, DateTime.now())
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
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
                      Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: inMonth ? null : Theme.of(context).disabledColor,
                            ),
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
                              Text('+${peopleWithShifts.length - 4}', style: const TextStyle(fontSize: 9)),
                          ],
                        ),
                    ],
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
