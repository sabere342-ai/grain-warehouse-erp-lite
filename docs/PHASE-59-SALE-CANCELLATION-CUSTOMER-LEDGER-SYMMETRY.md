# Phase 59 — Sale Cancellation Customer Ledger Symmetry

**Date:** 2026-07-10

## Baseline

| Item | Value |
|---|---|
| Phase 58 commit | `63d8be4` |
| Phase 58 tag | `phase-58-accounting-freeze-production-readiness-audit` |
| Phase 59 commit | `4ebbd58` |
| Phase 59 tag | `phase-59-sale-cancellation-customer-ledger-symmetry` |
| Phase 59A (this doc) | Closes the documentation gap |

## Problem Found in Phase 58

The Phase 58 accounting freeze audit identified one known limitation:

> Sale cancellation reverses stock (via `StockMovementType.saleCancellation`) but does **not** reverse customer account ledger entries.

This asymmetry meant that cancelling a credit, partial, or any customer-bound sale left the customer's outstanding receivable overstated. The customer's ledger continued to show the original debit entry even though the sale was reversed at the stock level.

The purchase side handled this correctly: `PurchaseRepository.cancelPurchaseIntake()` calls `SupplierAccountRepository.reversePurchaseEntry()` to create a reversing supplier account entry.

## Scope

- Add customer ledger reversal for sale cancellation.
- Mirror the purchase cancellation pattern (reversal entry in the customer ledger).
- Production code change only in Phase 59.
- Documentation closure only in Phase 59A.

## Non-Goals

- No cloud sync.
- No mobile app.
- No schema change (no database migration).
- No new reports.
- No UI redesign.
- No new permissions or roles.

## Accounting Rule Implemented

1. The original sale ledger entry **remains in place** — no deletion.
2. Cancellation creates a **reversing customer ledger entry** (type `saleCancellation`).
3. No silent deletion or rewriting of historical entries.
4. No fake reversal for sales with zero net customer balance impact (fully paid cash sales).
5. Partial payment cancellation credits only the remaining net balance impact.
6. Duplicate cancellation is idempotent — only one reversal entry is created.
7. Existing customer collections block cancellation (symmetric with supplier payment blocking purchase cancellation).
8. The reversal entry is linked to the original sale via `sourceDocumentId`.
9. An audit log entry is recorded on reversal.

## Before / After Behavior

| Scenario | Before (Phase 58) | After (Phase 59) |
|---|---|---|
| Credit sale cancelled | Stock restored, customer receivable stayed at totalQirsh | Stock restored, reversal entry credits totalQirsh, balance = 0 |
| Cash sale (fully paid) cancelled | Stock restored, entry with debit=credit remained | No reversal (no net balance impact), entry unchanged |
| Partial payment sale cancelled | Stock restored, remaining balance remained | Reversal credits remaining amount, balance = 0 |
| Double cancellation | Stock reversal not duplicated (safe guard) | Customer reversal not duplicated (safe guard) |
| Collections exist on a sale | Cancellation would succeed, balance would become negative | Cancellation blocked (collections must be reversed first) |

## Implementation Summary

### Files Changed (Phase 59)

| File | Change |
|---|---|
| `lib/core/customer_accounts/customer_account_entry.dart` | Added `saleCancellation` enum value + Arabic label |
| `lib/core/customer_accounts/customer_account_repository.dart` | Added `reverseSaleEntry()` method (abstract + implementation) |
| `lib/core/sales/sale_controller.dart` | Calls `reverseSaleEntry()` after stock reversal in `cancelSale()` |
| `lib/features/prints/printable_customer_statement_view.dart` | Added switch case for `saleCancellation` entry type |

### New Method: `reverseSaleEntry()`

Located in `CustomerAccountRepository` / `LocalCustomerAccountRepository`.

Signature:

```dart
Future<CustomerAccountEntry> reverseSaleEntry({
  required SaleRecord cancelledSale,
  required String cancelledByUserId,
  required String cancellationReason,
});
```

Logic:

1. Finds the original `sale` entry by matching `sourceDocumentType == 'sale'` and `sourceDocumentId == cancelledSale.id`.
2. Throws `StateError` if no original entry is found.
3. Computes `netImpact = originalEntry.debitAmountQirsh - originalEntry.creditAmountQirsh`.
4. If `netImpact <= 0`, returns the original entry (no reversal needed — fully paid cash case).
5. Calculates any collections against this sale: `collectedAmount = netImpact - balanceBeforeReversal`. Throws `StateError` if > 0.
6. Creates a `saleCancellation` entry with `creditAmountQirsh = netImpact`.
7. Records an audit log entry with action type `customer.sale.reversed`.

### Controller Integration

In `SaleController.cancelSale()`:

```dart
final cancelled = await _saleRepository.cancelSale(...);
if (_customerAccountRepository != null && cancelled.customerId != null) {
  await _customerAccountRepository!.reverseSaleEntry(
    cancelledSale: cancelled,
    cancelledByUserId: user.id,
    cancellationReason: cancellationReason,
  );
}
```

### Printable Statement Support

The `saleCancellation` entry type displays as `"إلغاء بيع — {description}"` in the printable customer statement view.

## Test Coverage

### New Test File

`test/phase59_sale_cancellation_customer_ledger_symmetry_test.dart`

9 tests:

| # | Test | Status |
|---|---|---|
| 1 | Credit sale reversal restores balance to zero | PASS |
| 2 | Fully paid cash sale does not create fake reversal entry | PASS |
| 3 | Partial payment reversal credits remaining balance only | PASS |
| 4 | Double cancellation does not create duplicate reversal entries | PASS |
| 5 | Reversal entry links to original sale via `sourceDocumentId` | PASS |
| 6 | Collections block cancellation with error message | PASS |
| 7 | Direct repository API (`reverseSaleEntry`) mirrors controller behavior | PASS |
| 8 | Non-existent sale throws `StateError` | PASS |
| 9 | `reverseSaleEntry` creates audit log entry | PASS |

## Schema Impact

- **No database migration.**
- No new storage layer.
- Enum- and model-level change only.

## Production Code Impact

| Phase | Production code changed |
|---|---|
| Phase 59 | Yes |
| Phase 59A | No |

## Verification Results (Phase 59)

- `flutter analyze --no-pub`: no issues found.
- `flutter test test/phase59_sale_cancellation_customer_ledger_symmetry_test.dart`: 9/9 passed.
- `flutter test`: 527/527 passed.
- `flutter build windows --release`: succeeded with usual CMake/MSVCRT warnings only.
- `git diff --check`: clean (only expected CRLF warnings).
- `git status --short`: clean after commit.

## Verification Results (Phase 59A — documentation closure)

- `flutter analyze --no-pub`: no issues found.
- `flutter test`: 527/527 passed.
- `flutter build windows --release`: succeeded with usual CMake/MSVCRT warnings only.
- `git diff --check`: clean (only expected CRLF warnings).
- `git status --short`: clean after commit.

## Remaining Limitations

- The project remains single-device local Windows only.
- Cloud sync is not implemented.
- Multi-device live sync is not implemented.
- Backup restore writes without a transaction (acknowledged limitation).
- No remaining known limitation for this specific sale cancellation customer ledger symmetry issue.

## Conclusion

Phase 59 resolved the accounting asymmetry identified in Phase 58 where sale cancellation did not reverse customer account entries. The fix mirrors the purchase cancellation pattern, preserves original ledger history, guards against duplicate reversals, and safely handles collections and fully-paid cash sales. Phase 59A closes the documentation gap by recording the fix, its tests, verification results, and remaining limitations.
