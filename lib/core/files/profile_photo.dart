import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// A profile photo chosen from the gallery, already shrunk to a sensible size.
class PickedProfilePhoto {
  const PickedProfilePhoto({required this.bytes, required this.extension});

  final Uint8List bytes;

  /// File extension without the dot, e.g. `jpg`.
  final String extension;
}

/// Lets the user pick a photo from the gallery, or returns null if they
/// back out. Photos are scaled down (max 800px) before upload.
Future<PickedProfilePhoto?> pickProfilePhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    imageQuality: 85,
  );
  if (file == null) return null;

  final name = file.name.isNotEmpty ? file.name : file.path;
  final extension = name.contains('.') ? name.split('.').last : 'jpg';
  return PickedProfilePhoto(
    bytes: await file.readAsBytes(),
    extension: extension.toLowerCase(),
  );
}
