import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../profile/domain/profile_model.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/employee_repository.dart';
import 'add_employee_screen.dart';
import 'employee_detail_screen.dart';

/// The team: administrators and standard members as cards (avatar, name,
/// role, phone), in a grid on wide screens. Tap a card for the person's
/// details, where the admin edits them and manages their admin rights (there
/// is deliberately no one-tap promotion on the list).
class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  void _openDetail(BuildContext context, ProfileModel member, bool canRemove) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            EmployeeDetailScreen(member: member, canRemove: canRemove),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final employeesAsync = ref.watch(employeeListProvider);
    final ownersAsync = ref.watch(ownerListProvider);
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;

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

            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 700
                    ? 2
                    : 1;
                final grid = SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 92,
                );

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (owners.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          label: l10n.sectionBossesLabel,
                          count: owners.length,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid.builder(
                          gridDelegate: grid,
                          itemCount: owners.length,
                          itemBuilder: (context, index) {
                            final owner = owners[index];
                            final isMe = owner.id == myId;
                            return _MemberCard(
                              member: owner,
                              isOwner: true,
                              isMe: isMe,
                              onTap: () => _openDetail(context, owner, false),
                            );
                          },
                        ),
                      ),
                    ],
                    if (employees.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          label: l10n.employeesTitle,
                          count: employees.length,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        sliver: SliverGrid.builder(
                          gridDelegate: grid,
                          itemCount: employees.length,
                          itemBuilder: (context, index) {
                            final employee = employees[index];
                            return _MemberCard(
                              member: employee,
                              isOwner: false,
                              isMe: false,
                              onTap: () => _openDetail(context, employee, true),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text(friendlyError(context, error))),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddEmployeeScreen()),
          );
        },
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l10n.addEmployeeTooltip),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.isOwner,
    required this.isMe,
    required this.onTap,
  });

  final ProfileModel member;
  final bool isOwner;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasPhone = member.phone != null && member.phone!.isNotEmpty;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              MemberAvatar(member: member, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe
                          ? '${member.fullName} ${l10n.youLabel}'
                          : member.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // A Wrap so that a wide role label (e.g. "Administrador")
                    // plus the phone number drop to two lines instead of
                    // overflowing on a narrow card.
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RoleChip(isOwner: isOwner),
                        if (hasPhone)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  member.phone!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A person's avatar: their photo, or their initials on a soft tint.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.radius = 24});

  final ProfileModel member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.25),
      foregroundColor: theme.colorScheme.onSurface,
      backgroundImage: member.avatarUrl != null
          ? NetworkImage(member.avatarUrl!)
          : null,
      child: member.avatarUrl == null
          ? Text(
              initialsOf(member.fullName),
              style: TextStyle(
                fontSize: radius * 0.6,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

/// The small "Administrator" / "Standard" pill.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOwner
            ? const Color(0xFF14181C)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner) ...[
            const Icon(Icons.shield_outlined, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              isOwner ? l10n.roleOwnerLabel : l10n.roleEmployeeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isOwner ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count', style: theme.textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}
