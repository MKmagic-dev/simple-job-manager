import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../domain/project_model.dart';

enum _Mode { day, week, month, year }

/// An overview of all projects on a timeline: one row per project with its
/// name on the left and a colored bar across the days it runs (a Gantt
/// chart). Built to stay readable with dozens of projects — rows scroll,
/// a search box narrows them down, and by default only projects running in
/// the shown period are listed. Week/month show days, year shows months;
/// day is a plain list of what's running that day.
class ProjectsTimeline extends StatefulWidget {
  const ProjectsTimeline({
    super.key,
    required this.projects,
    required this.onProjectTap,
  });

  final List<ProjectModel> projects;
  final void Function(ProjectModel project) onProjectTap;

  @override
  State<ProjectsTimeline> createState() => _ProjectsTimelineState();
}

typedef _Span = ({int from, int to});

class _ProjectsTimelineState extends State<ProjectsTimeline> {
  static const _rowHeight = 56.0;
  static const _headerHeight = 48.0;

  _Mode _mode = _Mode.week;
  DateTime _anchor = dateOnly(DateTime.now());
  final _searchController = TextEditingController();
  bool _onlyActive = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  (DateTime, DateTime) get _range {
    switch (_mode) {
      case _Mode.day:
        return (_anchor, _anchor);
      case _Mode.week:
        final start = _addDays(_anchor, -(_anchor.weekday - 1));
        return (start, _addDays(start, 6));
      case _Mode.month:
        return (
          DateTime(_anchor.year, _anchor.month, 1),
          DateTime(_anchor.year, _anchor.month + 1, 0),
        );
      case _Mode.year:
        return (DateTime(_anchor.year, 1, 1), DateTime(_anchor.year, 12, 31));
    }
  }

  void _step(int direction) {
    setState(() {
      switch (_mode) {
        case _Mode.day:
          _anchor = _addDays(_anchor, direction);
        case _Mode.week:
          _anchor = _addDays(_anchor, 7 * direction);
        case _Mode.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
        case _Mode.year:
          _anchor = DateTime(_anchor.year + direction, 1, 1);
      }
    });
  }

  String _rangeLabel(String locale, DateTime start, DateTime end) {
    switch (_mode) {
      case _Mode.day:
        return DateFormat.yMMMMEEEEd(locale).format(start);
      case _Mode.week:
        return '${DateFormat.MMMd(locale).format(start)} – ${DateFormat.MMMd(locale).format(end)}';
      case _Mode.month:
        return DateFormat.yMMMM(locale).format(start);
      case _Mode.year:
        return '${start.year}';
    }
  }

  /// The visible day indexes [from, to] this project covers, or null if it
  /// doesn't run in [rangeStart]..[rangeEnd]. A project with no start (or
  /// end) date is treated as running from (until) the edge of the range.
  _Span? _span(ProjectModel p, DateTime rangeStart, DateTime rangeEnd) {
    final start = p.startDate == null ? rangeStart : dateOnly(p.startDate!);
    final end = p.endDate == null ? rangeEnd : dateOnly(p.endDate!);
    if (end.isBefore(rangeStart) || start.isAfter(rangeEnd)) return null;
    return (
      from: _daysBetween(
        rangeStart,
        start.isBefore(rangeStart) ? rangeStart : start,
      ),
      to: _daysBetween(rangeStart, end.isAfter(rangeEnd) ? rangeEnd : end),
    );
  }

