# Phase 84 — High-Risk Transaction Screens Design-System Migration & UX Safety

## Status

- Phase 84 is **closed** on `phase-84-high-risk-transaction-ui-migration`.
- Implementation commit: `dff5abdac10fe2d4c822dceaadee8fff3df4f8f6`.
- Closure commit: added in the commit immediately following this document update.
- Annotated tag: `phase-84-high-risk-transaction-ui-migration-verified` pointing at the closure commit.
- Closure date: 2026-07-23.

## Verified baseline and governance

- Starting branch: `phase-83-ui-ux-design-foundation`.
- Starting commit: `6b78398239dba4754fb1f99f7af6a17eaecba1c1`.
- `phase-83-ui-ux-design-foundation-verified` is an annotated tag and dereferences to the starting commit.
- The starting working tree had no tracked, staged, or untracked changes.
- Repository documentation, local history, local refs, tags, and remote heads did not reserve Phase 84 for another purpose.
- Phase 84 starts from the exact Phase 83 commit; schema version 14 and Backup version 7 are frozen.

## Roadmap authority and selected wave

`PHASE-83-SCREEN-MIGRATION-ROADMAP.md` assigns wave 1 to:

- Sales.
- Purchases.
- Expenses.
- Supplier/customer payments and advances.

The stated objectives are reusable form/dialog primitives, safe action ordering, unsaved-change protection, and accurate Pending/Executed language. The mandatory domain gates are payment routing, Phase 82 approvals, reversals, inventory, and actor identity.

## Route and entry-point inventory

| Surface | Entry point | Mutation boundary | Permission gate | Financial or inventory effect |
|---|---|---|---|---|
| Sales | `DashboardShell` → `SalesScreen` | `SaleController.createSale/cancelSale` | `canCreateSale`, `canCancelInvoice` | stock, customer account, financial account allocations, reversals |
| Purchases | `DashboardShell` → `PurchasesScreen` | `NegativeBalanceApprovalWorkflowService.submitPurchase`; cancellation through `PurchaseController` | `canCreatePurchaseIntake`, `canCancelInvoice` | stock, supplier payable or financial account, durable approval, reversals |
| Expenses | `DashboardShell` → `ExpensesScreen` | `NegativeBalanceApprovalWorkflowService.submitExpense` | `canCreateExpense` | expense record, financial account, durable approval |
| Customer collection | `CustomersScreen` customer-card action | `CustomerController.recordCollection` | `canCreateCustomerPayment` or settings access | receivable, financial account, overpayment advance |
| Customer advances | customer-card action → `CustomerAdvanceActionsScreen` | customer controller apply/refund/reverse methods | customer-payment/settings permission; reversal owner-only | receivable, financial account, advance/refund reversal |
| Supplier payment | `SuppliersScreen`/`SupplierStatementScreen` → `SupplierPaymentDialog` | durable approval workflow or supplier account repository/controller | supplier-payment/manage-supplier contract | payable, financial account, overpayment advance, durable approval |
| Supplier advances | supplier-card action → `SupplierAdvanceActionsScreen` | supplier controller apply/refund/reverse methods | supplier management contract; reversal owner-only | payable, financial account, advance/refund reversal and approval |

These screens use the existing controllers, repositories, repository transactions, payment-routing policy, and Phase 82 approval service. Phase 84 will not introduce alternate transaction services or change their identifiers, payloads, equations, or authorization rules.

## Exact production scope

### Included root/list surfaces

- `SalesScreen`.
- `PurchasesScreen`.
- `ExpensesScreen`.
- `CustomerAdvanceActionsScreen`.
- `SupplierAdvanceActionsScreen`.
- The transaction-specific supplier statement surface used to record supplier payments.

### Included transaction flows embedded in otherwise deferred screens

- Customer collection dialog and its action/result presentation inside `CustomersScreen`.
- Supplier payment dialog and entry points inside the already-migrated supplier list and supplier statement.

Only those transaction-flow sections may be edited in `CustomersScreen` and `SuppliersScreen`; their full list/search/card migration belongs to roadmap wave 2 or the completed Phase 83 reference scope.

### Included dialogs

- Sale creation and sale cancellation.
- Purchase creation and purchase cancellation.
- Expense creation.
- Customer collection.
- Supplier payment.
- Customer advance apply, refund, and refund reversal.
- Supplier advance apply, refund, and refund reversal.
- Existing owner/negative-balance approval prompts reached by those flows, by integration rather than a new approval state machine.

### Intentionally deferred

