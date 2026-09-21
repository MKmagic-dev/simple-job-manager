import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/profile/domain/profile_model.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_completion_notice_model.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/projects/presentation/project_list_screen.dart';
import 'package:simple_job_manager/features/projects/presentation/project_workspace_tabs.dart';
import 'package:simple_job_manager/features/tasks/data/task_repository.dart';
import 'package:simple_job_manager/features/tasks/domain/project_task_model.dart';
import 'package:simple_job_manager/features/tasks/domain/task_completion_notice_model.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final _active = ProjectModel(
  id: 'p1',
  companyId: 'c1',
  name: 'Budowa domu',
  startDate: _today(),
  endDate: _today().add(const Duration(days: 30)),
);
final _archivedProject = ProjectModel(
  id: 'p2',
  companyId: 'c1',
  name: 'Stary remont',
  archivedAt: _today(),
);

ProjectTaskModel _task(String id, String title, {bool archived = false}) =>
    ProjectTaskModel(
      id: id,
      companyId: 'c1',
      projectId: 'p1',
      title: title,
      startDate: _today(),
      endDate: _today().add(const Duration(days: 2)),
      createdAt: _today(),
      archivedAt: archived ? _today() : null,
    );

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

void main() {
  testWidgets('project list splits into Active and Archive', (tester) async {
    _setSize(tester, const Size(1000, 800));
    await tester.pumpWidget(
      _host(
        const ProjectListScreen(companyId: 'c1'),
        overrides: [
          projectListProvider.overrideWith(
            (ref) async => [_active, _archivedProject],
          ),
          taskListProvider.overrideWith((ref) async => []),
          projectCompletionNoticeListProvider.overrideWith((ref) async => []),
          taskCompletionNoticeListProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Aktywne (1)'), findsOneWidget);
    expect(find.text('Archiwum (1)'), findsOneWidget);
    expect(find.text('Budowa domu'), findsOneWidget);
    expect(find.text('Stary remont'), findsNothing);
    expect(find.text('Dodaj projekt'), findsOneWidget);

    await tester.tap(find.text('Archiwum (1)'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Stary remont'), findsOneWidget);
    expect(find.text('Zarchiwizowany'), findsOneWidget);
    expect(find.text('Budowa domu'), findsNothing);
    // Nothing new can be added while looking at the archive.
    expect(find.text('Dodaj projekt'), findsNothing);
  });

  testWidgets('a task reported done shows who did it and a way to archive', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    final anna = ProfileModel(
      id: 'e1',
      companyId: 'c1',
      role: UserRole.worker,
      fullName: 'Anna Testowa',
    );
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: ProjectTasksTab(
            companyId: 'c1',
            project: _active,
            tasks: [
              _task('t1', 'Wylewanie fundamentów'),
              _task('t2', 'Ścianki działowe', archived: true),
            ],
            shifts: const [],
            peopleById: {'e1': anna},
          ),
        ),
        overrides: [
          taskCompletionNoticeListProvider.overrideWith(
            (ref) async => [
              TaskCompletionNoticeModel(
                id: 'n1',
                taskId: 't1',
                employeeId: 'e1',
                createdAt: _today(),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Wylewanie fundamentów'), findsOneWidget);
    expect(find.text('Anna Testowa zgłasza: zadanie wykonane'), findsOneWidget);
    expect(find.text('Zarchiwizuj'), findsOneWidget);
    expect(find.text('Ścianki działowe'), findsNothing);

    await tester.tap(find.text('Archiwum (1)'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ścianki działowe'), findsOneWidget);
    expect(find.text('Przywróć'), findsOneWidget);
    expect(find.text('Wylewanie fundamentów'), findsNothing);
  });

  testWidgets('an archived project cannot get new shifts or tasks', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: ProjectTasksTab(
            companyId: 'c1',
            project: _archivedProject,
            tasks: [_task('t1', 'Zadanie')],
            shifts: const [],
            peopleById: const {},
          ),
        ),
        overrides: [
          taskCompletionNoticeListProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Zadanie'), findsOneWidget);
    expect(find.text('Dodaj zmianę'), findsNothing);
  });

  test('archived_at parses into isArchived for projects and tasks', () {
    final project = ProjectModel.fromJson({
      'id': 'p',
      'company_id': 'c',
      'name': 'X',
      'archived_at': '2026-09-01T10:00:00Z',
    });
    expect(project.isArchived, isTrue);
    expect(
      ProjectModel.fromJson({
        'id': 'p',
        'company_id': 'c',
        'name': 'X',
      }).isArchived,
      isFalse,
    );
    final notice = ProjectCompletionNoticeModel(
      id: 'n',
      projectId: 'p',
      employeeId: 'e',
      createdAt: _today(),
    );
    expect(notice.projectId, 'p');
  });
}
