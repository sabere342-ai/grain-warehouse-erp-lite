# BUILD-12 — Parameterized AI Read-Only Action Scope Freeze

## Executive summary

BUILD-12 is an architecture and documentation audit only. It adds no AI tool,
reader, result model, registry, production wiring, domain API, repository,
permission, UI, schema, migration, backup/restore path, or test. Its single
output is the frozen BUILD-13 recommendation below.

The six category-B candidates from BUILD-09 were re-audited against the
current repository after BUILD-11. **Expense analysis** is the only candidate
that passes every BUILD-13 eligibility gate without creating a new domain
boundary: its existing public `FinancialReportService` method returns a typed
report, its production screen uses `canViewFinancialReports`, and focused
domain tests already exist. BUILD-13 is therefore frozen as the parameterized
read-only action `financial_expense_analysis`.

This is a recommendation and scope freeze, not authorization to implement the
action in BUILD-12.

## Baseline, scope, and protected state

Baseline HEAD: `8f9198fa744ae4be98bdda6ad61b6a2757159a50`
(`BUILD-11: add financial outflows summary action`) on branch
`phase9e-expense-analysis-report`. The preflight worktree contained only the
inherited modification to
`lib/features/financial_reports/advances_and_refunds_report_screen.dart` and
the untracked `.build-diagnostics/` directory. They are not BUILD-12 work.

Before BUILD-12, the protected screen was SHA-256
`A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`, Git blob
`22800a9ccb08ee5796f0fa69c87bd9995739adbf`, and 32,418 bytes. BUILD-12 does
not modify, format, stage, or commit it.

Outside scope: any production or test source change; action/tool/reader/model
implementation; `ai_assistant.dart`; registry/composition changes; new domain
API; repository, UI, schema, permission, backup/restore, networking, Chat UI,
OpenAI, mutation, tag, or push.

## AI action inventory after BUILD-11

| Build | Action ID | Tool / boundary | Domain method | Input | Result | Permission | Mode | Focused test | Exported |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 02 | `inventory_attention` | `InventoryAttentionTool` / `InventoryAttentionReader` | `InventoryAttentionService.loadAttention()` | `{}` | `List<InventoryAttentionItem>` | no caller contract | read-only | `inventory_attention_tool_test.dart` | yes |
| 03 | `financial_account_balances` | `FinancialAccountBalancesTool` / `FinancialAccountBalanceReportReader` | `accountBalanceReport(includeInactive: true)` | `{}` | `FinancialAccountBalancesResult` | `canViewFinancialReports` | read-only | `financial_account_balances_tool_test.dart` | yes |
| 04 | `financial_account_statement` | `FinancialAccountStatementTool` / `FinancialAccountStatementReportReader` | `accountStatementReport(accountId: ...)` | required `financialAccountId` | `FinancialAccountStatementResult` | `canViewFinancialReports` | read-only | `financial_account_statement_tool_test.dart` | yes |
| 05 | `financial_payment_method_summary` | `FinancialPaymentMethodSummaryTool` / `FinancialPaymentMethodReportReader` | `paymentMethodReport()` | `{}` | `FinancialPaymentMethodSummaryResult` | `canViewFinancialReports` | read-only | `financial_payment_method_summary_tool_test.dart` | yes |
| 06 | `financial_transfer_summary` | `FinancialTransferSummaryTool` / `FinancialTransferReportReader` | `transferReport()` | `{}` | `FinancialTransferSummaryResult` | `canViewFinancialReports` | read-only | `financial_transfer_summary_tool_test.dart` | yes |
| 07 | `financial_advances_and_refunds_summary` | `FinancialAdvancesAndRefundsSummaryTool` / `FinancialAdvancesAndRefundsReportReader` | `getAdvancesAndRefundsReport()` | `{}` | `FinancialAdvancesAndRefundsSummaryResult` | `canViewFinancialReports` | read-only | `financial_advances_and_refunds_summary_tool_test.dart` | yes |
| 08 | `financial_closing_reconciliation_summary` | `FinancialClosingReconciliationSummaryTool` / `FinancialClosingReconciliationReportReader` | `closingReconciliationReport()` | `{}` | `FinancialClosingReconciliationReport` | active owner | read-only | `financial_closing_reconciliation_summary_tool_test.dart` | yes |
| 10 | `financial_inflows_summary` | `FinancialInflowsSummaryTool` / `FinancialInflowsReportReader` | `inflowsReport()` | `{}` | `FlowReport` (same reference) | `canViewFinancialReports` | read-only | `financial_inflows_summary_tool_test.dart` | yes |
| 11 | `financial_outflows_summary` | `FinancialOutflowsSummaryTool` / `FinancialOutflowsReportReader` | `outflowsReport()` | `{}` | `FlowReport` (same reference) | `canViewFinancialReports` | read-only | `financial_outflows_summary_tool_test.dart` | yes |