- Products, Inventory, Stock Take, adjustment history, and complete Customers migration: wave 2.
- Customer and supplier statement redesign beyond transaction entry/safety: wave 2.
- General document-history UI: wave 2/5 depending on list versus print presentation.
- Financial reports, daily report, closing/reconciliation: wave 3.
- Backup/Restore, data wipe, audit log, identity editor, help: wave 4.
- Invoice/statement/report printing and preview redesign: wave 5.
- Customer/supplier master-data forms and opening balances, except where a transaction entry must remain reachable: not part of wave 1.

## Initial UI gap matrix

| Target | Current evidence | Safety/responsive gap | Phase 84 treatment | Domain contract held fixed |
|---|---|---|---|---|
| Sales list/header | manual `Row`, direct colors and ad-hoc loading/empty/error | actions can compress on compact widths; states are inconsistent | shared page header, tokens, standard states, responsive action wrapping | sale loading, permissions, record order |
| Sale form | large raw `AlertDialog`; line/allocation rows; hard-coded colors/spaces | compact overflow risk, no reusable dialog bound, icon-only removal lacks tooltip, no unsaved-close guard | responsive form dialog, sections/summary, compact stacking, semantic removal action, dirty-form confirmation, guarded submit | parsing, minimum-price/stock/domain validation, allocations, actor/idempotency |
| Sale cancellation | raw destructive dialog | no shared destructive semantics; write can be retriggered while outer controller works | explicit consequence copy, destructive styling, local submit lock | cancellation reason and reversal behavior |
| Purchases list/header | manual header and ad-hoc states | compact action compression | shared header/states/tokens | permissions, sorting, document history route |
| Purchase form | raw dialog with quantity/unit row and account impact card | compact fixed-width unit field; no dirty guard; action not locally locked | responsive layout, financial summary, pending wording, dirty guard, submit lock | credit/paid modes, routing, Phase 82 request creation, totals |
| Purchase cancellation | raw destructive dialog | same confirmation and repeat-action risks | shared destructive confirmation behavior | stock/supplier/account reversal rules |
| Expenses list/header | manual header and ad-hoc states | inconsistent state semantics and compact actions | shared header/states/tokens | loaded records and permission contract |
| Expense form | raw dialog; no current-balance impact preview; no local submit lock | compact/keyboard and duplicate-tap risk | responsive form shell, sections, account/method clarity, dirty guard, submit lock | date, amount parsing, account routing, actor, durable approval |
| Customer collection | raw dialog with overpayment split summary | fixed dialog layout, no dirty guard; transaction result copy not centralized | responsive financial dialog and summary, safe close/submit, precise result copy | receivable, deposit account, overpayment approval and advance |
| Supplier payment | raw dialog with overpayment split summary | same layout and close/safety gaps | same shared financial-dialog pattern | payable, withdrawal account, durable negative-balance/overpayment rules |
| Customer advances | ad-hoc scaffold states/cards and three raw dialogs | duplicated state patterns, compact dialog risk, inconsistent destructive affordance | shared header/states/tokens and responsive apply/refund/reversal dialogs | permissions, original-account rule, balances, approval, idempotency |
| Supplier advances | ad-hoc scaffold states/cards and three raw dialogs | same state/dialog risks | same shared transaction patterns | permissions, original-account rule, balances, approval, idempotency |
| Supplier statement payment entry | direct Scaffold/AppBar and ad-hoc body states | inconsistent back/state behavior around payment entry | align transaction entry and states with Phase 83 primitives; preserve navigator route | statement lines and supplier-account equations |

## Final shared UI architecture

Phase 84 added only the reusable presentation primitive needed by multiple targets:

- `GhalalResponsiveDialog`: a constrained, scroll-safe form-dialog shell using Phase 83 spacing, maximum-width, action-overflow, and compact-inset tokens.
- The dialog owns the shared user-back/Escape and explicit-cancel dirty-form contract. It blocks dismissal while busy and requires a separate destructive confirmation before discarding entered values.
- Existing `GhalalPageHeader`, `GhalalLoadingState`, `GhalalEmptyState`, and `GhalalErrorState` are reused. `GhalalErrorState` gained only an optional retry-button key so existing behavior can be asserted without duplicating the component.
- Financial impact summaries remain operation-specific because their accounting meanings differ. They use the shared token and semantic-color system rather than introducing another component or token layer.

All primitives must use `app_tokens.dart`, the established theme, directional padding/alignment, minimum touch targets, tooltips/semantics for icon-only controls, and the existing `ResponsiveLayout`. No repository query may move into `build`.

