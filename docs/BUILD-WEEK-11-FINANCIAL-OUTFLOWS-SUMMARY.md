# BUILD-11 — Financial Outflows Summary Action

## Authorized scope and action contract

BUILD-11 adds the owner-authorized AI action
`financial_outflows_summary`. It is read-only, has no confirmation, performs
no mutation or side effect, and accepts exactly `{}`. Any key, including one
with a null value, is rejected. The typed intent boundary also rejects non-map
payloads before tool execution.

The action requires `AppUser.permissions.canViewFinancialReports`. Missing,
inactive, and callers without that permission fail validation before the reader
is invoked. Owner role is not substituted for the required financial-report
permission.

## Canonical domain boundary

`FinancialOutflowsReportReader` is a read-only delegation boundary. Its
production adapter calls `FinancialReportService.outflowsReport()` with no
arguments. The domain service owns the current calendar-month range through
its established time source, as well as account lookup, filtering, transfer
exclusion, ordering, qirsh totals, source breakdown, labels, null semantics,
and reversal state.

The tool returns the exact `FlowReport` received from the reader. Neither the
tool nor reader accesses repositories, storage, or a database; calculates or
recalculates totals/balances; determines dates; filters or sorts; converts to a
map; creates a duplicate financial DTO; drops zero entries; changes signs; or
normalizes null values.

## Composition and files

No production global `AiToolRegistry`, singleton, or auto-registration was
added. As before, callers explicitly provide tool instances to their
registries.

BUILD-11 adds the outflows tool, its focused contract test, and this document.
It extends the existing financial-reader boundary with the outflows reader and
adapter, and exports the tool from `ai_assistant.dart`. It does not modify
financial report calculations, repositories, permissions, UI/navigation,
schema, migrations, networking, mutations, exports, or the protected
advances/refunds report screen.

## Verification and delivery

The focused test covers action/registry metadata, read-only mode, `{}` only,
non-object payload rejection, authorized pass-through with one reader call,
empty reports, null/zero/order/total preservation, authorization before the
reader, safe failures, and source-level no-repository/no-calculation/no-sort
checks. The focused suite passed 10 tests. Relevant AI financial-tool,
AI-execution, BUILD-10, and `FlowReport` regressions passed 130 tests with one
expected skip. The full `flutter test` suite passed 1,384 tests with one
expected skip. `flutter analyze --no-pub`, the direct bundled Dart SDK
`dart analyze`, and `git diff --check` reported no issues.

`flutter build windows --release` exited 0 and produced
`build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe`
(785,408 bytes; modified 2026-07-18 22:07:17 local time). The build emitted
only the existing Firebase CMake deprecation and MSVCRT LNK4078 warnings.
The final commit hash is recorded in the closure report after the commit.

The inherited local change to
`lib/features/financial_reports/advances_and_refunds_report_screen.dart` and
the untracked `.build-diagnostics/` directory remain outside BUILD-11. No tag
or push is created.
