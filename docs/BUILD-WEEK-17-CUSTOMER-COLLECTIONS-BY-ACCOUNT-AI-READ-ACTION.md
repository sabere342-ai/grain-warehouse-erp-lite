# BUILD-17 — Customer Collections by Financial Account AI Read Action

## Executive status

BUILD-17 implements the owner-authorized, read-only AI action for the canonical BUILD-16 customer-collections report. It adds no UI, write path, schema, migration, backup-format, ledger, balance, or domain-report change.

## BUILD-16 continuity and owner decision

BUILD-16 (`3d9a178ae05c6f38f29eb071ad2fa5f4a9c4f9fe`) supplied the immutable, canonical `customerCollectionsByFinancialAccountReport` domain boundary. BUILD-17 exposes that exact boundary through the sole approved action:

| Item | Decision |
| --- | --- |
| Action ID | `financial_customer_collections_by_account` |
| Functional name | Customer Collections by Financial Account |
| Arabic name | تحصيلات العملاء حسب الحساب المالي |
| Purpose | Read one account's customer collections for an inclusive local-business-date period. |
| Execution mode | `AiExecutionMode.readOnly` |
| Confirmation | None (`requiresConfirmation == false`) |
| Permission | Existing `Permissions.canViewFinancialReports` |
| AI action count | 10 before BUILD-17; 11 in an explicitly caller-supplied BUILD-17 registry. |

## Input and date contract

Only these parameters are accepted:

| Parameter | Type | Required | Rules |
| --- | --- | --- | --- |
| `financialAccountId` | string | yes | Non-empty after validation; exactly one account. |
| `startDate` | string | yes | Exact local `YYYY-MM-DD`, inclusive. |
| `endDate` | string | yes | Exact local `YYYY-MM-DD`, inclusive and not before `startDate`. |
| `customerId` | string or null | no | Non-empty when supplied; null means no customer filter. |

The tool rejects every unapproved input key. It parses only exact calendar dates into local date-only `DateTime` values, rejects impossible dates, makes no UTC conversion, and neither supplies defaults nor adjusts dates. The tool does not accept payment-method, name, amount, employee, activity, search, sort, pagination, grouping, multi-ID, all-time, timestamp, timezone, query, or controller input.

## Reader, authorization, and domain boundary

`CustomerCollectionsByFinancialAccountTool` is located at `lib/features/ai_assistant/tools/customer_collections_by_financial_account_tool.dart`. It validates the approved syntax and date range, requires read-only mode, then checks that an active caller can proceed and has `canViewFinancialReports` before it invokes its reader.

The injected reader interface and its sole adapter are in `lib/features/ai_assistant/services/customer_collections_by_financial_account_report_reader.dart`. The adapter depends only on `CustomerCollectionsByFinancialAccountReportService` and delegates once to:

```dart
customerCollectionsByFinancialAccountReport(
  financialAccountId: financialAccountId,
  startDate: startDate,
  endDate: endDate,
  customerId: customerId,
)
```

Neither AI file imports or accesses a repository. The reader is not called on input, mode, or permission failure; therefore no account, customer, or collection data is read and permission denial cannot reveal supplied-ID existence.

## Result, privacy, and accounting safety

The tool returns the exact immutable `CustomerCollectionsByFinancialAccountReport` object as `AiToolResult.data`. There is no AI result wrapper, table projection, calculation, filtering, sorting, grouping, identity lookup, enrichment, formatting, or reconstruction.

The canonical result exposes only the approved financial-account ID, display name, type and active state; inclusive period; optional customer ID filter; row count; total integer qirsh; and row collection ID/date, customer ID/name/active state, account ID, nullable payment method, and integer qirsh amount. It preserves BUILD-16's date-then-collection-ID ordering, inactive existing entities, empty successful reports, and `paymentMethod == null` exactly.

It does not expose phone numbers, addresses, notes, suppliers, employees, usernames, authentication data, balances, ledger/closing/reopening data, audit/backup content, storage metadata, raw entities, persistence details, filesystem paths, or data outside the selected account and period. Amounts remain integer qirsh and the canonical `rowCount` and `totalAmountQirsh` are not recalculated.

## Error behavior

BUILD-17 uses the established AI response framework rather than adding a parallel error model. Invalid input, wrong mode, and permission denial raise `AiToolValidationException`, surfaced as the existing safe `validationFailure` response; the authorization error contains no entity information. Canonical missing-entity and unexpected reader errors are contained by `AiExecutionService` as its existing safe `failure` response: `The requested operation could not be completed.` This preserves the current framework's no-stack-trace, no-path, and no-storage-detail behavior.

## Registry and exports

The central `ai_assistant.dart` barrel explicitly exports the new tool and reader. `AiToolRegistry` remains the immutable allow-list constructed from the caller-supplied iterable, with duplicate-ID rejection and no global registry, singleton, static mutable registry, auto-discovery, or hidden second registry. The focused test composes all prior ten IDs plus this tool and proves a unique 11-action caller-supplied registry. Existing focused suites retain the individual behavior contracts for the preceding actions.

## Verification and isolation

- Focused BUILD-17 suite: 9 passed.
- Related AI/registry/financial and BUILD-16 regression selection: 128 passed.
- Full `flutter test`: 1,424 passed, 0 failures, 1 expected skip.
- `flutter analyze --no-pub`: no issues.
- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze`: no issues.
- `git diff --check`: no diff errors; only existing CRLF/toolchain notices.
- `flutter build windows --release`: exit 0 outside the restricted sandbox; `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`, 785,408 bytes, modified `2026-07-19 14:16:44` local time. Existing Firebase CMake deprecation and MSVCRT LNK4078 warnings remain non-blocking.

The inherited protected file remains `lib/features/financial_reports/advances_and_refunds_report_screen.dart`, modified but unstaged as inherited. Its required SHA-256 remains `A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`, Git blob remains `22800a9ccb08ee5796f0fa69c87bd9995739adbf`, and size remains 32,418 bytes. `.build-diagnostics/` remains untracked and unstaged.

BUILD-17's commit message is `BUILD-17: add customer collections financial account AI action`. No tag is created and nothing is pushed.

## Explicit future non-goals

This build does not authorize another AI action, input expansion, export, sharing, UI change, repository access from AI, write mode, confirmation, all-accounts report, split payments, advances, overpayments, refunds, cloud sync, mobile, multi-device synchronization, schema work, migration, backup change, balance change, ledger change, or a change to BUILD-16 semantics.
