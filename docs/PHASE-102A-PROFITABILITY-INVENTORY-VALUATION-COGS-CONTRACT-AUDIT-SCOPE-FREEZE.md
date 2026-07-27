# Phase 102A — Profitability, Inventory Valuation and COGS Contract Audit / Scope Freeze

Date: 2026-07-27
Branch: `codex/phase-102a-profitability-inventory-valuation-cogs-contract-freeze`
Phase decision: **Outcome A — FULL SUCCESS / CONTRACTS OWNER-APPROVED**

## 1. Executive Summary

The current application cannot calculate precise, auditable historical operating profit. It stores sales revenue and purchase prices, but inventory movements are quantity-only, opening inventory has no carrying value, and sale lines have no cost snapshot or COGS. The current report deliberately uses mutable product `referenceCostPricePiastersPerKg` and labels its figures as estimates; it must not become an accounting KPI.

Perpetual moving weighted average is selected and owner-approved as the future costing method for interchangeable grain. The owner also approved the activation boundary, expense classification, inventory-adjustment treatment, historical-data prohibition and old-purchase cancellation policy on 2026-07-27. Phase 102B is authorized to implement those contracts. Actual profitability activation remains blocked until the owner supplies and approves real physical-count quantities, trustworthy integer-qirsh costs per kilogram and the activation date. No production accounting behavior was changed in Phase 102A.

## 2. Starting Baseline

- Phase 101H commit: `4fe35d7c08d09ed7218c1731a37efa9c2f5af7e1`; local annotated tag remains unchanged.
- Phase 101H baseline: 1,844 passes, one known skip, analyzer and Windows Release passed.
- Phase 101I began from the two declared UI fixes only and did not mix profitability work.

## 3. Phase 101I Closure Evidence

- Commit: `fa627a783facc3570208eceec0867362cd57dae5`
- Message: `PHASE 101I: fix stocktake theme surface and dashboard hierarchy`
- Scope: two production UI files and three directly related tests; 116 insertions and 7 deletions.
- Verified 93 focused stocktake/dashboard/navigation/theme/RTL/backup tests, `flutter analyze --no-pub`, `git diff --check`, Windows Release, and an isolated native Windows launch. No tag or push was created.
- The stocktake route now uses the themed route scaffold instead of exposing the black surface. Dashboard order is guidance, operational summary/alerts, then administration/backup; permissions and backup destination are unchanged.

## 4. Current Sales Data Model

- `lib/core/sales/sale_record.dart:21-32` stores product, integer kg, selling price and line revenue only. `SaleRecord` adds payment mode, customer, paid amount/allocations, timestamps and cancellation metadata.
- `lib/core/sales/sale_repository.dart:72-126` validates stock, writes one quantity movement per item, and saves revenue. It stores no unit cost, COGS, inventory value, or cost provenance.
- `lib/core/sales/sale_repository.dart:184-205` restores quantity on cancellation, but cannot reverse original COGS because none was stored.
- `lib/core/sales/sale_controller.dart` separates customer-account entries and cash payment allocations from the sale document and wraps participating repositories in a rollback boundary.
- Completed, non-cancelled cash and credit sales are revenue. Collections and advances are not new revenue.

## 5. Current Purchasing Data Model

- `lib/core/purchases/purchase_intake.dart:22-65` stores quantity, integer-qirsh unit purchase price, total, supplier, payment mode and cancellation metadata.
- `lib/core/purchases/purchase_repository.dart:61-180` posts quantity, supplier liability, and paid cash outflow atomically, but does not post inventory value.
- `lib/core/purchases/purchase_repository.dart:299-310` permits cancellation whenever current total stock is at least the purchase quantity. That does not prove the original layer remains untouched after mixing or sales.
- Purchase payment changes cash/payables only. A purchase raises the inventory asset; it is not automatically a period expense or COGS.

## 6. Current Inventory Model

