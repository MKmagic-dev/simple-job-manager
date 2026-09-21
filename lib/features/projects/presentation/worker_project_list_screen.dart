import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/project_repository.dart';
import 'project_detail_screen.dart';
import 'project_list_screen.dart' show ProjectCover;

/// A worker's read-only view of the projects they're assigned to (RLS
/// already restricts projectListProvider to those — see
/// projects_employee_select). No add/edit/delete here; tapping a project
/// opens its detail screen in employee mode.
class WorkerProjectListScreen extends ConsumerWidget {
  const WorkerProjectListScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectsTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(projectListProvider.future),
        child: projectsAsync.when(
          data: (projects) {
            if (projects.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(child: Text(l10n.noProjectsYet)),
                  ),
                ),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: projects.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final project = projects[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: ProjectCover(project: project),
                    ),
                  ),
                  title: Text(project.name),
                  subtitle: project.address != null
                      ? Text(project.address!)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailScreen(
                          companyId: companyId,
                          project: project,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}
