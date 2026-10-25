-- Lets a boss set a profile photo for people in their own company (when adding
-- someone, or later from the person's page). Until now only a person could
-- write into their own avatars/<their id>/ folder.
--
-- Safe to run more than once.

drop policy if exists avatars_boss_insert on storage.objects;
create policy avatars_boss_insert on storage.objects
  for insert
  with check (
    bucket_id = 'avatars'
    and is_owner()
    and (storage.foldername(name))[1] in (
      select id::text from public.profiles where company_id = my_company_id()
    )
  );

drop policy if exists avatars_boss_update on storage.objects;
create policy avatars_boss_update on storage.objects
  for update
  using (
    bucket_id = 'avatars'
    and is_owner()
    and (storage.foldername(name))[1] in (
      select id::text from public.profiles where company_id = my_company_id()
    )
  );

drop policy if exists avatars_boss_select on storage.objects;
create policy avatars_boss_select on storage.objects
  for select
  using (
    bucket_id = 'avatars'
    and is_owner()
    and (storage.foldername(name))[1] in (
      select id::text from public.profiles where company_id = my_company_id()
    )
  );
