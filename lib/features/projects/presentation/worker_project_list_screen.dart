import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../tasks/data/task_repository.dart';
import '../data/project_repository.dart';
import '../domain/project_model.dart';
import 'project_detail_screen.dart';
import 'project_list_screen.dart' show ProjectCover;

/// A worker's read-only view of the projects they're assigned to (RLS
/// already restricts projectListProvider to those — see
/// projects_employee_select): one card per project with its main photo,
/// address, dates and how many of their tasks are in it. No add/edit/delete;
/// tapping a project opens its detail screen in employee mode.
class WorkerProjectListScreen extends ConsumerWidget {
  const WorkerProjectListScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);
    final tasks = ref.watch(taskListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectsTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(taskListProvider);
          ref.invalidate(projectListProvider);
          await ref.read(projectListProvider.future);
        },
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

            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 640
                    ? 2
                    : 1;
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: columns == 1 ? 1.45 : 1.25,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _WorkerProjectCard(
                      project: project,
                      taskCount: tasks
                          .where((task) => task.projectId == project.id)
                          .length,
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
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}

class _WorkerProjectCard extends StatelessWidget {
  const _WorkerProjectCard({
    required this.project,
    required this.taskCount,
    required this.onTap,
  });

  final ProjectModel project;
  final int taskCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final dateFormat = DateFormat.yMMMd(locale);
    final dates = [
      if (project.startDate != null) dateFormat.format(project.startDate!),
      if (project.endDate != null) dateFormat.format(project.endDate!),
    ].join(' – ');

    Widget meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProjectCover(project: project),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 4,
                      child: ColoredBox(color: colorForProject(project)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (project.address != null &&
                        project.address!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        project.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (dates.isNotEmpty) meta(Icons.event_outlined, dates),
                        meta(
                          Icons.checklist_outlined,
                          l10n.tasksCountLabel(taskCount),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
