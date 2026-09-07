-- Server-authoritative Internal Transfer only. This migration is additive
-- except for narrow check/unique constraint replacements required to admit the
-- new receipt, ledger source, and three-audit command contract.

create schema if not exists private;
revoke all on schema private from public, anon;

alter table public.financial_account_entries
  drop constraint financial_account_entries_source_type_check;
alter table public.financial_account_entries
  add constraint financial_account_entries_source_type_check
  check (source_type in (
    'openingBalance', 'expense', 'transferOut', 'transferIn'
  ));

alter table public.financial_command_receipts
  drop constraint financial_command_receipts_command_type_check;
alter table public.financial_command_receipts
  add constraint financial_command_receipts_command_type_check
  check (command_type in ('post_expense', 'post_internal_transfer'));

alter table public.audit_events
  drop constraint audit_events_action_type_check;
alter table public.audit_events
  add constraint audit_events_action_type_check
  check (action_type in (
    'financial_account.entry.created',
    'expense.created',
    'financial_transfer.created'
  ));

alter table public.audit_events
  drop constraint audit_events_business_id_action_type_command_id_key;
alter table public.audit_events
  add constraint audit_events_business_action_command_reference_key
  unique (business_id, action_type, command_id, reference_id);

create table private.financial_transfer_number_counters (
  business_id uuid primary key references public.businesses(id),
  next_number bigint not null default 1 check (next_number > 0)
);

alter table private.financial_transfer_number_counters
  enable row level security;
revoke all on table private.financial_transfer_number_counters
  from public, anon, authenticated;

create table public.financial_transfers (
  id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  command_id uuid not null,
  source_financial_account_id uuid not null
    references public.financial_accounts(id),
  destination_financial_account_id uuid not null
    references public.financial_accounts(id),
  amount_qirsh bigint not null check (amount_qirsh > 0),
  effective_business_date date not null,
  transfer_reference uuid not null,
  display_sequence bigint not null check (display_sequence > 0),
  display_number text not null check (display_number ~ '^TR-[0-9]{6,}$'),
  note text,
  created_by_auth_user_id uuid not null references auth.users(id),
  accepted_at timestamptz not null,
  source_entry_id uuid not null references public.financial_account_entries(id),
  destination_entry_id uuid not null
    references public.financial_account_entries(id),
  check (source_financial_account_id <> destination_financial_account_id),
  check (source_entry_id <> destination_entry_id),
  unique (business_id, command_id),
  unique (business_id, transfer_reference),
  unique (business_id, display_sequence),
  unique (business_id, display_number),
  unique (source_entry_id),
  unique (destination_entry_id)
);

create index financial_transfers_business_date_idx
  on public.financial_transfers
  (business_id, effective_business_date desc, accepted_at desc, id);
create index financial_transfers_source_date_idx
  on public.financial_transfers
  (business_id, source_financial_account_id, effective_business_date desc, id);
create index financial_transfers_destination_date_idx
  on public.financial_transfers
  (business_id, destination_financial_account_id,
   effective_business_date desc, id);

alter table public.financial_transfers enable row level security;
create policy financial_transfers_member_read
  on public.financial_transfers
  for select to authenticated
  using (
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.business_memberships membership
      where membership.business_id = financial_transfers.business_id
        and membership.auth_user_id = (select auth.uid())
        and membership.is_active
    )
  );

revoke all on table public.financial_transfers
  from public, anon, authenticated;
grant select on table public.financial_transfers to authenticated;

