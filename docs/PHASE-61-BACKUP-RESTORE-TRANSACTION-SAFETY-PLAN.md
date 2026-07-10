# Phase 61 — Backup-Restore Transaction Safety Plan

**Date:** 2026-07-10

## Starting Baseline

| Item | Value |
|---|---|
| Phase 60 commit | `94bdfef` |
| Phase 60 tag | `phase-60-final-production-candidate-packaging` |
| Current delivery package | `delivery/grain_warehouse_erp_lite_phase60_final_production_candidate_20260710-073828/` |
| Test count | 527 |

## Scope

This document investigates the current backup/restore implementation and presents a safe future implementation plan for making restore atomic/transaction-safe. No production code is changed in this phase.

## Non-Goals

- No production code changes.
- No implementation of transaction-safe restore.
- No new backup format.
- No new schema.
- No cloud sync.
- No UI changes.

## Current Restore Behavior (Based on Code Inspection)

The restore implementation is in `lib/core/backup/backup_restore_service.dart`, method `restoreToEmpty()`. The flow is:

1. **Permission check** — only owner can restore.
2. **Preview validation** — `BackupRestorePreviewService.preview()` validates JSON structure, backup version (v1 or v2), checksum, sensitive key detection, and count-data consistency.
3. **Full parse** — `_parseBackupData()` parses all JSON into in-memory Dart objects (products, suppliers, movements, purchases, sales, customers, customer accounts, supplier accounts, expenses, audit logs).
4. **Relationship validation** — `_validateRelationships()` checks cross-references (e.g., every movement references a valid product, every purchase references valid product/supplier/movement, sale totals match line items).
5. **Empty-system check** — `_checkEmptySystem()` queries every repository; if any data exists, restore is rejected.
6. **Sequential writes** — Data is written to repositories one by one in this order:
   - `restoreProductsIntoEmpty`
   - `restoreSuppliersIntoEmpty`
   - `restoreMovementsIntoEmpty`
   - `restorePurchaseIntakesIntoEmpty`
   - `restoreSalesIntoEmpty`
   - `restoreCustomersIntoEmpty`
   - `restoreCustomerAccountsIntoEmpty`
   - `restoreSupplierAccountsIntoEmpty`
   - `restoreExpensesIntoEmpty`
   - `restoreAuditLogsIntoEmpty`
7. **No transaction** — The source code explicitly states on lines 103–104:
   > "The current in-memory repositories do not expose transactions."
8. **Error handling** — If any write throws, the outer catch block returns a failure result. However, data written before the failure remains in the in-memory repositories.

The data wipe (`BusinessDataWipeService.wipeBusinessData`) follows the same sequential non-transactional pattern: backup is taken first, then each repository's `clearForOwnerDataWipe()` is called sequentially.

## Current Risk

### Partial Restore / Corruption Risk

If the restore process is interrupted after some writes have completed (app crash, power loss, system shutdown), the in-memory repositories will contain a partial data set:

- Some entity types will have data (e.g., products, suppliers, movements)
- Others will be empty (e.g., sales, customer accounts)
- The system is no longer "empty" — re-running restore will fail the empty-system check
- Cross-references will be broken: e.g., a sale references a movement that exists, but the customer account entry for that sale is missing

In the current single-session in-memory architecture, this risk is primarily theoretical for the following reasons:
- The app runs as a single Windows process with in-memory SQLite databases
- A power loss or crash during restore would lose the entire in-memory state
- On restart, the app starts fresh with an empty system
- The real risk would materialize if restore were writing to a persisted database (e.g., SQLite on disk) with sequential writes and no transaction

### Audit Trail Gap

If a partial restore leaves the system in an inconsistent state, there is no rollback mechanism. The only recovery option is manual data wipe and re-restore.

## Safety Requirements for Future Implementation

