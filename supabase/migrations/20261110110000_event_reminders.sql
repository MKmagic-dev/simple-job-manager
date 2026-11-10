-- Reminders on calendar events ("przypomnienie"): a morning reminder on the
-- day of the event or the day before. The reminder shows as a badge on that
-- day of the calendar and as a popup when the app is opened; closing the popup
-- marks it as read (a row in calendar_event_acks), so the badge goes away.
--
-- Each user acknowledges their own reminders, on any of their devices.
-- Safe to run more than once.

alter table public.calendar_events
  add column if not exists reminder text not null default 'none';

do $$
begin
  alter table public.calendar_events
    add constraint calendar_events_reminder_valid
    check (reminder in ('none', 'morning_same_day', 'morning_day_before'));
exception
  when duplicate_object then null;
end $$;

create table if not exists public.calendar_event_acks (
  event_id      uuid not null references public.calendar_events(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  reminder_date date not null,
  acknowledged_at timestamptz not null default now(),
  primary key (event_id, user_id, reminder_date)
);

alter table public.calendar_event_acks enable row level security;

drop policy if exists calendar_event_acks_own_all on public.calendar_event_acks;
create policy calendar_event_acks_own_all on public.calendar_event_acks
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