- `lib/core/inventory/stock_movement.dart:1-8` defines opening, manual increase/decrease, purchase, sale and cancellation movement types.
- `lib/core/inventory/stock_movement.dart:44-77` stores signed integer kg, timestamps and document/reversal references only—no value, unit cost or COGS.
- `lib/core/inventory/inventory_repository.dart:51-76` prevents negative quantity and a second opening movement, then derives stock by summing signed quantities.
- `lib/core/catalog/product.dart:23-25` contains optional default/minimum sale prices and a mutable optional reference cost. Reference cost is master-data guidance, not an accounting cost ledger.
- `lib/core/reports/business_summary_calculator.dart:28-67` estimates sales cost and stock value from the **current** reference cost. For multi-item invoices it reads the legacy first product/quantity fields rather than every line, so even the estimate can omit items. UI labels remain explicitly “تقديرية”.

## 7. Current Expense Model

- `lib/core/expenses/expense.dart` stores date, free-text category, positive integer-qirsh amount and optional payment route.
- `lib/core/expenses/expense_repository.dart:45-116` only creates/lists/sums expenses and posts an immediate cash outflow when routed. There is no accrual, capital/operating classification, cancellation, deletion or reversal contract.
- Therefore recorded expenses are paid entries, but not every free-text category can safely be assumed operating. Official operating profit needs an explicit classification field/policy; Phase 102A does not invent accrual accounting.

## 8. Current Financial Accounts Model

- `FinancialAccountEntry` records signed integer-qirsh inflow/outflow, effective date, source document and reversal references.
- Sources distinguish sale payment, purchase payment, collection, supplier settlement, advances/refunds, expense, cancellations and transfers.
- Customer and supplier ledgers separately represent receivables/payables, settlements and advances. This supports a cash-flow report, but cash entries are not a revenue or COGS source.
- Internal transfers must be paired and excluded from net business cash movement.

## 9. Current Closing Model

- `lib/core/financial_accounts/financial_account_repository.dart:819-873` creates non-overlapping approved closings.
- `_ensureDateIsOpen` at lines 907-912 blocks financial entries in a closed period.
- Sales, purchases and inventory movements use creation timestamps and have no inventory-value ledger or equivalent closing guard. Current closings therefore protect financial-account postings, not historical COGS/valuation.
- Future cost postings and reversals must check closure before any read/write side effect. Closed snapshots are never silently recomputed.

## 10. Current Backup Contract

- `BackupExportService.backupVersion` is 7; preview supports versions 1–7.
- Backup includes products, quantity movements, purchases, sales, expenses, ledgers, accounts and closings. It carries product reference cost and purchase price, but no opening valuation, valuation ledger, sale COGS snapshot or precision residual.
- Restore is owner-gated, preflighted, empty-system-only and transactionally rolled back on failure.
- A future cost engine requires a new schema migration and backup version. Version 7 and older may restore, but their pre-activation profitability classification must remain unavailable/estimated—not reconstructed silently.

## 11. Profit vs Cash Flow Decision

Profit and cash are separate reports. Net operating profit uses recognized revenue, stored COGS and classified operating expenses. Net cash movement uses actual financial-account inflows minus outflows, grouped by source, with internal transfers eliminated. The IFRS Foundation's IAS 7 summary likewise distinguishes cash flows and explains that profit requires adjustments for non-cash and timing effects. Source: [IFRS Foundation — IAS 7 Statement of Cash Flows](https://www.ifrs.org/issued-standards/list-of-standards/ias-7-statement-of-cash-flows.html/).

Mandatory Arabic warning: **صافي حركة النقدية لا يساوي صافي الربح.**

## 12. Revenue Recognition Decision

For this application contract, revenue is recognized when a non-cancelled sale is completed, regardless of cash/credit/partial payment. Net sales revenue equals completed sale-line totals less exact cancelled/reversed sale totals and only actually supported revenue discounts. Collections, advances, advance refunds, opening balances, supplier payments and internal transfers are excluded. The repository has no tax, invoice-discount, sales-fee or sales-return domain beyond full cancellation; these must not be invented or netted.

## 13. Inventory Valuation Alternatives

The full comparison and transaction effects are in [PHASE-102A-PROFITABILITY-COSTING-DECISION-MATRIX.md](PHASE-102A-PROFITABILITY-COSTING-DECISION-MATRIX.md). FIFO and weighted average are valid general formulas for interchangeable inventory under the IAS 2 summary; specific identification requires non-interchangeable/traceable units. Periodic average conflicts with immutable live-period snapshots, and reference/standard cost cannot be treated as actual here because no variance ledger exists.

