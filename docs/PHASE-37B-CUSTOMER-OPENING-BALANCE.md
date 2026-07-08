# Phase 37B — Customer Opening Balance

## Purpose

Phase 37B extends the Phase 37A opening balance feature to customer accounts. Before Phase 37B, customer balances always started from zero — only credit sales and collections could create ledger entries. Now the owner can record a pre-existing customer debt as an opening balance during initial system setup, mirroring the supplier opening balance pattern from Phase 37A.

## Why customer opening balances are needed

- A warehouse transitioning into the system may already have outstanding customer debts from before the system start date.
- Without opening balances, the first customer statement would start at zero, forcing the owner to manually track pre-system receivables outside the app.
- Phase 37A added opening balances for inventory and suppliers; this phase adds the customer counterpart for accounting completeness.

## Pre-existing repository support

The `LocalCustomerAccountRepository` already contained:

- `createOpeningBalanceEntry` — creates a debit entry (`debitAmountQirsh = amount`, `creditAmountQirsh = 0`) with `sourceDocumentType: 'customerOpeningBalance'`.
- `hasOpeningBalanceEntry(customerId)` — returns `bool`.
- Both methods were implemented before this phase. The abstract `CustomerAccountRepository` interface also included these methods.

The `CustomerAccountEntryType` enum already contained `openingBalance` with Arabic label `'رصيد افتتاحي'`.

## What was added in this phase

### 37B.1 — Customer opening balance UI (customers_screen.dart)

- A "رصيد افتتاحي" `OutlinedButton.icon` (using `Icons.account_balance_rounded`) appears on each customer card that does NOT already have an opening balance.
- The button is hidden once `hasOpeningBalanceEntry` returns `true` for that customer.
- Tapping the button opens `_CustomerOpeningBalanceDialog`:
  - User enters amount in qirsh (e.g., `50000` for EGP 500).
  - Amount must be positive.
  - Amount must be a multiple of 100 qirsh (whole EGP).
  - Shows inline validation error for invalid input.
  - On success, shows snackbar "تم تسجيل الرصيد الافتتاحي بنجاح.".
  - On error, shows snackbar with the controller's error message.
- The dialog and callback follow the same pattern as the supplier `_SupplierOpeningBalanceDialog` from Phase 37A.

### 37B.2 — Controller layer additions (customer_controller.dart)

- `hasOpeningBalanceForCustomer(String customerId)` — returns `bool` based on `_customersWithOpeningBalance` set.
- `recordOpeningBalance` — delegates to `repository.createOpeningBalanceEntry`, reloads customers on success, returns `false` on failure with Arabic error message.
- `_loadCustomersWithOpeningBalance` — load-time helper that populates `_customersWithOpeningBalance` by calling `hasOpeningBalanceEntry` for each customer.
- `_openingBalanceMessageForError` — maps exceptions to clear Arabic messages:
  - `ArgumentError`: "اكتب مبلغ الرصيد الافتتاحي بشكل صحيح ويجب أن يكون أكبر من صفر."
  - `StateError` with "already exists": "الرصيد الافتتاحي موجود مسبقا لهذا العميل."
  - `StateError` with "has transactions": "لا يمكن إضافة رصيد افتتاحي بعد وجود مشتريات أو تحصيلات للعميل."
  - Other: "لا يمكن تسجيل الرصيد الافتتاحي بهذه البيانات."

### 37B.3 — Customer statement display (customers_screen.dart)

- `_StatementLineCard` now handles `entry.type == CustomerAccountEntryType.openingBalance`:
  - Displays label `'الرصيد الافتتاحي: X ج.م'` instead of separate debit/credit labels.
  - Opening balance appears as the first entry in the statement, providing a complete balance picture.
- Removed misleading text "لا يوجد رصيد افتتاحي يدوي" from statement explanation.

## Rule summary

| Rule | Enforcement |
|---|---|
| One opening balance per customer | `createOpeningBalanceEntry` checks `hasOpeningBalanceEntry` first and throws `StateError` if one exists. UI hides the button after creation. |
| No opening balance after transactions | `createOpeningBalanceEntry` checks if any existing entry exists for the customer and throws `StateError`. |
| No negative or zero amounts | `ArgumentError` thrown for `amountQirsh <= 0`. |
| Whole EGP only | UI dialog validates multiple of 100 qirsh; repository does not enforce this (allows any positive integer). |
| Permission check | `recordOpeningBalance` checks `_canManage(user)` — requires `canCreateCustomerPayment` or `canAccessSettings`. |

## Integration with existing features

| Feature | Interaction |
|---|---|
| Credit sale | An opening balance entry appears as a debit. A subsequent credit sale adds another debit. Both contribute to the running balance in the statement. |
| Collection | An opening balance entry followed by a collection produces: debit (opening balance) → credit (collection). Running balance decreases after collection. |
| Reports | `totalOutstandingReceivablesQirsh` in reports sums all positive customer balances (including opening balances). This is correct accounting — opening balance is a receivable. |
| Credit sales count | Opening balances are NOT counted as credit sales. Only `SaleRecord` with `isCreditSale == true` counts toward `totalCreditSalesAmountQirsh`. |
| Backup/restore | Customer account entries (including opening balance entries) are included in backup via `CustomerAccountEntry` serialization. No version bump needed — Phase 34/35 already included entries. |
| Document history | Opening balance entries do NOT appear in document history. They are ledger entries, not sales or purchases. |

## Tests added

File: `test/phase37b_customer_opening_balances_test.dart` — 11 new tests:

| # | Test | Layer |
|---|---|---|
| 1 | Create opening balance increases balance | Repository |
| 2 | Duplicate opening balance is rejected | Repository |
| 3 | `hasOpeningBalanceEntry` returns correct status | Repository |
| 4 | Negative amount is rejected | Repository |
| 5 | Zero amount is rejected | Repository |
| 6 | Statement shows opening balance entry with running balance | Repository |
| 7 | Opening balance + credit sale produces correct running balance | Repository |
| 8 | Collection reduces opening balance correctly | Repository |
| 9 | Opening balance rejected after existing transactions | Repository |
| 10 | `recordOpeningBalance` returns true and updates controller state | Controller |
| 11 | `recordOpeningBalance` returns false on duplicate | Controller |

## Verification results

- `flutter analyze --no-pub`: 0 errors, 0 warnings, 40 info-only (all pre-existing).
- `flutter test`: 321/321 passed (11 new + 310 existing).
- `flutter build windows --release`: succeeded.
- `git diff --check`: no whitespace errors.

## Delivery safety

Source code safety check passed. The delivery package contains only:
- `Release/grain_warehouse_erp_lite.exe` and required DLLs/data.
- Owner-facing Arabic documentation (README, acceptance checklist, release notes, feedback form, runbook, etc.)

No `.git/`, `lib/`, `test/`, `tool/`, source archives, or internal developer docs are included.

## Remaining risks

- Customer opening balance is a manual entry — the owner must ensure the entered amount matches actual pre-existing customer debt. There is no automated verification.
- Amount validation in the UI enforces whole EGP (multiples of 100 qirsh) — this is a UX convenience, not a repository rule. The repository accepts any positive integer.
- Opening balance and credit sale are both debit entries. The statement correctly shows both with their respective types, but the owner must understand the distinction.
- If a customer has both an opening balance and subsequent credit sales, canceling a credit sale does NOT affect the opening balance. The opening balance entry is immutable.
- No `SupplierAccountException` equivalent exists for customers — `StateError` is used instead. This is consistent with pre-existing customer account repository patterns.
- Backup v2 compatibility is unchanged — customer account entries were already included in Phase 34/35.
