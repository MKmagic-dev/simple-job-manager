-- Notes an employee writes to the boss about a task ("notatka do szefa"),
-- next to the photos/files of that task.
--
-- Who sees what:
--   * the boss (owner) and the admin: every note of their company,
--   * a project admin: the notes of tasks in their projects,
--   * an employee: only the notes they wrote themselves, and only on tasks
--     they are on (assigned or with a shift); they may delete their own note.
--
-- company_id is stored on the row so these policies never read project_tasks
-- (same reasoning as task_assignees). Safe to run more than once.

create table if not exists public.task_notes (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references public.project_tasks(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  author_id   uuid not null references public.profiles(id) on delete cascade,
  content     text not null check (char_length(btrim(content)) between 1 and 2000),
  created_at  timestamptz not null default now()
);

create index if not exists idx_task_notes_task on public.task_notes (task_id);
create index if not exists idx_task_notes_company on public.task_notes (company_id);

alter table public.task_notes enable row level security;

drop policy if exists task_notes_owner_all on public.task_notes;
create policy task_notes_owner_all on public.task_notes
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

drop policy if exists task_notes_admin_all on public.task_notes;
create policy task_notes_admin_all on public.task_notes
  for all
  using (is_admin());

drop policy if exists task_notes_manager_select on public.task_notes;
create policy task_notes_manager_select on public.task_notes
  for select
  using (
    task_id in (select public.managed_task_ids())
    and company_id = my_company_id()
  );

drop policy if exists task_notes_employee_select on public.task_notes;
create policy task_notes_employee_select on public.task_notes
  for select
  using (author_id = auth.uid());

drop policy if exists task_notes_employee_insert on public.task_notes;
create policy task_notes_employee_insert on public.task_notes
  for insert
  with check (
    author_id = auth.uid()
    and company_id = my_company_id()
    and (
      task_id in (select task_id from public.task_assignees where employee_id = auth.uid())
      or task_id in (select task_id from public.shifts where employee_id = auth.uid() and task_id is not null)
    )
  );

drop policy if exists task_notes_employee_delete on public.task_notes;
create policy task_notes_employee_delete on public.task_notes
  for delete
  using (author_id = auth.uid());
