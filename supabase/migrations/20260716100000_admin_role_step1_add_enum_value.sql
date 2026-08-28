-- Step 1 of 2 for the shared multi-tenant + admin role migration.
--
-- Must run in its OWN SQL Editor execution, separate from step 2 — Postgres
-- doesn't allow a new enum value to be used in the same transaction that
-- adds it. Adding an admin role is what makes the "one Admin account can
-- manage every company" requirement possible.

alter type public.user_role add value 'admin';
