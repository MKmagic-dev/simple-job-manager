import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/unread/last_seen_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/domain/shift_model.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/work_photo_repository.dart';
import '../domain/work_photo_model.dart';
import 'add_work_photo_screen.dart';

/// Shared between the boss and worker apps — RLS already restricts which
/// rows come back (see WorkPhotoRepository.fetchWorkPhotos). For the boss
/// this shows every employee's photos grouped by person then by shift; for
/// an employee (who only ever gets their own rows back) it's just a flat
/// grid, since grouping by person would be pointless.
class WorkPhotoListScreen extends ConsumerStatefulWidget {
  const WorkPhotoListScreen({
    super.key,
    required this.companyId,
    required this.employeeId,
    required this.isOwner,
  });

  final String companyId;
  final String employeeId;
  final bool isOwner;

  @override
  ConsumerState<WorkPhotoListScreen> createState() =>
      _WorkPhotoListScreenState();
}

class _WorkPhotoListScreenState extends ConsumerState<WorkPhotoListScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isOwner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(lastSeenWorkPhotosProvider.notifier).markSeenNow();
      });
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final photosAsync = ref.watch(workPhotoListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.workPhotosTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(workPhotoListProvider.future),
        child: photosAsync.when(
          data: (photos) {
            if (photos.isEmpty) {
              final emptyText = widget.isOwner
                  ? l10n.noWorkPhotosUploadedYet
                  : l10n.noWorkPhotosYet;
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(child: Text(emptyText)),
                  ),
                ),
              );
            }

            return widget.isOwner
                ? _GroupedByPerson(photos: photos)
                : _FlatGrid(photos: photos, formatDate: _formatDate);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
      floatingActionButton: widget.isOwner
          ? null
          : FloatingActionButton(
              tooltip: l10n.addWorkPhotoTooltip,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddWorkPhotoScreen(
                      companyId: widget.companyId,
                      employeeId: widget.employeeId,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add_a_photo_outlined),
            ),
    );
  }
}

class _FlatGrid extends StatelessWidget {
  const _FlatGrid({required this.photos, required this.formatDate});

  final List<WorkPhotoModel> photos;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
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
          date: formatDate(photo.createdAt),
        );
      },
    );
  }
}

class _GroupedByPerson extends ConsumerWidget {
  const _GroupedByPerson({required this.photos});

  final List<WorkPhotoModel> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final employeesAsync = ref.watch(employeeListProvider);
    final shiftsAsync = ref.watch(shiftListProvider);
    final employees = employeesAsync.valueOrNull ?? const [];
    final shifts = shiftsAsync.valueOrNull ?? const [];

    final byEmployee = <String, List<WorkPhotoModel>>{};
    for (final photo in photos) {
      byEmployee.putIfAbsent(photo.employeeId, () => []).add(photo);
    }
    final employeeIds = byEmployee.keys.toList()
      ..sort((a, b) {
        final nameA =
            employees
                .where((e) => e.id == a)
                .map((e) => e.fullName)
                .firstOrNull ??
            '';
        final nameB =
            employees
                .where((e) => e.id == b)
                .map((e) => e.fullName)
                .firstOrNull ??
            '';
        return nameA.compareTo(nameB);
      });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final employeeId in employeeIds)
          _EmployeeSection(
            name:
                employees
                    .where((e) => e.id == employeeId)
                    .map((e) => e.fullName)
                    .firstOrNull ??
                '?',
            avatarUrl: employees
                .where((e) => e.id == employeeId)
                .map((e) => e.avatarUrl)
                .firstOrNull,
            photos: byEmployee[employeeId]!,
            shifts: shifts,
            locale: locale,
            noShiftLabel: l10n.noShiftOption,
          ),
      ],
    );
  }
}

class _EmployeeSection extends StatelessWidget {
  const _EmployeeSection({
    required this.name,
    required this.avatarUrl,
    required this.photos,
    required this.shifts,
    required this.locale,
    required this.noShiftLabel,
  });

  final String name;
  final String? avatarUrl;
  final List<WorkPhotoModel> photos;
  final List<ShiftModel> shifts;
  final String locale;
  final String noShiftLabel;

  String _shiftLabel(String? shiftId) {
    if (shiftId == null) return noShiftLabel;
    final shift = shifts.where((s) => s.id == shiftId).firstOrNull;
    if (shift == null) return noShiftLabel;
    return '${DateFormat.yMMMd(locale).format(shift.workDate)} '
        '${formatTime(shift.startTime)}–${formatTime(shift.endTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final byShift = <String?, List<WorkPhotoModel>>{};
    for (final photo in photos) {
      byShift.putIfAbsent(photo.shiftId, () => []).add(photo);
    }
    final shiftKeys = byShift.keys.toList()
      ..sort((a, b) => _shiftLabel(b).compareTo(_shiftLabel(a)));

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        child: avatarUrl == null ? Text(initialsOf(name)) : null,
      ),
      title: Text(name),
      subtitle: Text('${photos.length}'),
      children: [
        for (final shiftKey in shiftKeys)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shiftLabel(shiftKey),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final photo in byShift[shiftKey]!)
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: _WorkPhotoThumbnail(
                          storagePath: photo.storagePath,
                          caption: photo.caption,
                          date: DateFormat.yMMMd(
                            locale,
                          ).format(photo.createdAt),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WorkPhotoThumbnail extends ConsumerWidget {
  const _WorkPhotoThumbnail({
    required this.storagePath,
    this.caption,
    required this.date,
  });

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
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  void _showFullScreen(BuildContext context, String? url) {
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: InteractiveViewer(child: Image.network(url)),
                ),
                if (caption != null && caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(caption!),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    date,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
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
}
