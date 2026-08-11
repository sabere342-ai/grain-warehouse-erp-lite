# Phase 108C — Transaction Boundary Audit

## Current mechanisms

- All production Drift adapters share `AppRepositories.database`.
- `FoundationDatabase.inTransaction` provides a real local SQLite transaction.
- `RepositoryTransaction` captures participant snapshots and rolls them back on
  a Dart exception; some adapters persist/hydrate in-memory delegates.
- Certain cross-repository operations are nested under a real database
  transaction (notably governed business wipe). Others coordinate snapshots
  while participant writes may each commit their own local transaction. That is
  useful local rollback behavior but is not a crash-safe distributed boundary.
- Future Cloud commands must replace this ambiguity with one server-side
  Postgres transaction and one idempotency result.

## Actual and required business boundaries

### Sale posting

```text
Operation: create sale
Current atomic boundary: sale row + stock movement + valuation/COGS in the sale
repository; customer ledger and one/more financial allocation entries are
coordinated by SaleController snapshots.
Current local transaction mechanism: Drift transactions inside adapters plus
RepositoryTransaction snapshots; controller does not inject one outer durable
database transaction.
Cloud risk: crash/timeout/independent retries can split document, inventory,
COGS, receivable and cash entries; concurrent devices can oversell.
Required future authority: one idempotent server sale command atomically accepts
sale+lines, stock movement, valuation/COGS, customer effect, allocations, audit,
number and command result.
Can be eventually consistent? NO for acceptance; YES only for cache/report refresh.
```

### Sale cancellation

```text
Operation: cancel/reverse sale
Current atomic boundary: cancellation metadata, reversal movements/value events,
customer-ledger reversal and payment reversals coordinated by snapshots.
Current local transaction mechanism: adapter Drift transactions + controller
RepositoryTransaction.
Cloud risk: double reversal or partial cash/stock/customer restoration.
Required future authority: one server reversal command linked to the original;
original remains immutable.
Can be eventually consistent? NO.
```

### Purchase posting/cancellation

```text
Operation: purchase intake or reversal
Current atomic boundary: purchase, stock movement, valuation, supplier payable,
cash payment and audit participate in DriftPurchaseRepository orchestration.
Current local transaction mechanism: RepositoryTransaction snapshots and nested
adapter transactions; request ID/fingerprint exists for purchase create.
Cloud risk: dependency order, partial posting and concurrent valuation order.
Required future authority: one idempotent server purchase/reversal command.
Can be eventually consistent? NO.
```

### Expense posting

```text
Operation: create/reclassify expense
Current atomic boundary: expense row, optional financial outflow, approval use,
and audit coordinated via snapshots.
Current local transaction mechanism: sequence transaction plus independent
participant persistence under RepositoryTransaction.
Cloud risk: expense without cash entry, duplicate retry, or unauthorized reclass.
Required future authority: one server command; reclassification is versioned and
audited, never a client-side overwrite of accounting truth.
Can be eventually consistent? NO for posting; read projection YES.
```

### Customer collection/advance/refund/opening balance

```text
Operation: customer account command
Current atomic boundary: customer ledger payload records, collection/advance
record, financial-account entry when applicable, approval and audit.
Current local transaction mechanism: in-memory domain aggregate persisted into
multiple SQLite payload tables with RepositoryTransaction snapshots.
Cloud risk: duplicate collection/refund, over-application and split ledger/cash.
Required future authority: idempotent server command, append/reversal semantics.
Can be eventually consistent? NO.
```

### Supplier payment/advance/refund/opening balance

```text
Operation: supplier account command
Current atomic boundary: supplier ledger payload records, payment/advance,
financial-account entry, approval and audit.
Current local transaction mechanism: same aggregate-persist/snapshot pattern.
Cloud risk: duplicate payment/refund or payable/cash divergence.
Required future authority: idempotent server command, append/reversal semantics.
Can be eventually consistent? NO.
```

### Financial transfer

```text
Operation: transfer / transfer reversal
Current atomic boundary: transfer record + source outflow + destination inflow +
approval consumption + audit in the financial aggregate; durable adapter rewrites
the aggregate in one SQLite transaction.
Current local transaction mechanism: RepositoryTransaction plus durable aggregate
persist. `clientRequestId` and transfer reference are unique; replay mismatch is rejected.
Cloud risk: concurrent balance check, duplicate command, two-account ordering.
Required future authority: one serializable/idempotent server transaction locking
or version-checking both accounts.
Can be eventually consistent? NO.
```

### Inventory stock take / manual adjustment

```text
Operation: manual increase/decrease with optional valuation/accounting effect
Current atomic boundary: movement, valuation event/state, optional financial
entry and audit coordinated by InventoryController snapshots.
Current local transaction mechanism: RepositoryTransaction; adapter writes.
Cloud risk: two stock takes against different base versions and fabricated final stock.
Required future authority: server adjustment command with observed/base version,
reason and actor; append delta, never overwrite ledger.
Can be eventually consistent? NO for acceptance.
```

### Financial closing/reopening

```text
Operation: create closing or reopen
Current atomic boundary: closing aggregate and audit; date-open checks gate postings.
Current local transaction mechanism: financial aggregate snapshot + SQLite persist.
Cloud risk: another device posts while a client closes, or stale close totals.
Required future authority: server-only privileged command serialized against postings.
Can be eventually consistent? NO.
```

### Backup restore and business-data wipe

```text
Operation: restore-to-empty / wipe local business data
Current atomic boundary: restore validates checksum/relationships/empty target,
then repository snapshots; wipe runs all 13 clears inside one outer Drift transaction.
Current local transaction mechanism: validation plus RepositoryTransaction; wipe
also has FoundationDatabase.inTransaction.
Cloud risk: treating local restore or wipe as ordinary sync can duplicate/delete
an entire tenant.
Required future authority: staged import job with reconciliation; separate local
cache reset and privileged cloud deletion workflows.
Can be eventually consistent? NO.
```

## Strong consistency set

Sales, purchases, cancellations/reversals, stock movements, valuation/COGS,
financial entries, collections/payments/refunds, transfers, opening balances,
negative-balance approvals, closings, document numbers and import cutover.

## Eventual consistency set

Product/party descriptive caches, audit/report/dashboard projections, logo cache,
sync status and device read replicas, provided versions/staleness are visible.

## Device-local / derived set

Theme/window/file handles/drafts/outbox mechanics are device-local. Balances,
document history, KPIs and reports are derived from acknowledged records.
