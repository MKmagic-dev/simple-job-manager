-- Fixes avatar upload failing with "new row violates row-level security
-- policy" specifically when the client uploads with upsert=true (which the
-- app always does, so re-uploading a photo just replaces the old one).
--
-- Root cause: Supabase Storage's upsert path does an internal existence
-- check on the object before deciding to insert vs. update, and that check
-- requires a SELECT policy — the original avatars migration skipped one,
-- reasoning that downloads go through the public URL route and bypass RLS
-- (still true), but that doesn't cover this internal check on the write
-- path. Confirmed by direct API testing: uploads succeed without
-- x-upsert, and the identical pattern already works for work-photos,
-- which does have a matching SELECT policy.

create policy avatars_owner_select on storage.objects
  for select
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
