begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values
  ('10000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'employee@example.test', '', now(), now(), now()),
  ('10000000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'owner@example.test', '', now(), now(), now()),
  ('10000000-0000-4000-8000-000000000003',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'outsider@example.test', '', now(), now(), now()),
  ('10000000-0000-4000-8000-000000000004',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'viewer@example.test', '', now(), now(), now()),
  ('10000000-0000-4000-8000-000000000005',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'inactive@example.test', '', now(), now(), now());

insert into public.businesses (id, name) values
  ('20000000-0000-4000-8000-000000000001', 'Business A'),
  ('20000000-0000-4000-8000-000000000002', 'Business B');

insert into public.business_memberships
  (business_id, auth_user_id, role, is_active) values
  ('20000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000001', 'employee', true),
  ('20000000-0000-4000-8000-000000000002',
   '10000000-0000-4000-8000-000000000001', 'employee', true),
  ('20000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000002', 'owner', true),
  ('20000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000004', 'viewer', true),
  ('20000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000005', 'employee', false);

insert into public.financial_accounts (
  id, business_id, name, account_type, is_active,
  allow_negative_balance, is_cloud_ready, reconciled_at,
  reconciliation_version
) values
  ('30000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001', 'Treasury', 'treasury',
   true, false, true, now(), 1),
  ('30000000-0000-4000-8000-000000000002',
   '20000000-0000-4000-8000-000000000001', 'Bank', 'bank',
   true, false, true, now(), 1),
  ('30000000-0000-4000-8000-000000000003',
   '20000000-0000-4000-8000-000000000001', 'Wallet',
   'electronicWallet', true, false, true, now(), 1),
  ('30000000-0000-4000-8000-000000000004',
   '20000000-0000-4000-8000-000000000001', 'Inactive', 'treasury',
   false, false, true, now(), 1),
  ('30000000-0000-4000-8000-000000000005',
   '20000000-0000-4000-8000-000000000001', 'Approval', 'treasury',
   true, true, true, now(), 1),
  ('30000000-0000-4000-8000-000000000006',
   '20000000-0000-4000-8000-000000000001', 'Insufficient', 'treasury',
   true, false, true, now(), 1),
  ('30000000-0000-4000-8000-000000000007',
   '20000000-0000-4000-8000-000000000002', 'Other business', 'treasury',
   true, false, true, now(), 1);

insert into public.financial_account_entries (
  id, business_id, financial_account_id, direction, amount_qirsh,
  source_type, source_document_id, effective_date,
  created_by_auth_user_id
) values
  ('40000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '30000000-0000-4000-8000-000000000001', 'inflow', 10000,
   'openingBalance', '41000000-0000-4000-8000-000000000001', current_date,
   '10000000-0000-4000-8000-000000000002'),
  ('40000000-0000-4000-8000-000000000002',
   '20000000-0000-4000-8000-000000000001',
   '30000000-0000-4000-8000-000000000002', 'inflow', 10000,
   'openingBalance', '41000000-0000-4000-8000-000000000002', current_date,
   '10000000-0000-4000-8000-000000000002'),
  ('40000000-0000-4000-8000-000000000003',
   '20000000-0000-4000-8000-000000000001',
   '30000000-0000-4000-8000-000000000003', 'inflow', 10000,
   'openingBalance', '41000000-0000-4000-8000-000000000003', current_date,
   '10000000-0000-4000-8000-000000000002'),
  ('40000000-0000-4000-8000-000000000007',
   '20000000-0000-4000-8000-000000000002',
   '30000000-0000-4000-8000-000000000007', 'inflow', 10000,
   'openingBalance', '41000000-0000-4000-8000-000000000007', current_date,
   '10000000-0000-4000-8000-000000000002');

set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{}', true);
select is(
  public.post_expense_v1(
    '50000000-0000-4000-8000-000000000000', 1,
    '20000000-0000-4000-8000-000000000001', current_date::text,
    'Transport', 1000, null,
    '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
  )->>'code',
  'unauthenticated.sessionRequired',
  'unauthenticated caller is denied'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000003', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003"}', true
);
select is(
  public.post_expense_v1(
    '50000000-0000-4000-8000-000000000000', 1,
    '20000000-0000-4000-8000-000000000001', current_date::text,
    'Transport', 1000, null,
    '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
  )->>'code',
  'unauthorized.expensePostingDenied',
  'caller without membership is denied'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000004', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004"}', true
);
select is(
  public.post_expense_v1(
    '50000000-0000-4000-8000-000000000000', 1,
    '20000000-0000-4000-8000-000000000001', current_date::text,
    'Transport', 1000, null,
    '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
  )->>'code',
  'unauthorized.expensePostingDenied',
  'wrong membership role is denied'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000005', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000005"}', true
);
select is(
  public.post_expense_v1(
    '50000000-0000-4000-8000-000000000000', 1,
    '20000000-0000-4000-8000-000000000001', current_date::text,
    'Transport', 1000, null,
    '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
  )->>'code',
  'unauthorized.expensePostingDenied',
  'inactive membership is denied'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001"}', true
);

select is(
  public.post_expense_v1(
    '50000000-0000-4000-8000-000000000001', 1,
    '20000000-0000-4000-8000-000000000001', current_date::text,
    '  Transport  ', 1250, '  note  ',
    '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
  )->>'ok',
  'true',
  'successful first post'
);

select is(
  public.post_expense_v1(
    '50000000-0000-4000-8000-000000000001', 1,
    '20000000-0000-4000-8000-000000000001', current_date::text,
    'Transport', 1250, 'note',
    '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
  )->>'replayed',
  'true',
  'normalized exact replay succeeds'
);

reset role;
select is((select count(*) from public.expenses where command_id =
  '50000000-0000-4000-8000-000000000001'), 1::bigint,
  'exactly one expense');
select is((select count(*) from public.financial_account_entries
  where source_type = 'expense' and source_document_id in
    (select id from public.expenses where command_id =
      '50000000-0000-4000-8000-000000000001')), 1::bigint,
  'exactly one expense outflow entry');
select is((select count(*) from public.audit_events where command_id =
  '50000000-0000-4000-8000-000000000001'), 2::bigint,
  'exactly two audit events');
select is((select count(*) from public.financial_command_receipts where
  command_id = '50000000-0000-4000-8000-000000000001'
  and status = 'completed'), 1::bigint, 'exactly one completed receipt');
select is((select sum(case when direction = 'inflow' then amount_qirsh
  else -amount_qirsh end) from public.financial_account_entries where
  financial_account_id = '30000000-0000-4000-8000-000000000001'),
  8750::numeric, 'balance decreases exactly once');
select is((select count(distinct id) from public.audit_events where command_id =
  '50000000-0000-4000-8000-000000000001'), 2::bigint,
  'audit IDs are distinct');
select ok((select id <> command_id from public.expenses where command_id =
  '50000000-0000-4000-8000-000000000001'),
  'server expense ID is independent of the client command ID');
select ok((select entry.id <> expense.id and entry.id <> expense.command_id
  from public.financial_account_entries entry
  join public.expenses expense on expense.id = entry.source_document_id
  where expense.command_id = '50000000-0000-4000-8000-000000000001'),
  'server entry ID is independently generated');
select ok((select accepted_at between now() - interval '1 minute'
  and clock_timestamp() + interval '1 second' from public.expenses
  where command_id = '50000000-0000-4000-8000-000000000001'),
  'server acceptance timestamp comes from the database clock');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000002', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002"}', true
);
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000001', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Transport', 1250, 'note',
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'idempotencyConflict', 'changed actor conflicts');
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001"}', true
);

