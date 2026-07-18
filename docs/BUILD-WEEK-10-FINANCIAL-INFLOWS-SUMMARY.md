# BUILD-10 — Financial Inflows Summary Action

## Authorized scope

BUILD-10 implements the owner-selected read-only AI action
`financial_inflows_summary`. It accepts exactly `{}`, uses the current
calendar month determined by the existing `FinancialReportService` time
source, and requires `AppUser.permissions.canViewFinancialReports`.

The action uses `FinancialInflowsReportReader`, whose production adapter calls
`FinancialReportService.inflowsReport()` with no arguments. That existing
canonical domain method owns the current-month date range, account lookup,
entry filtering, transfer exclusion, ordering, qirsh totals, source breakdown,
labels, and reversal state. The AI tool returns the resulting `FlowReport`
unchanged: it performs no repository access, financial calculation, sorting,
filtering, projection, conversion, or mutation.

## Authorization and composition

Validation rejects every non-empty parameter map and non-read-only execution
mode. Missing, inactive, or callers without `canViewFinancialReports` fail
before reader access. The tool has no confirmation or action path.

There is no production global `AiToolRegistry`. Callers continue to create
their explicit registries and decide which tool instances to supply, matching
the established architecture.

## Files and exclusions

BUILD-10 adds the reader boundary and service adapter, the exported tool, this
documentation, and focused action tests. It does not change financial domain
calculation, repositories, permissions, UI/navigation, schema, migrations,
networking, tool chaining, mutations, exports, or the protected advances and
refunds report screen.

## Verification and delivery

The focused action suite has 10 passing tests covering registry discovery,
metadata, exact `{}`, safe mode validation, permission-before-reader,
pass-through report identity, canonical ordering/signs/qirsh values, empty
reports, safe reader failure, and the absence of AI-layer repository access or
sorting. The full `flutter test` suite passed with 1,374 tests and one expected
skip. `flutter analyze --no-pub`, the direct bundled Dart SDK `dart analyze`,
and `git diff --check` reported no issues.

`flutter build windows --release` exited 0 and produced
`build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe`
(785,408 bytes; modified 2026-07-18 21:56:02 local time). The build emitted
only the existing Firebase CMake deprecation and MSVCRT LNK4078 warnings.

The inherited edit to
`lib/features/financial_reports/advances_and_refunds_report_screen.dart` and
the untracked `.build-diagnostics/` directory remain outside this build. No
tag or push is created.
