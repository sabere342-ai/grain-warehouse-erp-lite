# Phase 104H — Controlled Audit Log Read Failure & Runtime Integration

## Outcome

**Outcome B — SAFE BLOCKED: GLOBAL FULL SUITE STILL FAILS IN PHASE 102J**

The Phase 104H Audit Log contract is implemented and its focused gates pass.
The global suite is not green because the previously known Phase 102J
profitability test still has the same isolated failure. This commit must not be
used as the governing baseline for the next phase.

## Starting point and branch

- Starting branch:
  `codex/phase-104g-genuine-runtime-audit-log-acceptance-architecture-freeze`
- Starting HEAD: `ea703135cadf0230fa6fd0aa8531344cd717bf27`
- Phase branch:
  `codex/phase-104h-controlled-audit-log-read-failure-runtime-integration`
- Final commit: the single commit containing this report, with message
  `PHASE 104H: handle audit read failures and prove runtime integration`.
  Its exact hash is recorded in the final handoff after Git creates it.

The starting worktree was clean, the branch and HEAD matched the required
starting point, and `git diff --check` passed before any change.

## Files changed

- `lib/core/audit/audit_log_controller.dart`
- `lib/features/audit/audit_logs_screen.dart`
- `test/phase104e_atomic_audit_log_read_contract_migration_test.dart`
- `test/phase104h_controlled_audit_log_read_runtime_integration_test.dart`
- `docs/PHASE-104H-CONTROLLED-AUDIT-LOG-READ-FAILURE-RUNTIME-INTEGRATION.md`

No Phase 102J file was modified.

## Previous defect and new controller contract

Previously, `AuditLogController.loadLogs()` set `isLoading` before awaiting
`listAuditLogs()`, but had no error boundary. A repository exception escaped to
the caller and skipped the statements that reset `isLoading`, leaving the
controller indefinitely loading. The Phase 104E test explicitly froze this
incorrect behavior.

The controller now:

1. sets `isLoading=true`, clears `errorMessage`, and notifies at the start;
2. stores the returned `AuditLogReadModel` list without sorting or remapping;
3. contains repository exceptions and returns `false` instead of exposing an
   unhandled asynchronous exception;
4. publishes the safe Arabic message
   `تعذر تحميل سجل التدقيق. حاول مرة أخرى.`;
5. always resets `isLoading=false` in `finally` and notifies the settled state;
6. preserves the last successful entries when a later refresh fails; and
7. suppresses notifications after controller disposal.

An initial failure therefore leaves an empty list plus an explicit error. A
refresh failure leaves cached models visible plus an independent error state.
Starting a retry clears the old error immediately, and a successful retry
settles with data and no error.

## Screen behavior and retry

`AuditLogsScreen` now represents all required states:

- loading: the standard loading state;
- successful data: Audit Log cards based only on `AuditLogReadModel`;
- successful empty result: the existing Arabic empty state;
- initial failure without cached data: error icon, safe Arabic message, and
  `إعادة المحاولة` action;
- refresh failure with cached data: the previous cards remain visible under a
  non-blocking warning with a retry action.

The post-frame initial load checks `mounted`, retry and initial load use the same
method, and the controller owns exception containment. Widget tests prove the
`failure -> loading -> success` retry transition and verify that no exception is
reported through `tester.takeException()`.

## SQLite reopen to production composition integration

`test/phase104h_controlled_audit_log_read_runtime_integration_test.dart`
contains one real, linked runtime test which:

1. creates a unique temporary directory and SQLite file;
2. opens the file with the production database opener;
3. writes two real Audit Log entries through the approved Drift write
   repository;
4. fully closes the database;
5. reopens the same SQLite file;
6. calls `AppRepositories.initializeProduction(databaseFactory: ...)`;
7. obtains the injected `AuditLogReadRepository` and proves it is the production
   `DriftAuditLogRepository`;
8. constructs `AuditLogController`, calls `loadLogs()`, and proves settled
   success; and
