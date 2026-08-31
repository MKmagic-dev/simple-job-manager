import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/project_repository.dart';
import '../domain/project_attachment_model.dart';
import '../domain/project_model.dart';
import 'add_project_screen.dart';

/// Shows everything about a project — description, duration, who's
/// assigned (derived from shifts), and its attached files/photos — with an
/// Edit button at the bottom for making changes.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({
    super.key,
    required this.companyId,
    required this.project,
  });

  final String companyId;
  final ProjectModel project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final shiftsAsync = ref.watch(shiftListProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final attachmentsAsync = ref.watch(projectAttachmentsProvider(project.id));

    final assignedIds = {
      for (final shift in shiftsAsync.valueOrNull ?? const [])
        if (shift.projectId == project.id) shift.employeeId,
    };
    final assignedEmployees = (employeesAsync.valueOrNull ?? const [])
        .where((employee) => assignedIds.contains(employee.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (project.address != null && project.address!.isNotEmpty) ...[
                Text(
                  project.address!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
              if (project.description != null &&
                  project.description!.isNotEmpty) ...[
                Text(
                  l10n.descriptionLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(project.description!),
                const SizedBox(height: 16),
              ],
              if (project.startDate != null || project.endDate != null) ...[
                Text(
                  l10n.durationLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (project.startDate != null)
                      DateFormat.yMMMd(locale).format(project.startDate!),
                    if (project.endDate != null)
                      DateFormat.yMMMd(locale).format(project.endDate!),
                  ].join(' – '),
                ),
                const SizedBox(height: 16),
              ],
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
                            _AttachmentTile(attachment: attachment),
                        ],
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text(error.toString()),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AddProjectScreen(
                        companyId: companyId,
                        existingProject: project,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.editButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({required this.attachment});

  final ProjectAttachmentModel attachment;

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
    if (attachment.isImage) {
      final signedUrlAsync = ref.watch(
        projectAttachmentSignedUrlProvider(attachment.storagePath),
      );
      return GestureDetector(
        onTap: () => _open(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 90,
            height: 90,
            child: signedUrlAsync.when(
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
    }

    return ActionChip(
      avatar: const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
      onPressed: () => _open(context, ref),
    );
  }
}
