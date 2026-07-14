import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../projects/data/project_repository.dart';
import '../data/shift_repository.dart';
import 'add_shift_screen.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key, required this.companyId});

  final String companyId;

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shiftsAsync = ref.watch(shiftListProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduleTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(shiftListProvider.future),
        child: shiftsAsync.when(
          data: (shifts) {
            if (shifts.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: Text(l10n.noShiftsScheduledYet)),
                  ),
                ),
              );
            }

            final employeeNames = {
              for (final employee in employeesAsync.valueOrNull ?? []) employee.id: employee.fullName,
            };
            final projectNames = {
              for (final project in projectsAsync.valueOrNull ?? []) project.id: project.name,
            };

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: shifts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final shift = shifts[index];
                final subtitleParts = <String>[
                  employeeNames[shift.employeeId] ?? '?',
                  if (shift.projectId != null) projectNames[shift.projectId] ?? '?',
                ];
                return ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    '${_formatDate(shift.workDate)} · ${_formatTime(shift.startTime)}–${_formatTime(shift.endTime)}',
                  ),
                  subtitle: Text(subtitleParts.join(' · ')),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
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
