import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/domain/project_model.dart';

/// Shared building blocks used by every calendar view (day/week/month/year)
/// so they all color, label, and describe shifts the same way.

const employeeColors = <MaterialColor>[
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.brown,
];

/// A person shown on a calendar's legend and used to color/label their
/// shift blocks. [avatarUrl] is optional — when present and there's room,
/// their photo is shown instead of initials.
class CalendarPerson {
  const CalendarPerson({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;
}

MaterialColor colorForPerson(List<CalendarPerson> people, String id) {
  final index = people.indexWhere((p) => p.id == id);
  return employeeColors[(index < 0 ? 0 : index) % employeeColors.length];
}

CalendarPerson? personById(List<CalendarPerson> people, String id) =>
    people.where((p) => p.id == id).firstOrNull;

MaterialColor colorForProject(ProjectModel project) =>
    employeeColors[project.id.hashCode.abs() % employeeColors.length];

bool isProjectActiveOn(ProjectModel project, DateTime day) {
  final afterStart = project.startDate == null || !day.isBefore(dateOnly(project.startDate!));
  final beforeEnd = project.endDate == null || !day.isAfter(dateOnly(project.endDate!));
  return afterStart && beforeEnd;
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String initialsOf(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class LegendChip extends StatelessWidget {
  const LegendChip({
    super.key,
    required this.name,
    required this.color,
    required this.hidden,
    required this.onTap,
  });

  final String name;
  final MaterialColor color;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hidden ? null : color.shade50,
          border: Border.all(color: hidden ? Theme.of(context).dividerColor : color.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hidden ? Colors.transparent : color,
                border: hidden ? Border.all(color: color) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                color: hidden ? Theme.of(context).disabledColor : null,
                decoration: hidden ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared nav header: back/forward/today, with a label in the middle.
/// Used by every view — only the label text and step size differ.
class CalendarNavHeader extends StatelessWidget {
  const CalendarNavHeader({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.previousPeriodTooltip,
            onPressed: onPrevious,
          ),
          Expanded(
            child: Center(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.nextPeriodTooltip,
            onPressed: onNext,
          ),
          TextButton(
            onPressed: onToday,
            child: Text(l10n.todayButtonLabel),
          ),
        ],
      ),
    );
  }
}
