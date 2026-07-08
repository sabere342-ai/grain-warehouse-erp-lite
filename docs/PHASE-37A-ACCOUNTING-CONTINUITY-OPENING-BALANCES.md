# Phase 37A — Accounting Continuity: Opening Balances

## Purpose

Phase 37A enables the pilot warehouse owner to record opening balances for inventory items and supplier accounts before starting daily operations. This closes the accounting continuity gap: previously, stock and supplier balances always started from zero. Now the owner can enter pre-existing stock and pre-existing supplier debts during initial system setup.

## Why opening balances are needed

- A warehouse transitioning into the system already has physical stock in the store.
- A warehouse already has unpaid supplier invoices from before the system start date.
- Without opening balances, the first inventory report or supplier statement would be incomplete, forcing the owner to manually track pre-system history outside the app.

## What changed

### 37A.1 — Inventory opening balance UI (inventory_screen.dart)

- A dedicated "إضافة رصيد افتتاحي" button appears on each product card that does NOT already have an opening balance.
- The button is shown only when the current user has `canCreateStockAdjustment` permission (owner by default).
- Tapping the button opens `_OpeningBalanceDialog` which:
  - Shows the product name.
  - Lets the user choose unit: كجم (kg) or طن (ton).
  - Lets the user enter the quantity in the chosen unit.
  - Converts tons to kg internally (1 ton = 1000 kg).
  - Shows a confirmation step before saving.
- After successful creation, the button disappears for that product (only one opening balance per product).
- The opening balance is implemented as a stock adjustment movement (`StockMovement`) with a dedicated internal note.

### 37A.2a — SupplierAccountEntryType.openingBalance (supplier_account_entry.dart)

- New enum value `openingBalance` with Arabic display label `'رصيد افتتاحي'`.

### 37A.2b — Supplier opening balance repository (supplier_account_repository.dart)

- New method `createOpeningBalanceEntry`:
  - Creates a debit entry (`debitAmountQirsh = amount`, `creditAmountQirsh = 0`) with `sourceDocumentType: 'supplierOpeningBalance'`.
  - Rejects if the supplier already has an opening balance (`SupplierAccountException`).
  - Rejects negative or zero amounts.
  - Returns the created `SupplierAccountEntry`.
- New method `hasOpeningBalanceEntry(supplierId)` — returns `bool`.
- Implemented in `LocalSupplierAccountRepository`.

### 37A.2c — Supplier opening balance UI (suppliers_screen.dart)

- A "رصيد افتتاحي" button appears on supplier cards when:
  - No opening balance exists for that supplier yet.
  - Current user has supplier management permission.
- Tapping opens `_SupplierOpeningBalanceDialog`:
  - User enters amount in EGP (whole pounds).
  - Amount must be positive and a multiple of 100 qirsh (whole EGP).
  - Shows success/error snackbar.
- After successful creation, the button disappears.

### 37A.2d — Supplier statement opening balance display (supplier_statement_screen.dart)

- `_buildLine` now handles `entry.type == SupplierAccountEntryType.openingBalance`:
  - Icon: `Icons.account_balance_rounded`.
  - Label: `'رصيد افتتاحي'`.
  - Debit amount displayed in EGP.
- The opening balance appears as the first line in the supplier statement, providing a complete balance picture.

### 37A.3 — Backup version 2 with backward compatibility

- `backupVersion` bumped from 1 to 2 in `backup_export.dart`.
- `BackupRestorePreviewService.supportedBackupVersions` = `{1, 2}`.
  - v1 backups (no supplierAccountEntries) are accepted; the restore code uses `_optionalList` which returns `[]` for missing keys.
  - v2 backups include supplierAccountEntries and are accepted.
  - Version 99 is rejected as unsupported.
- All existing backup tests updated to expect version 2.

## How conflicting opening balances are prevented

- **Inventory**: The opening balance button is hidden once a product has an opening balance. The `StockMovement` with the opening balance note serves as the single source of truth.
- **Supplier**: `createOpeningBalanceEntry` checks `hasOpeningBalanceEntry` first and throws `SupplierAccountException` if one already exists. The UI button is hidden after creation.
- Both safeguards prevent duplicate or conflicting opening balances.

## How supplier statement now calculates balance

The supplier statement displays entries in chronological order and calculates a running balance:
- **Opening balance** → appears as a debit entry at the top (increases the owed amount).
- **Purchases** → debit entries (increase the owed amount).
- **Payments** → credit entries (decrease the owed amount).
- **Running balance** = sum of all debits minus all credits up to each row.
- The final balance = opening balance + purchases − payments.

This gives a complete and correct picture of what the warehouse owes each supplier since the beginning.

## Backup v2 compatibility

| Backup version | Preview | Restore |
|---|---|---|
| v1 | Accepted | Works — missing `supplierAccountEntries` resolves to `[]` |
| v2 | Accepted | Works — includes `supplierAccountEntries` |
| Unsupported (e.g. v99) | Rejected | N/A |

## Tests added

File: `test/phase37a_opening_balances_test.dart` — 10 new tests:

1. Supplier opening balance creation succeeds.
2. Duplicate supplier opening balance is rejected.
3. `hasOpeningBalanceEntry` returns true after creation.
4. Negative amount is rejected.
5. Supplier statement displays opening balance entry.
6. Opening balance + purchase combination produces correct running balance.
7. Backup v2 export includes version 2.
8. Backup v1 preview is accepted.
9. Backup v2 preview is accepted.
10. Version 99 is rejected.

## Verification results

- `flutter analyze --no-pub`: 0 errors, 0 warnings, 38 info-only (all pre-existing).
- `flutter test`: 310/310 passed (10 new).
- `flutter build windows --release`: succeeded.
- `git diff --check`: no whitespace errors.
- Working tree is clean.

## Delivery safety

Source code safety check passed. The delivery package contains only:
- `Release/grain_warehouse_erp_lite.exe` and required DLLs/data.
- Owner-facing Arabic documentation:
  - `README-AR.txt`
  - `PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md`
  - `PILOT-RELEASE-NOTES-AR.md`
  - `PILOT-FEEDBACK-FORM-AR.md`
  - `PHASE-26-FIRST-CUSTOMER-TRIAL-START-CHECKLIST-AR.md`
  - `CUSTOMER-TRIAL-DAILY-LOG-AR.md`
  - `PILOT-ISSUE-LOG.md`
  - `PHASE-24-PILOT-FIELD-TRIAL-RUNBOOK-AR.md`
  - `CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md`
  - `RELEASE-NOTES-AR.md`
  - `PHASE-22-PILOT-DELIVERY-CHECKLIST.md`
  - `OWNER-QUICK-START-AR.md`

No `.git/`, `lib/`, `test/`, `tool/`, `build/` intermediates, source archives, or internal developer docs are included.

## Remaining risks

- Opening balance is a manual entry — the owner must ensure the entered amount matches actual pre-existing stock/debt. There is no automated verification.
- Supplier opening balance amounts must be whole EGP (multiples of 100 qirsh). Fractional piasters are not supported for opening balances.
- Inventory opening balance uses stock adjustment movement with a special note — it does NOT create a supplier account entry. Stock opening balance and supplier opening balance are independent concepts.
- Backup v1 → v2 upgrade path is one-directional. Once a v2 backup is created, it cannot be restored by a v1-only version of the app.
