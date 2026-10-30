import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/employees/data/employee_repository.dart';
import 'package:simple_job_manager/features/notes/data/note_repository.dart';
import 'package:simple_job_manager/features/notes/domain/note_model.dart';
import 'package:simple_job_manager/features/notes/presentation/note_form_screen.dart';
import 'package:simple_job_manager/features/notes/presentation/notes_body.dart';
import 'package:simple_job_manager/features/profile/domain/profile_model.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/tasks/data/task_repository.dart';
import 'package:simple_job_manager/features/tasks/domain/project_task_model.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

NoteModel _note(
  String id,
  String title, {
  String? content,
  String? projectId,
  String? taskId,
}) => NoteModel(
  id: id,
  companyId: 'c1',
  title: title,
  content: content,
  projectId: projectId,
  taskId: taskId,
  createdAt: DateTime(2026, 10, 28),
  updatedAt: DateTime(2026, 10, 28),
);

ProfileModel _person(String id, String name) => ProfileModel(
  id: id,
  companyId: 'c1',
  role: UserRole.worker,
  fullName: name,
);

final _project = ProjectModel(id: 'p1', companyId: 'c1', name: 'Remont dachu');
final _task = ProjectTaskModel(
  id: 't1',
  companyId: 'c1',
  projectId: 'p1',
  title: 'Wylewanie fundamentów',
  startDate: DateTime(2026, 11, 2),
  endDate: DateTime(2026, 11, 4),
  createdAt: DateTime(2026, 10, 1),
);

Widget _host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      projectListProvider.overrideWith((ref) async => [_project]),
      taskListProvider.overrideWith((ref) async => [_task]),
      ...overrides,
    ],
    child: MaterialApp(
      locale: const Locale('pl'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the boss sees notes with who they are shared with', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    await tester.pumpWidget(
      _host(
        const NotesBody(companyId: 'c1'),
        overrides: [
          noteListProvider.overrideWith(
            (ref) async => [
              _note('n1', 'Zamówić beton', content: 'Zadzwonić przed 8:00'),
              _note('n2', 'Prywatna notatka'),
            ],
          ),
          noteRecipientsProvider.overrideWith(
            (ref) async => const [
              NoteRecipientModel(noteId: 'n1', employeeId: 'a'),
              NoteRecipientModel(noteId: 'n1', employeeId: 'b'),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Zamówić beton'), findsOneWidget);
    expect(find.text('Zadzwonić przed 8:00'), findsOneWidget);
    expect(find.text('Udostępniona: 2 osobom'), findsOneWidget);
    expect(find.text('Tylko dla mnie'), findsOneWidget);
  });

  testWidgets('no notes yet shows an invitation to add one', (tester) async {
    _setSize(tester, const Size(500, 900));
    await tester.pumpWidget(
      _host(
        const NotesBody(companyId: 'c1'),
        overrides: [
          noteListProvider.overrideWith((ref) async => []),
          noteRecipientsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Nie masz jeszcze notatek. Dodaj pierwszą.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'an employee reads shared notes and never sees who else got them',
    (tester) async {
      _setSize(tester, const Size(500, 900));
      await tester.pumpWidget(
        _host(
          const WorkerNotesBody(),
          overrides: [
            noteListProvider.overrideWith(
              (ref) async => [
                _note('n1', 'Zamówić beton', content: 'Zadzwonić przed 8:00'),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zamówić beton'), findsOneWidget);
      // No "shared with N people" badge for an employee.
      expect(find.textContaining('Udostępniona'), findsNothing);
      expect(find.text('Tylko dla mnie'), findsNothing);

      await tester.tap(find.text('Zamówić beton'));
      await tester.pumpAndSettle();
      expect(find.text('Zadzwonić przed 8:00'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an employee with no shared notes gets a plain message', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    await tester.pumpWidget(
      _host(
        const WorkerNotesBody(),
        overrides: [noteListProvider.overrideWith((ref) async => [])],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Szef nie udostępnił Ci jeszcze żadnych notatek.'),
      findsOneWidget,
    );
  });

  testWidgets('the note form needs a title and offers optional people', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 1200));
    await tester.pumpWidget(
      _host(
        const NoteFormScreen(companyId: 'c1'),
        overrides: [
          employeeListProvider.overrideWith(
            (ref) async => [
              _person('a', 'Anna Kowalska'),
              _person('b', 'Jan Nowak'),
            ],
          ),
          noteRecipientsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The sharing part is there, optional, with the people to pick from.
    expect(find.text('Udostępnij osobom (opcjonalnie)'), findsOneWidget);
    expect(find.text('Anna Kowalska'), findsOneWidget);
    expect(find.text('Jan Nowak'), findsOneWidget);

    // Saving without a title is refused.
    await tester.scrollUntilVisible(
      find.text('Zapisz'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(find.text('Wpisz tytuł notatki.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a note shows its project and task label, only there', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    await tester.pumpWidget(
      _host(
        const NotesBody(companyId: 'c1'),
        overrides: [
          noteListProvider.overrideWith(
            (ref) async => [
              _note('n1', 'Beton', projectId: 'p1', taskId: 't1'),
              _note('n2', 'Tylko projekt', projectId: 'p1'),
              _note('n3', 'Bez etykiety'),
            ],
          ),
          noteRecipientsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Remont dachu › Wylewanie fundamentów'), findsOneWidget);
    expect(find.text('Remont dachu'), findsOneWidget);
  });

  testWidgets('tapping a note opens it for editing with everything filled in', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 1400));
    await tester.pumpWidget(
      _host(
        const NotesBody(companyId: 'c1'),
        overrides: [
          noteListProvider.overrideWith(
            (ref) async => [
              _note(
                'n1',
                'Zamówić beton',
                content: 'Zadzwonić przed 8:00',
                projectId: 'p1',
                taskId: 't1',
              ),
            ],
          ),
          noteRecipientsProvider.overrideWith(
            (ref) async => const [
              NoteRecipientModel(noteId: 'n1', employeeId: 'a'),
            ],
          ),
          employeeListProvider.overrideWith(
            (ref) async => [
              _person('a', 'Anna Kowalska'),
              _person('b', 'Jan Nowak'),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zamówić beton'));
    await tester.pumpAndSettle();

    // The edit form, prefilled: title, text, project, task, and who it's shared with.
    expect(find.text('Edytuj notatkę'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Zamówić beton'), findsOneWidget);
    expect(find.text('Zadzwonić przed 8:00'), findsOneWidget);
    expect(find.text('Remont dachu'), findsWidgets);
    expect(find.text('Wylewanie fundamentów'), findsWidgets);
    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(boxes.map((b) => b.value), contains(true));
    // …and it can be deleted from there.
    expect(find.byTooltip('Usuń notatkę'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
