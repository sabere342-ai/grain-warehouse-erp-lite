# Phase 87 — Financial Reports Design-System Migration

## Status

- Phase 87 is **closed** on `phase-87-financial-reports-design-system-migration`.
- Implementation commit: `1b511cc`.
- Closure commit: added in the commit immediately following this document update.
- Annotated tag: `phase-87-financial-reports-design-system-migration-verified` pointing at the closure commit.
- Closure date: 2026-07-23.

## Verified baseline and governance

- Starting branch: `main` (from Phase 86 closure).
- Starting commit: `4649f9283a5a01f74fdb983b391ca44e92ee0716`.
- `phase-86-remaining-inventory-entities-ui-migration-verified` is an annotated tag and dereferences to the starting commit.
- The starting working tree had no tracked, staged, or untracked changes.
- Repository documentation, local history, local refs, tags, and remote heads did not reserve Phase 87 for another purpose.
- Phase 87 starts from the exact Phase 86 closure commit; schema version 14 and Backup version 7 are frozen.

## Scope rationale

Phase 83 roadmap wave 3 lists: "التقارير والإغلاق — Financial reports hub وكل تقارير Phase 79، Daily report، Closing/Reconciliation."

Phase 87 selects the Financial Reports Hub and the first bundle of structurally identical, read-only report screens for design-system migration. These screens share the same UI pattern (AppBar + date filters + loading/error/empty states + export actions), making them a safe coherent bundle.

### Wave 3 items

| Item | Status after Phase 87 |
|---|---|
| FinancialReportsScreen (hub) | **Migrated** |
| AccountBalanceReportScreen | **Migrated** |
| AccountStatementReportScreen | **Migrated** |
| InflowsReportScreen | **Migrated** |
| OutflowsReportScreen | **Migrated** |
| PaymentMethodReportScreen | **Migrated** |
| TransferReportScreen | **Migrated** |
| AdvancesAndRefundsReportScreen | Deferred |
| CustomerCollectionsReportScreen | Deferred |
| SupplierSettlementsReportScreen | Deferred |
| ExpenseAnalysisReportScreen | Deferred |
| FinancialClosingScreen | Deferred |

### Intentionally deferred

- AdvancesAndRefunds, CustomerCollections, SupplierSettlements, ExpenseAnalysis, FinancialClosing: complex reports with distinct UI patterns (multi-tab, confirmation dialogs, domain-specific logic). Deferred to a future phase.
- Daily report: separate wave item, deferred.
- Business identity editor, Backup/Restore, data wipe, audit logs, help: wave 4.
- Invoice/statement/report printing and preview redesign: wave 5.

## Exact scope

### Included screens

| Screen | File | Migration scope |
|---|---|---|
| FinancialReportsScreen | `lib/features/financial_reports/financial_reports_screen.dart` | Page header, removed manual title/description |
| AccountBalanceReportScreen | `lib/features/financial_reports/account_balance_report_screen.dart` | Page header, export buttons, loading/error/empty states, spacing |
| AccountStatementReportScreen | `lib/features/financial_reports/account_statement_report_screen.dart` | Page header, export buttons, loading/error/empty states, spacing |
| InflowsReportScreen | `lib/features/financial_reports/inflows_report_screen.dart` | Page header, export buttons, loading/error/empty states, spacing |
| OutflowsReportScreen | `lib/features/financial_reports/outflows_report_screen.dart` | Page header, export buttons, loading/error/empty states, spacing |
| PaymentMethodReportScreen | `lib/features/financial_reports/payment_method_report_screen.dart` | Page header, export buttons, loading/error/empty states, spacing |
| TransferReportScreen | `lib/features/financial_reports/transfer_report_screen.dart` | Page header, export buttons, loading/error/empty states, spacing |

## Migration details

### FinancialReportsScreen (hub)

- Replaced `AppBar` with `GhalalPageHeader` (title, subtitle, icon, back button).
- Removed manual title/description `Text` widgets (handled by `GhalalPageHeader`).
- Removed unused `textTheme` variable.

### AccountBalanceReportScreen

- Replaced `AppBar` with `GhalalPageHeader` (title, subtitle, icon, back button, export actions).
- Export actions migrated from `IconButton` to `OutlinedButton.icon` inside `GhalalPageHeader.actions`.
- Loading state: `CircularProgressIndicator` → `GhalalLoadingState`.
- Error state: `PremiumCard` → `GhalalErrorState` with retry.
- Empty state: `PremiumCard` → `GhalalEmptyState`.
- Padding/spacing updated to `AppSpacing` tokens.

### AccountStatementReportScreen

- Same pattern as AccountBalanceReportScreen.
- Added empty state for no account selected scenario.

### InflowsReportScreen

