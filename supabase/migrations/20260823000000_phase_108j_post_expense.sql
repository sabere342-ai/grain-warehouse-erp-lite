-- Phase 108J: one atomic, idempotent, server-authoritative PostExpense slice.
-- This migration intentionally contains no generic sync, journal, inventory,
-- sale, purchase, approval-workflow, Realtime, Storage, or Edge Function work.

create extension if not exists pgcrypto with schema extensions;

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp()
);

create table public.business_memberships (
  business_id uuid not null references public.businesses(id),
  auth_user_id uuid not null references auth.users(id),
  role text not null check (role in ('owner', 'employee', 'viewer')),
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  primary key (business_id, auth_user_id)
);

create index business_memberships_auth_active_idx
  on public.business_memberships (auth_user_id, is_active, business_id);

create table public.financial_accounts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  legacy_local_account_id text,
  name text not null check (btrim(name) <> ''),
  account_type text not null
    check (account_type in ('treasury', 'bank', 'electronicWallet')),
  is_active boolean not null default true,
  allow_negative_balance boolean not null default false,
  is_cloud_ready boolean not null default false,
  reconciled_at timestamptz,
  reconciliation_version integer not null default 0
    check (reconciliation_version >= 0),
  created_at timestamptz not null default clock_timestamp(),
  unique (business_id, legacy_local_account_id)
);

create index financial_accounts_business_active_idx
  on public.financial_accounts (business_id, is_active, id);

create table public.financial_period_closures (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  from_date date not null,
  to_date date not null,
  accepted_at timestamptz not null default clock_timestamp(),
  reopened_at timestamptz,
  check (from_date <= to_date)
);

create index financial_period_closures_lookup_idx
  on public.financial_period_closures
  (business_id, from_date, to_date)
  where reopened_at is null;

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  command_id uuid not null,
  business_date date not null,
  category text not null check (btrim(category) <> ''),
  amount_qirsh bigint not null check (amount_qirsh > 0),
  notes text,
  financial_account_id uuid not null references public.financial_accounts(id),
  payment_method text not null
    check (payment_method in ('cash', 'bankTransfer', 'mobileWallet')),
  accounting_classification text not null
    check (accounting_classification in ('operating', 'capital', 'nonOperating')),
  created_by_auth_user_id uuid not null references auth.users(id),
  accepted_at timestamptz not null default clock_timestamp(),
  unique (business_id, command_id)
);

create index expenses_business_date_idx
  on public.expenses (business_id, business_date desc, accepted_at desc, id);

create table public.financial_account_entries (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  financial_account_id uuid not null references public.financial_accounts(id),
  direction text not null check (direction in ('inflow', 'outflow')),
  amount_qirsh bigint not null check (amount_qirsh > 0),
  source_type text not null check (source_type in ('openingBalance', 'expense')),
  source_document_id uuid not null,
  effective_date date not null,
  payment_method text
    check (payment_method is null or payment_method in
      ('cash', 'bankTransfer', 'mobileWallet')),
  created_by_auth_user_id uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (business_id, source_type, source_document_id)
);

create index financial_account_entries_balance_idx
  on public.financial_account_entries
  (business_id, financial_account_id, effective_date, created_at, id);

create table public.financial_command_receipts (
  business_id uuid not null references public.businesses(id),
  command_type text not null check (command_type = 'post_expense'),
  command_id uuid not null,
  actor_auth_user_id uuid not null references auth.users(id),
  fingerprint text not null check (length(fingerprint) = 64),
  status text not null check (status in ('reserved', 'completed')),
  canonical_result_json jsonb,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  primary key (business_id, command_type, command_id),
  unique (command_type, command_id),
  check (
    (status = 'reserved' and canonical_result_json is null and completed_at is null)
    or
    (status = 'completed' and canonical_result_json is not null and completed_at is not null)
  )
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  action_type text not null
    check (action_type in ('financial_account.entry.created', 'expense.created')),
  actor_auth_user_id uuid not null references auth.users(id),
  reference_id uuid not null,
  command_id uuid not null,
  metadata jsonb not null,
  occurred_at timestamptz not null default clock_timestamp(),
  unique (business_id, action_type, command_id)
);

