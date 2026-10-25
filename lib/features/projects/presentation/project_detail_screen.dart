import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
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
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
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
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 8,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProjectCover(project: project),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                              stops: [0.45, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: Text(
                            project.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (project.address != null && project.address!.isNotEmpty ||
                    dates.isNotEmpty ||
                    project.description != null &&
                        project.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (project.address != null &&
                            project.address!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.place_outlined,
                            text: project.address!,
                          ),
                        if (dates.isNotEmpty)
                          _InfoRow(icon: Icons.event_outlined, text: dates),
                        if (project.description != null &&
                            project.description!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.notes_outlined,
                            text: project.description!,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _SectionHeader(
                  icon: Icons.checklist_outlined,
                  title: l10n.myTasksTitle,
                ),
                if (tasks.isEmpty)
                  _SectionCard(
                    child: Text(
                      l10n.noMyTasksYet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final task in tasks) _TaskTile(task: task),
                const SizedBox(height: 12),
                _SectionHeader(
                  icon: Icons.photo_library_outlined,
                  title: l10n.galleryLabel,
                ),
                _SectionCard(
                  child: attachments.isEmpty
                      ? Text(
                          l10n.noGalleryLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Wrap(
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
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
