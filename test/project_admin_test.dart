import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/employees/data/employee_repository.dart';
import 'package:simple_job_manager/features/employees/presentation/employee_detail_screen.dart';
import 'package:simple_job_manager/features/home/data/my_work_providers.dart';
import 'package:simple_job_manager/features/profile/data/profile_repository.dart';
import 'package:simple_job_manager/features/profile/domain/profile_model.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_member_model.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/projects/presentation/worker_project_list_screen.dart';
import 'package:simple_job_manager/features/shifts/data/shift_repository.dart';
import 'package:simple_job_manager/features/shifts/domain/shift_model.dart';
import 'package:simple_job_manager/features/tasks/data/task_repository.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

const _boss = ProfileModel(
  id: 'boss',
  companyId: 'c1',
  role: UserRole.boss,
  fullName: 'Jan Szef',
);
const _anna = ProfileModel(
  id: 'anna',
  companyId: 'c1',
  role: UserRole.worker,
  fullName: 'Anna Kowalska',
  phone: '500 100 200',
);
final _projectA = ProjectModel(id: 'pa', companyId: 'c1', name: 'Budowa domu');
final _projectB = ProjectModel(id: 'pb', companyId: 'c1', name: 'Remont dachu');

Widget _host(Widget home, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('pl'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

List<Override> _panelOverrides({List<ProjectMemberModel>? members}) => [
  employeeListProvider.overrideWith((ref) async => [_anna]),
  ownerListProvider.overrideWith((ref) async => [_boss]),
  projectListProvider.overrideWith((ref) async => [_projectA, _projectB]),
  projectMembersProvider.overrideWith(
    (ref) async =>
        members ??
        const [
          ProjectMemberModel(projectId: 'pa', employeeId: 'anna'),
          ProjectMemberModel(
            projectId: 'pb',
            employeeId: 'anna',
            isManager: true,
          ),
        ],
  ),
  shiftListProvider.overrideWith((ref) async => []),
  taskListProvider.overrideWith((ref) async => []),
  currentProfileProvider.overrideWith((ref) async => _boss),
];

void main() {
  test('member role parses as manager', () {
    expect(
      ProjectMemberModel.fromJson({
        'project_id': 'p',
        'employee_id': 'e',
        'role': 'manager',
      }).isManager,
      isTrue,
    );
    expect(
      ProjectMemberModel.fromJson({
        'project_id': 'p',
        'employee_id': 'e',
      }).isManager,
      isFalse,
    );
  });

  testWidgets(
    'a person\'s page edits details and sets project admin per project',
    (tester) async {
      _setSize(tester, const Size(500, 1400));
      await tester.pumpWidget(
        _host(
          const EmployeeDetailScreen(member: _anna, canRemove: true),
          overrides: _panelOverrides(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Phone is shown and there is somewhere to edit it.
      expect(find.text('500 100 200'), findsOneWidget);
      expect(find.text('Edytuj dane'), findsOneWidget);

      // One row per project, each with its own admin switch; Remont dachu is on.
      expect(find.text('Budowa domu'), findsOneWidget);
      expect(find.text('Remont dachu'), findsOneWidget);
      final switches = tester
          .widgetList<Switch>(find.byType(Switch))
          .map((s) => s.value)
          .toList();
      expect(switches, [false, true]);

      // Turning one on asks first, naming the person and the project.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('Nadać admina projektu?'), findsOneWidget);
      expect(find.textContaining('Anna Kowalska'), findsWidgets);
      expect(find.textContaining('Budowa domu'), findsWidgets);
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(find.text('Nadać admina projektu?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing a person refuses an empty name', (tester) async {
    _setSize(tester, const Size(500, 1400));
    await tester.pumpWidget(
      _host(
        const EmployeeDetailScreen(member: _anna, canRemove: true),
        overrides: _panelOverrides(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edytuj dane'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(find.text('Podaj imię i nazwisko osoby.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('company-wide admin needs the person\'s name typed to confirm', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 1600));
    await tester.pumpWidget(
      _host(
        const EmployeeDetailScreen(member: _anna, canRemove: true),
        overrides: _panelOverrides(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Nadaj administratora firmy'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Nadaj administratora firmy'));
    await tester.pumpAndSettle();

    FilledButton confirm() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Potwierdź'),
    );
    expect(confirm().onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'anna kowalska');
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'projects the employee administers are marked and open the panel',
    (tester) async {
      _setSize(tester, const Size(500, 900));
      await tester.pumpWidget(
        _host(
          const WorkerProjectListScreen(companyId: 'c1'),
          overrides: [
            projectListProvider.overrideWith(
              (ref) async => [_projectA, _projectB],
            ),
            taskListProvider.overrideWith((ref) async => []),
            projectMembersProvider.overrideWith(
              (ref) async => const [
                ProjectMemberModel(projectId: 'pa', employeeId: 'anna'),
                ProjectMemberModel(
                  projectId: 'pb',
                  employeeId: 'anna',
                  isManager: true,
                ),
              ],
            ),
            currentProfileProvider.overrideWith((ref) async => _anna),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Zarządzasz'), findsOneWidget);
    },
  );

  test(
    '"my" shifts are only the signed-in person\'s, even for a project admin',
    () async {
      ShiftModel shift(String id, String employee) => ShiftModel(
        id: id,
        companyId: 'c1',
        employeeId: employee,
        workDate: DateTime(2026, 10, 30),
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 0),
      );
      final container = ProviderContainer(
        overrides: [
          shiftListProvider.overrideWith(
            (ref) async => [shift('1', 'anna'), shift('2', 'ewa')],
          ),
          currentProfileProvider.overrideWith((ref) async => _anna),
        ],
      );
      addTearDown(container.dispose);

      final mine = await container.read(myShiftsProvider.future);
      expect(mine.map((s) => s.id), ['1']);
    },
  );
}
