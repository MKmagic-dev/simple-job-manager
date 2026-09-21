import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/employees/data/employee_repository.dart';
import 'package:simple_job_manager/features/employees/presentation/people_checklist.dart';
import 'package:simple_job_manager/features/profile/domain/profile_model.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_member_model.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/projects/presentation/project_people_actions.dart';
import 'package:simple_job_manager/features/projects/presentation/project_workspace_tabs.dart';
import 'package:simple_job_manager/features/tasks/data/task_repository.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

ProfileModel _person(int i) => ProfileModel(
  id: 'e$i',
  companyId: 'c1',
  role: UserRole.worker,
  fullName: 'Pracownik $i',
);

Widget _host(Widget home, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('pl'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  test('memberIdsOf returns only the people on that project', () {
    final members = [
      const ProjectMemberModel(projectId: 'p1', employeeId: 'e1'),
      const ProjectMemberModel(projectId: 'p1', employeeId: 'e2'),
      const ProjectMemberModel(projectId: 'p2', employeeId: 'e3'),
    ];
    expect(memberIdsOf(members, 'p1'), {'e1', 'e2'});
    expect(memberIdsOf(members, 'p2'), {'e3'});
    expect(memberIdsOf(members, 'p3'), isEmpty);
  });

  testWidgets('a 100-person checklist can be searched and bulk-selected', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    final people = [for (var i = 1; i <= 100; i++) _person(i)];
    var selected = <String>{};

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => PeopleChecklist(
            people: people,
            selected: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Narrow to the "Pracownik 9x" people: 9, 90..99 → 11 of them.
    await tester.enterText(find.byType(TextField), 'Pracownik 9');
    await tester.pumpAndSettle();
    expect(find.text('Pracownik 1'), findsNothing);

    await tester.tap(find.text('Zaznacz wszystkich'));
    await tester.pumpAndSettle();
    expect(selected.length, 11);
    expect(selected, contains('e9'));
    expect(selected, contains('e95'));
    expect(selected, isNot(contains('e1')));
    expect(tester.takeException(), isNull);

    // Nobody matches → friendly message, no crash.
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nikogo nie znaleziono.'), findsOneWidget);
  });

  testWidgets('the project overview lists its team with add and remove', (
    tester,
  ) async {
    _setSize(tester, const Size(700, 1000));
    final project = ProjectModel(id: 'p1', companyId: 'c1', name: 'Budowa');

    await tester.pumpWidget(
      _host(
        ProjectOverviewTab(
          companyId: 'c1',
          project: project,
          tasks: const [],
          assigned: [_person(1), _person(2)],
        ),
        overrides: [
          projectCompletionNoticeListProvider.overrideWith((ref) async => []),
          employeeListProvider.overrideWith(
            (ref) async => [for (var i = 1; i <= 5; i++) _person(i)],
          ),
          ownerListProvider.overrideWith((ref) async => []),
          projectAttachmentsProvider('p1').overrideWith((ref) async => []),
          projectTaskAttachmentsProvider('p1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Przypisani pracownicy (2)'), findsOneWidget);
    expect(find.text('Pracownik 1'), findsOneWidget);
    expect(find.text('Pracownik 2'), findsOneWidget);
    expect(find.text('Dodaj pracowników'), findsOneWidget);

    // The picker offers only the three people not on the project yet.
    await tester.tap(find.text('Dodaj pracowników'));
    await tester.pumpAndSettle();
    expect(find.text('Dodaj pracowników do projektu'), findsOneWidget);
    expect(find.text('Pracownik 3'), findsOneWidget);
    expect(find.text('Pracownik 5'), findsOneWidget);
    expect(find.text('Pracownik 1'), findsOneWidget); // only the chip behind
    expect(tester.takeException(), isNull);
  });
}
