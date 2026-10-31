import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../calendar_events/domain/calendar_event_model.dart';
import '../../projects/domain/project_model.dart';
import '../../tasks/domain/project_task_model.dart';
import '../../tasks/domain/task_assignment_model.dart';
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
///
/// [tasks] are date-range items without an hour of day — shown as bars
/// above the hour grid (day/week) and as chips in the month cells. Set
/// [showProjectBars] to false on a single project's own calendar.
class ScheduleCalendar extends StatefulWidget {
  const ScheduleCalendar({
    super.key,
    required this.shifts,
    required this.projects,
    this.tasks = const [],
    this.taskAssignments = const [],
    this.separateDayAndWeek = false,
    this.showProjectBars = true,
    this.people = const [],
    this.isOwner = false,
    this.events = const [],
    this.onAddEvent,
    this.onEventTap,
    this.initialMode = CalendarViewMode.week,
  });

  final List<ShiftModel> shifts;
  final List<ProjectModel> projects;
  final List<ProjectTaskModel> tasks;

  /// Who is assigned to which task; lets the people legend hide tasks too.
  final List<TaskAssignmentModel> taskAssignments;

  /// A project's calendar: day = hour grid only, week = task bars only.
  final bool separateDayAndWeek;
  final bool showProjectBars;
  final List<CalendarPerson> people;
  final bool isOwner;

  /// Personal calendar events/reminders. Tapping one calls [onEventTap];
  /// [onAddEvent] (given a day) makes the day sheet offer "add event".
  final List<CalendarEventModel> events;
  final ValueChanged<DateTime>? onAddEvent;
  final ValueChanged<CalendarEventModel>? onEventTap;

  /// The view shown first (week by default).
  final CalendarViewMode initialMode;

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  late CalendarViewMode _mode = widget.initialMode;

  /// The date every view is looking at. Switching between day / week / month /
  /// year keeps it, so a task seen in the month is still in view in the week.
  DateTime _focus = dateOnly(DateTime.now());

  void _setFocus(DateTime date) => setState(() => _focus = dateOnly(date));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SegmentedButton<CalendarViewMode>(
            // No check mark: on a phone it squeezed "Tydzień" onto two lines.
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: CalendarViewMode.day,
                label: Text(l10n.dayViewLabel),
              ),
              ButtonSegment(
                value: CalendarViewMode.week,
                label: Text(l10n.weekViewLabel),
              ),
              ButtonSegment(
                value: CalendarViewMode.month,
                label: Text(l10n.monthViewLabel),
              ),
              ButtonSegment(
                value: CalendarViewMode.year,
                label: Text(l10n.yearViewLabel),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _mode.index,
            children: [
              TimeGridView(
                shifts: widget.shifts,
                projects: widget.projects,
                tasks: widget.tasks,
                taskAssignments: widget.taskAssignments,
                separateDayAndWeek: widget.separateDayAndWeek,
                showProjectBars: widget.showProjectBars,
                people: widget.people,
                daySpan: 1,
                focusDate: _focus,
                onFocusChanged: _setFocus,
                isOwner: widget.isOwner,
                events: widget.events,
                onEventTap: widget.onEventTap,
              ),
              TimeGridView(
                shifts: widget.shifts,
                projects: widget.projects,
                tasks: widget.tasks,
                taskAssignments: widget.taskAssignments,
                separateDayAndWeek: widget.separateDayAndWeek,
                showProjectBars: widget.showProjectBars,
                people: widget.people,
                daySpan: 7,
                focusDate: _focus,
                onFocusChanged: _setFocus,
                isOwner: widget.isOwner,
                events: widget.events,
                onEventTap: widget.onEventTap,
              ),
              MonthCalendarView(
                focusDate: _focus,
                onFocusChanged: _setFocus,
                shifts: widget.shifts,
                projects: widget.projects,
                tasks: widget.tasks,
                taskAssignments: widget.taskAssignments,
                showProjectBars: widget.showProjectBars,
                people: widget.people,
                isOwner: widget.isOwner,
                events: widget.events,
                onAddEvent: widget.onAddEvent,
                onEventTap: widget.onEventTap,
              ),
              YearCalendarView(
                focusDate: _focus,
                onFocusChanged: _setFocus,
                shifts: widget.shifts,
                projects: widget.projects,
                tasks: widget.tasks,
                events: widget.events,
                showProjectBars: widget.showProjectBars,
                people: widget.people,
                isOwner: widget.isOwner,
                onAddEvent: widget.onAddEvent,
                onEventTap: widget.onEventTap,
                // Tapping a month's name jumps to that month.
                onOpenMonth: (month) => setState(() {
                  _focus = dateOnly(month);
                  _mode = CalendarViewMode.month;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
