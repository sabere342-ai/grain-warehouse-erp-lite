# BUILD-08 — Financial Closing/Reconciliation Summary

## Purpose and authorized scope

BUILD-08 adds the strictly read-only AI action
`financial_closing_reconciliation_summary`. It exposes the canonical Phase 80
financial-closing and reconciliation history without creating, reopening, or
otherwise changing a closing.

The previous BUILD-08 preflight stopped before changes because no canonical
read model or settled display permission existed. The owner decisions
`DC-BW08-001` through `DC-BW08-007` authorize the limited domain boundary
implemented here:

- a canonical read-only report inside `FinancialReportService`;
- owner-only viewing, with no permission-model change;
- exactly `{}` as the action input;
- all current closing records in the existing canonical order;
- account-name resolution, including inactive historical accounts; and
- a safe failure if a recorded account reference cannot be resolved.

## Canonical report boundary

`FinancialReportService.closingReconciliationReport()` returns the immutable
`FinancialClosingReconciliationReport`. It is the only BUILD-08 layer that
uses `FinancialAccountRepository`, calling `listAccounts(includeInactive:
true)` and `listClosings()` once each. The service preserves both repository
closing order and each closing's line order.

The report contains immutable `FinancialClosingReconciliationSummary` records
with closing ID, kind, period dates, creation timestamp and identity, optional
note, canonical open/reopened state, reopening timestamp/identity/reason,
canonical total difference in qirsh, and immutable account rows. Each
`FinancialClosingReconciliationAccountRow` contains the financial-account ID,
canonical account name and type, active state, expected/book balance, actual
balance, and canonical difference; every monetary value is an `int` qirsh.

The service passes through `FinancialClosingLine.differenceQirsh` and
`FinancialClosing.totalDifferenceQirsh`; it does not reconstruct ledger
balances, recalculate variance, change signs, filter records, or invent labels
or statuses. A missing account reference raises a clear domain failure rather
than returning a partial or labelled fallback result.

## AI action contract

`FinancialReportServiceClosingReconciliationReader` delegates directly to the
canonical method. Neither that reader nor
`FinancialClosingReconciliationSummaryTool` accesses a repository.

The tool accepts exactly `{}`, requires `AiExecutionMode.readOnly`, and has no
confirmation flow. Validation occurs before authorization; missing, inactive,
and non-owner callers fail before the reader is invoked. The authorization is
`caller.role == UserRole.owner`. `canViewFinancialReports` is intentionally
insufficient because Phase 80 is owner-only and BUILD-08 adds neither a new
permission nor a broader permission interpretation.

For an authorized request the reader is called exactly once and the immutable
canonical report is returned unchanged as structured action data. There are no
AI-layer calculations, sorting, filtering, grouping, qirsh conversions,
repository access, mutations, closing/reopening commands, networking, tool
chaining, or UI changes.

## Files changed

- `lib/core/financial_accounts/financial_report_models.dart`
- `lib/core/financial_accounts/financial_report_service.dart`
- `lib/features/ai_assistant/ai_assistant.dart`
- `lib/features/ai_assistant/services/financial_account_balance_report_reader.dart`
- `lib/features/ai_assistant/tools/financial_closing_reconciliation_summary_tool.dart`
- `test/financial_closing_reconciliation_report_test.dart`
- `test/financial_closing_reconciliation_summary_tool_test.dart`
- this document

No Phase 80 screen, close/reopen write logic, ledger calculation, schema,
migration, backup/restore path, permission model, navigation, or protected
advances/refunds report screen was changed.

## Tests and verification

The new domain-report suite has 4 passing tests; the focused AI-action suite
has 9 passing tests. They cover repository reads, empty reports, ordering,
inactive-account resolution, missing-account failure, qirsh values and signs,
total variance, null and reopening fields, immutability, exact input, read-only
mode, owner-only authorization-before-reader, safe reader failure, and no tool
repository dependency.

Regression suites passed: BUILD-01 7, BUILD-02 4, BUILD-03 11, BUILD-04 11,
BUILD-05 10, BUILD-06 10, BUILD-07 10, Phase 79 65, Phase 80 5, Phase 81 5,
financial-account repository 7, and permissions 11 (156 total).

`flutter test` passed with 1,364 tests and 1 expected skip. `flutter analyze
--no-pub` and the bundled Dart SDK's `dart analyze` both reported no issues.
`git diff --check` passed. Windows release build exited 0 and produced
`build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe`
(785,408 bytes; modified 2026-07-18 21:28:01 local time).

## Protected baseline and delivery policy

Before and after BUILD-08, the protected
`lib/features/financial_reports/advances_and_refunds_report_screen.dart`
remained SHA-1 `46D6166909D207DEEF6AE06D6332F49BD7A6B4AE`, Git blob
`22800a9ccb08ee5796f0fa69c87bd9995739adbf`, and 32,418 bytes. Its inherited
local edit and the untracked `.build-diagnostics/` directory remain outside
staging and this build.

The BUILD-08 commit is created only after the final protected-file and staging
audit. No tag and no push are created.