alter table public.businesses enable row level security;
alter table public.business_memberships enable row level security;
alter table public.financial_accounts enable row level security;
alter table public.financial_period_closures enable row level security;
alter table public.expenses enable row level security;
alter table public.financial_account_entries enable row level security;
alter table public.financial_command_receipts enable row level security;
alter table public.audit_events enable row level security;

create policy businesses_member_read on public.businesses
  for select to authenticated
  using (
    is_active and exists (
      select 1 from public.business_memberships membership
      where membership.business_id = businesses.id
        and membership.auth_user_id = auth.uid()
        and membership.is_active
    )
  );

create policy memberships_self_read on public.business_memberships
  for select to authenticated
  using (auth_user_id = auth.uid());

create policy financial_accounts_member_read on public.financial_accounts
  for select to authenticated
  using (exists (
    select 1 from public.business_memberships membership
    where membership.business_id = financial_accounts.business_id
      and membership.auth_user_id = auth.uid()
      and membership.is_active
  ));

create policy period_closures_member_read on public.financial_period_closures
  for select to authenticated
  using (exists (
    select 1 from public.business_memberships membership
    where membership.business_id = financial_period_closures.business_id
      and membership.auth_user_id = auth.uid()
      and membership.is_active
  ));

create policy expenses_member_read on public.expenses
  for select to authenticated
  using (exists (
    select 1 from public.business_memberships membership
    where membership.business_id = expenses.business_id
      and membership.auth_user_id = auth.uid()
      and membership.is_active
  ));

create policy financial_entries_member_read
  on public.financial_account_entries
  for select to authenticated
  using (exists (
    select 1 from public.business_memberships membership
    where membership.business_id = financial_account_entries.business_id
      and membership.auth_user_id = auth.uid()
      and membership.is_active
  ));

create policy receipts_actor_read on public.financial_command_receipts
  for select to authenticated
  using (
    actor_auth_user_id = auth.uid()
    and exists (
      select 1 from public.business_memberships membership
      where membership.business_id = financial_command_receipts.business_id
        and membership.auth_user_id = auth.uid()
        and membership.is_active
    )
  );

create policy audit_events_member_read on public.audit_events
  for select to authenticated
  using (exists (
    select 1 from public.business_memberships membership
    where membership.business_id = audit_events.business_id
      and membership.auth_user_id = auth.uid()
      and membership.is_active
  ));

revoke all on table public.businesses from public, anon, authenticated;
revoke all on table public.business_memberships from public, anon, authenticated;
revoke all on table public.financial_accounts from public, anon, authenticated;
revoke all on table public.financial_period_closures from public, anon, authenticated;
revoke all on table public.expenses from public, anon, authenticated;
revoke all on table public.financial_account_entries from public, anon, authenticated;
revoke all on table public.financial_command_receipts from public, anon, authenticated;
revoke all on table public.audit_events from public, anon, authenticated;

grant select on table public.businesses to authenticated;
grant select on table public.business_memberships to authenticated;
grant select on table public.financial_accounts to authenticated;
grant select on table public.financial_period_closures to authenticated;
grant select on table public.expenses to authenticated;
grant select on table public.financial_account_entries to authenticated;
grant select on table public.financial_command_receipts to authenticated;
grant select on table public.audit_events to authenticated;

