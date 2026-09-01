import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../profile/domain/profile_model.dart';
import '../data/admin_repository.dart';

class AdminCompanyMembersScreen extends ConsumerWidget {
  const AdminCompanyMembersScreen({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  final String companyId;
  final String companyName;

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref,
    ProfileModel member,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.fullName),
        content: Text(l10n.removeMemberTooltip),
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

    await ref.read(adminRepositoryProvider).deleteProfile(member.id);
    ref.invalidate(companyMembersProvider(companyId));

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.memberRemovedSuccess)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final membersAsync = ref.watch(companyMembersProvider(companyId));

    return Scaffold(
      appBar: AppBar(title: Text(companyName)),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return Center(child: Text(l10n.noEmployeesYet));
          }
          return ListView.separated(
            itemCount: members.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              final roleLabel = member.role == UserRole.boss
                  ? l10n.roleOwnerLabel
                  : l10n.roleEmployeeLabel;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(member.fullName),
                subtitle: Text(roleLabel),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: l10n.removeMemberTooltip,
                  onPressed: () => _confirmRemoveMember(context, ref, member),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}
