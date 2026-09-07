begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values
  ('11000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'transfer-owner@example.test', '', now(), now(), now()),
  ('11000000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'transfer-employee@example.test', '', now(), now(), now()),
  ('11000000-0000-4000-8000-000000000003',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'transfer-outsider@example.test', '', now(), now(), now());

insert into public.businesses (id, name) values
  ('21000000-0000-4000-8000-000000000001', 'Transfer Business A'),
  ('21000000-0000-4000-8000-000000000002', 'Transfer Business B');
insert into public.business_memberships
  (business_id, auth_user_id, role, is_active) values
  ('21000000-0000-4000-8000-000000000001',
   '11000000-0000-4000-8000-000000000001', 'owner', true),
  ('21000000-0000-4000-8000-000000000001',
   '11000000-0000-4000-8000-000000000002', 'employee', true);

insert into public.financial_accounts (
  id, business_id, name, account_type, is_active,
  allow_negative_balance, is_cloud_ready, reconciled_at,
  reconciliation_version
) values
  ('31000000-0000-4000-8000-000000000001',
   '21000000-0000-4000-8000-000000000001', 'Source', 'treasury',
   true, false, true, now(), 1),
  ('31000000-0000-4000-8000-000000000002',
   '21000000-0000-4000-8000-000000000001', 'Destination', 'bank',
   true, false, true, now(), 1),
  ('31000000-0000-4000-8000-000000000003',
   '21000000-0000-4000-8000-000000000001', 'Wallet',
   'electronicWallet', true, false, true, now(), 1),
  ('31000000-0000-4000-8000-000000000004',
   '21000000-0000-4000-8000-000000000001', 'Inactive', 'treasury',
   false, false, true, now(), 1),
  ('31000000-0000-4000-8000-000000000005',
   '21000000-0000-4000-8000-000000000001', 'Negative allowed',
   'treasury', true, true, true, now(), 1),
  ('31000000-0000-4000-8000-000000000006',
   '21000000-0000-4000-8000-000000000002', 'Other business',
   'treasury', true, false, true, now(), 1),
  ('31000000-0000-4000-8000-000000000007',
   '21000000-0000-4000-8000-000000000001', 'Not Cloud ready',
   'treasury', true, false, false, null, 0);

insert into public.financial_account_entries (
  id, business_id, financial_account_id, direction, amount_qirsh,
  source_type, source_document_id, effective_date, created_by_auth_user_id
) values
  ('41000000-0000-4000-8000-000000000001',
   '21000000-0000-4000-8000-000000000001',
   '31000000-0000-4000-8000-000000000001', 'inflow', 10000,
   'openingBalance', '42000000-0000-4000-8000-000000000001', current_date,
   '11000000-0000-4000-8000-000000000001'),
  ('41000000-0000-4000-8000-000000000002',
   '21000000-0000-4000-8000-000000000001',
   '31000000-0000-4000-8000-000000000002', 'inflow', 5000,
   'openingBalance', '42000000-0000-4000-8000-000000000002', current_date,
   '11000000-0000-4000-8000-000000000001'),
  ('41000000-0000-4000-8000-000000000003',
   '21000000-0000-4000-8000-000000000001',
   '31000000-0000-4000-8000-000000000003', 'inflow', 1000,
   'openingBalance', '42000000-0000-4000-8000-000000000003', current_date,
   '11000000-0000-4000-8000-000000000001'),
  ('41000000-0000-4000-8000-000000000005',
   '21000000-0000-4000-8000-000000000001',
   '31000000-0000-4000-8000-000000000005', 'inflow', 100,
   'openingBalance', '42000000-0000-4000-8000-000000000005', current_date,
   '11000000-0000-4000-8000-000000000001');

select throws_ok(
  $$insert into public.financial_accounts (
      id, business_id, name, account_type, is_active,
      allow_negative_balance, is_cloud_ready, reconciliation_version
    ) values (
      '31000000-0000-4000-8000-000000000008',
      '21000000-0000-4000-8000-000000000001', 'Unsupported',
      'unsupported', true, false, true, 1
    )$$,
  '23514', null, 'unsupported account type cannot enter the domain'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{}', true);
select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000000', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000002', 1250, current_date::text,
  '61000000-0000-4000-8000-000000000000', null
)->>'code', 'unauthenticated.sessionRequired', 'session is required');

select set_config('request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000002"}', true);
select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000000', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000002', 1250, current_date::text,
  '61000000-0000-4000-8000-000000000000', null
)->>'code', 'unauthorized.internalTransferDenied',
  'employee cannot execute transfer');

