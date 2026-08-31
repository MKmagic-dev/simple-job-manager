-- Lets an owner attach PDF/JPG/PNG files to a project (site photos, plans,
-- etc.), shown in the project's detail screen gallery. Mirrors the
-- instruction_photos + instruction-attachments pattern exactly.

create table public.project_attachments (
  id           uuid primary key default gen_random_uuid(),
  project_id   uuid not null references public.projects(id) on delete cascade,
  storage_path text not null,
  uploaded_by  uuid references public.profiles(id),
  created_at   timestamptz not null default now()
);

create index idx_project_attachments_project on public.project_attachments (project_id);

alter table public.project_attachments enable row level security;

create policy project_attachments_owner_all on public.project_attachments
  for all
  using (
    is_owner()
    and project_id in (select id from public.projects where company_id = my_company_id())
  );

create policy project_attachments_admin_all on public.project_attachments
  for all
  using (is_admin());

-- Storage bucket for the actual files.
-- File path convention: instruction-attachments/<company id>/<project id>/<filename>
insert into storage.buckets (id, name, public)
values ('project-attachments', 'project-attachments', false)
on conflict (id) do nothing;

create policy project_attachments_owner_all_storage on storage.objects
  for all
  using (
    bucket_id = 'project-attachments'
    and is_owner()
    and (storage.foldername(name))[1] = my_company_id()::text
  )
  with check (
    bucket_id = 'project-attachments'
    and is_owner()
    and (storage.foldername(name))[1] = my_company_id()::text
  );

-- Note: the owner policy above is FOR ALL (not just INSERT), so it already
-- covers SELECT too — unlike the avatars bucket fix in
-- 20260829090000_avatars_select_policy.sql, no separate SELECT policy is
-- needed here for upsert uploads to work.
create policy project_attachments_admin_all_storage on storage.objects
  for all
  using (bucket_id = 'project-attachments' and is_admin());