## 14. Selected Costing Method

Select **perpetual moving weighted average per product**:

```text
newTotalValueQirsh = oldTotalValueQirsh + acceptedIncomingValueQirsh
newQuantityKg      = oldQuantityKg + incomingQuantityKg
newAverage         = newTotalValue / newQuantity (fixed precision, never binary float)
saleCOGSQirsh      = deterministic allocation from pre-sale carrying value
```

Purchases and approved valued surpluses update average. Sales and shortages consume current carrying value without changing the remaining average except for a deterministic residual. Reaching zero clears quantity, value and residual before the next purchase.

## 15. Opening Inventory Valuation Decision

Current opening stock carries quantity only, so its historical value cannot be determined. The owner approved **Option A**: after a real physical count, the owner enters and approves each product's reconciled quantity and integer-qirsh cost per kilogram supported by trustworthy purchase evidence, with source note and audit identity. This is an opening asset, not purchase, revenue, expense or cash flow.

There is no automatic activation date during migration or installation. The system remains `profitabilityNotActivated` until the workflow validates all products and the owner approves the snapshot and date. Accuracy begins only at that boundary. Products without trustworthy cost cannot be activated; selling price, reference cost, zero and defaults are prohibited substitutes. Previous purchases are summarized only by the approved opening snapshot and are not replayed historically.

## 16. Historical Sales Accuracy Decision

Historical sales before activation have revenue but no contemporaneous cost snapshot. Current reference costs may have changed and multi-item estimates can omit lines. Those periods are **not available for precise operating profit**. Classification:

- `exact`: all opening value, valued movements, sale COGS, reversals and expense classifications are complete and closed-safe.
- `exactFrom`: exact only on/after the approved activation timestamp.
- `estimated`: explicitly advisory, with method and missing-data warning.
- `unavailable`: ambiguity could materially change the result.

No estimate may masquerade as exact.

## 17. COGS Snapshot Decision

Each future sale item must persist immutable fields equivalent to `unitCostSnapshotFixed`, `costOfGoodsSoldQirsh`, `inventoryQuantityBeforeKg`, `inventoryQuantityAfterKg`, `inventoryValueBeforeQirsh`, `inventoryValueAfterQirsh`, `costMethodVersion`, and rounding/residual metadata. Names are illustrative; semantics are mandatory. Aggregate invoice COGS is the checked sum of line COGS. Product reference cost is never substituted.

## 18. Cancellation and Reversal Decision

- Sale cancellation restores the original quantity/value and negates the exact stored original line COGS; today's average is irrelevant. Revenue, receivable and original paid allocations reverse atomically.
- An untouched, open-period purchase can reverse its exact quantity/value and related payable/cash effects.
- A purchase that has been mixed, partially consumed, followed by other valuation events, or included in a closed period cannot be deleted/cancelled by replaying history. Block it and use the owner-approved explicit current-dated supplier return/corrective adjustment with reason and audit record.
- Idempotency keys, reversal links, preflight validation and one rollback boundary are mandatory.

## 19. Stocktake and Adjustment Decision

Owner-approved contract:

- Shortage/manual decrease consumes current moving-average carrying cost and posts a separately disclosed operating inventory loss.
- Surplus/manual increase requires an explicit integer-qirsh cost per kilogram, reason, documented source and owner approval recorded in the audit log. Missing cost blocks posting; zero-cost inventory is not silently created.
- Stocktake itself changes no cash. Opening inventory is separate from surplus and purchase.
- Closed-period effective dates are rejected before mutation.

## 20. Precision and Rounding Decision

- Existing money remains signed/unsigned 64-bit-compatible integers in qirsh; UI converts 100 qirsh = EGP 1.00.
- Existing quantity is integer kg; `GrainUnitConverter` defines 1 ton = 1,000 kg. The requested “fractional quantities” test means exact kg derived from a larger unit under the current contract; true sub-kg quantities require a separately authorized quantity-schema decision.
- Moving unit cost needs precision finer than one qirsh/kg. Store total carrying value in integer qirsh plus deterministic high-precision/rational state or residual; never use `double` for persisted monetary decisions.
- Allocate rounded COGS deterministically, carry the residual, force the final depletion to consume the exact remaining value, and use checked integer arithmetic for overflow.

