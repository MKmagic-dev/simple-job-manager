import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../employees/data/employee_repository.dart';
import '../../employees/presentation/employee_list_screen.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/presentation/my_account_screen.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_model.dart';
import '../../projects/presentation/project_list_screen.dart';
import '../../shifts/data/shift_change_request_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../shifts/presentation/project_schedule_select_screen.dart';
import '../../shifts/presentation/team_requests_screen.dart';
import '../../work_photos/data/work_photo_repository.dart';
import '../../work_photos/presentation/work_photo_list_screen.dart';
import 'boss_sidebar.dart';
import 'dashboard_tile.dart';

/// Below this width there's no room for a fixed 260px sidebar plus usable
/// content, so the screen falls back to the tile-grid dashboard + normal
/// full-page navigation — the layout this app is actually used in day to
/// day, on a phone. At or above it (desktop/tablet browser), a permanent
/// sidebar stays on screen while the right-hand pane swaps sections.
const _wideLayoutBreakpoint = 900.0;

class BossHomeScreen extends ConsumerStatefulWidget {
  const BossHomeScreen({super.key, required this.profile});

  final ProfileModel profile;

  @override
  ConsumerState<BossHomeScreen> createState() => _BossHomeScreenState();
}

class _BossHomeScreenState extends ConsumerState<BossHomeScreen> {
  final _contentNavigatorKey = GlobalKey<NavigatorState>();
  // Index 0 is always "Home" (the overview pane); section N lives at N + 1.
  int _selectedIndex = 0;

  List<_Section> _sections(
    AppLocalizations l10n,
    String companyId,
    int unreadPhotos,
    int unreadRequests,
    List<CalendarPerson> people,
    List<ProjectModel> projects,
  ) {
    return [
      _Section(
        icon: Icons.people_outline,
        label: l10n.teamTitle,
        builder: (context) => const EmployeeListScreen(),
      ),
      _Section(
        icon: Icons.work_outline,
        label: l10n.projectsTitle,
        builder: (context) => ProjectListScreen(companyId: companyId),
      ),
      _Section(
        icon: Icons.calendar_month_outlined,
        label: l10n.scheduleTitle,
        builder: (context) => ProjectScheduleSelectScreen(companyId: companyId),
      ),
      _Section(
        icon: Icons.description_outlined,
        label: l10n.instructionsTitle,
        builder: (context) =>
            InstructionListScreen(companyId: companyId, isOwner: true),
      ),
      _Section(
        icon: Icons.photo_camera_back_outlined,
        label: l10n.workPhotosTitle,
        badgeCount: unreadPhotos,
        builder: (context) => WorkPhotoListScreen(
          companyId: companyId,
          employeeId: widget.profile.id,
          isOwner: true,
        ),
      ),
      _Section(
        icon: Icons.forum_outlined,
        label: l10n.changeRequestsSectionLabel,
        badgeCount: unreadRequests,
        builder: (context) =>
            TeamRequestsScreen(people: people, projects: projects),
      ),
    ];
  }