select set_config('request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000001"}', true);

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000001', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000002', 1250, current_date::text,
  '61000000-0000-4000-8000-000000000001', '  note  '
)->>'ok', 'true', 'owner transfer succeeds');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000001', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000002', 1250, current_date::text,
  '61000000-0000-4000-8000-000000000001', 'note'
)->>'replayed', 'true', 'normalized exact replay returns receipt');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000001', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000002', 1251, current_date::text,
  '61000000-0000-4000-8000-000000000001', 'note'
)->>'code', 'idempotencyConflict', 'changed payload conflicts');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000002', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000002', 1, current_date::text,
  '61000000-0000-4000-8000-000000000001', null
)->>'code', 'transferReference.conflict', 'duplicate reference conflicts');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000003', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001', 1, current_date::text,
  '61000000-0000-4000-8000-000000000003', null
)->>'code', 'validation.sameAccount', 'same account is rejected');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000004', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000004',
  '31000000-0000-4000-8000-000000000002', 1, current_date::text,
  '61000000-0000-4000-8000-000000000004', null
)->>'code', 'sourceAccount.notFoundOrInactive',
  'inactive source is rejected');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000005', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000005',
  '31000000-0000-4000-8000-000000000002', 101, current_date::text,
  '61000000-0000-4000-8000-000000000005', null
)->>'code', 'balance.insufficient',
  'insufficient funds reject even when negatives are allowed');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000006', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000006', 1, current_date::text,
  '61000000-0000-4000-8000-000000000006', null
)->>'code', 'wrongBusinessContext', 'cross-business destination is rejected');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000009', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000007', 1, current_date::text,
  '61000000-0000-4000-8000-000000000009', null
)->>'code', 'destinationAccount.notFoundOrInactive',
  'unready destination is rejected while both account locks are held');

select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000007', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000003',
  '31000000-0000-4000-8000-000000000002', 250, current_date::text,
  '61000000-0000-4000-8000-000000000007', null
)->>'displayNumber', 'TR-000002',
  'second successful transfer receives next business number');

select set_config('internal_transfer.inject_failure', 'after_header', true);
select is(public.post_internal_transfer_v1(
  '51000000-0000-4000-8000-000000000008', 1,
  '21000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000002', 100, current_date::text,
  '61000000-0000-4000-8000-000000000008', null
)->>'code', 'transactionFailure', 'injected failure is atomic');
select set_config('internal_transfer.inject_failure', '', true);

reset role;

select is((select count(*) from public.financial_transfers), 2::bigint,
  'two successful headers and no rejected headers');
select is((select count(*) from public.financial_account_entries
  where source_type in ('transferOut', 'transferIn')), 4::bigint,
  'exactly two ledger legs per success');
select is((select count(*) from public.audit_events
  where action_type in ('financial_account.entry.created',
    'financial_transfer.created')), 6::bigint,
  'exactly three audits per success');
select is((select count(*) from public.financial_command_receipts
  where command_type = 'post_internal_transfer' and status = 'completed'),
  2::bigint, 'exactly one completed receipt per success');
select is((select next_number from private.financial_transfer_number_counters
  where business_id = '21000000-0000-4000-8000-000000000001'),
  3::bigint, 'replay/rejections/failure do not consume a number');
select is((select count(*) from public.financial_transfers
  where command_id = '51000000-0000-4000-8000-000000000001'),
  1::bigint, 'exact replay creates no duplicate transfer');
