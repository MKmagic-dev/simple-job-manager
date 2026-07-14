import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'add_project_controller.dart';

class AddProjectScreen extends ConsumerStatefulWidget {
  const AddProjectScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends ConsumerState<AddProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final now = DateTime.now();
    final initial = (isStartDate ? _startDate : _endDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStartDate) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(addProjectControllerProvider.notifier).submit(
          companyId: widget.companyId,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          description: _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.projectAddedSuccess)),
      );
      Navigator.of(context).pop();
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final submitState = ref.watch(addProjectControllerProvider);
    final isLoading = submitState.isLoading;

    ref.listen<AsyncValue<void>>(addProjectControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addProjectTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.projectNameLabel),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.projectNameRequiredError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.addressLabel),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !isLoading,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l10n.descriptionLabel),
                ),
                const SizedBox(height: 16),
                _DatePickerRow(
                  label: l10n.startDateLabel,
                  value: _startDate,
                  formatDate: _formatDate,
                  selectDateLabel: l10n.selectDateButton,
                  enabled: !isLoading,
                  onTap: () => _pickDate(isStartDate: true),
                ),
                const SizedBox(height: 12),
                _DatePickerRow(
                  label: l10n.endDateLabel,
                  value: _endDate,
                  formatDate: _formatDate,
                  selectDateLabel: l10n.selectDateButton,
                  enabled: !isLoading,
                  onTap: () => _pickDate(isStartDate: false),
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

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.formatDate,
    required this.selectDateLabel,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final String Function(DateTime) formatDate;
  final String selectDateLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value != null ? formatDate(value!) : selectDateLabel),
      ),
    );
  }
}
