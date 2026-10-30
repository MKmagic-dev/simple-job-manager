import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/files/profile_photo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../profile/data/profile_repository.dart';
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

  /// The boss picks a new profile photo for this person.
  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await pickProfilePhoto();
    if (picked == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatarFor(
            userId: member.id,
            bytes: picked.bytes,
            fileExtension: picked.extension,
          );
      ref.invalidate(employeeListProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.personPhotoUpdatedSuccess)),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorText(l10n, error))),
      );
    }
  }

  /// Edit this person's name and phone. Only the admin can; employees edit
  /// nothing.
  Future<void> _editDetails(
    BuildContext context,
    WidgetRef ref,
    ProfileModel person,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: person.fullName);
    final phoneController = TextEditingController(text: person.phone ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editPersonTitle),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l10n.fullNameLabel),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.fullNameRequiredError
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.phoneLabel,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    nameController.dispose();
    phoneController.dispose();
    if (saved != true) return;

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfileFor(userId: person.id, fullName: name, phone: phone);
      ref.invalidate(employeeListProvider);
      ref.invalidate(ownerListProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.personUpdatedSuccess)),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorText(l10n, error))),
      );
    }
  }

  /// Makes this person an administrator of [project] only (or an ordinary
  /// member of it again), after a confirmation that says exactly what changes.
  Future<void> _setProjectAdmin(
    BuildContext context,
    WidgetRef ref,
    ProjectModel project,
    bool makeAdmin,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          makeAdmin
              ? l10n.grantProjectAdminTitle
              : l10n.revokeProjectAdminTitle,
        ),
        content: Text(
          makeAdmin
              ? l10n.grantProjectAdminMessage(member.fullName, project.name)
              : l10n.revokeProjectAdminMessage(member.fullName, project.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(projectRepositoryProvider)
          .setManager(
            projectId: project.id,
            employeeId: member.id,
            isManager: makeAdmin,
          );
      ref.invalidate(projectMembersProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            makeAdmin ? l10n.projectAdminGranted : l10n.projectAdminRevoked,
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorText(l10n, error))),
      );
    }
  }

  /// Promotes to / demotes from full administrator of the whole team. A
  /// deliberately heavy step: the boss has to type the person's name, so it
  /// can't happen by a stray tap.
  Future<void> _setCompanyAdmin(
    BuildContext context,
    WidgetRef ref,
    bool makeAdmin,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final matches =
              controller.text.trim().toLowerCase() ==
              member.fullName.trim().toLowerCase();
          return AlertDialog(
            title: Text(
              makeAdmin
                  ? l10n.promoteToOwnerTooltip
                  : l10n.demoteToEmployeeTooltip,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  makeAdmin
                      ? l10n.promoteToOwnerConfirmMessage(member.fullName)
                      : l10n.demoteToEmployeeConfirmMessage(member.fullName),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.confirmTypeNameLabel,
                    helperText: member.fullName,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancelButton),
              ),
              FilledButton(
                onPressed: matches
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(l10n.confirmButton),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (confirmed != true) return;

    try {
      await ref
          .read(employeeRepositoryProvider)
          .setOwnerRole(member.id, isOwner: makeAdmin);
      ref.invalidate(employeeListProvider);
      ref.invalidate(ownerListProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            makeAdmin ? l10n.companyAdminGranted : l10n.companyAdminRevoked,
          ),
        ),
      );
      // The person moved to the other group, so this page is stale.
      navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorText(l10n, error))),
      );
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
    // The latest copy of this person (the one passed in can be stale once a
    // new photo has been uploaded).
    final shown =
        [
          ...?ref.watch(employeeListProvider).valueOrNull,
          ...?ref.watch(ownerListProvider).valueOrNull,
        ].where((p) => p.id == member.id).firstOrNull ??
        member;
    final hasPhone = shown.phone != null && shown.phone!.isNotEmpty;
    final myId = ref.watch(currentProfileProvider).valueOrNull?.id;
    final isMe = myId == member.id;

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
    final managerProjectIds = {
      for (final m in ref.watch(projectMembersProvider).valueOrNull ?? const [])
        if (m.employeeId == member.id && m.isManager) m.projectId,
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
                      MemberAvatar(member: shown, radius: 44),
                      const SizedBox(height: 14),
                      Text(
                        shown.fullName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RoleChip(isOwner: isOwner),
                      if (!isOwner) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _changePhoto(context, ref),
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 18,
                          ),
                          label: Text(
                            shown.avatarUrl == null
                                ? l10n.addProfilePhotoButton
                                : l10n.changeProfilePhotoButton,
                          ),
                        ),
                      ],
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
                          Text(hasPhone ? shown.phone! : '—'),
                        ],
                      ),
                      if (!isOwner) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _editDetails(context, ref, shown),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(l10n.editPersonButton),
                        ),
                      ],
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
                  else ...[
                    Text(
                      l10n.projectAdminHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final project in myProjects)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colorForProject(project),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    l10n.projectAdminLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          managerProjectIds.contains(project.id)
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: managerProjectIds.contains(project.id),
                              onChanged: (value) => _setProjectAdmin(
                                context,
                                ref,
                                project,
                                value,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.removeFromProjectTooltip,
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => removePersonFromProject(
                                context,
                                ref,
                                projectId: project.id,
                                person: member,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
                if (!isMe) ...[
                  const SizedBox(height: 28),
                  Text(
                    l10n.companyAdminSectionTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.companyAdminSectionHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _setCompanyAdmin(context, ref, !isOwner),
                    icon: Icon(
                      isOwner
                          ? Icons.arrow_downward
                          : Icons.admin_panel_settings_outlined,
                    ),
                    label: Text(
                      isOwner
                          ? l10n.revokeCompanyAdminButton
                          : l10n.grantCompanyAdminButton,
                    ),
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
