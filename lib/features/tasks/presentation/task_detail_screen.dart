import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/widgets/attachment_tile.dart';
import '../../../core/config/branding_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_model.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/add_shift_screen.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/task_note_repository.dart';
import '../data/task_repository.dart';
import '../domain/task_note_model.dart';
import '../domain/project_task_model.dart';
import 'task_actions.dart';
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
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Employee: tell the boss the task is finished (they decide whether to
  /// archive it).
  Future<void> _markDone(ProjectTaskModel task) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.markTaskDoneButton),
        content: Text(l10n.markTaskDoneConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(taskRepositoryProvider).submitCompletionNotice(task.id);
      ref.invalidate(taskCompletionNoticeListProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.taskDoneSentSuccess)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
      }
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
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
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
    final shifts = ref.watch(shiftListProvider).valueOrNull ?? const [];
    final assignees = [
      for (final id in task.assigneeIdsFrom(
        shifts,
        ref.watch(taskAssignmentsProvider).valueOrNull ?? const [],
      ))
        if (peopleById[id] != null) peopleById[id]!,
    ];

    // A task has no hours of its own when they are set per person (shifts):
    // show those, one slot per day/time with who is on it.
    final slotMap = <String, _TimeSlot>{};
    for (final shift in shifts.where((s) => s.taskId == task.id)) {
      final range =
          '${formatTime(shift.startTime)}–${formatTime(shift.endTime)}';
      final slot = slotMap.putIfAbsent(
        '${shift.workDate}|$range',
        () => _TimeSlot(
          date: DateFormat.MMMEd(locale).format(shift.workDate),
          range: range,
          sortKey: shift.workDate.add(
            Duration(
              hours: shift.startTime.hour,
              minutes: shift.startTime.minute,
            ),
          ),
        ),
      );
      final name = peopleById[shift.employeeId]?.fullName;
      if (name != null) slot.names.add(name);
    }
    final slots = slotMap.values.toList()
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    final sameProjectTasks = <ProjectTaskModel>[
      for (final t in ref.watch(taskListProvider).valueOrNull ?? const [])
        if (t.projectId == task.projectId) t,
    ];
    final taskColor = colorForTask(
      task,
      sameProjectTasks.isEmpty ? [task] : sameProjectTasks,
    );

    final taskNotices =
        (ref.watch(taskCompletionNoticeListProvider).valueOrNull ?? const [])
            .where((notice) => notice.taskId == task.id)
            .toList();
    final reportedByMe = taskNotices.any(
      (notice) => notice.employeeId == currentUserId,
    );
    final doneByNames = [
      for (final notice in taskNotices)
        peopleById[notice.employeeId]?.fullName ?? '?',
    ];
    final canAddShift =
        project != null && !task.isArchived && !project.isArchived;

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
          if (widget.isOwner)
            IconButton(
              icon: Icon(
                task.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.inventory_2_outlined,
              ),
              tooltip: task.isArchived
                  ? l10n.restoreTaskAction
                  : l10n.archiveTaskAction,
              onPressed: () =>
                  setTaskArchived(context, ref, task, !task.isArchived),
            ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _TaskHeader(
                  title: task.title,
                  color: taskColor,
                  project: project,
                  archived: task.isArchived,
                  archivedLabel: l10n.archivedBadgeLabel,
                ),
                if (widget.isOwner && doneByNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: BrandingConfig.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: BrandingConfig.accentColor.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.task_alt,
                          color: BrandingConfig.accentColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.taskDoneByLabel(doneByNames.join(', ')),
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
                ],
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.event_outlined,
                  title: '$dateLabel · ${l10n.taskDaysCount(task.dayCount)}',
                  child: task.hasHours
                      ? _TimeSlotRow(
                          accent: taskColor,
                          date: null,
                          range:
                              '${formatTime(task.startTime!)}–${formatTime(task.endTime!)}',
                          names: [for (final p in assignees) p.fullName],
                        )
                      : slots.isEmpty
                      ? Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(l10n.taskWholeDayLabel)),
                          ],
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < slots.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _TimeSlotRow(
                                accent: taskColor,
                                date: slots[i].date,
                                range: slots[i].range,
                                names: slots[i].names,
                              ),
                            ],
                          ],
                        ),
                ),
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.notes_outlined,
                    title: l10n.descriptionLabel,
                    child: Text(
                      task.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
                if (widget.isOwner) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.groups_outlined,
                    title: l10n.taskPeopleLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (assignees.isEmpty)
                          Text(
                            l10n.taskNoPeopleYet,
                            style: theme.textTheme.bodySmall,
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final person in assignees)
                                _PersonPill(person: person),
                            ],
                          ),
                        if (canAddShift) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AddShiftScreen(
                                  companyId: task.companyId,
                                  preselectedProjectId: project.id,
                                  preselectedTaskId: task.id,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.addShiftToTaskButton),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.photo_library_outlined,
                  title: l10n.taskFilesSectionLabel,
                  trailing: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _addFile(task),
                    icon: _uploading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(l10n.addPhotoOrFileButton),
                  ),
                  child: attachments.isEmpty
                      ? Text(
                          l10n.noTaskFilesYet,
                          style: theme.textTheme.bodySmall,
                        )
                      : Wrap(
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
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.sticky_note_2_outlined,
                  title: widget.isOwner
                      ? l10n.taskNoteOwnerSectionTitle
                      : l10n.taskNoteSectionTitle,
                  child: _TaskNotesCard(
                    task: task,
                    isOwner: widget.isOwner,
                    peopleById: peopleById,
                  ),
                ),
                if (!widget.isOwner) ...[
                  const SizedBox(height: 16),
                  if (reportedByMe)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: BrandingConfig.accentColor.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.task_alt,
                            color: BrandingConfig.accentColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(l10n.taskDoneSentLabel)),
                        ],
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => _markDone(task),
                      icon: const Icon(Icons.task_alt),
                      label: Text(l10n.markTaskDoneButton),
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

