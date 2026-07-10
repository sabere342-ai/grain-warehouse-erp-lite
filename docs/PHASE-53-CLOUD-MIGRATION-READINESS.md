# Phase 53 - Cloud Migration Readiness

## Phase status
Phase 53 is a planning, readiness, and audit phase only.

No cloud sync was implemented in Phase 53.
No mobile app was implemented in Phase 53.
No multi-device live sync was implemented in Phase 53.
No cloud backend, API key, Firebase setup, Supabase setup, sync queue, tenant service, or remote database behavior was added in Phase 53.
No production code or schema change was required.

## Phase purpose
Phase 53 documents what must be protected before any future move from the current local Windows pilot to cloud, mobile, SaaS, or multi-device use. The purpose is to prevent duplicate accounting events, stock conflicts, owner permission drift, unsafe restore behavior, and misleading delivery promises.

This phase does not start a new baseline. It builds directly on the Phase 52 accounting freeze.

## Baseline from Phase 52
- Baseline commit: `82407ad`
- Baseline tag: `phase-52-accounting-freeze-audit`
- Phase 52 result: accounting and inventory sources of truth are frozen for the local Windows pilot.
- Product stock is derived from inventory movement records.
- Customer balances are derived from customer account entries.
- Supplier balances are derived from supplier account entries.
- Daily reports are read-only projections over source repositories.
- Backup restore is safe only into an empty validated local system.
- Cloud sync, mobile app, and multi-device live sync remained absent in Phase 52 and remain absent in Phase 53.

## Current local-first architecture
The current application is a local Windows pilot. Its active repositories are in-memory local repositories used by the Flutter app during the session. Backup export writes JSON, and restore imports a validated backup only into an empty local system.

The current architecture is suitable for a controlled local pilot, not for concurrent writes from multiple devices. Any future cloud design must treat the existing accounting operations as immutable business events, not as casual UI state.

## Accounting sources of truth
| Area | Current source of truth | Future cloud requirement |
|---|---|---|
| Product stock quantity | Sum of `StockMovement.signedQuantityKg` from `LocalInventoryRepository.currentStockKg()` | Append-only inventory events with idempotency keys and conflict policy |
| Inventory history | `LocalInventoryRepository.listAllMovements()` | Server-validated movement stream, actor/device tracking, no destructive edits |
| Customer balance | `LocalCustomerAccountRepository.balanceForCustomer()` | Append-only customer ledger entries, duplicate-prevention for sales and collections |
| Supplier balance | `LocalSupplierAccountRepository.balanceForSupplier()` | Append-only supplier ledger entries, duplicate-prevention for purchases and payments |
| Purchases | Posted purchase intake records plus purchase stock movement and supplier ledger impact | Atomic server-side purchase posting or rejected transaction |
| Sales | Posted sale records plus sale stock movement and customer ledger impact | Atomic server-side sale posting with stock availability rules |
| Customer collections | Customer collection records and customer ledger credit entries | Idempotent payment/collection events, no double posting from retries |
| Supplier payments | Supplier payment records and supplier ledger debit entries | Idempotent payment events, no double posting from retries |
| Manual stock adjustments | `manualIncrease` and `manualDecrease` stock movements | Owner-only adjustment events with audit reason and conflict handling |
| Reports | `LocalReportRepository.dailyActivityReport()` read-only projection | Read-only server/client projections derived from accepted events |
| Backup/restore | Local JSON export and restore-to-empty only | No restore over non-empty cloud tenant data without a separate approved migration/import protocol |

## Simulation scope
The Phase 53 simulation scope is a readiness simulation, not a cloud runtime simulation. It checks the current local invariants that future sync must preserve:

