import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/task_repository.dart';
import '../domain/project_task_model.dart';

/// Confirms (when archiving) and applies archive/restore for a task, then
/// refreshes the lists that show tasks and "done" notices. Shared by the
/// task cards and the task's own screen. Returns whether it went through.
Future<bool> setTaskArchived(
  BuildContext context,
  WidgetRef ref,
  ProjectTaskModel task,
  bool archived,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  if (archived) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archiveTaskAction),
        content: Text(l10n.archiveTaskConfirmMessage),
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
        .read(taskRepositoryProvider)
        .setArchived(task.id, archived: archived);
    ref.invalidate(taskListProvider);
    ref.invalidate(taskCompletionNoticeListProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archived ? l10n.taskArchivedSuccess : l10n.taskRestoredSuccess,
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
