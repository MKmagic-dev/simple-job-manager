import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/data/project_repository.dart';
import 'calendar_shared.dart';
import 'schedule_screen.dart';

/// Lets the boss pick which schedule to open: the whole company's (every
/// shift, same as before projects had their own schedules), or a single
/// project's (only shifts assigned to it).
class ProjectScheduleSelectScreen extends ConsumerWidget {
  const ProjectScheduleSelectScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.selectProjectScheduleTitle)),
      body: projectsAsync.when(
        data: (projects) {
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(l10n.allProjectsOption),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ScheduleScreen(companyId: companyId),
                    ),
                  );
                },
              ),
              if (projects.isNotEmpty) const Divider(height: 1),
              for (final project in projects)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorForProject(project),
                    child: Text(
                      initialsOf(project.name),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text(project.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ScheduleScreen(
                          companyId: companyId,
                          project: project,
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}
