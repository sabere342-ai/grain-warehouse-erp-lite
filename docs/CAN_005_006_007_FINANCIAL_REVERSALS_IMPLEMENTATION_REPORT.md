# CAN-005 / CAN-006 / CAN-007 — Financial Reversals Implementation Report

## Baseline and scope

- Baseline: `af56ced8b68c6a2604973aff6d0e6447edaeee94`
- Branch: `can-005-006-007-financial-reversals`
- CAN-005: cancel a customer collection with a compensating customer-ledger entry.
- CAN-006: cancel a supplier payment with a compensating supplier-ledger entry.
- CAN-007: create the linked financial-account compensating entry for either cancellation.

No deployment, tag, merge, secret change, or change to
`MASTER-PROJECT-EXECUTION-PLAN-AR.md` was made.

## Design

Each cancellation is a new immutable operation, not a mutation that erases the
posted collection or payment. The original record receives immutable
cancellation metadata containing the cancellation id, actor, reason, time, and
the identifiers of its compensating movements.

The state transition is `posted -> cancelled`. A cancellation requires an
active owner, a non-empty reason, and a unique operation request id. Reusing a
request id, retrying an already cancelled source record, and concurrent attempts
are rejected. The global `RepositoryTransaction` serialization makes the result
deterministic.

For a linked financial account, CAN-005 writes an outflow and CAN-006 writes an
inflow. Both use `FinancialAccountEntrySource.cancellationReversal`, retain the
original financial entry, and link to it through `reversalOf`. If the original
record claims a financial account but its original entry is absent, cancellation
fails closed. Existing financial-account negative-balance controls remain in
force; no approval path is bypassed.

The cancellation boundary snapshots the affected customer/supplier repository,
financial account repository, and audit repository. A failed ledger, financial
entry, or audit write restores collection/payment status, ledger entries,
financial balance, generated ids, request-id guards, and audit records.

## Reporting, backup, and UI

Cancelled collections and payments are excluded from dashboard and daily-report
cash totals while their immutable original and reversal ledger lines remain
visible in statements. Backup export/restore preserves cancellation metadata and
the linkage identifiers. Customer and supplier statement labels render the new
compensating-entry types.

## Test evidence

- `test/can_005_006_007_financial_reversals_test.dart`: customer and supplier
  accounting symmetry, owner-only access, replay/concurrency rejection, and
  injected audit failure rollback.
- Focused regression run: CAN tests, supplier purchase atomicity, Phase 72
  financial integration, and reports tests — passed (64 tests).
- `dart analyze` through the direct Dart SDK executable — passed with no issues.
- `git diff --check` — passed at the latest verification before final review.

The normal `flutter.bat` / `dart.bat` launchers could not access Flutter's SDK
lockfile inside the sandbox. The same checks were run successfully through the
direct Dart SDK executable with Flutter-tool access approved, so this is not a
product-code limitation.

## Final verification record

The earlier 63-second direct-invocation result was an interactive-session
boundary, not a suite stall or a product-test failure. Final verification used
independent PowerShell processes with stdout/stderr logs and exit-code files,
so each command was allowed to finish and produced its real exit code.

- `flutter test --no-pub --concurrency=1`: 838 tests passed, exit 0, 2m 10s
  (22:21:18 to 22:23:28).
- `flutter test --no-pub` at default concurrency: 838 tests passed, exit 0,
  1m 34s (22:24:48 to 22:26:22).
- `flutter build windows --release --no-pub`: exit 0, 1m 18s wall time
  (Flutter reported 56.8s build time). The Release executable is
  `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe` (784,384
  bytes; existing executable timestamp 19:12:03), and the rebuilt Flutter
  assets were timestamped 22:28:34. No `dart`, `flutter`, `cmake`, `ninja`,
  `msbuild`, or `cl` build process remained after completion. The CMake
  deprecation warning came from Firebase's extracted SDK and did not affect the
  zero build exit code.
- `flutter analyze --no-pub`: passed with no issues (10.6s).
- `git diff --check`: passed.
- The CAN Dart files plus the new CAN test were format-checked after final
  review: 14 files, 0 changes. A whole-repository Dart format check still
  reports 76 pre-existing out-of-scope files; it produced no worktree changes,
  so those baseline files were deliberately not reformatted in this ticket.
- `test/can_005_006_007_financial_reversals_test.dart` passed twice after the
  final review (4 tests per run). These runs repeat the duplicate-concurrency
  rejection and audit-write failure rollback paths.

Final diff review confirms the only implementation changes are the CAN-005,
CAN-006, and CAN-007 financial-reversal behavior, their persistence/reporting/
backup/UI integration, the traceability entry, report, and focused tests.
`MASTER-PROJECT-EXECUTION-PLAN-AR.md` is unchanged. No deployment, tag, merge,
secret change, or unrelated source change was made.
