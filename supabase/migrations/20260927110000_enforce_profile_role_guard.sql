-- SECURITY: make sure nobody can change their own (or anyone's) role or company
-- unless they are an owner or an admin.
--
-- The guard trigger was defined in earlier migrations, but a live test showed
-- an ordinary employee could still `update profiles set role = 'owner'` on
-- their own row through the API — i.e. the trigger was missing or disabled in
-- that database. This re-creates the function, re-creates the trigger and makes
-- sure it is enabled. Safe to run more than once.

create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (public.is_owner() or public.is_admin()) then
    if new.role is distinct from old.role
       or new.company_id is distinct from old.company_id then
      raise exception 'Only an owner or an admin can change role or company_id';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_profile_privilege_escalation on public.profiles;
create trigger trg_prevent_profile_privilege_escalation
  before update on public.profiles
  for each row
  execute function public.prevent_profile_privilege_escalation();

alter table public.profiles enable trigger trg_prevent_profile_privilege_escalation;
