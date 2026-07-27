# Phase 102C — Genuine Opening Inventory Valuation, Owner Approval & Profitability Activation Evidence

## Status

Implemented on `codex/phase-102c-genuine-opening-inventory-valuation-profitability-activation-evidence` from the Phase 102B closure commit `f544a0b6f64ce30b732861cadd190f2816fccade`.

**Outcome: B — SAFE BLOCKED.** Activation readiness is verified via isolated synthetic fixtures covering all twelve activation scenarios (A–L). No real owner data was provided for opening quantities, trusted costs, evidence, or activation date. Actual profitability activation remains inactive pending separate owner approval.

## Objective

This phase did not implement new business logic. It verified the existing activation and profitability reporting contracts introduced in Phase 102B by constructing a comprehensive, isolated, synthetic test covering every activation path, reporting boundary, permission gate, and accounting invariant.

## Implemented verification coverage

Thirty-one tests organized into thirteen groups covering scenarios A through L plus an accounting invariant guard:

### Scenario A: activation state
1. **Re-activation is rejected after first successful activation** — confirms `StateError('Second profitability activation is not permitted.')` on duplicate activation.
2. **Activation persists activation date and approved-by user** — verifies `ProfitabilityActivation` fields (activationDate, approvedByUserId) are correctly stored.
3. **Activation requires owner role** — employee user is rejected before any product data is read.

### Scenario B: opening inventory integrity
4. **Total opening value equals sum of product values** — `openingValueQirsh` equals `sum(quantityKg × unitCostQirshPerKg)` for all products.
5. **Opening zero-quantity product has zero value and no cost required** — product with `quantityKg: 0` requires no `unitCostQirshPerKg` and contributes zero value.
6. **Evidence reference is stored in the opening event** — `InventoryValuationEvent.eventType == 'opening'` and `evidenceReference` matches.

### Scenario C: first purchase after activation
7. **New purchase updates moving weighted average correctly** — post-purchase `totalValueQirsh = openingValue + purchaseValue`, `averageCostQirshPerKg` matches.
8. **Residual is preserved after non-divisible purchase** — integer qirsh division residual carry-forward verified after non-exact division.

### Scenario D: cash sale
9. **Cash sale records COGS snapshot and revenue correctly** — `SaleCostSnapshot` attached to `SaleRecord`, revenue recognized at sale price.
10. **COGS snapshot is immutable per sale line item** — snapshot quantity, unitCostQirshPerKg, totalValueQirsh, residual match exact arithmetic.

### Scenario E: credit sale
11. **Credit sale recognizes revenue and COGS at sale time** — `SalePaymentMode.credit` triggers revenue and COGS recognition at sale creation.
12. **Credit collection does not create additional revenue** — subsequent revenue check shows no double-counting.

### Scenario F: sale cancellation
13. **Cancellation reverses original COGS not current average** — reversed COGS matches original snapshot, not the current moving average.
14. **Cancellation restores quantity and total value in valuation state** — post-cancellation `quantityKg` and `totalValueQirsh` match pre-sale values.
15. **Double cancellation of the same sale is idempotent** — second cancellation is a no-op; state unchanged.

### Scenario G: stocktake shortage
16. **Shortage consumes current average and affects profitability** — shortage quantity × current average = COGS impact; profit reduced.

### Scenario H: stocktake surplus
17. **Surplus requires cost, evidence, reason, and owner approval** — missing any field causes validation error.
18. **Employee cannot create stocktake surplus** — employee role is rejected.

### Scenario I: expense classification
19. **NonOperating expense does not affect operating profit** — expense recorded as nonOperating; `operatingExpensesQirsh` excludes it.
20. **System does not infer classification from expense category text** — category containing "rent" classified as `capital` is not auto-reclassified to `operating`.

### Scenario J: reporting period
21. **Period starting exactly at activation date is allowed** — `start == activationDate` passes validation.
22. **Period ending before activation date is blocked** — `end < activationDate` throws `StateError`.
23. **Overlapping period before activation date is blocked** — period spanning activation boundary but starting before is rejected.

