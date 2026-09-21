import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../instructions/presentation/add_instruction_screen.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_model.dart';
import '../../shifts/data/shift_change_request_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../shifts/presentation/team_requests_screen.dart';
import '../../tasks/data/task_repository.dart';

/// The boss's "notes & requests" area: every instruction/document across
/// all projects, plus the employees' change requests, as two tabs.
class NotesHubScreen extends ConsumerStatefulWidget {
  const NotesHubScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<NotesHubScreen> createState() => _NotesHubScreenState();
}

class _NotesHubScreenState extends ConsumerState<NotesHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this)..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addInstruction() async {
    final l10n = AppLocalizations.of(context)!;
    final projects = ref.read(projectListProvider).valueOrNull ?? const [];
    if (projects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noProjectsYet)));
      return;
    }

    final project = await showDialog<ProjectModel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.chooseProjectTitle),
        children: [
          for (final project in projects)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(project),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorForProject(project),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(project.name)),
                ],
              ),
            ),
        ],
      ),
    );
    if (project == null || !mounted) return;

    // Offer the people actually on this project; fall back to the whole
    // team when nobody has been put on it yet.
    final tasks = ref.read(taskListProvider).valueOrNull ?? const [];
    final shifts = ref.read(shiftListProvider).valueOrNull ?? const [];
    final assignedIds = <String>{
      for (final task in tasks)
        if (task.projectId == project.id) ...task.assigneeIds,
      for (final shift in shifts)
        if (shift.projectId == project.id) shift.employeeId,
    };
    final everyone = ref.read(employeeListProvider).valueOrNull ?? const [];
    final assigned = everyone.where((e) => assignedIds.contains(e.id)).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddInstructionScreen(
          companyId: widget.companyId,
          projectId: project.id,
          employeeOptions: assigned.isNotEmpty ? assigned : everyone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final unreadRequests = ref.watch(unreadRequestsCountProvider);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notesHubTitle),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: theme.colorScheme.primary,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: l10n.instructionsTitle),
            Tab(
              child: Badge(
                label: Text('$unreadRequests'),
                isLabelVisible: unreadRequests > 0,
                offset: const Offset(12, -8),
                child: Text(l10n.changeRequestsSectionLabel),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const InstructionListBody(isOwner: true),
          TeamRequestsBody(people: people, projects: projects),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _addInstruction,
              icon: const Icon(Icons.add),
              label: Text(l10n.addInstructionTooltip),
            )
          : null,
    );
  }
}
