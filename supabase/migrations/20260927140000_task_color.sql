-- Optional color per task, so tasks of one project can be told apart on the
-- calendar. Null = automatic (the app picks a different palette color for each
-- task of a project).
--
-- Safe to run more than once.

alter table public.project_tasks add column if not exists color text;
