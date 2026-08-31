import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/domain/project_model.dart';
import '../domain/shift_model.dart';
import 'calendar_shared.dart';
import 'shift_details_dialog.dart';

/// Opens a bottom sheet listing every shift on [day], for use from the
/// month/year grid views where a single cell is too small to show shift
/// blocks directly. Tapping a row opens the same shift-detail dialog the
/// time-grid view uses.
void showDayShiftsSheet(
  BuildContext rootContext, {
  required DateTime day,
  required List<ShiftModel> shifts,
  required List<CalendarPerson> people,
  required List<ProjectModel> projects,
  required bool isOwner,
}) {
  final l10n = AppLocalizations.of(rootContext)!;
  final locale = Localizations.localeOf(rootContext).languageCode;
  final dayShifts =
      shifts.where((shift) => isSameDate(shift.workDate, day)).toList()..sort(
        (a, b) => (a.startTime.hour * 60 + a.startTime.minute).compareTo(
          b.startTime.hour * 60 + b.startTime.minute,
        ),
      );
  final dayProjects = projects
      .where((project) => isProjectActiveOn(project, day))
      .toList();
  final singlePerson = people.isEmpty;

  showModalBottomSheet<void>(
    context: rootContext,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMMEEEEd(locale).format(day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (dayProjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.activeProjectsSectionLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final project in dayProjects)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: colorForProject(project),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project.address != null
                              ? '${project.name} · ${project.address}'
                              : project.name,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (dayShifts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l10n.noShiftsThisDayLabel),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: dayShifts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final shift = dayShifts[index];
                    final person = singlePerson
                        ? null
                        : personById(people, shift.employeeId);
                    final projectName = shift.projectId == null
                        ? null
                        : projects
                              .where((p) => p.id == shift.projectId)
                              .map((p) => p.name)
                              .firstOrNull;
                    final color = singlePerson
                        ? null
                        : colorForPerson(people, shift.employeeId);

                    return ListTile(
                      leading: singlePerson
                          ? const Icon(Icons.schedule)
                          : CircleAvatar(
                              backgroundColor: color!.shade50,
                              foregroundColor: color.shade900,
                              backgroundImage: person?.avatarUrl != null
                                  ? NetworkImage(person!.avatarUrl!)
                                  : null,
                              child: person?.avatarUrl == null
                                  ? Text(initialsOf(person?.name ?? '?'))
                                  : null,
                            ),
                      title: Text(
                        '${formatTime(shift.startTime)}–${formatTime(shift.endTime)}',
                      ),
                      subtitle: () {
                        final parts = <String>[?person?.name, ?projectName];
                        return parts.isEmpty ? null : Text(parts.join(' · '));
                      }(),
                      onTap: () {
                        Navigator.of(rootContext).pop();
                        showShiftDetailsDialog(
                          rootContext,
                          shift,
                          people,
                          projects,
                          isOwner: isOwner,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
