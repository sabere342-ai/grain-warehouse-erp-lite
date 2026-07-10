# Phase 62 — Data Wipe Sequential Safety Audit

**Date:** 2026-07-10

## Starting Baseline

| Item | Value |
|---|---|
| Phase 61 commit | `ad03002` |
| Phase 61 tag | `phase-61-owner-trial-incident-log-restore-safety-plan` |
| Current delivery package | `delivery/grain_warehouse_erp_lite_phase60_final_production_candidate_20260710-073828/` |
| Test count | 527 |

## Scope

This document audits the current data wipe implementation (`BusinessDataWipeService.wipeBusinessData()`), documents the sequential delete order, evaluates partial-wipe risk, verifies access controls, and presents a safe future plan for making wipe atomic/transaction-safe. No production code is changed in this phase.

## Non-Goals

- No production code changes.
- No implementation of transaction-safe wipe.
- No new backup format.
- No new schema.
- No cloud sync.
- No UI changes.

## Source Code Files Inspected

| File | Purpose |
|---|---|
| `lib/core/backup/business_data_wipe_service.dart` | Main wipe service — orchestrates backup + sequential clear |
| `lib/features/backup/data_wipe_screen.dart` | UI screen — owner guard, confirmation field, warning card |
| `lib/core/auth/permissions.dart` | Permission flags — `canWipeBusinessData` is owner-only |
| `lib/core/auth/auth_service.dart` | Auth service — provides current user with permissions |
| `lib/features/backup/export_backup_screen.dart` | Backup screen — links to data wipe screen |
| `lib/core/backup/backup_export_service.dart` | Backup export — creates JSON backup before wipe |
| `lib/core/sales/sale_repository.dart` | `clearForOwnerDataWipe()` — clears `_sales` and resets ID counter |
| `lib/core/purchases/purchase_repository.dart` | `clearForOwnerDataWipe()` — clears intakes and resets ID counter |
| `lib/core/expenses/expense_repository.dart` | `clearForOwnerDataWipe()` — clears expenses and resets ID counter |
| `lib/core/audit/audit_log_repository.dart` | `clearForOwnerDataWipe()` — clears audit log and resets ID counter |
| `lib/core/catalog/product_repository.dart` | `clearForOwnerDataWipe()` — clears products and resets ID counter |
| `lib/core/customers/customer_repository.dart` | `clearForOwnerDataWipe()` — clears customers and resets ID counter |
| `lib/core/inventory/inventory_repository.dart` | `clearForOwnerDataWipe()` — clears movements and resets ID counter |
| `lib/core/suppliers/supplier_repository.dart` | `clearForOwnerDataWipe()` — clears suppliers and resets ID counter |
| `lib/core/customer_accounts/customer_account_repository.dart` | `clearForOwnerDataWipe()` — clears entries + collections, resets ID counters |
| `lib/core/supplier_accounts/supplier_account_repository.dart` | `clearForOwnerDataWipe()` — clears entries + payments, resets ID counters |
| `lib/core/documents/document_history.dart` | No `clearForOwnerDataWipe()` — history is a computed view from sales + purchases |
| `test/phase17_owner_data_wipe_test.dart` | 14 existing tests covering wipe behavior |

## Current Wipe Behavior (Based on Code Inspection)

### Access Control

Data wipe is guarded at **two levels**:

1. **UI level** (`DataWipeScreen`): `user?.permissions.canWipeBusinessData != true` at the start of `build()` — if the current user is not owner, the screen shows a permission-denied message and does not render any wipe controls.
2. **Service level** (`BusinessDataWipeService.wipeBusinessData()`): `user?.permissions.canWipeBusinessData != true` at line 71 — if the user is not owner, the method returns early with `WipeResult.notAuthorized`.

The `Permissions` class defines:
- `Permissions.owner`: `canWipeBusinessData: true`
- `Permissions.employee`: `canWipeBusinessData: false`

### Confirmation and Warning

Before the wipe proceeds, the user must:

1. **Read the warning** — `DataWipeScreen` displays a `_DangerCopyCard` with Arabic text explaining:
   - This is a dangerous operation.
   - A backup will be created first automatically.
   - Wipe will not proceed if backup creation or save fails.
   - Operating data (products, stock, purchases, sales, document history) will be deleted.
   - Owner account and login data will NOT be deleted.
   - This cannot be undone from within the system except by restoring a valid backup to an empty system.
   - Restore over existing data is still not supported.

2. **Type the exact confirmation phrase** — The user must type `"امسح بيانات التشغيل"` (Arabic: "Wipe operating data") into a text field. The service method checks `_normalized(typedConfirmation) == _normalized(confirmationPhrase)` and returns `WipeResult.confirmationMismatch` if they don't match.

### Backup Requirement

