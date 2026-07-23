# Phase 85 — Inventory & Entities Design-System Migration

## Status

- Phase 85 is **closed** on `phase-85-inventory-entities-design-system-migration`.
- Implementation commit: `2f64e88514b3e06727f890cbb0bd0e325165150e`.
- Closure commit: added in the commit immediately following this document update.
- Annotated tag: `phase-85-inventory-entities-design-system-migration-verified` pointing at the closure commit.
- Closure date: 2026-07-23.

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

- Products and Inventory screens now use `GhalalPageHeader` plus distinct loading, empty, and initial-error/retry states.
- Product creation/editing, stock movement, and opening balance dialogs use the shared responsive shell, directional spacing, scroll-safe content, dirty-close protection, and guarded primary actions.
- Stock take and adjustment report navigation buttons are integrated into the header actions with proper responsive wrapping.
- Confirmation dialogs for opening balance and stock movement use the shared responsive dialog pattern.
- The `GhalalPageHeader` shared component was fixed to handle multiple action buttons at narrow viewports by wrapping the actions in a `Flexible` widget.

## Production files changed

- `lib/features/products/products_screen.dart`.
- `lib/features/inventory/inventory_screen.dart`.
- `lib/shared/widgets/ghalal_page_header.dart` (overflow fix for multiple action buttons).

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

- Updated `test/phase11_ux_test.dart` to match the new `GhalalEmptyState` title/message format for Products screen empty state.
- Existing inventory, stock take, and adjustment report tests continued to pass after migration.
- No new dedicated Phase 85 test file was needed because existing tests already covered the migrated screens comprehensively.

## Closure evidence

Phase 85 is **closed** after all mandatory gates passed successfully.

### Pre-build verification (on implementation commit `2f64e88`)

- Focused tests: 69/69 passed (inventory, stock take, adjustment report, Phase 11 UX).
- Full test suite: 1562 passed, 1 skipped (pre-existing intentional skip, not from Phase 85), 0 failed.
- Analyzer: `flutter analyze --no-pub` — `No issues found!`.
- `git diff --check`: passed (CRLF warnings only on `windows/flutter/generated_*` and `ghalal_page_header.dart`, no whitespace errors).

### Windows release build

- Build command: `flutter build windows --release`
- Build HEAD: `2f64e88514b3e06727f890cbb0bd0e325165150e`
- Build start: 2026-07-23 15:11:31
- Build result: success (75.6s)
- EXE path: `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- EXE size: 785,408 bytes
- EXE last-write time: 2026-07-23 15:13:11 (after build start)
- Known warnings during build: CMake deprecation warning for Firebase SDK `cmake_minimum_required < 3.10`, MSVCRT LNK4078 `.voltbl` section warning. Neither constitutes a build failure; the EXE was produced and is functional.

### Post-build verification

- `git rev-parse HEAD`: `2f64e88514b3e06727f890cbb0bd0e325165150e` — unchanged.
- `git status --short`: empty — tree clean.
- `git diff --check`: passed.
- Source files were not modified by the build.

### Post-document-update verification (before closure commit)

- Analyzer: `flutter analyze --no-pub` — `No issues found!`.
- Full test suite: 1562 passed, 1 skipped, 0 failed.
- `git diff --check`: passed.
- `git status --short`: only the Phase 85 document itself is modified.

### Diff review

- Only production files in scope were modified: ProductsScreen, InventoryScreen, GhalalPageHeader.
- One test file updated to match new UI (legitimate migration change).
- Phase 85 document added.
- No secrets or sensitive paths were introduced.
- No formatter sweep was performed.
- The pre-existing formatter debt of 49 unrelated files remains unchanged and out of scope.
- Schema remains 14 and Backup remains 7.

### Governance

- Phase 85 was derived from Wave 2 of the Phase 83 roadmap.
- Closure commit created after all gates passed.
- Final annotated tag `phase-85-inventory-entities-design-system-migration-verified` created on the closure commit.
- No push was performed (not a blocker).
- Phase 86 was not started.

## Known residual risks

- The Products and Inventory screens have been migrated but not every real form has been instantiated independently at every one of the six viewport sizes. This stricter matrix remains a known residual risk but does not block closure.
- The shared dirty-back guard currently uses `WillPopScope` with a scoped deprecation suppression because `PopScope` blocked the existing programmatic success-pop contract in widget evidence. A future Flutter upgrade should migrate this carefully with tests for both user back/Escape and successful submit.
- The repository-wide pre-existing formatter debt (49 files) remains an operational concern unrelated to Phase 85 and was not introduced or expanded by this phase.
