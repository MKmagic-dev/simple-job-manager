import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/calendar_event_repository.dart';
import '../domain/calendar_event_model.dart';

/// Shows today's reminders once, when the home screen opens. Closing the popup
/// marks them as read, so their badge in the calendar goes away.
class RemindersOnOpen extends ConsumerStatefulWidget {
  const RemindersOnOpen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RemindersOnOpen> createState() => _RemindersOnOpenState();
}

class _RemindersOnOpenState extends ConsumerState<RemindersOnOpen> {
  bool _checked = false;

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

  Future<void> _show(List<CalendarEventModel> due) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.remindersPopupTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final event in due)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  event.hasTime
                      ? '${formatTime(event.startTime!)}  ${event.title}'
                      : event.title,
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
