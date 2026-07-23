# Phase 85 — Inventory & Entities Design-System Migration

## Status

- Phase 85 is **open** on `phase-85-inventory-entities-design-system-migration`.
- This document records the repository-first inventory and approved scope before the first production-code edit.
- Closure remains conditional on focused regressions, the full Flutter suite, analyzer, Windows release build, diff review, one coherent commit, a new annotated tag, and a clean tree.

## Verified baseline and governance

- Starting branch: `phase-84-high-risk-transaction-ui-migration`.
- Starting commit: `4f5bc97fc6d2a12f2d359a7c87121d08f0b973b9`.
- `phase-84-high-risk-transaction-ui-migration-verified` is an annotated tag and dereferences to the starting commit.
- The starting working tree had no tracked, staged, or untracked changes.
- Repository documentation, local history, local refs, tags, and remote heads did not reserve Phase 85 for another purpose.
- Phase 85 starts from the exact Phase 84 closure commit; schema version 14 and Backup version 7 are frozen.

## Roadmap authority and selected wave

`PHASE-83-SCREEN-MIGRATION-ROADMAP.md` assigns wave 2 to:

- Products.
- Customers.
- Inventory.
- Stock take.
- Adjustment history.
- Statements.

The stated objectives are unified search/filter, responsive lists/tables, and no-data/no-results states. The mandatory domain gates are stock invariants, balances, and document history.

**Phase 85 name derivation:** The name "Inventory & Entities Design-System Migration" is derived from Wave 2 content in the Phase 83 roadmap. Wave 2 covers inventory screens and entity management screens (Products, Customers) that were explicitly deferred by Phase 84.

## Route and entry-point inventory

| Surface | Entry point | Mutation boundary | Permission gate | Financial or inventory effect |
|---|---|---|---|---|
| Products | `DashboardShell` → `ProductsScreen` | `ProductController.createProduct/updateProduct/setProductActive` | `canManageProducts` | product catalog, reference prices |
| Customers | `DashboardShell` → `CustomersScreen` | `CustomerController.createCustomer/updateCustomer` | `canCreateCustomerPayment` or settings access | customer records, account references |
| Inventory | `DashboardShell` → `InventoryScreen` | `InventoryController.createOpeningBalance/createManualIncrease/createManualDecrease` | `canCreateStockAdjustment` | stock balances, stock movements |
| Stock Take | `InventoryScreen` → `StockTakeScreen` | `InventoryController.submitStockTake` | `canCreateStockAdjustment` | stock variances, adjustments |
| Adjustment Report | `InventoryScreen` → `StockAdjustmentReportScreen` | Read-only | `canCreateStockAdjustment` | adjustment history display |
| Supplier Statement | `SuppliersScreen` → `SupplierStatementScreen` | Payment entry (already migrated in Phase 84) | supplier-payment permission | payable, financial account |

These screens use the existing controllers, repositories, and authorization rules. Phase 85 will not introduce alternate transaction services or change their identifiers, payloads, equations, or authorization rules.

## Exact production scope

### Included root/list surfaces

- `ProductsScreen`.
- `CustomersScreen` (full list/search/card migration — Phase 84 only migrated collection flow).
- `InventoryScreen`.
- `StockTakeScreen`.
- `StockAdjustmentReportScreen`.

### Included dialogs

- Product creation and editing dialog.
- Customer creation and editing dialog.
- Stock movement creation dialog.
- Opening balance dialog.
- Stock take submission dialog.

### Intentionally deferred

- Supplier statement full redesign beyond payment entry: already migrated in Phase 84.
- Financial reports, daily report, closing/reconciliation: wave 3.
- Business identity editor, Backup/Restore, data wipe, audit logs, help: wave 4.
- Invoice/statement/report printing and preview redesign: wave 5.
- Customer/supplier master-data forms and opening balances, except where a transaction entry must remain reachable: not part of wave 2.

## Initial UI gap matrix

| Target | Current evidence | Safety/responsive gap | Phase 85 treatment | Domain contract held fixed |
|---|---|---|---|---|
| Products list/header | manual `Row`, direct colors and ad-hoc loading/empty/error | actions can compress on compact widths; states are inconsistent | shared page header, tokens, standard states, responsive action wrapping | product loading, permissions, record order |
| Product form | raw `AlertDialog`; no reusable dialog bound | compact overflow risk, no reusable dialog bound, no unsaved-close guard | responsive form dialog, sections/summary, compact stacking, dirty-form confirmation, guarded submit | name validation, price validation, unit selection, active status |
| Customers list/header | manual header and ad-hoc states | compact action compression, no unified search | shared header/states/tokens, unified search/filter | permissions, sorting, document history route |
| Customer form | raw dialog with account impact | fixed dialog layout, no dirty guard | responsive form shell, sections, dirty guard, submit lock | name, phone, notes validation |
| Inventory list/header | manual header and ad-hoc states | inconsistent state semantics and compact actions | shared header/states/tokens | loaded records and permission contract |
| Inventory movement form | raw dialog; no current-balance impact preview; no local submit lock | compact/keyboard and duplicate-tap risk | responsive form shell, sections, account/method clarity, dirty guard, submit lock | product selection, movement type, quantity, unit conversion, note |
| Opening balance dialog | raw dialog with confirmation | fixed dialog layout, no dirty guard | responsive form shell, quantity/unit selection, dirty guard, submit lock | product, quantity, unit conversion |
| Stock Take screen | direct Scaffold/AppBar and ad-hoc body states | inconsistent back/state behavior | align with Phase 83 primitives; preserve navigator route | stock take workflow, variance calculation |
| Adjustment Report screen | direct Scaffold/AppBar and read-only body | inconsistent back/state behavior | align with Phase 83 primitives; preserve navigator route | adjustment history display |

