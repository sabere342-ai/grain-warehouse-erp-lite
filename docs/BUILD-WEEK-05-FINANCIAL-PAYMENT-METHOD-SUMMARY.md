# BUILD-05: Financial Payment Method Summary action

## Scope and authorized continuation audit

BUILD-05 adds `financial_payment_method_summary`, a strictly read-only AI
Action Layer projection of the canonical Phase 79 payment-method report. The
only accepted input is `{}`; every key is rejected. It requires
`AiExecutionMode.readOnly`, has no confirmation or mutation capability, and
uses `AppUser.permissions.canViewFinancialReports`.

This build resumed four owner-authorized partial paths:

- `lib/features/ai_assistant/ai_assistant.dart`
- `lib/features/ai_assistant/services/financial_account_balance_report_reader.dart`
- `lib/features/ai_assistant/models/financial_payment_method_summary_result.dart`
- `lib/features/ai_assistant/tools/financial_payment_method_summary_tool.dart`

The audit preserved their minimal barrel exports, injected reader interface and
adapter, immutable result shape, and read-only tool mapping. They were valid
because the adapter delegates directly to the canonical domain report, the tool
does not import a repository, caller authorization happens before reader use,
and no financial aggregation is duplicated. The partial work was incomplete
because it lacked BUILD-05 focused tests and documentation. The existing reader
file already contained BUILD-03 balance and BUILD-04 statement adapters, so the
small additional explicitly named payment-method adapter remains coherent; no
broad rename was necessary.

## Boundary, authorization, and result

`FinancialReportServicePaymentMethodReader.loadPaymentMethodReport()` delegates
without arguments to `FinancialReportService.paymentMethodReport()`. The domain
service therefore owns its existing unfiltered/default reporting period,
grouping, inactive-account handling, transfer exclusion, ordering, and all
financial calculations. The AI layer supplies no dates, account filters,
payment-method filters, or implicit dates.

Missing, inactive, or unauthorized callers fail closed before the reader is
called. Canonical reader failures flow through the established safe AI failure
response, without stack or storage detail leakage.

The immutable typed result includes the canonical report period, ordered
payment-method rows, canonical `PaymentMethod?`, domain display name,
operation count, integer-qirsh inflows/outflows, canonical domain net movement,
and report-wide inflow/outflow/net totals. Rows are not reordered or filtered.
Null payment methods remain null and retain the canonical domain display label;
they are never converted to cash or otherwise normalized. `isEmpty` depends
only on canonical rows. No monetary value is converted to floating point.

## Files and exclusions

BUILD-05 adds focused tests and this document, and modifies only the inherited
AI barrel and shared financial-report reader adapter files plus the inherited
result model and tool. It does not alter UI, transactions, balances, reports,
financial accounts, payment methods, backup/restore, schema/migrations,
networking, chat, OpenAI integration, cloud/mobile/multi-device work, tool
chaining, autonomous execution, tags, or pushes.

## Verification

Focused BUILD-05, BUILD-01 through BUILD-04, payment-method, financial-report,
permission, complete-suite, analysis, Windows release-build, whitespace, and
protected-file verification results are recorded after final execution. The
preserved expected skip remains
`test/phase9a_inflows_outflows_reports_test.dart:552`: `Requires negative
balance approval with actual credentials.`

BUILD-05 focused tests passed (10). BUILD-01 execution tests (7), BUILD-02
inventory service tests (3), BUILD-02 inventory tool tests (4), BUILD-03
financial-account balance tests (11), BUILD-04 financial-account statement
tests (11), canonical payment-method report tests (8), Phase 79 financial-report
tests (65), and relevant permission tests (11) passed. The complete suite
passed with 1,331 tests, 0 failures, and 1 expected skip. `flutter analyze
--no-pub` and `dart analyze` both passed with no issues.

The normal Windows verification command completed successfully:

```powershell
C:\src\flutter\bin\flutter.bat build windows --release --no-pub
```

It rebuilt `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
(785,408 bytes; 2026-07-18 19:39:34 +03:00). `git diff --check` passed. The
only non-blocking native message was the existing Firebase CMake deprecation
warning.

The protected unrelated report-screen change remains unstaged and unchanged:
Git blob `22800a9ccb08ee5796f0fa69c87bd9995739adbf`, filesystem SHA-1
`46D6166909D207DEEF6AE06D6332F49BD7A6B4AE`, size 32,418 bytes.
