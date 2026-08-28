import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/domain/project_model.dart';
import '../data/shift_change_request_repository.dart';
import '../data/shift_repository.dart';
import '../domain/shift_model.dart';
import 'add_shift_screen.dart';
import 'calendar_shared.dart';

/// The shared shift-detail popup, opened by tapping a shift block in any
/// view (the time grid, or the day-detail sheet opened from month/year).
///
/// For an owner it also offers editing/deleting the shift, and shows any
/// change requests the employee has left on it. For the employee viewing
/// their own shift, it offers leaving a change request instead.
void showShiftDetailsDialog(
  BuildContext context,
  ShiftModel shift,
  List<CalendarPerson> people,
  List<ProjectModel> projects, {
  required bool isOwner,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => _ShiftDetailsDialog(
      shift: shift,
      people: people,
      projects: projects,
      isOwner: isOwner,
    ),
  );
}

class _ShiftDetailsDialog extends ConsumerStatefulWidget {
  const _ShiftDetailsDialog({
    required this.shift,
    required this.people,
    required this.projects,
    required this.isOwner,
  });

  final ShiftModel shift;
  final List<CalendarPerson> people;
  final List<ProjectModel> projects;
  final bool isOwner;

  @override
  ConsumerState<_ShiftDetailsDialog> createState() => _ShiftDetailsDialogState();
}

class _ShiftDetailsDialogState extends ConsumerState<_ShiftDetailsDialog> {
  final _messageController = TextEditingController();
  bool _showRequestForm = false;
  bool _submittingRequest = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _deleteShift() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteShiftTooltip),
        content: Text(l10n.deleteShiftConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancelButton)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.deleteButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(shiftRepositoryProvider).deleteShift(widget.shift.id);
    ref.invalidate(shiftListProvider);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shiftDeletedSuccess)));
    }
  }

  void _editShift() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddShiftScreen(companyId: widget.shift.companyId, existingShift: widget.shift),
      ),
    );
  }

  Future<void> _submitChangeRequest() async {
    final l10n = AppLocalizations.of(context)!;
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.requestChangeMessageRequiredError)));
      return;
    }

    setState(() => _submittingRequest = true);
    try {
      await ref
          .read(shiftChangeRequestRepositoryProvider)
          .submitChangeRequest(shiftId: widget.shift.id, message: message);
      ref.invalidate(shiftChangeRequestListProvider);
      if (mounted) {
        setState(() {
          _showRequestForm = false;
          _messageController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.requestChangeSentSuccess)));
      }
    } finally {
      if (mounted) setState(() => _submittingRequest = false);
    }
  }

  Future<void> _dismissChangeRequest(String id) async {
    await ref.read(shiftChangeRequestRepositoryProvider).dismissChangeRequest(id);
    ref.invalidate(shiftChangeRequestListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final employeeName = personById(widget.people, widget.shift.employeeId)?.name;
    final projectName = widget.shift.projectId == null
        ? null
        : widget.projects.where((p) => p.id == widget.shift.projectId).map((p) => p.name).firstOrNull;
    final changeRequestsAsync = ref.watch(shiftChangeRequestListProvider);
    final changeRequests =
        changeRequestsAsync.valueOrNull?.where((r) => r.shiftId == widget.shift.id).toList() ?? [];

    return AlertDialog(
      title: Text(l10n.shiftDetailsTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(widget.shift.workDate)}  '
                '${formatTime(widget.shift.startTime)}–${formatTime(widget.shift.endTime)}',
              ),
              if (employeeName != null) ...[
                const SizedBox(height: 8),
                Text('${l10n.employeeLabel}: $employeeName'),
              ],
              if (projectName != null) ...[
                const SizedBox(height: 8),
                Text('${l10n.projectLabel}: $projectName'),
              ],
              if (widget.shift.notes != null && widget.shift.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.shift.notes!),
              ],
              if (changeRequests.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.changeRequestsSectionLabel, style: Theme.of(context).textTheme.labelLarge),
                for (final request in changeRequests)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(request.message)),
                        if (widget.isOwner)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: l10n.dismissChangeRequestTooltip,
                            onPressed: () => _dismissChangeRequest(request.id),
                          ),
                      ],
                    ),
                  ),
              ],
              if (!widget.isOwner) ...[
                const SizedBox(height: 16),
                if (_showRequestForm) ...[
                  TextField(
                    controller: _messageController,
                    enabled: !_submittingRequest,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: l10n.requestChangeMessageLabel),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _submittingRequest ? null : _submitChangeRequest,
                      child: Text(l10n.sendButton),
                    ),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showRequestForm = true),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(l10n.requestChangeButton),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.isOwner) ...[
          TextButton(onPressed: _deleteShift, child: Text(l10n.deleteShiftTooltip)),
          TextButton(onPressed: _editShift, child: Text(l10n.editButton)),
        ],
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.closeButton),
        ),
      ],
    );
  }
}
