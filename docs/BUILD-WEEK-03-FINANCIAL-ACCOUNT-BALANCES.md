# BUILD-03: Financial Account Balances action

## Owner-authorized scope

BUILD-03 adds `financial_account_balances`, a strictly read-only AI Action
Layer projection of the existing Financial Account Balance Report. It accepts
only `{}`, requires `AiExecutionMode.readOnly`, and has no confirmation,
navigation, export, network, file, or write behavior.

The authoritative boundary is `FinancialReportService.accountBalanceReport`,
the same boundary used by the owner-gated account balance report screen. The
tool receives an injected reader adapter; it does not import a repository,
storage API, screen, or protected financial-report file.

## Authorization and output

The action reuses `AppUser.permissions.canViewFinancialReports`, which is the
existing screen permission. Missing, inactive, or unauthorized callers fail
closed before the report reader is called.

The immutable result contains ordered account items (`accountId`, `accountName`,
`accountType`, `isActive`, opening balance, inflows, outflows, and current
balance), authoritative report totals, and `isEmpty`. All amounts are integer
qirsh values directly mapped from the report; no accounting formula is
duplicated in the AI adapter.

## Exclusions

No Split Payments, advances, overpayments, refunds, transfers, reversals,
exports, UI/navigation, chat interface, OpenAI integration, schema, migration,
backup, ledger, or inventory/accounting write-path changes are included.

## Verification

Focused BUILD-03 tests passed (11 tests), including registry discovery,
read-only metadata, strict input validation, authorization, safe errors,
immutable mapping, canonical ordering, empty results, and integer-qirsh
precision. BUILD-01 execution tests (7), BUILD-02 inventory service tests (3),
BUILD-02 inventory tool tests (4), and the Phase 79 financial-report regression
suite (65) also passed.

`flutter analyze --no-pub` passed with no issues. The complete test suite
passed with 1,310 passed, 0 failed, and 1 expected skipped test. The preserved
skip remains `test/phase9a_inflows_outflows_reports_test.dart:552` with reason
`Requires negative balance approval with actual credentials.`

The normal Windows verification command was:

```powershell
C:\src\flutter\bin\flutter.bat build windows --release --no-pub
```

It completed with exit code `0` and rebuilt
`build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` (785,408
bytes; 2026-07-18 19:39:34 +03:00). `git diff --check` passed. The only
non-blocking native warnings were the existing Firebase CMake deprecation and
MSVCRT `LNK4078` warning.

No schema, migration, backup contract, accounting write path, inventory write
path, UI, export, or navigation change was made. The protected unrelated report
file remained modified but unstaged, with Git blob hash
`22800a9ccb08ee5796f0fa69c87bd9995739adbf`, filesystem SHA-1
`46D6166909D207DEEF6AE06D6332F49BD7A6B4AE`, and size 32,418 bytes before and
after BUILD-03 verification.

BUILD-03 is committed as `BUILD-03: add financial account balances action`.
No BUILD-03 tag was authorized or created. Split Payments,
Advances/Overpayments/Refunds, chat UI, and OpenAI integration remain outside
this build.
