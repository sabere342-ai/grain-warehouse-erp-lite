create schema if not exists private;
revoke all on schema private from public, anon;

create or replace function private.canonical_jsonb_text(p_value jsonb)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case pg_catalog.jsonb_typeof(p_value)
    when 'object' then
      '{' || coalesce((
        select pg_catalog.string_agg(
          pg_catalog.to_jsonb(entry.key)::text || ':' ||
          private.canonical_jsonb_text(entry.value),
          ',' order by entry.key
        )
        from pg_catalog.jsonb_each(p_value) entry
      ), '') || '}'
    when 'array' then
      '[' || coalesce((
        select pg_catalog.string_agg(
          private.canonical_jsonb_text(entry.value),
          ',' order by entry.ordinality
        )
        from pg_catalog.jsonb_array_elements(p_value)
          with ordinality entry(value, ordinality)
      ), '') || ']'
    else p_value::text
  end
$$;

revoke all on function private.canonical_jsonb_text(jsonb)
from public, anon, authenticated;

create table public.products (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete restrict,
  legacy_local_id text,
  name text not null,
  normalized_name text not null,
  code text,
  normalized_code text,
  unit text not null check (unit in ('kilogram', 'ton')),
  is_active boolean not null,
  default_sale_price_piasters_per_kg bigint,
  minimum_sale_price_piasters_per_kg bigint,
  reference_cost_price_piasters_per_kg bigint,
  notes text,
  entity_version bigint not null check (entity_version > 0),
  created_at_utc timestamptz not null,
  server_modified_at_utc timestamptz not null,
  actor_auth_user_id uuid not null references auth.users(id) on delete restrict,
  device_id uuid not null,
  source_operation_id uuid not null,
  is_deleted boolean not null default false,
  deletion_version bigint,
  deleted_at_utc timestamptz,
  deleted_by_auth_user_id uuid references auth.users(id) on delete restrict,
  deleted_by_device_id uuid,
  deletion_source_operation_id uuid,
  unique (business_id, id),
  unique (business_id, normalized_name),
  check (default_sale_price_piasters_per_kg is null or
         default_sale_price_piasters_per_kg > 0),
  check (minimum_sale_price_piasters_per_kg is null or
         minimum_sale_price_piasters_per_kg > 0),
  check (reference_cost_price_piasters_per_kg is null or
         reference_cost_price_piasters_per_kg > 0),
  check (default_sale_price_piasters_per_kg is null or
         minimum_sale_price_piasters_per_kg is null or
         minimum_sale_price_piasters_per_kg <=
           default_sale_price_piasters_per_kg),
  check (
    (not is_deleted and deletion_version is null and deleted_at_utc is null
      and deleted_by_auth_user_id is null and deleted_by_device_id is null
      and deletion_source_operation_id is null)
    or
    (is_deleted and deletion_version = entity_version
      and deleted_at_utc is not null
      and deleted_by_auth_user_id is not null
      and deleted_by_device_id is not null
      and deletion_source_operation_id is not null)
  )
);

create unique index products_business_normalized_code_uq
  on public.products (business_id, normalized_code)
  where normalized_code is not null;

create table private.product_catalog_operation_receipts (
  operation_id uuid primary key,
  idempotency_key uuid not null unique,
  business_id uuid not null references public.businesses(id) on delete restrict,
  actor_auth_user_id uuid not null references auth.users(id) on delete restrict,
  payload_fingerprint text not null check (
    payload_fingerprint ~ '^[0-9a-f]{64}$'
  ),
  status text not null check (status in ('pending', 'completed')),
  canonical_result_json jsonb,
  created_at_utc timestamptz not null,
  completed_at_utc timestamptz,
  check (
    (status = 'pending' and canonical_result_json is null
      and completed_at_utc is null)
    or
    (status = 'completed' and canonical_result_json is not null
      and completed_at_utc is not null)
  )
);

