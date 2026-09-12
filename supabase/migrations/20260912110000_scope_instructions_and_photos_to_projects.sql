-- Instructions already had a nullable project_id column (unused until now).
-- Work photos gets one added here too, so both can be filtered/created from
-- within a project's screen instead of only from the global main-panel
-- lists, which stay as read-only views.
alter table public.work_photos add column project_id uuid references public.projects(id) on delete set null;

create index idx_work_photos_project on public.work_photos (project_id);
