-- FIXED. Tenant comes only from the memberships table, which users cannot write.
drop policy if exists inv_select on public.invoices;
drop policy if exists inv_update on public.invoices;
drop policy if exists inv_delete on public.invoices;
drop policy if exists inv_insert on public.invoices;
drop policy if exists mem_insert on public.memberships;
create schema if not exists private;
grant usage on schema private to authenticated;
-- security definer so the lookup is not itself blocked by memberships RLS;
-- empty search_path so it cannot be hijacked.
create or replace function private.user_tenant_ids() returns setof uuid
  language sql stable security definer set search_path = '' as $$
  select m.tenant_id from public.memberships m where m.user_id = auth.uid()
$$;
revoke execute on function private.user_tenant_ids() from public;
grant execute on function private.user_tenant_ids() to authenticated;
alter table public.invoices enable row level security;
create policy inv_select on public.invoices for select to authenticated
  using (tenant_id in (select private.user_tenant_ids()));
create policy inv_insert on public.invoices for insert to authenticated
  with check (tenant_id in (select private.user_tenant_ids()));
create policy inv_update on public.invoices for update to authenticated
  using (tenant_id in (select private.user_tenant_ids()))
  with check (tenant_id in (select private.user_tenant_ids()));
create policy inv_delete on public.invoices for delete to authenticated
  using (tenant_id in (select private.user_tenant_ids()));
-- memberships: read your own rows only; no insert, update or delete policies.
alter table public.attachments enable row level security;
create policy att_select on public.attachments for select to authenticated
  using (tenant_id in (select private.user_tenant_ids()));
