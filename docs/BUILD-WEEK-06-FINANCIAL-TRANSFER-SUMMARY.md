# BUILD-06: Financial Transfer Summary action

## Owner-authorized scope

BUILD-06 adds `financial_transfer_summary`, a strictly read-only AI Action
Layer projection of the canonical Phase 79 financial transfer report. The only
accepted input is `{}`; every key, including a null-valued key, is rejected.
The action requires `AiExecutionMode.readOnly` and
`AppUser.permissions.canViewFinancialReports`.

Missing, inactive, or unauthorized callers fail closed before the injected
reader is invoked. The tool has no confirmation, repository access, mutation,
state change, navigation, UI, network, OpenAI, or tool-chaining behavior.

## Canonical boundary and result

`FinancialReportServiceTransferReader.loadTransferReport()` delegates without
arguments to `FinancialReportService.transferReport()`. The domain service owns
the default report period, filtering behavior, source/destination labels,
reversal interpretation, ordering, and total calculation. The AI layer passes
no date, account, or reversal filters and does not sort, group, aggregate, or
reinterpret transfers.

The immutable typed result preserves report period, ordered rows, transfer ID,
display number, effective date, source and destination account names,
integer-qirsh amount, reference/note, reversal metadata, and creator when
provided. It carries the canonical `totalAmountQirsh` unchanged, retains null
fields exactly, preserves zero rows, and uses `isEmpty` only from canonical row
count. No floating-point monetary values or invented fallback labels exist.

## Architecture and exclusions

The existing BUILD-03/04/05 shared financial-report reader file already holds
small explicitly named injected interfaces and adapters, so BUILD-06 adds the
equivalent named transfer reader there without broad renaming. The barrel adds
only the new model and tool exports.

Excluded scope includes financial mutations, creating/editing/deleting
transfers, confirmation or autonomous execution, UI/navigation, schemas,
migrations, backup/restore, networking, chat/OpenAI, cloud/mobile/multi-device,
split payments, negative-balance controls, advances/refunds, closing, and
unrelated refactors.

## Verification

Focused BUILD-06, BUILD-01 through BUILD-05, transfer-report, Phase 79,
permission, full-suite, analysis, Windows release-build, whitespace, and
protected-file evidence are recorded after final verification. The protected
unrelated report-screen change remains unstaged and unchanged: Git blob
`22800a9ccb08ee5796f0fa69c87bd9995739adbf`, filesystem SHA-1
`46D6166909D207DEEF6AE06D6332F49BD7A6B4AE`, size 32,418 bytes. No tag or push
is authorized.

BUILD-06 focused tests passed (10). BUILD-01 execution tests (7), BUILD-02
inventory service tests (3), BUILD-02 inventory tool tests (4), BUILD-03
financial-account balance tests (11), BUILD-04 financial-account statement
tests (11), BUILD-05 payment-method summary tests (10), canonical transfer
report tests (9), Phase 79 financial-report tests (65), and relevant permission
tests (11) passed. The complete suite passed with 1,341 tests, 0 failures, and
1 expected skip. `flutter analyze --no-pub` and `dart analyze` both completed
with no issues.

The normal Windows verification command completed successfully:

```powershell
C:\src\flutter\bin\flutter.bat build windows --release --no-pub
```

It rebuilt `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
(785,408 bytes; 2026-07-18 19:39:34 +03:00). `git diff --check` passed. The
only non-blocking native message was the existing Firebase CMake deprecation
warning.
