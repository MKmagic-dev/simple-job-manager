-- A reminder can now be "on the day" and/or "the day before" at the same time,
-- so the single choice column from 20261110110000 becomes two flags.
--
-- Safe to run more than once.

alter table public.calendar_events
  drop constraint if exists calendar_events_reminder_valid;

alter table public.calendar_events
  drop column if exists reminder;

alter table public.calendar_events
  add column if not exists remind_same_day boolean not null default false,
  add column if not exists remind_day_before boolean not null default false;
