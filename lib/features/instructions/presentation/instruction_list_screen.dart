import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../notes/presentation/notes_body.dart';
import '../data/instruction_repository.dart';
import '../domain/instruction_model.dart';

/// The employee's "my instructions" screen. RLS already restricts which rows
/// come back (see InstructionRepository.fetchInstructions). Read-only: new
/// instructions are always created by the boss from a project.
class InstructionListScreen extends StatelessWidget {
  const InstructionListScreen({
    super.key,
    required this.companyId,
    required this.isOwner,
  });

  final String companyId;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isOwner) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.instructionsTitle)),
        body: InstructionListBody(isOwner: isOwner),
      );
    }

    // An employee gets two tabs: the instructions for their projects, and the
    // notes their boss shared with them.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.instructionsTitle),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Theme.of(context).colorScheme.primary,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: l10n.instructionsTitle),
              Tab(text: l10n.notesTabLabel),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            InstructionListBody(isOwner: isOwner),
            const WorkerNotesBody(),
          ],
        ),
      ),
    );
  }
}

/// The instruction list without its own Scaffold, so it can sit inside a tab.
/// Pass [projectId] to show only that project's instructions.
class InstructionListBody extends ConsumerWidget {
  const InstructionListBody({
    super.key,
    required this.isOwner,
    this.projectId,
    this.emptyText,
  });

  final bool isOwner;
  final String? projectId;
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final instructionsAsync = ref.watch(instructionListProvider);
    final employeesAsync = isOwner ? ref.watch(employeeListProvider) : null;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(instructionListProvider.future),
      child: instructionsAsync.when(
        data: (all) {
          final instructions = projectId == null
              ? all
              : all.where((i) => i.projectId == projectId).toList();

          if (instructions.isEmpty) {
            final text =
                emptyText ??
                (isOwner ? l10n.noInstructionsSentYet : l10n.noInstructionsYet);
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: Text(text)),
                ),
              ),
            );
          }

          final employeeNames = {
            for (final employee in employeesAsync?.valueOrNull ?? [])
              employee.id: employee.fullName,
          };

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: instructions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final instruction = instructions[index];
              final subtitleParts = <String>[
                _formatDate(instruction.createdAt),
                if (isOwner && instruction.employeeId != null)
                  employeeNames[instruction.employeeId] ?? '?',
                if (instruction.content != null &&
                    instruction.content!.isNotEmpty)
                  instruction.content!,
              ];
              return ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(instruction.title),
                subtitle: Text(
                  subtitleParts.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => showInstructionDetails(context, instruction),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(friendlyError(context, error))),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

void showInstructionDetails(
  BuildContext context,
  InstructionModel instruction,
) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(instruction.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(instruction.createdAt)),
              if (instruction.content != null &&
                  instruction.content!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(instruction.content!),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.attachmentsSectionLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              _AttachmentsList(instructionId: instruction.id),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.closeButton),
        ),
      ],
    ),
  );
}

class _AttachmentsList extends ConsumerWidget {
  const _AttachmentsList({required this.instructionId});

  final String instructionId;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String storagePath,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final url = await ref.read(
        instructionAttachmentSignedUrlProvider(storagePath).future,
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
    final attachmentsAsync = ref.watch(
      instructionAttachmentsProvider(instructionId),
    );

    return attachmentsAsync.when(
      data: (attachments) {
        if (attachments.isEmpty) {
          return Text(
            l10n.noAttachmentsLabel,
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final attachment in attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.attach_file),
                title: Text(
                  attachment.fileName,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(context, ref, attachment.storagePath),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stackTrace) => Text(
        friendlyError(context, error),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
