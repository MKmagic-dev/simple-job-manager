import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/work_photo_repository.dart';
import 'add_work_photo_screen.dart';

/// Shared between the boss and worker apps — RLS already restricts which
/// rows come back (see WorkPhotoRepository.fetchWorkPhotos), so the only
/// difference between the two roles here is whether the "add" button shows
/// (only employees can upload work photos, per the work_photos RLS policies).
class WorkPhotoListScreen extends ConsumerWidget {
  const WorkPhotoListScreen({
    super.key,
    required this.companyId,
    required this.employeeId,
    required this.isOwner,
  });

  final String companyId;
  final String employeeId;
  final bool isOwner;

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final photosAsync = ref.watch(workPhotoListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.workPhotosTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(workPhotoListProvider.future),
        child: photosAsync.when(
          data: (photos) {
            if (photos.isEmpty) {
              final emptyText = isOwner ? l10n.noWorkPhotosUploadedYet : l10n.noWorkPhotosYet;
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: Text(emptyText)),
                  ),
                ),
              );
            }

            return GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return _WorkPhotoThumbnail(
                  storagePath: photo.storagePath,
                  caption: photo.caption,
                  date: _formatDate(photo.createdAt),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
      floatingActionButton: isOwner
          ? null
          : FloatingActionButton(
              tooltip: l10n.addWorkPhotoTooltip,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddWorkPhotoScreen(
                      companyId: companyId,
                      employeeId: employeeId,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add_a_photo_outlined),
            ),
    );
  }
}

class _WorkPhotoThumbnail extends ConsumerWidget {
  const _WorkPhotoThumbnail({required this.storagePath, this.caption, required this.date});

  final String storagePath;
  final String? caption;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedUrlAsync = ref.watch(workPhotoSignedUrlProvider(storagePath));

    return GestureDetector(
      onTap: () => _showFullScreen(context, signedUrlAsync.valueOrNull),
      child: signedUrlAsync.when(
        data: (url) => Image.network(url, fit: BoxFit.cover),
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  void _showFullScreen(BuildContext context, String? url) {
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(child: Image.network(url)),
            if (caption != null && caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(caption!),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(date, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
