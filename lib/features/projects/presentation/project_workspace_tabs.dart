import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/files/picked_file.dart';
import '../../../core/widgets/attachment_tile.dart';
import '../../../core/config/branding_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../instructions/data/instruction_repository.dart';
import '../../instructions/presentation/add_instruction_screen.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../shifts/domain/shift_model.dart';
import '../../shifts/presentation/add_shift_screen.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../shifts/presentation/schedule_calendar.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/project_task_model.dart';
import '../../tasks/presentation/task_actions.dart';
import '../../tasks/presentation/task_detail_screen.dart';
import '../../tasks/presentation/task_form_screen.dart';
import '../data/project_repository.dart';
import '../domain/project_model.dart';
import 'add_project_screen.dart';
import 'project_people_actions.dart';
import 'project_list_screen.dart' show setProjectArchived;

/// Contents of the tabs on the boss's project screen (see
/// ProjectWorkspaceScreen). Kept apart from the screen shell so each tab
/// stays readable on its own.

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.title, this.trailing});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title!, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Keeps a tab's content at a comfortable reading width on wide screens.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: children,
        ),
      ),
    );
  }
}

// --- Overview ---------------------------------------------------------------

class ProjectOverviewTab extends ConsumerWidget {
  const ProjectOverviewTab({
    super.key,
    required this.companyId,
    required this.project,
    required this.tasks,
    required this.assigned,
  });

  final String companyId;
  final ProjectModel project;
  final List<ProjectTaskModel> tasks;
  final List<ProfileModel> assigned;

