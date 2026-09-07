create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;

-- This test deliberately commits its isolated fixture so the independent
-- dblink sessions can see it. Fixed IDs and cleanup on both ends keep reruns
-- deterministic on the disposable local Supabase database.
delete from public.audit_events
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.financial_transfers
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.financial_command_receipts
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.financial_account_entries
where business_id = '22000000-0000-4000-8000-000000000001';
delete from private.financial_transfer_number_counters
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.financial_accounts
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.business_memberships
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.businesses
where id = '22000000-0000-4000-8000-000000000001';
delete from auth.users
where id = '12000000-0000-4000-8000-000000000001';

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values (
  '12000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', 'transfer-concurrency@example.test', '',
  now(), now(), now()
);
insert into public.businesses (id, name) values
  ('22000000-0000-4000-8000-000000000001', 'Transfer Concurrency');
insert into public.business_memberships
  (business_id, auth_user_id, role, is_active) values (
  '22000000-0000-4000-8000-000000000001',
  '12000000-0000-4000-8000-000000000001', 'owner', true
);
insert into public.financial_accounts (
  id, business_id, name, account_type, is_active,
  allow_negative_balance, is_cloud_ready, reconciled_at,
  reconciliation_version
)
select id::uuid,
  '22000000-0000-4000-8000-000000000001'::uuid,
  name, 'treasury', true, false, true, now(), 1
from (values
  ('32000000-0000-4000-8000-000000000001', 'Competing source'),
  ('32000000-0000-4000-8000-000000000002', 'Competing destination one'),
  ('32000000-0000-4000-8000-000000000003', 'Competing destination two'),
  ('32000000-0000-4000-8000-000000000004', 'Opposite A'),
  ('32000000-0000-4000-8000-000000000005', 'Opposite B'),
  ('32000000-0000-4000-8000-000000000006', 'Replay source'),
  ('32000000-0000-4000-8000-000000000007', 'Replay destination')
) as fixture(id, name);
insert into public.financial_account_entries (
  id, business_id, financial_account_id, direction, amount_qirsh,
  source_type, source_document_id, effective_date,
  created_by_auth_user_id
)
select entry_id::uuid,
  '22000000-0000-4000-8000-000000000001'::uuid,
  account_id::uuid, 'inflow', amount_qirsh, 'openingBalance',
  document_id::uuid, current_date,
  '12000000-0000-4000-8000-000000000001'::uuid
from (values
  ('42000000-0000-4000-8000-000000000001',
   '32000000-0000-4000-8000-000000000001',
   '43000000-0000-4000-8000-000000000001', 100::bigint),
  ('42000000-0000-4000-8000-000000000004',
   '32000000-0000-4000-8000-000000000004',
   '43000000-0000-4000-8000-000000000004', 100::bigint),
  ('42000000-0000-4000-8000-000000000005',
   '32000000-0000-4000-8000-000000000005',
   '43000000-0000-4000-8000-000000000005', 100::bigint),
  ('42000000-0000-4000-8000-000000000006',
   '32000000-0000-4000-8000-000000000006',
   '43000000-0000-4000-8000-000000000006', 100::bigint)
) as fixture(entry_id, account_id, document_id, amount_qirsh);

select no_plan();
select is(extensions.dblink_connect(
  'transfer_concurrency_one',
  'host=host.docker.internal port=55322 dbname=postgres user=postgres password=postgres'
), 'OK', 'first bounded concurrency connection opens');
select is(extensions.dblink_connect(
  'transfer_concurrency_two',
  'host=host.docker.internal port=55322 dbname=postgres user=postgres password=postgres'
), 'OK', 'second bounded concurrency connection opens');

create temporary table internal_transfer_concurrency_results (
  scenario text not null,
  result jsonb not null
);

select is(extensions.dblink_send_query('transfer_concurrency_one', $sql$
  with claims as materialized (
    select set_config(
      'request.jwt.claim.sub',
      '12000000-0000-4000-8000-000000000001', false
    )
  )
  select public.post_internal_transfer_v1(
    '52000000-0000-4000-8000-000000000001', 1,
    '22000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000002',
    80, current_date::text,
    '62000000-0000-4000-8000-000000000001', null
  )::text from claims
$sql$), 1, 'first competing withdrawal starts asynchronously');
select is(extensions.dblink_send_query('transfer_concurrency_two', $sql$
  with claims as materialized (
    select set_config(
      'request.jwt.claim.sub',
      '12000000-0000-4000-8000-000000000001', false
    )
  )
  select public.post_internal_transfer_v1(
    '52000000-0000-4000-8000-000000000002', 1,
    '22000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000003',
    80, current_date::text,
    '62000000-0000-4000-8000-000000000002', null
  )::text from claims
$sql$), 1, 'second competing withdrawal starts asynchronously');
insert into internal_transfer_concurrency_results
select 'withdrawal_one', result::jsonb
from extensions.dblink_get_result('transfer_concurrency_one')
  as response(result text);
insert into internal_transfer_concurrency_results
select 'withdrawal_two', result::jsonb
from extensions.dblink_get_result('transfer_concurrency_two')
  as response(result text);
select is((select count(*)
  from extensions.dblink_get_result('transfer_concurrency_one', false)
    as response(result text)), 0::bigint,
  'first competing query result is fully drained');
select is((select count(*)
  from extensions.dblink_get_result('transfer_concurrency_two', false)
    as response(result text)), 0::bigint,
  'second competing query result is fully drained');
select is((select count(*) from internal_transfer_concurrency_results
  where scenario like 'withdrawal_%' and result->>'ok' = 'true'),
  1::bigint, 'competing withdrawals permit exactly one success');