9. compares `id`, timestamp instant, `descriptionAr`, `referenceId`, and the
   frozen timestamp-then-id descending order.

### Database isolation

Before opening SQLite, the test asserts that the absolute database path is
inside its own temporary directory, is outside the real `%APPDATA%` directory,
and does not use `grain_warehouse_erp.sqlite3`, the Windows production database
file name. All database resources are closed and the temporary directory is
deleted in teardown. No customer or production database was touched.

## Architectural search

The required searches were run across `lib`, `test`, and `tool`:

- `rg -n "listLogs\s*\(" lib test tool`: zero matches;
- `AuditLogEntry`: limited to write/storage, backup/restore, and necessary test
  fakes/fixtures; neither the controller nor screen uses it;
- `AuditLogReadModel`: the screen/controller/read repositories and focused tests
  use the frozen four-field read model;
- `AuditLogReadRepository`: the controller depends on this abstraction, not on
  Drift;
- `DriftAuditLogRepository`: production composition still injects it; direct
  construction remains limited to storage/runtime tests and the existing
  isolated Phase 102J tool.

There is no legacy public `listLogs()` read surface, no Audit Log cloud/backend
implementation, no schema change, and no migration.

## Verification gates

| Gate | Result |
| --- | --- |
| Phase 104H tests | PASS — 8 passed, 0 failed, 0 skipped |
| Focused Audit Log suite (8I, 104B/C/E/F/G/H) | PASS — 42 passed, 0 failed, 0 skipped; exit 0; 16.2 s |
| SQLite reopen integration | PASS — real file, close/reopen, production composition, controller |
| Widget failure/retry coverage | PASS — loading, data, empty, initial failure, retry, cached refresh failure |
| Full Suite | FAIL — 1943 passed, 1 failed, 1 skipped; exit 1; 175.1 s |
| Analyzer | PASS — `No issues found!`; 103.7 s |
| Formatting | PASS — direct Dart SDK, 4 changed Dart files, 0 changed by final check |
| `git diff --check` | PASS |
| Windows Release build | PASS — exit 0; Flutter reported 73.3 s |
| Native smoke | NOT EXECUTED — production database isolation was not proven safe for native application launch |

The normal `dart.bat` wrapper hung before producing output. Formatting therefore
used `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe` directly. Flutter gates
used that same Dart executable with
`C:\src\flutter\bin\cache\flutter_tools.snapshot`. The final formatting check
changed no files.

### Full Suite blocker and skip

The only failure is the previously known, out-of-scope blocker:

- file: `test/phase102j_synthetic_profitability_activation_test.dart`
- test: `sandbox activation produces COGS and a synthetic profitability report`
- location: line 148
- expected: `250000`
- actual: `0`

The single skipped test is in
`test/phase9a_inflows_outflows_reports_test.dart` at line 552 with the existing
reason `Requires negative balance approval with actual credentials`.

Phase 102J was not modified or repaired. Production profitability remains in
the frozen `profitabilityNotActivated` state; the related focused architecture
test passes. The Phase 102J failure requires its own atomic phase.

## Windows artifact

- Path:
  `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes
- SHA-256:
  `ACFCC654CA3A17A904CECDB16FEC320C7A93A366CB89F2631087CA0E67D702FF`
- Non-blocking build diagnostics: Firebase CMake minimum-version deprecation
  warning and linker warning `LNK4078` about `.voltbl` sections.

## Final safety statements

- Repository exceptions no longer escape `loadLogs()`.
- `isLoading` cannot remain true after repository success or failure.
- Retry works and a failed refresh preserves the last successful data.
- The test used only its isolated temporary SQLite file.
- No schema, migration, Firebase, Supabase, REST, or cloud/backend work was
  added.
- No profitability logic or production activation state was changed.
- No Phase 102J file was changed.
- Full Suite is not green, so the final Phase 104H commit is not a governing
  baseline despite all Phase 104H gates passing.
