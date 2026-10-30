-- Only an administrator edits people's details.
--
-- Before: any signed-in person could update their OWN profile row (name,
-- phone, photo). Now employees can't change their details at all — their
-- administrator does, from the person's page — while owners can edit anyone in
-- their company (themselves included) and a super admin anyone.
--
-- Passwords are not affected: changing your own password goes through the auth
-- service, not the profiles table.
--
-- Safe to run more than once.

drop policy if exists profiles_update_owner_or_self on public.profiles;
drop policy if exists profiles_update_owner on public.profiles;
create policy profiles_update_owner on public.profiles
  for update
  using (is_owner() and company_id = my_company_id())
  with check (is_owner() and company_id = my_company_id());

-- Profile photos live in the public 'avatars' bucket. People could write into
-- their own folder; now only an owner can (the avatars_boss_* policies already
-- cover every person in the owner's company, owner included).
drop policy if exists avatars_owner_insert on storage.objects;
drop policy if exists avatars_owner_update on storage.objects;
drop policy if exists avatars_owner_delete on storage.objects;

drop policy if exists avatars_boss_delete on storage.objects;
create policy avatars_boss_delete on storage.objects
  for delete
  using (
    bucket_id = 'avatars'
    and is_owner()
    and (storage.foldername(name))[1] in (
      select id::text from public.profiles where company_id = my_company_id()
    )
  );
