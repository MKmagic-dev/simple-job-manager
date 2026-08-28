-- Step 2 of 2 for the shared multi-tenant + admin role migration.
-- Run this AFTER step1 has already been run and committed on its own.
--
-- What this does:
--   1. Admin profiles aren't tied to any one company, so company_id must
--      become optional — but only for admins (a check constraint keeps it
--      required for everyone else).
--   2. Adds an is_admin() helper, matching the existing is_owner() /
--      my_company_id() pattern, so admin-access checks read the same way
--      everywhere.
--   3. Updates the privilege-escalation guard trigger so an admin (not just
--      an owner) is allowed to change someone's role/company_id — needed
--      for the admin panel to actually manage accounts.
--   4. Adds "admin can do anything, anywhere" policies to every table, and
--      also adds real policies to `companies` — before this migration, the
--      table had RLS enabled but *no* policies at all, which was fine when
--      every project held exactly one company (nobody needed to query it
--      directly) but breaks now that many companies share one project.

-- 1. company_id becomes optional for admins only.
alter table public.profiles alter column company_id drop not null;
alter table public.profiles
  add constraint profiles_company_id_required_unless_admin
  check (role = 'admin' or company_id is not null);

-- 2. Admin helper, same pattern as is_owner()/my_company_id().
create or replace function public.is_admin()
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select role = 'admin' from profiles where id = auth.uid();
$$;

-- 3. Let admins manage role/company_id too, not just owners.
create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (public.is_owner() or public.is_admin()) then
    if new.role is distinct from old.role or new.company_id is distinct from old.company_id then
      raise exception 'Only an owner or an admin can change role or company_id';
    end if;
  end if;
  return new;
end;
$$;

-- 4a. companies — previously had zero policies.
create policy companies_admin_all on public.companies
  for all
  using (is_admin());

create policy companies_member_select on public.companies
  for select
  using (id = my_company_id());

-- 4b. Admin bypass on every other table.
create policy profiles_admin_all on public.profiles
  for all
  using (is_admin());

create policy projects_admin_all on public.projects
  for all
  using (is_admin());

create policy shifts_admin_all on public.shifts
  for all
  using (is_admin());

create policy instructions_admin_all on public.instructions
  for all
  using (is_admin());

create policy instruction_photos_admin_all on public.instruction_photos
  for all
  using (is_admin());

create policy work_photos_admin_all on public.work_photos
  for all
  using (is_admin());

-- 4c. Admin bypass on the work-photos storage bucket too.
create policy work_photos_admin_all_storage on storage.objects
  for all
  using (bucket_id = 'work-photos' and is_admin());
