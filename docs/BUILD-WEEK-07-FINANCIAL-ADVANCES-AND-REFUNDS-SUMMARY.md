# BUILD-07: Financial Advances and Refunds Summary action

## Owner-authorized scope and preflight

BUILD-07 adds `financial_advances_and_refunds_summary`, a strictly read-only
AI Action Layer projection of the existing canonical advances-and-refunds
report. Preflight confirmed BUILD-06 is HEAD, the only unrelated worktree
changes are the protected report-screen formatting edit and untracked
`.build-diagnostics/`, and no inherited BUILD-07 work exists.

The canonical boundary is
`FinancialReportService.getAdvancesAndRefundsReport()`, called without
arguments through `FinancialReportServiceAdvancesAndRefundsReader`. The domain
service owns the default reporting period, eligible customer/supplier
advance-refund and reversal rows, labels, ordering, grouping, and totals. This
BUILD does not add date, account, party, entity, or transaction filters.

## Authorization and output contract

The only accepted input is `{}`. Every key, including a null-valued key, is
rejected. The action requires `AiExecutionMode.readOnly` and
`AppUser.permissions.canViewFinancialReports`; missing, inactive, or
unauthorized callers fail closed before the reader runs.

The immutable typed result preserves canonical details, account summaries,
customer summaries, supplier summaries, report dates, and every supplied
integer-qirsh total. It preserves party IDs/names, account data, source and
reference fields, reversal links/status, null values, and canonical collection
ordering. `isEmpty` follows canonical detail rows. No amount becomes `double`,
and the AI layer performs no financial calculations, repository reads, sorting,
filtering, grouping, label synthesis, or mutations.

The report's canonical scope is qualified customer and supplier
advance-refund entries and their reversals; it does not invent a separate
overpayment or advance workflow.

## Files and exclusions

BUILD-07 adds a focused test, immutable model, tool, reader adapter, barrel
exports, and this document. It does not modify the protected advances/refunds
screen, UI/navigation, transaction workflows, permissions, schema/migrations,
backup/restore, closing/reconciliation, networking, chat/OpenAI, cloud/mobile,
tool chaining, confirmation flows, autonomous execution, tags, or pushes.

## Verification

Focused BUILD-07, BUILD-01 through BUILD-06, Phase 9D advances/refunds,
Phase 79, relevant Phase 80/81, permissions, complete-suite, analysis, Windows
release-build, whitespace, and protected-file evidence are recorded after final
verification. The protected file must remain Git blob
`22800a9ccb08ee5796f0fa69c87bd9995739adbf`, SHA-1
`46D6166909D207DEEF6AE06D6332F49BD7A6B4AE`, and 32,418 bytes. No tag or push
is authorized.

BUILD-07 focused tests passed (10). BUILD-01 execution tests (7), BUILD-02
inventory service tests (3), BUILD-02 inventory tool tests (4), BUILD-03
financial-account balance tests (11), BUILD-04 financial-account statement
tests (11), BUILD-05 payment-method summary tests (10), and BUILD-06 transfer
summary tests (10) passed. The Phase 9D advances-and-refunds report regression
suite passed (69), Phase 79 financial-report tests passed (65), Phase 80
financial-closing tests passed (5), Phase 81 backup-contract tests passed (5),
and relevant permission tests passed (11). The complete suite passed with
1,351 tests, 0 failures, and 1 expected skip. `flutter analyze --no-pub` and
`dart analyze` both completed with no issues.

The normal Windows verification command completed successfully:

```powershell
C:\src\flutter\bin\flutter.bat build windows --release --no-pub
```

It rebuilt `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
(785,408 bytes; 2026-07-18 19:39:34 +03:00). `git diff --check` passed. The
only non-blocking native message was the existing Firebase CMake deprecation
warning.