## Implemented production migration

- Sales, Purchases, and Expenses now use `GhalalPageHeader` plus distinct loading, empty, and initial-error/retry states. A recoverable error with already-loaded records remains visible without replacing valid data.
- Sale, purchase, expense, customer-collection, supplier-payment, and customer/supplier advance dialogs use the shared responsive shell, expanded dropdowns, directional spacing, scroll-safe content, dirty-close protection, and guarded primary actions.
- Sale and purchase cancellation dialogs use explicit reversal consequences, error-semantic destructive actions, dirty-reason protection, and guarded post-confirmation mutation indicators.
- Customer collection and supplier payment entry points prevent concurrent re-entry and expose a disabled progress state while their write is outstanding.
- Expense entry loads account balances before opening the dialog and presents current balance, expense amount, projected balance, and the exact Phase 82 pending-request consequence. No repository query runs from `build`.
- Supplier statement payment entry uses standard loading/error/retry states, the existing supplier-payment permission, and a guarded progress state.
- Icon-only sale-line and allocation removal actions retain the theme's 48-pixel target, and now provide tooltips and semantic error colors.
- No search or filter was added: wave 1 is the form/dialog safety wave, while list search/filter standardization is assigned to roadmap wave 2.

## Production files changed

- `lib/shared/widgets/ghalal_responsive_dialog.dart` (new).
- `lib/shared/widgets/ghalal_state_view.dart`.
- `lib/features/sales/sales_screen.dart`.
- `lib/features/purchases/purchases_screen.dart`.
- `lib/features/expenses/expenses_screen.dart`.
- `lib/features/customers/customers_screen.dart` (collection flow only).
- `lib/features/customers/customer_advance_actions_screen.dart`.
- `lib/features/supplier_accounts/supplier_payment_dialog.dart`.
- `lib/features/supplier_accounts/supplier_statement_screen.dart` (payment entry and states only).
- `lib/features/suppliers/suppliers_screen.dart` (payment-entry guard only).
- `lib/features/suppliers/supplier_advance_actions_screen.dart`.

## Production-logic defect assessment

No accounting, inventory, approval, persistence, routing, authorization-policy, or report-calculation defect was found or changed. The only production behavior hardening is presentation-layer re-entry prevention, busy-state visibility, accurate Pending/Executed wording, retry wiring to existing controller loads, and unsaved-input protection.

## State and wording contract

- Successful direct execution is reported only after the existing service/controller confirms it.
- A Phase 82 insufficient-balance submission is described as a durable pending request and explicitly as not executed.
- Rejected, cancelled, stale, and executed approval states retain their Phase 82 meanings.
- Loading, no business data, recoverable error/retry, and loaded data are distinct. Search-empty applies only to included lists that already expose search; Phase 84 will not invent speculative filters.
- Recoverable validation keeps entered data. Repeated primary actions are disabled while submitting.

## Responsive, RTL, accessibility, and navigation acceptance

The dedicated Phase 84 suite will exercise 360×800, 390×844, 800×1024, a small practical Windows viewport, 1366×768, and 1600×900. It will assert reachable primary actions, no overflow, long Arabic labels, text scaling, RTL direction, logical action order, semantic status text, icon-action tooltips, and keyboard-safe scrolling.

The existing shell remains the only root navigation architecture. Dashboard selection, mobile More drawer, desktop sidebar, route-local back, and `Alt+Left` remain Phase 83 contracts. Dirty transaction dialogs will require an explicit discard decision rather than silently losing entered values.

## Frozen invariants and regression plan

- Schema: 14 before and after.
- Backup: 7 before and after; prior-version restore compatibility unchanged.
- No storage-format, ledger, balance, inventory, report, approval-state, stale-state, routing, ID, actor, authorization, or reversal change.
- Existing sale, purchase, expense, customer-account, supplier-account, financial-account, Phase 82, Phase 83, reporting, backup, DC-U007, and DC-U008 suites remain regression gates.
- Dedicated Phase 84 tests will add meaningful widget assertions for responsive dialogs/screens, disabled repeated submission, dirty-close handling, financial labels and Pending copy, RTL/accessibility, and reuse of standard states. Existing domain tests remain the source of truth for exact financial mutations.

## Tests added or strengthened

