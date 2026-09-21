-- Tasks ("zadania") inside a project: a named piece of work with a date range
-- (hours optional), one or more assigned employees, and photos/PDFs attached
-- by the boss or by the assigned employees. Replaces the earlier idea of
-- labelling groups of shifts with shifts.task_name.
--
-- Also adds a cover photo to projects.

alter table public.projects add column cover_path text;

-- --- project_tasks -----------------------------------------------------------

create table public.project_tasks (
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

create index idx_project_tasks_project on public.project_tasks (project_id);
create index idx_project_tasks_company_dates on public.project_tasks (company_id, start_date, end_date);

-- company_id is repeated here (rather than only reachable through
-- project_tasks) so this table's owner policy needs no subquery — a subquery
-- back into project_tasks would make it and project_tasks' employee policy
-- (which reads this table) reference each other, which Postgres rejects as
-- infinite policy recursion.
create table public.task_assignees (
  task_id     uuid not null references public.project_tasks(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  primary key (task_id, employee_id)
);

create index idx_task_assignees_employee on public.task_assignees (employee_id);

create table public.task_attachments (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references public.project_tasks(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete cascade,
  storage_path text not null,
  uploaded_by  uuid references public.profiles(id),
  created_at   timestamptz not null default now()
);

create index idx_task_attachments_task on public.task_attachments (task_id);

alter table public.project_tasks enable row level security;
alter table public.task_assignees enable row level security;
alter table public.task_attachments enable row level security;

-- project_tasks

create policy project_tasks_owner_all on public.project_tasks
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

create policy project_tasks_admin_all on public.project_tasks
  for all
  using (is_admin());

create policy project_tasks_employee_select on public.project_tasks
  for select
  using (
    id in (select task_id from public.task_assignees where employee_id = auth.uid())
  );

-- task_assignees

create policy task_assignees_owner_all on public.task_assignees
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

create policy task_assignees_admin_all on public.task_assignees
  for all
  using (is_admin());

create policy task_assignees_employee_select on public.task_assignees
  for select
  using (employee_id = auth.uid());

-- task_attachments

create policy task_attachments_owner_all on public.task_attachments
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

create policy task_attachments_admin_all on public.task_attachments
  for all
  using (is_admin());

create policy task_attachments_employee_select on public.task_attachments
  for select
  using (
    task_id in (select task_id from public.task_assignees where employee_id = auth.uid())
  );

create policy task_attachments_employee_insert on public.task_attachments
  for insert
  with check (
    uploaded_by = auth.uid()
    and company_id = my_company_id()
    and task_id in (select task_id from public.task_assignees where employee_id = auth.uid())
  );

-- --- storage bucket for task files ------------------------------------------
-- Path convention: <company id>/<task id>/<timestamp>_<filename>

insert into storage.buckets (id, name, public)
values ('task-attachments', 'task-attachments', false)
on conflict (id) do nothing;

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

create policy task_attachments_admin_all_storage on storage.objects
  for all
  using (bucket_id = 'task-attachments' and is_admin());

create policy task_attachments_employee_insert_storage on storage.objects
  for insert
  with check (
    bucket_id = 'task-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (storage.foldername(name))[2] in (
      select task_id::text from public.task_assignees where employee_id = auth.uid()
    )
  );

create policy task_attachments_employee_select_storage on storage.objects
  for select
  using (
    bucket_id = 'task-attachments'
    and (storage.foldername(name))[2] in (
      select task_id::text from public.task_assignees where employee_id = auth.uid()
    )
  );

-- --- employees can see a project (and its files) once they have a task on it

create policy projects_employee_select_via_tasks on public.projects
  for select
  using (
    company_id = my_company_id()
    and id in (select project_id from public.project_tasks)
  );

create policy project_attachments_employee_select_via_tasks on public.project_attachments
  for select
  using (
    project_id in (select project_id from public.project_tasks)
  );

create policy project_attachments_employee_select_storage_via_tasks on storage.objects
  for select
  using (
    bucket_id = 'project-attachments'
    and (storage.foldername(name))[2] in (
      select project_id::text from public.project_tasks
    )
  );

create policy project_completion_notices_employee_insert_via_tasks on public.project_completion_notices
  for insert
  with check (
    employee_id = auth.uid()
    and project_id in (select project_id from public.project_tasks)
  );
