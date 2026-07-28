# Phase 103 — Responsive Mobile UI Readiness Inventory

Date: 2026-07-28
Method: static source audit of every reachable `*Screen`, routes/push navigation, shell, responsive helpers, scrolling, fixed dimensions, dialogs, row density, destructive confirmations, RTL and platform/file behavior. No Android/iOS runtime claim is made.

## 1. Inventory boundary and counts

- Audited screen classes: **42** — 41 public classes plus reachable private `_CustomerStatementScreen`.
- Supporting contexts assessed separately: `AuthGate`, `DashboardShell`, and five printable preview views.
- Screen classification: **6 `MobileReady`**, **18 `ResponsiveAdjustmentRequired`**, **15 `MobileRedesignRequired`**, **0 `DesktopOnly`**, **3 `BlockedByArchitecture`**.
- No screen is removed or hidden. `DesktopOnly=0` is deliberate: print layouts may remain fixed-paper previews, but their business functions require mobile alternatives rather than disappearing.

`MobileReady` means source structure is plausibly usable at 360 logical pixels, not that a device test passed.

## 2. Cross-screen evidence

- RTL is forced globally in `GrainWarehouseApp`; Arabic localization and Light/Dark themes exist. Small-width text wrapping still requires device/golden verification.
- No reachable screen depends on hover or right-click. Alt+Left exists only in `DashboardShell`; it is an enhancement, not the only back action.
- Material controls generally provide touch semantics, but dense row action clusters and icon buttons require a 44–48 logical-pixel target audit in Phase 110.
- `DashboardShell` already switches desktop sidebar to drawer/bottom navigation using `ResponsiveLayout` and provides a visible back-to-dashboard action.
- Most screens use `ListView`/`SingleChildScrollView`; none uses `DataTable`. Many financial screens build multiple rigid `Row` groups, which can still overflow despite vertical scrolling.
- `GhalalResponsiveDialog` improves compact width, but several screens still use raw `AlertDialog` or fixed widths (notably the 640-wide profitability activation dialog).
- Long EGP/qirsh values occur across sales, purchases, accounts, ledgers, valuation and reports; they need flexible numeric columns, ellipsis/tooltips where safe, and full-value drill-down.
- Destructive actions in restore/wipe/cancel/reverse/close workflows generally request confirmation, but mobile placement, reauthentication and server authority remain future gates.

## 3. Per-screen inventory

Legend for “risks”: `R` = dense rigid rows; `A` = many actions; `D` = dialog/form; `F` = local file/platform behavior; `M` = long money; `X` = destructive/approval; `B` = architecture authority/scope blocker. “Scroll” records the current vertical/list mechanism; it does not guarantee overflow safety. Minimum width is a conservative source-based estimate of current comfort, not a tested device measurement.

