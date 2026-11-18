-- Two-account test. Each check runs as a real API role with real JWT claims,
-- in its own subtransaction that is always rolled back, so checks never
-- affect each other. 'blocked' passes when 0 rows are affected or Postgres
-- refuses the statement; 'allowed' passes when at least 1 row is affected.
create schema if not exists lab;
create or replace function lab.try(p_role text, p_claims jsonb, p_sql text)
returns int language plpgsql as $$
declare n int;
begin
  begin
    perform set_config('request.jwt.claims', coalesce(p_claims::text, ''), true);
    execute format('set local role %I', p_role);
    execute p_sql into n;
    raise exception using errcode = 'LAB01', message = n::text;  -- force rollback
  exception
    when sqlstate 'LAB01' then n := sqlerrm::int;
    when insufficient_privilege then n := -1;                     -- refused (42501)
  end;
  return n;
end $$;
create temp table checks (id text, actor text, expect text, role text, claims jsonb, sql text);
insert into checks values
 ('T1','bob reads his own invoices','allowed','authenticated',
  '{"sub":"b0b00000-0000-0000-0000-000000000002","role":"authenticated","user_metadata":{"tenant_id":"bbbbbbbb-0000-0000-0000-000000000002"}}',
  'select count(*) from public.invoices'),
 ('T2','bob edits his user_metadata to tenant A, then reads A''s invoices','blocked','authenticated',
  '{"sub":"b0b00000-0000-0000-0000-000000000002","role":"authenticated","user_metadata":{"tenant_id":"aaaaaaaa-0000-0000-0000-000000000001"}}',
  'select count(*) from public.invoices where tenant_id = ''aaaaaaaa-0000-0000-0000-000000000001'''),
 ('T3','bob changes an invoice belonging to A','blocked','authenticated',
  '{"sub":"b0b00000-0000-0000-0000-000000000002","role":"authenticated","user_metadata":{"tenant_id":"aaaaaaaa-0000-0000-0000-000000000001"}}',
  'with x as (update public.invoices set amount_pence = 1 where tenant_id = ''aaaaaaaa-0000-0000-0000-000000000001'' returning 1) select count(*) from x'),
 ('T4','bob deletes an invoice belonging to A','blocked','authenticated',
  '{"sub":"b0b00000-0000-0000-0000-000000000002","role":"authenticated","user_metadata":{"tenant_id":"aaaaaaaa-0000-0000-0000-000000000001"}}',
  'with x as (delete from public.invoices where tenant_id = ''aaaaaaaa-0000-0000-0000-000000000001'' returning 1) select count(*) from x'),
 ('T5','bob creates an invoice for his own tenant B','allowed','authenticated',
  '{"sub":"b0b00000-0000-0000-0000-000000000002","role":"authenticated"}',
  'with x as (insert into public.invoices (tenant_id, amount_pence) values (''bbbbbbbb-0000-0000-0000-000000000002'', 100) returning 1) select count(*) from x'),
 ('T6','bob creates an invoice inside tenant A','blocked','authenticated',
  '{"sub":"b0b00000-0000-0000-0000-000000000002","role":"authenticated"}',
  'with x as (insert into public.invoices (tenant_id, amount_pence) values (''aaaaaaaa-0000-0000-0000-000000000001'', 100) returning 1) select count(*) from x'),
 ('T7','bob adds himself as a member of tenant A','blocked','authenticated',
  '{"sub":"b0b00000-0000-0000-0000-000000000002","role":"authenticated"}',
  'with x as (insert into public.memberships values (''b0b00000-0000-0000-0000-000000000002'', ''aaaaaaaa-0000-0000-0000-000000000001'') returning 1) select count(*) from x'),
 ('T8','bob reads A''s attachments','blocked','authenticated',
  '{"sub":"b0b00000-0000-0000-0000-000000000002","role":"authenticated"}',
  'select count(*) from public.attachments where tenant_id = ''aaaaaaaa-0000-0000-0000-000000000001'''),
 ('T9','alice reads her own attachments','allowed','authenticated',
  '{"sub":"a11ce000-0000-0000-0000-000000000001","role":"authenticated"}',
  'select count(*) from public.attachments'),
 ('T10','a visitor who is not signed in reads any attachments','blocked','anon', null,
  'select count(*) from public.attachments'),
 ('T11','a visitor who is not signed in reads any invoices','blocked','anon', null,
  'select count(*) from public.invoices');
select id, expect, n as rows,
       case when (expect = 'blocked' and n <= 0) or (expect = 'allowed' and n > 0)
            then 'PASS' else 'FAIL' end as result, actor
from (select c.*, lab.try(c.role, c.claims, c.sql) as n from checks c) t
order by length(id), id;
