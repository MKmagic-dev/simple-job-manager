import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../profile/domain/profile_model.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_model.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../tasks/data/task_repository.dart';
import '../../projects/presentation/project_people_actions.dart';
import '../data/employee_repository.dart';
import 'employee_list_screen.dart' show MemberAvatar, RoleChip;

/// Shown when tapping someone in the team list: who they are, how to reach
/// them, and their next shifts. Only offers "remove from team" for
/// role=employee rows — removing a co-boss isn't something this screen does
/// (that's the separate demote flow on the list itself), and there's no RLS
/// policy letting an owner delete another owner's row here.
class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.member,
    required this.canRemove,
  });

  final ProfileModel member;
  final bool canRemove;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFromTeamTooltip),
        content: Text(l10n.removeFromTeamConfirmMessage(member.fullName)),
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

    try {
      await ref.read(employeeRepositoryProvider).deleteEmployee(member.id);
      ref.invalidate(employeeListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.employeeRemovedSuccess)));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
      }
    }
  }

  /// Puts this person on one more (active) project.
  Future<void> _addToProject(
    BuildContext context,
    WidgetRef ref,
    List<ProjectModel> options,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (options.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noProjectsToAddTo)));
      return;
    }
    final project = await showDialog<ProjectModel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.addToProjectTitle),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option),
              child: Text(option.name),
            ),
        ],
      ),
    );
    if (project == null) return;

    try {
      await ref
          .read(projectRepositoryProvider)
          .addMembers(
            companyId: project.companyId,
            projectId: project.id,
            employeeIds: [member.id],
          );
      ref.invalidate(projectMembersProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.peopleAddedToProject(1))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorText(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final isOwner = member.role == UserRole.boss;
    final hasPhone = member.phone != null && member.phone!.isNotEmpty;

    final today = dateOnly(DateTime.now());
    final upcoming =
        (ref.watch(shiftListProvider).valueOrNull ?? const [])
            .where(
              (shift) =>
                  shift.employeeId == member.id &&
                  !shift.workDate.isBefore(today),
            )
            .toList()
          ..sort((a, b) {
            final byDate = a.workDate.compareTo(b.workDate);
            return byDate != 0
                ? byDate
                : (a.startTime.hour * 60 + a.startTime.minute).compareTo(
                    b.startTime.hour * 60 + b.startTime.minute,
                  );
          });
    final projects = ref.watch(projectListProvider).valueOrNull ?? const [];
    final tasks = ref.watch(taskListProvider).valueOrNull ?? const [];
    final myProjectIds = {
      for (final m in ref.watch(projectMembersProvider).valueOrNull ?? const [])
        if (m.employeeId == member.id) m.projectId,
    };
    final myProjects = [
      for (final project in projects)
        if (myProjectIds.contains(project.id) && !project.isArchived) project,
    ];
    final projectsToAdd = [
      for (final project in projects)
        if (!myProjectIds.contains(project.id) && !project.isArchived) project,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.memberDetailsTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      MemberAvatar(member: member, radius: 44),
                      const SizedBox(height: 14),
                      Text(
                        member.fullName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RoleChip(isOwner: isOwner),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(hasPhone ? member.phone! : '—'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        l10n.projectsTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _addToProject(context, ref, projectsToAdd),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.addToProjectButton),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (myProjects.isEmpty)
                    Text(
                      l10n.noProjectsForPerson,
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final project in myProjects)
                          InputChip(
                            avatar: CircleAvatar(
                              radius: 6,
                              backgroundColor: colorForProject(project),
                            ),
                            label: Text(project.name),
                            deleteButtonTooltipMessage:
                                l10n.removeFromProjectTooltip,
                            onDeleted: () => removePersonFromProject(
                              context,
                              ref,
                              projectId: project.id,
                              person: member,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.upcomingShiftsTitle,

                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  if (upcoming.isEmpty)
                    Text(
                      l10n.noUpcomingShiftsLabel,
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    for (final shift in upcoming.take(6))
                      _ShiftRow(
                        dateLabel: DateFormat.MMMEd(
                          locale,
                        ).format(shift.workDate),
                        hours:
                            '${formatTime(shift.startTime)}–${formatTime(shift.endTime)}',
                        projectName: projects
                            .where((p) => p.id == shift.projectId)
                            .map((p) => p.name)
                            .firstOrNull,
                        projectColor: projects
                            .where((p) => p.id == shift.projectId)
                            .map(colorForProject)
                            .firstOrNull,
                        taskTitle: tasks
                            .where((t) => t.id == shift.taskId)
                            .map((t) => t.title)
                            .firstOrNull,
                      ),
                ],
                if (canRemove) ...[
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _confirmRemove(context, ref),
                    icon: const Icon(Icons.person_remove_outlined),
                    label: Text(l10n.removeFromTeamTooltip),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({
    required this.dateLabel,
    required this.hours,
    required this.projectName,
    required this.projectColor,
    required this.taskTitle,
  });

  final String dateLabel;
  final String hours;
  final String? projectName;
  final Color? projectColor;
  final String? taskTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = [?projectName, ?taskTitle].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: projectColor ?? theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateLabel · $hours',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
