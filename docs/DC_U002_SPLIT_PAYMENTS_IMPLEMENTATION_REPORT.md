# DC-U002 — Atomic Split Payments

## Baseline, scope, and dependency audit

- Branch: `dc-u002-split-payments`
- Starting commit: `49878f72186c02c45196eea1f238e92d3b3648b1`
- Supported operation: sales invoices (`SaleDraft` / `SaleRecord`). This is the
  only current invoice workflow that accepted a financial account; customer
  collections, supplier payments, expenses, and purchases retain their own
  separate single-payment contracts and were not claimed as split-capable.

The audit found that sales create inventory movements in `LocalSaleRepository`,
customer receivable entries in `CustomerAccountRepository`, and financial
entries in `SaleController`. Financial accounts already provide append-only
entries, `reversalOf`, negative-balance approval consumption, audit snapshots,
and `RepositoryTransaction`. CAN-005/006/007 established the compensating
reversal convention. Backup/restore serializes sales and financial entries.

## Design and safeguards

`SalePaymentAllocation` is an immutable sale-payment part containing a
financial account id, a positive qirsh amount, and a payment method. The
allocation total must equal the paid invoice amount exactly; no floating-point
money is used. Split requests allow at most five distinct accounts, reject
zero/negative amounts, duplicate accounts, missing/inactive accounts, and a
total that differs from the invoice payment.

Existing single-account fields remain compatible. When a legacy cash or
partial sale includes `financialAccountId`, it is internally represented as one
allocation. New allocation-based requests require `operationRequestId`; the
sale repository persists the consumed request id and restores it from backup.
Concurrent/replayed requests serialize through `RepositoryTransaction` and
cannot create another sale.

For allocation-based requests, the sale repository, inventory, customer ledger,
financial accounts, audit log, generated ids, and approval state participate in
one rollback boundary. One inflow `FinancialAccountEntry` is written per
allocation using the original sale id. Any later failure restores all prior
participants. Existing legacy adapters without transaction snapshots continue
to use their prior one-account behavior rather than being silently treated as
split-capable.

Cancellation of a split sale is atomic. It creates one outflow reversal per
allocation, linked to its own original financial entry by `reversalOf`; a
missing or failing account rolls back the cancellation, stock restoration,
customer-ledger reversal, financial entries, audit state, and approval state.
Partial reversal is not exposed.

## Persistence, reporting, and UI

Backup export/restore now includes allocation account ids, qirsh amounts,
methods, and the sale operation request id. Restore validates account links,
distinctness, and exact totals. Existing reports continue to count the sale
document once through `totalQirsh`/`paidAmountQirsh`; allocations are financial
movement detail and are not separate sales documents.

The current sales form has no financial-account selector even for its legacy
single-account field. This ticket deliberately stabilizes and tests the
business API first; UI allocation rows are not claimed as delivered. They can
be wired to `SaleController.createSale(paymentAllocations:, operationRequestId:)`
without changing accounting semantics.

## Verification record

- `test/dc_u002_split_payments_test.dart`: 7 tests passed, including one/two/
  three allocations, exact qirsh arithmetic, invalid inputs, replay/concurrent
  requests, creation rollback, reversal linkage, and reversal rollback.
- Regression batch (`DC-U002`, CAN-005/006/007, Phase 72, and Phase 59): 63
  tests passed.
- `dart analyze`: passed with no issues.
- `dart format --output=none --set-exit-if-changed` on all modified Dart
  files: 7 files, 0 changes. `git diff --check`: passed.
- Independent `flutter test --no-pub --concurrency=1`: 845 tests passed in
  1m 36s, exit 0. Independent default-concurrency `flutter test --no-pub`:
  845 tests passed in 42s, exit 0. These independent processes avoid the
  interactive-session timeout boundary.
- `flutter build windows --release --no-pub`: passed, exit 0, 42.2s reported
  build time. Artifact:
  `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe` (784,384
  bytes). No Dart/Flutter/CMake/Ninja/MSBuild/compiler process remained.

No deployment, merge, tag, secret/environment change, or modification to
`MASTER-PROJECT-EXECUTION-PLAN-AR.md` is included.