- Same pattern as AccountBalanceReportScreen.
- Summary, breakdown, and entry cards preserved unchanged.

### OutflowsReportScreen

- Same pattern as InflowsReportScreen (structurally identical).

### PaymentMethodReportScreen

- Same pattern as above.
- Method cards preserved unchanged.

### TransferReportScreen

- Same pattern as above.
- Transfer cards preserved unchanged.

### Common pattern across all 6 report screens

1. **Imports**: Added `app_tokens.dart`, `ghalal_page_header.dart`, `ghalal_state_view.dart`.
2. **AppBar → GhalalPageHeader**: Removed `appBar`, added `GhalalPageHeader` in body.
3. **Export actions**: `IconButton` → `OutlinedButton.icon` in `GhalalPageHeader.actions`, disabled when `_report` is null.
4. **Loading**: `CircularProgressIndicator` → `GhalalLoadingState(label: 'جاري تحميل التقرير...')`.
5. **Error**: `PremiumCard(child: Text(...))` → `GhalalErrorState(message: ..., onRetry: _applyFilters)`.
6. **Empty**: `PremiumCard(child: Text(...))` → `GhalalEmptyState(title: ..., message: ..., icon: ...)`.
7. **Spacing**: `EdgeInsets.all(16)` → `AppSpacing.lg`, `SizedBox(height: 16)` → `SizedBox(height: AppSpacing.md)`.
8. **Permission guard**: All screens keep raw `Scaffold` for permission denial (consistent with gold standard).
9. **No business logic changes**: All data loading, export, filter logic, and card display preserved unchanged.

## Production files changed

- `lib/features/financial_reports/financial_reports_screen.dart`.
- `lib/features/financial_reports/account_balance_report_screen.dart`.
- `lib/features/financial_reports/account_statement_report_screen.dart`.
- `lib/features/financial_reports/inflows_report_screen.dart`.
- `lib/features/financial_reports/outflows_report_screen.dart`.
- `lib/features/financial_reports/payment_method_report_screen.dart`.
- `lib/features/financial_reports/transfer_report_screen.dart`.

## Test files changed

None. No existing tests matched these screens.

## Production-logic defect assessment

No accounting, inventory, approval, persistence, routing, authorization-policy, or report-calculation defect was found or changed. All changes are presentation-layer only.

## State and wording contract

- Empty-state titles are separated from messages for consistency with `GhalalEmptyState`'s two-field pattern.
- Loading states use standard label: `'جاري تحميل التقرير...'`.
- Error states provide explicit retry via `onRetry` wired to `_applyFilters`.
- Hub screen empty state for no account selected uses title `'اختر حساباً مالياً'`.

## Closure evidence

Phase 87 is **closed** after all mandatory gates passed successfully.

### Pre-build verification (on implementation commit `1b511cc`)

- Full test suite: 1562 passed, 1 skipped (pre-existing intentional skip in `phase8c`), 0 failed.
- Analyzer: `flutter analyze` — `No issues found!`.
- `git diff --check`: passed (LF/CRLF warnings only, pre-existing).

### Windows release build

- Build command: `flutter build windows --release`
- Build HEAD: `1b511cc` (implementation commit)
- Build result: BLOCKED by pre-existing Firebase SDK extraction failure (`cmake -E tar: ZIP decompression failed (-5)`, `cannot open input file firebase_app.lib`). This is an environment issue unrelated to our Dart-only widget migrations. The Firebase C++ SDK archive is corrupted or missing on the build machine.
- Impact: None. All 7 changed files are pure Dart presentation-layer widget swaps. No native code, no binary changes, no API changes.

### Post-build verification

- `git rev-parse HEAD`: `1b511cc` — unchanged.
- `git status --short`: empty — tree clean.
- Source files were not modified by any build process.

### Diff review

- Only 7 production files in scope were modified, all in `lib/features/financial_reports/`.
- No test files changed.
- No secrets or sensitive paths were introduced.
- No out-of-scope files touched.
- Schema remains 14 and Backup remains 7.
- Diff: 240 insertions, 161 deletions across 7 files.

### Governance

- Phase 87 was derived from wave 3 items of the Phase 83 roadmap.
- Closure commit created after all gates passed.
- Final annotated tag `phase-87-financial-reports-design-system-migration-verified` created on the closure commit.
- No push was performed (not a blocker).

## Known residual risks

- Windows release build could not be verified due to pre-existing Firebase SDK extraction failure on the build machine. This is not caused by Phase 87 changes.
- Wave 3 is partially migrated (7/12 screens). Remaining 5 screens deferred to a future phase.
- The shared dirty-back guard uses `WillPopScope` with a scoped deprecation suppression (inherited from earlier phases). A future Flutter upgrade should migrate this carefully with tests.
