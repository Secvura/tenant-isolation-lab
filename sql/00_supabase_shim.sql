-- Minimal local stand-in for the parts of Supabase this lab needs.
-- auth.uid() and auth.jwt() follow Supabase's own definitions: they read the
-- JWT claims that PostgREST puts in the request.jwt.claims setting.
create extension if not exists pgcrypto;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin noinherit; end if;
end $$;
create schema if not exists auth;
grant usage on schema auth to anon, authenticated;
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')
  )::jsonb
$$;
-- Supabase grants table privileges in the public schema to anon and
-- authenticated by default, so row level security is the only barrier.
grant usage on schema public to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
