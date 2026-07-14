import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../data/instruction_repository.dart';
import 'add_instruction_screen.dart';

/// Shared between the boss and worker apps — RLS already restricts which
/// rows come back (see InstructionRepository.fetchInstructions), so the only
/// difference between the two roles here is whether the "add" button shows.
class InstructionListScreen extends ConsumerWidget {
  const InstructionListScreen({
    super.key,
    required this.companyId,
    required this.isOwner,
  });

  final String companyId;
  final bool isOwner;

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final instructionsAsync = ref.watch(instructionListProvider);
    final employeesAsync = isOwner ? ref.watch(employeeListProvider) : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.instructionsTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(instructionListProvider.future),
        child: instructionsAsync.when(
          data: (instructions) {
            if (instructions.isEmpty) {
              final emptyText = isOwner ? l10n.noInstructionsSentYet : l10n.noInstructionsYet;
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

            final employeeNames = {
              for (final employee in employeesAsync?.valueOrNull ?? []) employee.id: employee.fullName,
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
                  if (instruction.content != null && instruction.content!.isNotEmpty)
                    instruction.content!,
                ];
                return ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(instruction.title),
                  subtitle: Text(subtitleParts.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              tooltip: l10n.addInstructionTooltip,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AddInstructionScreen(companyId: companyId)),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
