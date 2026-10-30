import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/shifts/presentation/calendar_shared.dart';
import 'package:simple_job_manager/features/shifts/presentation/calendar_view_mode.dart';
import 'package:simple_job_manager/features/shifts/presentation/schedule_calendar.dart';
import 'package:simple_job_manager/features/tasks/domain/project_task_model.dart';
import 'package:simple_job_manager/features/tasks/domain/task_assignment_model.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

ProjectTaskModel _task(
  String id,
  String title, {
  required DateTime start,
  int days = 0,
  String? color,
  int createdOffset = 0,
  TimeOfDay? from,
  TimeOfDay? to,
}) => ProjectTaskModel(
  id: id,
  companyId: 'c1',
  projectId: 'p1',
  title: title,
  startDate: start,
  endDate: start.add(Duration(days: days)),
  createdAt: DateTime(2026, 1, 1).add(Duration(minutes: createdOffset)),
  color: color,
  startTime: from,
  endTime: to,
);

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('pl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  test('tasks of one project get different colors; an own color wins', () {
    final start = DateTime(2026, 11, 2);
    final tasks = [
      for (var i = 0; i < 12; i++)
        _task('t$i', 'Zadanie $i', start: start, createdOffset: i),
    ];
    final colors = {for (final t in tasks) colorForTask(t, tasks)};
    expect(colors.length, 12, reason: 'no two of the first 12 look alike');

    final custom = _task(
      'x',
      'Własny',
      start: start,
      color: '#112233',
      createdOffset: 99,
    );
    expect(colorForTask(custom, [...tasks, custom]), const Color(0xFF112233));
  });

  testWidgets('a multi-day task is ONE bar across its days in the month', (
    tester,
  ) async {
    _setSize(tester, const Size(700, 900));
    final monday = _today().subtract(Duration(days: _today().weekday - 1));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          initialMode: CalendarViewMode.month,
          tasks: [
            _task('a', 'Fundamenty', start: monday, days: 3),
            _task('b', 'Ściany', start: monday, days: 1, createdOffset: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Each task's name appears once for the week (not once per day).
    expect(find.text('Fundamenty'), findsOneWidget);
    expect(find.text('Ściany'), findsOneWidget);
  });

  testWidgets('the month grid stays usable with many overlapping tasks', (
    tester,
  ) async {
    _setSize(tester, const Size(360, 700));
    final monday = _today().subtract(Duration(days: _today().weekday - 1));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          initialMode: CalendarViewMode.month,
          tasks: [
            for (var i = 0; i < 9; i++)
              _task(
                't$i',
                'Zadanie numer $i',
                start: monday,
                days: 4,
                createdOffset: i,
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // What doesn't fit is counted ("+N"), not drawn over the grid.
    expect(find.textContaining('+'), findsWidgets);
  });

  testWidgets('the year view is readable and a month name opens that month', (
    tester,
  ) async {
    _setSize(tester, const Size(1000, 800));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          initialMode: CalendarViewMode.year,
          tasks: [_task('a', 'Fundamenty', start: _today(), days: 5)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Twelve month cards, each with its name.
    expect(find.text('Styczeń'), findsOneWidget);
    expect(find.text('Grudzień'), findsOneWidget);

    await tester.tap(find.text('Styczeń'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // We're now in the month view, on January.
    expect(find.textContaining('styczeń'), findsWidgets);
  });

  testWidgets('the year view works on a phone too', (tester) async {
    _setSize(tester, const Size(360, 800));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          initialMode: CalendarViewMode.year,
          tasks: [
            _task('a', 'Fundamenty', start: _today(), days: 5),
            _task('b', 'Ściany', start: _today(), days: 9, createdOffset: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(GridView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tasks with hours sit on the hour grid, all-day ones above it', (
    tester,
  ) async {
    _setSize(tester, const Size(700, 900));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          initialMode: CalendarViewMode.week,
          tasks: [
            _task(
              'a',
              'Fundamenty',
              start: _today(),
              from: const TimeOfDay(hour: 9, minute: 0),
              to: const TimeOfDay(hour: 12, minute: 0),
            ),
            _task('b', 'Sprzątanie', start: _today(), createdOffset: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final nineY = tester.getCenter(find.text('9:00')).dy;
    final sixY = tester.getCenter(find.text('6:00')).dy;
    final timedY = tester.getTopLeft(find.text('Fundamenty')).dy;
    final allDayY = tester.getTopLeft(find.text('Sprzątanie')).dy;

    // The timed task starts at the 9:00 line of the grid…
    expect((timedY - nineY).abs() < 30, isTrue, reason: 'timed task at 9:00');
    // …and shows its hours.
    expect(find.text('09:00–12:00'), findsOneWidget);
    // The task without hours is a bar above the whole grid (above 6:00).
    expect(allDayY < sixY, isTrue, reason: 'all-day task above the grid');

    // The day view does the same.
    await tester.tap(find.text('Dzień'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final dayNineY = tester.getCenter(find.text('9:00')).dy;
    final dayTimedY = tester.getTopLeft(find.text('Fundamenty')).dy;
    expect((dayTimedY - dayNineY).abs() < 30, isTrue);
  });

  testWidgets('overlapping timed tasks share the width instead of covering', (
    tester,
  ) async {
    _setSize(tester, const Size(700, 900));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          initialMode: CalendarViewMode.day,
          tasks: [
            _task(
              'a',
              'Beton',
              start: _today(),
              from: const TimeOfDay(hour: 8, minute: 0),
              to: const TimeOfDay(hour: 12, minute: 0),
            ),
            _task(
              'b',
              'Zbrojenie',
              start: _today(),
              createdOffset: 1,
              from: const TimeOfDay(hour: 9, minute: 0),
              to: const TimeOfDay(hour: 11, minute: 0),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final left1 = tester.getTopLeft(find.text('Beton')).dx;
    final left2 = tester.getTopLeft(find.text('Zbrojenie')).dx;
    expect((left2 - left1).abs() > 50, isTrue, reason: 'side by side');
  });

  testWidgets('the day view names the people on each task', (tester) async {
    _setSize(tester, const Size(700, 900));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          isOwner: true,
          initialMode: CalendarViewMode.day,
          people: const [
            CalendarPerson(id: 'a', name: 'Ania'),
            CalendarPerson(id: 'b', name: 'Basia'),
          ],
          taskAssignments: const [
            TaskAssignmentModel(taskId: 'x', employeeId: 'a'),
            TaskAssignmentModel(taskId: 'x', employeeId: 'b'),
            TaskAssignmentModel(taskId: 'z', employeeId: 'a'),
            TaskAssignmentModel(taskId: 'w', employeeId: 'b'),
          ],
          tasks: [
            _task(
              'z',
              'Krótkie',
              start: _today(),
              createdOffset: 2,
              from: const TimeOfDay(hour: 14, minute: 0),
              to: const TimeOfDay(hour: 15, minute: 30),
            ),
            _task(
              'w',
              'Szybkie',
              start: _today(),
              createdOffset: 3,
              from: const TimeOfDay(hour: 16, minute: 0),
              to: const TimeOfDay(hour: 16, minute: 30),
            ),
            _task(
              'x',
              'Sprzątanie',
              start: _today(),
              from: const TimeOfDay(hour: 9, minute: 0),
              to: const TimeOfDay(hour: 13, minute: 0),
            ),
            _task('y', 'Całodniowe', start: _today(), createdOffset: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ania, Basia'), findsOneWidget);
    // Short blocks name their people too, not only the tall ones.
    expect(find.text('Ania'), findsNWidgets(2)); // legend chip + block
    expect(find.textContaining('Szybkie · Basia'), findsOneWidget);

    await tester.tap(find.text('Tydzień'));
    await tester.pumpAndSettle();
    expect(find.text('Ania, Basia'), findsNothing);
  });

  testWidgets('switching a person off in the legend hides their tasks', (
    tester,
  ) async {
    _setSize(tester, const Size(700, 900));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          isOwner: true,
          initialMode: CalendarViewMode.week,
          people: const [
            CalendarPerson(id: 'a', name: 'Ania'),
            CalendarPerson(id: 'b', name: 'Basia'),
          ],
          taskAssignments: const [
            TaskAssignmentModel(taskId: 'x', employeeId: 'a'),
            TaskAssignmentModel(taskId: 'y', employeeId: 'b'),
          ],
          tasks: [
            _task('x', 'Zadanie Ani', start: _today()),
            _task('y', 'Zadanie Basi', start: _today(), createdOffset: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zadanie Ani'), findsOneWidget);
    expect(find.text('Zadanie Basi'), findsOneWidget);

    await tester.tap(find.text('Basia'));
    await tester.pumpAndSettle();
    expect(find.text('Zadanie Ani'), findsOneWidget);
    expect(find.text('Zadanie Basi'), findsNothing);

    await tester.tap(find.text('Pokaż wszystkich'));
    await tester.pumpAndSettle();
    expect(find.text('Zadanie Basi'), findsOneWidget);
  });
}