There are nine exported tool implementations after BUILD-11. The current
`AiToolRegistry` is an immutable index of the iterable passed by its caller;
source contains no production global registry, singleton, or automatic
composition site. All nine tool files are exported by `ai_assistant.dart`.
The focused tests instantiate their registries explicitly. No duplicate action
ID, non-exported current tool, unused current financial-reader interface, or
orphaned current AI result-model file was found. BUILD-10 and BUILD-11 reuse
the canonical `FlowReport` rather than adding duplicate result models.

Compared with BUILD-09, the seven recorded actions became nine through the
approved BUILD-10 inflows and BUILD-11 outflows additions. The registry finding
is unchanged: exported definitions can be inventoried statically, while actual
runtime contents remain caller-supplied.

## The six BUILD-09 category-B candidates

### 1. Customer collections by account

- Proposed action: `financial_customer_collections_by_account`.
- Actual boundary: `Future<CustomerCollectionsByAccountReport>
  getCustomerCollectionsByAccount({DateTime? fromDate, DateTime? toDate,
  String? accountIdFilter, String? customerIdFilter})` on
  `FinancialReportService`.
- Inputs supported by the domain are all optional. `{}` uses the service's
  current-calendar-month default; account and customer filters are nullable;
  no pagination exists. The existing screen exposes date/account filters, not
  an AI input contract.
- Result: typed report with account/customer summaries, details, integer qirsh
  gross/reversal/net totals, names, nullable customer/reference/document and
  reversal IDs, and domain-owned sorting. The list fields are mutable model
  fields, so an AI action must return the same report reference and not edit it.
- Existing display permission: `canViewFinancialReports`.
- Why still B / eligibility result: **fails**. Customer resolution depends on
  optional `CustomerCollectionReportLookup`; its concrete production adapter
  is private to the UI screen and directly coordinates customer, customer
  account, and financial repositories. Calling the service without that lookup
  produces unresolved identity data. BUILD-13 would need a reusable
  domain-owned lookup/composition decision, which BUILD-12 may not create.

### 2. Supplier settlements by account

- Proposed action: `financial_supplier_settlements_by_account`.
- Actual boundary: `Future<SupplierSettlementsByAccountReport>
  getSupplierSettlementsByAccount({DateTime? fromDate, DateTime? toDate,
  String? accountIdFilter, String? supplierIdFilter,
  SupplierSettlementReportLookup? supplierLookup})` on
  `FinancialReportService`.
- Inputs are optional domain filters; `{}` uses current month. The lookup is
  also optional at the method boundary. No pagination exists.
- Result: typed account/supplier summaries and details with qirsh
  gross/reversal/net totals, nullable supplier/reference/document and reversal
  IDs, and domain sorting. Preserve its exact reference, nulls, signs, and
  order if exposed.
- Existing display permission: `canViewFinancialReports`.
- Why still B / eligibility result: **fails**. Supplier name/identity
  resolution requires `SupplierSettlementReportLookup`, whose concrete
  adapter is private UI code coordinating supplier, supplier-account, and
  financial repositories. The current stable service does not provide an
  AI-safe reusable configured boundary.

### 3. Expense analysis

- Proposed and selected action: `financial_expense_analysis`.
- Actual boundary: `Future<ExpenseAnalysisReport> expenseAnalysisReport({
  DateTime? fromDate, DateTime? toDate, String? accountIdFilter,
  PaymentMethod? paymentMethodFilter, String? categoryFilter})` on
  `FinancialReportService`; it is asynchronous and public.
- Result: `ExpenseAnalysisReport` with `int totalQirsh`, `int grandCount`,
  ordered category rows and details, nullable notes, labels, and
  `double percentageOfTotal`. The existing service owns every calculation,
  category grouping, case-insensitive category match, ordering, time default,
  and optional-expense-repository empty-report behavior. BUILD-13 must return
  the same report reference, including the double exactly as supplied; it must
  not recalculate, round, format, convert, or rebuild it.
- Existing production screen and focused tests use
  `canViewFinancialReports`; a non-active caller must also fail before the
  reader. The screen constructs the established service with its existing
  `ExpenseRepository`; BUILD-13's reader may depend only on that already
  configured `FinancialReportService`, never on a repository.