/// The top of the page: the task's own color as an edge, its name big, and the
/// project it belongs to.
class _TaskHeader extends StatelessWidget {
  const _TaskHeader({
    required this.title,
    required this.color,
    required this.project,
    required this.archived,
    required this.archivedLabel,
  });

  final String title;
  final Color color;
  final ProjectModel? project;
  final bool archived;
  final String archivedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 8, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (project != null) _ProjectPill(project: project!),
                        if (archived)
                          Chip(
                            avatar: const Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                            ),
                            label: Text(archivedLabel),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded section with a small icon tile and a title, so the page reads as
/// separate blocks instead of one flat list.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: BrandingConfig.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: BrandingConfig.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (trailing != null) ...[const SizedBox(height: 12), trailing!],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// One time slot: the hours big, the day (if the slot has its own), and the
/// people on it as small pills.
class _TimeSlotRow extends StatelessWidget {
  const _TimeSlotRow({
    required this.accent,
    required this.date,
    required this.range,
    required this.names,
  });

  final Color accent;
  final String? date;
  final String range;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: accent, width: 4)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                range,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (date != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    date!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in names)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      name,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonPill extends StatelessWidget {
  const _PersonPill({required this.person});

  final ProfileModel person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: person.avatarUrl != null
                ? NetworkImage(person.avatarUrl!)
                : null,
            child: person.avatarUrl == null
                ? Text(
                    initialsOf(person.fullName),
                    style: const TextStyle(fontSize: 11),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              person.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSlot {
  _TimeSlot({required this.date, required this.range, required this.sortKey});

  final String date;
  final String range;
  final DateTime sortKey;
  final List<String> names = [];
}

/// The notes on a task: an employee writes to the boss here (and sees their
/// own notes), the boss reads everybody's.
class _TaskNotesCard extends ConsumerStatefulWidget {
  const _TaskNotesCard({
    required this.task,
    required this.isOwner,
    required this.peopleById,
  });

  final ProjectTaskModel task;
  final bool isOwner;
  final Map<String, ProfileModel> peopleById;

  @override
  ConsumerState<_TaskNotesCard> createState() => _TaskNotesCardState();
}

class _TaskNotesCardState extends ConsumerState<_TaskNotesCard> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _markedRead = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(taskNoteRepositoryProvider)
          .addNote(
            companyId: widget.task.companyId,
            taskId: widget.task.id,
            content: text,
          );
      _controller.clear();
      ref.invalidate(taskNoteListProvider(widget.task.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.taskNoteSentSuccess)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(TaskNoteModel note) async {
    try {
      await ref.read(taskNoteRepositoryProvider).deleteNote(note.id);
      ref.invalidate(taskNoteListProvider(widget.task.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final notes = ref.watch(taskNoteListProvider(widget.task.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isOwner) ...[
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: l10n.taskNoteHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_outlined, size: 18),
              label: Text(l10n.taskNoteSendButton),
            ),
          ),
          const SizedBox(height: 12),
        ],
        notes.when(
          data: (list) {
            // The boss opening the task reads its notes: the badges on the
            // project, its tasks tab and this task go away.
            if (widget.isOwner &&
                !_markedRead &&
                list.any((note) => note.readAt == null)) {
              _markedRead = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                await ref
                    .read(taskNoteRepositoryProvider)
                    .markRead(widget.task.id);
                ref.invalidate(unreadTaskNotesProvider);
                ref.invalidate(taskNoteListProvider(widget.task.id));
              });
            }
            if (list.isEmpty) {
              return Text(l10n.taskNoteEmpty, style: theme.textTheme.bodySmall);
            }
            return Column(
              children: [
                for (final note in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.isOwner)
                                Text(
                                  widget.peopleById[note.authorId]?.fullName ??
                                      '?',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(note.content),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.yMMMd(
                                  locale,
                                ).add_Hm().format(note.createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!widget.isOwner)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: l10n.taskNoteDeleteTooltip,
                            onPressed: () => _delete(note),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stackTrace) => Text(
            friendlyError(context, error),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
