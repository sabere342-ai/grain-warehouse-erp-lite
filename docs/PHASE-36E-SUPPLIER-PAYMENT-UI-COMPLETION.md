# Phase 36E – Supplier Payment UI Completion

**Supersedes**: Phase 35 customer collection patterns for supplier side.

## Summary

Complete the supplier payment UI so that users can see outstanding balances, record payments against suppliers, view payments in reports, and navigate payment flows from supplier cards, supplier purchase lists, and supplier account statements.

## Changes

### Data Layer

- **`DailyActivityReport`**: Added `totalSupplierPaymentsQirsh`, `totalOutstandingSupplierPayablesQirsh`.
- **`LocalReportRepository`**: Computes supplier payment totals from `SupplierAccountRepository.listEntries()` filtered by `payment` type and date range. Computes outstanding payables from `balancesBySupplierId()`.
- **`AppRepositories`**: Passes `supplierAccountRepository` to `LocalReportRepository`.

### UI Layer

- **`SupplierPaymentDialog`** (new): Reusable dialog for recording a supplier payment. Shows current balance, amount input (EGP), optional notes. Validates amount > 0, amount <= balance.
- **`SuppliersScreen`**: Each supplier card now shows outstanding balance ("له علينا: X ج.م" or "لا يوجد رصيد مستحق"). "تسجيل دفعة" button appears when balance > 0. Balances loaded via `balancesBySupplierId()`.
- **`SupplierStatementScreen`**: "تسجيل دفعة" button at top of balance card when balance > 0. Refreshes statement after payment.
- **`SupplierPurchasesScreen`**: Shows outstanding balance at top of purchase list when loaded.
- **`ReportsScreen`**: New "حسابات الموردين" section showing total supplier payments and outstanding payables. New summary cards in grid. Arabic guidance text explaining payments reduce payable, not expenses.

### Tests

**12 new tests** across `phase36e_supplier_payment_ui_test.dart` and `reports_test.dart`:
- Payment reduces balance
- Full payment zeros balance
- Multi-supplier balance aggregation
- Statement running balance after payment
- Empty supplierId rejected
- Empty userId rejected
- Multiple supplier payments in cash balance
- DashboardController load
- Purchase creates entry + payment reduces balance
- Cancellation blocked after payment
- Report totals include supplier payments
- Report totals include outstanding payables

### Total test count: 294 (was 282)

### Quality Gates

- `dart analyze`: No errors.
- `flutter test`: 294/294 passed.
- `flutter build windows`: Verified release build succeeds.

## Accounting Rules Preserved

- Payment cannot exceed supplier balance (enforced in `SupplierAccountRepository.createPayment`).
- Purchase cancellation blocked if supplier payments exist (`reversePurchaseEntry` check).
- Payments are credit entries (reduce payable), not expenses.
- Cash balance = cash sales + collections – expenses – supplier payments.
- No supplier advance tracking (`paidNowQirsh`) introduced.
- No per-purchase payment tracking (out of scope without `paidNowQirsh`).
- Audit log entries created for every payment.

## Files Changed

```
lib/core/reports/daily_activity_report.dart     (2 fields added)
lib/core/reports/report_repository.dart          (supplier data computed)
lib/app/app_repositories.dart                    (pass supplierAccountRepo to report repo)
lib/features/supplier_accounts/supplier_payment_dialog.dart  (new)
lib/features/suppliers/suppliers_screen.dart     (balance + payment button)
lib/features/supplier_accounts/supplier_statement_screen.dart (payment button + refresh)
lib/features/purchases/supplier_purchases_screen.dart (balance at top)
lib/features/reports/reports_screen.dart         (supplier section + summary cards)
test/phase36e_supplier_payment_ui_test.dart      (new: 10 tests)
test/reports_test.dart                           (updated: 2 new tests, UI assertions)
```

## Next Steps

Phase 37 not yet opened. Phase 36E completes the supplier payment UI for pilot.
