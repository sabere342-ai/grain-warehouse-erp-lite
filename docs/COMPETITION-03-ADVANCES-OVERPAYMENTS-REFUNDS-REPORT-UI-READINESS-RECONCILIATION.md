# COMPETITION-03 — Advances, Overpayments and Refunds Report UI Readiness Reconciliation

## Decision and baseline

The owner authorized reconciliation of the inherited change in
`lib/features/financial_reports/advances_and_refunds_report_screen.dart`.
The baseline was commit `724ce65b35cf3838429a3c200cffa5c49984c407`
(`COMPETITION-02: complete visible-page back navigation audit`) on branch
`phase9e-expense-analysis-report`.

Initial worktree state was:

```text
 M lib/features/financial_reports/advances_and_refunds_report_screen.dart
?? .build-diagnostics/
```

The initial report-screen SHA-256 was
`A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`.
Its working-tree blob was `22800a9ccb08ee5796f0fa69c87bd9995739adbf`.
The inherited diff was exactly four added and four removed lines: it changed
the party-type dropdown `items` list and its three `DropdownMenuItem`s from
individually `const` values in a mutable list to one `const` list. It is a
presentation/allocation-only change: it does not change navigation, filters,
financial data, totals, money signs, or permissions.

`.build-diagnostics/` was read-only inventoried as 36 untracked paths before
work and is excluded from every edit, stage, commit, and cleanup action.

## Selected outcome

**Outcome B — valid but incomplete.** The inherited `const` list change is
valid and is preserved. It did not make the report ready by itself: the screen
started protected reads before enforcing its visible permission denial, used
incorrect identifiers to resolve refund parties, and overflowed its paired
date controls in a narrow RTL layout. Its broad Arabic title also implied an
advances report although its canonical result is specifically advance-refund
cash movements and their reversals.

## Navigation and canonical report boundary

`FinancialReportsScreen` pushes `AdvancesAndRefundsReportScreen` with a
`MaterialPageRoute`. The destination remains a pushed `Scaffold` with an app
bar and the standard visible return control. Export actions remain available
only to users with `canExportFinancialReports`.

After `canViewFinancialReports` is established through `AuthScope`, the screen
creates `FinancialReportService` with the durable financial account repository
and customer/supplier lookup adapters. It calls
`FinancialReportService.getAdvancesAndRefundsReport`, passing the selected
period, account, party, and entity filters. The service, not the widget,
filters, sorts, aggregates, and supplies all qirsh totals.

`AdvancesAndRefundsReport` supplies canonical read-only detail and summary data:
details contain the entry ID, account, party, optional entity ID, source type,
reversal relation, qirsh amount, and signed cash effect; the report supplies
per-account/per-party summaries and grand totals. Details are canonically
ordered by account, party, entity, descending timestamp, and entry ID.

The service admits only these source types:

- `customerAdvanceRefund` and a correctly linked
  `customerAdvanceRefundReversal`;
- `supplierAdvanceRefund` and a correctly linked
  `supplierAdvanceRefundReversal`.

It explicitly excludes opening balances, manual corrections, restore imports,
ordinary sale/purchase payments, customer collections, supplier settlements,
expenses, generic cancellation reversals, and transfers. Customer refund cash
effect is negative (outflow); supplier refund cash effect is positive (inflow).
Gross, reversal, net, and signed grand-effect totals remain computed by the
domain service in qirsh and rendered with `MoneyUtils` without widget-side
recalculation.

## Current truthful product boundary

The screen reports recorded customer advance refunds, recorded supplier advance
refunds, and their qualified reversals within an inclusive selected period. It
has account, party, and party-specific entity filters. It reports no rows when
the selected period contains no qualified entries and now says so explicitly in
Arabic: `لا توجد عمليات رد سلف أو عكسها في الفترة المحددة.`

It does **not** report advance creation/application movements, general customer
or supplier credit balances, an opening credit balance, ordinary cancellations,
or a generic overpayment register. It therefore cannot classify an opening
credit as an overpayment, nor classify a cancellation as a refund. These are
excluded rather than inferred. The repository does contain separate advance and
advance-refund domain workflows; COMPETITION-03 neither added nor changed any
of them.

Entity IDs are nullable in the canonical result. An unresolved historical
entity stays unresolved and is visibly labelled as such; no customer or supplier
name is fabricated. Active/inactive status is not used to discard a qualified
historical financial entry: financial accounts are loaded with
`includeInactive: true`, while entity resolution is best-effort from the
current durable repositories.

## Remediation

- Preserved the inherited `const` dropdown list.
- Deferred report initialization until an authorized financial-report user is
  available, so denied users do not start account, entity, or report reads.
- Corrected customer reversal lookup to inspect both collection and
  advance-refund financial accounts.
- Corrected supplier refund lookup to map an advance refund's
  `operationRequestId` to its supplier, and to inspect advance-refund accounts
  for qualified reversals. This is a read-only presentation lookup; no ledger
  or aggregation rule changed.
- Renamed the report and its menu entry to `تقرير رد السلف وعكسها`, updated the
  empty state and account heading, and retained the precise menu subtitle.
- Replaced hard-coded light-theme text/party colors with semantic color-scheme
  colors in this screen.
- Made date and action filters wrap responsively, with ellipsized date labels,
  to remove the observed 360px RTL overflow.
- Added a widget regression covering real menu navigation, pushed route host,
  back return, unchanged financial balances, permission denial, truthful empty
  state, RTL, high-contrast theme, and narrow layout.

The menu title change in `financial_reports_screen.dart` is the minimal
navigation-entry correction required to keep the source and destination labels
truthful and consistent.

## Files and verification

Production changes:

- `lib/features/financial_reports/advances_and_refunds_report_screen.dart`
- `lib/features/financial_reports/financial_reports_screen.dart`

Focused test added:

- `test/advances_and_refunds_report_screen_test.dart`

Relevant regression command completed successfully (177 tests):

```powershell
flutter test test\advances_and_refunds_report_screen_test.dart `
  test\phase9d_advances_and_refunds_report_test.dart `
  test\dc_u008_advances_test.dart `
  test\phase79_account_based_financial_reports_test.dart `
  test\phase80_financial_closing_test.dart `
  test\phase81_transaction_financial_backup_contract_test.dart `
  test\phase49b_stock_adjustment_report_test.dart --reporter compact
```

Final completion gates also passed:

- `flutter analyze --no-pub`: clean (88.4 seconds).
- Direct Dart SDK `analyze`: clean.
- `flutter test --reporter compact`: 1,452 passed and one known expected skip.
- `git diff --check`: clean.
- Direct Flutter-tools `build windows --release`: exit 0; the release executable
  was produced. The build emitted only the existing Firebase CMake deprecation
  and MSVCRT LNK4078 warnings.

No transaction workflow, ledger posting rule, balance mutation, schema,
backup contract, permission grant, or AI action was added or modified. The
protected `.build-diagnostics/` directory remains untouched and untracked.
