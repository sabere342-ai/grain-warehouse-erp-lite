# Phase 72 — Transaction Integration

## Status

Phase 72 integrates the unified financial accounts foundation introduced in Phase 71 with the core operational transactions of the application.

The phase connects financial-account ledger entries to:

* Sales payments.
* Purchase payments.
* Customer collections.
* Supplier payments.
* Expenses.
* Sale cancellation reversals.

## Scope

The implementation adds explicit financial-account and payment-method information to the affected transaction models and repositories.

The supported payment flows include:

* Fully paid transactions.
* Partially paid transactions.
* Credit transactions.
* Transactions without a financial-account ID where the existing workflow permits this.

Credit-only transactions do not create an immediate financial-account movement.

Only the actually paid amount is posted to the selected financial account for partially paid transactions.

## Financial-account ledger integration

The phase extends `FinancialAccountEntrySource` with the transaction-source values required for operational integration.

`FinancialAccountRepository.createEntry` is used to create traceable ledger movements with:

* Financial account ID.
* Direction.
* Amount in integer qirsh.
* Source type.
* Source record ID.
* Description.
* Transaction date.

Inflows and outflows follow the existing financial-account balance convention:

* Cash received creates an inflow.
* Cash paid creates an outflow.
* Cancellation reversal entries use the opposite direction of the original financial movement.

Financial-account balances remain derived from ledger entries and do not re-add the stored opening-balance field.

## Sales integration

`SaleController` now creates financial-account entries for the paid amount of a sale when a valid financial-account ID is supplied.

The supported sale cases are:

* Cash sale: posts the full received amount.
* Partially paid sale: posts only the received portion.
* Credit sale: creates no immediate financial-account entry.
* Sale without a financial-account ID: preserves the compatible existing behavior.
* Cancelled paid sale: creates a reversal entry for the original paid movement.

## Sale cancellation bug fix

A bug was found in `LocalSaleRepository.createSale`.

The repository was not forwarding:

* `financialAccountId`
* `paymentMethod`

from the sale draft into the persisted `SaleRecord`.

As a result, cancellation logic could not identify the original financial account and silently skipped creation of the financial-account reversal entry.

The repository now persists both fields correctly, allowing cancellation to reverse the original paid movement.

## Purchases integration

Purchase intake records now support:

* Payment mode.
* Paid amount.
* Financial-account ID.

The supported cases are:

* Fully paid purchase: posts the full paid amount as an outflow.
* Partially paid purchase: posts only the paid portion as an outflow.
* Credit purchase: creates no immediate financial-account entry.
* Purchase without a financial-account ID: preserves compatible existing behavior.

Inventory intake and supplier liability remain distinct from the actual financial-account payment movement.

## Customer collections

Customer collections can now create a matching financial-account inflow.

The collection record stores the financial-account linkage required for traceability.

The customer balance decreases by the collected amount while the selected financial account increases by the same amount.

## Supplier payments

Supplier payments can now create a matching financial-account outflow.

The supplier payment record stores the financial-account linkage required for traceability.

The supplier payable decreases by the paid amount while the selected financial account decreases by the same amount.

## Expenses

Expenses can now create a matching financial-account outflow when a financial account is selected.

The expense record stores the financial-account linkage and payment method required for transaction traceability.

## Accounting safeguards

The phase preserves the following accounting rules:

* All monetary values remain stored as integer qirsh.
* Credit-only transactions do not affect financial-account balances immediately.
* Partially paid transactions affect financial accounts only by the paid amount.
* Posted amounts are not counted twice.
* Sale cancellation creates a reversal rather than deleting the historical financial movement.
* Financial-account balances remain based on ledger entries.
* Customer and supplier balances remain tied to their respective account ledgers.
* Purchase inventory value is not treated automatically as fully paid cash.

## Schema and backup

No database-schema migration was introduced in Phase 72.

No backup-format version change was introduced in Phase 72.

The changes extend the current in-memory/domain models and repository integration while preserving the existing backup version established before this phase.

## Tests

A new test file was added:

`test/phase72_transaction_integration_test.dart`

It contains 43 new domain tests covering:

* `PaymentMethod` labels.
* New `FinancialAccountEntrySource` values.
* `PurchasePaymentMode` labels.
* `FinancialAccountRepository.createEntry`.
* Expense financial-account entries.
* Customer collection financial-account entries.
* Supplier payment financial-account entries.
* Sale cash, partial, credit, no-account, and cancellation-reversal cases.
* Purchase paid, partial, credit, and no-account cases.
* Balance consistency.
* Direction consistency.
* Model-field persistence.

A Phase 71 test cleanup was also included to satisfy the analyzer's const-constructor and const-declaration rules without changing business expectations.

## Requirements traceability

The following requirements were marked implemented:

* `ACC-009`
* `ACC-010`

## Verification

Final verification results:

* `flutter analyze --no-pub`: no issues found.
* `flutter test`: 673 of 673 tests passed.
* `flutter build windows --release`: succeeded.
* `git diff --check`: passed with only normal LF/CRLF conversion warnings.

The Windows build continued to show the existing non-blocking CMake deprecation and MSVCRT linker warnings.

## Production impact

Production code changed: Yes.

Schema changed: No.

Backup version changed: No.

Cloud sync implemented in this phase: No.

Multi-device live synchronization implemented in this phase: No.

Mobile application implemented in this phase: No.

These roadmap items remain part of the master product plan and are not removed by this phase.
