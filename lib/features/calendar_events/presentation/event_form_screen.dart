import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/calendar_event_repository.dart';
import '../domain/calendar_event_model.dart';

/// Adds a calendar event / reminder, or edits [existing]: a title, an
/// optional note, a date range, and either a time of day or "all day".
/// [initialDate] pre-fills the day when adding from a tapped calendar day.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({
    super.key,
    required this.companyId,
    this.existing,
    this.initialDate,
  });

  final String companyId;
  final CalendarEventModel? existing;
  final DateTime? initialDate;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.existing?.notes ?? '',
  );

  late DateTime _startDate;
  late DateTime _endDate;
  late bool _allDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final now = DateTime.now();
    final fallback =
        widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _startDate = existing?.startDate ?? fallback;
    _endDate = existing?.endDate ?? _startDate;
    _allDay = existing != null && !existing.hasTime;
    _startTime = existing?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = existing?.endTime ?? const TimeOfDay(hour: 10, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    // A timed event that ends before it starts on the same day makes no sense.
    if (!_allDay &&
        _startDate == _endDate &&
        _minutes(_endTime) <= _minutes(_startTime)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.eventEndBeforeStartError)));
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(calendarEventRepositoryProvider);
    try {
      final title = _titleController.text.trim();
      final notes = _notesController.text.trim();
      final existing = widget.existing;
      if (existing == null) {
        await repository.createEvent(
          companyId: widget.companyId,
          title: title,
          notes: notes,
          startDate: _startDate,
          endDate: _endDate,
          startTime: _allDay ? null : _startTime,
          endTime: _allDay ? null : _endTime,
        );
      } else {
        await repository.updateEvent(
          eventId: existing.id,
          title: title,
          notes: notes,
          startDate: _startDate,
          endDate: _endDate,
          startTime: _allDay ? null : _startTime,
          endTime: _allDay ? null : _endTime,
        );
      }
      ref.invalidate(calendarEventListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.eventSavedSuccess)));
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEventTooltip),
        content: Text(l10n.deleteEventConfirmMessage),
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
      await ref
          .read(calendarEventRepositoryProvider)
          .deleteEvent(widget.existing!.id);
      ref.invalidate(calendarEventListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.eventDeletedSuccess)));
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
    final dateFormat = DateFormat.yMMMEd(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editEventTitle : l10n.addEventTitle),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteEventTooltip,
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !_saving,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.eventTitleLabel,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.eventTitleRequiredError
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _saving
                                ? null
                                : () => _pickDate(isStart: true),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.taskFromDateLabel,
                              ),
                              child: Text(dateFormat.format(_startDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _saving
                                ? null
                                : () => _pickDate(isStart: false),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.taskToDateLabel,
                              ),
                              child: Text(dateFormat.format(_endDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.eventAllDayLabel),
                      value: _allDay,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _allDay = value),
                    ),
                    if (!_allDay) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _saving
                                  ? null
                                  : () => _pickTime(isStart: true),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.startTimeLabel,
                                ),
                                child: Text(_startTime.format(context)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _saving
                                  ? null
                                  : () => _pickTime(isStart: false),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.endTimeLabel,
                                ),
                                child: Text(_endTime.format(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.eventNotesLabel,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.saveButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the event form to add an event (optionally on [initialDate]) or, with
/// [existing], to edit one.
void openEventForm(
  BuildContext context, {
  required String companyId,
  CalendarEventModel? existing,
  DateTime? initialDate,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => EventFormScreen(
        companyId: companyId,
        existing: existing,
        initialDate: initialDate,
      ),
    ),
  );
}
