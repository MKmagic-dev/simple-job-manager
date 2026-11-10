import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/calendar_event_repository.dart';
import '../domain/calendar_event_model.dart';

/// Whether the user has opened the calendar in this app session. Clears the
/// count on the "Kalendarz" menu item.
final remindersSeenProvider = StateProvider<bool>((ref) => false);

/// Shows today's reminders once, when the screen it wraps opens. Closing the
/// popup marks them as read, so their badge in the calendar goes away.
/// [isCalendar] marks that the calendar itself was opened.
class RemindersOnOpen extends ConsumerStatefulWidget {
  const RemindersOnOpen({
    super.key,
    required this.child,
    this.isCalendar = false,
  });

  final Widget child;
  final bool isCalendar;

  @override
  ConsumerState<RemindersOnOpen> createState() => _RemindersOnOpenState();
}

class _RemindersOnOpenState extends ConsumerState<RemindersOnOpen> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (widget.isCalendar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(remindersSeenProvider.notifier).state = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(calendarEventListProvider).valueOrNull;
    final acknowledged = ref.watch(reminderAcksProvider).valueOrNull;
    if (!_checked && events != null && acknowledged != null) {
      _checked = true;
      final due = remindersOn(DateTime.now(), events, acknowledged);
      if (due.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _show(due);
        });
      }
    }
    return widget.child;
  }

  Future<void> _show(List<ReminderDue> due) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.remindersPopupTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final reminder in due)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  reminder.event.hasTime
                      ? '${formatTime(reminder.event.startTime!)}  ${reminder.event.title}'
                      : reminder.event.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );

    try {
      await ref.read(calendarEventRepositoryProvider).acknowledge(due);
      ref.invalidate(reminderAcksProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
      }
    }
  }
}
