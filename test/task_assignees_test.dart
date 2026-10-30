import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/employees/data/employee_repository.dart';
import 'package:simple_job_manager/features/profile/data/profile_repository.dart';
import 'package:simple_job_manager/features/profile/domain/profile_model.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_member_model.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/shifts/domain/shift_model.dart';
import 'package:simple_job_manager/features/tasks/data/task_repository.dart';
import 'package:simple_job_manager/features/tasks/domain/project_task_model.dart';
import 'package:simple_job_manager/features/tasks/domain/task_assignment_model.dart';
import 'package:simple_job_manager/features/tasks/presentation/task_form_screen.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

ProfileModel _person(String id, String name) => ProfileModel(
  id: id,
  companyId: 'c1',
  role: UserRole.worker,
  fullName: name,
);

final _project = ProjectModel(id: 'p1', companyId: 'c1', name: 'Budowa');

Widget _form({
  required List<ProfileModel> everyone,
  required List<ProjectMemberModel> members,
  List<TaskAssignmentModel> assignments = const [],
}) {
  return ProviderScope(
    overrides: [
      employeeListProvider.overrideWith((ref) async => everyone),
      projectMembersProvider.overrideWith((ref) async => members),
      taskAssignmentsProvider.overrideWith((ref) async => assignments),
      // Only a company administrator composes a project's team.
      currentProfileProvider.overrideWith(
        (ref) async => const ProfileModel(
          id: 'boss',
          companyId: 'c1',
          role: UserRole.boss,
          fullName: 'Jan Szef',
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('pl'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TaskFormScreen(companyId: 'c1', project: _project),
    ),
  );
}

void _setSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  test('a task counts people assigned to it and people with a shift on it', () {
    final task = ProjectTaskModel(
      id: 't1',
      companyId: 'c1',
      projectId: 'p1',
      title: 'Fundamenty',
      startDate: DateTime(2026, 10, 21),
      endDate: DateTime(2026, 10, 23),
      createdAt: DateTime(2026, 10, 1),
    );
    final shift = ShiftModel(
      id: 's1',
      companyId: 'c1',
      employeeId: 'jan',
      taskId: 't1',
      workDate: DateTime(2026, 10, 21),
      startTime: const TimeOfDay(hour: 8, minute: 0),
      endTime: const TimeOfDay(hour: 16, minute: 0),
    );
    const assigned = TaskAssignmentModel(taskId: 't1', employeeId: 'anna');
    const elsewhere = TaskAssignmentModel(taskId: 't2', employeeId: 'ewa');

    expect(task.assigneeIdsFrom([shift], [assigned, elsewhere]), {
      'anna',
      'jan',
    });
    expect(task.assigneeIdsFrom(const []), isEmpty);
  });

  testWidgets('the task form offers only the project team to pick from', (
    tester,
  ) async {
    _setSize(tester);
    await tester.pumpWidget(
      _form(
        everyone: [
          _person('a', 'Anna Kowalska'),
          _person('j', 'Jan Nowak'),
          _person('o', 'Outsider Person'),
        ],
        members: const [
          ProjectMemberModel(projectId: 'p1', employeeId: 'a'),
          ProjectMemberModel(projectId: 'p1', employeeId: 'j'),
          // Someone else's project: must not be offered here.
          ProjectMemberModel(projectId: 'other', employeeId: 'o'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kto wykonuje zadanie'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Anna Kowalska'), findsOneWidget);
    expect(find.text('Jan Nowak'), findsOneWidget);
    expect(find.text('Outsider Person'), findsNothing);

    // Ticking people works.
    await tester.tap(find.text('Anna Kowalska'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('with an empty team the form asks to add people first', (
    tester,
  ) async {
    _setSize(tester);
    await tester.pumpWidget(
      _form(everyone: [_person('a', 'Anna Kowalska')], members: const []),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dodaj pracowników'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Nikogo nie ma jeszcze'), findsOneWidget);
    expect(find.text('Anna Kowalska'), findsNothing);
  });
}
