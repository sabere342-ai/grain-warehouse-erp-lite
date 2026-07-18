# BUILD-09 — AI Read-Only Action Coverage Audit and Next-Scope Freeze

## Purpose and scope declaration

BUILD-09 is documentation and architecture audit only. It inventories the
read-only AI Action Layer from the actual source, classifies uncovered
read-only candidates, and freezes the next scope without adding an action,
reader, model, service, permission, UI, schema, test, or network integration.

Baseline commit: `233d66d66063677bbb9bc7dcfec6f17f75998b0e`
(`BUILD-08: add financial closing reconciliation summary action`). The only
pre-existing worktree items are the protected local edit to
`lib/features/financial_reports/advances_and_refunds_report_screen.dart` and
untracked `.build-diagnostics/`; neither is part of this build.

## Protected-file evidence

Before the audit, the protected file was SHA-1
`46D6166909D207DEEF6AE06D6332F49BD7A6B4AE`, Git blob
`22800a9ccb08ee5796f0fa69c87bd9995739adbf`, and 32,418 bytes. BUILD-09 does
not modify, format, stage, or commit it.

## Existing action inventory

The source contains seven exported `AiTool` implementations. BUILD-01 is the
foundation (`AiTool`, `AiToolRegistry`, `AiExecutionService`) and adds no
action; BUILD-02 through BUILD-08 add the following concrete read-only tools.

| Build | Action | Tool / reader boundary | Canonical source | Input | Authorization | Result coverage |
| --- | --- | --- | --- | --- | --- | --- |
| BUILD-02 | `inventory_attention` | `InventoryAttentionTool` / `InventoryAttentionReader` | `InventoryAttentionService.loadAttention()` | `{}` | no caller guard | Full inventory-attention list |
| BUILD-03 | `financial_account_balances` | `FinancialAccountBalancesTool` / `FinancialAccountBalanceReportReader` | `FinancialReportService.accountBalanceReport(includeInactive: true)` | `{}` | `canViewFinancialReports` | Full canonical balance report |
| BUILD-04 | `financial_account_statement` | `FinancialAccountStatementTool` / `FinancialAccountStatementReportReader` | `FinancialReportService.accountStatementReport(accountId: ...)` | one non-empty `financialAccountId` | `canViewFinancialReports` | Full statement for the selected account |
| BUILD-05 | `financial_payment_method_summary` | `FinancialPaymentMethodSummaryTool` / `FinancialPaymentMethodReportReader` | `FinancialReportService.paymentMethodReport()` | `{}` | `canViewFinancialReports` | Full canonical payment-method report |
| BUILD-06 | `financial_transfer_summary` | `FinancialTransferSummaryTool` / `FinancialTransferReportReader` | `FinancialReportService.transferReport()` | `{}` | `canViewFinancialReports` | Full canonical transfer report |
| BUILD-07 | `financial_advances_and_refunds_summary` | `FinancialAdvancesAndRefundsSummaryTool` / `FinancialAdvancesAndRefundsReportReader` | `FinancialReportService.getAdvancesAndRefundsReport()` | `{}` | `canViewFinancialReports` | Full canonical advances/refunds report |
| BUILD-08 | `financial_closing_reconciliation_summary` | `FinancialClosingReconciliationSummaryTool` / `FinancialClosingReconciliationReportReader` | `FinancialReportService.closingReconciliationReport()` | `{}` | active owner role only | Full canonical closing/reconciliation history |

The financial action result wrappers use `int` qirsh values. They copy domain
rows/totals and preserve ordering, nulls, reversals, and signs; neither tools
nor readers access repositories. BUILD-08 returns the immutable canonical
domain report directly. No tool performs a financial calculation.

## Registry and composition audit

`lib/features/ai_assistant/registry/ai_tool_registry.dart` is an immutable
index of caller-supplied tools, not a static application catalogue. It rejects
blank and duplicate IDs, stores `Map.unmodifiable`, supports `findById`, and
exposes the supplied iterable as `all`. `AiExecutionService` resolves IDs,
checks required metadata parameters, and converts validation exceptions and
unexpected reader failures to structured safe responses.

Consequently, the code evidence is **seven exported action definitions**, but
there is no single production `AiToolRegistry([...])` composition site whose
runtime contents can be counted independently. The focused tests construct
registries explicitly. This is an architecture/documentation drift, not a
duplicate registration or security bypass: documentation must not imply a
global auto-registration mechanism that source does not contain.

All seven tool files are exported by
`lib/features/ai_assistant/ai_assistant.dart`. Each financial reader interface
and adapter in `services/financial_account_balance_report_reader.dart` is used
by its matching tool; the five financial AI result-model files are used by
their matching tools; the BUILD-08 report intentionally has no duplicate AI
wrapper. No orphaned exported tool, reader, or result model was found. No
duplicate action ID was found in the seven implementations.

