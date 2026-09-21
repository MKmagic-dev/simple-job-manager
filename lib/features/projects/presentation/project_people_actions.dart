import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../employees/presentation/people_checklist.dart';
import '../../profile/domain/profile_model.dart';
import '../../shifts/data/shift_repository.dart';
import '../data/project_repository.dart';
import '../domain/project_member_model.dart';

/// The ids of the people on [projectId] among [members] (all memberships the
/// caller can see, i.e. `ref.watch(projectMembersProvider).valueOrNull`).
Set<String> memberIdsOf(
  Iterable<ProjectMemberModel> members,
  String projectId,
) => {
  for (final member in members)
    if (member.projectId == projectId) member.employeeId,
};

/// Asks which employees to put on the project (only people not already on it
/// are offered; the picker has search + "select everyone" for big teams) and
/// adds them. Returns the ids that were added (empty when cancelled).
Future<Set<String>> addPeopleToProject(
  BuildContext context,
  WidgetRef ref, {
  required String companyId,
  required String projectId,
  required Set<String> alreadyOn,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final candidates = [
    for (final person
        in ref.read(employeeListProvider).valueOrNull ?? const <ProfileModel>[])
      if (!alreadyOn.contains(person.id)) person,
  ];

  final chosen = await showPeoplePickerDialog(
    context,
    title: l10n.addPeopleToProjectTitle,
    people: candidates,
  );
  if (chosen == null || chosen.isEmpty) return {};

  try {
    await ref
        .read(projectRepositoryProvider)
        .addMembers(
          companyId: companyId,
          projectId: projectId,
          employeeIds: chosen,
        );
    ref.invalidate(projectMembersProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.peopleAddedToProject(chosen.length))),
    );
    return chosen;
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    return {};
  }
}

/// Confirms, then takes [person] off the project (and removes their upcoming
/// shifts in it).
Future<void> removePersonFromProject(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required ProfileModel person,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.removeFromProjectTooltip),
      content: Text(l10n.removeFromProjectConfirmMessage(person.fullName)),
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
    await ref
        .read(projectRepositoryProvider)
        .removeMember(projectId: projectId, employeeId: person.id);
    ref.invalidate(projectMembersProvider);
    ref.invalidate(shiftListProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.personRemovedFromProject)),
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
  }
}
