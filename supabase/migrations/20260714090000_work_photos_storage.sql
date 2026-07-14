-- Storage bucket + access rules for worker-uploaded work photos.
--
-- The `work_photos` table (see 20260713120000_initial_schema.sql) already
-- stores each photo's metadata (who took it, which company, which shift,
-- a caption) and has its own RLS policies. This migration adds the other
-- half: a private Storage bucket to hold the actual image files, plus
-- separate RLS policies on `storage.objects` controlling who can
-- upload/download the files themselves.
--
-- File path convention: every uploaded file lives at
--   work-photos/<employee's user id>/<filename>
-- The policies below check that first path segment against auth.uid(), so
-- an employee can only ever write into (and read from) their own folder.

insert into storage.buckets (id, name, public)
values ('work-photos', 'work-photos', false)
on conflict (id) do nothing;

create policy work_photos_employee_insert on storage.objects
  for insert
  with check (
    bucket_id = 'work-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy work_photos_employee_select_storage on storage.objects
  for select
  using (
    bucket_id = 'work-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Owners can view any work photo file that belongs to their own company —
-- checked by joining back to the work_photos row for that exact path,
-- mirroring the same pattern used to fix the instruction_photos RLS bug.
create policy work_photos_owner_select_storage on storage.objects
  for select
  using (
    bucket_id = 'work-photos'
    and is_owner()
    and exists (
      select 1 from public.work_photos wp
      where wp.storage_path = storage.objects.name
        and wp.company_id = my_company_id()
    )
  );