create table public.product_catalog_changes (
  change_cursor bigint generated always as identity primary key,
  business_id uuid not null references public.businesses(id) on delete restrict,
  product_id uuid not null,
  entity_version bigint not null check (entity_version > 0),
  operation_kind text not null check (operation_kind in (
    'product.create.v1', 'product.update.v1', 'product.setActive.v1'
  )),
  payload jsonb not null,
  payload_fingerprint text not null check (
    payload_fingerprint ~ '^[0-9a-f]{64}$'
  ),
  source_operation_id uuid not null,
  actor_auth_user_id uuid not null references auth.users(id) on delete restrict,
  device_id uuid not null,
  server_modified_at_utc timestamptz not null,
  is_deleted boolean not null default false,
  deletion_metadata jsonb,
  unique (business_id, source_operation_id),
  foreign key (business_id, product_id)
    references public.products(business_id, id) on delete restrict,
  check (
    (not is_deleted and deletion_metadata is null)
    or (is_deleted and deletion_metadata is not null)
  )
);

create index product_catalog_changes_business_cursor_idx
  on public.product_catalog_changes (business_id, change_cursor);
create index product_catalog_changes_business_product_version_idx
  on public.product_catalog_changes
  (business_id, product_id, entity_version);

alter table public.products enable row level security;
alter table public.product_catalog_changes enable row level security;

create policy products_active_member_read on public.products
for select to authenticated
using (
  (select auth.uid()) is not null
  and exists (
    select 1 from public.business_memberships membership
    where membership.business_id = products.business_id
      and membership.auth_user_id = (select auth.uid())
      and membership.is_active
      and membership.role in ('owner', 'employee', 'viewer')
  )
);

create policy product_catalog_changes_active_member_read
on public.product_catalog_changes
for select to authenticated
using (
  (select auth.uid()) is not null
  and exists (
    select 1 from public.business_memberships membership
    where membership.business_id = product_catalog_changes.business_id
      and membership.auth_user_id = (select auth.uid())
      and membership.is_active
      and membership.role in ('owner', 'employee', 'viewer')
  )
);

revoke all on table public.products from public, anon, authenticated;
revoke all on table public.product_catalog_changes
from public, anon, authenticated;
revoke all on sequence public.product_catalog_changes_change_cursor_seq
from public, anon, authenticated;
revoke all on table private.product_catalog_operation_receipts
from public, anon, authenticated;
grant select on table public.products to authenticated;
grant select on table public.product_catalog_changes to authenticated;

create or replace function private.product_catalog_result(
  p_change public.product_catalog_changes,
  p_replayed boolean
) returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'ok', true,
    'payload', p_change.payload,
    'entityVersion', p_change.entity_version,
    'sourceOperationId', p_change.source_operation_id::text,
    'actorAuthUserId', p_change.actor_auth_user_id::text,
    'deviceId', p_change.device_id::text,
    'serverModifiedAtUtc',
      pg_catalog.to_char(
        p_change.server_modified_at_utc at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
      ),
    'changeCursor', p_change.change_cursor,
    'deletion', p_change.deletion_metadata,
    'replayed', p_replayed
  )
$$;

revoke all on function private.product_catalog_result(
  public.product_catalog_changes, boolean
) from public, anon, authenticated;
grant execute on function private.product_catalog_result(
  public.product_catalog_changes, boolean
) to authenticated;