select is((select count(*) from public.financial_account_entries entry
  join public.financial_transfers transfer
    on transfer.id = entry.source_document_id
  where transfer.command_id = '51000000-0000-4000-8000-000000000001'),
  2::bigint, 'header has two equal and opposite entries');
select ok((select source_entry.amount_qirsh = destination_entry.amount_qirsh
    and source_entry.direction = 'outflow'
    and destination_entry.direction = 'inflow'
  from public.financial_transfers transfer
  join public.financial_account_entries source_entry
    on source_entry.id = transfer.source_entry_id
  join public.financial_account_entries destination_entry
    on destination_entry.id = transfer.destination_entry_id
  where transfer.command_id = '51000000-0000-4000-8000-000000000001'),
  'entry amounts are equal with opposite directions');
select is((select sum(case when direction = 'inflow' then amount_qirsh
    else -amount_qirsh end)
  from public.financial_account_entries
  where source_type in ('transferOut', 'transferIn')), 0::numeric,
  'combined transfer ledger value is zero');
select is((select count(*) from public.financial_transfers
  where command_id = '51000000-0000-4000-8000-000000000008'),
  0::bigint, 'injected failure leaves no header');
select is((select count(*) from public.financial_account_entries
  where source_document_id in (select id from public.financial_transfers
    where command_id = '51000000-0000-4000-8000-000000000008')),
  0::bigint, 'injected failure leaves no legs');
select is((select count(*) from public.financial_command_receipts
  where command_id = '51000000-0000-4000-8000-000000000008'),
  0::bigint, 'injected failure leaves no receipt');

select ok(not has_table_privilege('authenticated',
  'public.financial_transfers', 'INSERT'),
  'authenticated cannot insert transfer headers directly');
select ok(not has_table_privilege('authenticated',
  'public.financial_account_entries', 'INSERT'),
  'authenticated cannot insert ledger entries directly');
select ok(not has_table_privilege('authenticated',
  'public.financial_command_receipts', 'INSERT,UPDATE,DELETE'),
  'authenticated cannot mutate receipts directly');
select ok(not has_table_privilege('authenticated',
  'public.audit_events', 'INSERT,UPDATE,DELETE'),
  'authenticated cannot mutate authoritative audits directly');
select ok(not has_table_privilege('authenticated',
  'private.financial_transfer_number_counters', 'INSERT,UPDATE,DELETE'),
  'authenticated cannot mutate the private number counter directly');
select ok(not has_function_privilege('anon',
  'public.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)',
  'EXECUTE'), 'anon cannot execute public wrapper');
select ok(has_function_privilege('authenticated',
  'public.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)',
  'EXECUTE'), 'authenticated may execute only the exposed wrapper API');
select ok(not has_function_privilege('anon',
  'private.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)',
  'EXECUTE'), 'anon cannot execute private implementation');
select ok((select prosecdef from pg_proc
  where oid = 'private.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)'::regprocedure),
  'private implementation is security definer');
select ok(not (select prosecdef from pg_proc
  where oid = 'public.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)'::regprocedure),
  'public wrapper is security invoker');
select ok((select pg_get_functiondef(
  'private.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)'::regprocedure))
    like '%SET search_path TO ''''%',
  'private function has empty search path');
select ok((select pg_get_functiondef(
  'private.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)'::regprocedure))
    like '%least(v_source_id, v_destination_id)%',
  'account locking chooses the lower UUID first');
select ok((select pg_get_functiondef(
  'private.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)'::regprocedure))
    like '%greatest(v_source_id, v_destination_id)%',
  'account locking chooses the higher UUID second');
select ok((select relrowsecurity from pg_class
  where oid = 'public.financial_transfers'::regclass),
  'transfer table has RLS enabled');
select ok((select relrowsecurity from pg_class
  where oid = 'private.financial_transfer_number_counters'::regclass),
  'private number counter has RLS defense in depth');
select ok(coalesce(current_setting('pgrst.db_schemas', true), 'public')
    not like '%private%',
  'private schema is not exposed through PostgREST');

select * from finish();
rollback;
