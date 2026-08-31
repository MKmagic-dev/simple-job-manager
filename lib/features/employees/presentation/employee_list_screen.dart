import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../profile/domain/profile_model.dart';
import '../data/employee_repository.dart';
import 'add_employee_screen.dart';
import 'employee_detail_screen.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  Future<void> _confirmPromote(
    BuildContext context,
    WidgetRef ref,
    ProfileModel employee,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.promoteToOwnerTooltip),
        content: Text(l10n.promoteToOwnerConfirmMessage(employee.fullName)),
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

    await ref
        .read(employeeRepositoryProvider)
        .setOwnerRole(employee.id, isOwner: true);
    ref.invalidate(employeeListProvider);
    ref.invalidate(ownerListProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.ownerPromotedSuccess)));
    }
  }

  Future<void> _confirmDemote(
    BuildContext context,
    WidgetRef ref,
    ProfileModel owner,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.demoteToEmployeeTooltip),
        content: Text(l10n.demoteToEmployeeConfirmMessage(owner.fullName)),
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

    await ref
        .read(employeeRepositoryProvider)
        .setOwnerRole(owner.id, isOwner: false);
    ref.invalidate(employeeListProvider);
    ref.invalidate(ownerListProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.ownerDemotedSuccess)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final employeesAsync = ref.watch(employeeListProvider);
    final ownersAsync = ref.watch(ownerListProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employeeListProvider);
          ref.invalidate(ownerListProvider);
          await Future.wait([
            ref.read(employeeListProvider.future),
            ref.read(ownerListProvider.future),
          ]);
        },
        child: employeesAsync.when(
          data: (employees) {
            final owners = ownersAsync.valueOrNull ?? [];

            if (employees.isEmpty && owners.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(child: Text(l10n.noEmployeesYet)),
                  ),
                ),
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (owners.isNotEmpty) ...[
                  _SectionHeader(label: l10n.sectionBossesLabel),
                  for (final owner in owners)
                    ListTile(
                      leading: _MemberAvatar(
                        avatarUrl: owner.avatarUrl,
                        icon: Icons.shield_outlined,
                      ),
                      title: Text(
                        owner.id == myId
                            ? '${owner.fullName} ${l10n.youLabel}'
                            : owner.fullName,
                      ),
                      subtitle: owner.phone != null ? Text(owner.phone!) : null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EmployeeDetailScreen(
                              member: owner,
                              canRemove: false,
                            ),
                          ),
                        );
                      },
                      trailing: owner.id == myId
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.arrow_downward),
                              tooltip: l10n.demoteToEmployeeTooltip,
                              onPressed: () =>
                                  _confirmDemote(context, ref, owner),
                            ),
                    ),
                  const Divider(height: 1),
                ],
                if (employees.isNotEmpty) ...[
                  _SectionHeader(label: l10n.employeesTitle),
                  for (final employee in employees)
                    ListTile(
                      leading: _MemberAvatar(
                        avatarUrl: employee.avatarUrl,
                        icon: Icons.person_outline,
                      ),
                      title: Text(employee.fullName),
                      subtitle: employee.phone != null
                          ? Text(employee.phone!)
                          : null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EmployeeDetailScreen(
                              member: employee,
                              canRemove: true,
                            ),
                          ),
                        );
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: l10n.promoteToOwnerTooltip,
                        onPressed: () =>
                            _confirmPromote(context, ref, employee),
                      ),
                    ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addEmployeeTooltip,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddEmployeeScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.avatarUrl, required this.icon});

  final String? avatarUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null ? Icon(icon) : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
