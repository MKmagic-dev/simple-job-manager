import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/files/picked_file.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../employees/presentation/people_checklist.dart';
import '../../profile/domain/profile_model.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_model.dart';
import '../../projects/presentation/project_people_actions.dart';
import '../data/task_repository.dart';
import '../domain/project_task_model.dart';

/// Adds a task to [project], or edits [existingTask]: a name, a date range
/// (working hours are optional — a task can just be "these days") and
/// photos/PDFs, and who does it (picked from the project's team; exact
/// working hours per person can still be set on shifts).
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.companyId,
    required this.project,
    this.existingTask,
  });

  final String companyId;
  final ProjectModel project;
  final ProjectTaskModel? existingTask;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.existingTask?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existingTask?.description ?? '',
  );

  late DateTime _startDate =
      widget.existingTask?.startDate ?? _initialStartDate();
  late DateTime _endDate = widget.existingTask?.endDate ?? _startDate;
  late bool _useHours = widget.existingTask?.hasHours ?? false;
  late TimeOfDay _startTime =
      widget.existingTask?.startTime ?? const TimeOfDay(hour: 8, minute: 0);
  late TimeOfDay _endTime =
      widget.existingTask?.endTime ?? const TimeOfDay(hour: 16, minute: 0);
  final _newFiles = <PickedFileData>[];
  bool _saving = false;

  /// The people chosen to do this task (starts from its current assignees).
  late final Set<String> _assigneeIds = {
    if (widget.existingTask != null)
      for (final assignment
          in ref.read(taskAssignmentsProvider).valueOrNull ?? const [])
        if (assignment.taskId == widget.existingTask!.id) assignment.employeeId,
  };

  bool get _isEditing => widget.existingTask != null;

  DateTime _initialStartDate() {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
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

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addFiles() async {
    final picked = await pickManyFiles();
    if (picked.isEmpty) return;
    setState(() => _newFiles.addAll(picked));
  }

  Future<void> _deleteExistingFile(String id, String storagePath) async {
    try {
      await ref.read(taskRepositoryProvider).deleteAttachment(id, storagePath);
      ref.invalidate(taskAttachmentsProvider(widget.existingTask!.id));
      ref.invalidate(projectTaskAttachmentsProvider(widget.project.id));
    } catch (error) {
      if (mounted) _showError(friendlyError(context, error));
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (_useHours && _minutes(_endTime) <= _minutes(_startTime)) {
      _showError(l10n.endTimeBeforeStartError);
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final startTime = _useHours ? _startTime : null;
      final endTime = _useHours ? _endTime : null;

      final String taskId;
      if (_isEditing) {
        taskId = widget.existingTask!.id;
        await repo.updateTask(
          taskId: taskId,
          title: title,
          description: description,
          startDate: _startDate,
          endDate: _endDate,
          startTime: startTime,
          endTime: endTime,
        );
      } else {
        taskId = await repo.createTask(
          companyId: widget.companyId,
          projectId: widget.project.id,
          title: title,
          description: description,
          startDate: _startDate,
          endDate: _endDate,
          startTime: startTime,
          endTime: endTime,
        );
      }

      await repo.setAssignees(
        taskId: taskId,
        companyId: widget.companyId,
        employeeIds: _assigneeIds,
      );

      for (final file in _newFiles) {
        await repo.uploadAttachment(
          companyId: widget.companyId,
          taskId: taskId,
          fileName: file.fileName,
          bytes: file.bytes,
        );
      }

      ref.invalidate(taskListProvider);
      ref.invalidate(taskAssignmentsProvider);
      ref.invalidate(taskAttachmentsProvider(taskId));
      ref.invalidate(projectTaskAttachmentsProvider(widget.project.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? l10n.taskUpdatedSuccess : l10n.taskAddedSuccess,
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showError(friendlyError(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editTaskTitle : l10n.addTaskTitle),
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
                    Text(
                      widget.project.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.taskNameLabel,
                        hintText: l10n.taskNameHint,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.taskNameRequiredError
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: l10n.descriptionLabel,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerField(
                            label: l10n.taskFromDateLabel,
                            value: _formatDate(_startDate),
                            enabled: !_saving,
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PickerField(
                            label: l10n.taskToDateLabel,
                            value: _formatDate(_endDate),
                            enabled: !_saving,
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.taskSetHoursLabel),
                      value: _useHours,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _useHours = value),
                    ),
                    if (_useHours) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerField(
                              label: l10n.startTimeLabel,
                              value: _formatTime(_startTime),
                              enabled: !_saving,
                              onTap: () => _pickTime(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _PickerField(
                              label: l10n.endTimeLabel,
                              value: _formatTime(_endTime),
                              enabled: !_saving,
                              onTap: () => _pickTime(isStart: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(l10n.taskAssigneesLabel, style: labelStyle),
                    const SizedBox(height: 4),
                    Text(
                      l10n.taskAssigneesHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final everyone =
                            ref.watch(employeeListProvider).valueOrNull ??
                            const <ProfileModel>[];
                        final memberIds = memberIdsOf(
                          ref.watch(projectMembersProvider).valueOrNull ??
                              const [],
                          widget.project.id,
                        );
                        // The project's team, plus anyone already on this task
                        // who has since left the team (so they stay visible).
                        final pool = [
                          for (final person in everyone)
                            if (memberIds.contains(person.id) ||
                                _assigneeIds.contains(person.id))
                              person,
                        ];
                        if (pool.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.projectHasNoPeopleHint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => addPeopleToProject(
                                        context,
                                        ref,
                                        companyId: widget.companyId,
                                        projectId: widget.project.id,
                                        alreadyOn: const {},
                                      ),
                                icon: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                ),
                                label: Text(l10n.addPeopleToProjectButton),
                              ),
                            ],
                          );
                        }
                        return PeopleChecklist(
                          people: pool,
                          selected: _assigneeIds,
                          enabled: !_saving,
                          onChanged: (value) => setState(() {
                            _assigneeIds
                              ..clear()
                              ..addAll(value);
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.taskFilesSectionLabel, style: labelStyle),
                    const SizedBox(height: 8),
                    if (_isEditing)
                      Consumer(
                        builder: (context, ref, _) {
                          final attachments =
                              ref
                                  .watch(
                                    taskAttachmentsProvider(
                                      widget.existingTask!.id,
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
                                    onDeleted: _saving
                                        ? null
                                        : () => _deleteExistingFile(
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
                    if (_newFiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final file in _newFiles)
                              Chip(
                                label: Text(
                                  file.fileName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onDeleted: _saving
                                    ? null
                                    : () => setState(
                                        () => _newFiles.remove(file),
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
                        onPressed: _saving ? null : _addFiles,
                        icon: const Icon(Icons.attach_file),
                        label: Text(l10n.addAttachmentButton),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}