create or replace function private.apply_product_catalog_operation_v1(
  p_business_id text,
  p_operation_id text,
  p_idempotency_key text,
  p_device_id text,
  p_operation_kind text,
  p_base_entity_version bigint,
  p_payload jsonb,
  p_payload_fingerprint text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_business_id uuid;
  v_operation_id uuid;
  v_device_id uuid;
  v_product_id uuid;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_fingerprint text;
  v_inserted integer;
  v_receipt private.product_catalog_operation_receipts%rowtype;
  v_product public.products%rowtype;
  v_change public.product_catalog_changes%rowtype;
  v_result jsonb;
  v_name text := nullif(pg_catalog.btrim(p_payload->>'name'), '');
  v_code text := nullif(pg_catalog.btrim(p_payload->>'code'), '');
 v_notes text := nullif(pg_catalog.btrim(p_payload->>'notes'), '');
  v_is_active boolean;
  v_default_price bigint;
  v_minimum_price bigint;
  v_reference_cost bigint;
begin
  if v_actor is null then
    return pg_catalog.jsonb_build_object(
      'ok', false, 'outcome', 'permanentFailure',
      'code', 'unauthenticated.sessionRequired'
    );
  end if;
  begin
    v_business_id := p_business_id::uuid;
    v_operation_id := p_operation_id::uuid;
    v_device_id := p_device_id::uuid;
   v_product_id := (p_payload->>'remoteProductId')::uuid;
    v_is_active := (p_payload->>'isActive')::boolean;
    v_default_price :=
      (p_payload->>'defaultSalePricePiastersPerKg')::bigint;
    v_minimum_price :=
      (p_payload->>'minimumSalePricePiastersPerKg')::bigint;
    v_reference_cost :=
      (p_payload->>'referenceCostPricePiastersPerKg')::bigint;
  exception when others then
    return pg_catalog.jsonb_build_object(
      'ok', false, 'outcome', 'permanentFailure',
      'code', 'validation.invalidField'
    );
  end;
  if p_operation_id <> p_idempotency_key
     or p_payload is null
     or pg_catalog.jsonb_typeof(p_payload) <> 'object'
    or p_payload->>'schemaVersion' <> '1'
     or not (p_payload ?& array[
       'schemaVersion', 'mutationKind', 'remoteProductId',
       'legacyLocalId', 'name', 'code', 'unit', 'isActive',
       'defaultSalePricePiastersPerKg',
       'minimumSalePricePiastersPerKg',
       'referenceCostPricePiastersPerKg', 'notes'
     ])
     or (p_payload - array[
       'schemaVersion', 'mutationKind', 'remoteProductId',
       'legacyLocalId', 'name', 'code', 'unit', 'isActive',
       'defaultSalePricePiastersPerKg',
       'minimumSalePricePiastersPerKg',
       'referenceCostPricePiastersPerKg', 'notes'
     ]) <> '{}'::jsonb
    or p_payload->>'mutationKind' <> p_operation_kind
     or p_operation_kind not in (
       'product.create.v1', 'product.update.v1', 'product.setActive.v1'
     )
    or p_payload->>'unit' not in ('kilogram', 'ton')
     or pg_catalog.jsonb_typeof(p_payload->'isActive') <> 'boolean'
    or v_name is null
    or p_payload_fingerprint !~ '^[0-9a-f]{64}$'
     or v_default_price <= 0
     or v_minimum_price <= 0
     or v_reference_cost <= 0
    or (
       v_default_price is not null
       and v_minimum_price > v_default_price
     )
     or (p_operation_kind = 'product.create.v1'
         and p_base_entity_version is not null)
     or (p_operation_kind <> 'product.create.v1'
         and (p_base_entity_version is null or p_base_entity_version <= 0))
     or not exists (
       select 1 from public.business_memberships membership
       join public.businesses business
         on business.id = membership.business_id
       where membership.business_id = v_business_id
         and membership.auth_user_id = v_actor
         and membership.is_active
         and membership.role = 'owner'
         and business.is_active
     ) then
    return pg_catalog.jsonb_build_object(
      'ok', false, 'outcome', 'permanentFailure',
      'code', case when not exists (
        select 1 from public.business_memberships membership
        where membership.business_id = v_business_id
          and membership.auth_user_id = v_actor
          and membership.is_active
          and membership.role = 'owner'
      ) then 'unauthorized.productCatalogMutationDenied'
      else 'validation.invalidField' end
    );
  end if;

  v_fingerprint := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(
        private.canonical_jsonb_text(p_payload), 'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
  if v_fingerprint <> p_payload_fingerprint then
    return pg_catalog.jsonb_build_object(
      'ok', false, 'outcome', 'permanentFailure',
      'code', 'fingerprintMismatch'
    );
  end if;

  insert into private.product_catalog_operation_receipts (
    operation_id, idempotency_key, business_id, actor_auth_user_id,
    payload_fingerprint, status, created_at_utc
  ) values (
    v_operation_id, p_idempotency_key::uuid, v_business_id, v_actor,
    v_fingerprint, 'pending', v_now
  ) on conflict do nothing;
  get diagnostics v_inserted = row_count;

  select * into v_receipt
  from private.product_catalog_operation_receipts receipt
 where receipt.operation_id = v_operation_id
    or receipt.idempotency_key = p_idempotency_key::uuid
  order by (receipt.operation_id = v_operation_id) desc
  limit 1
 for update;
  if v_receipt.business_id <> v_business_id
     or v_receipt.actor_auth_user_id <> v_actor
     or v_receipt.idempotency_key <> p_idempotency_key::uuid
     or v_receipt.payload_fingerprint <> v_fingerprint then
    return pg_catalog.jsonb_build_object(
      'ok', false, 'outcome', 'permanentFailure',
      'code', 'idempotencyConflict'
    );
  end if;
  if v_inserted = 0 and v_receipt.status = 'completed' then
    return pg_catalog.jsonb_set(
      v_receipt.canonical_result_json, '{replayed}', 'true'::jsonb
    );
  end if;

  if p_operation_kind = 'product.create.v1' then
    begin
      insert into public.products (
        id, business_id, legacy_local_id, name, normalized_name,
        code, normalized_code, unit, is_active,
        default_sale_price_piasters_per_kg,
        minimum_sale_price_piasters_per_kg,
        reference_cost_price_piasters_per_kg, notes, entity_version,
        created_at_utc, server_modified_at_utc, actor_auth_user_id,
        device_id, source_operation_id
      ) values (
        v_product_id, v_business_id, p_payload->>'legacyLocalId',
        v_name, pg_catalog.lower(v_name), v_code,
        pg_catalog.lower(v_code), p_payload->>'unit',
        v_is_active, v_default_price, v_minimum_price, v_reference_cost,
        v_notes, 1, v_now, v_now, v_actor, v_device_id, v_operation_id
      )
      returning * into v_product;
    exception when unique_violation then
      select product.* into v_product
      from public.products product
      where product.business_id = v_business_id
        and (
          product.id = v_product_id
          or product.normalized_name = pg_catalog.lower(v_name)
          or (
            v_code is not null
            and product.normalized_code = pg_catalog.lower(v_code)
          )
        )
      order by (product.id = v_product_id) desc,
               product.entity_version desc
      limit 1;
      select change.* into v_change
      from public.product_catalog_changes change
      where change.business_id = v_business_id
        and change.product_id = v_product.id
      order by change.change_cursor desc
      limit 1;
      if v_change.change_cursor is null then
        raise exception 'missing product catalog change evidence';
      end if;
      v_result := private.product_catalog_result(v_change, false);
      delete from private.product_catalog_operation_receipts
      where operation_id = v_operation_id and status = 'pending';
      return pg_catalog.jsonb_build_object(
        'ok', false, 'outcome', 'versionConflict',
        'code', 'duplicateNaturalKey',
        'remote', v_result
      );
    end;
  else
    select * into v_product
    from public.products product
    where product.business_id = v_business_id
      and product.id = v_product_id
    for update;
    if not found then
      delete from private.product_catalog_operation_receipts
      where operation_id = v_operation_id and status = 'pending';
      return pg_catalog.jsonb_build_object(
        'ok', false, 'outcome', 'permanentFailure',
        'code', 'product.notFound'
      );
    end if;
    if v_product.is_deleted or
       v_product.entity_version <> p_base_entity_version then
      select change.* into v_change
      from public.product_catalog_changes change
      where change.business_id = v_business_id
        and change.product_id = v_product_id
      order by change.change_cursor desc
      limit 1;
      v_result := private.product_catalog_result(v_change, false);
      delete from private.product_catalog_operation_receipts
      where operation_id = v_operation_id and status = 'pending';
      return pg_catalog.jsonb_build_object(
        'ok', false, 'outcome', 'versionConflict',
        'code', case when v_product.is_deleted
          then 'deleteVsUpdate' else 'versionMismatch' end,
        'remote', v_result
      );
    end if;
    begin
      update public.products set
        name = v_name,
        normalized_name = pg_catalog.lower(v_name),
        code = v_code,
        normalized_code = pg_catalog.lower(v_code),
        unit = p_payload->>'unit',
        is_active = v_is_active,
        default_sale_price_piasters_per_kg = v_default_price,
        minimum_sale_price_piasters_per_kg = v_minimum_price,
        reference_cost_price_piasters_per_kg = v_reference_cost,
        notes = v_notes,
        entity_version = entity_version + 1,
        server_modified_at_utc = v_now,
        actor_auth_user_id = v_actor,
        device_id = v_device_id,
        source_operation_id = v_operation_id
      where business_id = v_business_id and id = v_product_id
      returning * into v_product;
    exception when unique_violation then
      select product.* into v_product
      from public.products product
      where product.business_id = v_business_id
        and product.id <> v_product_id
        and (
          product.normalized_name = pg_catalog.lower(v_name)
          or (
            v_code is not null
            and product.normalized_code = pg_catalog.lower(v_code)
          )
        )
      order by product.entity_version desc
      limit 1;
      select change.* into v_change
      from public.product_catalog_changes change
      where change.business_id = v_business_id
        and change.product_id = v_product.id
      order by change.change_cursor desc
      limit 1;
      if v_change.change_cursor is null then
        raise exception 'missing product catalog change evidence';
      end if;
      v_result := private.product_catalog_result(v_change, false);
      delete from private.product_catalog_operation_receipts
      where operation_id = v_operation_id and status = 'pending';
      return pg_catalog.jsonb_build_object(
        'ok', false, 'outcome', 'versionConflict',
        'code', 'duplicateNaturalKey',
        'remote', v_result
      );
    end;
  end if;

  insert into public.product_catalog_changes (
    business_id, product_id, entity_version, operation_kind, payload,
    payload_fingerprint, source_operation_id, actor_auth_user_id,
    device_id, server_modified_at_utc
  ) values (
    v_business_id, v_product_id, v_product.entity_version,
    p_operation_kind, p_payload, v_fingerprint, v_operation_id,
    v_actor, v_device_id, v_now
  ) returning * into v_change;

  v_result := private.product_catalog_result(v_change, false);
  update private.product_catalog_operation_receipts set
    status = 'completed',
    canonical_result_json = v_result,
    completed_at_utc = v_now
  where operation_id = v_operation_id;
  return v_result;
exception when others then
  return pg_catalog.jsonb_build_object(
    'ok', false, 'outcome', 'retryableFailure',
    'code', 'transactionFailure'
  );
end;
$$;

revoke all on function private.apply_product_catalog_operation_v1(
  text, text, text, text, text, bigint, jsonb, text
) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.apply_product_catalog_operation_v1(
  text, text, text, text, text, bigint, jsonb, text
) to authenticated;

create or replace function public.apply_product_catalog_operation_v1(
  p_business_id text,
  p_operation_id text,
  p_idempotency_key text,
  p_device_id text,
  p_operation_kind text,
  p_base_entity_version bigint,
  p_payload jsonb,
  p_payload_fingerprint text
) returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.apply_product_catalog_operation_v1(
    p_business_id, p_operation_id, p_idempotency_key, p_device_id,
    p_operation_kind, p_base_entity_version, p_payload,
    p_payload_fingerprint
  )
$$;

revoke all on function public.apply_product_catalog_operation_v1(
  text, text, text, text, text, bigint, jsonb, text
) from public, anon;
grant execute on function public.apply_product_catalog_operation_v1(
  text, text, text, text, text, bigint, jsonb, text
) to authenticated;

create or replace function public.pull_product_catalog_changes_v1(
  p_business_id text,
  p_after_cursor bigint,
  p_limit integer
) returns setof jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.product_catalog_result(change, false)
  from public.product_catalog_changes change
  where change.business_id = p_business_id::uuid
    and change.change_cursor >
      greatest(p_after_cursor, 0::bigint)
    and exists (
      select 1 from public.business_memberships membership
      where membership.business_id = change.business_id
        and membership.auth_user_id = (select auth.uid())
        and membership.is_active
        and membership.role in ('owner', 'employee', 'viewer')
    )
  order by change.change_cursor
  limit least(greatest(p_limit, 1), 100)
$$;

revoke all on function public.pull_product_catalog_changes_v1(
  text, bigint, integer
) from public, anon;
grant execute on function public.pull_product_catalog_changes_v1(
  text, bigint, integer
) to authenticated;
