-- Lets an employee leave a short note on their own shift asking the owner
-- to fix a mistake (wrong time, wrong day, ...), without giving them any
-- ability to edit the shift itself — only owners/admins can do that
-- (shifts_owner_all / shifts_admin_all already cover it).
--
-- A separate table (rather than a column on `shifts`) so RLS can cleanly
-- say "an employee may insert/read their own requests" without needing
-- column-level grants, and so the owner can just delete a row once handled
-- instead of needing an extra "resolved" flag.

create table public.shift_change_requests (
  id          uuid primary key default gen_random_uuid(),
  shift_id    uuid not null references public.shifts(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  message     text not null,
  created_at  timestamptz not null default now()
);

create index idx_shift_change_requests_shift on public.shift_change_requests (shift_id);

alter table public.shift_change_requests enable row level security;

-- Owner: full access, scoped to shifts in their own company.
create policy shift_change_requests_owner_all on public.shift_change_requests
  for all
  using (
    is_owner()
    and shift_id in (select id from public.shifts where company_id = my_company_id())
  );

-- Employee: can only file a request against their own shift, as themselves.
create policy shift_change_requests_employee_insert on public.shift_change_requests
  for insert
  with check (
    employee_id = auth.uid()
    and shift_id in (select id from public.shifts where employee_id = auth.uid())
  );

create policy shift_change_requests_employee_select on public.shift_change_requests
  for select
  using (employee_id = auth.uid());

create policy shift_change_requests_admin_all on public.shift_change_requests
  for all
  using (is_admin());
