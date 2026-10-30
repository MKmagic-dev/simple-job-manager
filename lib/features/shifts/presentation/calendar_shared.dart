import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/domain/project_model.dart';
import '../../tasks/domain/project_task_model.dart';

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

/// A distinct palette for projects (separate from [employeeColors]) so a
/// project's automatic color never gets visually confused with a person's.
const projectColorPalette = <Color>[
  Color(0xFF1E88E5),
  Color(0xFFD81B60),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00897B),
  Color(0xFFC0CA33),
  Color(0xFF6D4C41),
  Color(0xFF3949AB),
  Color(0xFFE53935),
];

/// Distinct, bright colors for tasks (readable on the dark theme). A task with
/// no color of its own takes the next one in this list, in creation order, so
/// the tasks of one project never blur into the project's single color.
const taskColorPalette = <Color>[
  Color(0xFF1E88E5),
  Color(0xFFE91E63),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
  Color(0xFFFDD835),
  Color(0xFFE53935),
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFFFF7043),
  Color(0xFF9CCC65),
];

/// The task's own color if it has one, otherwise the palette color for its
/// place among [allTasks] of the same project (oldest first).
Color colorForTask(ProjectTaskModel task, Iterable<ProjectTaskModel> allTasks) {
  final custom = task.color == null ? null : colorFromHex(task.color!);
  if (custom != null) return custom;
  final siblings = allTasks.where((t) => t.projectId == task.projectId).toList()
    ..sort((a, b) {
      final byCreated = a.createdAt.compareTo(b.createdAt);
      return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
    });
  final index = siblings.indexWhere((t) => t.id == task.id);
  return taskColorPalette[(index < 0 ? task.id.hashCode.abs() : index) %
      taskColorPalette.length];
}

String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2)}';

Color? colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// The project's own color if it set one, otherwise an automatic pick from
/// [projectColorPalette] derived from its id (stable across rebuilds).
Color colorForProject(ProjectModel project) {
  final custom = project.color == null ? null : colorFromHex(project.color!);
  return custom ??
      projectColorPalette[project.id.hashCode.abs() %
          projectColorPalette.length];
}

bool isProjectActiveOn(ProjectModel project, DateTime day) {
  final afterStart =
      project.startDate == null || !day.isBefore(dateOnly(project.startDate!));
  final beforeEnd =
      project.endDate == null || !day.isAfter(dateOnly(project.endDate!));
  return afterStart && beforeEnd;
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String initialsOf(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
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
    final theme = Theme.of(context);
    final fill = hidden ? null : color.withValues(alpha: 0.22);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(
            color: hidden ? theme.colorScheme.outline : color.shade400,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hidden)
              Icon(
                Icons.visibility_off_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              )
            else
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            const SizedBox(width: 6),
            Text(
              name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: hidden
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
                decoration: hidden ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "who is who" strip above a multi-person calendar: one chip per person
/// in their color; tapping one hides/shows that person's shifts. Scrolls
/// sideways so a big team doesn't push the calendar off the screen.
class PeopleLegend extends StatelessWidget {
  const PeopleLegend({
    super.key,
    required this.people,
    required this.hiddenIds,
    required this.onToggle,
    required this.onShowAll,
  });

  final List<CalendarPerson> people;
  final Set<String> hiddenIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: l10n.legendHint,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.legendTitle,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (hiddenIds.isNotEmpty)
                TextButton(
                  onPressed: onShowAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l10n.legendShowAll),
                ),
            ],
          ),
          Text(
            l10n.legendHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final person = people[index];
                return LegendChip(
                  name: person.name,
                  color: colorForPerson(people, person.id),
                  hidden: hiddenIds.contains(person.id),
                  onTap: () => onToggle(person.id),
                );
              },
            ),
          ),
        ],
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
          TextButton(onPressed: onToday, child: Text(l10n.todayButtonLabel)),
        ],
      ),
    );
  }
}
