# Phase 102B — Moving Weighted Average Inventory Valuation and Transaction COGS

## Status

Implemented on `codex/phase-102b-moving-weighted-average-inventory-valuation-transaction-level-cogs` from the Phase 102A closure commit `ba7ac8736ffff6db4803cec5e6030a42137c39bb`.

Actual profitability remains deliberately **not activated**. Activation requires the owner to approve a real physical count, an integer opening cost in qirsh per kilogram for every product, supporting evidence, and an activation date. No production opening balance or historical profit was inferred or fabricated.

## Implemented contracts

- Perpetual moving weighted-average valuation uses integer money and quantity values with exact rational residual carry-forward; no accounting path uses `double`.
- Sales persist immutable line-level quantity, unit-cost, residual, and total COGS snapshots. A cancellation reverses the original snapshot rather than the current average.
- Purchases update the moving average. Direct cancellation is rejected after the purchased layer has been mixed, sold, adjusted, or falls in a closed period.
- Physical shortages consume the current average. Surpluses require an explicit integer cost, reason, evidence, owner authorization, and audit entry.
- Profitability activation is owner-only and creates the opening valuation snapshot from approved physical quantities and trusted costs.
- Profit reports authorize `canViewFinancialReports` before reading repositories, reject periods before activation, and report net sales, transaction COGS, gross profit, operating expenses, and net operating profit.
- The profitability report always shows the exact warning: `صافي حركة النقدية لا يساوي صافي الربح.`
- Expenses require an explicit `operating`, `capital`, or `nonOperating` classification. Only operating expenses reduce net operating profit. Historical reclassification is owner-only, requires a reason, and is audited.
- Legacy reference-cost reporting is labelled as a non-accounting reference indicator; it is not presented as accounting profit.

## Persistence and recovery

- Database schema advanced safely from 14 to 15 with activation, valuation-state, valuation-event, sale-cost-snapshot, and expense-classification persistence.
- Backup format advanced to v8 and includes activation state, product valuation states, valuation events, sale COGS snapshots, and expense classifications.
- Backup versions v1–v7 remain readable. Missing valuation fields restore as `profitabilityNotActivated`; no historical COGS is invented.
- Business-data wipe includes all valuation data.

## User experience

- The home dashboard is focused on daily operational information. Backup and restore administration was removed from the customer-facing daily view.
- Backup and restore now appears under Settings for the owner only.
- Stocktake uses a responsive, compact layout and requests surplus cost evidence only after profitability activation.
- The financial reports area contains the authoritative profitability screen and its controlled activation workflow.

## Verification coverage

Automated coverage includes arithmetic conservation and residuals, activation validation and authorization, durable persistence, transaction-level sale and purchase integration, exact cancellation reversals, stocktake handling, closed periods, profitability report permissions and periods, expense classifications, schema migration, backup v8 round-trip, and legacy v7 restore behavior.

Test fixtures are explicitly synthetic. They are not represented as owner or production data.

## Final reverification results

Final reverification was completed on 2026-07-27 (10:47 PM local). All mandatory gates passed explicitly:

- The five focused Phase 102B test files passed: 25 tests.
- Dashboard and Settings backup-placement coverage passed: 7 tests.
- Backup contract v1 through v8 coverage passed: 8 tests.
- Dashboard readiness coverage passed: 5 tests.
- Restore-empty-system coverage passed: 19 tests.
- Stocktake coverage passed: 25 tests.
- Valuation and COGS report coverage passed: 19 tests.
- Durable sale and expense coverage passed: 17 tests.
- The complete suite `flutter test` exited with code 0 after 175 seconds: 1,874 tests passed and 1 test was skipped (0 failures).
- `flutter analyze --no-pub` exited with code 0: no issues found in 83.9 seconds.
- `dart format --set-exit-if-changed .` exited with code 0: 357 files checked and 0 files changed in 6.20 seconds.
- `git diff --check HEAD~1 HEAD` exited with code 0. No whitespace errors were reported.
- `flutter build windows --release` exited with code 0 after 39.8 seconds and produced `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`. The build emitted non-fatal CMake deprecation and MSVC LNK4078 warnings.
- Native smoke launch started the release executable as process 16540. After five seconds it was still running and Windows reported `Responding=True`; the exact process was then stopped. No visible-window claim is made.

The final audit also confirmed that accounting money and quantity paths do not use `double`; fixed-point residuals are preserved without integer-overflow mutation; sale COGS snapshots are immutable; cancellation reverses the stored original cost; historical transactions are not repriced at the current average; reference cost is not accounting COGS; authorization is checked before profitability repository reads; schema migration and legacy restore do not activate profitability; and no opening quantity, opening cost, COGS, or profit data was fabricated.

Actual profitability remains inactive pending separate owner approval of real physical quantities, trusted opening costs, supporting evidence, and the activation date.
