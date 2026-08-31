import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../profile/domain/profile_model.dart';
import '../data/employee_repository.dart';

/// Shown when tapping someone in the team list. Only offers "remove from
/// team" for role=employee rows — removing a co-boss isn't something this
/// screen does (that's the separate demote flow on the list itself), and
/// there's no RLS policy letting an owner delete another owner's row here.
class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.member,
    required this.canRemove,
  });

  final ProfileModel member;
  final bool canRemove;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFromTeamTooltip),
        content: Text(l10n.removeFromTeamConfirmMessage(member.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(employeeRepositoryProvider).deleteEmployee(member.id);
      ref.invalidate(employeeListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.employeeRemovedSuccess)));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.memberDetailsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: member.avatarUrl != null
                      ? NetworkImage(member.avatarUrl!)
                      : null,
                  child: member.avatarUrl == null
                      ? const Icon(Icons.person_outline, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  member.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  member.role == UserRole.boss
                      ? l10n.roleOwnerLabel
                      : l10n.roleEmployeeLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: Text(
                  member.phone != null && member.phone!.isNotEmpty
                      ? member.phone!
                      : '—',
                ),
              ),
              if (canRemove) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _confirmRemove(context, ref),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: Text(l10n.removeFromTeamTooltip),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
