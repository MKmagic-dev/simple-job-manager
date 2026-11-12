-- When the boss read an employee's note on a task. Null = not read yet, so the
-- task, its tab and its project show a badge until the boss opens the task.
-- The boss already may update notes of the company (task_notes_owner_all).
--
-- Safe to run more than once.

alter table public.task_notes
  add column if not exists read_at timestamptz;

create index if not exists idx_task_notes_unread
  on public.task_notes (company_id)
  where read_at is null;