Before ANY data is cleared, the wipe service:

1. Creates a backup using `BackupExportService.exportToDirectory()`.
2. Validates the backup result (`BackupExportResult.success`).
3. Saves the backup to disk.

If the backup fails (returns error or throws), the wipe is blocked entirely — no data is deleted. The success message states: "تم إنشاء النسخة الاحتياطية ثم مسح بيانات التشغيل بنجاح."

### Sequential Delete Order

After successful backup, `clearForOwnerDataWipe()` is called on each repository **sequentially** in this exact order:

| Step | Repository | What is cleared |
|---|---|---|
| 1 | AuditLogRepository | Audit log entries, ID counter reset |
| 2 | ExpenseRepository | Expenses, ID counter reset |
| 3 | CustomerRepository | Customers, ID counter reset |
| 4 | CustomerAccountRepository | Customer account entries + collections, both ID counters reset |
| 5 | SaleRepository | Sales, ID counter reset |
| 6 | PurchaseRepository | Purchase intakes, ID counter reset |
| 7 | SupplierAccountRepository | Supplier account entries + payments, both ID counters reset |
| 8 | InventoryRepository | Stock movements, ID counter reset |
| 9 | SupplierRepository | Suppliers, ID counter reset |
| 10 | ProductRepository | Products, ID counter reset |

### Document History

`LocalDocumentHistoryRepository` does **not** have a `clearForOwnerDataWipe()` method. Document history is a **computed read-only view** built from:
- Sales (from `SaleRepository`)
- Purchases (from `PurchaseRepository`)
- Inventory movements (from `InventoryRepository`)
- Products (from `ProductRepository` — for name lookup)

After wipe clears sales, purchases, inventory movements, and products, the document history view naturally returns an empty list. No explicit clear is needed.

### What Is NOT Wiped

- **Owner account** — `AuthService` session remains intact.
- **User login data** — The owner can continue using the app immediately after wipe.
- **The app itself** — No files are deleted from disk (except backup artifacts are created, not deleted).

### Error Handling

The wipe method is wrapped in a `try-catch` block. If any `clearForOwnerDataWipe()` call throws:

1. The catch block returns `WipeResult.error('...')`.
2. Data already cleared before the exception **remains cleared** — there is no rollback.
3. Data not yet cleared at the time of the exception **remains in memory**.

### Test Coverage (14 tests)

`test/phase17_owner_data_wipe_test.dart` covers:

| # | Test Case | What It Verifies |
|---|---|---|
| 1 | Owner can wipe business data | Owner with confirmation succeeds |
| 2 | Wipe clears all categories | All 10 repository categories have 0 items after wipe |
| 3 | Auth persists after wipe | Owner still logged in, can access the app |
| 4 | Backup failure blocks wipe | If backup export fails, no data is cleared |
| 5 | Non-owner cannot wipe | Employee role gets notAuthorized result |
| 6 | Counts are reported before wipe | `_currentCounts()` sums all repository item counts |
| 7 | Wipe clears specific categories individually | Each category count drops to zero after wipe |
| 8 | Backup file is created before wipe | Backup file exists on disk after successful wipe |
| 9 | Confirmation mismatch blocks wipe | Wrong phrase returns confirmationMismatch |
| 10 | Wipe result types are correct | notAuthorized, confirmationMismatch, success, error are distinct |
| 11 | Owner sees wipe UI | Owner can navigate to wipe screen and see the form |
| 12 | Non-owner sees permission denied | Employee sees warning message, no wipe controls |
| 13 | Wipe success message is in Arabic | Result.message contains Arabic text |
| 14 | Wipe screen has confirmation field | Confirmation text field accepts and compares input |

## Current Risk: Partial Wipe

### Scenario

If the `wipeBusinessData()` method is interrupted after some `clearForOwnerDataWipe()` calls have completed but before others:

1. Backup has already been saved (safe — can be used for restore).
2. Repositories cleared so far are now empty.
3. Repositories not yet cleared still contain data.
4. The app remains in a partially-wiped state.

### Risk Assessment in Current Architecture

In the current **single-session in-memory architecture**:

- **App crash** during wipe loses the entire in-memory state — the app restarts fresh with no data. The only surviving artifact is the backup file on disk.
- **Normal exception** during wipe causes the try-catch to return an error. The remaining uncleared repositories still hold their data, while cleared repositories are empty. The app continues running in an inconsistent state.
- **The backup file on disk** is always complete because it is saved before any clear operation. The owner can restore this backup to a fresh app instance.

**Risk level: LOW** for crash-in-the-middle (in-memory state lost entirely).
**Risk level: MEDIUM** for exception-in-the-middle (app continues running with partial data).

### Mitigation Recommendations

