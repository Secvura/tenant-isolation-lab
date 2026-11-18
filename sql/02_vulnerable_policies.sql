-- DELIBERATELY VULNERABLE. Three common tenant isolation mistakes.
alter table public.invoices enable row level security;
alter table public.memberships enable row level security;
-- Flaw 1: tenant taken from user_metadata, which the signed-in user can edit
-- themselves (supabase.auth.updateUser({ data: { tenant_id } })).
create policy inv_select on public.invoices for select to authenticated
  using (tenant_id = (auth.jwt() -> 'user_metadata' ->> 'tenant_id')::uuid);
create policy inv_update on public.invoices for update to authenticated
  using (tenant_id = (auth.jwt() -> 'user_metadata' ->> 'tenant_id')::uuid);
create policy inv_delete on public.invoices for delete to authenticated
  using (tenant_id = (auth.jwt() -> 'user_metadata' ->> 'tenant_id')::uuid);
-- Flaw 2: any signed-in user may insert a row for any tenant.
create policy inv_insert on public.invoices for insert to authenticated
  with check (auth.uid() is not null);
-- Flaw 3: a 'join team' policy that lets users add themselves to any tenant.
create policy mem_select on public.memberships for select to authenticated
  using (user_id = auth.uid());
create policy mem_insert on public.memberships for insert to authenticated
  with check (user_id = auth.uid());
-- Flaw 4: row level security never enabled on attachments.
