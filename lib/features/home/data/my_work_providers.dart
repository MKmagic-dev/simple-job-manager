import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/domain/shift_model.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/project_task_model.dart';

/// The signed-in person's OWN shifts. An ordinary employee only ever receives
/// their own from the database, but an administrator of a project also
/// receives everyone's shifts on it — the employee-side screens (my schedule,
/// today) must still show just theirs.
final myShiftsProvider = FutureProvider.autoDispose<List<ShiftModel>>((
  ref,
) async {
  final shifts = await ref.watch(shiftListProvider.future);
  final me = (await ref.watch(currentProfileProvider.future))?.id;
  if (me == null) return shifts;
  return [
    for (final shift in shifts)
      if (shift.employeeId == me) shift,
  ];
});

/// The tasks the signed-in person is actually on (assigned to, or with a shift
/// on) — again, not every task of a project they administer.
final myTasksProvider = FutureProvider.autoDispose<List<ProjectTaskModel>>((
  ref,
) async {
  final tasks = await ref.watch(taskListProvider.future);
  final assignments = await ref.watch(taskAssignmentsProvider.future);
  final myShifts = await ref.watch(myShiftsProvider.future);
  final me = (await ref.watch(currentProfileProvider.future))?.id;
  if (me == null) return tasks;
  return [
    for (final task in tasks)
      if (task.assigneeIdsFrom(myShifts, assignments).contains(me)) task,
  ];
});
