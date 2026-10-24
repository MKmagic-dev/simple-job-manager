import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/shifts/presentation/calendar_view_mode.dart';
import 'package:simple_job_manager/features/shifts/presentation/schedule_calendar.dart';
import 'package:simple_job_manager/features/tasks/domain/project_task_model.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Widget _calendar(List<ProjectTaskModel> tasks, CalendarViewMode mode) {
  return MaterialApp(
    locale: const Locale('pl'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ScheduleCalendar(
        shifts: const [],
        projects: [ProjectModel(id: 'p', companyId: 'c', name: 'P')],
        tasks: tasks,
        showProjectBars: false,
        initialMode: mode,
      ),
    ),
  );
}

ProjectTaskModel _task(String title, DateTime start, {int days = 3}) =>
    ProjectTaskModel(
      id: title,
      companyId: 'c',
      projectId: 'p',
      title: title,
      startDate: start,
      endDate: start.add(Duration(days: days - 1)),
      createdAt: _today(),
    );

void _setSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the week view follows the month you were looking at', (
    tester,
  ) async {
    _setSize(tester);
    // A task on the 1st of NEXT month, which today's week (almost) never shows.
    final next = DateTime(_today().year, _today().month + 1, 1);
    await tester.pumpWidget(
      _calendar([_task('Fundamenty', next)], CalendarViewMode.month),
    );
    await tester.pumpAndSettle();

    // Step the month view to next month, then switch to the week view: it has
    // to open on that month (the week containing the 1st), with the task in it
    // — not snap back to the current week.
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    expect(find.text('Fundamenty'), findsWidgets);

    await tester.tap(find.text('Tydzień'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Fundamenty'), findsOneWidget);
  });

  testWidgets('a task this month stays in view when switching month → week', (
    tester,
  ) async {
    _setSize(tester);
    // A task that starts today, so today's week must show it.
    await tester.pumpWidget(
      _calendar([_task('Dzisiejsze', _today())], CalendarViewMode.month),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Dzisiejsze'), findsWidgets);

    await tester.tap(find.text('Tydzień'));
    await tester.pumpAndSettle();
    expect(find.text('Dzisiejsze'), findsOneWidget);

    await tester.tap(find.text('Dzień'));
    await tester.pumpAndSettle();
    expect(find.text('Dzisiejsze'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moving the week forward is remembered by the month view', (
    tester,
  ) async {
    _setSize(tester);
    final target = _today().add(const Duration(days: 40));
    await tester.pumpWidget(
      _calendar([_task('Odległe', target)], CalendarViewMode.week),
    );
    await tester.pumpAndSettle();

    // Step the week view forward ~6 weeks, then look at the month: it must be
    // the month we ended up in, with the task visible.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Miesiąc'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Odległe'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
