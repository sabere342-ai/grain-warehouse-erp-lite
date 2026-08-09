# Phase 107B — Atomic Business-Data-Wipe Contract

## 1. Phase identity

Phase 107B makes the owner-only business-data wipe all-or-nothing, proves
rollback with deterministic failure injection, and makes failure reporting
match the final persistent state.

## 2. Baseline

Governing baseline: `c85f191a981d7e8a06f08990588b3ba84d47c04e`
(`PHASE 107A: prove post-review system status and remaining work`). The
worktree was clean and HEAD matched this commit before editing.

## 3. Final commit

This report is part of the single Phase 107B commit with subject
`PHASE 107B: make business data wipe atomic`. Its exact hash is recorded by
the post-commit lineage proof and final task response because a commit cannot
contain its own hash.

## 4. Outcome

**Outcome A — FULL SUCCESS.** The durable transaction, success and empty
paths, four rollback positions, truthful messages, full tests, analyzer,
formatting, Windows release build, scope, and Git gates all pass.

## 5. Governing Phase 107A finding

R1-001 stated that sequential destructive operations could partially commit
while the broad catch reported that no data had been deleted. This phase
closes R1-001 only.

## 6. Pre-change architecture

`DataWipeScreen` called `BusinessDataWipeService.wipeBusinessData`. The service
created, validated, previewed, and saved a backup, read pre-wipe counts, then
called 13 repository clear methods sequentially. Production repositories were
all composed over the single `AppRepositories.database` `FoundationDatabase`,
but the wipe service had no shared transaction runner. Several durable
repositories also maintain cached/local delegates, for which the existing
`TransactionSnapshotProvider` contract is the governed cache rollback seam.

## 7. Business-data wipe entrypoint

UI entrypoint: `lib/features/backup/data_wipe_screen.dart`, `_wipe`.
Service entrypoint: `lib/core/backup/business_data_wipe_service.dart`,
`BusinessDataWipeService.wipeBusinessData`.

## 8. Exact targeted business domains

The unchanged destructive contract targets negative-balance approval requests
and transitions, audit logs, expenses, customers, customer account data,
sales, purchases, supplier account data, inventory valuation activation/state/
events, inventory movements, suppliers, products, and financial accounts/
entries/transfers/closings. Document history is derived from the cleared
purchase, sale, product, and inventory sources and is empty after success.

## 9. Preserved domains

Authentication accounts, owner/session identity, roles, business identity,
application configuration, schema metadata, and other non-business/system
configuration remain outside the wipe. The durable success test snapshots and
compares the `auth_accounts` rows before and after wipe. Historical policy
classifies audit logs as operating data, so they remain intentionally targeted.

## 10. Pre-fix deletion order

1. Negative-balance approval requests
2. Audit logs
3. Expenses
4. Customers
5. Customer accounts
6. Sales
7. Purchases
8. Supplier accounts
9. Inventory valuation
10. Inventory movements
11. Suppliers
12. Products
13. Financial accounts

The same dependency-safe order is retained inside the transaction.

## 11. Pre-fix failure semantics

Every clear was awaited and could commit independently. A later exception was
caught by the same catch used for backup failure. The returned Arabic message
claimed backup failure and claimed that no data would be deleted even when
earlier repository deletes had already committed.

## 12. Root cause

The service coordinated repositories but did not receive the shared database
transaction boundary. Its single broad try/catch also conflated backup,
preparation, and destructive failures.

## 13. Frozen atomicity contract

- Success: every targeted domain is empty, preserved data is unchanged, and
  the pre-wipe counts are returned.
- Failure before mutation: failure is returned and business state is unchanged.
- Failure after any destructive step: every prior deletion is rolled back,
  persistent and cached state equal the pre-wipe state, and failure is returned.
- Empty state: a valid backup and zero-count wipe succeeds deterministically.

## 14. Transaction boundary chosen

`AppRepositories.businessDataWipeService` injects
`(operation) => database.inTransaction(operation)`. The service invokes this
runner immediately before the first destructive step and returns from it only
after the final financial-account clear. Inside it,
`RepositoryTransaction.execute(_transactionSnapshots(), operation)` captures
and governs all 13 repository participants.

## 15. Production implementation changes

- `lib/core/backup/business_data_wipe_service.dart`: requires the transaction
  runner, captures repository snapshots, executes all 13 clears inside one
  boundary, exposes a narrow step hook for deterministic tests, and separates
  backup, preparation, and rolled-back wipe failures.
- `lib/app/app_repositories.dart`: supplies the one production
  `FoundationDatabase.inTransaction` runner.

No UI production file changed.

## 16. Why the boundary guarantees rollback

All production repositories share the injected `FoundationDatabase`. Nested
repository transactions therefore execute under the outer Drift transaction.
An exception first causes `RepositoryTransaction` to restore snapshot-backed
cached delegates in reverse order and rethrow. The rethrow escapes the outer
callback, so Drift rolls the database transaction back and rethrows. The
service catches only after this boundary has completed its rollback. No
destructive repository call exists outside the governed callback.

## 17. Error/reporting semantics

Backup creation/validation/save failure remains `backup-required-failed` and
truthfully states that no delete began. Count/preparation failure is now
`wipe-preparation-failed` and truthfully states that no data was deleted. Any
destructive failure is `business-data-wipe-rolled-back`; its Arabic message
states that the operation was rolled back and no partial deletion was adopted.
Success is returned only after the transaction commits.

## 18. Failure injection mechanism

`BusinessDataWipeStepHook` is an optional, synchronous, deterministic seam
called immediately before each named destructive step. Production supplies no
hook. Tests throw at a selected enum step; no timing, race, sleep, or debug
mode is involved.

