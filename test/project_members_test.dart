import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/employees/data/employee_repository.dart';
import 'package:simple_job_manager/features/employees/presentation/people_checklist.dart';
import 'package:simple_job_manager/features/profile/data/profile_repository.dart';
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

  testWidgets(
    'the project team shows as icons; removing takes a menu + confirm',
    (tester) async {
      _setSize(tester, const Size(700, 1000));
      final project = ProjectModel(id: 'p1', companyId: 'c1', name: 'Budowa');
      ProfileModel named(String id, String name) => ProfileModel(
        id: id,
        companyId: 'c1',
        role: UserRole.worker,
        fullName: name,
      );
      final anna = named('a', 'Anna Kowalska');
      final jan = named('j', 'Jan Nowak');
      final everyone = [
        anna,
        jan,
        named('e', 'Ewa Lis'),
        named('d', 'Adam Bor'),
        named('z', 'Zofia Kot'),
      ];

      await tester.pumpWidget(
        _host(
          ProjectOverviewTab(
            companyId: 'c1',
            project: project,
            tasks: const [],
            assigned: [anna, jan],
          ),
          overrides: [
            projectCompletionNoticeListProvider.overrideWith((ref) async => []),
            employeeListProvider.overrideWith((ref) async => everyone),
            // Only a company administrator composes a project's team.
            currentProfileProvider.overrideWith(
              (ref) async => const ProfileModel(
                id: 'boss',
                companyId: 'c1',
                role: UserRole.boss,
                fullName: 'Jan Szef',
              ),
            ),

            ownerListProvider.overrideWith((ref) async => []),
            projectAttachmentsProvider('p1').overrideWith((ref) async => []),
            projectTaskAttachmentsProvider(
              'p1',
            ).overrideWith((ref) async => []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Przypisane osoby (2)'), findsOneWidget);
      // Icons with first names, and no one-tap "x" that could remove by accident.
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(find.text('Dodaj osoby'), findsOneWidget);

      // Tapping a person opens a menu; nothing is removed yet.
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      expect(find.text('Anna Kowalska'), findsOneWidget);
      expect(find.text('Usuń z projektu'), findsOneWidget);

      // Choosing it asks for confirmation, and cancelling keeps the person.
      await tester.tap(find.text('Usuń z projektu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('straci zaplanowane'), findsOneWidget);
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(find.text('Przypisane osoby (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The picker offers only the three people not on the project yet.
      await tester.tap(find.text('Dodaj osoby'));
      await tester.pumpAndSettle();
      expect(find.text('Dodaj osoby do projektu'), findsOneWidget);
      expect(find.text('Ewa Lis'), findsOneWidget);
      expect(find.text('Zofia Kot'), findsOneWidget);
      expect(find.text('Anna Kowalska'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
