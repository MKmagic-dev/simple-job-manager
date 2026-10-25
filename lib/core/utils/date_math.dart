/// Calendar-day arithmetic that survives daylight-saving changes.
///
/// `date.add(Duration(days: n))` adds n × 24 hours, which on the day clocks
/// change is an hour off — midnight turns into 23:00 of the previous day and a
/// calendar cell shows the wrong date. These helpers move by calendar days.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole calendar days from [a] to [b] (negative when [b] is earlier),
/// ignoring the time of day and any 23/25-hour DST days in between.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
