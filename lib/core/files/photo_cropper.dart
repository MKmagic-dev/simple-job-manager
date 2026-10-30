import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Opens a full-screen cropper for [bytes]: the photo can be dragged and
/// zoomed under a fixed frame of [aspectRatio], and the framed part comes back
/// as a PNG. Returns null if the user backs out.
Future<Uint8List?> cropPhoto(
  BuildContext context,
  Uint8List bytes, {
  double aspectRatio = 16 / 9,
  bool circle = false,
}) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => PhotoCropScreen(
        bytes: bytes,
        aspectRatio: aspectRatio,
        circle: circle,
      ),
    ),
  );
}

class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({
    super.key,
    required this.bytes,
    this.aspectRatio = 16 / 9,
    this.circle = false,
  });

  final Uint8List bytes;
  final double aspectRatio;

  /// Show a round guide (for profile photos, which are displayed in a circle).
  /// The result is still a square image.
  final bool circle;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _controller = CropController();
  bool _ready = false;
  bool _cropping = false;

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cropPhotoFailedError),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cropPhotoTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _ready && !_cropping
                  ? () {
                      setState(() => _cropping = true);
                      _controller.crop();
                    }
                  : null,
              child: _cropping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.cropPhotoDoneButton),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Crop(
                image: widget.bytes,
                controller: _controller,
                aspectRatio: widget.aspectRatio,
                withCircleUi: widget.circle,
                // The photo moves and zooms under a fixed frame.
                interactive: true,
                fixCropRect: true,
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.6),
                onCropped: _onCropped,
                onStatusChanged: (status) {
                  final ready =
                      status == CropStatus.ready ||
                      status == CropStatus.cropping;
                  if (ready != _ready && mounted) {
                    setState(() => _ready = ready);
                  }
                },
                progressIndicator: const CircularProgressIndicator(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.cropPhotoHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
