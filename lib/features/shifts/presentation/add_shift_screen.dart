import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../projects/data/project_repository.dart';
import '../domain/shift_model.dart';
import 'add_shift_controller.dart';

/// Also used to edit a shift — pass [existingShift] and the form is
/// prefilled and submits an update instead of creating a new one.
///
/// [preselectedProjectId], when adding a new shift from a single project's
/// schedule, starts the project dropdown on that project (still changeable).
class AddShiftScreen extends ConsumerStatefulWidget {
  const AddShiftScreen({
    super.key,
    required this.companyId,
    this.existingShift,
    this.preselectedProjectId,
  });

  final String companyId;
  final ShiftModel? existingShift;
  final String? preselectedProjectId;

  @override
  ConsumerState<AddShiftScreen> createState() => _AddShiftScreenState();
}

class _AddShiftScreenState extends ConsumerState<AddShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _notesController = TextEditingController(
    text: widget.existingShift?.notes ?? '',
  );

  bool get _isEditing => widget.existingShift != null;

  late String? _employeeId = widget.existingShift?.employeeId;
  late String? _projectId =
      widget.existingShift?.projectId ?? widget.preselectedProjectId;
  late DateTime _workDate = widget.existingShift?.workDate ?? DateTime.now();
  late TimeOfDay _startTime =
      widget.existingShift?.startTime ?? const TimeOfDay(hour: 8, minute: 0);
  late TimeOfDay _endTime =
      widget.existingShift?.endTime ?? const TimeOfDay(hour: 16, minute: 0);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _workDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  int _minutesSinceMidnight(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) return;

    if (_employeeId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.employeeRequiredError)));
      return;
    }

    if (_minutesSinceMidnight(_endTime) <= _minutesSinceMidnight(_startTime)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.endTimeBeforeStartError)));
      return;
    }

    final notifier = ref.read(addShiftControllerProvider.notifier);
    final success = _isEditing
        ? await notifier.update(
            shiftId: widget.existingShift!.id,
            employeeId: _employeeId!,
            projectId: _projectId,
            workDate: _workDate,
            startTime: _startTime,
            endTime: _endTime,
            notes: _notesController.text.trim(),
          )
        : await notifier.submit(
            companyId: widget.companyId,
            employeeId: _employeeId!,
            projectId: _projectId,
            workDate: _workDate,
            startTime: _startTime,
            endTime: _endTime,
            notes: _notesController.text.trim(),
          );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? l10n.shiftUpdatedSuccess : l10n.shiftAddedSuccess,
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final submitState = ref.watch(addShiftControllerProvider);
    final isLoading = submitState.isLoading;
    final employeesAsync = ref.watch(employeeListProvider);
    final projectsAsync = ref.watch(projectListProvider);

    ref.listen<AsyncValue<void>>(addShiftControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editShiftTitle : l10n.addShiftTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                employeesAsync.when(
                  data: (employees) => DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    decoration: InputDecoration(labelText: l10n.employeeLabel),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text(employee.fullName),
                        ),
                    ],
                    onChanged: isLoading
                        ? null
                        : (value) => setState(() => _employeeId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text(error.toString()),
                ),
                const SizedBox(height: 16),
                projectsAsync.when(
                  data: (projects) => DropdownButtonFormField<String?>(
                    initialValue: _projectId,
                    decoration: InputDecoration(
                      labelText: l10n.projectOptionalLabel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.noProjectOption),
                      ),
                      for (final project in projects)
                        DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name),
                        ),
                    ],
                    onChanged: isLoading
                        ? null
                        : (value) => setState(() => _projectId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text(error.toString()),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: isLoading ? null : _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: l10n.workDateLabel),
                    child: Text(_formatDate(_workDate)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () => _pickTime(isStart: true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.startTimeLabel,
                          ),
                          child: Text(_formatTime(_startTime)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () => _pickTime(isStart: false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.endTimeLabel,
                          ),
                          child: Text(_formatTime(_endTime)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  enabled: !isLoading,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l10n.notesLabel),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isLoading
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
    );
  }
}