select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000001', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Changed', 1250, 'note',
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'idempotencyConflict', 'changed category conflicts');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000001', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Transport', 1251, 'note',
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'idempotencyConflict', 'changed amount conflicts');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000001', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Transport', 1250, 'note',
  '30000000-0000-4000-8000-000000000002', 'bankTransfer', 'operating'
)->>'code', 'idempotencyConflict', 'changed account conflicts');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000001', 1,
  '20000000-0000-4000-8000-000000000002', current_date::text,
  'Transport', 1250, 'note',
  '30000000-0000-4000-8000-000000000007', 'cash', 'operating'
)->>'code', 'idempotencyConflict', 'changed business conflicts');

select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000002', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Bank fee', 100, null,
  '30000000-0000-4000-8000-000000000002', 'bankTransfer', 'capital'
)->>'ok', 'true', 'bank transfer route succeeds');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000003', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Wallet fee', 100, null,
  '30000000-0000-4000-8000-000000000003', 'mobileWallet', 'nonOperating'
)->>'ok', 'true', 'mobile wallet route succeeds');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000004', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Bad route', 100, null,
  '30000000-0000-4000-8000-000000000002', 'cash', 'operating'
)->>'code', 'paymentRoute.invalid', 'invalid route is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000005', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Cheque', 100, null,
  '30000000-0000-4000-8000-000000000001', 'check', 'operating'
)->>'code', 'validation.invalidField', 'cheque is rejected');