## Permission matrix and privacy audit

| Action | Missing/inactive caller fails before reader | Non-owner behavior | Proven visible-source alignment | Classification |
| --- | --- | --- | --- | --- |
| `inventory_attention` | No caller is injected | no explicit restriction | Dashboard/inventory attention is operational, but no AI user contract exists | Contract inconsistency: document and decide future caller policy |
| `financial_account_balances` | Yes | denied without `canViewFinancialReports` | Financial report screens use the same permission | No issue |
| `financial_account_statement` | Yes | denied without `canViewFinancialReports` | Account-statement screen uses the same permission | No issue |
| `financial_payment_method_summary` | Yes | denied without `canViewFinancialReports` | Payment-method screen uses the same permission | No issue |
| `financial_transfer_summary` | Yes | denied without `canViewFinancialReports` | Transfer screen uses the same permission | No issue |
| `financial_advances_and_refunds_summary` | Yes | denied without `canViewFinancialReports` | Advances/refunds screen uses the same permission | No issue |
| `financial_closing_reconciliation_summary` | Yes | denied unless active owner | Phase 80 screen and owner decision are owner-only | No issue |

The inventory action is the only existing action without caller injection or
authorization-before-reader. It exposes product names, stock quantities, and
attention classification, not financial balances or personal records. It is
not evidence of a broader permission than its visible source, but it lacks the
uniform caller contract used by BUILD-03 through BUILD-08. Audit logs,
document history, backup content, customer/supplier balances, cancellation and
reopening reasons, and user identities are sensitive candidates and are not
approved for direct AI exposure by this audit.

## Canonical boundary and candidate matrix

Classification key: **A** ready for direct exposure; **B** canonical domain
boundary required first; **C** owner product/authorization decision required;
**D** outside current read-only scope; **E** already covered; **F** no
trustworthy contract.

| Candidate / evidence | Inputs actually required | Audit finding | Class |
| --- | --- | --- | --- |
| Account balances — `FinancialReportService.accountBalanceReport()` | `{}` uses canonical current-month default | Typed totals, labels, ordering and permission already covered by BUILD-03 | E |
| Account statement — `accountStatementReport(accountId: ...)` | `financialAccountId` | Canonical per-account result already covered by BUILD-04 | E |
| Payment-method report — `paymentMethodReport()` | `{}` | Canonical report already covered by BUILD-05 | E |
| Transfer report — `transferReport()` | `{}` | Canonical report already covered by BUILD-06 | E |
| Advances/refunds — `getAdvancesAndRefundsReport()` | `{}` | Canonical report already covered by BUILD-07 | E |
| Closing/reconciliation — `closingReconciliationReport()` | `{}` | Canonical immutable owner-only report already covered by BUILD-08 | E |
| Inventory attention — `InventoryAttentionService.loadAttention()` | `{}` | Canonical operational result already covered by BUILD-02 | E |
| Financial inflows — `FinancialReportService.inflowsReport()` | `{}` can use the documented current-month default; optional date/account filters are not needed for the default report | Typed `FlowReport`, domain ordering/totals/source labels, qirsh `int`, reversals, and `canViewFinancialReports` are present; repository access remains in the service | A |
| Financial outflows — `FinancialReportService.outflowsReport()` | `{}` can use the documented current-month default; optional date/account filters are not needed for the default report | Same mature `FlowReport` contract and permission as inflows | A |
| Customer collections by account — `getCustomerCollectionsByAccount(...)` | date range and optional account/customer filters exist | Needs customer-resolution lookup and an explicit default/filter scope before an AI reader can be safe | B |
| Supplier settlements by account — `getSupplierSettlementsByAccount(...)` | date range and optional account/supplier filters exist | Needs supplier-resolution lookup and explicit default/filter scope | B |
| Expense analysis — `expenseAnalysisReport(...)` | date range plus optional account/payment/category filters | Uses an optional expense repository and exposes a `double` percentage field; needs a qirsh-safe exposure contract and scope decision | B |
| Daily activity report — `ReportRepository.dailyActivityReport(selectedDate: ...)` | required date | Coherent report but boundary is a repository, aggregates many repositories, uses fallback product labels, and requires an explicit date contract | B |
| Stock movement / stock-adjustment reports | product/date/filter selection | Current sources are repositories and UI report screens, not a coherent immutable report boundary | B |
| Sales and purchase operational summaries | date/filter selection | Only list repositories and UI aggregation were found; no canonical report DTO | B |
| Audit log history — `AuditLogRepository.listLogs()` / controller | filter/privacy scope unresolved | Owner audit permission exists, but entries can reveal user identities and internal reasons; no AI report contract | C |
| Document history — `DocumentHistoryController` | `DocumentHistoryFilter` and privacy scope | Controller/UI state and mixed audit permissions; needs owner decision and domain boundary | C |
| Backup validation/preview — `BackupRestorePreviewService.preview(jsonText)` | backup JSON text | Input carries backup content and metadata; safe AI privacy/retention policy is unresolved | C |
| Dashboard summary — `DashboardService.load()` | `{}` | Multi-repository derived dashboard contains heuristic wheat-name matching and broad sensitive balances; not a trustworthy canonical AI contract | F |
| Close/reopen/reconcile commands | closing ID, balances, reason, confirmation | Financial state mutation and owner confirmation workflow | D |
| Backup restore, wipe, account/configuration and transactional commands | command-specific | Mutating/destructive operations, including confirmation and audit requirements | D |
| Autonomous tool chaining, networking, chat/OpenAI execution | n/a | Explicitly outside the current local read-only action layer | D |