- Why it was B in BUILD-09: its optional service dependency, filter scope, and
  floating-point percentage required an explicit pass-through contract. The
  frozen subset below resolves those decisions without a new API, schema,
  permission, or domain calculation. **Passes all eligibility gates.**

### 4. Daily activity report

- Proposed action: `daily_activity_report`.
- Actual boundary: `Future<DailyActivityReport> dailyActivityReport({required
  DateTime selectedDate})` on `ReportRepository`; it is asynchronous and
  requires a date.
- Result includes financial and inventory totals, optional estimated values,
  completeness flags, missing product names, stock balances, and recent
  movements. `LocalReportRepository` directly reads seven repositories and
  performs folds, summary calculation, date selection, and fallback labels.
- Existing controller permission: `canViewReports`, not
  `canViewFinancialReports`.
- Eligibility result: **fails**. The only boundary is a multi-repository
  repository implementation rather than a dedicated AI-safe domain service;
  its required date input and broad mixed-sensitive result would need a new
  domain contract and permission/scope decision.

### 5. Stock movement / stock-adjustment reports

- Proposed action: `stock_adjustment_report`.
- Actual sources: `InventoryRepository.listAllMovements()` and the
  `StockAdjustmentReportScreen` / `InventoryController` UI path.
- Inputs in the UI are search text and adjustment-type filter; the controller
  loads all movements and the screen filters, maps product names, totals, and
  sorts. There is no immutable report DTO or report service API.
- Existing display permission: `canCreateStockAdjustment` (owner-only in the
  existing role model), not a read-report permission.
- Eligibility result: **fails**. An AI action would have to reproduce UI
  aggregation or access repositories, and the read permission/scope is not a
  settled report contract.

### 6. Sales and purchase operational summaries

- Proposed actions: `sales_operational_summary` and
  `purchases_operational_summary` were one combined BUILD-09 candidate.
- Actual sources: `SaleRepository.listSales()` and
  `PurchaseRepository.listPurchaseIntakes()` plus controllers/UI aggregation.
  Both are raw repository lists; no canonical summary DTO/service, default
  period, filter contract, or settled report permission was found.
- Eligibility result: **fails**. A new domain boundary and product decision
  would be necessary; AI cannot aggregate raw lists or access repositories.

## Eligibility gates and ranking

Score scale: 0 absent/high risk, 1 weak, 2 partial, 3 established/low risk.
Scores are explanatory only; a candidate failing any eligibility gate cannot
be selected regardless of total.

| Candidate | Boundary | Inputs | Permission | Pass-through result | Testability | Low transform risk | Low repository risk | Time risk | Scope | Similarity | User value | Deferred overlap | Total | Eligible |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Expense analysis | 3 | 3 | 3 | 3 | 3 | 2 | 3 | 3 | 3 | 3 | 3 | 3 | 35 | yes |
| Customer collections | 2 | 2 | 3 | 3 | 2 | 2 | 1 | 3 | 2 | 2 | 3 | 2 | 27 | no: UI-private lookup |
| Supplier settlements | 2 | 2 | 3 | 3 | 2 | 2 | 1 | 3 | 2 | 2 | 3 | 2 | 27 | no: UI-private lookup |
| Daily activity | 1 | 2 | 2 | 2 | 2 | 1 | 0 | 2 | 1 | 1 | 3 | 1 | 18 | no: repository-derived |
| Stock adjustment | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 0 | 2 | 2 | 8 | no: UI/repository-derived |
| Sales/purchase summaries | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 3 | 2 | 6 | no: raw lists only |

The expense score is reduced from a perfect score because the domain result
contains `double percentageOfTotal` and the service can return a canonical
empty report when it was constructed without an expense repository. These are
handled by direct pass-through and explicit configured-service dependency, not
by AI calculations.

## Frozen BUILD-13 contract

### Identity and execution

- Build: `BUILD-13`.
- Action ID: `financial_expense_analysis`.
- Type and execution mode: read-only / `AiExecutionMode.readOnly`.
- Confirmation: none.
- Mutation, writes, side effects, networking, exports, tool chaining, and
  global registry composition: prohibited.

### Exact input schema

