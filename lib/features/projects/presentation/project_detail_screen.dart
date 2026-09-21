import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/attachment_tile.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/project_task_model.dart';
import '../../tasks/presentation/task_detail_screen.dart';
import '../data/project_repository.dart';
import '../domain/project_model.dart';
import 'project_list_screen.dart' show ProjectCover;

/// The employee's read-only view of a project they're assigned to: what it
/// is, their own tasks in it (where they add photos for the boss), the
/// project gallery, and a "project completed" button that only notifies the
/// boss — it changes nothing about the project itself. Employees can't edit
/// or delete projects.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({
    super.key,
    required this.companyId,
    required this.project,
  });

  final String companyId;
  final ProjectModel project;

  Future<void> _confirmMarkCompleted(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectCompletedButton),
        content: Text(l10n.projectCompletedConfirmMessage),
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
    if (confirmed != true) return;

    try {
      await ref
          .read(projectRepositoryProvider)
          .submitCompletionNotice(project.id);
      ref.invalidate(projectCompletionNoticeListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.projectCompletedNoticeSentSuccess)),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(locale);

    final tasks = (ref.watch(taskListProvider).valueOrNull ?? const [])
        .where((task) => task.projectId == project.id)
        .toList();
    final attachments =
        ref.watch(projectAttachmentsProvider(project.id)).valueOrNull ??
        const [];

    final dates = [
      if (project.startDate != null) dateFormat.format(project.startDate!),
      if (project.endDate != null) dateFormat.format(project.endDate!),
    ].join(' – ');

    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    child: ProjectCover(project: project),
                  ),
                ),
                const SizedBox(height: 16),
                if (project.address != null && project.address!.isNotEmpty)
                  _InfoRow(icon: Icons.place_outlined, text: project.address!),
                if (dates.isNotEmpty)
                  _InfoRow(icon: Icons.event_outlined, text: dates),
                if (project.description != null &&
                    project.description!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.notes_outlined,
                    text: project.description!,
                  ),
                const SizedBox(height: 16),
                Text(l10n.myTasksTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (tasks.isEmpty)
                  Text(l10n.noMyTasksYet, style: theme.textTheme.bodySmall)
                else
                  for (final task in tasks) _TaskTile(task: task),
                const SizedBox(height: 16),
                Text(l10n.galleryLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (attachments.isEmpty)
                  Text(l10n.noGalleryLabel, style: theme.textTheme.bodySmall)
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final attachment in attachments)
                        AttachmentTile(
                          isImage: attachment.isImage,
                          fileName: attachment.fileName,
                          urlProvider: projectAttachmentSignedUrlProvider(
                            attachment.storagePath,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _confirmMarkCompleted(context, ref),
                  icon: const Icon(Icons.task_alt_outlined),
                  label: Text(l10n.projectCompletedButton),
                ),
              ],
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final ProjectTaskModel task;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat.MMMd(locale);
    final dateLabel = task.startDate == task.endDate
        ? dateFormat.format(task.startDate)
        : '${dateFormat.format(task.startDate)} – ${dateFormat.format(task.endDate)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.checklist_outlined),
        title: Text(task.title),
        subtitle: Text(
          '$dateLabel · ${task.hasHours ? '${formatTime(task.startTime!)}–${formatTime(task.endTime!)}' : l10n.taskWholeDayLabel}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(task: task, isOwner: false),
          ),
        ),
      ),
    );
  }
}
