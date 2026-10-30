import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_cropper.dart';

/// A profile photo chosen from the gallery and framed by the user, already
/// shrunk to a sensible size.
class PickedProfilePhoto {
  const PickedProfilePhoto({required this.bytes, required this.extension});

  final Uint8List bytes;

  /// File extension without the dot, e.g. `png`.
  final String extension;
}

/// Lets the user pick a photo from the gallery and then move/zoom it inside a
/// round frame (profile photos are shown in a circle, so a logo or a wide
/// photo would otherwise get cut off at random). Returns null if they back out.
/// Photos are scaled down (max 800px) before framing.
Future<PickedProfilePhoto?> pickProfilePhoto(BuildContext context) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    imageQuality: 85,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;

  final framed = await cropPhoto(context, bytes, aspectRatio: 1, circle: true);
  if (framed == null) return null;
  return PickedProfilePhoto(bytes: framed, extension: 'png');
}
