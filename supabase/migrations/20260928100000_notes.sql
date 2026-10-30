-- Notes ("notatki"): free-form notes the boss keeps, optionally shared with
-- chosen employees. Not the same as instructions (those belong to projects).
--
--  * notes: title + text, owned by the company; only owners/admins manage them.
--  * note_recipients: which employees (optionally) can read a note. A note with
--    no recipients is just the boss's own.
--
-- An employee sees only the notes shared with THEM, and only their own
-- recipient rows — never who else a note was shared with. company_id is stored
-- on note_recipients so its policies never read notes (whose employee policy
-- reads note_recipients), which would be a policy recursion.
--
-- Safe to run more than once.

create table if not exists public.notes (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  title      text not null,
  content    text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notes_company_created on public.notes (company_id, created_at desc);

create table if not exists public.note_recipients (
  note_id     uuid not null references public.notes(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  primary key (note_id, employee_id)
);

create index if not exists idx_note_recipients_employee on public.note_recipients (employee_id);

alter table public.notes enable row level security;
alter table public.note_recipients enable row level security;

drop policy if exists notes_owner_all on public.notes;
create policy notes_owner_all on public.notes
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

drop policy if exists notes_admin_all on public.notes;
create policy notes_admin_all on public.notes
  for all
  using (is_admin());

drop policy if exists notes_employee_select on public.notes;
create policy notes_employee_select on public.notes
  for select
  using (
    id in (select note_id from public.note_recipients where employee_id = auth.uid())
  );

drop policy if exists note_recipients_owner_all on public.note_recipients;
create policy note_recipients_owner_all on public.note_recipients
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

drop policy if exists note_recipients_admin_all on public.note_recipients;
create policy note_recipients_admin_all on public.note_recipients
  for all
  using (is_admin());

drop policy if exists note_recipients_employee_select on public.note_recipients;
create policy note_recipients_employee_select on public.note_recipients
  for select
  using (employee_id = auth.uid());