create or replace function private.post_internal_transfer_v1(
  p_command_id text,
  p_schema_version integer,
  p_business_id text,
  p_source_financial_account_id text,
  p_destination_financial_account_id text,
  p_amount_qirsh bigint,
  p_effective_business_date text,
  p_transfer_reference text,
  p_note text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_command_id uuid;
  v_business_id uuid;
  v_source_id uuid;
  v_destination_id uuid;
  v_first_id uuid;
  v_second_id uuid;
  v_reference uuid;
  v_effective_date date;
  v_effective_date_is_valid boolean := false;
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_business public.businesses%rowtype;
  v_membership public.business_memberships%rowtype;
  v_first_account public.financial_accounts%rowtype;
  v_second_account public.financial_accounts%rowtype;
  v_source_account public.financial_accounts%rowtype;
  v_destination_account public.financial_accounts%rowtype;
  v_receipt public.financial_command_receipts%rowtype;
  v_fingerprint text;
  v_inserted integer;
  v_source_balance_before bigint;
  v_destination_balance_before bigint;
  v_source_balance_after bigint;
  v_destination_balance_after bigint;
  v_display_sequence bigint;
  v_display_number text;
  v_transfer_id uuid;
  v_source_entry_id uuid;
  v_destination_entry_id uuid;
  v_source_audit_id uuid;
  v_destination_audit_id uuid;
  v_transfer_audit_id uuid;
  v_accepted_at timestamptz;
  v_result jsonb;
  v_inject_failure text;
begin
  if v_actor is null then
    return pg_catalog.jsonb_build_object(
      'ok', false,
      'category', 'authentication',
      'code', 'unauthenticated.sessionRequired',
      'retryable', false
    );
  end if;

  if p_effective_business_date is not null
     and p_effective_business_date ~ '^\d{4}-\d{2}-\d{2}$' then
    begin
      v_effective_date := p_effective_business_date::date;
      v_effective_date_is_valid :=
        pg_catalog.to_char(v_effective_date, 'YYYY-MM-DD') =
          p_effective_business_date;
    exception
      when invalid_datetime_format or datetime_field_overflow then
        v_effective_date_is_valid := false;
    end;
  end if;

  if p_schema_version is distinct from 1
     or p_command_id is null
     or p_business_id is null
     or p_source_financial_account_id is null
     or p_destination_financial_account_id is null
     or p_transfer_reference is null
     or p_command_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or p_business_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or p_source_financial_account_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or p_destination_financial_account_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or p_transfer_reference !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or not v_effective_date_is_valid
     or p_amount_qirsh is null
     or p_amount_qirsh <= 0 then
    return pg_catalog.jsonb_build_object(
      'ok', false,
      'category', 'validation',
      'code', 'validation.invalidField',
      'retryable', false
    );
  end if;

  v_command_id := p_command_id::uuid;
  v_business_id := p_business_id::uuid;
  v_source_id := p_source_financial_account_id::uuid;
  v_destination_id := p_destination_financial_account_id::uuid;
  v_reference := p_transfer_reference::uuid;

  if v_source_id = v_destination_id then
    return pg_catalog.jsonb_build_object(
      'ok', false,
      'category', 'validation',
      'code', 'validation.sameAccount',
      'retryable', false
    );
  end if;
  if v_effective_date >
      (pg_catalog.clock_timestamp() at time zone 'Africa/Cairo')::date then
    return pg_catalog.jsonb_build_object(
      'ok', false,
      'category', 'validation',
      'code', 'validation.invalidField',
      'retryable', false,
      'fieldErrors', pg_catalog.jsonb_build_object(
        'effectiveBusinessDate', 'futureDate'
      )
    );
  end if;

  select * into v_business
  from public.businesses business
  where business.id = v_business_id
  for share;
  select * into v_membership
  from public.business_memberships membership
  where membership.business_id = v_business_id
    and membership.auth_user_id = v_actor
  for share;
  if v_business.id is null
     or not v_business.is_active
     or v_membership.business_id is null
     or not v_membership.is_active
     or v_membership.role <> 'owner' then
    return pg_catalog.jsonb_build_object(
      'ok', false,
      'category', 'authorization',
      'code', 'unauthorized.internalTransferDenied',
      'retryable', false
    );
  end if;

  v_fingerprint := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(
        pg_catalog.jsonb_build_object(
          'actorAuthUserId', v_actor::text,
          'amountQirsh', p_amount_qirsh,
          'businessId', v_business_id::text,
          'commandType', 'post_internal_transfer',
          'destinationFinancialAccountId', v_destination_id::text,
          'effectiveBusinessDate', p_effective_business_date,
          'note', v_note,
          'schemaVersion', p_schema_version,
          'sourceFinancialAccountId', v_source_id::text,
          'transferReference', v_reference::text
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  select * into v_receipt
  from public.financial_command_receipts receipt
  where receipt.command_type = 'post_internal_transfer'
    and receipt.command_id = v_command_id;
  if found then
    if v_receipt.business_id <> v_business_id
       or v_receipt.actor_auth_user_id <> v_actor
       or v_receipt.fingerprint <> v_fingerprint
       or v_receipt.status <> 'completed'
       or v_receipt.canonical_result_json is null then
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'idempotency',
        'code', 'idempotencyConflict',
        'retryable', false
      );
    end if;
    return pg_catalog.jsonb_set(
      v_receipt.canonical_result_json,
      '{replayed}',
      'true'::jsonb
    );
  end if;

  insert into public.financial_command_receipts (
    business_id,
    command_type,
    command_id,
    actor_auth_user_id,
    fingerprint,
    status
  ) values (
    v_business_id,
    'post_internal_transfer',
    v_command_id,
    v_actor,
    v_fingerprint,
    'reserved'
  ) on conflict (command_type, command_id) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    select * into v_receipt
    from public.financial_command_receipts receipt
    where receipt.command_type = 'post_internal_transfer'
      and receipt.command_id = v_command_id;
    if v_receipt.business_id = v_business_id
       and v_receipt.actor_auth_user_id = v_actor
       and v_receipt.fingerprint = v_fingerprint
       and v_receipt.status = 'completed'
       and v_receipt.canonical_result_json is not null then
      return pg_catalog.jsonb_set(
        v_receipt.canonical_result_json,
        '{replayed}',
        'true'::jsonb
      );
    end if;
    return pg_catalog.jsonb_build_object(
      'ok', false,
      'category', 'idempotency',
      'code', 'idempotencyConflict',
      'retryable', false
    );
  end if;

  begin
    v_first_id := least(v_source_id, v_destination_id);
    v_second_id := greatest(v_source_id, v_destination_id);
    select * into v_first_account
    from public.financial_accounts account
    where account.id = v_first_id
    for update;
    select * into v_second_account
    from public.financial_accounts account
    where account.id = v_second_id
    for update;
    if v_source_id = v_first_id then
      v_source_account := v_first_account;
      v_destination_account := v_second_account;
    else
      v_source_account := v_second_account;
      v_destination_account := v_first_account;
    end if;

    if v_source_account.id is null then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'account',
        'code', 'sourceAccount.notFoundOrInactive',
        'retryable', false
      );
    end if;
    if v_destination_account.id is null then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'account',
        'code', 'destinationAccount.notFoundOrInactive',
        'retryable', false
      );
    end if;
    if v_source_account.business_id <> v_business_id
       or v_destination_account.business_id <> v_business_id then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'businessContext',
        'code', 'wrongBusinessContext',
        'retryable', false
      );
    end if;
    if not v_source_account.is_active
       or not v_source_account.is_cloud_ready
       or v_source_account.reconciled_at is null
       or v_source_account.reconciliation_version <= 0
       or v_source_account.account_type not in (
         'treasury', 'bank', 'electronicWallet'
       ) then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'account',
        'code', 'sourceAccount.notFoundOrInactive',
        'retryable', false
      );
    end if;
    if not v_destination_account.is_active
       or not v_destination_account.is_cloud_ready
       or v_destination_account.reconciled_at is null
       or v_destination_account.reconciliation_version <= 0
       or v_destination_account.account_type not in (
         'treasury', 'bank', 'electronicWallet'
       ) then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'account',
        'code', 'destinationAccount.notFoundOrInactive',
        'retryable', false
      );
    end if;
    if exists (
      select 1
      from public.financial_period_closures closure
      where closure.business_id = v_business_id
        and closure.reopened_at is null
        and v_effective_date between closure.from_date and closure.to_date
    ) then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'period',
        'code', 'period.closed',
        'retryable', false
      );
    end if;
    if exists (
      select 1
      from public.financial_transfers transfer
      where transfer.business_id = v_business_id
        and transfer.transfer_reference = v_reference
    ) then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'idempotency',
        'code', 'transferReference.conflict',
        'retryable', false
      );
    end if;

    select coalesce(pg_catalog.sum(
      case when entry.direction = 'inflow'
        then entry.amount_qirsh else -entry.amount_qirsh end
    ), 0) into v_source_balance_before
    from public.financial_account_entries entry
    where entry.business_id = v_business_id
      and entry.financial_account_id = v_source_id;
    select coalesce(pg_catalog.sum(
      case when entry.direction = 'inflow'
        then entry.amount_qirsh else -entry.amount_qirsh end
    ), 0) into v_destination_balance_before
    from public.financial_account_entries entry
    where entry.business_id = v_business_id
      and entry.financial_account_id = v_destination_id;
    if v_source_balance_before < p_amount_qirsh then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'balance',
        'code', 'balance.insufficient',
        'retryable', false
      );
    end if;
    v_source_balance_after := v_source_balance_before - p_amount_qirsh;
    v_destination_balance_after :=
      v_destination_balance_before + p_amount_qirsh;

    insert into private.financial_transfer_number_counters (
      business_id,
      next_number
    ) values (v_business_id, 1)
    on conflict (business_id) do nothing;
    select counter.next_number into v_display_sequence
    from private.financial_transfer_number_counters counter
    where counter.business_id = v_business_id
    for update;
    v_display_number := 'TR-' ||
      pg_catalog.lpad(v_display_sequence::text, 6, '0');
    update private.financial_transfer_number_counters
    set next_number = next_number + 1
    where business_id = v_business_id;

    v_transfer_id := extensions.gen_random_uuid();
    v_source_entry_id := extensions.gen_random_uuid();
    v_destination_entry_id := extensions.gen_random_uuid();
    v_source_audit_id := extensions.gen_random_uuid();
    v_destination_audit_id := extensions.gen_random_uuid();
    v_transfer_audit_id := extensions.gen_random_uuid();
    v_accepted_at := pg_catalog.clock_timestamp();
    v_inject_failure :=
      pg_catalog.current_setting('internal_transfer.inject_failure', true);

    if v_inject_failure = 'after_receipt_reserve' then
      raise exception using errcode = 'P0001',
        message = 'internal_transfer_test_failure';
    end if;

    insert into public.financial_account_entries (
      id, business_id, financial_account_id, direction, amount_qirsh,
      source_type, source_document_id, effective_date, payment_method,
      created_by_auth_user_id, created_at
    ) values (
      v_source_entry_id, v_business_id, v_source_id, 'outflow',
      p_amount_qirsh, 'transferOut', v_transfer_id, v_effective_date, null,
      v_actor, v_accepted_at
    );
    if v_inject_failure = 'after_source_entry' then
      raise exception using errcode = 'P0001',
        message = 'internal_transfer_test_failure';
    end if;
    insert into public.financial_account_entries (
      id, business_id, financial_account_id, direction, amount_qirsh,
      source_type, source_document_id, effective_date, payment_method,
      created_by_auth_user_id, created_at
    ) values (
      v_destination_entry_id, v_business_id, v_destination_id, 'inflow',
      p_amount_qirsh, 'transferIn', v_transfer_id, v_effective_date, null,
      v_actor, v_accepted_at
    );
    if v_inject_failure = 'after_destination_entry' then
      raise exception using errcode = 'P0001',
        message = 'internal_transfer_test_failure';
    end if;

    insert into public.financial_transfers (
      id, business_id, command_id, source_financial_account_id,
      destination_financial_account_id, amount_qirsh,
      effective_business_date, transfer_reference, display_sequence,
      display_number, note, created_by_auth_user_id, accepted_at,
      source_entry_id, destination_entry_id
    ) values (
      v_transfer_id, v_business_id, v_command_id, v_source_id,
      v_destination_id, p_amount_qirsh, v_effective_date, v_reference,
      v_display_sequence, v_display_number, v_note, v_actor, v_accepted_at,
      v_source_entry_id, v_destination_entry_id
    );
    if v_inject_failure = 'after_header' then
      raise exception using errcode = 'P0001',
        message = 'internal_transfer_test_failure';
    end if;

    insert into public.audit_events (
      id, business_id, action_type, actor_auth_user_id, reference_id,
      command_id, metadata, occurred_at
    ) values
    (
      v_source_audit_id, v_business_id,
      'financial_account.entry.created', v_actor, v_source_entry_id,
      v_command_id,
      pg_catalog.jsonb_build_object(
        'businessId', v_business_id,
        'commandId', v_command_id,
        'transferId', v_transfer_id,
        'displayNumber', v_display_number,
        'transferReference', v_reference,
        'sourceFinancialAccountId', v_source_id,
        'destinationFinancialAccountId', v_destination_id,
        'sourceFinancialEntryId', v_source_entry_id,
        'destinationFinancialEntryId', v_destination_entry_id,
        'amountQirsh', p_amount_qirsh,
        'effectiveBusinessDate', v_effective_date,
        'serverAcceptedAtUtc', v_accepted_at
      ),
      v_accepted_at
    ),
    (
      v_destination_audit_id, v_business_id,
      'financial_account.entry.created', v_actor, v_destination_entry_id,
      v_command_id,
      pg_catalog.jsonb_build_object(
        'businessId', v_business_id,
        'commandId', v_command_id,
        'transferId', v_transfer_id,
        'displayNumber', v_display_number,
        'transferReference', v_reference,
        'sourceFinancialAccountId', v_source_id,
        'destinationFinancialAccountId', v_destination_id,
        'sourceFinancialEntryId', v_source_entry_id,
        'destinationFinancialEntryId', v_destination_entry_id,
        'amountQirsh', p_amount_qirsh,
        'effectiveBusinessDate', v_effective_date,
        'serverAcceptedAtUtc', v_accepted_at
      ),
      v_accepted_at
    ),
    (
      v_transfer_audit_id, v_business_id,
      'financial_transfer.created', v_actor, v_transfer_id,
      v_command_id,
      pg_catalog.jsonb_build_object(
        'businessId', v_business_id,
        'commandId', v_command_id,
        'transferId', v_transfer_id,
        'displayNumber', v_display_number,
        'transferReference', v_reference,
        'sourceFinancialAccountId', v_source_id,
        'destinationFinancialAccountId', v_destination_id,
        'sourceFinancialEntryId', v_source_entry_id,
        'destinationFinancialEntryId', v_destination_entry_id,
        'amountQirsh', p_amount_qirsh,
        'effectiveBusinessDate', v_effective_date,
        'serverAcceptedAtUtc', v_accepted_at
      ),
      v_accepted_at
    );
    if v_inject_failure = 'after_audits' then
      raise exception using errcode = 'P0001',
        message = 'internal_transfer_test_failure';
    end if;

    v_result := pg_catalog.jsonb_build_object(
      'ok', true,
      'commandId', v_command_id::text,
      'businessId', v_business_id::text,
      'transferId', v_transfer_id::text,
      'displayNumber', v_display_number,
      'transferReference', v_reference::text,
      'sourceFinancialAccountId', v_source_id::text,
      'destinationFinancialAccountId', v_destination_id::text,
      'sourceFinancialEntryId', v_source_entry_id::text,
      'destinationFinancialEntryId', v_destination_entry_id::text,
      'auditEventIds', pg_catalog.jsonb_build_array(
        v_source_audit_id::text,
        v_destination_audit_id::text,
        v_transfer_audit_id::text
      ),
      'effectiveBusinessDate',
        pg_catalog.to_char(v_effective_date, 'YYYY-MM-DD'),
      'amountQirsh', p_amount_qirsh,
      'sourceBalanceAfterQirsh', v_source_balance_after,
      'destinationBalanceAfterQirsh', v_destination_balance_after,
      'serverAcceptedAtUtc', pg_catalog.to_char(
        v_accepted_at at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
      ),
      'replayed', false
    );
    if v_inject_failure = 'before_receipt_completion' then
      raise exception using errcode = 'P0001',
        message = 'internal_transfer_test_failure';
    end if;
    update public.financial_command_receipts
    set status = 'completed',
        canonical_result_json = v_result,
        completed_at = v_accepted_at
    where command_type = 'post_internal_transfer'
      and command_id = v_command_id;
    return v_result;
  exception
    when unique_violation then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      if exists (
        select 1 from public.financial_transfers transfer
        where transfer.business_id = v_business_id
          and transfer.transfer_reference = v_reference
      ) then
        return pg_catalog.jsonb_build_object(
          'ok', false,
          'category', 'idempotency',
          'code', 'transferReference.conflict',
          'retryable', false
        );
      end if;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'transaction',
        'code', 'transactionFailure',
        'retryable', true,
        'diagnosticReference', sqlstate
      );
    when others then
      delete from public.financial_command_receipts
      where command_type = 'post_internal_transfer'
        and command_id = v_command_id;
      return pg_catalog.jsonb_build_object(
        'ok', false,
        'category', 'transaction',
        'code', 'transactionFailure',
        'retryable', true,
        'diagnosticReference', sqlstate
      );
  end;
end;
$$;

revoke all on function private.post_internal_transfer_v1(
  text, integer, text, text, text, bigint, text, text, text
) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.post_internal_transfer_v1(
  text, integer, text, text, text, bigint, text, text, text
) to authenticated;

create or replace function public.post_internal_transfer_v1(
  p_command_id text,
  p_schema_version integer,
  p_business_id text,
  p_source_financial_account_id text,
  p_destination_financial_account_id text,
  p_amount_qirsh bigint,
  p_effective_business_date text,
  p_transfer_reference text,
  p_note text
) returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.post_internal_transfer_v1(
    p_command_id,
    p_schema_version,
    p_business_id,
    p_source_financial_account_id,
    p_destination_financial_account_id,
    p_amount_qirsh,
    p_effective_business_date,
    p_transfer_reference,
    p_note
  )
$$;

revoke all on function public.post_internal_transfer_v1(
  text, integer, text, text, text, bigint, text, text, text
) from public, anon;
grant execute on function public.post_internal_transfer_v1(
  text, integer, text, text, text, bigint, text, text, text
) to authenticated;