1. **Current mitigation already present**: Backup is created and saved before any clear. A complete data snapshot exists on disk before any destructive operation.
2. **Current mitigation already present**: The warning screen explains this cannot be undone except via restore.

## Safety Requirements for Future Implementation

1. **Validate backup before clearing data** — Already done (backup is created and validated first).
2. **Create pre-wipe safety backup** — Already done (backup is automatic and mandatory).
3. **Use atomic clear or equivalent safe approach** — Replace sequential per-repository clears with a single clear-all operation that either fully succeeds or does nothing.
4. **Rollback path if clear fails** — Keep the pre-wipe backup for automatic rollback (currently manual — owner must restore).
5. **Preserve backup format compatibility** — Continue to support v1 and v2 backup formats.
6. **Preserve accounting integrity** — The clear order already respects dependencies (customer accounts before sales, inventory before suppliers and products). Future implementations must maintain this order.
7. **Never leave app in partially-wiped state** — If clear fails mid-way, the app should either complete the clear or roll back to the pre-wipe state.

## Proposed Future Algorithm

```
1. Verify owner permission (already done).
2. Verify confirmation phrase (already done).
3. Create and save pre-wipe backup (already done).
4. If backup succeeds, perform wipe as an atomic operation:
   a. Snapshot current in-memory state (references to all lists).
   b. Create new empty lists for all repositories.
   c. Atomically swap all repository lists at once.
   d. If any list creation fails, revert to the snapshot.
5. If wipe fails mid-way:
   a. Restore from the pre-wipe backup automatically (future).
   b. Report detailed error to the user.
   c. Never leave the app with partially cleared data.
```

## Relation to Phase 61 (Backup-Restore Safety)

The Phase 61 audit documented that `BackupRestoreService.restoreToEmpty()` writes data sequentially without a transaction. The data wipe has the same pattern but in reverse — it clears repositories sequentially.

Both features share the same root cause: the current in-memory repositories do not expose transactions. A future persistent database engine would resolve both issues simultaneously.

## Decision

**Phase 62 does not implement transaction-safe wipe.**

The current in-memory architecture has the following characteristics:

1. The backup is created and saved **before** any clear operation — a complete data snapshot always exists.
2. In case of a crash during wipe, the in-memory state is lost entirely and the app restarts with an empty system. The backup file on disk remains usable.
3. In case of an exception during wipe (not a crash), the app continues with partially cleared data. The owner can restore from the pre-wipe backup.

Therefore:

1. The partial-wipe risk is **LOW** in the current architecture.
2. Implementing transaction-safe wipe would require the same architectural change as transaction-safe restore (persisted database engine).
3. This change is not justified during the single-client pilot phase.

**Transaction-safe wipe is planned for a future phase** when:
- The app adopts a persistent on-disk database engine (e.g., SQLite via `sqflite` or `drift`).
- Transaction-safe restore is also implemented.
- The pilot validates demand for this safety guarantee.

## Files Changed

| File | Change |
|---|---|
| `docs/PHASE-62-DATA-WIPE-SEQUENTIAL-SAFETY-AUDIT.md` | New — this document |
| `docs/DATA-WIPE-SAFETY-GUIDE-AR.md` | New — Arabic owner guide for data wipe |
| `docs/PHASE-62-DATA-WIPE-SEQUENTIAL-SAFETY-SUMMARY.md` | New — summary document |
| `docs/DEVELOPER-HANDOFF-NOTES.md` | Updated — added Phase 62 section |
| `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md` | Updated — added data wipe checklist items |
| `docs/PILOT-RELEASE-NOTES-AR.md` | Updated — added Phase 62 release note |
| `docs/OWNER-QUICK-START-AR.md` | Updated — added data wipe section |
| `docs/OWNER-TRIAL-INCIDENT-LOG-AR.md` | Updated — added data wipe safety note to daily checklist |
| No production code changes | — |

## Verification Results

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | No issues found |
| `flutter test` | 527/527 passed |
| `flutter build windows --release` | Succeeded (usual CMake/MSVCRT warnings only) |
| `git diff --check` | Clean (expected CRLF warnings only) |
| `git status --short` | Clean after commit |

## Remaining Limitations

- Data wipe is still not transaction-safe (documented — planned for future phase when persistent on-disk database is introduced).
- Restore has the same sequential non-transactional pattern (documented in Phase 61).
- This document is an audit only; no implementation was done.

## Final Conclusion

The data wipe implementation in the current in-memory architecture is functionally correct for the single-session pilot scenario. The backup-before-wipe guarantee ensures a complete data snapshot always exists before any destructive operation. The risk of partial-wipe corruption is low because a crash during wipe loses the in-memory state entirely. Transaction-safe wipe should be implemented alongside a persistent on-disk database engine and transaction-safe restore in a future phase, following the algorithm documented here.
