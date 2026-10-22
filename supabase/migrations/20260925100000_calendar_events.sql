-- General calendar events / reminders ("wydarzenia i przypominajki").
--
-- Personal to whoever creates them (a boss's own calendar notes, or an
-- employee's), not tied to a project: a title, optional note, a date range,
-- and either a time of day or "all day". Nobody else in the company sees them.
--
-- Safe to run more than once.

create table if not exists public.calendar_events (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  title      text not null,
  notes      text,
  start_date date not null,
  end_date   date not null,
  start_time time,
  end_time   time,
  created_at timestamptz not null default now(),
  constraint calendar_events_dates_ordered check (end_date >= start_date)
);

create index if not exists idx_calendar_events_owner_dates
  on public.calendar_events (created_by, start_date, end_date);

alter table public.calendar_events enable row level security;

drop policy if exists calendar_events_own_all on public.calendar_events;
create policy calendar_events_own_all on public.calendar_events
  for all
  using (created_by = auth.uid() and company_id = my_company_id())
  with check (created_by = auth.uid() and company_id = my_company_id());

drop policy if exists calendar_events_admin_all on public.calendar_events;
create policy calendar_events_admin_all on public.calendar_events
  for all
  using (is_admin());
