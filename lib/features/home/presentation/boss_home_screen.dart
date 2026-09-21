import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../employees/data/employee_repository.dart';
import '../../employees/presentation/employee_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/presentation/my_account_screen.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/presentation/project_list_screen.dart';
import '../../shifts/data/shift_change_request_repository.dart';
import '../../shifts/presentation/general_calendar_screen.dart';
import 'boss_sidebar.dart';
import 'dashboard_tile.dart';
import 'home_tile.dart';
import 'notes_hub_screen.dart';

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

  List<HomeSection> _sections(
    AppLocalizations l10n,
    String companyId,
    int unreadRequests,
  ) {
    return [
      HomeSection(
        icon: Icons.people_outline,
        label: l10n.teamTitle,
        builder: (context) => const EmployeeListScreen(),
      ),
      HomeSection(
        icon: Icons.work_outline,
        label: l10n.projectsTitle,
        builder: (context) => ProjectListScreen(companyId: companyId),
      ),
      HomeSection(
        icon: Icons.sticky_note_2_outlined,
        label: l10n.notesHubTitle,
        badgeCount: unreadRequests,
        builder: (context) => NotesHubScreen(companyId: companyId),
      ),
      HomeSection(
        icon: Icons.calendar_month_outlined,
        label: l10n.calendarTitle,
        builder: (context) => GeneralCalendarScreen(companyId: companyId),
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

  void _selectHome(String title, List<HomeSection> sections) {
    setState(() => _selectedIndex = 0);
    _contentNavigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (context) => _OverviewPane(
          title: title,
          firstName: _firstName(widget.profile.fullName),
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
    final sections = _sections(l10n, companyId, unreadRequests);

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
                      firstName: _firstName(profile.fullName),
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
  final List<HomeSection> sections;

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

/// The right pane's default content on wide screens: a greeting and the four
/// sections as large, easy-to-hit cards.
///
/// A ConsumerWidget on purpose: it's built once by the nested Navigator's
/// onGenerateRoute (Flutter doesn't re-run that for a route already on the
/// stack), so it has to watch its own providers to keep the counts live.
class _OverviewPane extends ConsumerWidget {
  const _OverviewPane({
    required this.title,
    required this.firstName,
    required this.sections,
    required this.onSectionTap,
  });

  final String title;
  final String firstName;
  final List<HomeSection> sections;
  final ValueChanged<int> onSectionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    final teamCount = ref.watch(employeeListProvider).valueOrNull?.length ?? 0;
    final projectCount =
        ref.watch(projectListProvider).valueOrNull?.length ?? 0;
    // Same order as the sections built in _BossHomeScreenState._sections.
    final subtitles = [
      l10n.homeTeamSubtitle(teamCount),
      l10n.homeProjectsSubtitle(projectCount),
      l10n.homeNotesSubtitle,
      l10n.homeCalendarSubtitle,
    ];
    final today = DateFormat.yMMMMEEEEd(locale).format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
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
                  today,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720 ? 2 : 1;
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 128,
                      ),
                      children: [
                        for (var i = 0; i < sections.length; i++)
                          HomeTile(
                            icon: sections[i].icon,
                            label: sections[i].label,
                            subtitle: i < subtitles.length
                                ? subtitles[i]
                                : null,
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
        ),
      ),
    );
  }
}
