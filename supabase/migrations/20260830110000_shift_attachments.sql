-- Lets PDF/JPG/PNG files be attached to a shift — either by the owner when
-- creating/editing it (e.g. a reference drawing for the job), or by the
-- assigned employee from the shift's own detail view (e.g. proof of
-- finished work). Both directions land in the same table/bucket; only who
-- uploaded (uploaded_by) differs.

create table public.shift_attachments (
  id           uuid primary key default gen_random_uuid(),
  shift_id     uuid not null references public.shifts(id) on delete cascade,
  storage_path text not null,
  uploaded_by  uuid references public.profiles(id),
  created_at   timestamptz not null default now()
);

create index idx_shift_attachments_shift on public.shift_attachments (shift_id);

alter table public.shift_attachments enable row level security;

create policy shift_attachments_owner_all on public.shift_attachments
  for all
  using (
    is_owner()
    and shift_id in (select id from public.shifts where company_id = my_company_id())
  );

-- An employee can attach a file to their own shift...
create policy shift_attachments_employee_insert on public.shift_attachments
  for insert
  with check (
    uploaded_by = auth.uid()
    and shift_id in (select id from public.shifts where employee_id = auth.uid())
  );

-- ...and see every attachment on it (their own uploads plus the owner's).
create policy shift_attachments_employee_select on public.shift_attachments
  for select
  using (shift_id in (select id from public.shifts where employee_id = auth.uid()));

create policy shift_attachments_admin_all on public.shift_attachments
  for all
  using (is_admin());

-- Storage bucket for the actual files.
-- File path convention: <company id>/<shift id>/<filename>
insert into storage.buckets (id, name, public)
values ('shift-attachments', 'shift-attachments', false)
on conflict (id) do nothing;

create policy shift_attachments_owner_all_storage on storage.objects
  for all
  using (
    bucket_id = 'shift-attachments'
    and is_owner()
    and (storage.foldername(name))[1] = my_company_id()::text
  )
  with check (
    bucket_id = 'shift-attachments'
    and is_owner()
    and (storage.foldername(name))[1] = my_company_id()::text
  );

create policy shift_attachments_employee_insert_storage on storage.objects
  for insert
  with check (
    bucket_id = 'shift-attachments'
    and (storage.foldername(name))[1] = my_company_id()::text
    and (storage.foldername(name))[2] in (
      select id::text from public.shifts where employee_id = auth.uid()
    )
  );

create policy shift_attachments_employee_select_storage on storage.objects
  for select
  using (
    bucket_id = 'shift-attachments'
    and (storage.foldername(name))[2] in (
      select id::text from public.shifts where employee_id = auth.uid()
    )
  );

create policy shift_attachments_admin_all_storage on storage.objects
  for all
  using (bucket_id = 'shift-attachments' and is_admin());
