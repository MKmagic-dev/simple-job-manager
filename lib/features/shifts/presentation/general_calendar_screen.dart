import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../calendar_events/data/calendar_event_repository.dart';
import '../../calendar_events/presentation/event_form_screen.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/presentation/project_workspace_screen.dart';
import '../../projects/presentation/projects_timeline.dart';
import 'calendar_view_mode.dart';
import 'schedule_calendar.dart';

/// The boss's overview calendar, in two modes:
///  - Calendar: a normal day/week/month/year calendar with the boss's own
///    events and reminders (add them with the + button or from a tapped day)
///    and, while there are only a few, the projects' colored bars;
///  - Project timeline: one row per project with a bar across its dates —
///    the view that stays readable with dozens of projects. Tap a project to
///    open it.
/// No shifts or people here; those live in each project's own calendar.
class GeneralCalendarScreen extends ConsumerStatefulWidget {
  const GeneralCalendarScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<GeneralCalendarScreen> createState() =>
      _GeneralCalendarScreenState();
}

class _GeneralCalendarScreenState extends ConsumerState<GeneralCalendarScreen> {
  /// Project bars on the day/week/month grids stop being useful past this
  /// many projects — the timeline mode is for that.
  static const _maxProjectBars = 5;

  bool _timeline = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);
    final events = ref.watch(calendarEventListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: projectsAsync.when(
        data: (allProjects) {
          final projects = [
            for (final project in allProjects)
              if (!project.isArchived) project,
          ];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(l10n.calendarModeCalendar),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.view_timeline_outlined),
                      label: Text(l10n.calendarModeProjects),
                    ),
                  ],
                  selected: {_timeline},
                  onSelectionChanged: (value) =>
                      setState(() => _timeline = value.first),
                ),
              ),
              Expanded(
                child: _timeline
                    ? ProjectsTimeline(
                        projects: projects,
                        onProjectTap: (project) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProjectWorkspaceScreen(
                                companyId: widget.companyId,
                                project: project,
                              ),
                            ),
                          );
                        },
                      )
                    : ScheduleCalendar(
                        shifts: const [],
                        projects: projects,
                        showProjectBars: projects.length <= _maxProjectBars,
                        isOwner: true,
                        events: events,
                        initialMode: CalendarViewMode.month,
                        onAddEvent: (day) => openEventForm(
                          context,
                          companyId: widget.companyId,
                          initialDate: day,
                        ),
                        onEventTap: (event) => openEventForm(
                          context,
                          companyId: widget.companyId,
                          existing: event,
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(friendlyError(context, error))),
      ),
      floatingActionButton: _timeline
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  openEventForm(context, companyId: widget.companyId),
              icon: const Icon(Icons.add),
              label: Text(l10n.addEventButton),
            ),
    );
  }
}