## 19. F1 result

Injected before `negativeBalanceApprovalRequests`, before any delete: PASS.
Zero mutation; persistent and cached snapshots equal the pre-wipe state.

## 20. F2 result

Injected before `auditLogs`, after the first clear executed: PASS. Full
rollback; persistent and cached snapshots equal the pre-wipe state.

## 21. F3 result

Injected before `purchases`, after six earlier steps executed: PASS. Full
rollback; persistent and cached snapshots equal the pre-wipe state.

## 22. F4 result

Injected before final `financialAccounts`, after twelve earlier steps
executed: PASS. Full rollback; persistent and cached snapshots equal the
pre-wipe state.

## 23. State equality / rollback proof

For every failure, the test snapshots every non-SQLite-internal database table
as sorted full-row representations, including IDs, quantities, money,
relationships, documents, valuation, approvals, audit, sequences, and auth.
The complete map is equal after rollback. It separately compares cached sale
IDs, valuation event IDs, financial-account IDs, and account balances to prove
that durable rollback did not leave delegate caches stale.

## 24. Success-path proof

A populated Drift database containing product, supplier, customer, purchase,
two inventory movements, sale, expense, audit, financial account and entries,
inventory valuation, and a negative-balance approval request is wiped. All 13
target repositories and derived document history are empty, the result is
successful, and reported counts match the pre-wipe data.

## 25. Empty-state proof

A durable database with only the preserved owner auth row produces a valid
backup, returns success with all nine reported counts equal to zero, leaves all
business domains empty, and preserves the auth row.

## 26. Preserved-data proof

`auth_accounts` is captured before both populated and empty-state success
tests and is identical afterward. The service never receives or clears the
auth, business identity, or configuration repositories.

## 27. Accounting regression safety

No accounting calculation, valuation rule, COGS rule, balance rule, payment
routing rule, opening balance, closing, or journal creation logic changed.
The rollback fixture includes monetary values, an opening balance, an expense
entry, account balance, purchase/sale totals, and valuation state. Full tests
pass.

## 28. Product-read regression safety

`_currentCounts` still uses
`ProductCatalogReadRepository.listProductCatalog(includeInactive: true)` and
`List.length`. No legacy product read or read-model expansion was introduced.
The Phase 106AF focused tests pass.

## 29. Focused tests

`test/phase107b_atomic_business_data_wipe_test.dart`: 7 passed. Existing Phase
17 wipe/UI, Phase 18 lifecycle/restore-adjacent, Phase 106AF counts, and four
Phase 106 exact production-scope suites also pass. The 20 stale Phase 106
lineage guards were made descendant-safe with `git merge-base`; they retain
their exact historical checks for pre-107A heads and now accept the committed
107A baseline and descendants.

## 30. Full test-suite result

PASS in 380.6 seconds: **2,375 passed, 1 historical skip, 0 failed**. No skip
was added. Baseline was 2,368 passed, 1 skipped, 0 failed; Phase 107B adds seven
passing tests.

## 31. Analyzer result

PASS: `flutter analyze` reported `No issues found!`.

## 32. Formatting result

PASS: the Dart formatter gate scanned 420 files with zero pending changes
before the final documentation/Git checks. It is rerun after all Dart edits.

## 33. Windows Release result

PASS: `flutter build windows --release` built
`build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`. The first
link attempt was blocked by a running copy of that exact workspace EXE; after
stopping only PID 1120, the rebuild completed in 19.6 seconds. A final clean
verification rerun also passed in 40.0 seconds. Existing CMake
deprecation and LNK4078 warnings were non-fatal.

## 34. Production diff

Exactly two production files changed: the service and composition root listed
in section 15. No UI, repository implementation, accounting, or unrelated
production file changed.

## 35. Schema diff

None. Schema version remains 15; no migration or generated database file
changed.

## 36. Dependency diff

None. `pubspec.yaml` and `pubspec.lock` are unchanged.

## 37. Remaining known findings from 107A

R1-001 is closed. Remaining counts are R0=0, R1=5, R2=7, R3=7. Unexecuted
items include checksum verification, packaging/installer, fresh-machine and
genuine-client acceptance, client documentation correction, encryption and
security hardening, broad foreign-key work, the historical skipped transfer
test, broad UI acceptance, observability, demo credential hygiene, cloud/
mobile work, and PRC-114 through PRC-118 infrastructure/test consumers.

## 38. Git lineage proof

Before commit: HEAD is `c85f191a981d7e8a06f08990588b3ba84d47c04e`
and the tree began clean. After commit, required proof is: `HEAD^` equals that
baseline, `rev-list --count baseline..HEAD` equals 1, and `git diff --check
HEAD^ HEAD` is clean.

## 39. Final tree state

The intended final state is one Phase 107B commit after the baseline and a
clean worktree. Build output is ignored and no executable, dump, temporary
file, push, tag, merge, or external publication is included.

## 40. Recommended next atomic phase

Phase 107C — Backup Restore Checksum Verification Contract. Verify the stored
checksum before preview success or restore writes, with valid, corrupted,
tampered, and rollback-safe tests. Do not combine it with installer,
encryption, schema, or client-acceptance work.

## Negative proof summary

Before Phase 107B, each awaited clear could commit before a later clear threw,
and the broad catch then claimed a backup failure and no deletion. After Phase
107B, every clear is inside one rollback-capable Drift transaction, cached
delegates participate through repository snapshots, exceptions rethrow through
both layers, and the service reports the rolled-back outcome only after the
boundary finishes.
