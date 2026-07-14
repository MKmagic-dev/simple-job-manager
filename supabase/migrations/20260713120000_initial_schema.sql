-- Simple Job Manager — baseline schema for a fresh client Supabase project.
--
-- This reproduces the schema that was reverse-engineered from the first
-- client's live project on 2026-07-13, with two RLS fixes applied (see notes
-- inline below) so that every new client starts from the secure version.
--
-- Deployment model: each client company gets its own separate Supabase
-- project (not a shared multi-tenant database), so `company_id` here scopes
-- data *within* one company's project (its boss + workers), not across
-- clients. RLS is still required because a project has many profiles
-- (owner + employees) who must not see each other's restricted data.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Enum: profiles.role
-- ---------------------------------------------------------------------
create type public.user_role as enum ('owner', 'employee');

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

create table public.companies (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

-- One row per authenticated user, 1:1 with auth.users. There is no
-- self-registration trigger — an owner creates the auth user + profile row
-- for each employee (see profiles_insert_owner policy below), matching the
-- app's "boss adds employees" flow.
create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  role       public.user_role not null,
  full_name  text not null,
  phone      text,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- RLS helper functions
--
-- These are SECURITY DEFINER so that RLS policies which query `profiles`
-- (to check the caller's own role/company) don't recursively re-trigger
-- profiles' own RLS policies. `set search_path = public` pins the schema
-- lookup path so a SECURITY DEFINER function can't be tricked by a caller
-- manipulating search_path — standard hardening for this pattern.
-- ---------------------------------------------------------------------

create or replace function public.is_owner()
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select role = 'owner' from profiles where id = auth.uid();
$$;

create or replace function public.my_company_id()
returns uuid
language sql
stable security definer
set search_path = public
as $$
  select company_id from profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- Remaining tables
-- ---------------------------------------------------------------------

create table public.projects (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text not null,
  address     text,
  description text,
  start_date  date,
  end_date    date,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);

create table public.shifts (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  project_id  uuid references public.projects(id) on delete set null,
  work_date   date not null,
  start_time  time not null,
  end_time    time not null,
  notes       text,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);

create index idx_shifts_company_date on public.shifts (company_id, work_date);
create index idx_shifts_employee_date on public.shifts (employee_id, work_date);

create table public.instructions (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  project_id  uuid references public.projects(id) on delete cascade,
  shift_id    uuid references public.shifts(id) on delete cascade,
  employee_id uuid references public.profiles(id) on delete cascade,
  title       text not null,
  content     text,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);

create table public.instruction_photos (
  id             uuid primary key default gen_random_uuid(),
  instruction_id uuid not null references public.instructions(id) on delete cascade,
  storage_path   text not null,
  uploaded_by    uuid references public.profiles(id),
  created_at     timestamptz not null default now()
);

create table public.work_photos (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  shift_id    uuid references public.shifts(id) on delete cascade,
  storage_path text not null,
  caption     text,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------

alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.shifts enable row level security;
alter table public.instructions enable row level security;
alter table public.instruction_photos enable row level security;
alter table public.work_photos enable row level security;

-- profiles ---------------------------------------------------------------

create policy profiles_select on public.profiles
  for select
  using (id = auth.uid() or (is_owner() and company_id = my_company_id()));

create policy profiles_insert_owner on public.profiles
  for insert
  with check (is_owner() and company_id = my_company_id());

create policy profiles_update_owner_or_self on public.profiles
  for update
  using (id = auth.uid() or (is_owner() and company_id = my_company_id()));

-- FIX (2026-07-13): the policy above only checks *whose row* is being
-- updated, not *which columns* change. Without this guard, an employee
-- could run `update profiles set role = 'owner'` on their own row and RLS
-- would allow it, since USING (id = auth.uid()) is satisfied and there was
-- no WITH CHECK restricting which columns may change. This trigger blocks
-- anyone who isn't already an owner from changing their own (or, since the
-- UPDATE policy's USING clause wouldn't let them target others anyway,
-- effectively their own) role or company_id.
create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    if new.role is distinct from old.role or new.company_id is distinct from old.company_id then
      raise exception 'Only an owner can change role or company_id';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_prevent_profile_privilege_escalation
  before update on public.profiles
  for each row
  execute function public.prevent_profile_privilege_escalation();

-- companies ----------------------------------------------------------------
-- (No policies observed on the source project — companies has exactly one
-- row per Supabase project under the per-client deployment model, so it
-- wasn't gated further. Revisit if that assumption changes.)

-- projects -------------------------------------------------------------

create policy projects_owner_all on public.projects
  for all
  using (is_owner() and company_id = my_company_id());

create policy projects_employee_select on public.projects
  for select
  using (
    company_id = my_company_id()
    and exists (
      select 1 from shifts
      where shifts.project_id = projects.id
        and shifts.employee_id = auth.uid()
    )
  );

-- shifts -----------------------------------------------------------------

create policy shifts_owner_all on public.shifts
  for all
  using (is_owner() and company_id = my_company_id());

create policy shifts_employee_select_own on public.shifts
  for select
  using (employee_id = auth.uid());

-- instructions -------------------------------------------------------------

create policy instructions_owner_all on public.instructions
  for all
  using (is_owner() and company_id = my_company_id());

create policy instructions_employee_select on public.instructions
  for select
  using (
    company_id = my_company_id()
    and (
      employee_id = auth.uid()
      or shift_id in (select id from shifts where shifts.employee_id = auth.uid())
    )
  );

-- instruction_photos ---------------------------------------------------

-- FIX (2026-07-13): the source project's equivalent policy was
-- `using (is_owner())` with no company check at all — instruction_photos
-- has no company_id column of its own, so that let an owner from ANY
-- company read/write/delete ANY other company's instruction photos via the
-- shared `is_owner()` check. Scoped here through instructions.company_id.
create policy instruction_photos_owner_all on public.instruction_photos
  for all
  using (
    is_owner()
    and instruction_id in (
      select id from instructions where company_id = my_company_id()
    )
  );

create policy instruction_photos_employee_select on public.instruction_photos
  for select
  using (
    instruction_id in (
      select id from instructions where instructions.employee_id = auth.uid()
    )
  );

-- work_photos ------------------------------------------------------------

create policy work_photos_owner_select on public.work_photos
  for select
  using (is_owner() and company_id = my_company_id());

create policy work_photos_employee_select_own on public.work_photos
  for select
  using (employee_id = auth.uid());

create policy work_photos_employee_insert_own on public.work_photos
  for insert
  with check (employee_id = auth.uid() and company_id = my_company_id());
