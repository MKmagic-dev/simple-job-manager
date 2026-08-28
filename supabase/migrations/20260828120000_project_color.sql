-- Lets an owner pick a custom color for a project (shown on the calendar's
-- Gantt-style project bars). Nullable — when not set, the app falls back to
-- an automatic color derived from the project's id, same as before this
-- column existed.

alter table public.projects add column color text;
