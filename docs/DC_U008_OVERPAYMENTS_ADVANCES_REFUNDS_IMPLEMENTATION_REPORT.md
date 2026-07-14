# DC-U008: Overpayments, Advances, and Refunds — Implementation Report

## Scope

Customer and supplier overpayments, advances, advance applications, advance
refunds, and compensating reversals for each of application and refund — on both
the customer and supplier side — including namespace isolation, replay
protection, concurrency safety, and atomic rollback.

## Accounting Directions

| Side | Overpayment | Application | Refund |
|------|-------------|-------------|--------|
| Customer | Collection > invoice amount | Advance reduces receivable | Cash returned to customer |
| Supplier | Payment > invoice amount | Advance reduces payable | Cash returned from supplier |

- Customer overpayment: financial account receives a net inflow (balance
  increases).
- Supplier overpayment: financial account sends a net outflow (balance
  decreases; negative-balance approval required).

## Approval-Binding Model

Every overpayment and negative-balance advancement is bound to a
`NegativeBalanceApproval` that stores:

- `accountId` — the financial account
- `amountQirsh` — the exact approved amount
- `operationType` — `customerOverpayment` or `supplierOverpayment`
- `sourceDocumentType` — e.g. `'customerOverpayment'`
- `sourceDocumentId` — the request/source identifier
- `requestedByUserId` — who requested
- `balanceBeforeQirsh` / `expectedBalanceAfterQirsh` — pinned balance snapshot

The `NegativeBalanceApprovalService.verify()` method on line 87 checks **all**
nine binding fields against the stored approval before any mutation. The
`consume()` method marks the approval used after the successful transaction.

Overpayment approvals and negative-balance approvals are **never
interchangeable**: the latter uses `operationType` values like `expense`,
`supplierPayment`, `transfer`, etc., while overpayments use dedicated
`customerOverpayment` or `supplierOverpayment` values with
`requiresNegativeBalance == false`.

## Replay and Concurrency Guarantees

- Every mutation uses a unique `operationRequestId`.
- Replay fingerprints are stored per-namespace (customer vs supplier) with
  prefixed keys (`'customer|reverse-application|...'`,
  `'supplier|reverse-refund|...'`) to prevent cross-namespace collisions.
- Concurrent reversals with distinct request IDs race; exactly one succeeds and
  the other observes `isReversed == true` and throws `StateError`.
- The namespace isolation test verifies that the **same shared request ID** can
  be used for a customer reversal and a supplier reversal without conflict.

## Rollback Coverage

- Failed reversals leave no partial ledger entry, advance mutation, audit log,
  approval consumption, or financial-account balance change.
- Audit-log failures during reversal trigger full rollback of the financial
  entry, the ledger entry, the advance reversal flag, and approval reversion.
- Supplier refund reversals that fail mid-approval do not consume the
  overpayment approval.

## Compensating Entries (No Deletions)

- Advance application reversals create a new ledger entry of type
  `advanceApplicationReversal` with the opposite sign — the original entry
  remains.
- Advance refund reversals create a new financial entry with
  `reversalOf: <originalEntryId>` and `sourceType` set to
  `customerAdvanceRefundReversal` / `supplierAdvanceRefundReversal` — the
  original entry remains.
- Application reversal links `reversalLedgerEntryId` on the application record.
- Refund reversal links `reversalFinancialEntryId` on the refund record.

## Backup/Restore Coverage

- `backup_export.dart` serialises advances, advance applications, and advance
  refunds (both customer and supplier).
- `backup_restore_service.dart` restores advances from JSON and preserves
  reversal state and compensating-entry links.
- `phase81_transaction_financial_backup_contract_test.dart` verifies v6 backup
  round-trip for advances.

## Reports

The `LocalReportRepository` filters out reversed advance applications and
refunds from active calculations. The test at `dc_u008_advances_test.dart`
verifies that reports do not count reversed refunds as active cash movements.

## Test Counts and Durations

| Suite | Tests | Duration |
|-------|-------|----------|
| `dc_u008_advances_test.dart` | 13 | ~3 s |
| Full repository (sequential) | 858 | 1 min 58 s |
| Full repository (default) | 858 | 46 s |
| Financial regression matrix | 159 | 17 s |

## Analyzer / Build Results

| Check | Result |
|-------|--------|
| `flutter analyze --no-pub` | No issues found |
| `git diff --check` | No whitespace errors |
| `git status --short` | 16 modified + 3 new (all DC-U008 scoped) |
| `flutter build windows --release --no-pub` | Build succeeded (69 s) |

## Files Changed

**New files (3):**
- `lib/core/customer_accounts/customer_advance.dart`
- `lib/core/supplier_accounts/supplier_advance.dart`
- `test/dc_u008_advances_test.dart`

**Modified files (16):**
- `lib/app/app_repositories.dart`
- `lib/core/backup/backup_export.dart`
- `lib/core/backup/backup_restore_service.dart`
- `lib/core/customer_accounts/customer_account_entry.dart`
- `lib/core/customer_accounts/customer_account_repository.dart`
- `lib/core/customer_accounts/customer_collection.dart`
- `lib/core/financial_accounts/financial_account_entry.dart`
- `lib/core/financial_accounts/financial_account_repository.dart`
- `lib/core/financial_accounts/negative_balance_approval.dart`
- `lib/core/financial_accounts/negative_balance_approval_service.dart`
- `lib/core/supplier_accounts/supplier_account_entry.dart`
- `lib/core/supplier_accounts/supplier_account_repository.dart`
- `lib/core/supplier_accounts/supplier_payment.dart`
- `lib/features/prints/printable_customer_statement_view.dart`
- `lib/features/supplier_accounts/supplier_statement_screen.dart`
- `test/reports_test.dart`

## Known UI Limitations

- No dedicated "advances" screen exists yet; advances are visible only through
  ledger statements and printable statements.
- Supplier statement screen shows advance columns; customer statement already
  shows collection breakdown.
- No widget/integration test for advance UI flows (all tests are unit-level).
