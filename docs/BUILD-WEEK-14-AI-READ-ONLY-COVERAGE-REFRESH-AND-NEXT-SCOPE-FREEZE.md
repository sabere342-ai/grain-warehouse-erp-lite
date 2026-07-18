# BUILD-14 — AI Read-Only Coverage Refresh and Next Scope Freeze

## Executive summary

BUILD-14 is documentation and architecture audit only. It refreshes the
actual AI action inventory after BUILD-13 and re-evaluates the uncovered
BUILD-09 candidates. It adds no tool, reader, result model, registry,
production composition, test, domain API, repository, permission, UI, schema,
migration, backup/restore path, tag, or push.

Baseline: `51c6fdc2a5df728358a21905e980579edae134eb`
(`BUILD-13: add financial expense analysis action`). The inherited modified
financial-reports screen and untracked `.build-diagnostics/` are protected
baseline state, not BUILD-14 work.

## Flutter execution rule

Flutter commands that use the SDK cache must run outside the workspace
sandbox in this environment. The sandbox cannot write
`C:\src\flutter\bin\cache\lockfile`, causing `flutter.bat` to retry without
progress. This is environmental, not a source or Windows-build defect.
BUILD-14 neither runs `flutter clean` nor deletes build artifacts for it.

## Actual AI action inventory after BUILD-13

The source exports ten concrete `AiTool` implementations. All are read-only
and confirmation-free. Tools remain explicitly supplied by callers to
`AiToolRegistry`; there is no production global registry, singleton,
auto-discovery, composition root, or Chat wiring.

| Build | Action ID | Tool / reader | Input | Permission | Domain method | Result | Focused test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 02 | `inventory_attention` | `InventoryAttentionTool` / `InventoryAttentionReader` | `{}` | no caller contract | `InventoryAttentionService.loadAttention()` | canonical list | `inventory_attention_tool_test.dart` |
| 03 | `financial_account_balances` | balances tool / balance reader | `{}` | `canViewFinancialReports` | `accountBalanceReport(includeInactive: true)` | existing AI projection | balance tool test |
| 04 | `financial_account_statement` | statement tool / statement reader | non-blank `financialAccountId` | `canViewFinancialReports` | `accountStatementReport(accountId: ...)` | existing AI projection | statement tool test |
| 05 | `financial_payment_method_summary` | payment-method tool / reader | `{}` | `canViewFinancialReports` | `paymentMethodReport()` | existing AI projection | payment-method tool test |
| 06 | `financial_transfer_summary` | transfer tool / reader | `{}` | `canViewFinancialReports` | `transferReport()` | existing AI projection | transfer tool test |
| 07 | `financial_advances_and_refunds_summary` | advances/refunds tool / reader | `{}` | `canViewFinancialReports` | `getAdvancesAndRefundsReport()` | existing AI projection | advances/refunds tool test |
| 08 | `financial_closing_reconciliation_summary` | closing tool / reader | `{}` | active owner | `closingReconciliationReport()` | same domain report | closing tool test |
| 10 | `financial_inflows_summary` | inflows tool / reader | `{}` | `canViewFinancialReports` | `inflowsReport()` | same `FlowReport` | inflows tool test |
| 11 | `financial_outflows_summary` | outflows tool / reader | `{}` | `canViewFinancialReports` | `outflowsReport()` | same `FlowReport` | outflows tool test |
| 13 | `financial_expense_analysis` | expense tool / reader | optional `accountId`, `paymentMethod`, `category` | `canViewFinancialReports` | `expenseAnalysisReport(...)` | same `ExpenseAnalysisReport` | expense tool test |

The financial tools authorize before the reader. Inventory attention is the
pre-existing exception without an injected caller contract; BUILD-14 records
but does not redesign it. The ten static IDs are unique, every tool has a
focused test, each financial reader is consumed by its matching tool, and the
five existing financial AI result models are consumed by their corresponding
legacy projection tools. Direct pass-through actions intentionally have no
parallel result model. No orphan reader, model, export, or global production
wiring was found.

## BUILD-09 / BUILD-12 refresh

BUILD-09 recorded seven actions, two A candidates, and six B candidates.
BUILD-10 and BUILD-11 implemented inflows and outflows. BUILD-12 selected and
froze expense analysis; BUILD-13 implemented it as
`financial_expense_analysis`. Expense analysis is therefore covered and not a
new candidate.

## Remaining category-B candidates

