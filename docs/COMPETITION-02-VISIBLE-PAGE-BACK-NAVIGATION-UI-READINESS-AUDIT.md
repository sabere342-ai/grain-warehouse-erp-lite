# COMPETITION-02 — Visible-Page Back Navigation and Competition UI Readiness Audit

## Scope and verified baseline

COMPETITION-02 is a narrow navigation/UI-readiness audit, not a redesign or a
business-feature build. The baseline was
`c380a0dca3d37539edb8befe60729ce6cdb2938d` —
`COMPETITION-01: restore stocktake back navigation` — on
`phase9e-expense-analysis-report`.

Reachable pages were derived from current `AppRoutes`, `DashboardShell`, all
direct `Navigator.push`/`MaterialPageRoute` call sites, dashboard destinations,
and the page widgets those entry points construct. Source and widget-test
evidence are used below; no manual owner acceptance is claimed.

## Authorized Inherited Dirty Baseline

The owner expressly authorized continuation with these unrelated protected
paths already present:

- Modified `lib/features/financial_reports/advances_and_refunds_report_screen.dart`
- Untracked `.build-diagnostics/`

Before COMPETITION-02, the financial-report file was modified by 4 inserted
and 4 removed lines, with SHA-256
`A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`.
Its working-tree Git blob was `22800a9ccb08ee5796f0fa69c87bd9995739adbf`.
The diagnostics inventory was captured by path and timestamp only; its contents
are not reproduced or used as COMPETITION-02 evidence.

Neither protected path was edited, formatted, staged, or committed. The
financial-report screen was audited read-only. It is a non-root report opened
from `FinancialReportsScreen`, and its working copy has a `Scaffold` with an
`AppBar`; Flutter supplies the localized, RTL-aware leading back control when
the route can pop. It is compliant from current source evidence; no protected
path defect was deferred.

The final `git status --short` is intentionally not empty because these two
inherited items remain preserved and excluded.

## Root destinations excluded from a route-pop requirement

The root state flow (`AuthGate`, login, and first-owner setup) and
`DashboardShell` have no previous application page to pop. Dashboard-shell
destinations are application contexts, not pushed detail pages: dashboard,
sales, purchases, products, inventory, suppliers, customers, financial
accounts, financial reports, expenses, audit log, operational reports,
stocktake, stock-adjustment report, and settings. The shell already provides
its established dashboard return affordance for non-dashboard destinations.
Settings business-identity and theme controls are inline sections, not pages.

## Audited non-root full pages

| Entry context | Screen(s) | Return contract | Outcome |
| --- | --- | --- | --- |
| Dashboard | Backup export; Help guide | Shared return / app-bar back | Compliant |
| Backup export | Restore preview; Data wipe | Shared `PageBackButton` before all content states | Compliant |
| Purchases and Sales | Document history | Shared `PageBackButton` | Compliant |
| Supplier | Supplier purchases; supplier statement; supplier advances | `AppBarBackButton` / `maybePop` | Compliant |
| Supplier detail | Printable statement and purchase invoice | Shared printable scaffold Arabic return / `maybePop` | Compliant |
| Customer | Customer statement; customer advances; printable statement | App-bar or printable scaffold return | Compliant |
| Sales / reports | Printable sales invoice; printable daily report | Shared printable scaffold return | Compliant |
| Inventory | Stocktake | COMPETITION-01 shared return, tooltip, `maybePop` | Compliant |
| Inventory | Stock adjustment report | Missing return and route Material host | Remediated |
| Financial accounts | Account statement; internal transfers | Pushed scaffold with localized app-bar leading back | Compliant |
| Financial reports | Balances, closing, statement, payment method, transfers, flows, collections, settlements, advances/refunds, expenses | Pushed scaffold with localized app-bar leading back | Compliant |

Ordinary form/review/confirmation dialogs, date pickers, menus, tabs, and
inline panels were excluded because they are not full-page route headers.

## Confirmed defects and remediation

`InventoryScreen` pushes `StockAdjustmentReportScreen`. The report had no
header-level return control, so empty, populated, loading, and error branches
offered no visible return path. Its subtitle used light-only
`AppColors.mutedText`. The pushed route also had no `Material` ancestor, which
caused the report filter `TextField` to throw on the real Inventory route.

The minimal remediation:

1. Adds the established shared `PageBackButton` in the report's unconditional
   header, with Arabic `رجوع` tooltip and a stable key.
2. Uses active `onSurface` and `onSurfaceVariant` colors for title/subtitle.
3. Supplies a normal `Scaffold` only in the existing Inventory pushed route,
   providing the Material host without changing dashboard-shell composition or
   adding an app bar.

`Navigator.maybePop` pops only the report route, makes no duplicate Inventory
route, and invokes no write. The shared arrow is direction-aware in RTL. No
unsaved-state policy was introduced.

## Files and focused coverage

- `lib/features/inventory/inventory_screen.dart` — route Material host only.
- `lib/features/inventory/stock_adjustment_report_screen.dart` — visible return
  control and semantic header colors.
- `test/phase49b_stock_adjustment_report_test.dart` — actual route, tooltip,
  RTL-aware icon, one-route pop, original Inventory context, no movement, and
  dark-theme header tests.
- This audit record.

Existing Phase 49A stocktake, Phase 49B report/read-only, and Phase 67
navigation tests remain regression evidence. No accounting calculation, stock
quantity, ledger entry, backup behavior, permission, schema, migration, or AI
contract changed.

## Remaining limitations and exclusions

This audit does not provide automatic compliance for future pages, does not
claim manual visual review beyond tested/source-derived evidence, and does not
constitute owner acceptance or competition approval. It does not change
accounting, inventory, financial reports, backup/restore contracts, permissions,
AI, branding, packaging, Cloud, mobile, or multi-device work.

## Verification and closure

- `flutter test test\\phase49a_stock_take_test.dart
  test\\phase49b_stock_adjustment_report_test.dart test\\inventory_test.dart
  test\\product_catalog_test.dart test\\phase67_navigation_theme_branding_test.dart
  --reporter compact` — 82 tests passed.
- `flutter test --reporter compact` — 1,449 tests passed with 1 existing
  expected skip.
- `flutter analyze --no-pub` — no issues.
- `C:\\src\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe analyze` — no issues.
- Global `git diff --check` and the scoped COMPETITION-02 diff check — passed.
- Windows release command:
  `C:\\src\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe C:\\src\\flutter\\packages\\flutter_tools\\bin\\flutter_tools.dart build windows --release`.
  Exit 0; artifact:
  `C:\\dev\\multi-pos\\grain-warehouse-erp-lite\\build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe`
  (785,408 bytes; 2026-07-19 18:40:14 local time). The existing Firebase CMake
  deprecation and MSVCRT `LNK4078` warnings were non-blocking.

The required closure commit is
`COMPETITION-02: complete visible-page back navigation audit`. Only the three
authorized production/test paths and this audit record are eligible for isolated
staging. The owner-authorized protected report file and `.build-diagnostics/`
remain unstaged, uncommitted, and intentionally dirty. No tag or push is
authorized.