select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000006', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Zero', 0, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'validation.invalidField', 'zero amount is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000007', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Negative', -1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'validation.invalidField', 'negative amount is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000008', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  '   ', 1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'validation.invalidField', 'blank category is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000009', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Bad class', 1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'other'
)->>'code', 'validation.invalidField', 'invalid classification is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000010', 1,
  '20000000-0000-4000-8000-000000000001', '2026-02-30',
  'Bad date', 1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'validation.invalidField', 'invalid date is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000011', 1,
  '20000000-0000-4000-8000-000000000001',
  (current_date + 1)::text, 'Future', 1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'validation.invalidField', 'future date is rejected');

select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000012', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Missing', 1, null,
  '39999999-0000-4000-8000-000000000099', 'cash', 'operating'
)->>'code', 'account.notFoundOrInactive', 'missing account is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000013', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Inactive', 1, null,
  '30000000-0000-4000-8000-000000000004', 'cash', 'operating'
)->>'code', 'account.notFoundOrInactive', 'inactive account is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000014', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Cross business', 1, null,
  '30000000-0000-4000-8000-000000000007', 'cash', 'operating'
)->>'code', 'wrongBusinessContext', 'cross-business account is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000015', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'No balance', 1, null,
  '30000000-0000-4000-8000-000000000006', 'cash', 'operating'
)->>'code', 'balance.insufficient', 'insufficient balance is rejected');
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000016', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Approval path', 1, null,
  '30000000-0000-4000-8000-000000000005', 'cash', 'operating'
)->>'code', 'approvalRequired', 'negative policy returns approvalRequired');

reset role;
insert into public.financial_period_closures
  (business_id, from_date, to_date)
values ('20000000-0000-4000-8000-000000000001', current_date, current_date);
set local role authenticated;
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000017', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Closed', 1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'period.closed', 'closed period is rejected');
reset role;
delete from public.financial_period_closures;

set local role authenticated;
select set_config('phase_108j.inject_failure', 'after_expense', true);
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000018', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Injected expense', 1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'transactionFailure', 'failure after expense rolls back');
select set_config('phase_108j.inject_failure', 'after_ledger', true);
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000019', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Injected ledger', 1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'transactionFailure', 'failure after ledger rolls back');
select set_config(
  'phase_108j.inject_failure', 'before_receipt_completion', true
);
select is(public.post_expense_v1(
  '50000000-0000-4000-8000-000000000020', 1,
  '20000000-0000-4000-8000-000000000001', current_date::text,
  'Injected receipt', 1, null,
  '30000000-0000-4000-8000-000000000001', 'cash', 'operating'
)->>'code', 'transactionFailure', 'failure before receipt completion rolls back');
select set_config('phase_108j.inject_failure', '', true);

select throws_ok(
  $$insert into public.expenses (
      business_id, command_id, business_date, category, amount_qirsh,
      financial_account_id, payment_method, accounting_classification,
      created_by_auth_user_id
    ) values (
      '20000000-0000-4000-8000-000000000001',
      '59999999-0000-4000-8000-000000000099', current_date, 'Direct', 1,
      '30000000-0000-4000-8000-000000000001', 'cash', 'operating',
      '10000000-0000-4000-8000-000000000001'
    )$$,
  '42501', null, 'authenticated direct expense writes are denied'
);
select throws_ok(
  $$update public.financial_accounts set is_active = false$$,
  '42501', null, 'authenticated direct account updates are denied'
);
select throws_ok(
  $$delete from public.audit_events$$,
  '42501', null, 'authenticated direct audit deletes are denied'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000004', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004"}', true
);
select is((select count(*) from public.financial_accounts
  where business_id = '20000000-0000-4000-8000-000000000002'), 0::bigint,
  'membership-scoped reads hide another business');
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000003', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003"}', true
);
select is((select count(*) from public.financial_accounts), 0::bigint,
  'caller without membership reads no accounts through RLS');

reset role;
select is((select count(*) from public.expenses where command_id in (
  '50000000-0000-4000-8000-000000000018',
  '50000000-0000-4000-8000-000000000019',
  '50000000-0000-4000-8000-000000000020'
)), 0::bigint, 'injected failures leave no expenses');
select is((select count(*) from public.financial_command_receipts where
  command_id in (
    '50000000-0000-4000-8000-000000000018',
    '50000000-0000-4000-8000-000000000019',
    '50000000-0000-4000-8000-000000000020'
  )), 0::bigint, 'injected failures leave no receipts');
select is((select count(*) from public.audit_events where command_id in (
  '50000000-0000-4000-8000-000000000018',
  '50000000-0000-4000-8000-000000000019',
  '50000000-0000-4000-8000-000000000020'
)), 0::bigint, 'injected failures leave no audits');

select * from finish();
rollback;
