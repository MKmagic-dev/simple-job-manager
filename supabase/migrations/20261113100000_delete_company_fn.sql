-- Deletes a whole company and everything in it, in one transaction. Called only
-- by the server function `delete-company` (service role), after it checked that
-- the caller is that company's owner and confirmed their e-mail code.
--
-- The rows that point at people through NON-cascading foreign keys are removed
-- first; then the company row goes, and its cascade removes the rest, including
-- the profiles. The matching logins and storage files are removed by the function.
--
-- Safe to run more than once.

create or replace function public.delete_company_data(p_company uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.instruction_photos
    where uploaded_by in (select id from public.profiles where company_id = p_company);
  delete from public.project_attachments
    where uploaded_by in (select id from public.profiles where company_id = p_company);
  delete from public.shift_attachments
    where uploaded_by in (select id from public.profiles where company_id = p_company);
  delete from public.task_attachments
    where uploaded_by in (select id from public.profiles where company_id = p_company);
  delete from public.project_completion_notices
    where employee_id in (select id from public.profiles where company_id = p_company);
  delete from public.task_completion_notices
    where employee_id in (select id from public.profiles where company_id = p_company);

  delete from public.companies where id = p_company;
end;
$$;

revoke all on function public.delete_company_data(uuid) from public;
grant execute on function public.delete_company_data(uuid) to service_role;
