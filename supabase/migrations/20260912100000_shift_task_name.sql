-- Lets an owner label a group of shifts as one "task" (e.g. "wylewanie
-- fundamentów") when creating several shifts at once for a date range and
-- multiple employees. Purely a display label — each employee/day still gets
-- its own shifts row, grouped only by sharing this same text.
alter table public.shifts add column task_name text;
