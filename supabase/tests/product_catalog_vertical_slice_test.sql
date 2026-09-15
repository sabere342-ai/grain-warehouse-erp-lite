begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values
  ('11000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'catalog-owner@example.test', '', now(), now(), now()),
  ('11000000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'catalog-employee@example.test', '', now(), now(), now()),
  ('11000000-0000-4000-8000-000000000003',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'catalog-viewer@example.test', '', now(), now(), now()),
  ('11000000-0000-4000-8000-000000000004',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'catalog-outsider@example.test', '', now(), now(), now());

insert into public.businesses (id, name) values
  ('21000000-0000-4000-8000-000000000001', 'Catalog A'),
  ('21000000-0000-4000-8000-000000000002', 'Catalog B');

insert into public.business_memberships
  (business_id, auth_user_id, role, is_active) values
  ('21000000-0000-4000-8000-000000000001',
   '11000000-0000-4000-8000-000000000001', 'owner', true),
  ('21000000-0000-4000-8000-000000000001',
   '11000000-0000-4000-8000-000000000002', 'employee', true),
  ('21000000-0000-4000-8000-000000000001',
   '11000000-0000-4000-8000-000000000003', 'viewer', true);

select set_config(
  'test.catalog.create_payload',
  '{"schemaVersion":1,"mutationKind":"product.create.v1",'
  '"remoteProductId":"31000000-0000-4000-8000-000000000001",'
  '"legacyLocalId":"prd-legacy","name":"قمح","code":"W-1",'
  '"unit":"kilogram","isActive":true,'
  '"defaultSalePricePiastersPerKg":1200,'
  '"minimumSalePricePiastersPerKg":1000,'
  '"referenceCostPricePiastersPerKg":900,"notes":null}',
  false
);
select set_config(
  'test.catalog.create_fingerprint',
  encode(
    extensions.digest(
      convert_to(
        private.canonical_jsonb_text(
          current_setting('test.catalog.create_payload')::jsonb
        ),
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  ),
  false
);

select ok(
  has_table_privilege('authenticated', 'public.products', 'SELECT'),
  'authenticated members have the RLS-filtered read grant'
);
select ok(
  not has_table_privilege('authenticated', 'public.products', 'INSERT'),
  'authenticated clients cannot insert products directly'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.apply_product_catalog_operation_v1(text,text,text,text,text,bigint,jsonb,text)',
    'EXECUTE'
  ),
  'authenticated users can execute the public mutation wrapper'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.apply_product_catalog_operation_v1(text,text,text,text,text,bigint,jsonb,text)',
    'EXECUTE'
  ),
  'anonymous users cannot execute the mutation wrapper'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000001', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000001"}', true
);

select is(
  public.apply_product_catalog_operation_v1(
    '21000000-0000-4000-8000-000000000001',
    '41000000-0000-4000-8000-000000000001',
    '41000000-0000-4000-8000-000000000001',
    '51000000-0000-4000-8000-000000000001',
    'product.create.v1', null,
    current_setting('test.catalog.create_payload')::jsonb,
    current_setting('test.catalog.create_fingerprint')
  )->>'entityVersion',
  '1',
  'owner creates version one'
);

select is(
  public.apply_product_catalog_operation_v1(
    '21000000-0000-4000-8000-000000000001',
    '41000000-0000-4000-8000-000000000001',
    '41000000-0000-4000-8000-000000000001',
    '51000000-0000-4000-8000-000000000001',
    'product.create.v1', null,
    current_setting('test.catalog.create_payload')::jsonb,
    current_setting('test.catalog.create_fingerprint')
  )->>'replayed',
  'true',
  'exact replay returns the receipt without another mutation'
);

select is((select count(*)::text from public.products), '1',
  'one authoritative product exists');
select is((select count(*)::text from public.product_catalog_changes), '1',
  'one accepted operation emits one change');

reset role;
select set_config(
  'test.catalog.duplicate_payload',
  replace(
    current_setting('test.catalog.create_payload'),
    '31000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000002'
  ),
  false
);
select set_config(
  'test.catalog.duplicate_fingerprint',
  encode(
    extensions.digest(
      convert_to(
        private.canonical_jsonb_text(
          current_setting('test.catalog.duplicate_payload')::jsonb
        ),
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  ),
  false
);
set local role authenticated;
select is(
  public.apply_product_catalog_operation_v1(
    '21000000-0000-4000-8000-000000000001',
    '41000000-0000-4000-8000-000000000010',
    '41000000-0000-4000-8000-000000000010',
    '51000000-0000-4000-8000-000000000010',
    'product.create.v1', null,
    current_setting('test.catalog.duplicate_payload')::jsonb,
    current_setting('test.catalog.duplicate_fingerprint')
  )->>'outcome',
  'versionConflict',
  'natural-key collision is a durable conflict outcome'
);
select is(
  public.apply_product_catalog_operation_v1(
    '21000000-0000-4000-8000-000000000001',
    '41000000-0000-4000-8000-000000000010',
    '41000000-0000-4000-8000-000000000010',
    '51000000-0000-4000-8000-000000000010',
    'product.create.v1', null,
    current_setting('test.catalog.duplicate_payload')::jsonb,
    current_setting('test.catalog.duplicate_fingerprint')
  )#>>'{remote,payload,remoteProductId}',
  '31000000-0000-4000-8000-000000000001',
  'natural-key conflict preserves the authoritative remote snapshot'
);
select is((select count(*)::text from public.products), '1',
  'natural-key collision does not create another product');
select is((select count(*)::text from public.product_catalog_changes), '1',
  'natural-key collision does not emit another change');

select set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000002', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000002"}', true
);
select is(
  public.apply_product_catalog_operation_v1(
    '21000000-0000-4000-8000-000000000001',
    '41000000-0000-4000-8000-000000000002',
    '41000000-0000-4000-8000-000000000002',
    '51000000-0000-4000-8000-000000000002',
    'product.create.v1', null,
    current_setting('test.catalog.create_payload')::jsonb,
    current_setting('test.catalog.create_fingerprint')
  )->>'code',
  'unauthorized.productCatalogMutationDenied',
  'employee cannot mutate the catalog'
);

select set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000003', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000003"}', true
);
select is(
  (select count(*)::text from public.pull_product_catalog_changes_v1(
    '21000000-0000-4000-8000-000000000001', 0, 100
  )),
  '1',
  'viewer can pull the active business in cursor order'
);
select is(
  (select count(*)::text from public.pull_product_catalog_changes_v1(
    '21000000-0000-4000-8000-000000000002', 0, 100
  )),
  '0',
  'member cannot pull another business'
);

select set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000004', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000004"}', true
);
select is((select count(*)::text from public.products), '0',
  'RLS hides products from a non-member');

reset role;
select * from finish();
rollback;
