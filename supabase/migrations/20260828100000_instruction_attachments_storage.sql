-- Storage bucket + access rules for instruction attachments (PDF/JPG/PNG
-- files an owner attaches to an instruction, e.g. a plan drawing or a
-- reference photo).
--
-- The `instruction_photos` table (see 20260713120000_initial_schema.sql)
-- already stores each attachment's metadata (which instruction, who
-- uploaded it) and has RLS policies scoping it correctly through
-- instructions.company_id / instructions.employee_id. This migration adds
-- the other half: a private Storage bucket for the actual files, plus
-- RLS policies on `storage.objects`.
--
-- File path convention: every uploaded file lives at
--   instruction-attachments/<company id>/<instruction id>/<filename>
-- The owner-facing policy checks the company-id folder segment directly
-- (cheap, and safe since only owners can write). The employee-facing
-- policy instead joins back through instruction_photos/instructions —
-- trusting the folder path alone isn't enough there, since two employees
-- in the same company must not be able to read each other's attachments.

insert into storage.buckets (id, name, public)
values ('instruction-attachments', 'instruction-attachments', false)
on conflict (id) do nothing;

create policy instruction_attachments_owner_all on storage.objects
  for all
  using (
    bucket_id = 'instruction-attachments'
    and is_owner()
    and (storage.foldername(name))[1] = my_company_id()::text
  )
  with check (
    bucket_id = 'instruction-attachments'
    and is_owner()
    and (storage.foldername(name))[1] = my_company_id()::text
  );

create policy instruction_attachments_employee_select on storage.objects
  for select
  using (
    bucket_id = 'instruction-attachments'
    and exists (
      select 1
      from public.instruction_photos ip
      join public.instructions i on i.id = ip.instruction_id
      where ip.storage_path = storage.objects.name
        and i.employee_id = auth.uid()
    )
  );

create policy instruction_attachments_admin_all on storage.objects
  for all
  using (bucket_id = 'instruction-attachments' and is_admin());