select is((select count(*) from internal_transfer_concurrency_results
  where scenario like 'withdrawal_%'
    and result->>'code' = 'balance.insufficient'),
  1::bigint, 'competing withdrawal rechecks balance after account lock');
select is((select sum(case when direction = 'inflow' then amount_qirsh
    else -amount_qirsh end)
  from public.financial_account_entries
  where financial_account_id =
    '32000000-0000-4000-8000-000000000001'),
  20::numeric, 'competing withdrawals cannot overspend the source');

select is(extensions.dblink_send_query('transfer_concurrency_one', $sql$
  with claims as materialized (
    select set_config(
      'request.jwt.claim.sub',
      '12000000-0000-4000-8000-000000000001', false
    )
  )
  select public.post_internal_transfer_v1(
    '52000000-0000-4000-8000-000000000003', 1,
    '22000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000004',
    '32000000-0000-4000-8000-000000000005',
    10, current_date::text,
    '62000000-0000-4000-8000-000000000003', null
  )::text from claims
$sql$), 1, 'A-to-B transfer starts asynchronously');
select is(extensions.dblink_send_query('transfer_concurrency_two', $sql$
  with claims as materialized (
    select set_config(
      'request.jwt.claim.sub',
      '12000000-0000-4000-8000-000000000001', false
    )
  )
  select public.post_internal_transfer_v1(
    '52000000-0000-4000-8000-000000000004', 1,
    '22000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000005',
    '32000000-0000-4000-8000-000000000004',
    10, current_date::text,
    '62000000-0000-4000-8000-000000000004', null
  )::text from claims
$sql$), 1, 'B-to-A transfer starts asynchronously');
insert into internal_transfer_concurrency_results
select 'opposite_one', result::jsonb
from extensions.dblink_get_result('transfer_concurrency_one')
  as response(result text);
insert into internal_transfer_concurrency_results
select 'opposite_two', result::jsonb
from extensions.dblink_get_result('transfer_concurrency_two')
  as response(result text);
select is((select count(*)
  from extensions.dblink_get_result('transfer_concurrency_one', false)
    as response(result text)), 0::bigint,
  'A-to-B query result is fully drained');
select is((select count(*)
  from extensions.dblink_get_result('transfer_concurrency_two', false)
    as response(result text)), 0::bigint,
  'B-to-A query result is fully drained');
select is((select count(*) from internal_transfer_concurrency_results
  where scenario like 'opposite_%' and result->>'ok' = 'true'),
  2::bigint, 'opposite-direction transfers complete without deadlock');

select is(extensions.dblink_send_query('transfer_concurrency_one', $sql$
  with claims as materialized (
    select set_config(
      'request.jwt.claim.sub',
      '12000000-0000-4000-8000-000000000001', false
    )
  )
  select public.post_internal_transfer_v1(
    '52000000-0000-4000-8000-000000000005', 1,
    '22000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000006',
    '32000000-0000-4000-8000-000000000007',
    10, current_date::text,
    '62000000-0000-4000-8000-000000000005', null
  )::text from claims
$sql$), 1, 'first identical command starts asynchronously');
select is(extensions.dblink_send_query('transfer_concurrency_two', $sql$
  with claims as materialized (
    select set_config(
      'request.jwt.claim.sub',
      '12000000-0000-4000-8000-000000000001', false
    )
  )
  select public.post_internal_transfer_v1(
    '52000000-0000-4000-8000-000000000005', 1,
    '22000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000006',
    '32000000-0000-4000-8000-000000000007',
    10, current_date::text,
    '62000000-0000-4000-8000-000000000005', null
  )::text from claims
$sql$), 1, 'second identical command starts asynchronously');
insert into internal_transfer_concurrency_results
select 'replay_one', result::jsonb
from extensions.dblink_get_result('transfer_concurrency_one')
  as response(result text);
insert into internal_transfer_concurrency_results
select 'replay_two', result::jsonb
from extensions.dblink_get_result('transfer_concurrency_two')
  as response(result text);
select is((select count(*)
  from extensions.dblink_get_result('transfer_concurrency_one', false)
    as response(result text)), 0::bigint,
  'first identical query result is fully drained');
select is((select count(*)
  from extensions.dblink_get_result('transfer_concurrency_two', false)
    as response(result text)), 0::bigint,
  'second identical query result is fully drained');
select is((select count(*) from internal_transfer_concurrency_results
  where scenario like 'replay_%' and result->>'ok' = 'true'),
  2::bigint, 'both identical callers converge to an authoritative result');
select is((select count(*) from internal_transfer_concurrency_results
  where scenario like 'replay_%' and result->>'replayed' = 'true'),
  1::bigint, 'one concurrent identical caller receives an exact replay');
select is((select count(*) from public.financial_transfers
  where command_id = '52000000-0000-4000-8000-000000000005'),
  1::bigint, 'concurrent identical commands create one transfer');
select is((select count(distinct display_number)
  from public.financial_transfers
  where business_id = '22000000-0000-4000-8000-000000000001'),
  4::bigint, 'all concurrent successes receive unique display numbers');

select is(extensions.dblink_disconnect('transfer_concurrency_one'), 'OK',
  'first concurrency connection closes');
select is(extensions.dblink_disconnect('transfer_concurrency_two'), 'OK',
  'second concurrency connection closes');
select * from finish();

delete from public.audit_events
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.financial_transfers
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.financial_command_receipts
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.financial_account_entries
where business_id = '22000000-0000-4000-8000-000000000001';
delete from private.financial_transfer_number_counters
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.financial_accounts
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.business_memberships
where business_id = '22000000-0000-4000-8000-000000000001';
delete from public.businesses
where id = '22000000-0000-4000-8000-000000000001';
delete from auth.users
where id = '12000000-0000-4000-8000-000000000001';
