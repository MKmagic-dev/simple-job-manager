-- Lets an owner remove an employee from their team. Previously there was
-- no DELETE policy on profiles at all for owners (only admin_all covered
-- delete), so this action would have failed with an RLS error.
--
-- Deliberately scoped to role = 'employee' only — removing a co-boss (or
-- yourself) isn't something this "remove from team" action should do;
-- that's the separate demote-then-remove flow.
--
-- Note: this only removes the profile row. The underlying auth.users login
-- stays behind (same documented limitation as the admin panel's company
-- deletion — deleting an auth user requires the service-role key, which
-- the app never has).

create policy profiles_owner_delete_employee on public.profiles
  for delete
  using (
    is_owner()
    and company_id = my_company_id()
    and role = 'employee'
  );
