-- Archiving of projects and tasks.
--
-- A project or task is "archived" when archived_at is set (null = active).
-- Nothing is deleted: the task list, photos, files and shift history all stay
-- for the boss, in the "Archive" tab. What archiving changes:
--   * the boss stops seeing it in the day-to-day views (calendar, pickers);
--   * employees stop seeing it at all (enforced here, in RLS, not just in the
--     app): the project, its tasks, and the employee's shifts on it.
--
-- An employee can tell the boss "this task is done" (task_completion_notices,
-- same idea as project_completion_notices); the boss then archives it.
--
-- Safe to run more than once.

alter table public.projects add column if not exists archived_at timestamptz;
alter table public.project_tasks add column if not exists archived_at timestamptz;

create index if not exists idx_projects_company_archived on public.projects (company_id, archived_at);
create index if not exists idx_project_tasks_project_archived on public.project_tasks (project_id, archived_at);

-- SECURITY DEFINER on purpose: the employee policies below need to look at
-- projects.archived_at, but projects' own employee policy reads shifts, so a
-- plain subquery would make projects <-> shifts policies recurse forever.
create or replace function public.project_is_archived(pid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select archived_at is not null from public.projects where id = pid), false)
$$;

-- Employees no longer see archived projects, their tasks, or their shifts on them.

drop policy if exists projects_employee_select on public.projects;
create policy projects_employee_select on public.projects
  for select
  using (
    company_id = my_company_id()
    and archived_at is null
    and exists (
      select 1 from public.shifts
      where shifts.project_id = projects.id
        and shifts.employee_id = auth.uid()
    )
  );

drop policy if exists shifts_employee_select_own on public.shifts;
create policy shifts_employee_select_own on public.shifts
  for select
  using (
    employee_id = auth.uid()
    and (project_id is null or not public.project_is_archived(project_id))
  );

drop policy if exists project_tasks_employee_select on public.project_tasks;
create policy project_tasks_employee_select on public.project_tasks
  for select
  using (
    archived_at is null
    and id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
  );

-- "This task is done" notices ------------------------------------------------

create table if not exists public.task_completion_notices (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references public.project_tasks(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (task_id, employee_id)
);

create index if not exists idx_task_completion_notices_task on public.task_completion_notices (task_id);

alter table public.task_completion_notices enable row level security;

drop policy if exists task_completion_notices_owner_all on public.task_completion_notices;
create policy task_completion_notices_owner_all on public.task_completion_notices
  for all
  using (
    is_owner()
    and task_id in (select id from public.project_tasks where company_id = my_company_id())
  )
  with check (
    is_owner()
    and task_id in (select id from public.project_tasks where company_id = my_company_id())
  );

drop policy if exists task_completion_notices_admin_all on public.task_completion_notices;
create policy task_completion_notices_admin_all on public.task_completion_notices
  for all
  using (is_admin());

drop policy if exists task_completion_notices_employee_insert on public.task_completion_notices;
create policy task_completion_notices_employee_insert on public.task_completion_notices
  for insert
  with check (
    employee_id = auth.uid()
    and task_id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
  );

drop policy if exists task_completion_notices_employee_select on public.task_completion_notices;
create policy task_completion_notices_employee_select on public.task_completion_notices
  for select
  using (employee_id = auth.uid());
