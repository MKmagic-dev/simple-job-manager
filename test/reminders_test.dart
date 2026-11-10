import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/calendar_events/domain/calendar_event_model.dart';

CalendarEventModel _event(
  String id, {
  required DateTime start,
  String reminder = 'none',
  DateTime? end,
}) => CalendarEventModel(
  id: id,
  companyId: 'c1',
  title: 'Dentysta $id',
  startDate: start,
  endDate: end ?? start,
  reminder: reminder,
);

void main() {
  final friday = DateTime(2026, 11, 13);
  final thursday = DateTime(2026, 11, 12);

  test('the reminder day is the event day or the morning before it', () {
    expect(
      _event('a', start: friday, reminder: 'morning_same_day').reminderDate,
      friday,
    );
    expect(
      _event('b', start: friday, reminder: 'morning_day_before').reminderDate,
      thursday,
    );
    expect(_event('c', start: friday).reminderDate, isNull);
  });

  test('the day before works across a month boundary', () {
    final first = DateTime(2026, 12, 1);
    expect(
      _event('d', start: first, reminder: 'morning_day_before').reminderDate,
      DateTime(2026, 11, 30),
    );
  });

  test('a reminder shows only on its own day', () {
    final events = [_event('a', start: friday, reminder: 'morning_day_before')];
    expect(remindersOn(thursday, events, {}), hasLength(1));
    expect(remindersOn(friday, events, {}), isEmpty);
  });

  test('a closed reminder no longer shows', () {
    final events = [
      _event('a', start: friday, reminder: 'morning_day_before'),
      _event('b', start: friday, reminder: 'morning_day_before'),
    ];
    final closed = {reminderKey('a', thursday)};
    final left = remindersOn(thursday, events, closed);
    expect(left.map((e) => e.id), ['b']);
  });

  test('closing a reminder does not hide it on another day', () {
    final event = _event('a', start: friday, reminder: 'morning_same_day');
    final closedOnThursday = {reminderKey('a', thursday)};
    expect(remindersOn(friday, [event], closedOnThursday), hasLength(1));
  });

  test('events without a reminder never show up', () {
    expect(remindersOn(friday, [_event('a', start: friday)], {}), isEmpty);
  });
}
