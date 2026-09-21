import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../projects/data/project_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../data/shift_repository.dart';
import '../domain/shift_model.dart';
import 'add_shift_controller.dart';

/// Adds shifts, or edits one when [existingShift] is passed.
///
/// A shift is: a project, optionally a task of that project ("wylewanie
/// fundamentów" — this is how an employee gets put on a task), the people,
/// the day(s) and the hours. When adding, several people and a date range
/// can be picked at once — one shift is created per person per day. When
/// editing, it's always exactly that one shift.
///
/// [preselectedProjectId] / [preselectedTaskId] / [preselectedEmployeeId]
/// start the form on those values (still changeable).
class AddShiftScreen extends ConsumerStatefulWidget {
  const AddShiftScreen({
    super.key,
    required this.companyId,
    this.existingShift,
    this.preselectedProjectId,
    this.preselectedTaskId,
    this.preselectedEmployeeId,
  });

  final String companyId;
  final ShiftModel? existingShift;
  final String? preselectedProjectId;
  final String? preselectedTaskId;
  final String? preselectedEmployeeId;

  @override
  ConsumerState<AddShiftScreen> createState() => _AddShiftScreenState();
}

class _AddShiftScreenState extends ConsumerState<AddShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _notesController = TextEditingController(
    text: widget.existingShift?.notes ?? '',
  );

  bool get _isEditing => widget.existingShift != null;

  late String? _employeeId =
      widget.existingShift?.employeeId ?? widget.preselectedEmployeeId;
  late final Set<String> _employeeIds = {
    if (widget.preselectedEmployeeId != null) widget.preselectedEmployeeId!,
  };
  late String? _projectId =
      widget.existingShift?.projectId ?? widget.preselectedProjectId;
  late String? _taskId =
      widget.existingShift?.taskId ?? widget.preselectedTaskId;
  late DateTime _workDate = widget.existingShift?.workDate ?? _today();
  late DateTime _endDate = _workDate;
  late TimeOfDay _startTime =
      widget.existingShift?.startTime ?? const TimeOfDay(hour: 8, minute: 0);
  late TimeOfDay _endTime =
      widget.existingShift?.endTime ?? const TimeOfDay(hour: 16, minute: 0);
  final _newAttachments = <PickedShiftAttachment>[];

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    // Arriving with a task already chosen (from the task's own screen):
    // start the dates on that task's span.
    final taskId = _taskId;
    if (!_isEditing && taskId != null) {
      final task = ref
          .read(taskListProvider)
          .valueOrNull
          ?.where((t) => t.id == taskId)
          .firstOrNull;
      if (task != null) {
        _workDate = task.startDate;
        _endDate = task.endDate;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Exactly one shift will be created (or we're editing one), so a file can
  /// sensibly be attached to it.
  bool get _singleShiftResult =>
      _isEditing || (_employeeIds.length <= 1 && _workDate == _endDate);

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    setState(() {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes != null) {
          _newAttachments.add(
            PickedShiftAttachment(fileName: file.name, bytes: bytes),
          );
        }
      }
    });
  }

  Future<void> _deleteExistingAttachment(String id, String storagePath) async {
    try {
      await ref.read(shiftRepositoryProvider).deleteAttachment(id, storagePath);
      ref.invalidate(shiftAttachmentsProvider(widget.existingShift!.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _workDate : _endDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _workDate = picked;
        if (_isEditing || _endDate.isBefore(_workDate)) _endDate = _workDate;
      } else {
        _endDate = picked;
      }
    });
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

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) return;

    if (_isEditing ? _employeeId == null : _employeeIds.isEmpty) {
      _showError(
        _isEditing
            ? l10n.employeeRequiredError
            : l10n.atLeastOneEmployeeRequiredError,
      );
      return;
    }
    if (!_isEditing && _endDate.isBefore(_workDate)) {
      _showError(l10n.endDateBeforeStartError);
      return;
    }
    if (_minutesSinceMidnight(_endTime) <= _minutesSinceMidnight(_startTime)) {
      _showError(l10n.endTimeBeforeStartError);
      return;
    }

    final notifier = ref.read(addShiftControllerProvider.notifier);
    final notes = _notesController.text.trim();
    final count = _isEditing
        ? 1
        : _employeeIds.length * (_endDate.difference(_workDate).inDays + 1);

    final success = _isEditing
        ? await notifier.update(
            companyId: widget.companyId,
            shiftId: widget.existingShift!.id,
            employeeId: _employeeId!,
            projectId: _projectId,
            taskId: _taskId,
            workDate: _workDate,
            startTime: _startTime,
            endTime: _endTime,
            notes: notes,
            attachments: _newAttachments,
          )
        : await notifier.submit(
            companyId: widget.companyId,
            employeeIds: _employeeIds.toList(),
            projectId: _projectId,
            taskId: _taskId,
            startDate: _workDate,
            endDate: _endDate,
            startTime: _startTime,
            endTime: _endTime,
            notes: notes,
            attachments: _newAttachments,
          );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? l10n.shiftUpdatedSuccess
                : l10n.shiftsAddedSuccess(count),
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
    final projectTasks = _projectId == null
        ? const []
        : (ref.watch(taskListProvider).valueOrNull ?? const [])
              .where((task) => task.projectId == _projectId)
              .toList();
    // A task that no longer exists on this project (e.g. after switching
    // project) can't stay selected in the dropdown.
    final taskValue = projectTasks.any((t) => t.id == _taskId) ? _taskId : null;

    ref.listen<AsyncValue<void>>(addShiftControllerProvider, (previous, next) {
      next.whenOrNull(error: (error, _) => _showError(error.toString()));
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editShiftTitle : l10n.addShiftTitle),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                            : (value) => setState(() {
                                _projectId = value;
                                _taskId = null;
                              }),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) => Text(error.toString()),
                    ),
                    if (_projectId != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        key: ValueKey('task-$_projectId'),
                        initialValue: taskValue,
                        decoration: InputDecoration(
                          labelText: l10n.taskOptionalLabel,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.noTaskOption),
                          ),
                          for (final task in projectTasks)
                            DropdownMenuItem(
                              value: task.id,
                              child: Text(task.title),
                            ),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() {
                                _taskId = value;
                                final task = projectTasks
                                    .where((t) => t.id == value)
                                    .firstOrNull;
                                if (!_isEditing && task != null) {
                                  _workDate = task.startDate;
                                  _endDate = task.endDate;
                                }
                              }),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_isEditing)
                      employeesAsync.when(
                        data: (employees) => DropdownButtonFormField<String>(
                          initialValue: _employeeId,
                          decoration: InputDecoration(
                            labelText: l10n.employeeLabel,
                          ),
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
                      )
                    else ...[
                      Text(
                        l10n.employeesLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      employeesAsync.when(
                        data: (employees) => Column(
                          children: [
                            for (final employee in employees)
                              CheckboxListTile(
                                value: _employeeIds.contains(employee.id),
                                title: Text(employee.fullName),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                onChanged: isLoading
                                    ? null
                                    : (checked) => setState(() {
                                        if (checked ?? false) {
                                          _employeeIds.add(employee.id);
                                        } else {
                                          _employeeIds.remove(employee.id);
                                        }
                                      }),
                              ),
                          ],
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) => Text(error.toString()),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_isEditing)
                      InkWell(
                        onTap: isLoading
                            ? null
                            : () => _pickDate(isStart: true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.workDateLabel,
                          ),
                          child: Text(_formatDate(_workDate)),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isLoading
                                  ? null
                                  : () => _pickDate(isStart: true),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.taskFromDateLabel,
                                ),
                                child: Text(_formatDate(_workDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: isLoading
                                  ? null
                                  : () => _pickDate(isStart: false),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.taskToDateLabel,
                                ),
                                child: Text(_formatDate(_endDate)),
                              ),
                            ),
                          ),
                        ],
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
                    if (_singleShiftResult) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.attachmentsSectionLabel,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isEditing)
                        Consumer(
                          builder: (context, ref, _) {
                            final attachments =
                                ref
                                    .watch(
                                      shiftAttachmentsProvider(
                                        widget.existingShift!.id,
                                      ),
                                    )
                                    .valueOrNull ??
                                const [];
                            if (attachments.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final attachment in attachments)
                                    Chip(
                                      label: Text(
                                        attachment.fileName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onDeleted: isLoading
                                          ? null
                                          : () => _deleteExistingAttachment(
                                              attachment.id,
                                              attachment.storagePath,
                                            ),
                                      deleteButtonTooltipMessage:
                                          l10n.removeAttachmentTooltip,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (_newAttachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final attachment in _newAttachments)
                                Chip(
                                  label: Text(
                                    attachment.fileName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onDeleted: isLoading
                                      ? null
                                      : () => setState(
                                          () => _newAttachments.remove(
                                            attachment,
                                          ),
                                        ),
                                  deleteButtonTooltipMessage:
                                      l10n.removeAttachmentTooltip,
                                ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: isLoading ? null : _pickAttachments,
                          icon: const Icon(Icons.attach_file),
                          label: Text(l10n.addAttachmentButton),
                        ),
                      ),
                    ],
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
        ),
      ),
    );
  }
}
