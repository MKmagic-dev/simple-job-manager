-- Removing an employee: their login is deleted, but their profile stays as an
-- empty row ("Konto usunięte", no personal data). That keeps their shifts,
-- tasks and attachments in the company without their name, so the profile
-- must be able to outlive its auth account.
--
-- Safe to run more than once.

alter table public.profiles
  drop constraint if exists profiles_id_fkey;

alter table public.profiles
  add column if not exists deleted_at timestamptz;
