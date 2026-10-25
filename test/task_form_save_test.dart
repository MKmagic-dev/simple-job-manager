import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/employees/data/employee_repository.dart';
import 'package:simple_job_manager/features/profile/domain/profile_model.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_member_model.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/tasks/data/task_repository.dart';
import 'package:simple_job_manager/features/tasks/domain/task_assignment_model.dart';
import 'package:simple_job_manager/features/tasks/presentation/task_form_screen.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records what the form asks the repository to save, without any network.
class _RecordingTaskRepository extends TaskRepository {
  _RecordingTaskRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  String? createdTitle;
  Set<String>? savedAssignees;
  String? savedForTask;

  @override
  Future<String> createTask({
    required String companyId,
    required String projectId,
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    createdTitle = title;
    return 'new-task-id';
  }

  @override
  Future<void> setAssignees({
    required String taskId,
    required String companyId,
    required Set<String> employeeIds,
  }) async {
    savedForTask = taskId;
    savedAssignees = {...employeeIds};
  }
}

ProfileModel _person(String id, String name) => ProfileModel(
  id: id,
  companyId: 'c1',
  role: UserRole.worker,
  fullName: name,
);

void main() {
  testWidgets(
    'ticking people and saving hands exactly them to the repository',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _RecordingTaskRepository();
      final project = ProjectModel(id: 'p1', companyId: 'c1', name: 'Budowa');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(repo),
            employeeListProvider.overrideWith(
              (ref) async => [
                _person('a', 'Anna Testowa'),
                _person('k', 'Katarzyna Testowa'),
              ],
            ),
            projectMembersProvider.overrideWith(
              (ref) async => const [
                ProjectMemberModel(projectId: 'p1', employeeId: 'a'),
                ProjectMemberModel(projectId: 'p1', employeeId: 'k'),
              ],
            ),
            taskAssignmentsProvider.overrideWith(
              (ref) async => const <TaskAssignmentModel>[],
            ),
            taskListProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TaskFormScreen(companyId: 'c1', project: project),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Fundamenty');
      await tester.scrollUntilVisible(
        find.text('Anna Testowa'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Anna Testowa'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Zapisz'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repo.createdTitle, 'Fundamenty');
      expect(repo.savedForTask, 'new-task-id');
      expect(
        repo.savedAssignees,
        {'a'},
        reason: 'Anna was ticked, so she (and only she) must be saved',
      );
    },
  );
}