The top-level value must be an object. It may contain only the following
optional properties; `{}` is valid and uses the existing domain current-month
default. Additional keys are rejected, including keys with null values.

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "accountId": {"type": "string", "nonBlank": true},
    "paymentMethod": {
      "type": "string",
      "enum": ["cash", "bankTransfer", "mobileWallet", "check"]
    },
    "category": {"type": "string", "nonBlankAfterTrim": true}
  }
}
```

No property is required. `accountId` must not be blank or whitespace and is
forwarded unchanged; the action must not look it up. `paymentMethod` is mapped
only to the existing `PaymentMethod` enum value. `category` must not be blank
after trimming and is forwarded to the domain method, which already owns its
case-insensitive matching semantics. Null, arrays, scalars, unknown enum
values, unknown keys, date keys, pagination, sorting, and unlisted filters are
validation failures. `fromDate` and `toDate` are intentionally excluded:
BUILD-13 must call the service with no date values so the established domain
time source remains authoritative.

### Authorization, boundary, and result

- Required authorization: `caller != null`, `caller.canProceed`, and
  `caller.permissions.canViewFinancialReports`.
- Validation and authorization occur before a reader call. Owner role is not a
  substitute for this permission.
- Proposed reader interface:
  `Future<ExpenseAnalysisReport> loadExpenseAnalysisReport({String?
  accountIdFilter, PaymentMethod? paymentMethodFilter, String?
  categoryFilter});`
- Reader implementation: direct delegation to the already configured
  `FinancialReportService.expenseAnalysisReport(...)`, passing only the three
  frozen optional filters and no dates.
- Result: return the exact `ExpenseAnalysisReport` reference as structured
  action data; no wrapper/result model is needed.
- Preserve all domain order, categories, rows, details, qirsh values, count,
  `percentageOfTotal` double, null notes, labels, and canonical empty report.
  Do not mutate its lists, recalculate percentages/totals, normalize null,
  remove zero values, sort, or build tables/maps/DTO copies.

Allowed BUILD-13 dependencies are `AppUser`, the existing AI contract/result
types, `PaymentMethod`, `ExpenseAnalysisReport`, the reader interface, and an
already configured `FinancialReportService`. Forbidden dependencies include
all repositories, `AppRepositories`, database/storage APIs, `DateTime.now`,
UI/controllers, exports, network APIs, and other AI tools.

### Required BUILD-13 tests

1. Registry discovers one unique action ID and export remains explicit.
2. Metadata is read-only with no confirmation.
3. `{}` and every allowed single/combined filter are accepted and forwarded
   exactly once to a fake reader.
4. Extra keys, null keys, blank values, invalid payment-method strings,
   non-object payloads, date/sorting/pagination keys, and wrong mode fail
   before the reader.
5. Missing, inactive, and non-financial-report callers fail before the reader;
   an active caller with the actual permission is accepted.
6. The authorized result is the same `ExpenseAnalysisReport` reference,
   preserving order, qirsh, `double percentageOfTotal`, null notes, counts,
   and empty reports.
7. Reader failures become the existing safe AI failure response.
8. Source checks prove direct service delegation and no repository,
   `DateTime.now`, sort, fold/reduce, financial calculation, or result
   reconstruction in AI code.

Expected BUILD-13 files: a financial expense-analysis reader interface and
adapter in the established reader module, the tool, its export,
`financial_expense_analysis_tool_test.dart`, and a BUILD-13 document. No
result model, global registry, domain/repository/UI/schema/permission change,
or production composition is expected. Proposed commit message:
`BUILD-13: add financial expense analysis action`.

## Exclusions and architectural decisions

BUILD-13 must not add dates, custom periods, account-name lookup, category
aggregation, percentage calculation, direct expense/financial repository
access, UI filters, exports, new permission flags, mutations, Chat/OpenAI, or
cloud/mobile/multi-device work. It must not solve the customer/supplier lookup
boundary, daily activity repository aggregation, stock UI derivation, or
sales/purchase summary gap; those remain separate architectural decisions.

No additional owner decision is required for the frozen expense-analysis
contract: its permission, method, filter vocabulary, default period, and
result shape are evidenced by the current screen, domain service, model, and
tests. A future change to expose date filters or any non-frozen filter requires
a separate owner/product decision rather than silently extending BUILD-13.

## BUILD-12 verification and delivery

BUILD-12 changes this documentation file only. `git diff --check` passed; the
only BUILD-12 file is this document. `flutter test` passed 1,384 tests with 0
failures and 1 expected skip. `flutter analyze --no-pub` and the direct bundled
Dart SDK command `C:\\src\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe
analyze` reported no issues.

`flutter build windows --release` exited 0 and produced
`build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe`
(785,408 bytes; modified 2026-07-18 22:22:32 local time). The build emitted
only the existing Firebase CMake deprecation and MSVCRT LNK4078 warnings.

The final protected-file proof and commit hash are recorded after the commit.
The protected screen and `.build-diagnostics/` remain outside staging. No tag
and no push are created.