- Purchases affect stock and supplier payables.
- Sales affect stock and customer receivables according to the existing customer-account behavior.
- Customer collections reduce customer receivables and do not affect supplier payables.
- Supplier payments reduce supplier payables and do not affect customer receivables.
- Manual stock adjustments affect inventory only.
- Daily reports read source records without mutating ledgers or stock.
- Cancellations/reversals preserve an audit trail using cancellation metadata and reversal stock movements where supported.
- Backup restore remains a local restore-to-empty operation, not a cloud merge.

## Synthetic business-day scenario
The readiness scenario is a synthetic single-owner business day:

1. Create one product, one supplier, and one customer.
2. Post a purchase intake for the product.
3. Post a customer-bound credit sale for part of the stock.
4. Post a customer collection.
5. Post a supplier payment.
6. Post a manual stock-taking adjustment using existing manual movement behavior.
7. Read the daily activity report.
8. Cancel supported sale and purchase records in a separate audit trail check.
9. Confirm that all accounting-critical events are explicit records that a future sync design must never duplicate silently.

## Accounting and stock invariants
- Inventory balance must be derived from inventory movements, not from customer or supplier ledgers.
- Customer balance must be derived from customer account entries, not from stock movements.
- Supplier balance must be derived from supplier account entries, not from stock movements.
- Customer collections must not mutate supplier balances.
- Supplier payments must not mutate customer balances.
- Manual stock increases/decreases must not mutate customer or supplier balances.
- Reports must not mutate products, movements, purchases, sales, customer ledgers, supplier ledgers, expenses, or backup state.
- Cancellations/reversals must preserve the original posted document and add clear reversal/audit data where supported.
- Backup restore must remain local-first and restore-to-empty only until a formal cloud import/merge policy exists.

## Future cloud migration risk register
| Risk | Why it matters | Required future control |
|---|---|---|
| Duplicate sales from retry/unstable internet | A retry can double stock reduction and receivables | Client-generated idempotency key plus server duplicate rejection |
| Same product sold from two devices at once | Stock can go negative or reports can diverge | Server-side stock transaction or reservation/conflict rule |
| Purchase and sale ordering conflict | A sale may appear before the purchase that made stock available | Ordered event acceptance with server timestamp and dependency rules |
| Customer collection entered on two devices | Receivable can be reduced twice | Idempotent collection event and duplicate detection |
| Supplier payment entered on two devices | Payable can be reduced twice | Idempotent supplier payment event and duplicate detection |
| Manual stock adjustment conflict | Two stock counts may overwrite each other conceptually | Append-only adjustment events with actor, device, reason, and conflict review |
| Backup restored over non-empty cloud data | Existing tenant history can be overwritten or duplicated | Block by default; require a separate migration/import protocol |
| Device clock differences | Reports and ordering can become misleading | Server timestamp for accepted events, device timestamp kept as metadata only |
| Owner/admin/cashier permission drift | A device may perform actions after permissions changed | Server-side authorization on every write |
| Partial sync causing reports to mismatch | Reports can show accepted and pending data as one truth | Clear accepted/pending states and read-only projections from accepted events |
| Code exposure risk in client delivery | Shipping source or secrets can expose business logic and credentials | Source-safe delivery, no embedded secrets, server-owned validation |

## Minimum future cloud requirements
- Tenant/owner identity model before any remote data is accepted.
- Stable tenant isolation for every product, customer, supplier, document, ledger entry, stock movement, and backup/import record.
- Append-only sync contract for accounting-critical events.
- Idempotency key for every sale, purchase, customer collection, supplier payment, and manual stock adjustment.
- Server-side validation for stock availability, account impact, permissions, and cancellation/reversal rules.
- Server-side timestamps for accepted event ordering.
- Actor and device metadata for every accepted write.
- Conflict policy for inventory, customer ledgers, supplier ledgers, stock-taking, and restore/import.
- Read-only reporting projections derived only from accepted events.
- Backup/import policy that cannot overwrite or merge non-empty cloud tenant data silently.
- Source-code protection and secret handling plan before any client delivery involving cloud credentials.

