-- Run this once in Supabase Dashboard -> SQL Editor, then paste the full
-- result back. It returns everything needed to write migration files by
-- hand: columns, constraints (PK/FK/UNIQUE/CHECK), indexes, RLS on/off
-- status, RLS policies, custom enum types, and triggers/functions
-- (including anything Supabase set up on auth.users, e.g. an
-- auto-create-profile trigger).
with columns as (
  select
    'COLUMN' as section,
    c.table_name,
    c.column_name as name,
    c.data_type || coalesce('(' || c.character_maximum_length || ')', '') as extra_1,
    'nullable=' || c.is_nullable || ', default=' || coalesce(c.column_default, '') as extra_2
  from information_schema.columns c
  where c.table_schema = 'public'
),
constraints as (
  select
    'CONSTRAINT' as section,
    con.conrelid::regclass::text as table_name,
    con.conname as name,
    case con.contype
      when 'p' then 'PRIMARY KEY'
      when 'f' then 'FOREIGN KEY'
      when 'u' then 'UNIQUE'
      when 'c' then 'CHECK'
      else con.contype::text
    end as extra_1,
    pg_get_constraintdef(con.oid) as extra_2
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
),
indexes as (
  select
    'INDEX' as section,
    tablename as table_name,
    indexname as name,
    '' as extra_1,
    indexdef as extra_2
  from pg_indexes
  where schemaname = 'public'
),
rls_status as (
  select
    'RLS_STATUS' as section,
    c.relname as table_name,
    'rls_enabled' as name,
    c.relrowsecurity::text as extra_1,
    c.relforcerowsecurity::text as extra_2
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
),
policies as (
  select
    'POLICY' as section,
    tablename as table_name,
    policyname as name,
    cmd || ' / roles=' || array_to_string(roles, ',') as extra_1,
    'USING: ' || coalesce(qual, '') || ' | WITH CHECK: ' || coalesce(with_check, '') as extra_2
  from pg_policies
  where schemaname = 'public'
),
enums as (
  select
    'ENUM' as section,
    t.typname as table_name,
    e.enumlabel as name,
    e.enumsortorder::text as extra_1,
    '' as extra_2
  from pg_type t
  join pg_enum e on t.oid = e.enumtypid
  join pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'public'
),
triggers as (
  select
    'TRIGGER' as section,
    event_object_table as table_name,
    trigger_name as name,
    action_timing || ' ' || event_manipulation as extra_1,
    action_statement as extra_2
  from information_schema.triggers
  where trigger_schema in ('public', 'auth')
),
functions as (
  select
    'FUNCTION' as section,
    n.nspname as table_name,
    p.proname as name,
    '' as extra_1,
    pg_get_functiondef(p.oid) as extra_2
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
)
select * from columns
union all select * from constraints
union all select * from indexes
union all select * from rls_status
union all select * from policies
union all select * from enums
union all select * from triggers
union all select * from functions
order by section, table_name, name;
