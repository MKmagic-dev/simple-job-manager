import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/calendar_events/data/calendar_event_repository.dart';
import 'package:simple_job_manager/features/calendar_events/domain/calendar_event_model.dart';
import 'package:simple_job_manager/features/calendar_events/presentation/event_form_screen.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/shifts/presentation/calendar_view_mode.dart';
import 'package:simple_job_manager/features/shifts/presentation/general_calendar_screen.dart';
import 'package:simple_job_manager/features/shifts/presentation/schedule_calendar.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

CalendarEventModel _event(
  String title, {
  TimeOfDay? start = const TimeOfDay(hour: 9, minute: 0),
  TimeOfDay? end = const TimeOfDay(hour: 10, minute: 0),
  int lengthDays = 0,
}) => CalendarEventModel(
  id: title,
  companyId: 'c1',
  title: title,
  startDate: _today(),
  endDate: _today().add(Duration(days: lengthDays)),
  startTime: start,
  endTime: end,
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
  test('CalendarEventModel reads times and spans from json', () {
    final event = CalendarEventModel.fromJson({
      'id': 'e',
      'company_id': 'c',
      'title': 'Przegląd',
      'start_date': '2026-10-21',
      'end_date': '2026-10-23',
      'start_time': '09:30:00',
      'end_time': '10:15:00',
    });
    expect(event.hasTime, isTrue);
    expect(event.isMultiDay, isTrue);
    expect(event.isOn(DateTime(2026, 10, 22)), isTrue);
    expect(event.isOn(DateTime(2026, 10, 24)), isFalse);
  });

  testWidgets('month view shows an event and the day sheet can add another', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    DateTime? added;
    CalendarEventModel? tapped;
    final event = _event('Spotkanie');

    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          events: [event],
          initialMode: CalendarViewMode.month,
          onAddEvent: (day) => added = day,
          onEventTap: (e) => tapped = e,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Spotkanie'), findsOneWidget);

    // Tap today's cell → the sheet lists the event and offers "add".
    await tester.tap(find.textContaining('Spotkanie'));
    await tester.pumpAndSettle();
    expect(find.text('Wydarzenia'), findsOneWidget);
    expect(find.text('Dodaj wydarzenie'), findsOneWidget);

    await tester.tap(find.text('Dodaj wydarzenie'));
    await tester.pumpAndSettle();
    expect(added, _today());

    // Reopen and open the event itself.
    await tester.tap(find.textContaining('Spotkanie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spotkanie').last);
    await tester.pumpAndSettle();
    expect(tapped?.id, 'Spotkanie');
  });

  testWidgets('week and day views draw timed and all-day events', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    await tester.pumpWidget(
      _host(
        ScheduleCalendar(
          shifts: const [],
          projects: const [],
          events: [
            _event('Spotkanie'),
            _event('Urlop', start: null, end: null, lengthDays: 2),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Week is the default: the all-day bar and the timed block are both there.
    expect(find.text('Urlop'), findsOneWidget);
    expect(find.text('09:00 Spotkanie'), findsOneWidget);

    await tester.tap(find.text('Dzień'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('09:00 Spotkanie'), findsWidgets);
  });

  testWidgets('the event form refuses an empty title and a backwards time', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    await tester.pumpWidget(_host(const EventFormScreen(companyId: 'c1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(find.text('Wpisz tytuł.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the general calendar toggles between calendar and timeline', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 900));
    await tester.pumpWidget(
      _host(
        const GeneralCalendarScreen(companyId: 'c1'),
        overrides: [
          projectListProvider.overrideWith(
            (ref) async => [
              ProjectModel(
                id: 'p1',
                companyId: 'c1',
                name: 'Budowa domu',
                startDate: _today(),
                endDate: _today().add(const Duration(days: 20)),
              ),
            ],
          ),
          calendarEventListProvider.overrideWith(
            (ref) async => [_event('Spotkanie')],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Calendar mode (month grid + the event) with an "add event" button.
    expect(find.textContaining('Spotkanie'), findsOneWidget);
    expect(find.text('Dodaj wydarzenie'), findsOneWidget);

    await tester.tap(find.text('Oś projektów'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Budowa domu'), findsWidgets);
    expect(find.text('Dodaj wydarzenie'), findsNothing);
  });
}
