-- A note can optionally be tagged with a project and/or a task. It is only a
-- label shown on the note itself in the Notes tab — notes never appear in the
-- calendar, the schedule or the project's own tabs.
--
-- on delete set null: deleting the project/task leaves the note, untagged.
--
-- Safe to run more than once.

alter table public.notes add column if not exists project_id uuid references public.projects(id) on delete set null;
alter table public.notes add column if not exists task_id uuid references public.project_tasks(id) on delete set null;

create index if not exists idx_notes_project on public.notes (project_id);
