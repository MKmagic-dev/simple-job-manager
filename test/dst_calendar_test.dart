import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/core/utils/date_math.dart';
import 'package:simple_job_manager/features/calendar_events/domain/calendar_event_model.dart';
import 'package:simple_job_manager/features/shifts/presentation/month_calendar_view.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

// Clocks go back on the last Sunday of October (25 Oct 2026 in Europe) and
// forward on the last Sunday of March (29 Mar 2026). On a machine set to such
// a timezone, naive "+ 24 hours" arithmetic shifts every calendar cell after
// the change by a day; these tests pin fixed dates around both changes.
void main() {
  test('addDays moves by calendar days across a clock change', () {
    expect(addDays(DateTime(2026, 10, 24), 1), DateTime(2026, 10, 25));
    expect(addDays(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
    expect(addDays(DateTime(2026, 10, 24), 42), DateTime(2026, 12, 5));
    expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
    expect(addDays(DateTime(2026, 11, 2), -9), DateTime(2026, 10, 24));
  });

  test('daysBetween counts whole days across a clock change', () {
    expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    expect(daysBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 24)), -2);
    expect(daysBetween(DateTime(2026, 5, 1), DateTime(2026, 5, 1)), 0);
  });

  for (final (label, month, eventDay) in [
    ('October (clocks back)', DateTime(2026, 10, 15), DateTime(2026, 10, 25)),
    ('March (clocks forward)', DateTime(2026, 3, 15), DateTime(2026, 3, 29)),
  ]) {
    testWidgets('month grid shows each day once in $label', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MonthCalendarView(
              shifts: const [],
              projects: const [],
              focusDate: month,
              events: [
                CalendarEventModel(
                  id: 'e',
                  companyId: 'c',
                  title: 'Jedno',
                  startDate: eventDay,
                  endDate: eventDay,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One event on one day → exactly one chip in the whole grid.
      expect(find.text('Jedno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
