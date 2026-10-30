-- Project administrators ("admin projektu").
--
-- An employee can be made an administrator of specific projects only: in
-- project_members, role 'manager' instead of 'member'. They stay an ordinary
-- employee (profiles.role = 'employee') and can manage THOSE projects — edit
-- them, their tasks, shifts, files and team — but nothing else: they can't
-- create or delete projects, change anyone's role, remove people from the
-- company, or touch other projects. Only the company owner grants/revokes
-- this (project_members_owner_all already covers it).
--
-- The helper functions are SECURITY DEFINER on purpose: policies on
-- project_tasks / shifts / project_members need to ask "is the caller a
-- manager of this project?", and answering that by querying those same
-- tables from inside their own policies would recurse.
--
-- Safe to run more than once.

alter table public.project_members add column if not exists role text not null default 'member';
alter table public.project_members drop constraint if exists project_members_role_check;
alter table public.project_members
  add constraint project_members_role_check check (role in ('member', 'manager'));

-- Helpers ---------------------------------------------------------------------

create or replace function public.managed_project_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select project_id from public.project_members
  where employee_id = auth.uid() and role = 'manager'
$$;

create or replace function public.managed_task_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select t.id from public.project_tasks t
  where t.project_id in (select public.managed_project_ids())
$$;

create or replace function public.is_project_manager_anywhere()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.project_members
    where employee_id = auth.uid() and role = 'manager'
  )
$$;

-- project_members: a manager sees the whole team of their projects and can add /
-- remove ordinary members, but can't create or remove other managers ------------

drop policy if exists project_members_manager_select on public.project_members;
create policy project_members_manager_select on public.project_members
  for select
  using (project_id in (select public.managed_project_ids()));

drop policy if exists project_members_manager_insert on public.project_members;
create policy project_members_manager_insert on public.project_members
  for insert
  with check (
    project_id in (select public.managed_project_ids())
    and company_id = my_company_id()
    and role = 'member'
  );

drop policy if exists project_members_manager_delete on public.project_members;
create policy project_members_manager_delete on public.project_members
  for delete
  using (
    project_id in (select public.managed_project_ids())
    and role = 'member'
  );

-- projects: edit (and archive) their own projects -------------------------------

drop policy if exists projects_manager_update on public.projects;
create policy projects_manager_update on public.projects
  for update
  using (id in (select public.managed_project_ids()) and company_id = my_company_id())
  with check (id in (select public.managed_project_ids()) and company_id = my_company_id());

-- tasks, assignees, task files ---------------------------------------------------

drop policy if exists project_tasks_manager_all on public.project_tasks;
create policy project_tasks_manager_all on public.project_tasks
  for all
  using (project_id in (select public.managed_project_ids()) and company_id = my_company_id())
  with check (project_id in (select public.managed_project_ids()) and company_id = my_company_id());

drop policy if exists task_assignees_manager_all on public.task_assignees;
create policy task_assignees_manager_all on public.task_assignees
  for all
  using (task_id in (select public.managed_task_ids()) and company_id = my_company_id())
  with check (task_id in (select public.managed_task_ids()) and company_id = my_company_id());

drop policy if exists task_attachments_manager_all on public.task_attachments;
create policy task_attachments_manager_all on public.task_attachments
  for all
  using (task_id in (select public.managed_task_ids()) and company_id = my_company_id())
  with check (task_id in (select public.managed_task_ids()) and company_id = my_company_id());

-- shifts on their projects --------------------------------------------------------

drop policy if exists shifts_manager_all on public.shifts;
create policy shifts_manager_all on public.shifts
  for all
  using (project_id in (select public.managed_project_ids()) and company_id = my_company_id())
  with check (project_id in (select public.managed_project_ids()) and company_id = my_company_id());

-- project files ---------------------------------------------------------------------

drop policy if exists project_attachments_manager_all on public.project_attachments;
create policy project_attachments_manager_all on public.project_attachments
  for all
  using (project_id in (select public.managed_project_ids()))
  with check (project_id in (select public.managed_project_ids()));

-- "Done" notices on their projects/tasks ---------------------------------------------

drop policy if exists project_completion_notices_manager_select on public.project_completion_notices;
create policy project_completion_notices_manager_select on public.project_completion_notices
  for select
  using (project_id in (select public.managed_project_ids()));

drop policy if exists project_completion_notices_manager_delete on public.project_completion_notices;
create policy project_completion_notices_manager_delete on public.project_completion_notices
  for delete
  using (project_id in (select public.managed_project_ids()));

drop policy if exists task_completion_notices_manager_select on public.task_completion_notices;
create policy task_completion_notices_manager_select on public.task_completion_notices
  for select
  using (task_id in (select public.managed_task_ids()));

drop policy if exists task_completion_notices_manager_delete on public.task_completion_notices;
create policy task_completion_notices_manager_delete on public.task_completion_notices
  for delete
  using (task_id in (select public.managed_task_ids()));

-- storage buckets ------------------------------------------------------------------

drop policy if exists project_attachments_manager_storage on storage.objects;
create policy project_attachments_manager_storage on storage.objects
  for all
  using (
    bucket_id = 'project-attachments'
    and (storage.foldername(name))[2] in (
      select p::text from public.managed_project_ids() p
    )
  )
  with check (
    bucket_id = 'project-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (storage.foldername(name))[2] in (
      select p::text from public.managed_project_ids() p
    )
  );

drop policy if exists task_attachments_manager_storage on storage.objects;
create policy task_attachments_manager_storage on storage.objects
  for all
  using (
    bucket_id = 'task-attachments'
    and (storage.foldername(name))[2] in (
      select t::text from public.managed_task_ids() t
    )
  )
  with check (
    bucket_id = 'task-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (storage.foldername(name))[2] in (
      select t::text from public.managed_task_ids() t
    )
  );

-- A manager needs to see the company's people to build their project teams ------------

drop policy if exists profiles_select_for_managers on public.profiles;
create policy profiles_select_for_managers on public.profiles
  for select
  using (company_id = my_company_id() and public.is_project_manager_anywhere());

-- Instructions on their projects (and the files attached to them) ----------------------

drop policy if exists instructions_manager_all on public.instructions;
create policy instructions_manager_all on public.instructions
  for all
  using (project_id in (select public.managed_project_ids()) and company_id = my_company_id())
  with check (project_id in (select public.managed_project_ids()) and company_id = my_company_id());

drop policy if exists instruction_photos_manager_all on public.instruction_photos;
create policy instruction_photos_manager_all on public.instruction_photos
  for all
  using (
    instruction_id in (
      select id from public.instructions
      where project_id in (select public.managed_project_ids())
    )
  )
  with check (
    instruction_id in (
      select id from public.instructions
      where project_id in (select public.managed_project_ids())
    )
  );

drop policy if exists instruction_attachments_manager_storage on storage.objects;
create policy instruction_attachments_manager_storage on storage.objects
  for all
  using (
    bucket_id = 'instruction-attachments'
    and (storage.foldername(name))[2] in (
      select id::text from public.instructions
      where project_id in (select public.managed_project_ids())
    )
  )
  with check (
    bucket_id = 'instruction-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (storage.foldername(name))[2] in (
      select id::text from public.instructions
      where project_id in (select public.managed_project_ids())
    )
  );