| # | Screen and path | Access/route | Function | Current comfortable min | Density / form evidence | Scroll, touch, RTL, money, back/destructive | Classification / priority |
| ---: | --- | --- | --- | ---: | --- | --- | --- |
| 1 | `LoginScreen` — `features/auth/login_screen.dart` | `/login`, `AuthGate` | Local sign-in | 360 | Simple constrained form | Scroll yes; touch/RTL structurally good; no money; auth back N/A | `MobileReady` / P2 |
| 2 | `FirstOwnerSetupScreen` — `features/auth/first_owner_setup_screen.dart` | `/first-owner-setup`, `AuthGate` | Create first local owner | 360 | Simple constrained form | Scroll yes; touch/RTL good; no money; back N/A | `MobileReady` / P2 |
| 3 | `DashboardScreen` — `features/dashboard/dashboard_screen.dart` | Shell index 0 | KPIs, alerts, help | 360 | Responsive grid/Wrap | Scroll yes; touch/RTL good; long values wrap; shell back N/A | `MobileReady` / P2 |
| 4 | `AuditLogsScreen` — `features/audit/audit_logs_screen.dart` | Shell audit destination | Audit list | 360 | List cards, no fixed-width table | Scroll yes; touch/RTL good; actor/time text; shell back visible | `MobileReady` / P2 |
| 5 | `FinancialReportsScreen` — `features/financial_reports/financial_reports_screen.dart` | Shell financial reports | Report menu | 360 | Vertical cards | Scroll yes; touch/RTL good; no values on menu; shell/push back | `MobileReady` / P2 |
| 6 | `HelpGuideScreen` — `features/help/help_guide_screen.dart` | Push from dashboard | Help content | 360 | Simple list/content | Scroll yes; touch/RTL good; app-bar back | `MobileReady` / P3 |
| 7 | `ProductsScreen` — `features/products/products_screen.dart` | Shell products | Product CRUD/pricing | 520 | `A,D,M`; responsive dialog/Wrap | Scroll yes; touch spacing needs check; RTL; long price; shell back; destructive state change | `ResponsiveAdjustmentRequired` / P1 |
| 8 | `CustomersScreen` — `features/customers/customers_screen.dart` | Shell customers | Customer CRUD, collections, statements | 520 | `A,D,M`; responsive helpers | Multiple scrolls; touch/RTL mostly; push back; confirmations in monetary actions | `ResponsiveAdjustmentRequired` / P1 |
| 9 | `CustomerAdvanceActionsScreen` — `features/customers/customer_advance_actions_screen.dart` | Push from customer | Advance apply/refund/reversal | 520 | `A,D,M,X`; max-width dialogs | Scroll yes; action spacing/keyboard numeric input needs test; explicit back/confirm | `ResponsiveAdjustmentRequired` / P1 |
| 10 | `SuppliersScreen` — `features/suppliers/suppliers_screen.dart` | Shell suppliers | Supplier CRUD and drill-downs | 620 | `R,A,D,M`; raw form dialog remains | Scroll yes; touch/RTL need narrow verification; push/shell back; state actions | `ResponsiveAdjustmentRequired` / P1 |
| 11 | `SupplierAdvanceActionsScreen` — `features/suppliers/supplier_advance_actions_screen.dart` | Push from supplier | Advances/refunds/reversals | 520 | `A,D,M,X`; responsive dialogs | Scroll yes; touch/RTL mostly; explicit back/confirm | `ResponsiveAdjustmentRequired` / P1 |
| 12 | `ExpensesScreen` — `features/expenses/expenses_screen.dart` | Shell expenses | Expense posting/reclassification | 520 | `D,M,X`; responsive dialog | Scroll yes; touch/RTL mostly; shell back; reclassification confirmation | `ResponsiveAdjustmentRequired` / P1 |
| 13 | `SalesScreen` — `features/sales/sales_screen.dart` | Shell sales | Multi-item sale/payment/cancel/print | 620 | `R,A,D,M,X`; responsive branches but long form | Scroll yes; numeric keyboard/touch action density require test; RTL; cancel confirm; push previews | `ResponsiveAdjustmentRequired` / P0 |
| 14 | `PurchasesScreen` — `features/purchases/purchases_screen.dart` | Shell purchases | Purchase/payment/cancel/history | 620 | `R,A,D,M,X`; tablet branch and 120-wide unit field | Scroll yes; touch/numeric form test; RTL; cancellation confirm; push back | `ResponsiveAdjustmentRequired` / P0 |
| 15 | `InventoryScreen` — `features/inventory/inventory_screen.dart` | Shell inventory | Balances/movements/opening/stocktake | 620 | `R,A,D,M,X`; several responsive dialogs and fixed 120 fields | Scroll yes; touch/RTL mostly; shell/push back; movement confirms | `ResponsiveAdjustmentRequired` / P0 |
| 16 | `StockTakeScreen` — `features/inventory/stock_take_screen.dart` | Shell and push from inventory | Physical count and adjustments | 620 | `R,A,M,X`; LayoutBuilder 1/2 columns, 120 field | Scroll yes; touch numeric entry requires test; RTL; confirmation dialog | `ResponsiveAdjustmentRequired` / P0 |
| 17 | `StockAdjustmentReportScreen` — `features/inventory/stock_adjustment_report_screen.dart` | Shell and push | Adjustment/variance report | 620 | `R,M`; fixed 280/340 controls inside Wrap | Scroll yes; touch/RTL; long values; back available | `ResponsiveAdjustmentRequired` / P1 |
| 18 | `FinancialAccountsScreen` — `features/financial_accounts/financial_accounts_screen.dart` | Shell accounts | Account list/create/statement/transfers | 520 | `R,A,D,M`; LayoutBuilder below 520 | Scroll yes; touch/RTL mostly; shell/push back; account state changes | `ResponsiveAdjustmentRequired` / P0 |
| 19 | `NegativeBalanceApprovalRequestsScreen` — `features/financial_accounts/negative_balance_approval_requests_screen.dart` | Shell approvals | Approval lifecycle | 620 | `A,D,M,X`; compact branch below 620, raw dialogs | Scroll yes; touch/RTL; long amounts; confirmation/reauth; shell back | `ResponsiveAdjustmentRequired` / P0 |
| 20 | `ReportsScreen` — `features/reports/reports_screen.dart` | Shell reports | Operational daily/stock/profit summary and print | 620 | `R,M`; responsive summary Wrap | Scroll yes; touch/RTL; long values; print push; shell back | `ResponsiveAdjustmentRequired` / P1 |
| 21 | `DocumentHistoryScreen` — `features/documents/document_history_screen.dart` | Push from sales/purchases | Search/cancelled document history | 720 | `R,A,M`; fixed 170–220 filter widths in Wrap | Scroll yes; touch/RTL; long totals; app-bar back | `ResponsiveAdjustmentRequired` / P1 |
| 22 | `SupplierPurchasesScreen` — `features/purchases/supplier_purchases_screen.dart` | Push from supplier | Supplier purchase list/preview | 620 | `R,A,M` | Two scroll/list contexts; touch/RTL need check; print preview back | `ResponsiveAdjustmentRequired` / P1 |
| 23 | `SettingsScreen` — `features/settings/settings_screen.dart` | Shell settings | Theme/business profile/logo/backup entry | 520 | `A,D,F`; file picker and many cards | Scroll yes; touch/RTL mostly; shell back; file capability needs mobile adapter | `ResponsiveAdjustmentRequired` / P1 |
| 24 | `SupplierStatementScreen` — `features/supplier_accounts/supplier_statement_screen.dart` | Push from supplier | Supplier ledger/payment/print | 620 | `R,A,D,M,X` | Scroll yes; touch/RTL; long ledger values; payment confirm; app-bar back | `ResponsiveAdjustmentRequired` / P0 |
| 25 | `TransferReportScreen` — `features/financial_reports/transfer_report_screen.dart` | Push from report menu | Financial transfer report/export | 720 | `R,M,F`; seven rigid rows and `dart:io` export | Vertical scroll only; narrow overflow likely; RTL/money/back; no destructive action | `MobileRedesignRequired` / P1 |
| 26 | `SupplierSettlementsReportScreen` — `features/financial_reports/supplier_settlements_report_screen.dart` | Push from report menu | Supplier settlements by account/export | 720 | `R,M,F`; eight rigid rows | Vertical scroll; card/detail redesign needed; RTL/money/back | `MobileRedesignRequired` / P1 |
| 27 | `PaymentMethodReportScreen` — `features/financial_reports/payment_method_report_screen.dart` | Push from report menu | Payment-method analysis/export | 720 | `R,M,F`; eight rigid rows | Vertical scroll; narrow overflow risk; RTL/money/back | `MobileRedesignRequired` / P1 |
| 28 | `AccountBalanceReportScreen` — `features/financial_reports/account_balance_report_screen.dart` | Push from report menu | Account balances/export | 720 | `R,M,F`; six rigid rows | Vertical scroll; mobile cards/drill-down needed; RTL/money/back | `MobileRedesignRequired` / P1 |
| 29 | `AccountStatementReportScreen` — `features/financial_reports/account_statement_report_screen.dart` | Push from report menu | Detailed account statement/export | 720 | `R,M,F`; seven rigid rows | Vertical scroll; ledger column redesign; RTL/money/back | `MobileRedesignRequired` / P0 |
| 30 | `CustomerCollectionsReportScreen` — `features/financial_reports/customer_collections_report_screen.dart` | Push from report menu | Collections by account/export | 720 | `R,M,F`; eight rigid rows | Vertical scroll; card/filter redesign; RTL/money/back | `MobileRedesignRequired` / P1 |
| 31 | `ExpenseAnalysisReportScreen` — `features/financial_reports/expense_analysis_report_screen.dart` | Push from report menu | Expense categories/details/export | 720 | `R,M,F`; seven rigid rows | Vertical scroll; chart/detail redesign; RTL/money/back | `MobileRedesignRequired` / P1 |
| 32 | `InflowsReportScreen` — `features/financial_reports/inflows_report_screen.dart` | Push from report menu | Inflow ledger/export | 720 | `R,M,F`; five rigid rows | Vertical scroll; ledger card redesign; RTL/money/back | `MobileRedesignRequired` / P1 |
| 33 | `OutflowsReportScreen` — `features/financial_reports/outflows_report_screen.dart` | Push from report menu | Outflow ledger/export | 720 | `R,M,F`; five rigid rows | Vertical scroll; ledger card redesign; RTL/money/back | `MobileRedesignRequired` / P1 |
| 34 | `AdvancesAndRefundsReportScreen` — `features/financial_reports/advances_and_refunds_report_screen.dart` | Push from report menu | Advance/refund/reversal analysis | 720 | `R,A,M,F`; ten rows, only limited narrow helper | Vertical scroll; high density; RTL/money/back | `MobileRedesignRequired` / P1 |
| 35 | `FinancialAccountStatementScreen` — `features/financial_accounts/financial_account_statement_screen.dart` | Push from account | Detailed local account ledger | 720 | `R,M`; multiple rigid rows | Vertical scroll; mobile ledger cards needed; RTL/money/back | `MobileRedesignRequired` / P0 |
| 36 | `FinancialTransfersScreen` — `features/financial_accounts/financial_transfers_screen.dart` | Push from accounts | Create/reverse transfers | 620 | `D,M,X`; raw dialogs and dense financial form | Scroll yes; mobile wizard/summary/reauth needed; RTL/back/confirm | `MobileRedesignRequired` / P0 |
| 37 | `FinancialClosingScreen` — `features/financial_reports/financial_closing_screen.dart` | Push from report menu | Close/reopen/reconcile period | 620 | `D,M,X`; raw dialogs, high-risk workflow | Scroll yes; mobile stepper + reauth and clear irreversible summary required | `MobileRedesignRequired` / P0 |
| 38 | `ProfitabilityReportScreen` — `features/financial_reports/profitability_report_screen.dart` | Push from report menu | Profitability/activation | 720 | `R,D,M,X`; activation dialog width 640 | Scroll yes; activation workflow must be redesigned and remains not activated; RTL/back | `MobileRedesignRequired` / P0 |
| 39 | `_CustomerStatementScreen` — within `features/customers/customers_screen.dart` | Push from customer | Customer ledger/print | 620 | `R,A,M` | Vertical scroll; ledger mobile cards/action separation; RTL/back | `MobileRedesignRequired` / P0 |
| 40 | `BackupExportScreen` — `features/backup/backup_export_screen.dart` | Push from settings | Whole local dataset export | 520 | `F,B,X`; local file result/paths | UI scroll/touch/RTL acceptable, but mobile meaning must split device recovery vs org export | `BlockedByArchitecture` / P0 |
| 41 | `BackupRestorePreviewScreen` — `features/backup/backup_restore_preview_screen.dart` | Push from backup export | Select/preview/restore v1–v8 | 520 | `F,B,X`; local file and whole-dataset restore | Scroll/confirmation exist; server/org/idempotency scope absent; must not be exposed as cloud restore | `BlockedByArchitecture` / P0 |
| 42 | `DataWipeScreen` — `features/backup/data_wipe_screen.dart` | Push from backup export | Backup then wipe business data | 520 | `F,B,X`; one local database/global business assumption | Scroll/confirm exist; cloud/mobile semantics require cache wipe vs server deletion separation | `BlockedByArchitecture` / P0 |