1. **Validate backup before replacing active data** — Already done (preview service validates JSON structure, version, and counts before any write).
2. **Create pre-restore safety backup** — Automatically backup the current state before any destructive write.
3. **Restore into temporary database/file first** — Write restored data to a temporary location before activating.
4. **Verify restored data before activation** — Open the temporary restored database, run integrity checks, and verify schema compatibility.
5. **Atomic swap or equivalent safe replacement** — Replace the active database file with the verified restored file atomically (e.g., file rename on the same volume).
6. **Rollback path if activation fails** — Keep the pre-restore safety backup and a copy of the original database for rollback.
7. **Preserve old backup compatibility** — Continue to support v1 and v2 backup formats.
8. **Preserve accounting integrity** — All cross-references (product → movement, purchase ↔ movement, sale ↔ customer account) must be verified before activation.
9. **Never leave app in half-restored state** — The activate step must be atomic; if it fails, the app continues with the original database.

## Proposed Future Algorithm

```
1. Close active database connections safely.
2. Validate selected backup file (preview + parse + relationship validation).
3. Check system is empty or prompt for confirmation if not empty.
4. Create pre-restore safety backup of current state.
5. Copy current database file to a pre-restore backup location.
6. Restore selected backup data into a temporary SQLite database.
7. Open the temporary database and run:
   a. PRAGMA integrity_check
   b. Schema version verification
   c. Count verification against expected values
   d. Key relationship spot checks
8. If all checks pass, atomically activate:
   a. On Windows: use file rename (same volume) to swap the temporary DB with the active DB
   b. The rename is near-atomic on the same filesystem volume
9. Reopen all repositories against the new active database.
10. Verify the app can read core records (products, sales, etc.).
11. If any step fails:
    a. Restore original database from pre-restore safety backup
    b. Report detailed error to the user
    c. Never leave the app with a partially written database
```

## Test Plan for Future Implementation

| Test Case | Description |
|---|---|
| Successful restore | Full backup restores correctly; all records match original |
| Invalid backup rejected | Bad JSON, wrong version, missing fields all rejected before any write |
| Interrupted restore simulation | Simulate crash mid-write; verify previous state is intact on recovery |
| Schema compatibility | Backup with older schema version is rejected or upgraded |
| Old backup compatibility | v1 and v2 backups restore correctly |
| Accounting balances preserved | Customer/supplier balances match after restore |
| Stock quantities preserved | Inventory quantities match after restore |
| Restore does not expose source files | Same source-safety scan as delivery package |
| Pre-restore backup created | Safety backup is created before any write |
| Rollback on validation failure | If restored data fails integrity check, original data is preserved |

## Decision

**Phase 61 does not implement transaction-safe restore.**

The current in-memory architecture does not use a persisted SQLite database. Restore writes to in-memory repositories sequentially. In case of a crash, the in-memory state is lost entirely and the app restarts with an empty system. Therefore:

1. The partial-restore risk is **low** in the current architecture.
2. Implementing transaction-safe restore would require a significant architectural change (persisted database engine, file-level atomic swap).
3. This change is not justified during the single-client pilot phase.

**Transaction-safe restore is planned for a future phase** when:
- The app adopts a persistent on-disk database engine (e.g., SQLite via `sqflite` or `drift`)
- Multi-session data persistence is required
- The pilot validates demand for this safety guarantee

## Files Changed

| File | Change |
|---|---|
| `docs/PHASE-61-BACKUP-RESTORE-TRANSACTION-SAFETY-PLAN.md` | New — this document |
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

- Restore is still not transaction-safe (documented — planned for future phase when persistent on-disk database is introduced).
- Data wipe (`BusinessDataWipeService`) has the same sequential non-transactional pattern.
- This document is a plan only; no implementation was done.

## Final Conclusion

The backup/restore implementation in the current in-memory architecture is functionally correct for the single-session pilot scenario. The risk of partial restore/corruption is low because a crash during restore loses the in-memory state entirely. Transaction-safe restore should be implemented alongside a persistent on-disk database engine in a future phase, following the algorithm and test plan documented here.
