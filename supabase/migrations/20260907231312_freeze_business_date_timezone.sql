-- Phase 108E is deliberately function-only. Rebuild the two existing
-- implementations from their installed definitions and replace only the
-- future-date clock expression. Signatures, security, grants, tables, and
-- successful result envelopes remain unchanged.
do $phase108e$
declare
  v_expense_definition text;
  v_expense_rewritten text;
  v_transfer_definition text;
  v_transfer_rewritten text;
begin
  select pg_catalog.pg_get_functiondef(
    'public.post_expense_v1(text,integer,text,text,text,bigint,text,text,text,text)'
      ::pg_catalog.regprocedure
  ) into strict v_expense_definition;

  v_expense_rewritten := pg_catalog.replace(
    v_expense_definition,
    'if v_business_date > current_date then',
    'if v_business_date > ' ||
      'pg_catalog.timezone(''Africa/Cairo'', ' ||
      'pg_catalog.clock_timestamp())::date then'
  );
  if v_expense_rewritten = v_expense_definition then
    raise exception 'Phase108E expense date predicate was not found';
  end if;
  execute v_expense_rewritten;

  select pg_catalog.pg_get_functiondef(
    'private.post_internal_transfer_v1(text,integer,text,text,text,bigint,text,text,text)'
      ::pg_catalog.regprocedure
  ) into strict v_transfer_definition;

  v_transfer_rewritten := pg_catalog.replace(
    v_transfer_definition,
    '(pg_catalog.clock_timestamp() at time zone ''Africa/Cairo'')::date',
    'pg_catalog.timezone(''Africa/Cairo'', ' ||
      'pg_catalog.clock_timestamp())::date'
  );
  if v_transfer_rewritten = v_transfer_definition then
    raise exception 'Phase108E transfer date predicate was not found';
  end if;
  execute v_transfer_rewritten;
end;
$phase108e$;
