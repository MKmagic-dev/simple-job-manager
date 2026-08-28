-- Storage bucket for profile photos ("Moje konto").
--
-- Unlike work-photos, this bucket is public: a profile picture isn't
-- sensitive the way a work photo or a company's business data is, and
-- making it public means the app can just use a plain URL to show someone's
-- avatar (in the team list, for example) instead of fetching a fresh signed
-- URL for every single face on screen.
--
-- File path convention: <user id>/<filename>, same as work-photos, so the
-- insert policy can check the caller only writes into their own folder.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy avatars_owner_insert on storage.objects
  for insert
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_owner_update on storage.objects
  for update
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_owner_delete on storage.objects
  for delete
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- No SELECT policy needed: the bucket is public, so reads go through the
-- public URL endpoint and bypass storage.objects RLS entirely.
