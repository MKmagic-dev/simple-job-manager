import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/calendar_events/domain/calendar_event_model.dart';

CalendarEventModel _event(
  String id, {
  required DateTime start,
  bool sameDay = false,
  bool dayBefore = false,
}) => CalendarEventModel(
  id: id,
  companyId: 'c1',
  title: 'Dentysta $id',
  startDate: start,
  endDate: start,
  remindSameDay: sameDay,
  remindDayBefore: dayBefore,
);

void main() {
  final friday = DateTime(2026, 11, 13);
  final thursday = DateTime(2026, 11, 12);

  test('the reminder days are the event day and/or the day before', () {
    expect(_event('a', start: friday, sameDay: true).reminderDays, [friday]);
    expect(_event('b', start: friday, dayBefore: true).reminderDays, [
      thursday,
    ]);
    expect(_event('c', start: friday).reminderDays, isEmpty);
  });

  test('both reminders can be on at once', () {
    final both = _event('d', start: friday, sameDay: true, dayBefore: true);
    expect(both.reminderDays, [thursday, friday]);
    expect(remindersOn(thursday, [both], {}), hasLength(1));
    expect(remindersOn(friday, [both], {}), hasLength(1));
  });

  test('the day before works across a month boundary', () {
    final first = DateTime(2026, 12, 1);
    expect(_event('e', start: first, dayBefore: true).reminderDays, [
      DateTime(2026, 11, 30),
    ]);
  });

  test('a reminder shows only on its own day', () {
    final events = [_event('a', start: friday, dayBefore: true)];
    expect(remindersOn(thursday, events, {}), hasLength(1));
    expect(remindersOn(friday, events, {}), isEmpty);
  });

  test('a closed reminder no longer shows', () {
    final events = [
      _event('a', start: friday, dayBefore: true),
      _event('b', start: friday, dayBefore: true),
    ];
    final closed = {reminderKey('a', thursday)};
    final left = remindersOn(thursday, events, closed);
    expect(left.map((due) => due.event.id), ['b']);
  });

  test('closing a reminder does not hide it on its other day', () {
    final event = _event('a', start: friday, sameDay: true, dayBefore: true);
    final closedOnThursday = {reminderKey('a', thursday)};
    expect(remindersOn(friday, [event], closedOnThursday), hasLength(1));
    expect(remindersOn(thursday, [event], closedOnThursday), isEmpty);
  });

  test('events without a reminder never show up', () {
    expect(remindersOn(friday, [_event('a', start: friday)], {}), isEmpty);
  });
}