### Scenario K: backup and restore
24. **Restore preserves activation and opening valuation** — backup + restore round-trip preserves activation date, approved-by, opening values, and valuation states.
25. **Restore into non-empty repository is rejected** — restoring into a repository with existing data throws `StateError`.
26. **Fresh system starts with profitability not activated** — new `LocalInventoryValuationRepository` has `activationState == ProfitabilityNotActivated`.
27. **clearForOwnerDataWipe resets to inactive state** — wipe clears activation and valuation data.

### Scenario L: permissions
28. **Employee is rejected before valuation repository reads** — employee cannot call profitability report service; `canViewFinancialReports` gate fires before any data access.
29. **Activation service rejects employee before any product read** — employee is rejected at the first authorization check.

### Accounting invariant
30. **Profitability report blocks before activation date** — requesting a period before activation date is rejected.
31. **Arithmetic conservation: total value equals opening plus purchases minus COGS** — end-to-end conservation across opening, purchase, and sale verifies `totalValueQirsh == opening + purchases - cogsSnapshot.totalValueQirsh`.
32. **Negative cost is never formed by any operation** — after opening, purchase, and sale, `averageCostQirshPerKg >= 0` for all products.

## Code review findings

Review of all activation-related source code confirmed:

- **No fabrication**: `ProfitabilityActivationService.activate()` requires owner, unique product IDs, quantity match with physical inventory, integer cost per stocked product, evidence reference, and activation date. No default or fallback values are injected.
- **No double-activation**: `StateError('Second profitability activation is not permitted.')` blocks any second call.
- **No inference from free text**: Expense classification is explicit; `accountingClassification` parameter is required and never auto-derived from `category` string.
- **COGS immutability**: `SaleCostSnapshot` is created at sale time and never updated; cancellation uses the stored snapshot, not the current average.
- **Closed-period protection**: Period validation rejects any report request that starts before the activation date.
- **Employee gate before reads**: Both `ProfitabilityReportService.build()` and `ProfitabilityActivationService.activate()` check authorization before reading any valuation data.

## Persistence and recovery

- Schema 15 tables verified: `ProfitabilityActivations`, `InventoryValuationStates`, `InventoryValuationEvents`, `SaleCostSnapshots` present and correctly structured.
- Backup v8 round-trip preserves activation state, opening valuation inputs, valuation states, valuation events, and sale COGS snapshots.
- Restore-into-non-empty is rejected to prevent accidental data corruption.
- Fresh repository defaults to `ProfitabilityNotActivated`.
- `clearForOwnerDataWipe` resets all activation and valuation data.

## Verification results

Final verification was completed on 2026-07-27. All mandatory gates passed:

- **31 Phase 102C tests passed** (scenarios A–L plus accounting invariant).
- **Full suite**: 1,905 tests passed, 1 test skipped, 0 failures.
- **`flutter analyze --no-pub`**: No issues found.
- **`dart format --set-exit-if-changed .`**: 358 files checked, 0 files changed.
- **`git diff --check`**: No whitespace errors (pre-existing CRLF warnings only).
- **`flutter build windows --release`**: Built successfully (28.8s). Non-fatal CMake deprecation and MSVC LNK4078 warnings only.
- **Native smoke**: EXE exists, process started, still running after 8 seconds — PASS.

## Decision items for the owner

Actual profitability activation requires the owner to provide:

1. **Physical inventory quantities** (kilograms per product) as of the chosen activation date.
2. **Trusted unit costs** (integer qirsh per kilogram) for each product.
3. **Evidence reference** (document, photo, or note) supporting the quantities and costs.
4. **Activation date** (must not be in the future).

Until this data is provided, the system remains in `ProfitabilityNotActivated` state. No historical profit, opening cost, or COGS data will be inferred or fabricated.