  String _datesLabel(ProjectModel p, String locale) {
    final format = DateFormat.MMMd(locale);
    final parts = [
      if (p.startDate != null) format.format(p.startDate!),
      if (p.endDate != null) format.format(p.endDate!),
    ];
    return parts.join(' – ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final (rangeStart, rangeEnd) = _range;
    final query = _searchController.text.trim().toLowerCase();

    final sorted = [...widget.projects]
      ..sort((a, b) {
        final byStart = (a.startDate ?? DateTime(1900)).compareTo(
          b.startDate ?? DateTime(1900),
        );
        return byStart != 0
            ? byStart
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final rows = <({ProjectModel project, _Span span})>[
      for (final project in sorted)
        if (query.isEmpty || project.name.toLowerCase().contains(query))
          if (_span(project, rangeStart, rangeEnd) case final span?)
            (project: project, span: span)
          else if (!_onlyActive && _mode != _Mode.day)
            (project: project, span: (from: -1, to: -1)),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.searchProjectsHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(_searchController.clear),
                            ),
                    ),
                  ),
                ),
              ),
              if (_mode != _Mode.day) ...[
                const SizedBox(width: 12),
                if (MediaQuery.sizeOf(context).width >= 640)
                  FilterChip(
                    label: Text(l10n.onlyActiveInPeriodLabel),
                    selected: _onlyActive,
                    onSelected: (value) => setState(() => _onlyActive = value),
                  )
                else
                  IconButton.filledTonal(
                    tooltip: l10n.onlyActiveInPeriodLabel,
                    isSelected: _onlyActive,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    selectedIcon: const Icon(Icons.filter_alt),
                    onPressed: () => setState(() => _onlyActive = !_onlyActive),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SegmentedButton<_Mode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: _Mode.day, label: Text(l10n.dayViewLabel)),
              ButtonSegment(value: _Mode.week, label: Text(l10n.weekViewLabel)),
              ButtonSegment(
                value: _Mode.month,
                label: Text(l10n.monthViewLabel),
              ),
              ButtonSegment(value: _Mode.year, label: Text(l10n.yearViewLabel)),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
        ),
        CalendarNavHeader(
          label: _rangeLabel(locale, rangeStart, rangeEnd),
          onPrevious: () => _step(-1),
          onNext: () => _step(1),
          onToday: () => setState(() => _anchor = dateOnly(DateTime.now())),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    l10n.noProjectsInRange,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : _mode == _Mode.day
              ? _buildDayList(
                  context,
                  rows.map((r) => r.project).toList(),
                  locale,
                )
              : _buildTimeline(context, rows, rangeStart, rangeEnd, locale),
        ),
      ],
    );
  }

  Widget _buildDayList(
    BuildContext context,
    List<ProjectModel> projects,
    String locale,
  ) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final project = projects[index];
        final color = colorForProject(project);
        final dates = _datesLabel(project, locale);
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => widget.onProjectTap(project),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (dates.isNotEmpty || project.address != null)
                          Text(
                            [
                              if (dates.isNotEmpty) dates,
                              if (project.address != null &&
                                  project.address!.isNotEmpty)
                                project.address!,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    List<({ProjectModel project, _Span span})> rows,
    DateTime rangeStart,
    DateTime rangeEnd,
    String locale,
  ) {
    final theme = Theme.of(context);
    final totalDays = _daysBetween(rangeStart, rangeEnd) + 1;
    final today = dateOnly(DateTime.now());
    final todayIndex = _daysBetween(rangeStart, today);
    final isYear = _mode == _Mode.year;

    return LayoutBuilder(
      builder: (context, constraints) {
        final nameWidth = (constraints.maxWidth * 0.26)
            .clamp(120.0, 240.0)
            .toDouble();
        final timeWidth = constraints.maxWidth - nameWidth;
        final pxPerDay = timeWidth / totalDays;
        final gridColor = theme.colorScheme.outlineVariant;

        // Background stripes shared by the header and all rows.
        final stripes = <Widget>[
          if (!isYear)
            for (var i = 0; i < totalDays; i++)
              if (_addDays(rangeStart, i).weekday >= DateTime.saturday)
                Positioned(
                  left: i * pxPerDay,
                  width: pxPerDay,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(color: gridColor.withValues(alpha: 0.25)),
                ),
          if (isYear)
            for (var m = 1; m <= 12; m++)
              Positioned(
                left:
                    _daysBetween(rangeStart, DateTime(rangeStart.year, m, 1)) *
                    pxPerDay,
                width: 1,
                top: 0,
                bottom: 0,
                child: ColoredBox(color: gridColor),
              ),
          if (todayIndex >= 0 && todayIndex < totalDays)
            Positioned(
              left: todayIndex * pxPerDay + pxPerDay / 2 - 1,
              width: 2,
              top: 0,
              bottom: 0,
              child: ColoredBox(color: theme.colorScheme.primary),
            ),
        ];

        return Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  SizedBox(width: nameWidth),
                  SizedBox(
                    width: timeWidth,
                    child: Stack(
                      children: [
                        ...stripes,
                        _buildHeaderCells(
                          context,
                          rangeStart,
                          totalDays,
                          pxPerDay,
                          today,
                          locale,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: rows.length * _rowHeight,
                  child: Stack(
                    children: [
                      Positioned(
                        left: nameWidth,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Stack(children: stripes),
                      ),
                      for (var i = 0; i < rows.length; i++)
                        Positioned(
                          top: i * _rowHeight,
                          left: 0,
                          right: 0,
                          height: _rowHeight,
                          child: _buildRow(
                            context,
                            rows[i].project,
                            rows[i].span,
                            nameWidth,
                            pxPerDay,
                            locale,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderCells(
    BuildContext context,
    DateTime rangeStart,
    int totalDays,
    double pxPerDay,
    DateTime today,
    String locale,
  ) {
    final theme = Theme.of(context);

    if (_mode == _Mode.year) {
      return Stack(
        children: [
          for (var m = 1; m <= 12; m++)
            Positioned(
              left:
                  _daysBetween(rangeStart, DateTime(rangeStart.year, m, 1)) *
                  pxPerDay,
              width: DateTime(rangeStart.year, m + 1, 0).day * pxPerDay,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  DateFormat.MMM(locale).format(DateTime(rangeStart.year, m)),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight:
                        today.year == rangeStart.year && today.month == m
                        ? FontWeight.bold
                        : null,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final roomy = pxPerDay >= 26;
    final step = roomy ? 1 : (26 / pxPerDay).ceil();
    return Stack(
      children: [
        for (var i = 0; i < totalDays; i++)
          if (i % step == 0)
            Positioned(
              left: i * pxPerDay,
              width: pxPerDay * (roomy ? 1 : step),
              top: 0,
              bottom: 0,
              child: () {
                final day = _addDays(rangeStart, i);
                final isToday = isSameDate(day, today);
                return Container(
                  alignment: Alignment.center,
                  color: isToday && roomy ? theme.colorScheme.primary : null,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (roomy)
                          Text(
                            DateFormat.E(locale).format(day),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isToday
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          '${day.day}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: isToday ? FontWeight.bold : null,
                            color: isToday && roomy
                                ? theme.colorScheme.onPrimary
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }(),
            ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    ProjectModel project,
    _Span span,
    double nameWidth,
    double pxPerDay,
    String locale,
  ) {
    final theme = Theme.of(context);
    final color = colorForProject(project);
    final textColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    final dates = _datesLabel(project, locale);
    final running = span.from >= 0;
    final barWidth = running ? (span.to - span.from + 1) * pxPerDay : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: nameWidth,
            child: InkWell(
              onTap: () => widget.onProjectTap(project),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (dates.isNotEmpty)
                            Text(
                              dates,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (running)
                  Positioned(
                    left: span.from * pxPerDay,
                    width: barWidth < 6 ? 6 : barWidth,
                    top: 14,
                    height: _rowHeight - 28,
                    child: Tooltip(
                      message: [
                        project.name,
                        if (dates.isNotEmpty) dates,
                      ].join('\n'),
                      child: GestureDetector(
                        onTap: () => widget.onProjectTap(project),
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: barWidth >= 90
                              ? Text(
                                  project.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
