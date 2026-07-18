# BUILD-04: Financial Account Statement action

## Owner-authorized scope

BUILD-04 adds `financial_account_statement`, a strictly read-only AI Action
Layer projection of the canonical
`FinancialReportService.accountStatementReport(...)` boundary. Its public input
is exactly `{ "financialAccountId": "non-empty-existing-account-id" }`: one
required string key, with no date, source, payment-method, or reversal filters.
It requires `AiExecutionMode.readOnly` and never asks for confirmation.

The tool has no write, navigation, export, file, network, schema, migration,
backup, UI, chat, OpenAI, inventory, or accounting-write-path behavior. It
uses an injected read-only adapter, never a repository, screen, or persistence
API directly.

## Authorization and output

Missing, inactive, or unauthorized callers fail closed before the reader is
called. Authorization reuses `AppUser.canProceed` and
`AppUser.permissions.canViewFinancialReports`, matching the existing report
screen. Canonical-domain failures, including an unknown account ID, are
converted by the existing execution service into the standard safe AI failure
without database or stack details.

The immutable output maps the canonical account and reporting period, opening
and closing integer-qirsh balances, and service-ordered statement entries. Each
entry exposes authoritative identifier, effective date, source, direction,
amount, source-document, reference/note, payment-method, reversal, and running
balance information. It does not recalculate balances, reorder entries, or
invent statement totals that the canonical report does not provide. An existing
inactive account is returned if the canonical report permits it.

## Validation and verification

Focused tests cover registry discovery, exact parameter validation, read-only
metadata, fail-closed authorization before reader access, safe unknown-account
failure, canonical ordering, integer-qirsh mapping, inactive accounts, empty
statements, immutable output, and no repository imports. BUILD-01/02/03 and
Phase 79 financial-report regression suites are also run, followed by analysis,
the complete test suite, `git diff --check`, and a normal Windows release build.

The BUILD-04 focused suite passed 11 tests. BUILD-01 execution (7), BUILD-02
inventory service (3), BUILD-02 inventory tool (4), BUILD-03 financial account
balances (11), and the Phase 79 financial-report suite (65) passed. Both
`flutter analyze --no-pub` and `dart analyze` completed with no issues. The
complete suite passed with 1,321 tests, 0 failures, and 1 expected skip.

The normal Windows verification command completed successfully:

```powershell
C:\src\flutter\bin\flutter.bat build windows --release --no-pub
```

It rebuilt `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
(785,408 bytes; 2026-07-18 19:39:34 +03:00). `git diff --check` passed. The
only non-blocking native message was the existing Firebase CMake deprecation
warning.

The preserved expected skip remains
`test/phase9a_inflows_outflows_reports_test.dart:552`: `Requires negative
balance approval with actual credentials.`

The unrelated protected report-screen formatting change remains outside this
build, unstaged and unmodified: Git blob
`22800a9ccb08ee5796f0fa69c87bd9995739adbf`, filesystem SHA-1
`46D6166909D207DEEF6AE06D6332F49BD7A6B4AE`, size 32,418 bytes. No tag is
authorized or created for BUILD-04.
