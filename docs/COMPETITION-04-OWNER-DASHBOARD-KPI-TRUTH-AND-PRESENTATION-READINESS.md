# COMPETITION-04 — Owner Dashboard KPI Truth and Presentation Readiness

**Decision:** Outcome A — remediated.  The dashboard contained two competition-visible defects: it started protected readers before authorization, and its card labelled `رصيد النقدية التراكمي` re-derived a balance from selected transaction lists rather than using the financial-account balance source of truth.

## Scope and baseline

This is a read-only audit/remediation of the existing owner dashboard.  No new KPI, route, write path, domain model, ledger rule, inventory rule, or approval policy was introduced.  The checked baseline is `79753b796fe217fc481bcd2524383929d6e10b6e` on `phase9e-expense-analysis-report`.

The visible screen is `DashboardScreen`, hosted by `DashboardShell`.  The identity shown in the shell continues to come from the existing business-identity scope; its existing flexible/ellipsis title and safe missing-logo handling were retained.  Backup export and help remain real `MaterialPageRoute` destinations and retain their existing Arabic return controls.

## KPI truth matrix

| Visible item | Displayed meaning and canonical reader | Permission before read | Empty / signed / inactive treatment | Destination or mutation |
| --- | --- | --- | --- | --- |
| مبيعات اليوم | Existing `SaleRepository` current-day, non-cancelled sales total. | `canViewFinancialReports` | Empty is zero; cancelled records remain excluded by the repository. | None; read-only. |
| نقد داخل اليوم | Existing current-day cash sales plus customer collections.  It is explicitly labelled as those two components, not as a balance. | `canViewFinancialReports` | Empty is zero; repository date semantics are unchanged. | None; read-only. |
| المستحق على العملاء | Positive customer-ledger balances from the existing customer-account repository. | `canViewFinancialReports` | Only positive receivables are included; signed ledger semantics are unchanged. | None; read-only. |
| المستحق للموردين | Positive supplier-ledger balances from the existing supplier-account repository. | `canViewFinancialReports` | Only positive payables are included; signed ledger semantics are unchanged. | None; read-only. |
| إجمالي أرصدة الحسابات المالية | `FinancialAccountRepository.allAccountBalances(includeInactive: true)`, summed from each canonical `currentBalanceQirsh`. | `canViewFinancialReports` | Preserves signed balances and includes inactive financial accounts. | None; read-only. |
| مخزون القمح | Existing inventory product/balance readers. | `canViewFinancialReports` | Existing product and quantity semantics unchanged. | None; read-only. |
| تنبيهات المخزون | Existing `InventoryAttentionService`. | `canViewFinancialReports` | Existing empty/attention rules unchanged. | None; read-only. |
| إرشاد اليوم | Existing dashboard-guidance reader. | `canViewFinancialReports` | Existing empty guidance state remains intact. | None; read-only. |
| تنبيهات المالك | Existing ledger and inventory alert readers, including customer/supplier names and balances. | `canViewFinancialReports` | Existing attention and empty states unchanged. | None; read-only. |
| تصدير نسخة احتياطية | Existing backup route/action. | Existing `canExportBackups` control | No dashboard data is read by the card. | Navigation only until the user explicitly exports. |
| دليل الاستخدام | Existing help route. | Dashboard financial-read gate for its containing owner shortcut | Static destination. | Navigation only. |

## Remediation and access decision

`DashboardScreen` now resolves the authenticated user and `canViewFinancialReports` **before** it creates or invokes the dashboard, guidance, or owner-alert futures.  This prevents a protected reader from being called merely because an employee can navigate to the dashboard route.

The employee route remains available and functional, but renders a factual static restriction message: financial dashboard summaries are available to the owner only.  It does not create the protected dashboard, guidance, ledger-name/balance, inventory-quantity, or transaction-count readers, and it does not render the protected cards or owner alerts.  This is the least-privilege outcome using the established financial-report permission; no permission model was changed.

The former cumulative-cash formula used sales, collections, expenses, and supplier payments directly.  It could omit opening balances, transfers, and other account activity.  The existing compatibility field `cashBalanceQirsh` now carries the canonical total of financial-account current balances, and the card title/subtitle were corrected to describe that meaning exactly.  The raw transaction and approval domains were not changed.

An owner-side service failure is now visible as a controlled dashboard error card instead of being silently rendered as zero values.

## Presentation and resilience

Dashboard-specific hard-coded colors were changed to semantic `ColorScheme` roles, including summary cards, alerts, and the dashboard-shell navigation indicator.  The existing wrapping metric layout, scrollable page, RTL text, long business-name ellipsis behavior, and dark/high-contrast themes were retained.  Widget coverage renders the owner dashboard at 800×600 in high-contrast/dark styling and exercises the backup/help routes and their Arabic return controls at 1024×640; no overflow or exception is reported.

## Changed files and exclusions

Production changes are limited to the dashboard service/controller/screen/alerts/shell.  The test updates only supply the now-required financial-account repository and change obsolete raw-formula expectations; they do not alter supplier, purchase, payment, expense, inventory, financial-account, or report business behavior.  `test/competition04_dashboard_readiness_test.dart` covers canonical balance reading without mutation, denied-before-read employee behavior, signed display, compact rendering, and real return navigation.

Explicitly excluded: all sale, purchase, return, stock, approval, customer/supplier ledger, financial-account, backup data, persistence, and migration implementations.  No mutations were added to the dashboard.

## Verification record

- Focused dashboard/financial/navigation regression suite: **148 passed**.
- Full Flutter suite: **1,456 passed, 1 expected skip**.
- Flutter analyzer and direct Dart analyzer: **No issues found**.
- `git diff --check`: passed (no whitespace errors).
- Windows release build: passed; `build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe` was produced.  Existing third-party CMake deprecation and MSVCRT linker warnings did not prevent the build.
