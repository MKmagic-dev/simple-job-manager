import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import 'add_instruction_controller.dart';

class AddInstructionScreen extends ConsumerStatefulWidget {
  const AddInstructionScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<AddInstructionScreen> createState() => _AddInstructionScreenState();
}

class _AddInstructionScreenState extends ConsumerState<AddInstructionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String? _employeeId;
  final _attachments = <PickedAttachment>[];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

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
          _attachments.add(PickedAttachment(fileName: file.name, bytes: bytes));
        }
      }
    });
  }

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

    final success = await ref.read(addInstructionControllerProvider.notifier).submit(
          companyId: widget.companyId,
          employeeId: _employeeId!,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          attachments: _attachments,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.instructionAddedSuccess)),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final submitState = ref.watch(addInstructionControllerProvider);
    final isLoading = submitState.isLoading;
    final employeesAsync = ref.watch(employeeListProvider);

    ref.listen<AsyncValue<void>>(addInstructionControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addInstructionTitle)),
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
                        DropdownMenuItem(value: employee.id, child: Text(employee.fullName)),
                    ],
                    onChanged: isLoading ? null : (value) => setState(() => _employeeId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text(error.toString()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.instructionTitleLabel),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.instructionTitleRequiredError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  enabled: !isLoading,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: l10n.instructionContentLabel),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.attachmentsSectionLabel, style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                if (_attachments.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final attachment in _attachments)
                        Chip(
                          label: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
                          onDeleted: isLoading
                              ? null
                              : () => setState(() => _attachments.remove(attachment)),
                          deleteButtonTooltipMessage: l10n.removeAttachmentTooltip,
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _pickAttachments,
                  icon: const Icon(Icons.attach_file),
                  label: Text(l10n.addAttachmentButton),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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