create or replace function public.post_expense_v1(
  p_command_id text,
  p_schema_version integer,
  p_business_id text,
  p_business_date text,
  p_category text,
  p_amount_qirsh bigint,
  p_notes text,
  p_financial_account_id text,
  p_payment_method text,
  p_accounting_classification text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, extensions
as $$
declare
  v_actor uuid := auth.uid();
  v_command_id uuid;
  v_business_id uuid;
  v_account_id uuid;
  v_business_date date;
  v_business_date_is_valid boolean := false;
  v_category text := btrim(coalesce(p_category, ''));
  v_notes text := nullif(btrim(coalesce(p_notes, '')), '');
  v_fingerprint text;
  v_receipt public.financial_command_receipts%rowtype;
  v_account public.financial_accounts%rowtype;
  v_inserted integer;
  v_balance_before bigint;
  v_balance_after bigint;
  v_expense_id uuid;
  v_entry_id uuid;
  v_account_audit_id uuid;
  v_expense_audit_id uuid;
  v_accepted_at timestamptz;
  v_result jsonb;
  v_inject_failure text;
begin
  if v_actor is null then
    return jsonb_build_object(
      'ok', false,
      'category', 'authentication',
      'code', 'unauthenticated.sessionRequired',
      'retryable', false
    );
  end if;

  if p_business_date is not null
     and p_business_date ~ '^\d{4}-\d{2}-\d{2}$' then
    begin
      v_business_date := p_business_date::date;
      v_business_date_is_valid :=
        to_char(v_business_date, 'YYYY-MM-DD') = p_business_date;
    exception
      when invalid_datetime_format or datetime_field_overflow then
        v_business_date_is_valid := false;
    end;
  end if;

  if p_schema_version is distinct from 1
     or p_command_id is null
     or p_business_id is null
     or p_financial_account_id is null
     or p_command_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or p_business_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or p_financial_account_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or not v_business_date_is_valid
     or v_category = ''
     or p_amount_qirsh is null
     or p_amount_qirsh <= 0
     or p_payment_method is null
     or p_payment_method not in ('cash', 'bankTransfer', 'mobileWallet')
     or p_accounting_classification is null
     or p_accounting_classification not in ('operating', 'capital', 'nonOperating') then
    return jsonb_build_object(
      'ok', false,
      'category', 'validation',
      'code', 'validation.invalidField',
      'retryable', false
    );
  end if;

  v_command_id := p_command_id::uuid;
  v_business_id := p_business_id::uuid;
  v_account_id := p_financial_account_id::uuid;

  if v_business_date > current_date then
    return jsonb_build_object(
      'ok', false,
      'category', 'validation',
      'code', 'validation.invalidField',
      'retryable', false,
      'fieldErrors', jsonb_build_object('businessDate', 'futureDate')
    );
  end if;

  if not exists (
    select 1 from public.business_memberships membership
    join public.businesses business on business.id = membership.business_id
    where membership.business_id = v_business_id
      and membership.auth_user_id = v_actor
      and membership.is_active
      and membership.role in ('owner', 'employee')
      and business.is_active
  ) then
    return jsonb_build_object(
      'ok', false,
      'category', 'authorization',
      'code', 'unauthorized.expensePostingDenied',
      'retryable', false
    );
  end if;

  v_fingerprint := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'accountingClassification', p_accounting_classification,
          'actorAuthUserId', v_actor::text,
          'amountQirsh', p_amount_qirsh,
          'businessDate', p_business_date,
          'businessId', v_business_id::text,
          'category', v_category,
          'commandType', 'post_expense',
          'financialAccountId', v_account_id::text,
          'notes', v_notes,
          'paymentMethod', p_payment_method,
          'schemaVersion', p_schema_version
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  select * into v_receipt
  from public.financial_command_receipts receipt
  where receipt.command_type = 'post_expense'
    and receipt.command_id = v_command_id;

  if found then
    if v_receipt.business_id <> v_business_id
       or v_receipt.actor_auth_user_id <> v_actor
       or v_receipt.fingerprint <> v_fingerprint
       or v_receipt.status <> 'completed'
       or v_receipt.canonical_result_json is null then
      return jsonb_build_object(
        'ok', false,
        'category', 'idempotency',
        'code', 'idempotencyConflict',
        'retryable', false
      );
    end if;
    return jsonb_set(v_receipt.canonical_result_json, '{replayed}', 'true'::jsonb);
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
    'post_expense',
    v_command_id,
    v_actor,
    v_fingerprint,
    'reserved'
  ) on conflict (command_type, command_id) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    select * into v_receipt
    from public.financial_command_receipts receipt
    where receipt.command_type = 'post_expense'
      and receipt.command_id = v_command_id;
    if v_receipt.business_id = v_business_id
       and v_receipt.actor_auth_user_id = v_actor
       and v_receipt.fingerprint = v_fingerprint
       and v_receipt.status = 'completed'
       and v_receipt.canonical_result_json is not null then
      return jsonb_set(v_receipt.canonical_result_json, '{replayed}', 'true'::jsonb);
    end if;
    return jsonb_build_object(
      'ok', false,
      'category', 'idempotency',
      'code', 'idempotencyConflict',
      'retryable', false
    );
  end if;

  begin
    select * into v_account
    from public.financial_accounts account
    where account.id = v_account_id
    for update;

    if not found then
      delete from public.financial_command_receipts
      where business_id = v_business_id
        and command_type = 'post_expense'
        and command_id = v_command_id;
      return jsonb_build_object(
        'ok', false,
        'category', 'account',
        'code', 'account.notFoundOrInactive',
        'retryable', false
      );
    end if;

    if v_account.business_id <> v_business_id then
      delete from public.financial_command_receipts
      where business_id = v_business_id
        and command_type = 'post_expense'
        and command_id = v_command_id;
      return jsonb_build_object(
        'ok', false,
        'category', 'businessContext',
        'code', 'wrongBusinessContext',
        'retryable', false
      );
    end if;

    if not v_account.is_active
       or not v_account.is_cloud_ready
       or v_account.reconciled_at is null
       or v_account.reconciliation_version <= 0 then
      delete from public.financial_command_receipts
      where business_id = v_business_id
        and command_type = 'post_expense'
        and command_id = v_command_id;
      return jsonb_build_object(
        'ok', false,
        'category', 'account',
        'code', 'account.notFoundOrInactive',
        'retryable', false
      );
    end if;

    if (p_payment_method = 'cash' and v_account.account_type <> 'treasury')
       or (p_payment_method = 'bankTransfer' and v_account.account_type <> 'bank')
       or (p_payment_method = 'mobileWallet'
           and v_account.account_type <> 'electronicWallet') then
      delete from public.financial_command_receipts
      where business_id = v_business_id
        and command_type = 'post_expense'
        and command_id = v_command_id;
      return jsonb_build_object(
        'ok', false,
        'category', 'paymentRoute',
        'code', 'paymentRoute.invalid',
        'retryable', false
      );
    end if;

    if exists (
      select 1 from public.financial_period_closures closure
      where closure.business_id = v_business_id
        and closure.reopened_at is null
        and v_business_date between closure.from_date and closure.to_date
    ) then
      delete from public.financial_command_receipts
      where business_id = v_business_id
        and command_type = 'post_expense'
        and command_id = v_command_id;
      return jsonb_build_object(
        'ok', false,
        'category', 'period',
        'code', 'period.closed',
        'retryable', false
      );
    end if;

    select coalesce(sum(
      case when entry.direction = 'inflow'
        then entry.amount_qirsh else -entry.amount_qirsh end
    ), 0) into v_balance_before
    from public.financial_account_entries entry
    where entry.business_id = v_business_id
      and entry.financial_account_id = v_account_id;

    v_balance_after := v_balance_before - p_amount_qirsh;
    if v_balance_after < 0 then
      delete from public.financial_command_receipts
      where business_id = v_business_id
        and command_type = 'post_expense'
        and command_id = v_command_id;
      if v_account.allow_negative_balance then
        return jsonb_build_object(
          'ok', false,
          'category', 'approval',
          'code', 'approvalRequired',
          'retryable', false
        );
      end if;
      return jsonb_build_object(
        'ok', false,
        'category', 'balance',
        'code', 'balance.insufficient',
        'retryable', false
      );
    end if;

    v_expense_id := gen_random_uuid();
    v_entry_id := gen_random_uuid();
    v_account_audit_id := gen_random_uuid();
    v_expense_audit_id := gen_random_uuid();
    v_accepted_at := clock_timestamp();
    v_inject_failure := current_setting('phase_108j.inject_failure', true);

    insert into public.expenses (
      id,
      business_id,
      command_id,
      business_date,
      category,
      amount_qirsh,
      notes,
      financial_account_id,
      payment_method,
      accounting_classification,
      created_by_auth_user_id,
      accepted_at
    ) values (
      v_expense_id,
      v_business_id,
      v_command_id,
      v_business_date,
      v_category,
      p_amount_qirsh,
      v_notes,
      v_account_id,
      p_payment_method,
      p_accounting_classification,
      v_actor,
      v_accepted_at
    );

    if v_inject_failure = 'after_expense' then
      raise exception using errcode = 'P0001', message = 'phase_108j_test_failure';
    end if;

    insert into public.financial_account_entries (
      id,
      business_id,
      financial_account_id,
      direction,
      amount_qirsh,
      source_type,
      source_document_id,
      effective_date,
      payment_method,
      created_by_auth_user_id,
      created_at
    ) values (
      v_entry_id,
      v_business_id,
      v_account_id,
      'outflow',
      p_amount_qirsh,
      'expense',
      v_expense_id,
      v_business_date,
      p_payment_method,
      v_actor,
      v_accepted_at
    );

    if v_inject_failure = 'after_ledger' then
      raise exception using errcode = 'P0001', message = 'phase_108j_test_failure';
    end if;

    insert into public.audit_events (
      id,
      business_id,
      action_type,
      actor_auth_user_id,
      reference_id,
      command_id,
      metadata,
      occurred_at
    ) values
    (
      v_account_audit_id,
      v_business_id,
      'financial_account.entry.created',
      v_actor,
      v_entry_id,
      v_command_id,
      jsonb_build_object(
        'businessId', v_business_id,
        'commandId', v_command_id,
        'expenseId', v_expense_id,
        'financialAccountId', v_account_id,
        'financialEntryId', v_entry_id
      ),
      v_accepted_at
    ),
    (
      v_expense_audit_id,
      v_business_id,
      'expense.created',
      v_actor,
      v_expense_id,
      v_command_id,
      jsonb_build_object(
        'businessId', v_business_id,
        'commandId', v_command_id,
        'expenseId', v_expense_id,
        'financialAccountId', v_account_id,
        'financialEntryId', v_entry_id
      ),
      v_accepted_at
    );

    if v_inject_failure = 'before_receipt_completion' then
      raise exception using errcode = 'P0001', message = 'phase_108j_test_failure';
    end if;

    v_result := jsonb_build_object(
      'ok', true,
      'commandId', v_command_id::text,
      'businessId', v_business_id::text,
      'expenseId', v_expense_id::text,
      'financialEntryId', v_entry_id::text,
      'auditEventIds', jsonb_build_array(
        v_account_audit_id::text,
        v_expense_audit_id::text
      ),
      'serverAcceptedAtUtc', to_char(
        v_accepted_at at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
      ),
      'businessDate', to_char(v_business_date, 'YYYY-MM-DD'),
      'amountQirsh', p_amount_qirsh,
      'balanceAfterQirsh', v_balance_after,
      'replayed', false
    );

    update public.financial_command_receipts
    set status = 'completed',
        canonical_result_json = v_result,
        completed_at = v_accepted_at
    where business_id = v_business_id
      and command_type = 'post_expense'
      and command_id = v_command_id;

    return v_result;
  exception when others then
    delete from public.financial_command_receipts
    where business_id = v_business_id
      and command_type = 'post_expense'
      and command_id = v_command_id;
    return jsonb_build_object(
      'ok', false,
      'category', 'transaction',
      'code', 'transactionFailure',
      'retryable', true,
      'diagnosticReference', sqlstate
    );
  end;
end;
$$;

revoke all on function public.post_expense_v1(
  text, integer, text, text, text, bigint, text, text, text, text
) from public, anon;
grant execute on function public.post_expense_v1(
  text, integer, text, text, text, bigint, text, text, text, text
) to authenticated;
