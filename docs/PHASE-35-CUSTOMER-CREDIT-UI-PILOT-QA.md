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

## Verification
- `flutter analyze --no-pub` — No issues found
- `flutter test test\phase35_customer_credit_ui_pilot_qa_test.dart` — 8/8 passed
- `flutter test test\phase34_customer_credit_collections_test.dart` — 4/4 passed
- `flutter test test\phase21c_profit_stock_valuation_reports_test.dart` — 5/5 passed
- `flutter test test\reports_test.dart` — 12/12 passed
- `flutter test` — 260/261 passed (1 pre-existing Phase 11 Arabic UX test unrelated to Phase 35)
- `flutter build windows --release` — Build successful, exe generated
- Delivery package created at `delivery\grain_warehouse_erp_lite_pilot_20260708-010044`
- Delivery safety check — PASS

## Remaining limitations
- No opening balances or prepayments are supported.
- No supplier credit was added.
- No cloud sync, branch sync, bank, wallet, tax, or full accounting module was added.
- Restore remains intentionally limited to safe restore into an empty system.