## 21. Permissions Decision

Official profitability, COGS and inventory valuation use the existing `canViewFinancialReports` permission initially (owner true, employee false). Authorization must be checked **before any repository read** and again at navigation/service boundaries. `canViewReports` alone is insufficient for sensitive cost/margin data. A new granular permission may be proposed later but is not created in Phase 102A.

Activation, opening-snapshot approval and surplus-cost approval are owner-only and must emit audit records.

## 22. Proposed Profitability Report Contract

Inputs: authorized user; normalized inclusive-start/exclusive-end interval; non-cancelled sale lines by sale effective date; immutable COGS snapshots; explicitly classified operating expenses by expense date; approved inventory-loss adjustments; accuracy metadata and closing status.

Outputs (integer qirsh, EGP display): total/gross sales; cash, partial and credit sales split; net sales revenue; COGS; gross profit; operating expenses; inventory losses separately; net operating profit; gross and operating margin only when denominator is positive; exact/estimated/unavailable badge; activation date; missing-data reasons; drill-down IDs and reconciliation totals.

Formula:

```text
gross profit = net sales revenue - COGS
net operating profit = gross profit - classified operating expenses - approved inventory losses
```

Exclude taxes, payroll, depreciation, finance cost, non-operating income/expense and capital movements unless separately modelled and authorized. Therefore the KPI is `صافي الربح التشغيلي`, not “final net profit”.

## 23. Proposed Cash-Flow Report Contract

Inputs: authorized user, date interval, financial account entries and source/reversal links. Outputs: opening cash/bank/wallet balances, external inflows and outflows by source/payment method/account, net external movement, closing balances and drill-down. Eliminate transfer pairs from business inflow/outflow totals while still showing a transfer section. Collections of old invoices and supplier settlements affect cash only, not current revenue/COGS. Always display: **صافي حركة النقدية لا يساوي صافي الربح.**

## 24. Proposed Dashboard Presentation

Textual wireframe only; Phase 102A adds no UI:

```text
[إرشادات الاستخدام]
[ملخص التشغيل والتنبيهات]
[الأداء المالي]  ← after operational summary, before admin tools
  إجمالي المبيعات | مجمل الربح | المصروفات | صافي الربح التشغيلي
  نقدي / آجل
  حالة الدقة + تاريخ بدء الدقة
  صافي حركة النقدية لا يساوي صافي الربح.
[أدوات الإدارة — ومنها النسخ الاحتياطي]
```

The section appears only after authorization and successful, exact-data loading. Estimated/unavailable data cannot appear as an unqualified KPI.

## 25. Migration Strategy

Phase 102B requires a versioned, restart-safe migration from database schema 14:

1. Add valuation state/ledger, sale-line COGS snapshots, method/version, residual, activation metadata and expense classification without backfilling invented values.
2. Preflight referential integrity, integer bounds, document totals, cancellation pairs and closed periods.
3. Require owner-approved activation quantity/value per active stocked product, reconcile to current quantity, and record evidence/hash/user/time.
4. Initialize one immutable opening valuation event per product; idempotent re-run returns the same result.
5. Classify pre-activation periods unavailable/estimated and post-activation periods exact only after all invariants pass.
6. Execute atomically with rollback; reject ambiguous or missing product references.

No historical COGS backfill from mutable reference cost is allowed.

## 26. Backup/Restore Impact

Phase 102B must increment backup version from 7 (proposed 8) and include activation metadata, valuation events/state, sale-line cost snapshots, residual/method version and expense classification. Restore must preflight all relationships, totals, reversals, precision and closed-period consistency, then commit atomically. Older versions remain accepted only under an explicit legacy path that marks pre-activation profitability unavailable and requests valuation activation; no zero/default cost and no inferred reference cost.

The audit confirmed that v8 is not currently used; v7 is current, so v8 is the approved next format. All versions currently supported by restore (v1–v7) retain backward compatibility.

## 27. Test Plan

Future Phase 102B must implement these 60 cases with repository, persistence/backup and UI layers where applicable:

1. First purchase initializes quantity/value/average exactly.
2. Second purchase at another price computes weighted average from totals.
3. Partial sale stores and consumes correct line COGS.
4. Full sale consumes exact remaining value.
5. Zero stock clears value and residual.
6. Purchase after zero starts a fresh average.
7. Fractional business quantity represented exactly under approved quantity units.
8. Ton input equals 1,000 integer kg and matches kg costing.
9. Repeating fractions retain deterministic residual and reconcile.
10. Large quantity/value rejects overflow without mutation.
11. Every sale line stores immutable cost fields.
12. Product/reference-cost edits do not alter historical COGS.
13. Multi-item invoice costs every item and reconciles invoice total.
14. Cash sale recognizes revenue/COGS and cash once.
15. Credit sale recognizes revenue/COGS, not full cash.
16. Sale cancellation reverses stored revenue/COGS/value exactly and idempotently.
17. Insufficient stock rejects sale with no partial writes.
18. Sale from approved opening value has exact COGS.
19. Sale after multiple purchases uses the pre-sale moving average.
20. Partial-period report selects by effective date and reconciles drill-down.
21. Untouched open-period purchase cancellation reverses exact value.
22. Used/mixed purchase cancellation is blocked with corrective guidance.
23. Purchase effective in a closed period is rejected before mutation.
24. Cancellation effective in a closed period is rejected before mutation.
25. Purchase keeps supplier ledger/value references consistent.
26. Paying a purchase changes cash/payable, never COGS.
27. Stocktake shortage consumes average value and records inventory loss.
28. Stocktake surplus requires/uses approved cost source.
29. Manual increase without cost is blocked; valued increase is auditable.
30. Manual decrease consumes average and records configured loss.
31. Opening quantity/value initializes once and is not purchase/revenue.
32. Unvalued product blocks exact COGS/reporting.
33. Cash-only period profitability is independent of payment routing.
34. Credit-only period includes revenue/COGS and shows no false cash.
35. Mixed period splits payment modes while reconciling total revenue.
36. Old-invoice collection changes cash, not current profit.
37. Only classified operating expenses reduce operating profit.
38. Cancelled invoice disappears through exact reversals, not deletion.
39. Customer advance receipt/application is excluded from revenue until sale.
40. Supplier advance/payment is excluded from COGS until inventory is acquired/sold.
41. Internal financial transfer nets to zero business cash and zero profit.
42. Sale below cost displays a negative margin accurately.
43. No-sales period returns zero revenue/COGS with defined margin state.
44. No-expense period computes operating profit from gross profit.
45. Closed period is stable across later product/purchase/cost changes.
46. Backup v8 round-trip preserves every cost bit and report totals.
47. Backup v1–v7 restores through legacy unavailable/activation path.
48. Missing cost data rejects exact status and never defaults to zero.
49. Missing product reference fails preflight without writes.
50. Mid-restore failure rolls back all valuation and legacy data.
51. Owner with financial permission sees the report.
52. Unauthorized employee is rejected before data reads and navigation.
53. Light theme renders report hierarchy and contrast correctly.
54. Dark theme renders without hard-coded light/black surfaces.
55. RTL order, labels, numerals and tables remain usable.
56. Dashboard financial card navigates to the authorized report and returns.
57. Profitability/stocktake routes expose no unexpected black surface.
58. EGP input/display round-trips qirsh exactly at two decimals.
59. UI visibly states profit differs from cash movement.
60. Every KPI drill-down sums exactly to its source total and date scope.

## 28. Files Reviewed

Reviewed production contracts include: sales record/repository/controller; purchases intake/repositories/controller; inventory movement/repository; product/grain unit; expenses; customer and supplier ledgers/advances; financial entries/repository/closing/reports; business-summary/report repository/UI; permissions/dashboard; Drift schema/migrations; backup export/preview/restore; money validation/formatting; and directly related tests. Key files include `sale_record.dart`, `sale_repository.dart`, `purchase_intake.dart`, `purchase_repository.dart`, `stock_movement.dart`, `inventory_repository.dart`, `business_summary_calculator.dart`, `expense.dart`, `expense_repository.dart`, `financial_account_repository.dart`, `foundation_database.dart`, `backup_export.dart`, `backup_restore_service.dart`, `permissions.dart`, and `grain_unit.dart`.

## 29. Files Changed

Phase 102A changes only:

- `docs/PHASE-102A-PROFITABILITY-INVENTORY-VALUATION-COGS-CONTRACT-AUDIT-SCOPE-FREEZE.md`
- `docs/PHASE-102A-PROFITABILITY-COSTING-DECISION-MATRIX.md`

No production Dart, schema, backup, permission, report, dashboard or test behavior changed.

## 30. Verification Results

- Repository audit: completed across all listed domains.
- External accounting cross-check: official IFRS Foundation IAS 2 and IAS 7 summaries; decisions remain scoped to this software and require owner/accountant validation for statutory use.
- Phase 101I focused tests/analyzer/diff/build/native launch: pass as recorded in section 3.
- Phase 102A focused suite: **318 passed**, covering sales, multi-item sales, purchases/atomicity, inventory, stocktake/adjustments, expenses, financial accounts/transfers/closing, customer/supplier ledgers, reversals, backup, reports, dashboard/navigation, Light/Dark/RTL surfaces, EGP and money.
- Full suite: **1,847 passed, 1 known baseline skip**; no new skip.
- `flutter analyze --no-pub`: **No issues found**.
- Formatting: direct Dart SDK check on the five Phase 101I Dart/test files reported `Formatted 5 files (0 changed)`. The `dart.bat` wrapper timed out before output, so the SDK executable was used to distinguish wrapper failure from formatting drift. Phase 102A changes no Dart.
- `git diff --check`: pass.
- Windows Release: pass after running outside the restricted sandbox so CMake could access the installed Visual C++ compiler; built `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe` in 18.8 seconds. Non-fatal CMake deprecation and LNK4078 warnings remain.
- Native launch of the final Release: process `grain_warehouse_erp_lite` reported `Responding: True` after eight seconds with isolated data at `tmp/phase102a-native-launch-final`, then was stopped.
- Pre-closure source status: only the two authorized Phase 102A Markdown documents. The owner authorization resolves the decision blockers and permits the documentation closure commit; no tag or push is authorized.

## 31. Accounting Safety Decision

**NO ACCOUNTING, MONETARY, INVENTORY, BALANCE, OR PROFIT-CALCULATION BEHAVIOR CHANGED**

The audit explicitly rejects reference cost as official COGS, rejects silent historical backfill, and preserves closed-period immutability. This documentation does not itself implement production logic; the separate owner authorization permits Phase 102B to implement only the frozen contracts.

## 32. Outcome

**Outcome A — FULL SUCCESS / CONTRACTS OWNER-APPROVED.** Phase 102A is accepted as a documentation and implementation-contract handoff. The owner explicitly approved moving weighted average, no historical fabrication, manual activation after a physical count, trusted opening costs, immutable sale-line COGS, exact sale reversals, guarded purchase cancellation, valued stock adjustments, mandatory expense classification, precision, permissions, schema migration and backup v8.

This does not activate profitability or make any historic period exact. The system must remain `profitabilityNotActivated` until real owner data and an activation date pass the future workflow.

## 33. Exact Scope for Phase 102B

Authorized Phase 102B scope: implement the perpetual moving-weighted-average valuation ledger/state; `profitabilityNotActivated` opening-valuation workflow; immutable sale-line COGS snapshots; exact sale reversal; safe purchase cancellation/current-dated correction rules; valued stock adjustments; mandatory `operating`/`capital`/`nonOperating` expense classification; owner-only sensitive edits with audit; closed-period enforcement; migration from schema 14; backup v8 with v1–v7 compatibility; profitability reports that reject a start before activation; and the 60-case automated suite. Dashboard presentation remains Phase 102C unless separately authorized after the engine/report gates pass.

## 34. Remaining Owner Decisions

No Phase 102B contract decision remains open. Actual activation still requires owner-supplied production facts, not developer-created defaults:

1. Real approved physical-count quantity for every activated product.
2. Trustworthy integer-qirsh cost per kilogram and evidence for every activated product.
3. The owner-selected activation date after reconciliation.

Until those inputs are approved, all pre-activation profitability is displayed as `غير متاحة محاسبيًا — لا توجد بيانات تكلفة تاريخية كافية`, and no test fixture may be presented as owner production data.

**NO ACCOUNTING, MONETARY, INVENTORY, BALANCE, OR PROFIT-CALCULATION BEHAVIOR CHANGED**
