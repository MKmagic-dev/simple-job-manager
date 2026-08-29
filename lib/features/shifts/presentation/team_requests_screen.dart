import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/unread/last_seen_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../projects/domain/project_model.dart';
import '../data/shift_change_request_repository.dart';
import '../data/shift_repository.dart';
import '../domain/shift_change_request_model.dart';
import 'calendar_shared.dart';
import 'shift_details_dialog.dart';

/// One place for the boss to see every shift-change request across the
/// whole team, instead of having to open each shift individually to spot
/// one. Opening this screen marks everything as seen (clears the badge on
/// its home-screen tile).
class TeamRequestsScreen extends ConsumerStatefulWidget {
  const TeamRequestsScreen({
    super.key,
    required this.people,
    required this.projects,
  });

  final List<CalendarPerson> people;
  final List<ProjectModel> projects;

  @override
  ConsumerState<TeamRequestsScreen> createState() => _TeamRequestsScreenState();
}

class _TeamRequestsScreenState extends ConsumerState<TeamRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lastSeenRequestsProvider.notifier).markSeenNow();
    });
  }

  Future<void> _dismiss(ShiftChangeRequestModel request) async {
    await ref
        .read(shiftChangeRequestRepositoryProvider)
        .dismissChangeRequest(request.id);
    ref.invalidate(shiftChangeRequestListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final requestsAsync = ref.watch(shiftChangeRequestListProvider);
    final shiftsAsync = ref.watch(shiftListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changeRequestsSectionLabel)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(shiftChangeRequestListProvider.future),
        child: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(child: Text(l10n.noChangeRequestsLabel)),
                  ),
                ),
              );
            }

            final shifts = shiftsAsync.valueOrNull ?? const [];

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final request = requests[index];
                final person = personById(widget.people, request.employeeId);
                final shift = shifts
                    .where((s) => s.id == request.shiftId)
                    .firstOrNull;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: person?.avatarUrl != null
                        ? NetworkImage(person!.avatarUrl!)
                        : null,
                    child: person?.avatarUrl == null
                        ? Text(initialsOf(person?.name ?? '?'))
                        : null,
                  ),
                  title: Text(person?.name ?? '?'),
                  subtitle: Text(
                    shift == null
                        ? request.message
                        : '${DateFormat.yMMMd(locale).format(shift.workDate)} '
                              '${formatTime(shift.startTime)}–${formatTime(shift.endTime)} · ${request.message}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: shift == null
                      ? null
                      : () => showShiftDetailsDialog(
                          context,
                          shift,
                          widget.people,
                          widget.projects,
                          isOwner: true,
                        ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.dismissChangeRequestTooltip,
                    onPressed: () => _dismiss(request),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}