  /// A person's actions on this project. Removing is a deliberate two-step
  /// (open the menu, then confirm) so a stray tap can't take someone off.
  void _showMemberMenu(
    BuildContext context,
    WidgetRef ref,
    ProfileModel person,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: person.avatarUrl != null
                    ? NetworkImage(person.avatarUrl!)
                    : null,
                child: person.avatarUrl == null
                    ? Text(initialsOf(person.fullName))
                    : null,
              ),
              title: Text(person.fullName),
              subtitle: person.phone != null && person.phone!.isNotEmpty
                  ? Text(person.phone!)
                  : null,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.removeFromProjectTooltip,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                removePersonFromProject(
                  context,
                  ref,
                  projectId: project.id,
                  person: person,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(locale);

    final notices =
        (ref.watch(projectCompletionNoticeListProvider).valueOrNull ?? const [])
            .where((notice) => notice.projectId == project.id)
            .toList();
    final peopleById = <String, ProfileModel>{
      for (final person in ref.watch(employeeListProvider).valueOrNull ?? [])
        person.id: person,
      for (final person in ref.watch(ownerListProvider).valueOrNull ?? [])
        person.id: person,
    };
    final fileCount =
        (ref
                .watch(projectAttachmentsProvider(project.id))
                .valueOrNull
                ?.length ??
            0) +
        (ref
                .watch(projectTaskAttachmentsProvider(project.id))
                .valueOrNull
                ?.length ??
            0);

    final dates = [
      if (project.startDate != null) dateFormat.format(project.startDate!),
      if (project.endDate != null) dateFormat.format(project.endDate!),
    ].join(' – ');

    return _TabBody(
      children: [
        if (project.isArchived) ...[
          _ArchivedBanner(
            message: l10n.projectArchivedBanner,
            actionLabel: l10n.restoreProjectAction,
            onAction: () => setProjectArchived(context, ref, project, false),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.checklist_outlined,
                value: tasks.length,
                label: l10n.tasksTitle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.people_outline,
                value: assigned.length,
                label: l10n.employeesLabel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.photo_library_outlined,
                value: fileCount,
                label: l10n.galleryLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: l10n.projectTabOverview,
          trailing: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddProjectScreen(
                  companyId: companyId,
                  existingProject: project,
                ),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.editButton),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (project.address != null && project.address!.isNotEmpty)
                _DetailRow(icon: Icons.place_outlined, text: project.address!),
              if (dates.isNotEmpty)
                _DetailRow(icon: Icons.event_outlined, text: dates),
              if (project.description != null &&
                  project.description!.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes_outlined,
                  text: project.description!,
                ),
              if ((project.address == null || project.address!.isEmpty) &&
                  dates.isEmpty &&
                  (project.description == null || project.description!.isEmpty))
                Text(l10n.noGalleryLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '${l10n.assignedEmployeesLabel} (${assigned.length})',
          trailing: project.isArchived
              ? null
              : TextButton.icon(
                  onPressed: () => addPeopleToProject(
                    context,
                    ref,
                    companyId: companyId,
                    projectId: project.id,
                    alreadyOn: {for (final person in assigned) person.id},
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: Text(l10n.addPeopleToProjectButton),
                ),
          child: assigned.isEmpty
              ? Text(
                  l10n.noAssignedEmployeesLabel,
                  style: theme.textTheme.bodySmall,
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    for (final person in assigned)
                      _TeamMemberTile(
                        person: person,
                        onTap: project.isArchived
                            ? null
                            : () => _showMemberMenu(context, ref, person),
                      ),
                  ],
                ),
        ),

        if (notices.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.completionNoticesSectionLabel,
            child: Column(
              children: [
                for (final notice in notices)
                  Row(
                    children: [
                      const Icon(Icons.task_alt_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.completedByLabel(
                            peopleById[notice.employeeId]?.fullName ?? '?',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: l10n.dismissChangeRequestTooltip,
                        onPressed: () async {
                          await ref
                              .read(projectRepositoryProvider)
                              .dismissCompletionNotice(notice.id);
                          ref.invalidate(projectCompletionNoticeListProvider);
                        },
                      ),
                    ],
                  ),
                if (!project.isArchived) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () =>
                          setProjectArchived(context, ref, project, true),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(l10n.archiveProjectAction),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (project.isArchived)
          FilledButton.icon(
            onPressed: () => setProjectArchived(context, ref, project, false),
            icon: const Icon(Icons.unarchive_outlined),
            label: Text(l10n.restoreProjectAction),
          )
        else
          OutlinedButton.icon(
            onPressed: () => setProjectArchived(context, ref, project, true),
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(l10n.archiveProjectAction),
          ),
      ],
    );
  }
}

/// A person on the project as a round photo/initials icon with their first
/// name underneath — compact enough for a team of dozens.
class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.person, required this.onTap});

  final ProfileModel person;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = person.fullName.trim().split(RegExp(r'\s+')).first;
    return Tooltip(
      message: person.fullName,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: person.avatarUrl != null
                    ? NetworkImage(person.avatarUrl!)
                    : null,
                child: person.avatarUrl == null
                    ? Text(
                        initialsOf(person.fullName),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.inventory_2_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.unarchive_outlined),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// --- Schedule ---------------------------------------------------------------

class ProjectScheduleTab extends StatelessWidget {
  const ProjectScheduleTab({
    super.key,
    required this.project,
    required this.tasks,
    required this.shifts,
    required this.people,
  });

  final ProjectModel project;
  final List<ProjectTaskModel> tasks;
  final List<ShiftModel> shifts;
  final List<CalendarPerson> people;

  @override
  Widget build(BuildContext context) {
    return ScheduleCalendar(
      shifts: shifts,
      projects: [project],
      tasks: tasks,
      showProjectBars: false,
      people: people,
      isOwner: true,
    );
  }
}

// --- Tasks ------------------------------------------------------------------

class ProjectTasksTab extends ConsumerStatefulWidget {
  const ProjectTasksTab({
    super.key,
    required this.companyId,
    required this.project,
    required this.tasks,
    required this.shifts,
    required this.peopleById,
  });

  final String companyId;
  final ProjectModel project;

  /// Every task of the project, archived ones included.
  final List<ProjectTaskModel> tasks;
  final List<ShiftModel> shifts;
  final Map<String, ProfileModel> peopleById;

  @override
  ConsumerState<ProjectTasksTab> createState() => _ProjectTasksTabState();
}

class _ProjectTasksTabState extends ConsumerState<ProjectTasksTab> {
  bool _showArchive = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final project = widget.project;
    final tasks = widget.tasks;

    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.checklist_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(l10n.noTasksYet, textAlign: TextAlign.center),
              if (!project.isArchived) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      openAddTask(context, widget.companyId, project),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addTaskTitle),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final active = [
      for (final task in tasks)
        if (!task.isArchived) task,
    ];
    final archived = [
      for (final task in tasks)
        if (task.isArchived) task,
    ];

    final today = DateTime.now();
    int rank(ProjectTaskModel task) => switch (task.phaseOn(today)) {
      TaskPhase.active => 0,
      TaskPhase.upcoming => 1,
      TaskPhase.done => 2,
    };
    final shown = [..._showArchive ? archived : active]
      ..sort((a, b) {
        final byPhase = _showArchive ? 0 : rank(a).compareTo(rank(b));
        return byPhase != 0 ? byPhase : a.startDate.compareTo(b.startDate);
      });

    // Names of the employees who reported each task as done.
    final notices =
        ref.watch(taskCompletionNoticeListProvider).valueOrNull ?? const [];
    List<String> doneBy(ProjectTaskModel task) => [
      for (final notice in notices)
        if (notice.taskId == task.id)
          widget.peopleById[notice.employeeId]?.fullName ?? '?',
    ];

    return _TabBody(
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.checklist_outlined),
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
        const SizedBox(height: 16),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                _showArchive ? l10n.noArchivedTasks : l10n.noActiveTasks,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        for (final task in shown) ...[
          _TaskCard(
            companyId: widget.companyId,
            project: project,
            task: task,
            assigneeIds: task.assigneeIdsFrom(
              widget.shifts,
              ref.watch(taskAssignmentsProvider).valueOrNull ?? const [],
            ),
            peopleById: widget.peopleById,
            doneBy: doneBy(task),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

void openAddTask(BuildContext context, String companyId, ProjectModel project) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) =>
          TaskFormScreen(companyId: companyId, project: project),
    ),
  );
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({
    required this.companyId,
    required this.project,
    required this.task,
    required this.assigneeIds,
    required this.peopleById,
    required this.doneBy,
  });

  final String companyId;
  final ProjectModel project;
  final ProjectTaskModel task;
  final Set<String> assigneeIds;
  final Map<String, ProfileModel> peopleById;

  /// Names of employees who reported this task as done.
  final List<String> doneBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd(locale);

    final phase = task.phaseOn(DateTime.now());
    final (phaseLabel, phaseColor) = task.isArchived
        ? (l10n.archivedBadgeLabel, Colors.grey)
        : switch (phase) {
            TaskPhase.active => (
              l10n.taskPhaseActive,
              BrandingConfig.accentColor,
            ),
            TaskPhase.upcoming => (
              l10n.taskPhaseUpcoming,
              const Color(0xFF1E88E5),
            ),
            TaskPhase.done => (l10n.taskPhaseDone, Colors.grey),
          };

    final dateLabel = task.startDate == task.endDate
        ? dateFormat.format(task.startDate)
        : '${dateFormat.format(task.startDate)} – ${dateFormat.format(task.endDate)}';
    final people = [
      for (final id in assigneeIds)
        if (peopleById[id] != null) peopleById[id]!,
    ];

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(task: task, isOwner: true),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      phaseLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: phaseColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _TaskMeta(
                    icon: Icons.event_outlined,
                    text: '$dateLabel · ${l10n.taskDaysCount(task.dayCount)}',
                  ),
                  _TaskMeta(
                    icon: Icons.schedule_outlined,
                    text: task.hasHours
                        ? '${formatTime(task.startTime!)}–${formatTime(task.endTime!)}'
                        : l10n.taskWholeDayLabel,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (doneBy.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: BrandingConfig.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.task_alt,
                        size: 20,
                        color: BrandingConfig.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.taskDoneByLabel(doneBy.join(', ')),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () =>
                            setTaskArchived(context, ref, task, true),
                        child: Text(l10n.archiveButtonShort),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: people.isEmpty
                        ? Text(
                            l10n.taskNoPeopleShort,
                            style: theme.textTheme.bodySmall,
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final person in people.take(6))
                                Tooltip(
                                  message: person.fullName,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundImage: person.avatarUrl != null
                                        ? NetworkImage(person.avatarUrl!)
                                        : null,
                                    child: person.avatarUrl == null
                                        ? Text(
                                            initialsOf(person.fullName),
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              if (people.length > 6)
                                Text(
                                  '+${people.length - 6}',
                                  style: theme.textTheme.labelSmall,
                                ),
                            ],
                          ),
                  ),
                  if (task.isArchived) ...[
                    if (!project.isArchived)
                      TextButton.icon(
                        onPressed: () =>
                            setTaskArchived(context, ref, task, false),
                        icon: const Icon(Icons.unarchive_outlined, size: 18),
                        label: Text(l10n.restoreButtonShort),
                      ),
                  ] else ...[
                    if (!project.isArchived)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AddShiftScreen(
                              companyId: companyId,
                              preselectedProjectId: project.id,
                              preselectedTaskId: task.id,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.addShiftToTaskButton),
                      ),
                    IconButton(
                      tooltip: l10n.archiveTaskAction,
                      onPressed: () =>
                          setTaskArchived(context, ref, task, true),
                      icon: const Icon(Icons.inventory_2_outlined, size: 20),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskMeta extends StatelessWidget {
  const _TaskMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

// --- Photos & notes ---------------------------------------------------------

class ProjectFilesTab extends ConsumerStatefulWidget {
  const ProjectFilesTab({
    super.key,
    required this.companyId,
    required this.project,
    required this.tasks,
    required this.assigned,
  });

  final String companyId;
  final ProjectModel project;
  final List<ProjectTaskModel> tasks;
  final List<ProfileModel> assigned;

  @override
  ConsumerState<ProjectFilesTab> createState() => _ProjectFilesTabState();
}

class _ProjectFilesTabState extends ConsumerState<ProjectFilesTab> {
  bool _uploading = false;

  Future<void> _addFile() async {
    final picked = await pickPhotoOrFile(context);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      await ref
          .read(projectRepositoryProvider)
          .uploadAttachment(
            companyId: widget.companyId,
            projectId: widget.project.id,
            fileName: picked.fileName,
            bytes: picked.bytes,
          );
      ref.invalidate(projectAttachmentsProvider(widget.project.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _addInstruction() {
    final employees = widget.assigned.isNotEmpty
        ? widget.assigned
        : (ref.read(employeeListProvider).valueOrNull ?? const []);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddInstructionScreen(
          companyId: widget.companyId,
          projectId: widget.project.id,
          employeeOptions: employees,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    final projectFiles =
        ref.watch(projectAttachmentsProvider(widget.project.id)).valueOrNull ??
        const [];
    final taskFiles =
        ref
            .watch(projectTaskAttachmentsProvider(widget.project.id))
            .valueOrNull ??
        const [];
    final instructions =
        (ref.watch(instructionListProvider).valueOrNull ?? const [])
            .where((i) => i.projectId == widget.project.id)
            .toList();

    final peopleById = <String, ProfileModel>{
      for (final person in ref.watch(employeeListProvider).valueOrNull ?? [])
        person.id: person,
      for (final person in ref.watch(ownerListProvider).valueOrNull ?? [])
        person.id: person,
    };
    final taskTitles = {for (final task in widget.tasks) task.id: task.title};

    String caption(
      String? uploadedBy,
      DateTime createdAt, {
      String? taskTitle,
    }) {
      final parts = <String>[
        ?(taskTitle == null ? null : l10n.fromTaskLabel(taskTitle)),
        ?(uploadedBy == null ? null : peopleById[uploadedBy]?.fullName),
        DateFormat.yMMMd(locale).format(createdAt),
      ];
      return parts.join(' · ');
    }

    final items = <({DateTime at, Widget tile})>[
      for (final file in projectFiles)
        (
          at: file.createdAt,
          tile: AttachmentTile(
            isImage: file.isImage,
            fileName: file.fileName,
            urlProvider: projectAttachmentSignedUrlProvider(file.storagePath),
            caption: caption(file.uploadedBy, file.createdAt),
            size: 112,
          ),
        ),
      for (final file in taskFiles)
        (
          at: file.createdAt,
          tile: AttachmentTile(
            isImage: file.isImage,
            fileName: file.fileName,
            urlProvider: taskAttachmentSignedUrlProvider(file.storagePath),
            caption: caption(
              file.uploadedBy,
              file.createdAt,
              taskTitle: taskTitles[file.taskId],
            ),
            size: 112,
          ),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return _TabBody(
      children: [
        _SectionCard(
          title: l10n.galleryLabel,
          trailing: OutlinedButton.icon(
            onPressed: _uploading ? null : _addFile,
            icon: _uploading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(l10n.addPhotoOrFileButton),
          ),
          child: items.isEmpty
              ? Text(l10n.noGalleryLabel, style: theme.textTheme.bodySmall)
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final item in items) item.tile],
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: l10n.instructionsTitle,
          trailing: OutlinedButton.icon(
            onPressed: _addInstruction,
            icon: const Icon(Icons.add),
            label: Text(l10n.addInstructionTooltip),
          ),
          child: instructions.isEmpty
              ? Text(
                  l10n.noProjectInstructionsYet,
                  style: theme.textTheme.bodySmall,
                )
              : Column(
                  children: [
                    for (final instruction in instructions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(instruction.title),
                        subtitle: Text(
                          [
                            DateFormat.yMMMd(
                              locale,
                            ).format(instruction.createdAt),
                            ?(instruction.employeeId == null
                                ? null
                                : peopleById[instruction.employeeId]?.fullName),
                          ].join(' · '),
                        ),
                        onTap: () =>
                            showInstructionDetails(context, instruction),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
