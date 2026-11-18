-- Fictional two-customer app. Tenant A = Acme, tenant B = Birch.
create table public.tenants (id uuid primary key, name text not null);
create table public.memberships (
  user_id uuid not null, tenant_id uuid not null references public.tenants(id),
  primary key (user_id, tenant_id));
create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  amount_pence int not null, note text);
create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  file_name text not null);
insert into public.tenants values
  ('aaaaaaaa-0000-0000-0000-000000000001','Acme (tenant A)'),
  ('bbbbbbbb-0000-0000-0000-000000000002','Birch (tenant B)');
-- alice belongs to A, bob belongs to B
insert into public.memberships values
  ('a11ce000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001'),
  ('b0b00000-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000002');
insert into public.invoices (tenant_id, amount_pence, note) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 120000, 'Acme invoice 1'),
  ('aaaaaaaa-0000-0000-0000-000000000001',  45000, 'Acme invoice 2'),
  ('bbbbbbbb-0000-0000-0000-000000000002',  99000, 'Birch invoice 1');
insert into public.attachments (tenant_id, file_name) values
  ('aaaaaaaa-0000-0000-0000-000000000001','acme-contract.pdf'),
  ('bbbbbbbb-0000-0000-0000-000000000002','birch-contract.pdf');
