import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';

/// A photo thumbnail (tap → full-screen viewer with a close button) or a PDF
/// chip (tap → opens in the system viewer), with an optional caption line
/// underneath such as "Added by Anna · 12 Sep". Works for any attachment
/// source — pass the family provider that resolves its signed URL.
class AttachmentTile extends ConsumerWidget {
  const AttachmentTile({
    super.key,
    required this.isImage,
    required this.fileName,
    required this.urlProvider,
    this.caption,
    this.size = 96,
  });

  final bool isImage;
  final String fileName;
  final AutoDisposeFutureProvider<String> urlProvider;
  final String? caption;
  final double size;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final url = await ref.read(urlProvider.future);
      if (!context.mounted) return;

      if (isImage) {
        _showViewer(context, url);
        return;
      }

      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotOpenAttachmentError)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotOpenAttachmentError)),
        );
      }
    }
  }

  void _showViewer(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: InteractiveViewer(child: Image.network(url)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final Widget tile;
    if (isImage) {
      tile = GestureDetector(
        onTap: () => _open(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: size,
            height: size,
            color: colorScheme.surfaceContainerHighest,
            child: ref
                .watch(urlProvider)
                .when(
                  data: (url) => Image.network(url, fit: BoxFit.cover),
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (error, stackTrace) =>
                      const Icon(Icons.broken_image_outlined),
                ),
          ),
        ),
      );
    } else {
      tile = InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context, ref),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 32),
              const SizedBox(height: 6),
              Text(
                fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      );
    }

    if (caption == null) return tile;

    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tile,
          const SizedBox(height: 4),
          Text(
            caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