## Final shared UI architecture

Phase 85 will use the existing reusable presentation primitives from Phase 83 and Phase 84:

- `GhalalPageHeader`: for consistent page headers with title and subtitle.
- `GhalalStateView`: for unified loading, empty, and error states with retry.
- `GhalalSearchField`: for unified search/filter on list screens.
- `GhalalResponsiveDialog`: for responsive form dialogs with dirty-close protection.
- `GhalalStatusBadge`: for status indicators where applicable.
- `PremiumCard`: for content containers (existing, may need token alignment).

No new shared components are expected to be needed. If a genuine shared need arises during implementation, it will be documented.

All primitives must use `app_tokens.dart`, the established theme, directional padding/alignment, minimum touch targets, tooltips/semantics for icon-only controls, and the existing `ResponsiveLayout`. No repository query may move into `build`.

## Implemented production migration

Phase 85 has not started yet. This section will be updated during implementation.

## Production files changed

Phase 85 has not started yet. This section will be updated during implementation.

## Production-logic defect assessment

No accounting, inventory, approval, persistence, routing, authorization-policy, or report-calculation defect was found or changed. The only production behavior hardening is presentation-layer re-entry prevention, busy-state visibility, accurate Pending/Executed wording, retry wiring to existing controller loads, and unsaved-input protection.

## State and wording contract

- Successful direct execution is reported only after the existing service/controller confirms it.
- A Phase 82 insufficient-balance submission is described as a durable pending request and explicitly as not executed.
- Rejected, cancelled, stale, and executed approval states retain their Phase 82 meanings.
- Loading, no business data, recoverable error/retry, and loaded data are distinct. Search-empty applies only to included lists that already expose search; Phase 85 will not invent speculative filters.
- Recoverable validation keeps entered data. Repeated primary actions are disabled while submitting.

## Responsive, RTL, accessibility, and navigation acceptance

The dedicated Phase 85 suite will exercise 360×800, 390×844, 800×1024, a small practical Windows viewport, 1366×768, and 1600×900. It will assert reachable primary actions, no overflow, long Arabic labels, text scaling, RTL direction, logical action order, semantic status text, icon-action tooltips, and keyboard-safe scrolling.

The existing shell remains the only root navigation architecture. Dashboard selection, mobile More drawer, desktop sidebar, route-local back, and `Alt+Left` remain Phase 83 contracts. Dirty transaction dialogs will require an explicit discard decision rather than silently losing entered values.

## Frozen invariants and regression plan

- Schema: 14 before and after.
- Backup: 7 before and after; prior-version restore compatibility unchanged.
- No storage-format, ledger, balance, inventory, report, approval-state, stale-state, routing, ID, actor, authorization, or reversal change.
- Existing sale, purchase, expense, customer-account, supplier-account, financial-account, Phase 82, Phase 83, reporting, backup, DC-U007, and DC-U008 suites remain regression gates.
- Dedicated Phase 85 tests will add meaningful widget assertions for responsive dialogs/screens, disabled repeated submission, dirty-close handling, financial labels and Pending copy, RTL/accessibility, and reuse of standard states. Existing domain tests remain the source of truth for exact financial mutations.

## Tests added or strengthened

Phase 85 has not started yet. This section will be updated during implementation.

## Closure evidence

Phase 85 remains **open** because implementation has not started yet.

- Focused tests: pending.
- Full test suite: pending.
- Analyzer: pending.
- Windows release build: pending.
- `git diff --check`: pending.
- Schema remains 14 and Backup remains 7.
- No files are staged. No commit or tag was created, and nothing was pushed.

Closure requires implementation, focused tests, full suite verification, analyzer, fresh Windows release build, diff review, one coherent commit, a new annotated tag, and a clean tree.

## Known residual risks

- The Products, Customers, Inventory, Stock Take, and Adjustment Report screens have not yet been instantiated at every one of the six viewport sizes. This stricter matrix remains required before verified closure.
- The shared dirty-back guard currently uses `WillPopScope` with a scoped deprecation suppression because `PopScope` blocked the existing programmatic success-pop contract in widget evidence. A future Flutter upgrade should migrate this carefully with tests for both user back/Escape and successful submit.
- The repository-wide pre-existing formatter debt (49 files) remains an operational concern unrelated to Phase 85 and was not introduced or expanded by this phase.
