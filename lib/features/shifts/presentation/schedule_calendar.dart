import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/domain/project_model.dart';
import '../domain/shift_model.dart';
import 'calendar_shared.dart';
import 'calendar_view_mode.dart';
import 'month_calendar_view.dart';
import 'time_grid_view.dart';
import 'year_calendar_view.dart';

/// Wraps the four calendar views (day/week/month/year) behind a
/// view-switcher. Week is the default. Each view keeps its own scroll/nav
/// position while hidden, since they're all kept alive in an [IndexedStack]
/// rather than rebuilt on every switch.
class ScheduleCalendar extends StatefulWidget {
  const ScheduleCalendar({
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
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  CalendarViewMode _mode = CalendarViewMode.week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SegmentedButton<CalendarViewMode>(
            segments: [
              ButtonSegment(value: CalendarViewMode.day, label: Text(l10n.dayViewLabel)),
              ButtonSegment(value: CalendarViewMode.week, label: Text(l10n.weekViewLabel)),
              ButtonSegment(value: CalendarViewMode.month, label: Text(l10n.monthViewLabel)),
              ButtonSegment(value: CalendarViewMode.year, label: Text(l10n.yearViewLabel)),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => setState(() => _mode = selection.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _mode.index,
            children: [
              TimeGridView(
                shifts: widget.shifts,
                projects: widget.projects,
                people: widget.people,
                daySpan: 1,
                isOwner: widget.isOwner,
              ),
              TimeGridView(
                shifts: widget.shifts,
                projects: widget.projects,
                people: widget.people,
                daySpan: 7,
                isOwner: widget.isOwner,
              ),
              MonthCalendarView(
                shifts: widget.shifts,
                projects: widget.projects,
                people: widget.people,
                isOwner: widget.isOwner,
              ),
              YearCalendarView(
                shifts: widget.shifts,
                projects: widget.projects,
                people: widget.people,
                isOwner: widget.isOwner,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
