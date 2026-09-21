import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/generated/app_localizations.dart';

/// A file the user picked (camera, gallery or file browser) that's still in
/// memory, waiting to be uploaded.
class PickedFileData {
  const PickedFileData({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// Asks where the file should come from (camera / photo library / PDF or
/// other file) and returns it, or null if the user backed out.
Future<PickedFileData?> pickPhotoOrFile(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showModalBottomSheet<_PickSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.takePhotoOption),
            onTap: () => Navigator.of(context).pop(_PickSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.choosePhotoOption),
            onTap: () => Navigator.of(context).pop(_PickSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l10n.chooseFileOption),
            onTap: () => Navigator.of(context).pop(_PickSource.file),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return null;

  switch (choice) {
    case _PickSource.camera:
    case _PickSource.gallery:
      final xFile = await ImagePicker().pickImage(
        source: choice == _PickSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (xFile == null) return null;
      final name = xFile.name.contains('.') ? xFile.name : '${xFile.name}.jpg';
      return PickedFileData(fileName: name, bytes: await xFile.readAsBytes());
    case _PickSource.file:
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: true,
      );
      final file = result?.files.firstOrNull;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return null;
      return PickedFileData(fileName: file.name, bytes: bytes);
  }
}

/// Multi-select from the file browser (PDF/JPG/PNG), for forms that collect
/// several attachments before saving.
Future<List<PickedFileData>> pickManyFiles() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: _allowedExtensions,
    allowMultiple: true,
    withData: true,
  );
  if (result == null) return const [];
  return [
    for (final file in result.files)
      if (file.bytes != null)
        PickedFileData(fileName: file.name, bytes: file.bytes!),
  ];
}

enum _PickSource { camera, gallery, file }
