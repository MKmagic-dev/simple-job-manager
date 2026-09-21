import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/files/picked_file.dart';
import '../../../core/widgets/attachment_tile.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_model.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/task_repository.dart';
import '../domain/project_task_model.dart';
import 'task_form_screen.dart';

/// One task: what it is, when, who's on it, and all its photos/files.
///
/// The owner can edit/delete it. Assigned employees can add photos or PDFs
/// to it (that's how work photos reach the boss, filed under the task) but
/// can't change or remove the task itself.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.isOwner,
  });

  /// Only used until [taskListProvider] delivers the live copy (and as the
  /// id to look that copy up by).
  final ProjectTaskModel task;
  final bool isOwner;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _uploading = false;

  Future<void> _addFile(ProjectTaskModel task) async {
    final picked = await pickPhotoOrFile(context);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      await ref
          .read(taskRepositoryProvider)
          .uploadAttachment(
            companyId: task.companyId,
            taskId: task.id,
            fileName: picked.fileName,
            bytes: picked.bytes,
          );
      ref.invalidate(taskAttachmentsProvider(task.id));
      ref.invalidate(projectTaskAttachmentsProvider(task.projectId));
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

  Future<void> _delete(ProjectTaskModel task) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTaskTooltip),
        content: Text(l10n.deleteTaskConfirmMessage),
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
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(taskRepositoryProvider).deleteTask(task.id);
      ref.invalidate(taskListProvider);
      ref.invalidate(projectTaskAttachmentsProvider(task.projectId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.taskDeletedSuccess)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    final task =
        ref
            .watch(taskListProvider)
            .valueOrNull
            ?.where((t) => t.id == widget.task.id)
            .firstOrNull ??
        widget.task;
    final project = ref
        .watch(projectListProvider)
        .valueOrNull
        ?.where((p) => p.id == task.projectId)
        .firstOrNull;
    final attachments =
        ref.watch(taskAttachmentsProvider(task.id)).valueOrNull ?? const [];

    final currentUserId = ref.watch(currentProfileProvider).valueOrNull?.id;
    final peopleById = <String, ProfileModel>{
      for (final person in ref.watch(employeeListProvider).valueOrNull ?? [])
        person.id: person,
      for (final person in ref.watch(ownerListProvider).valueOrNull ?? [])
        person.id: person,
    };
    final assignees = [
      for (final id in task.assigneeIds)
        if (peopleById[id] != null) peopleById[id]!,
    ];

    final dateFormat = DateFormat.yMMMd(locale);
    final dateLabel = task.startDate == task.endDate
        ? dateFormat.format(task.startDate)
        : '${dateFormat.format(task.startDate)} – ${dateFormat.format(task.endDate)}';

    String? captionFor(String? uploadedBy, DateTime createdAt) {
      final when = DateFormat.yMMMd(locale).format(createdAt);
      if (uploadedBy != null && uploadedBy == currentUserId) {
        return '${l10n.uploaderYouLabel} · $when';
      }
      final name = uploadedBy == null ? null : peopleById[uploadedBy]?.fullName;
      return name == null ? when : '$name · $when';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          if (widget.isOwner && project != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editButton,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TaskFormScreen(
                    companyId: task.companyId,
                    project: project,
                    existingTask: task,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteTaskTooltip,
              onPressed: () => _delete(task),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (project != null) _ProjectPill(project: project),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.event_outlined,
                  text: '$dateLabel · ${l10n.taskDaysCount(task.dayCount)}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  text: task.hasHours
                      ? '${formatTime(task.startTime!)}–${formatTime(task.endTime!)}'
                      : l10n.taskWholeDayLabel,
                ),
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    l10n.descriptionLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(task.description!),
                ],
                if (widget.isOwner) ...[
                  const SizedBox(height: 20),
                  Text(
                    l10n.assignedEmployeesLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  if (assignees.isEmpty)
                    Text(
                      l10n.noAssignedEmployeesLabel,
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final person in assignees)
                          Chip(
                            avatar: CircleAvatar(
                              backgroundImage: person.avatarUrl != null
                                  ? NetworkImage(person.avatarUrl!)
                                  : null,
                              child: person.avatarUrl == null
                                  ? Text(initialsOf(person.fullName))
                                  : null,
                            ),
                            label: Text(person.fullName),
                          ),
                      ],
                    ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.taskFilesSectionLabel,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : () => _addFile(task),
                      icon: _uploading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                      label: Text(l10n.addPhotoOrFileButton),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (attachments.isEmpty)
                  Text(l10n.noTaskFilesYet, style: theme.textTheme.bodySmall)
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final attachment in attachments)
                        AttachmentTile(
                          isImage: attachment.isImage,
                          fileName: attachment.fileName,
                          urlProvider: taskAttachmentSignedUrlProvider(
                            attachment.storagePath,
                          ),
                          caption: captionFor(
                            attachment.uploadedBy,
                            attachment.createdAt,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectPill extends StatelessWidget {
  const _ProjectPill({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final color = colorForProject(project);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(project.name, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
