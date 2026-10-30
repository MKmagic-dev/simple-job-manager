-- A project administrator is still an employee: they must not see the rest of
-- the company. Narrow what they can see to the people on THEIR projects, and
-- leave composing the team (adding / removing people) to the company owner.
--
-- Replaces profiles_select_for_managers (which exposed every profile in the
-- company, the owner included) and drops the manager insert/delete policies on
-- project_members.
--
-- Safe to run more than once.

create or replace function public.managed_team_member_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select employee_id from public.project_members
  where project_id in (select public.managed_project_ids())
$$;

drop policy if exists profiles_select_for_managers on public.profiles;
create policy profiles_select_for_managers on public.profiles
  for select
  using (
    company_id = my_company_id()
    and id in (select public.managed_team_member_ids())
  );

drop policy if exists project_members_manager_insert on public.project_members;
drop policy if exists project_members_manager_delete on public.project_members;