## Data ownership and source-code protection
- The warehouse owner owns the business data for their tenant.
- A future cloud system must keep tenant data isolated and must not allow one owner to read or write another owner's records.
- Cloud credentials, API keys, service-role secrets, and validation rules must not be shipped inside a source-exposed client package.
- Client delivery must remain source-safe. Future cloud delivery must separate client code from server-only validation and secrets.
- Server-side rules must be the accounting authority; the client UI must not be trusted to enforce financial correctness alone.

## Backup/restore limitations
- Current backup export is local JSON.
- Current restore is local restore-to-empty only.
- Current restore is not a cloud merge.
- Current restore is not safe to run over non-empty cloud tenant data.
- Future cloud restore/import requires a separate design that handles duplicate ids, document numbering, ledger ordering, tenant ownership, and explicit owner approval.

## Recommended migration path
### Step A - Owner identity and tenant model design
Define owner account, tenant id, roles, invited users, active device identity, and tenant isolation before adding remote writes.

### Step B - Append-only sync contract
Define immutable event payloads for sales, purchases, payments, collections, stock adjustments, cancellations, and opening balances. Every event must have an idempotency key, actor id, device id, client timestamp, and server accepted timestamp.

### Step C - Conflict policy for inventory/customer/supplier ledgers
Define what happens when stock is insufficient, two devices post the same operation, a payment arrives twice, or a stock count conflicts with newer accepted movements.

### Step D - Server-side validation
Move acceptance rules for accounting-critical writes to the server. The server must reject invalid stock, invalid ledger impact, unauthorized roles, duplicate idempotency keys, and unsafe reversals.

### Step E - Read-only reporting projections
Build reports as read-only projections from accepted event streams. Pending/offline events must be labeled separately and must not be mixed into final accounting totals without acceptance.

### Step F - Staged pilot with one owner account and one device first
Pilot cloud mode with one owner account and one device before adding multiple devices. Only after accepted-event reports match the local accounting freeze should multi-device testing begin.

## Stop conditions
Stop future cloud/mobile work immediately if any of the following appears:

- A sale, purchase, payment, collection, or stock adjustment can be applied twice by retry.
- Two devices can reduce the same stock without a server conflict rule.
- Reports can mix pending and accepted events without clear labeling.
- Restore/import can write over non-empty tenant data.
- A client package contains source code, cloud secrets, service-role credentials, or validation logic that must remain server-only.
- A visible page claims cloud sync, mobile support, or live multi-device use before those features are actually implemented and tested.

## Deferred items
- Cloud sync implementation.
- Mobile application.
- Multi-device live sync.
- Offline queue implementation.
- Tenant backend.
- API keys and cloud configuration.
- Remote database schema.
- SaaS billing or subscription model.
- Cloud backup/restore/import.
- Push notifications.
- Server-side audit dashboard.

## Explicit non-goals
- Phase 53 does not implement Cloud sync.
- Phase 53 does not implement a Mobile app.
- Phase 53 does not implement Multi-device live sync.
- Phase 53 does not add Firebase, Supabase, or any other cloud backend setup.
- Phase 53 does not add cloud API keys or secrets.
- Phase 53 does not change production accounting behavior.
- Phase 53 does not change the local schema.
- Phase 53 does not create a new delivery package.

## Verification checklist
- `test/phase53_cloud_migration_readiness_test.dart` verifies current local accounting invariants.
- The Phase 53 document states that cloud sync, mobile app, and multi-device live sync are not implemented.
- The risk register names duplicate sales, concurrent stock sale, ordering conflict, duplicate collections/payments, manual stock adjustment conflict, restore over cloud data, device clock differences, permission drift, partial sync mismatch, and source-code exposure risk.
- Owner-facing Arabic docs state that the current version is local and stable for pilot use.
- Owner-facing Arabic docs state that cloud sync, mobile app, and multi-device live sync are not available in this version.
- Production code remains unchanged unless a documented blocking defect is found.
- Schema remains unchanged.
