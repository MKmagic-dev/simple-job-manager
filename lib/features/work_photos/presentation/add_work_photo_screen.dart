import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../shifts/data/shift_repository.dart';
import 'add_work_photo_controller.dart';

class AddWorkPhotoScreen extends ConsumerStatefulWidget {
  const AddWorkPhotoScreen({
    super.key,
    required this.companyId,
    required this.employeeId,
  });

  final String companyId;
  final String employeeId;

  @override
  ConsumerState<AddWorkPhotoScreen> createState() => _AddWorkPhotoScreenState();
}

class _AddWorkPhotoScreenState extends ConsumerState<AddWorkPhotoScreen> {
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();

  Uint8List? _pickedBytes;
  String? _pickedExtension;
  String? _shiftId;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();
    final extension = xFile.path.contains('.')
        ? xFile.path.split('.').last
        : 'jpg';
    setState(() {
      _pickedBytes = bytes;
      _pickedExtension = extension;
    });
  }

  Future<void> _showPickerOptions() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhotoOption),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.choosePhotoOption),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    if (_pickedBytes == null || _pickedExtension == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.selectPhotoRequiredError)));
      return;
    }

    final success = await ref
        .read(addWorkPhotoControllerProvider.notifier)
        .submit(
          companyId: widget.companyId,
          employeeId: widget.employeeId,
          shiftId: _shiftId,
          caption: _captionController.text.trim(),
          bytes: _pickedBytes!,
          fileExtension: _pickedExtension!,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.workPhotoAddedSuccess)));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final submitState = ref.watch(addWorkPhotoControllerProvider);
    final isLoading = submitState.isLoading;
    final shiftsAsync = ref.watch(shiftListProvider);

    ref.listen<AsyncValue<void>>(addWorkPhotoControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addWorkPhotoTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: isLoading ? null : _showPickerOptions,
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _pickedBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _pickedBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_a_photo_outlined, size: 40),
                              const SizedBox(height: 8),
                              Text(l10n.addWorkPhotoTitle),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              shiftsAsync.when(
                data: (shifts) => DropdownButtonFormField<String?>(
                  initialValue: _shiftId,
                  decoration: InputDecoration(
                    labelText: l10n.shiftOptionalLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.noShiftOption),
                    ),
                    for (final shift in shifts)
                      DropdownMenuItem(
                        value: shift.id,
                        child: Text(
                          '${shift.workDate.year}-${shift.workDate.month.toString().padLeft(2, '0')}-${shift.workDate.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                  ],
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => _shiftId = value),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => Text(error.toString()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _captionController,
                enabled: !isLoading,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.captionLabel),
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
    );
  }
}
