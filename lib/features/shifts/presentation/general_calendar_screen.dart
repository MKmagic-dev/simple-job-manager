import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/presentation/project_workspace_screen.dart';
import 'calendar_shared.dart';
import 'schedule_calendar.dart';

/// The boss's overview calendar: projects only — no shifts, people or
/// tasks. Each project is a colored bar across the days it runs; tap one to
/// open it. A row of project chips above lets them hide or show projects
/// (all on by default). Shifts and tasks live inside each project's own
/// calendar.
class GeneralCalendarScreen extends ConsumerStatefulWidget {
  const GeneralCalendarScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<GeneralCalendarScreen> createState() =>
      _GeneralCalendarScreenState();
}

class _GeneralCalendarScreenState extends ConsumerState<GeneralCalendarScreen> {
  final _hiddenProjectIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);
    final projects = projectsAsync.valueOrNull ?? const [];
    final visibleProjects = projects
        .where((p) => !_hiddenProjectIds.contains(p.id))
        .toList();
    final allVisible = _hiddenProjectIds.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(l10n.allProjectsOption),
                    selected: allVisible,
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      if (allVisible) {
                        _hiddenProjectIds.addAll(projects.map((p) => p.id));
                      } else {
                        _hiddenProjectIds.clear();
                      }
                    }),
                  ),
                ),
                for (final project in projects)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: colorForProject(project),
                      ),
                      label: Text(project.name),
                      selected: !_hiddenProjectIds.contains(project.id),
                      showCheckmark: false,
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _hiddenProjectIds.remove(project.id);
                        } else {
                          _hiddenProjectIds.add(project.id);
                        }
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: projectsAsync.isLoading && projects.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ScheduleCalendar(
                    shifts: const [],
                    projects: visibleProjects,
                    projectsOnly: true,
                    isOwner: true,
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
                  ),
          ),
        ],
      ),
    );
  }
}