## 4. Supporting contexts

| Context | Finding | Future treatment |
| --- | --- | --- |
| `AuthGate` | Responsive by composition; local-only session model | Keep UI; replace identity/session source in Phase 106 |
| `DashboardShell` | Existing desktop sidebar + mobile drawer/bottom bar, visible back and optional Alt+Left | Preserve; add sync/device status and navigation restoration |
| Five printable views | Fixed-paper business document layouts inside scrollable `PrintableDocumentScaffold` | Keep as paper/desktop preview; mobile provides fit-to-width preview, PDF/share/print capability |

## 5. Phase 110 remediation order

1. P0 transactional and authority-sensitive screens: sales, purchases, inventory/stocktake, financial accounts/statement/transfers/closing, approvals, supplier/customer ledgers, profitability activation, backup/restore/wipe semantics.
2. P1 reference/entity screens and dense reports: products, parties, expenses, history, operational reports and all financial report layouts.
3. P2 authentication/dashboard/audit/report menu device verification.
4. P3 help and non-critical polish.

Acceptance requires 320/360/390/600/840 logical-pixel golden/widget coverage, large text, RTL, Light/Dark, touch targets, Android back gesture, keyboard/mouse parity on Windows, long Arabic strings, long EGP values, destructive confirmation, and no hidden page.

## 6. Mobile UX contracts

- Dense tables become summary cards with expandable detail, filters in sheets, and optional horizontal comparison only where meaning demands it.
- Transaction forms become progressive sections with a sticky but non-obscuring total/status action area.
- Dialogs become compact dialogs, bottom sheets, or full-screen routes based on complexity; high-risk workflows use full-screen review and reauthentication.
- Every pushed page exposes platform back; shell destinations return to dashboard without depending on keyboard.
- Platform file/print/share actions expose capability-aware alternatives and truthful unavailable states.
- Pending offline status is visible on affected records and totals; provisional values never look server-final.
- No page is deleted, permission-hidden to fake readiness, or replaced by a “completed” placeholder.
