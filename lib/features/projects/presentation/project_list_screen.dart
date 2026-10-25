import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../tasks/data/task_repository.dart';
import '../data/project_repository.dart';
import '../domain/project_model.dart';
import 'add_project_screen.dart';
import 'project_workspace_screen.dart';

/// The boss's project list: one card per project with its main photo, dates,
/// task count and any "employee says it's done" notices. Split into Active
/// and Archive — archived projects keep all their data but stay out of the
/// way (calendar, pickers, employees' screens).
class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  bool _showArchive = false;

  Future<void> _deleteProject(ProjectModel project) async {
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

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.projectDeletedSuccess)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);
    final projectNotices =
        ref.watch(projectCompletionNoticeListProvider).valueOrNull ?? const [];
    final taskNotices =
        ref.watch(taskCompletionNoticeListProvider).valueOrNull ?? const [];
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
          data: (allProjects) {
            if (allProjects.isEmpty) {
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

            final active = [
              for (final p in allProjects)
                if (!p.isArchived) p,
            ];
            final archived = [
              for (final p in allProjects)
                if (p.isArchived) p,
            ];
            final projects = _showArchive ? archived : active;
            final taskProjectById = {
              for (final task in tasks) task.id: task.projectId,
            };

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.work_outline),
                        label: Text(l10n.activeTabLabel(active.length)),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(l10n.archiveTabLabel(archived.length)),
                      ),
                    ],
                    selected: {_showArchive},
                    onSelectionChanged: (value) =>
                        setState(() => _showArchive = value.first),
                  ),
                ),
                Expanded(
                  child: projects.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(48),
                              child: Center(
                                child: Text(
                                  _showArchive
                                      ? l10n.noArchivedProjects
                                      : l10n.noActiveProjects,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1100
                                ? 3
                                : constraints.maxWidth >= 640
                                ? 2
                                : 1;
                            return GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                96,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: columns == 1
                                        ? 1.45
                                        : 1.25,
                                  ),
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                final project = projects[index];
                                return _ProjectCard(
                                  project: project,
                                  taskCount: tasks
                                      .where(
                                        (task) =>
                                            task.projectId == project.id &&
                                            !task.isArchived,
                                      )
                                      .length,
                                  noticeCount:
                                      projectNotices
                                          .where(
                                            (n) => n.projectId == project.id,
                                          )
                                          .length +
                                      taskNotices
                                          .where(
                                            (n) =>
                                                taskProjectById[n.taskId] ==
                                                project.id,
                                          )
                                          .length,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProjectWorkspaceScreen(
                                              companyId: widget.companyId,
                                              project: project,
                                            ),
                                      ),
                                    );
                                  },
                                  onToggleArchive: () => setProjectArchived(
                                    context,
                                    ref,
                                    project,
                                    !project.isArchived,
                                  ),
                                  onDelete: () => _deleteProject(project),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text(friendlyError(context, error))),
        ),
      ),
      floatingActionButton: _showArchive
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AddProjectScreen(companyId: widget.companyId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.addProjectTooltip),
            ),
    );
  }
}

/// Confirms (when archiving) and applies archive/restore for a project, then
/// refreshes everything that lists projects. Shared by the list cards and the
/// project's own screen. Returns whether it went through.
Future<bool> setProjectArchived(
  BuildContext context,
  WidgetRef ref,
  ProjectModel project,
  bool archived,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  if (archived) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archiveProjectAction),
        content: Text(l10n.archiveProjectConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.archiveButtonShort),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }

  try {
    await ref
        .read(projectRepositoryProvider)
        .setArchived(project.id, archived: archived);
    ref.invalidate(projectListProvider);
    ref.invalidate(projectCompletionNoticeListProvider);
    ref.invalidate(taskCompletionNoticeListProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archived ? l10n.projectArchivedSuccess : l10n.projectRestoredSuccess,
        ),
      ),
    );
    return true;
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(friendlyErrorText(l10n, error))),
    );
    return false;
  }
}

enum _CardAction { toggleArchive, delete }

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.taskCount,
    required this.noticeCount,
    required this.onTap,
    required this.onToggleArchive,
    required this.onDelete,
  });

  final ProjectModel project;
  final int taskCount;
  final int noticeCount;
  final VoidCallback onTap;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final color = colorForProject(project);
    final archived = project.isArchived;

    final dateFormat = DateFormat.yMMMd(locale);
    final dates = [
      if (project.startDate != null) dateFormat.format(project.startDate!),
      if (project.endDate != null) dateFormat.format(project.endDate!),
    ].join(' – ');

    // Archived cards are shown desaturated so they read as "put away".
    const greyscale = ColorFilter.matrix(<double>[
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);

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
                    archived
                        ? ColorFiltered(
                            colorFilter: greyscale,
                            child: ProjectCover(project: project),
                          )
                        : ProjectCover(project: project),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black38,
                        shape: const CircleBorder(),
                        child: PopupMenuButton<_CardAction>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 20,
                          ),
                          onSelected: (action) => switch (action) {
                            _CardAction.toggleArchive => onToggleArchive(),
                            _CardAction.delete => onDelete(),
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _CardAction.toggleArchive,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  archived
                                      ? Icons.unarchive_outlined
                                      : Icons.inventory_2_outlined,
                                ),
                                title: Text(
                                  archived
                                      ? l10n.restoreProjectAction
                                      : l10n.archiveProjectAction,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: _CardAction.delete,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.delete_outline),
                                title: Text(l10n.deleteProjectTooltip),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (archived)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.archivedBadgeLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else if (noticeCount > 0)
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
                      child: ColoredBox(color: archived ? Colors.grey : color),
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
                        color: archived
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
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
