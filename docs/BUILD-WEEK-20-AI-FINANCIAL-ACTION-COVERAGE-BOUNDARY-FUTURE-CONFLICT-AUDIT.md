# BUILD-20 — AI Financial Action Coverage, Boundary, and Future-Conflict Audit

## Verified baseline

- Baseline: `048297a0cfa590568e96de46be3641fc38695896` — `BUILD-19: add supplier payments financial account AI action`.
- Preflight worktree: only inherited modified `lib/features/financial_reports/advances_and_refunds_report_screen.dart` and untracked `.build-diagnostics/`.
- Protected file: SHA-256 `A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`; blob `22800a9ccb08ee5796f0fa69c87bd9995739adbf`; 32,418 bytes; modified and unstaged as inherited.
- Source inventory: 12 exported AI tools. Registries are constructed from caller-supplied iterables, reject duplicate IDs, and store an unmodifiable map.

## Action matrix

All financial tools use `readOnly`, require no confirmation, authorize before their injected reader, and return existing safe validation/failure responses. The authorization expectation for financial reports is `canViewFinancialReports`; closing reconciliation is owner-only through the existing caller contract. No reader imports a repository.

| ID | Tool / reader | Inputs | Boundary / result | Notes |
| --- | --- | --- | --- | --- |
| `inventory_attention` | `InventoryAttentionTool` / `InventoryAttentionReader` | none | `InventoryAttentionService.loadAttention()` / immutable items | Pre-existing non-financial exception; no caller permission contract. |
| `financial_account_balances` | balances tool / balance reader | none | `accountBalanceReport(includeInactive: true)` / AI balances projection | Account identity and balances. |
| `financial_account_statement` | statement tool / statement reader | `financialAccountId` | `accountStatementReport(accountId:)` / statement projection | Exact one-account statement. |
| `financial_payment_method_summary` | payment-method tool / reader | none | `paymentMethodReport()` / `PaymentMethodReport` | Canonical payment-method aggregate. |
| `financial_transfer_summary` | transfer tool / reader | none | `transferReport()` / `TransferReport` | Transfer register only. |
| `financial_advances_and_refunds_summary` | advances/refunds tool / reader | none | `getAdvancesAndRefundsReport()` / `AdvancesAndRefundsReport` | Governed credit/refund semantics. |
| `financial_closing_reconciliation_summary` | closing tool / reader | none | `closingReconciliationReport()` / canonical report | Owner-gated closing/reopening history. |
| `financial_inflows_summary` | inflows tool / reader | none | `inflowsReport()` / `FlowReport` | Canonical inflow report. |
| `financial_outflows_summary` | outflows tool / reader | none | `outflowsReport()` / `FlowReport` | Canonical outflow report. |
| `financial_expense_analysis` | expense tool / reader | optional account, method, category | `expenseAnalysisReport(...)` / `ExpenseAnalysisReport` | Domain-owned filtering. |
| `financial_customer_collections_by_account` | customer tool / dedicated reader | account, start/end, optional customer | BUILD-16 collections boundary / canonical immutable report | Date syntax in AI; filtering, ordering, sum in domain. |
| `financial_supplier_payments_by_account` | supplier tool / dedicated reader | account, start/end, optional supplier | BUILD-18 payments boundary / canonical immutable report | Preserves duplicate IDs and allocation-compatible rows. |

Focused test files for the last two are `customer_collections_by_financial_account_tool_test.dart` and `supplier_payments_by_financial_account_tool_test.dart`; each proves permission-before-reader, immutable pass-through, null preservation, input rejection, and no repository/calculation/sort dependency. Earlier action tests and `ai_execution_service_test.dart` prove the same established registry and safe-error patterns.

## Boundary ownership

`FinancialReportService` owns balances, statements, payment-method reports, transfers, flows, closing reconciliation, advances/refunds, and expense filtering/calculation. `InventoryAttentionService` owns inventory classification. BUILD-16 and BUILD-18 services own party identity lookup including inactive parties, local inclusive date normalization, exact account/party filtering, cancellation exclusion, qirsh totals, immutable rows, and canonical ordering.

