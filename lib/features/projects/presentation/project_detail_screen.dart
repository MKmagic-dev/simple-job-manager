import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/project_repository.dart';
import '../domain/project_attachment_model.dart';
import '../domain/project_completion_notice_model.dart';
import '../domain/project_model.dart';
import 'add_project_screen.dart';

/// Shows everything about a project — description, duration, who's
/// assigned (derived from shifts), and its attached files/photos.
///
/// For the owner: an Edit button, and any "project completed" notices
/// employees have sent (dismissible once acknowledged).
/// For an employee viewing a project they're assigned to: no edit/delete —
/// instead an "Add photo" button (uploads as themselves) and a "Project
/// completed" button that just notifies the owner, without changing
/// anything about the project itself.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.companyId,
    required this.project,
    required this.isOwner,
  });

  final String companyId;
  final ProjectModel project;
  final bool isOwner;

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  bool _uploadingAttachment = false;

  Future<void> _pickAndUploadAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    setState(() => _uploadingAttachment = true);
    try {
      await ref
          .read(projectRepositoryProvider)
          .uploadAttachment(
            companyId: widget.companyId,
            projectId: widget.project.id,
            fileName: file.name,
            bytes: bytes,
          );
      ref.invalidate(projectAttachmentsProvider(widget.project.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _confirmMarkCompleted() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectCompletedButton),
        content: Text(l10n.projectCompletedConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(projectRepositoryProvider)
          .submitCompletionNotice(widget.project.id);
      ref.invalidate(projectCompletionNoticeListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.projectCompletedNoticeSentSuccess)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _dismissNotice(String id) async {
    await ref.read(projectRepositoryProvider).dismissCompletionNotice(id);
    ref.invalidate(projectCompletionNoticeListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final shiftsAsync = ref.watch(shiftListProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final ownersAsync = ref.watch(ownerListProvider);
    final attachmentsAsync = ref.watch(
      projectAttachmentsProvider(widget.project.id),
    );

    // Only meaningful (and only resolvable via RLS) for the owner — an
    // employee's profiles_select policy only lets them see their own row.
    final peopleById = <String, ProfileModel>{
      for (final person in employeesAsync.valueOrNull ?? const [])
        person.id: person,
      for (final person in ownersAsync.valueOrNull ?? const [])
        person.id: person,
    };

    final assignedIds = {
      for (final shift in shiftsAsync.valueOrNull ?? const [])
        if (shift.projectId == widget.project.id) shift.employeeId,
    };
    final assignedEmployees = (employeesAsync.valueOrNull ?? const [])
        .where((employee) => assignedIds.contains(employee.id))
        .toList();

    final projectNotices = widget.isOwner
        ? (ref.watch(projectCompletionNoticeListProvider).valueOrNull ??
                  const [])
              .where((notice) => notice.projectId == widget.project.id)
              .toList()
        : const <ProjectCompletionNoticeModel>[];

    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.project.address != null &&
                  widget.project.address!.isNotEmpty) ...[
                Text(
                  widget.project.address!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
              if (widget.project.description != null &&
                  widget.project.description!.isNotEmpty) ...[
                Text(
                  l10n.descriptionLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(widget.project.description!),
                const SizedBox(height: 16),
              ],
              if (widget.project.startDate != null ||
                  widget.project.endDate != null) ...[
                Text(
                  l10n.durationLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (widget.project.startDate != null)
                      DateFormat.yMMMd(
                        locale,
                      ).format(widget.project.startDate!),
                    if (widget.project.endDate != null)
                      DateFormat.yMMMd(locale).format(widget.project.endDate!),
                  ].join(' – '),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.isOwner) ...[
                Text(
                  l10n.assignedEmployeesLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (assignedEmployees.isEmpty)
                  Text(
                    l10n.noAssignedEmployeesLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final employee in assignedEmployees)
                        Chip(
                          avatar: CircleAvatar(
                            backgroundImage: employee.avatarUrl != null
                                ? NetworkImage(employee.avatarUrl!)
                                : null,
                            child: employee.avatarUrl == null
                                ? Text(initialsOf(employee.fullName))
                                : null,
                          ),
                          label: Text(employee.fullName),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                if (projectNotices.isNotEmpty) ...[
                  Text(
                    l10n.completionNoticesSectionLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  for (final notice in projectNotices)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.completedByLabel(
                                peopleById[notice.employeeId]?.fullName ?? '?',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: l10n.dismissChangeRequestTooltip,
                            onPressed: () => _dismissNotice(notice.id),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
              Text(
                l10n.galleryLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              attachmentsAsync.when(
                data: (attachments) => attachments.isEmpty
                    ? Text(
                        l10n.noGalleryLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final attachment in attachments)
                            _AttachmentTile(
                              attachment: attachment,
                              uploaderName: widget.isOwner
                                  ? peopleById[attachment.uploadedBy]?.fullName
                                  : null,
                              locale: locale,
                            ),
                        ],
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text(error.toString()),
              ),
              const SizedBox(height: 24),
              if (widget.isOwner)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AddProjectScreen(
                          companyId: widget.companyId,
                          existingProject: widget.project,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.editButton),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: _uploadingAttachment
                      ? null
                      : _pickAndUploadAttachment,
                  icon: _uploadingAttachment
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined),
                  label: Text(l10n.addAttachmentButton),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _confirmMarkCompleted,
                  icon: const Icon(Icons.task_alt_outlined),
                  label: Text(l10n.projectCompletedButton),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.uploaderName,
    required this.locale,
  });

  final ProjectAttachmentModel attachment;
  final String? uploaderName;
  final String locale;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final url = await ref.read(
        projectAttachmentSignedUrlProvider(attachment.storagePath).future,
      );
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final caption = uploaderName == null
        ? null
        : '${l10n.addedByLabel} $uploaderName · ${DateFormat.yMMMd(locale).format(attachment.createdAt)}';

    final tile = attachment.isImage
        ? GestureDetector(
            onTap: () => _open(context, ref),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 90,
                height: 90,
                child: Consumer(
                  builder: (context, ref, _) {
                    final signedUrlAsync = ref.watch(
                      projectAttachmentSignedUrlProvider(
                        attachment.storagePath,
                      ),
                    );
                    return signedUrlAsync.when(
                      data: (url) => Image.network(url, fit: BoxFit.cover),
                      loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined),
                    );
                  },
                ),
              ),
            ),
          )
        : ActionChip(
            avatar: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
            onPressed: () => _open(context, ref),
          );

    if (caption == null) return tile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile,
        Text(caption, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
