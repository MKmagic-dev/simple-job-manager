import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../tasks/data/task_repository.dart';
import '../data/project_repository.dart';
import '../domain/project_model.dart';
import 'add_project_screen.dart';
import 'project_workspace_screen.dart';

/// The boss's project list: one card per project with its main photo, dates,
/// task count and any "employee says it's done" notices.
class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key, required this.companyId});

  final String companyId;

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    ProjectModel project,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProjectTooltip),
        content: Text(l10n.deleteProjectConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(projectRepositoryProvider).deleteProject(project.id);
    ref.invalidate(projectListProvider);
    ref.invalidate(taskListProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.projectDeletedSuccess)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);
    final notices =
        ref.watch(projectCompletionNoticeListProvider).valueOrNull ?? const [];
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: columns == 1 ? 1.45 : 1.25,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _ProjectCard(
                      project: project,
                      taskCount: tasks
                          .where((task) => task.projectId == project.id)
                          .length,
                      noticeCount: notices
                          .where((n) => n.projectId == project.id)
                          .length,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProjectWorkspaceScreen(
                              companyId: companyId,
                              project: project,
                            ),
                          ),
                        );
                      },
                      onDelete: () => _deleteProject(context, ref, project),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddProjectScreen(companyId: companyId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.addProjectTooltip),
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({
    required this.project,
    required this.taskCount,
    required this.noticeCount,
    required this.onTap,
    required this.onDelete,
  });

  final ProjectModel project;
  final int taskCount;
  final int noticeCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final color = colorForProject(project);

    final dateFormat = DateFormat.yMMMd(locale);
    final dates = [
      if (project.startDate != null) dateFormat.format(project.startDate!),
      if (project.endDate != null) dateFormat.format(project.endDate!),
    ].join(' – ');

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
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black38,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: l10n.deleteProjectTooltip,
                          onPressed: onDelete,
                        ),
                      ),
                    ),
                    if (noticeCount > 0)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Badge(
                          label: Text('$noticeCount'),
                          child: const Icon(
                            Icons.task_alt,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 4,
                      child: ColoredBox(color: color),
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
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (dates.isNotEmpty)
                          _MetaItem(icon: Icons.event_outlined, text: dates),
                        _MetaItem(
                          icon: Icons.checklist_outlined,
                          text: l10n.tasksCountLabel(taskCount),
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

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The project's main photo, or — when it has none — a solid block in the
/// project's own color with its initials, so every card still looks
/// intentional.
class ProjectCover extends ConsumerWidget {
  const ProjectCover({super.key, required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorForProject(project);

    Widget placeholder() => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.65)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initialsOf(project.name),
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: color.computeLuminance() > 0.5
              ? Colors.black54
              : Colors.white70,
        ),
      ),
    );

    final path = project.coverPath;
    if (path == null) return placeholder();

    return ref
        .watch(projectAttachmentSignedUrlProvider(path))
        .when(
          data: (url) => Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => placeholder(),
          ),
          loading: placeholder,
          error: (error, stackTrace) => placeholder(),
        );
  }
}
