import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/add_shift_screen.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../tasks/data/task_repository.dart';
import '../data/project_repository.dart';
import '../domain/project_model.dart';
import 'project_list_screen.dart' show ProjectCover;
import 'project_workspace_tabs.dart';

/// Everything about one project in one place, for the boss: overview,
/// the project's own calendar (shifts + tasks), its tasks, and the combined
/// gallery of photos/files and instructions.
class ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  const ProjectWorkspaceScreen({
    super.key,
    required this.companyId,
    required this.project,
  });

  final String companyId;
  final ProjectModel project;

  @override
  ConsumerState<ProjectWorkspaceScreen> createState() =>
      _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends ConsumerState<ProjectWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  static const _scheduleTab = 1;
  static const _tasksTab = 2;

  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  )..addListener(_onTabChanged);

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddToSchedule(ProjectModel project) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.addToScheduleTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(l10n.addShiftWithHoursOption),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddShiftScreen(
                      companyId: widget.companyId,
                      preselectedProjectId: project.id,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(l10n.addTaskTitle),
              onTap: () {
                Navigator.of(sheetContext).pop();
                openAddTask(context, widget.companyId, project);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final project =
        ref
            .watch(projectListProvider)
            .valueOrNull
            ?.where((p) => p.id == widget.project.id)
            .firstOrNull ??
        widget.project;
    final tasks = (ref.watch(taskListProvider).valueOrNull ?? const [])
        .where((task) => task.projectId == project.id)
        .toList();
    final shifts = (ref.watch(shiftListProvider).valueOrNull ?? const [])
        .where((shift) => shift.projectId == project.id)
        .toList();

    final employees = ref.watch(employeeListProvider).valueOrNull ?? const [];
    final peopleById = <String, ProfileModel>{
      for (final person in employees) person.id: person,
      for (final person in ref.watch(ownerListProvider).valueOrNull ?? [])
        person.id: person,
    };
    final assignedIds = <String>{for (final shift in shifts) shift.employeeId};
    final assigned = [
      for (final employee in employees)
        if (assignedIds.contains(employee.id)) employee,
    ];
    final calendarPeople = [
      for (final person in assigned)
        CalendarPerson(
          id: person.id,
          name: person.fullName,
          avatarUrl: person.avatarUrl,
        ),
    ];

    final showFab =
        _tabController.index == _scheduleTab ||
        _tabController.index == _tasksTab;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            title: Text(project.name),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ProjectCover(project: project),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black45, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: theme.colorScheme.primary,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: l10n.projectTabOverview),
                Tab(text: l10n.projectTabSchedule),
                Tab(text: l10n.projectTabTasks),
                Tab(text: l10n.projectTabFiles),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            ProjectOverviewTab(
              companyId: widget.companyId,
              project: project,
              tasks: tasks,
              assigned: assigned,
            ),
            ProjectScheduleTab(
              project: project,
              tasks: tasks,
              shifts: shifts,
              people: calendarPeople,
            ),
            ProjectTasksTab(
              companyId: widget.companyId,
              project: project,
              tasks: tasks,
              shifts: shifts,
              peopleById: peopleById,
            ),
            ProjectFilesTab(
              companyId: widget.companyId,
              project: project,
              tasks: tasks,
              assigned: assigned,
            ),
          ],
        ),
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: () => _tabController.index == _scheduleTab
                  ? _showAddToSchedule(project)
                  : openAddTask(context, widget.companyId, project),
              icon: const Icon(Icons.add),
              label: Text(
                _tabController.index == _scheduleTab
                    ? l10n.addToScheduleTitle
                    : l10n.addTaskTitle,
              ),
            )
          : null,
    );
  }
}
