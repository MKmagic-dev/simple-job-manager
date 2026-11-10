import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/calendar_events/domain/calendar_event_model.dart';
import 'package:simple_job_manager/features/shifts/presentation/calendar_view_mode.dart';
import 'package:simple_job_manager/features/shifts/presentation/schedule_calendar.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('pl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('a reminder due today shows a badge on today in the month grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          showProjectBars: false,
          initialMode: CalendarViewMode.month,
          events: [
            CalendarEventModel(
              id: 'e1',
              companyId: 'c1',
              title: 'Dentysta',
              startDate: today,
              endDate: today,
              remindSameDay: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(
        ValueKey('reminders-${today.year}-${today.month}-${today.day}'),
      ),
      findsOneWidget,
    );
  });
}
