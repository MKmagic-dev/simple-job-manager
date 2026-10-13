import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/branding_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/presentation/my_account_screen.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_model.dart';
import '../../projects/presentation/worker_project_list_screen.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/domain/shift_model.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../shifts/presentation/worker_schedule_screen.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/project_task_model.dart';
import '../../tasks/presentation/my_tasks_screen.dart';
import 'boss_sidebar.dart';
import 'home_tile.dart';

/// Same breakpoint as the boss's home: below it there's no room for the
/// permanent sidebar, so the overview page is the menu and sections open as
/// full pages; at or above it the sidebar stays and the right pane swaps.
const _wideLayoutBreakpoint = 900.0;

/// The employee's start screen: a greeting, today's work at a glance, and
/// four sections — my schedule, my tasks, projects, instructions.
class WorkerHomeScreen extends ConsumerStatefulWidget {
  const WorkerHomeScreen({super.key, required this.profile});

  final ProfileModel profile;

  @override
  ConsumerState<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends ConsumerState<WorkerHomeScreen> {
  final _contentNavigatorKey = GlobalKey<NavigatorState>();
  // Index 0 is always "Home" (the overview pane); section N lives at N + 1.
  int _selectedIndex = 0;

  List<HomeSection> _sections(AppLocalizations l10n, String companyId) {
    return [
      HomeSection(
        icon: Icons.calendar_month_outlined,
        label: l10n.workerScheduleTitle,
        builder: (context) => const WorkerScheduleScreen(),
      ),
      HomeSection(
        icon: Icons.checklist_outlined,
        label: l10n.myTasksTitle,
        builder: (context) => const MyTasksScreen(),
      ),
      HomeSection(
        icon: Icons.work_outline,
        label: l10n.projectsTitle,
        builder: (context) => WorkerProjectListScreen(companyId: companyId),
      ),
      HomeSection(
        icon: Icons.description_outlined,
        label: l10n.instructionsTitle,
        builder: (context) =>
            InstructionListScreen(companyId: companyId, isOwner: false),
      ),
    ];
  }

  String _firstName(String fullName) =>
      fullName.trim().split(RegExp(r'\s+')).first;

  void _selectSection(HomeSection section, int index) {
    setState(() => _selectedIndex = index + 1);
    _contentNavigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: section.builder),
    );
  }

  void _openMyAccount() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MyAccountScreen(profile: widget.profile),
      ),
    );
  }

  Widget _overview({
    required String title,
    required List<HomeSection> sections,
    required ValueChanged<int> onSectionTap,
    List<Widget> actions = const [],
  }) {
    return _WorkerOverview(
      title: title,
      firstName: _firstName(widget.profile.fullName),
      sections: sections,
      onSectionTap: onSectionTap,
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final l10n = AppLocalizations.of(context)!;
    // Safe: WorkerHomeScreen is only ever built for UserRole.worker, and
    // only UserRole.admin profiles have a null companyId.
    final companyId = profile.companyId!;
    final sections = _sections(l10n, companyId);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideLayoutBreakpoint) {
          return _overview(
            title: BrandingConfig.appName,
            sections: sections,
            onSectionTap: (index) => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: sections[index].builder)),
            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle_outlined),
                tooltip: l10n.myAccountTooltip,
                onPressed: _openMyAccount,
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: l10n.signOutTooltip,
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          );
        }

        void selectHome() {
          setState(() => _selectedIndex = 0);
          _contentNavigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(
              builder: (context) => _overview(
                title: l10n.homeSidebarLabel,
                sections: sections,
                onSectionTap: (index) => _selectSection(sections[index], index),
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              BossSidebar(
                userName: profile.fullName,
                signOutLabel: l10n.signOutTooltip,
                selectedIndex: _selectedIndex,
                destinations: [
                  BossSidebarDestination(
                    icon: Icons.home_outlined,
                    label: l10n.homeSidebarLabel,
                  ),
                  for (final section in sections)
                    BossSidebarDestination(
                      icon: section.icon,
                      label: section.label,
                    ),
                ],
                onSelect: (index) => index == 0
                    ? selectHome()
                    : _selectSection(sections[index - 1], index - 1),
                onAccountTap: _openMyAccount,
                onSignOutTap: () => ref.read(authRepositoryProvider).signOut(),
              ),
              Expanded(
                child: Navigator(
                  key: _contentNavigatorKey,
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (context) => _overview(
                      title: l10n.homeSidebarLabel,
                      sections: sections,
                      onSectionTap: (index) =>
                          _selectSection(sections[index], index),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Greeting + today card + the four section cards.
///
/// A ConsumerWidget on purpose: on wide screens it's built once by the nested
/// Navigator's onGenerateRoute, so it has to watch its own providers to keep
/// the summaries live.
class _WorkerOverview extends ConsumerWidget {
  const _WorkerOverview({
    required this.title,
    required this.firstName,
    required this.sections,
    required this.onSectionTap,
    required this.actions,
  });

  final String title;
  final String firstName;
  final List<HomeSection> sections;
  final ValueChanged<int> onSectionTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    final now = DateTime.now();
    final today = dateOnly(now);
    final List<ShiftModel> shifts =
        [...(ref.watch(shiftListProvider).valueOrNull ?? const [])]
          ..sort((a, b) {
            final byDate = a.workDate.compareTo(b.workDate);
            return byDate != 0
                ? byDate
                : (a.startTime.hour * 60 + a.startTime.minute).compareTo(
                    b.startTime.hour * 60 + b.startTime.minute,
                  );
          });
    final tasks = ref.watch(taskListProvider).valueOrNull ?? const [];
    final projects = ref.watch(projectListProvider).valueOrNull ?? const [];

    final upcomingCount = shifts
        .where((shift) => !dateOnly(shift.workDate).isBefore(today))
        .length;
    final openTaskCount = tasks
        .where((task) => task.phaseOn(now) != TaskPhase.done)
        .length;
    // Same order as the sections built in _WorkerHomeScreenState._sections.
    final subtitles = [
      l10n.homeWorkerScheduleSubtitle(upcomingCount),
      l10n.homeWorkerTasksSubtitle(openTaskCount),
      l10n.homeProjectsSubtitle(projects.length),
      l10n.homeWorkerInstructionsSubtitle,
    ];

    final List<ShiftModel> todaysShifts = shifts
        .where((shift) => isSameDate(shift.workDate, today))
        .toList();
    final List<ShiftModel> nextDayShifts = () {
      final next = shifts
          .where((shift) => dateOnly(shift.workDate).isAfter(today))
          .firstOrNull;
      if (next == null) return const <ShiftModel>[];
      return shifts
          .where((shift) => isSameDate(shift.workDate, next.workDate))
          .toList();
    }();
    final showingNext = todaysShifts.isEmpty && nextDayShifts.isNotEmpty;
    final List<ShiftModel> cardShifts = showingNext
        ? nextDayShifts
        : todaysShifts;

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeGreeting(firstName),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat.yMMMMEEEEd(locale).format(now),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _TodayCard(
                  heading: showingNext
                      ? l10n.homeNextShiftTitle
                      : l10n.homeTodayTitle,
                  dateLabel: showingNext
                      ? DateFormat.MMMEd(
                          locale,
                        ).format(nextDayShifts.first.workDate)
                      : null,
                  emptyLabel: l10n.homeNoShiftsToday,
                  shifts: cardShifts,
                  onTap: () => onSectionTap(0),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720 ? 2 : 1;
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        mainAxisExtent: 112,
                      ),
                      children: [
                        for (var i = 0; i < sections.length; i++)
                          HomeTile(
                            icon: sections[i].icon,
                            label: sections[i].label,
                            subtitle: i < subtitles.length
                                ? subtitles[i]
                                : null,
                            onTap: () => onSectionTap(i),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark "what's on today" card: each shift as a time + project + task
/// line. Falls back to the next working day when today is free.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({
    required this.heading,
    required this.emptyLabel,
    required this.shifts,
    required this.onTap,
    this.dateLabel,
  });

  final String heading;
  final String? dateLabel;
  final String emptyLabel;
  final List<ShiftModel> shifts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projects = ref.watch(projectListProvider).valueOrNull ?? const [];
    final tasks = ref.watch(taskListProvider).valueOrNull ?? const [];
    final accent = BrandingConfig.accentColor;

    return Material(
      color: AppTheme.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent, width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      heading.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (dateLabel != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      dateLabel!,
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (shifts.isEmpty)
                Text(
                  emptyLabel,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                )
              else
                for (var i = 0; i < shifts.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: Colors.white12),
                    ),
                  _TodayShiftRow(
                    shift: shifts[i],
                    project: projects
                        .where((p) => p.id == shifts[i].projectId)
                        .firstOrNull,
                    task: tasks
                        .where((t) => t.id == shifts[i].taskId)
                        .firstOrNull,
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayShiftRow extends StatelessWidget {
  const _TodayShiftRow({
    required this.shift,
    required this.project,
    required this.task,
  });

  final ShiftModel shift;
  final ProjectModel? project;
  final ProjectTaskModel? task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = project == null ? Colors.white38 : colorForProject(project!);
    final projectName = project?.name;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 5,
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
                  '${formatTime(shift.startTime)} – ${formatTime(shift.endTime)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (projectName != null)
                  Text(
                    projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                if (task != null)
                  Text(
                    task!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
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
