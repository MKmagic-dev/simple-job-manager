import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../projects/data/project_repository.dart';
import '../data/shift_repository.dart';
import 'add_shift_screen.dart';
import 'calendar_shared.dart';
import 'schedule_calendar.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shiftsAsync = ref.watch(shiftListProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduleTitle)),
      body: shiftsAsync.when(
        data: (shifts) {
          if (shifts.isEmpty) {
            return Center(child: Text(l10n.noShiftsScheduledYet));
          }

          final people = [
            for (final employee in employeesAsync.valueOrNull ?? const [])
              CalendarPerson(id: employee.id, name: employee.fullName, avatarUrl: employee.avatarUrl),
          ];

          return ScheduleCalendar(
            shifts: shifts,
            projects: projectsAsync.valueOrNull ?? [],
            people: people,
            isOwner: true,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addShiftTooltip,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddShiftScreen(companyId: companyId)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
