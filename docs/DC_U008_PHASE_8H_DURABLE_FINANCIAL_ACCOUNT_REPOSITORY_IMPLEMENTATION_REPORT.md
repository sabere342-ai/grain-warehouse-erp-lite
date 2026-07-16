# DC-U008 Phase 8H — Durable Financial Account Repository

## Result

Phase 8H migrates the production financial-account repository from process memory to the existing SQLite/Drift database. Baseline `2025148578aa6f81b90df438d5891409db43f44e`; branch `dc-u008-durable-financial-account-repository`; schema v7 → v8. Phase 8I was not started. No push, tag, merge, deploy, or release was performed.

## Contract and scope

The preserved contract covers accounts, active state, negative-balance policy, opening balances and corrections, append-only entries, derived balances/statements, transfers and reversal links, closings/reopening, backup restore, owner wipe, audit participation, approval participation, replay request IDs, and transaction snapshots. Customer, supplier, expense, audit, approval, authentication, and report repositories remain outside the migration scope.

## Schema and migration

Schema v8 adds `financial_accounts`, `financial_account_entries`, `financial_transfers`, and `financial_closings`. Accounts and entries use typed columns; transfers retain request/reference uniqueness and paired entry IDs; closing lines are stored as validated JSON inside the closing aggregate. The v7→v8 migration is additive and creates only these tables. The existing foundation, product, customer, supplier, inventory, purchase, sale, and repository-sequence tables are not recreated or cleared.

The migration test opens a populated v7 database, verifies its foundation row remains, creates a financial account after upgrade, and closes successfully. Existing Phase 8A, 8F, and 8G migration expectations were advanced to the current schema version and their tests pass.

## Ledger and accounting behavior

No current-balance column was introduced. Balance remains the sum of signed immutable entries. Statement ordering and running-balance computation continue to use the characterized local implementation. Opening-balance corrections append compensating entries; reversal and correction IDs, payment methods, approval metadata, and source metadata are persisted.

`DriftFinancialAccountRepository` reuses the characterized validation and accounting rules, hydrates them from Drift on startup, serializes writes, and persists the complete aggregate inside the shared `FoundationDatabase` transaction. External repository rollback snapshots restore both memory and durable rows. No independent SQLite connection is opened.

Transfers persist both paired entries, request ID, display sequence, reference, approval ID, and reversal links. Request replay returns the existing logical transfer. Closings persist date range, expected/actual values, difference inputs, reopening metadata, and posting-lock behavior inherited from the contract.

Restore validates the aggregate before persistence. Wipe clears all four financial tables atomically. Repository counters are restored from aggregate sizes so IDs/display numbers continue beyond restored/restarted state.

## Verification

- Phase 8H focused suite: 7/7 passed twice consecutively.
- Financial/approval regressions: 206/206 passed.
- Phase 8A/8F/8G migration regression group: 22/22 passed.
- Full sequential suite: 1000/1000 passed.
- Full default-concurrency suite: 1003/1003 passed.
- Analyzer: `No issues found`.
- Windows release: built successfully; `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe` exists.
- Drift generation completed successfully and a second generation completed without a source change.
- `git diff --check` passed before final audit.

## Toolchain Recovery Incident

The first attempt stopped as `BLOCKED_PHASE_8H_TOOLCHAIN_UNAVAILABLE` because `dart --version`, `flutter --version`, build_runner, and analyzer appeared to hang inside the command sandbox. Recovery evidence showed no owned stale process, no Zone.Identifier, writable SDK/cache ACLs, and no Defender block for Dart. The same SDK executables completed normally outside the sandbox: Flutter 3.24.5 at `C:\src\flutter`, Dart 3.5.4.

Recovery gates passed twice for version commands, `flutter doctor -v`, `flutter pub get`, `dart run build_runner help`, baseline analyzer, and the Phase 8A focused test. No Flutter cache, lockfile, ACL, security setting, SDK version, channel, or project production file was changed during recovery. Evidence is at `C:\Users\saber\AppData\Local\Temp\phase8h-toolchain-recovery-evidence`. The exact host-level cause was not conclusively proven; execution isolation is the supported inference. Phase 8H production changes began only after the recovery gate passed.

## Audits and residual risk

Intended files are limited to schema/migration, generated Drift code, repository implementation and production wiring, tests, and this report. Runtime databases, WAL/SHM files, logs, and build output are excluded from the commit. The production composition root retains an in-memory fallback for unit/widget contexts that do not initialize the production database, then replaces it with the durable repository during `initializeProduction`.

The existing Flutter SDK checkout contains a pre-existing Windows tooling modification and many untracked SDK files; it was not changed by Phase 8H. Flutter doctor, analyzer, tests, and Windows build nevertheless complete with the pinned SDK revision.
