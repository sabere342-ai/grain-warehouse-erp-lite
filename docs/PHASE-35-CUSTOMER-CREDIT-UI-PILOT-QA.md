# Phase 35 - Customer Credit UI Completion & Pilot QA

## Purpose
Phase 35 completes the visible customer credit workflows that were introduced in the Phase 34 accounting layer. The goal is to make credit sales, customer balances, collections, statements, and receivable reporting usable in the Windows pilot without changing the proven ledger model.

## UI additions
- Sales now has a clear payment mode choice: `نقدي` or `آجل على عميل`.
- Credit sales show an active customer selector and a clear final receivable amount message.
- Customers now show derived outstanding balances beside each customer.
- Customers with outstanding balances expose real actions for `كشف الحساب` and `تسجيل تحصيل`.
- Reports show separate totals for credit sales, customer collections, and outstanding receivables.

## Credit sale behavior
A credit sale still uses the same `SaleController.createSale` path as a cash sale. Stock validation, minimum sale price validation, and sale posting remain centralized in the existing sale logic. The only added requirement is that credit mode must select an active customer before posting. After the sale posts, the customer account repository records the receivable ledger debit.

## Customer balances
Customer balances are calculated from customer account ledger entries only: credit-sale debits minus collection credits. There is no editable balance field, no manual opening balance, and no fake balance value on the Customers page.

## Collections
Collections are recorded from the Customers page against the selected customer. The form validates that the amount is present, positive, valid money, and not greater than the current outstanding balance. Saving uses `CustomerAccountRepository.createCollection`, refreshes balances, and does not mutate inventory or create a sale.

## Customer statement
The customer statement displays the real ledger lines in order with date, source document id, Arabic description, debit, credit, running balance, and final balance. It does not add period filters or fake opening balances.

## Reports
The report UI now separates:
- `إجمالي البيع الآجل`
- `إجمالي التحصيلات من العملاء`
- `إجمالي أرصدة العملاء المستحقة`

Collections reduce customer receivables only. They are not counted as new sales revenue or profit.

## Backup and restore wording
Owner-facing wording now states that customer balances are calculated from credit-sale and collection movements. Backup preserves the customer ledger movements and collections, not a manually edited balance number.

## Superseded delivery

**Important:** The Phase 35 / Phase 35A delivery package has been superseded.
See `docs/PHASE-36D-PILOT-DELIVERY-REFRESH.md` for the current delivery.

The two pilot blockers found after Phase 35 delivery were:
1. Dashboard/Home used hardcoded placeholder data instead of live repository data.
2. Suppliers had no functional account connection (no ledger, no payment, no statement).

Both were fixed in Phase 36. The current pilot delivery must be built from
Phase 36 (commit `521d54f` or newer).

## Tests
Phase 35 adds focused controller/source/widget coverage for:
- credit sale requiring a customer;
- cash sale not requiring a customer;
- derived customer balances;
- collections reducing balances;
- over-collection rejection;
- statement debit, credit, source id, running balance, and final balance;
- report separation of credit sales, collections, and receivables;
- absence of manual balance UI controls.

## Phase 35A — Full test suite cleanup
Phase 35 fixed the analyzer and test issues in the Phase 35 code itself, but one pre-existing Phase 11 test (`phase11_ux_test.dart:111`) was still failing because the cancellation dialog text in the sales screen did not match the Arabic string the test expected. Phase 35A fixed that mismatch, bringing the full suite to green.

### Phase 35A verification
- `flutter analyze --no-pub` — No issues found
- `flutter test test\phase11_ux_test.dart` — 6/6 passed
- `flutter test` — 262/262 passed (full suite green)
- `flutter build windows --release` — Build successful, exe generated
- Delivery package with corrected Arabic encoding created at `delivery\grain_warehouse_erp_lite_pilot_20260708-020333`
- Delivery safety check — PASS
- Windows smoke launch — PASS

### Phase 35A files changed
- `lib/features/sales/sales_screen.dart` — cancellation dialog text updated to match test expectation
- `tool/create_pilot_delivery_package.ps1` — fixed corrupted Arabic UTF-8 in README template
- `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md` — fixed corrupted Arabic, added credit/collection checklist items

## Final delivery
- Commit: `e4699ec` tagged as `phase-35a-full-test-suite-cleanup`
- Delivery folder: `delivery\grain_warehouse_erp_lite_pilot_20260708-020333`
- Full test suite: **262/262 passed**
- Windows release build: **successful**
- Owner checklist: ready for handoff

## Remaining limitations
- No opening balances or prepayments are supported.
- No supplier credit was added.
- No cloud sync, branch sync, bank, wallet, tax, or full accounting module was added.
- Restore remains intentionally limited to safe restore into an empty system.
