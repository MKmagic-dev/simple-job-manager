import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../projects/domain/project_model.dart';
import '../domain/shift_model.dart';
import 'calendar_shared.dart';
import 'day_shifts_sheet.dart';

/// A year overview: 12 small month grids. Too zoomed-out to color-code by
/// person, so each day just gets a single dot if anyone has a shift that
/// day — tapping it opens the day-shifts sheet for the details.
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

  bool _hasShiftsOn(DateTime day) => widget.shifts.any((shift) => isSameDate(shift.workDate, day));

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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 700 ? 4 : (constraints.maxWidth >= 420 ? 3 : 2);
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
                  hasShiftsOn: _hasShiftsOn,
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
  const _MiniMonth({required this.month, required this.hasShiftsOn, required this.onDayTap});

  final DateTime month;
  final bool Function(DateTime day) hasShiftsOn;
  final void Function(DateTime day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final firstGridDay = month.subtract(Duration(days: month.weekday - 1));
    final days = List.generate(42, (i) => firstGridDay.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(DateFormat.MMMM(locale).format(month), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final inMonth = day.month == month.month;
                if (!inMonth) return const SizedBox.shrink();

                final today = isSameDate(day, DateTime.now());
                final hasShifts = hasShiftsOn(day);

                return GestureDetector(
                  onTap: () => onDayTap(day),
                  child: Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: today ? Theme.of(context).colorScheme.primaryContainer : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('${day.day}', style: const TextStyle(fontSize: 8)),
                        if (hasShifts)
                          Positioned(
                            bottom: 0,
                            child: Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