The audited candidate set is 22: A=2, B=6, C=3, D=3, E=7, F=1. The
inventory’s caller-policy inconsistency and the absence of global registry
composition are recorded architecture gaps; neither changes the classification
of the covered canonical report boundaries.

## Accounting-safety findings

All covered financial actions preserve integer qirsh values and canonical
financial report totals. BUILD-03 through BUILD-08 reject unauthorized callers
before a reader call; their focused tests verify this ordering and safe reader
failures. The new A candidates reuse `FlowReport`, whose service owns
current-month defaults, ordering (timestamp descending then entry ID), source
breakdown, total qirsh, account-name resolution, and reversal status. An AI
tool must not reproduce any of that logic.

Expense analysis is not A because its existing report includes a floating-point
percentage and optional dependency behavior. Customer/supplier reports are not
A because their party-name resolution and filter/default semantics have not
been captured in a single AI-safe boundary. Daily activity and dashboard
figures must not be reassembled from repositories or UI state.

## Ranked uncovered candidates and BUILD-10 freeze

1. **Financial inflows** — A: canonical typed `FlowReport`, default `{}`
   period, domain totals/ordering, qirsh values, and established financial
   permission.
2. **Financial outflows** — A: equivalent safety and scope to inflows.
3. Customer collections by account — B: useful but requires a canonical
   lookup/default-scope boundary.
4. Supplier settlements by account — B: same boundary issue.
5. Daily activity report — B: useful operationally but requires a service
   boundary and required-date contract.

There are two equally safe, non-duplicate A candidates. BUILD-09 therefore
selects **Outcome 2: owner choice required**, rather than guessing between
them.

### Proposed BUILD-10 alternatives

**Option A — Financial inflows summary**

- Action: `financial_inflows_summary`
- Input: exactly `{}` for the existing current-month default
- Mode: read-only
- Permission: `AppUser.permissions.canViewFinancialReports`
- Canonical method: `FinancialReportService.inflowsReport()`
- Result: immutable pass-through/wrapper of `FlowReport`, retaining entries,
  total qirsh, source breakdown, ordering, account/source labels and reversal
  state

**Option B — Financial outflows summary**

- Action: `financial_outflows_summary`
- Input, mode, permission, result, and test shape: the corresponding outflow
  equivalents of Option A
- Canonical method: `FinancialReportService.outflowsReport()`

Both options require tests for exact `{}`, mode, missing/inactive/unauthorized
caller rejection before reader, one authorized read, pass-through ordering,
qirsh/sign/reversal/null preservation, immutability, safe failure, no AI
repository access, and unique registry ID. They exclude filtering, custom date
or account schemas, exports, UI, mutations, networking, and any financial
calculation.

Required owner decision: choose **inflows** or **outflows** as BUILD-10. No
additional permission decision is required for either because the existing
screens and current actions prove `canViewFinancialReports`; the decision must
also confirm that the existing current-month default is the intended `{}`
scope. If neither default is desired, BUILD-10 must stop and obtain an input
contract instead of inventing one.

## Explicit exclusions

BUILD-09 does not authorize close/reopen/settlement execution, backup restore
or wipe, account configuration, transaction creation/cancellation, AI
orchestration, chat/OpenAI integration, networking, cloud sync, mobile,
multi-device work, new permissions, UI/navigation, schema/migrations, or any
production/test change.

## Verification and delivery

Files changed by BUILD-09: this document only. Verification completed with
`flutter test`: 1,364 passed, 0 failed, and 1 expected skip. `flutter analyze
--no-pub` reported no issues. Because `dart.bat` can hang in this environment,
the direct SDK command
`C:\\src\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe analyze` was run and
reported no issues. `git diff --check` passed.

`flutter build windows --release` exited 0 and produced
`build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe` at
785,408 bytes, modified 2026-07-18 21:44:00 local time. The build emitted only
the pre-existing Firebase CMake deprecation and MSVCRT LNK4078 warnings.

The final commit message is `BUILD-09: audit AI read-only action coverage`.
Its hash is recorded in the final closure report after the commit. No tag and
no push are made.
