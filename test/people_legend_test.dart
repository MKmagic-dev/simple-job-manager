import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/shifts/domain/shift_model.dart';
import 'package:simple_job_manager/features/shifts/presentation/calendar_shared.dart';
import 'package:simple_job_manager/features/shifts/presentation/schedule_calendar.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('the people legend explains itself and hides/shows a person', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ScheduleCalendar(
            shifts: [
              ShiftModel(
                id: 's1',
                companyId: 'c1',
                employeeId: 'a',
                workDate: day,
                startTime: const TimeOfDay(hour: 8, minute: 0),
                endTime: const TimeOfDay(hour: 16, minute: 0),
              ),
            ],
            projects: const [],
            people: const [
              CalendarPerson(id: 'a', name: 'Anna'),
              CalendarPerson(id: 'j', name: 'Jan'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The legend says what it is and how it works.
    expect(find.text('Osoby w grafiku'), findsOneWidget);
    expect(find.textContaining('Kliknij osobę, aby ukryć'), findsOneWidget);
    expect(find.text('Pokaż wszystkich'), findsNothing);

    // Tapping a person hides them (strikethrough + "show everyone" appears).
    await tester.tap(find.text('Jan'));
    await tester.pumpAndSettle();
    final hiddenStyle = tester.widget<Text>(find.text('Jan')).style;
    expect(hiddenStyle?.decoration, TextDecoration.lineThrough);
    expect(find.text('Pokaż wszystkich'), findsOneWidget);

    await tester.tap(find.text('Pokaż wszystkich'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Jan')).style?.decoration,
      isNot(TextDecoration.lineThrough),
    );
    expect(find.text('Pokaż wszystkich'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
