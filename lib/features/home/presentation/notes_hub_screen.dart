import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../notes/presentation/note_form_screen.dart';
import '../../notes/presentation/notes_body.dart';
import '../../projects/data/project_repository.dart';
import '../../shifts/data/shift_change_request_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../../shifts/presentation/team_requests_screen.dart';

/// The boss's "notes & requests" area, as two tabs: the boss's own notes
/// (optionally shared with chosen employees) and the employees' change
/// requests. Instructions live with their projects, not here.
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
            Tab(text: l10n.notesTabLabel),
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
          NotesBody(companyId: widget.companyId),
          TeamRequestsBody(people: people, projects: projects),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () =>
                  openNoteForm(context, companyId: widget.companyId),
              icon: const Icon(Icons.add),
              label: Text(l10n.addNoteButton),
            )
          : null,
    );
  }
}