- Added `test/phase84_high_risk_transaction_ui_test.dart` with 40 tests: six required viewport classes across all four dialog families (shared transaction dialog, supplier payment, expense form, purchase form), full-page screen empty-state coverage at multiple viewports (sales, expenses, purchases, customer advances, supplier advances), dirty-close preservation, dirty-form discard confirmation, clean-close without confirmation, busy-dialog button-disable contract, double-submit protection, GhalalLoadingState, GhalalErrorState with retry, GhalalEmptyState, 1.3x text scaling, Arabic RTL, light olive/blue and dark wheat/blue themes, dialog bounds, reachable actions, and 48-pixel touch targets.
- Updated the Phase 4 customer-advance UI helper only for the new explicit discard confirmation.
- Updated the Phase 11 empty-sale assertion from the obsolete "after saving" implementation wording to the more accurate "after execution" title/message contract.
- Existing domain tests remain authoritative for exact stock, receivable, payable, account, ledger, approval, actor, idempotency, atomicity, reversal, report, and backup effects.

## WillPopScope decision

The shared dirty-back guard in `GhalalResponsiveDialog` uses `WillPopScope` with a scoped `deprecated_member_use` suppression. On Flutter 3.24.5 this is the correct choice because:

1. `WillPopScope` intercepts `Navigator.maybePop()` (system back/Escape), which is exactly the user-back behavior we need to guard.
2. `PopScope` inverts the contract — it uses `onPopInvokedWithResult` which cannot selectively block a back while allowing a programmatic `Navigator.pop()` on successful submit. Evidence showed this broke the submit-close contract.
3. There are no predictive-back gesture issues on the Windows desktop target.
4. A future Flutter upgrade should migrate to `PopScope` with tests verifying both user back/Escape blocking and programmatic submit-close on success.

## Closure evidence

Phase 84 is **closed** after all mandatory gates passed successfully.

### Pre-build verification (on HEAD `dff5abd`)

- Focused tests: 40/40 passed.
- Full test suite: 1562 passed, 1 skipped (pre-existing intentional skip, not from Phase 84), 0 failed.
- Analyzer: `flutter analyze --no-pub` — `No issues found!`.
- `git diff --check`: passed (CRLF warnings only on `windows/flutter/generated_*` files, no whitespace errors).

### Windows release build

- Build command: `flutter build windows --release`
- Build HEAD: `dff5abdac10fe2d4c822dceaadee8fff3df4f8f6`
- Build start: 2026-07-23 14:15:08
- Build result: success (56.7s)
- EXE path: `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- EXE size: 785,408 bytes
- EXE last-write time: 2026-07-23 14:16:13 (after build start)
- Known warnings during build: CMake deprecation warning for Firebase SDK `cmake_minimum_required < 3.10`, MSVCRT LNK4078 `.voltbl` section warning. Neither constitutes a build failure; the EXE was produced and is functional.

### Post-build verification

- `git rev-parse HEAD`: `dff5abdac10fe2d4c822dceaadee8fff3df4f8f6` — unchanged.
- `git status --short`: empty — tree clean.
- `git diff --check`: passed.
- Source files were not modified by the build.

### Post-document-update verification (before closure commit)

- Analyzer: `flutter analyze --no-pub` — `No issues found!`.
- Full test suite: 1562 passed, 1 skipped, 0 failed.
- `git diff --check`: passed.
- `git status --short`: only the Phase 84 document itself is modified.

### Diff review

- Only the Phase 84 document was modified during closure.
- No production code was changed.
- No secrets or sensitive paths were introduced.
- No formatter sweep was performed.
- The pre-existing formatter debt of 49 unrelated files remains unchanged and out of scope.
- Schema remains 14 and Backup remains 7.

### Governance

- Premature local tag `phase-84-high-risk-transaction-ui-migration-verified` was removed before closure.
- Tag was confirmed local-only (not published to remote).
- Closure commit created after all gates passed.
- Final annotated tag `phase-84-high-risk-transaction-ui-migration-verified` created on the closure commit.
- No push was performed (not a blocker).
- Phase 85 was not started.

## Known residual risks

- The dedicated suite exercises the shared responsive transaction-dialog contract at all six required viewports and exercises the real supplier-payment dialog at all six. Sales, purchases, expenses, collections, and advance flows retain strong existing widget/domain coverage, but each real form has not yet been instantiated independently at every one of the six viewport sizes. This stricter matrix remains a known residual risk but does not block closure.
- The shared dirty-back guard currently uses `WillPopScope` with a scoped deprecation suppression because `PopScope` blocked the existing programmatic success-pop contract in widget evidence. A future Flutter upgrade should migrate this carefully with tests for both user back/Escape and successful submit.
- The repository-wide pre-existing formatter debt (49 files) remains an operational concern unrelated to Phase 84 and was not introduced or expanded by this phase.
