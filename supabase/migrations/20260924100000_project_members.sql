-- Project membership ("who is on this project").
--
-- The boss puts people on a project first (project_members); only then can
-- they be given shifts / tasks on it, and the shift and task pickers only
-- offer the project's own people (so with 100 employees nobody scrolls a
-- 100-name list). Being a member is also what lets an employee see the
-- project, its files and its tasks — replacing the old rule "you can see a
-- project once you have a shift on it".
--
-- Safe to run more than once.

create table if not exists public.project_members (
  project_id  uuid not null references public.projects(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (project_id, employee_id)
);

create index if not exists idx_project_members_employee on public.project_members (employee_id);
create index if not exists idx_project_members_company on public.project_members (company_id);

alter table public.project_members enable row level security;

drop policy if exists project_members_owner_all on public.project_members;
create policy project_members_owner_all on public.project_members
  for all
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

drop policy if exists project_members_admin_all on public.project_members;
create policy project_members_admin_all on public.project_members
  for all
  using (is_admin());

drop policy if exists project_members_employee_select on public.project_members;
create policy project_members_employee_select on public.project_members
  for select
  using (employee_id = auth.uid());

-- Everyone who already has a shift on a project becomes a member of it, so
-- nothing disappears for existing data.
insert into public.project_members (project_id, employee_id, company_id)
select distinct s.project_id, s.employee_id, s.company_id
from public.shifts s
where s.project_id is not null
on conflict do nothing;

-- Employees see a project (and what belongs to it) when they're a member ----

drop policy if exists projects_employee_select on public.projects;
create policy projects_employee_select on public.projects
  for select
  using (
    company_id = my_company_id()
    and archived_at is null
    and id in (select project_id from public.project_members where employee_id = auth.uid())
  );

drop policy if exists shifts_employee_select_own on public.shifts;
create policy shifts_employee_select_own on public.shifts
  for select
  using (
    employee_id = auth.uid()
    and (
      project_id is null
      or (
        not public.project_is_archived(project_id)
        and project_id in (select project_id from public.project_members where employee_id = auth.uid())
      )
    )
  );

drop policy if exists project_attachments_employee_insert on public.project_attachments;
create policy project_attachments_employee_insert on public.project_attachments
  for insert
  with check (
    uploaded_by = auth.uid()
    and project_id in (select project_id from public.project_members where employee_id = auth.uid())
  );

drop policy if exists project_attachments_employee_select on public.project_attachments;
create policy project_attachments_employee_select on public.project_attachments
  for select
  using (
    project_id in (select project_id from public.project_members where employee_id = auth.uid())
  );

drop policy if exists project_attachments_employee_insert_storage on storage.objects;
create policy project_attachments_employee_insert_storage on storage.objects
  for insert
  with check (
    bucket_id = 'project-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (storage.foldername(name))[2] in (
      select project_id::text from public.project_members where employee_id = auth.uid()
    )
  );

drop policy if exists project_attachments_employee_select_storage on storage.objects;
create policy project_attachments_employee_select_storage on storage.objects
  for select
  using (
    bucket_id = 'project-attachments'
    and (storage.foldername(name))[2] in (
      select project_id::text from public.project_members where employee_id = auth.uid()
    )
  );

drop policy if exists project_completion_notices_employee_insert on public.project_completion_notices;
create policy project_completion_notices_employee_insert on public.project_completion_notices
  for insert
  with check (
    employee_id = auth.uid()
    and project_id in (select project_id from public.project_members where employee_id = auth.uid())
  );