Repository access is confined to those domain services. AI performs only tool-shape validation, local date parsing where an input is serialized, mode/permission checks, and delegation. AI must never recalculate qirsh totals or row counts, reorder rows, filter canonical rows, enrich identity, or repair nulls. Nullable payment methods remain nullable. Existing canonical reports are immutable or are projected by the established legacy result models where that pre-dates BUILD-16/18.

## Coverage, overlap, privacy, and registry findings

- Account balances, statement, payment method, transfers, flows, expenses, closing, collections, and supplier payments are distinct capability groups.
- Inflows/outflows are acceptable complementary specializations of one `FlowReport`, not duplication: direction is a domain-owned distinction.
- Statement versus balances is no meaningful overlap: movement history/running balance differs from account summaries.
- Customer collections and supplier payments are purposeful counterparts with distinct domains and report-entry contracts; neither is a renamed ledger report.
- The legacy customer-collections and supplier-settlements methods in `FinancialReportService` are not candidates for more AI wrappers: they use different defaults, mutable lists and/or lookup composition. BUILD-16/18 supersede only the narrowly approved per-account read boundaries.
- All financial tools sanitize unexpected errors through `AiExecutionService`; they expose neither stack traces nor repository/persistence details. Tool/reader source tests reject repository imports and report transformation primitives.
- `AiToolRegistry` has no default instance, global mutable state, singleton, or auto-discovery. `AiExecutionService` receives a registry explicitly. BUILD-17 and BUILD-19 full-inventory fixtures demonstrate 11 then 12 caller-supplied IDs.

## Future-conflict analysis

Split Payments makes transaction-ID uniqueness and one-transaction-one-row assumptions unsafe. BUILD-18/19 correctly use report-entry rows and retain duplicate IDs. A future transaction-by-account candidate requires an allocation-aware immutable domain boundary before AI exposure.

Advances, overpayments, and refunds must not be classified as ordinary collections or supplier payments; the existing advances/refunds action remains the governed report. Negative-balance policy must never be inferred from a report. Closing/reopening reports distinguish historical reconciliation from mutable balances and must remain owner-gated. Backup compatibility requires respecting older restored null links; AI must preserve nulls. Cloud, mobile, and multi-device work reject global state, local paths, widget context, and mutable registries; current caller injection is compatible.

## Candidate evaluation

| Candidate | Boundary | Risk / duplication | Decision |
| --- | --- | --- | --- |
| Allocation-aware transaction-by-account report | none | Would overlap ledger and conflict with Split Payments without new domain work | Reject/defer. |
| Another party-payment action | BUILD-16/18 already covered | Probable duplication | Reject. |
| More flow variants | `FlowReport` already answers direction questions | Naming/discovery concern, not new capability | Do not add action. |
| No new action; document discovery/composition scope | existing 12 boundaries | Low risk, no accounting change | Strongest candidate. |

## BUILD-21 recommendation

**Title:** BUILD-21 — AI Action Discovery and Caller-Supplied Composition Scope Freeze.

**Category:** documentation and architecture only; no action or domain method.

It should inventory the twelve action descriptions, define a non-global caller-composition guide, and decide whether the current catalog needs approved discovery metadata. It must not add an action name, alter inputs/output, introduce a default registry, or expose new data. This is better than a thirteenth financial action because the evidence shows complete narrow coverage for the newly safe collection/payment counterpart pair while the remaining plausible reports either duplicate ledger reports or require allocation-aware future domain work.

Privacy exclusions remain contact data, balances unless already authorized by an existing action, auth/audit/persistence data, paths, and raw entities. The scope remains read-only and confirmation-free. Owner approval would still be needed for any future discovery mechanism that changes runtime composition or action visibility.

**BUILD-21 is not authorized by BUILD-20. A separate owner decision is required before implementation.**