| Candidate | Documented action ID | Actual boundary | Blocking evidence | Eligibility |
| --- | --- | --- | --- | --- |
| Customer collections by account | `financial_customer_collections_by_account` | Public async `FinancialReportService.getCustomerCollectionsByAccount({DateTime? fromDate, DateTime? toDate, String? accountIdFilter, String? customerIdFilter})` | `{}` has a service-month default and the result has canonical qirsh totals/order/nulls, but identity resolution remains UI-private repository composition. AI cannot reproduce it or expose unresolved identities. | Not eligible |
| Supplier settlements by account | `financial_supplier_settlements_by_account` | Public async `FinancialReportService.getSupplierSettlementsByAccount({DateTime? fromDate, DateTime? toDate, String? accountIdFilter, String? supplierIdFilter, SupplierSettlementReportLookup? supplierLookup})` | The configured lookup is UI-private repository composition. No established AI-safe reader can supply it. | Not eligible |
| Daily activity report | `daily_activity_report` | `ReportRepository.dailyActivityReport({required DateTime selectedDate})` | Repository boundary reads seven repositories, owns date selection, folds, fallback labels and mixed financial/inventory aggregation. `canViewReports` and its AI scope are not frozen. | Not eligible |
| Stock movement / adjustment | `stock_adjustment_report` | `InventoryRepository.listAllMovements()` plus screen/controller | No canonical report DTO/service; UI filters, maps, totals and sorts. Existing `canCreateStockAdjustment` is owner operation permission, not a settled report-read contract. | Not eligible |
| Sales / purchase operational summaries | `sales_operational_summary`, `purchases_operational_summary` | raw `SaleRepository.listSales()` / `PurchaseRepository.listPurchaseIntakes()` | No report result, default period, filter schema or settled report permission. AI would need a new domain boundary or aggregate raw lists. | Not eligible |

Every remaining B candidate fails at least one mandatory gate: reusable
configured service boundary, frozen input/time scope, existing read
permission, direct-result pass-through, or repository-free AI reader. These
are architectural failures, not score trade-offs.

## Category-C review

All B candidates fail, so BUILD-09 category C was opened. Audit-log history,
document history, and backup validation/preview remain ineligible: privacy,
sensitive identity/content scope, and authorization decisions are unresolved;
no frozen AI-safe input/result boundary exists. BUILD-14 invents no action ID,
permission, or retention policy.

## Decision matrix

Strict gates precede scoring. No candidate is eligible or selected.

| Candidate | Boundary | Input | Permission | Pass-through | Testability | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Customer collections | 2 | 2 | 3 | 2 | 2 | UI-private lookup blocks the reader |
| Supplier settlements | 2 | 2 | 3 | 2 | 2 | UI-private lookup blocks the reader |
| Daily activity | 1 | 1 | 2 | 1 | 1 | repository aggregation blocks the reader |
| Stock adjustment | 0 | 1 | 1 | 0 | 1 | UI-derived report and permission scope unresolved |
| Sales/purchase summaries | 0 | 0 | 0 | 0 | 1 | raw lists; domain contract missing |
| Category C | — | — | — | — | — | owner privacy/product decision required |

## BUILD-15 decision

**No BUILD-15 action is frozen.** Selecting an action would invent a contract.
The smallest owner decision is an independently scoped prerequisite: authorize
one reusable configured domain report boundary, including any identity lookup,
the exact read permission, and `{}`/filter/time contract. A later freeze may
only select an unused ID after that prerequisite exists.

There is therefore no BUILD-15 input schema, reader, domain call, result
rule, expected implementation file list, focused test list, or commit message.
Any future action must be read-only and confirmation-free; check permission
before its reader; depend on a configured service only; and preserve domain
ordering, nulls, totals, signs, and errors without calculation, sorting,
grouping, transformation, repository access, or global registry.

## Exclusions and delivery

BUILD-14 excludes changes under `lib/`, `test/`, `windows/`, `pubspec.yaml`,
and `pubspec.lock`, plus UI, domain/repository/permission/schema work,
networking, cloud, mobile, multi-device work, tags and push. This document is
the only intended BUILD-14 file. The protected screen and
`.build-diagnostics/` remain outside staging.

Verification completed after this document was written:

- `git diff --check` passed.
- `flutter test` outside the sandbox passed 1,396 tests with 0 failures and
  1 expected skip.
- `flutter analyze --no-pub` outside the sandbox reported no issues.
- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze` reported no
  issues.
- `flutter build windows --release` outside the sandbox exited 0 and produced
  `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
  (785,408 bytes; modified 2026-07-19 00:18:56 local time). The only warnings
  were the existing Firebase CMake deprecation and MSVCRT LNK4078 warnings.

No production or test source change, tag, or push is made.
