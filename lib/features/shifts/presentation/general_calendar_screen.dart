import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/presentation/project_workspace_screen.dart';
import '../../projects/presentation/projects_timeline.dart';

/// The boss's overview calendar: every project on a timeline (one row per
/// project, a colored bar across the days it runs) — no shifts, people or
/// tasks; those live in each project's own calendar. Tap a project to open
/// it.
class GeneralCalendarScreen extends ConsumerWidget {
  const GeneralCalendarScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: projectsAsync.when(
        data: (projects) => ProjectsTimeline(
          projects: [
            for (final project in projects)
              if (!project.isArchived) project,
          ],
          onProjectTap: (project) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProjectWorkspaceScreen(
                  companyId: companyId,
                  project: project,
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}
