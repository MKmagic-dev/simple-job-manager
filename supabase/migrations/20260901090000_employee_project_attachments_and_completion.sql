-- Two things:
--
-- 1. Lets an employee add PDF/JPG/PNG files to a project they're actually
--    assigned to (via a shift), and see every attachment on it — not just
--    their own uploads, so they can see the owner's reference files too.
--    Previously only the owner/admin could touch project_attachments at
--    all.
--
-- 2. A lightweight "I finished this" signal an employee can send on a
--    project. Deliberately NOT a status change on the project itself —
--    it's purely a notification for the owner (shown as a badge + "done
--    by <name>" note), who dismisses it once acknowledged. Same shape as
--    shift_change_requests.

-- --- project_attachments: employee access ----------------------------------

create policy project_attachments_employee_insert on public.project_attachments
  for insert
  with check (
    uploaded_by = auth.uid()
    and project_id in (select project_id from public.shifts where employee_id = auth.uid())
  );

create policy project_attachments_employee_select on public.project_attachments
  for select
  using (
    project_id in (select project_id from public.shifts where employee_id = auth.uid())
  );

create policy project_attachments_employee_insert_storage on storage.objects
  for insert
  with check (
    bucket_id = 'project-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (storage.foldername(name))[2] in (
      select project_id::text from public.shifts where employee_id = auth.uid()
    )
  );

create policy project_attachments_employee_select_storage on storage.objects
  for select
  using (
    bucket_id = 'project-attachments'
    and (storage.foldername(name))[2] in (
      select project_id::text from public.shifts where employee_id = auth.uid()
    )
  );

-- --- project_completion_notices ---------------------------------------------

create table public.project_completion_notices (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references public.projects(id) on delete cascade,
  employee_id uuid not null references public.profiles(id),
  created_at  timestamptz not null default now()
);

create index idx_project_completion_notices_project on public.project_completion_notices (project_id);

alter table public.project_completion_notices enable row level security;

create policy project_completion_notices_owner_all on public.project_completion_notices
  for all
  using (
    is_owner()
    and project_id in (select id from public.projects where company_id = my_company_id())
  );

create policy project_completion_notices_employee_insert on public.project_completion_notices
  for insert
  with check (
    employee_id = auth.uid()
    and project_id in (select project_id from public.shifts where employee_id = auth.uid())
  );

create policy project_completion_notices_employee_select on public.project_completion_notices
  for select
  using (employee_id = auth.uid());

create policy project_completion_notices_admin_all on public.project_completion_notices
  for all
  using (is_admin());
