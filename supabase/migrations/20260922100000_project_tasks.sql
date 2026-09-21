-- Tasks ("zadania") inside a project, e.g. "wylewanie fundamentów": a named
-- piece of work with a date range (working hours optional) and photos/PDFs.
--
-- People are NOT assigned to a task directly: an employee is put on the
-- project by getting shifts on it, and then onto a specific task by picking
-- that task on the shift (shifts.task_id). So "who is on this task" is
-- simply "who has a shift with this task_id".
--
-- Safe to run more than once, and also on a database where the first draft of
-- this migration (with a task_assignees table) was already applied.

alter table public.projects add column if not exists cover_path text;

create table if not exists public.project_tasks (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  project_id  uuid not null references public.projects(id) on delete cascade,
  title       text not null,
  description text,
  start_date  date not null,
  end_date    date not null,
  start_time  time,
  end_time    time,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  constraint project_tasks_dates_ordered check (end_date >= start_date)
);

create index if not exists idx_project_tasks_project on public.project_tasks (project_id);
create index if not exists idx_project_tasks_company_dates on public.project_tasks (company_id, start_date, end_date);

-- The first draft assigned people to tasks here; that now happens via shifts.
drop table if exists public.task_assignees cascade;

alter table public.shifts add column if not exists task_id uuid references public.project_tasks(id) on delete set null;
create index if not exists idx_shifts_task on public.shifts (task_id);

create table if not exists public.task_attachments (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references public.project_tasks(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete cascade,
  storage_path text not null,
  uploaded_by  uuid references public.profiles(id),
  created_at   timestamptz not null default now()
);

create index if not exists idx_task_attachments_task on public.task_attachments (task_id);

alter table public.project_tasks enable row level security;
alter table public.task_attachments enable row level security;

-- project_tasks ---------------------------------------------------------------

drop policy if exists project_tasks_owner_all on public.project_tasks;
create policy project_tasks_owner_all on public.project_tasks
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

drop policy if exists project_tasks_admin_all on public.project_tasks;
create policy project_tasks_admin_all on public.project_tasks
  for all
  using (is_admin());

-- An employee sees the tasks they have a shift on.
drop policy if exists project_tasks_employee_select on public.project_tasks;
create policy project_tasks_employee_select on public.project_tasks
  for select
  using (
    id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
  );

-- task_attachments ------------------------------------------------------------

drop policy if exists task_attachments_owner_all on public.task_attachments;
create policy task_attachments_owner_all on public.task_attachments
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

drop policy if exists task_attachments_admin_all on public.task_attachments;
create policy task_attachments_admin_all on public.task_attachments
  for all
  using (is_admin());

drop policy if exists task_attachments_employee_select on public.task_attachments;
create policy task_attachments_employee_select on public.task_attachments
  for select
  using (
    task_id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
  );

drop policy if exists task_attachments_employee_insert on public.task_attachments;
create policy task_attachments_employee_insert on public.task_attachments
  for insert
  with check (
    uploaded_by = auth.uid()
    and company_id = my_company_id()
    and task_id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
  );

-- storage bucket for task files (path: <company id>/<task id>/<ts>_<name>) ----

insert into storage.buckets (id, name, public)
values ('task-attachments', 'task-attachments', false)
on conflict (id) do nothing;

drop policy if exists task_attachments_owner_all_storage on storage.objects;
create policy task_attachments_owner_all_storage on storage.objects
  for all
  using (
    bucket_id = 'task-attachments'
    and is_owner()
    and (storage.foldername(name))[1] = my_company_id()::text
  )
  with check (
    bucket_id = 'task-attachments'
    and is_owner()
    and (storage.foldername(name))[1] = my_company_id()::text
  );

drop policy if exists task_attachments_admin_all_storage on storage.objects;
create policy task_attachments_admin_all_storage on storage.objects
  for all
  using (bucket_id = 'task-attachments' and is_admin());

drop policy if exists task_attachments_employee_insert_storage on storage.objects;
create policy task_attachments_employee_insert_storage on storage.objects
  for insert
  with check (
    bucket_id = 'task-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (storage.foldername(name))[2] in (
      select task_id::text from public.shifts where employee_id = auth.uid() and task_id is not null
    )
  );

drop policy if exists task_attachments_employee_select_storage on storage.objects;
create policy task_attachments_employee_select_storage on storage.objects
  for select
  using (
    bucket_id = 'task-attachments'
    and (storage.foldername(name))[2] in (
      select task_id::text from public.shifts where employee_id = auth.uid() and task_id is not null
    )
  );

-- Employees already see a project (and its files) through their shifts on it,
-- so the "via tasks" policies from the first draft are no longer needed.
drop policy if exists projects_employee_select_via_tasks on public.projects;
drop policy if exists project_attachments_employee_select_via_tasks on public.project_attachments;
drop policy if exists project_attachments_employee_select_storage_via_tasks on storage.objects;
drop policy if exists project_completion_notices_employee_insert_via_tasks on public.project_completion_notices;