  void _selectSection(_Section section, int index) {
    setState(() => _selectedIndex = index + 1);
    _contentNavigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: section.builder),
    );
  }

  void _selectHome(String title, List<_Section> sections) {
    setState(() => _selectedIndex = 0);
    _contentNavigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (context) => _OverviewPane(
          title: title,
          sections: sections,
          onSectionTap: (index) => _selectSection(sections[index], index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final l10n = AppLocalizations.of(context)!;
    final title = '${l10n.bossPanelTitle} — ${profile.fullName}';
    // Safe: BossHomeScreen is only ever built for UserRole.boss, and only
    // UserRole.admin profiles have a null companyId.
    final companyId = profile.companyId!;
    final unreadRequests = ref.watch(unreadRequestsCountProvider);
    final unreadPhotos = ref.watch(unreadWorkPhotosCountProvider);
    final employees = ref.watch(employeeListProvider).valueOrNull ?? const [];
    final people = [
      for (final employee in employees)
        CalendarPerson(
          id: employee.id,
          name: employee.fullName,
          avatarUrl: employee.avatarUrl,
        ),
    ];
    final projects = ref.watch(projectListProvider).valueOrNull ?? const [];
    final sections = _sections(
      l10n,
      companyId,
      unreadPhotos,
      unreadRequests,
      people,
      projects,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideLayoutBreakpoint) {
          return _MobileDashboard(
            title: title,
            profile: profile,
            sections: sections,
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
                      badgeCount: section.badgeCount,
                    ),
                ],
                onSelect: (index) => index == 0
                    ? _selectHome(title, sections)
                    : _selectSection(sections[index - 1], index - 1),
                onAccountTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MyAccountScreen(profile: profile),
                    ),
                  );
                },
                onSignOutTap: () => ref.read(authRepositoryProvider).signOut(),
              ),
              Expanded(
                child: Navigator(
                  key: _contentNavigatorKey,
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (context) => _OverviewPane(
                      title: title,
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

class _Section {
  const _Section({
    required this.icon,
    required this.label,
    required this.builder,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
  final WidgetBuilder builder;
}

/// The phone-width fallback — same tile-grid dashboard this app has used,
/// with normal push navigation between full-screen pages.
class _MobileDashboard extends StatelessWidget {
  const _MobileDashboard({
    required this.title,
    required this.profile,
    required this.sections,
  });

  final String title;
  final ProfileModel profile;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer(
      builder: (context, ref, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle_outlined),
                tooltip: l10n.myAccountTooltip,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MyAccountScreen(profile: profile),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: l10n.signOutTooltip,
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;
                return GridView(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  children: [
                    for (final section in sections)
                      DashboardTile(
                        icon: section.icon,
                        label: section.label,
                        badgeCount: section.badgeCount,
                        onTap: () {
                          Navigator.of(
                            context,
                          ).push(MaterialPageRoute(builder: section.builder));
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The right pane's default content on wide screens, before a sidebar item
/// has been picked — quick-glance numbers (how many employees, projects,
/// …) as both plain stat cards and a simple bar chart, then the same
/// sections as cards, so the pane isn't blank on first load.
///
/// A ConsumerWidget on purpose: it's built once by the nested Navigator's
/// onGenerateRoute (Flutter doesn't re-run that for a route already on the
/// stack), so it has to watch its own providers to stay live rather than
/// receiving a stats snapshot computed by the parent at that one moment.
class _OverviewPane extends ConsumerWidget {
  const _OverviewPane({
    required this.title,
    required this.sections,
    required this.onSectionTap,
  });

  final String title;
  final List<_Section> sections;
  final ValueChanged<int> onSectionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final employeeCount =
        ref.watch(employeeListProvider).valueOrNull?.length ?? 0;
    final projectCount =
        ref.watch(projectListProvider).valueOrNull?.length ?? 0;
    final shifts = ref.watch(shiftListProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));
    final upcomingShiftsCount = shifts
        .where(
          (shift) =>
              !shift.workDate.isBefore(today) &&
              shift.workDate.isBefore(weekEnd),
        )
        .length;
    final unreadRequestsCount = ref.watch(unreadRequestsCountProvider);
    final unreadPhotosCount = ref.watch(unreadWorkPhotosCountProvider);

    final stats = _OverviewStats(
      employeeCount: employeeCount,
      projectCount: projectCount,
      upcomingShiftsCount: upcomingShiftsCount,
      unreadRequestsCount: unreadRequestsCount,
      unreadPhotosCount: unreadPhotosCount,
    );
    final bars = [
      _StatBar(
        label: l10n.teamTitle,
        value: stats.employeeCount,
        color: const Color(0xFF4C8B14),
      ),
      _StatBar(
        label: l10n.projectsTitle,
        value: stats.projectCount,
        color: const Color(0xFFB6F04A),
      ),
      _StatBar(
        label: l10n.upcomingShiftsStatLabel,
        value: stats.upcomingShiftsCount,
        color: const Color(0xFFFFD84D),
      ),
      _StatBar(
        label: l10n.changeRequestsSectionLabel,
        value: stats.unreadRequestsCount,
        color: const Color(0xFF14181C),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  children: [
                    _StatCard(
                      icon: Icons.people_outline,
                      value: stats.employeeCount,
                      label: l10n.teamTitle,
                    ),
                    _StatCard(
                      icon: Icons.work_outline,
                      value: stats.projectCount,
                      label: l10n.projectsTitle,
                    ),
                    _StatCard(
                      icon: Icons.calendar_month_outlined,
                      value: stats.upcomingShiftsCount,
                      label: l10n.upcomingShiftsStatLabel,
                    ),
                    _StatCard(
                      icon: Icons.photo_camera_back_outlined,
                      value: stats.unreadPhotosCount,
                      label: l10n.workPhotosTitle,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.overviewChartTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  for (final bar in bars) ...[bar, const SizedBox(height: 14)],
                ],
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 1100 ? 3 : 2;
                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                  ),
                  children: [
                    for (var i = 0; i < sections.length; i++)
                      DashboardTile(
                        icon: sections[i].icon,
                        label: sections[i].label,
                        badgeCount: sections[i].badgeCount,
                        onTap: () => onSectionTap(i),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStats {
  const _OverviewStats({
    required this.employeeCount,
    required this.projectCount,
    required this.upcomingShiftsCount,
    required this.unreadRequestsCount,
    required this.unreadPhotosCount,
  });

  final int employeeCount;
  final int projectCount;
  final int upcomingShiftsCount;
  final int unreadRequestsCount;
  final int unreadPhotosCount;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One row of the simple bar chart: label, a proportional-width colored
/// bar, and the raw count — a lightweight stand-in for a real charting
/// package, enough to show "how many X" at a glance without adding a new
/// dependency for it.
class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  static const _scaleMax = 20;

  @override
  Widget build(BuildContext context) {
    final fraction = (value / _scaleMax).clamp(0.03, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 14,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
