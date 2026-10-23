-- Who performs a task, chosen when the task is created/edited (in addition to
-- shifts, which still say exactly when someone works on it). A person counts
-- as being on a task if they're listed here OR have a shift with that task.
--
-- company_id is stored on the row (not looked up from project_tasks) so these
-- policies never read project_tasks, whose employee policy reads this table —
-- that would be a policy recursion.
--
-- Safe to run more than once.

create table if not exists public.task_assignees (
  task_id     uuid not null references public.project_tasks(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (task_id, employee_id)
);

create index if not exists idx_task_assignees_employee on public.task_assignees (employee_id);
create index if not exists idx_task_assignees_company on public.task_assignees (company_id);

alter table public.task_assignees enable row level security;

drop policy if exists task_assignees_owner_all on public.task_assignees;
create policy task_assignees_owner_all on public.task_assignees
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

drop policy if exists task_assignees_admin_all on public.task_assignees;
create policy task_assignees_admin_all on public.task_assignees
  for all
  using (is_admin());

drop policy if exists task_assignees_employee_select on public.task_assignees;
create policy task_assignees_employee_select on public.task_assignees
  for select
  using (employee_id = auth.uid());

-- An employee sees the tasks they're assigned to or have a shift on ---------

drop policy if exists project_tasks_employee_select on public.project_tasks;
create policy project_tasks_employee_select on public.project_tasks
  for select
  using (
    archived_at is null
    and (
      id in (select task_id from public.task_assignees where employee_id = auth.uid())
      or id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
    )
  );

drop policy if exists task_attachments_employee_select on public.task_attachments;
create policy task_attachments_employee_select on public.task_attachments
  for select
  using (
    task_id in (select task_id from public.task_assignees where employee_id = auth.uid())
    or task_id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
  );

drop policy if exists task_attachments_employee_insert on public.task_attachments;
create policy task_attachments_employee_insert on public.task_attachments
  for insert
  with check (
    uploaded_by = auth.uid()
    and company_id = my_company_id()
    and (
      task_id in (select task_id from public.task_assignees where employee_id = auth.uid())
      or task_id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
    )
  );

drop policy if exists task_attachments_employee_insert_storage on storage.objects;
create policy task_attachments_employee_insert_storage on storage.objects
  for insert
  with check (
    bucket_id = 'task-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (
      (storage.foldername(name))[2] in (
        select task_id::text from public.task_assignees where employee_id = auth.uid()
      )
      or (storage.foldername(name))[2] in (
        select task_id::text from public.shifts where employee_id = auth.uid() and task_id is not null
      )
    )
  );

drop policy if exists task_attachments_employee_select_storage on storage.objects;
create policy task_attachments_employee_select_storage on storage.objects
  for select
  using (
    bucket_id = 'task-attachments'
    and (
      (storage.foldername(name))[2] in (
        select task_id::text from public.task_assignees where employee_id = auth.uid()
      )
      or (storage.foldername(name))[2] in (
        select task_id::text from public.shifts where employee_id = auth.uid() and task_id is not null
      )
    )
  );
