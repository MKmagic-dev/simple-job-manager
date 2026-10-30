import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../projects/data/project_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../tasks/data/task_repository.dart';
import '../data/note_repository.dart';
import '../domain/note_model.dart';
import 'note_form_screen.dart';

/// The boss's notes as cards: title, the start of the text, the date, and who
/// it's shared with. Tap one to edit it.
class NotesBody extends ConsumerWidget {
  const NotesBody({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notesAsync = ref.watch(noteListProvider);
    final recipients =
        ref.watch(noteRecipientsProvider).valueOrNull ?? const [];
    final link = _NoteLinks(
      ref.watch(projectListProvider).valueOrNull ?? const [],
      ref.watch(taskListProvider).valueOrNull ?? const [],
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(noteListProvider);
        ref.invalidate(noteRecipientsProvider);
        await ref.read(noteListProvider.future);
      },
      child: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return _EmptyScroll(text: l10n.noNotesYet);
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: notes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final sharedCount = recipients
                      .where((r) => r.noteId == note.id)
                      .length;
                  return _NoteCard(
                    note: note,
                    link: link.of(note),
                    sharedCount: sharedCount,
                    onTap: () => openNoteForm(
                      context,
                      companyId: companyId,
                      existing: note,
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(friendlyError(context, error))),
      ),
    );
  }
}

/// What an employee sees: the notes the boss shared with them, read-only.
class WorkerNotesBody extends ConsumerWidget {
  const WorkerNotesBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notesAsync = ref.watch(noteListProvider);
    final link = _NoteLinks(
      ref.watch(projectListProvider).valueOrNull ?? const [],
      ref.watch(taskListProvider).valueOrNull ?? const [],
    );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(noteListProvider.future),
      child: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return _EmptyScroll(text: l10n.noNotesSharedWithMe);
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: notes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return _NoteCard(
                    note: note,
                    link: link.of(note),
                    // Employees never see who else a note went to.
                    sharedCount: null,
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(note.title),
                        content: SingleChildScrollView(
                          child: Text(note.content ?? ''),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.closeButton),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(friendlyError(context, error))),
      ),
    );
  }
}

class _EmptyScroll extends StatelessWidget {
  const _EmptyScroll({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(text, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.link,
    required this.sharedCount,
    required this.onTap,
  });

  final NoteModel note;

  /// The project / task label, or null when the note has none (or the viewer
  /// can't see that project).
  final _NoteLink? link;

  /// How many people it's shared with, or null when that must stay hidden
  /// (the employee's view).
  final int? sharedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final text = note.content?.trim() ?? '';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (link != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: link!.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        link!.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    DateFormat.yMMMd(locale).format(note.createdAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (sharedCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sharedCount! > 0
                            ? theme.colorScheme.secondaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sharedCount! > 0
                                ? Icons.group_outlined
                                : Icons.lock_outline,
                            size: 14,
                            color: sharedCount! > 0
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              sharedCount! > 0
                                  ? l10n.noteSharedWithLabel(sharedCount!)
                                  : l10n.noteOnlyMineLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: sharedCount! > 0
                                    ? theme.colorScheme.onSecondaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Project › Task" label of a note and the color of its dot.
class _NoteLink {
  const _NoteLink(this.label, this.color);

  final String label;
  final Color color;
}

/// Looks up the label for a note from the projects/tasks the viewer can see.
class _NoteLinks {
  _NoteLinks(this.projects, this.tasks);

  final List<dynamic> projects;
  final List<dynamic> tasks;

  _NoteLink? of(NoteModel note) {
    if (note.projectId == null && note.taskId == null) return null;
    final project = projects
        .where((p) => p.id == note.projectId)
        .cast<dynamic>()
        .firstOrNull;
    final task = tasks
        .where((t) => t.id == note.taskId)
        .cast<dynamic>()
        .firstOrNull;
    if (project == null && task == null) return null;
    final parts = <String>[
      if (project != null) project.name as String,
      if (task != null) task.title as String,
    ];
    final Color color = project != null
        ? colorForProject(project)
        : colorForTask(task, tasks.cast());
    return _NoteLink(parts.join(' › '), color);
  }
}
