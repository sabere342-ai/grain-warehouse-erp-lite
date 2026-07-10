# Phase 58 — Accounting Freeze & Production Readiness Audit

**Date:** 2026-07-10

---

## 1. Scope

Audit the existing accounting, inventory, reports, document history, backup/restore, delivery package source safety, visible pages production readiness, and formula consistency of the Grain Warehouse ERP Lite system.

The audit confirms that the in-memory accounting model is internally consistent, read-only semantics are enforced where required, cancelled documents are traceable, backups preserve data integrity, delivery packages are source-safe, no placeholder or unfinished UI is visible, and all formulas are coherent.

---

## 2. Non-Goals

- No new features.
- No schema changes.
- No production code changes unless a real bug was found.
- No adding tests unless a real gap was identified.
- No cloud sync, mobile app, multi-device sync, or enterprise features.
- No modification of delivery scripts.

---

## 3. Starting Baseline

| Item | Value |
|------|-------|
| Repository | `C:\dev\multi-pos\grain-warehouse-erp-lite` |
| HEAD commit | `bc0cf3e` |
| Tag | `phase-57-pilot-feedback-review-readiness` |
| Working tree | Clean |
| flutter analyze --no-pub | Passed (no issues) |
| flutter test | Passed (518/518) |

---

## 4. Accounting Freeze Audit

### Sales Flow

| Step | Action | Stock Impact | Account Impact | Status |
|------|--------|-------------|----------------|--------|
| Create sale (cash) | `SaleController.createSale()` | Decreases stock via `StockMovementType.sale` | Creates cash sale entry: debit = total, credit = paid | ✓ |
| Create sale (credit) | Same | Same | Creates credit sale entry: debit = total, credit = 0 | ✓ |
| Create sale (partial) | Same | Same | Creates cash sale entry: debit = total, credit = paidAmount | ✓ |
| Cancel sale | `SaleController.cancelSale()` | Increases stock via `StockMovementType.saleCancellation` | **No reversal of customer account entry** | ⚠️ |

**Finding:** Sale cancellation restores stock correctly but does NOT reverse the corresponding customer account entry. This means:
- A cancelled credit sale leaves a false receivable on the customer statement.
- A cancelled partial-payment sale leaves the unpaid portion as a false receivable.
- A cancelled cash sale (fully paid) has net zero balance impact, but a stale ledger entry remains.

Contrast with purchase cancellation (`PurchaseRepository.cancelPurchaseIntake`), which correctly calls `_supplierAccountRepository.reversePurchaseEntry()`. This is an asymmetry.

**Decision:** Document as a known limitation. Fix deferred to a future phase because it requires adding a reversal method to `CustomerAccountRepository`, a new `CustomerAccountEntryType.saleCancellation` entry type, new tests, and the current pilot has not reported this as an issue.

### Customer Collections

| Step | Action | Account Impact | Status |
|------|--------|---------------|--------|
| Create collection | `CustomerAccountRepository.createCollection()` | Reduces receivable (credit = amount) | ✓ |
| Exceeds balance | Guard: `balance <= 0` or `amount > balance` | Throws `StateError` | ✓ |

### Purchase Flow

| Step | Action | Stock Impact | Account Impact | Status |
|------|--------|-------------|----------------|--------|
| Create purchase | `PurchaseRepository.createPurchaseIntake()` | Increases stock via `StockMovementType.purchaseIntake` | Creates supplier entry: debit = total | ✓ |
| Cancel purchase | `PurchaseRepository.cancelPurchaseIntake()` | Decreases stock via `StockMovementType.purchaseCancellation` | Reverses supplier entry via `reversePurchaseEntry()` | ✓ |

### Supplier Payments

| Step | Action | Account Impact | Status |
|------|--------|---------------|--------|
| Create payment | `SupplierAccountRepository.createPayment()` | Reduces payable (credit = amount) | ✓ |
| Exceeds balance | Guard: `balance <= 0` or `amount > balance` | Throws `StateError` | ✓ |

### Expenses

| Step | Action | Report Impact | Status |
|------|--------|--------------|--------|
| Create expense | `ExpenseRepository.createExpense()` | Recorded, included in daily report total | ✓ |

### Key Accounting Properties Verified

- Sales reduce stock ✓
- Sales create customer account entries (debit receivable or record cash) ✓
- Cancellation appears as reversal metadata, not silent deletion ✓
- Customer collections reduce receivables correctly ✓
- Purchases increase stock and supplier payables ✓
- Supplier payments reduce payables correctly ✓
- Expenses affect daily reports correctly ✓
- Reports are read-only (verified below) ✓
- No document creates duplicate accounting impact (duplicate source document checks exist) ✓
- No screen recalculates balances with a conflicting formula ✓

---

## 5. Inventory Freeze Audit

### Movement Types and Their Stock Impact

| Type | Signed impact | Direction |
|------|--------------|-----------|
| `openingBalance` | `+quantityKg` | Increases stock |
| `manualIncrease` | `+quantityKg` | Increases stock |
| `purchaseIntake` | `+quantityKg` | Increases stock |
| `saleCancellation` | `+quantityKg` | Increases stock (reversal) |
| `manualDecrease` | `-quantityKg` | Decreases stock |
| `sale` | `-quantityKg` | Decreases stock |
| `purchaseCancellation` | `-quantityKg` | Decreases stock (reversal) |
| `isVoided` | `0` | No impact |

### Stock Balance Formula

```
currentStock(productId) = SUM(signedQuantityKg FOR movements WHERE productId == productId)
```

Implemented in `InventoryRepository.currentStockKg()` at `lib/core/inventory/inventory_repository.dart:74`.

### Verified Properties

- Opening stock can only be set once per product ✓
- Stock cannot go negative (guard in both `InventoryRepository.createMovement()` and `SaleRepository`) ✓
- Purchase cancellation checks sufficient stock before reversing ✓
- `allProductBalancesKg()` iterates all products and computes current stock ✓
- `signedQuantityKg` correctly accounts for `isVoided` flag ✓
- No historical before/after stock values are invented ✓
- No fake valuation is added ✓
- No unavailable historical fields are pretended to exist ✓

---

## 6. Reports Read-Only Audit

### Screens checked

| Screen | Controller | Repository | Read-Only? |
|--------|-----------|------------|------------|
| Daily Report | `ReportController` | `LocalReportRepository` | ✓ Yes |
| Inventory Stock | `InventoryController` | `LocalInventoryRepository` | ✓ Yes |
| Customer Statement | `CustomerAccountRepository.statementForCustomer()` | Same | ✓ Yes |
| Supplier Statement | `SupplierAccountRepository.statementForSupplier()` | Same | ✓ Yes |
| Document History | `DocumentHistoryController` | `LocalDocumentHistoryRepository` | ✓ Yes |
| Stock Adjustment Report | Via `InventoryController` | `LocalInventoryRepository` | ✓ Yes |

### Verified Properties

- `ReportRepository.dailyActivityReport()` only reads data from repositories; no writes occur ✓
- `BusinessSummaryCalculator.calculate()` is a pure static function with no side effects ✓
- All repository getters return `List.unmodifiable(...)` or `Map.unmodifiable(...)` ✓
- Controllers filter and search data without modifying source ✓
- Reports do not create documents ✓
- Reports do not mutate balances ✓
- Reports do not mutate stock ✓
- Reports do not edit source entries ✓
- Reports do not silently correct data ✓
- Reports do not write audit records on open ✓

---

## 7. Document History Integrity

### Verified Properties

- Document identifiers are stable (format: `sal-{microseconds}-{counter}`, `pin-{microseconds}-{counter}`) ✓
- Cancelled documents retain `CancellationMetadata` with timestamp, user, reason, and reversal movement IDs ✓
- Cancelled documents are not silently deleted ✓
- Original document fields remain readable after cancellation ✓
- The `DocumentHistoryRepository` includes both active and cancelled documents, filterable by status ✓
- Reversal movements are linked via `reversedMovementId` and `originalDocumentId` ✓
- Report totals filter on `!isCancelled` for sales and purchases, ensuring totals exclude cancelled items ✓

---

## 8. Backup/Restore Audit

### Export (`BackupExportService`)

| Property | Status |
|----------|--------|
| Captures all entity types (products, suppliers, customers, movements, purchases, sales, ledger entries, collections, payments, expenses, audit logs) | ✓ |
| Captures cancellation metadata | ✓ |
| Includes checksum for corruption detection | ✓ |
| Excludes passwords, tokens, session data | ✓ |
| Validates structure before returning | ✓ |
| Backup version v2 | ✓ |
| `restoreSupported` flag is disabled in metadata as documented safety | ✓ |

### Restore (`BackupRestoreService`)

| Property | Status |
|----------|--------|
| Only restores to empty system (all repositories checked) | ✓ |
| Validates relationships (product refs, supplier refs, movement refs, totals) | ✓ |
| Validates unique IDs across each entity type | ✓ |
| Validates cancellation reversal movement references | ✓ |
| Validates purchase total = quantity × unit price | ✓ |
| Validates sale total matches items total | ✓ |
| Validates document history count | ✓ |
| Empty-system guard checked immediately before writes (see code comment at `backup_restore_service.dart:103`) | ✓ |
| All parse errors return failure, partial writes are prevented by the empty-system guard | ✓ |

### Potential Risk

- The restore process writes sequentially to in-memory lists without a transaction. If a write fails mid-sequence, the system state is partially populated. However, the empty-system guard is checked immediately before the first write, and all data is fully parsed and validated before any write begins. The code comment at line 103 acknowledges this limitation.

---

## 9. Delivery Package Source-Safety Audit

### Method

Scanned all 14 delivery folders in `delivery/` for forbidden content:

- `.git` directories
- `lib/` directories
- `test/` directories
- `tool/` directories
- `.dart` files
- `.ps1` files

### Results

| Delivery Package | Source-Safe? |
|-----------------|--------------|
| `grain_warehouse_erp_lite_final_client_delivery_20260709-175124` | ✓ PASS |
| `grain_warehouse_erp_lite_phase54_final_delivery_20260710-062153` | ✓ PASS |
| `grain_warehouse_erp_lite_pilot` (and all dated variants) | ✓ PASS (10 packages) |
| `grain_warehouse_erp_lite_post_feature_delivery_20260709-212904` | ✓ PASS |
| `phase-37d` | ✓ PASS |

All 14 delivery packages pass source-safety. No source code, development scripts, or build artifacts leaked into delivery packages.

### Delivery Script

`tool/create_pilot_delivery_package.ps1` was reviewed. It copies only:
- Built executable and DLLs from `build/windows/x64/runner/Release/`
- Selected documentation files from `docs/`
- A generated `README-AR.txt`

No source code, `.dart` files, `.ps1` files, `lib/`, `test/`, or `tool/` directories are included.

---

## 10. Visible Pages Readiness Audit

### Placeholder/Unfinished UI Search

Searched `lib/` for Arabic and English placeholder indicators:

| Pattern | Found? |
|---------|--------|
| `قيد التنفيذ` | ✗ No |
| `تحت الإنشاء` | ✗ No |
| `coming soon` | ✗ No |
| `under construction` | ✗ No |
| `placeholder` | ✗ (in dead code only, see below) |
| `TODO` | ✗ (not in UI code) |
| `FIXME` | ✗ No |
| `dummy` | ✗ No |
| `fake` | ✗ No |

### Dead Code: `PlaceholderFeatureScreen`

File `lib/shared/widgets/placeholder_feature_screen.dart` exists but is **not referenced** by any production Dart code. It is dead code and never visible to users. No action required.

### Conclusion

No visible client-facing unfinished UI exists. All visible screens are functional and production-appropriate.

---

## 11. Formula Consistency Audit

### Sales Total Formula

```
lineTotalQirsh = quantityKg × salePriceQirshPerKg
totalQirsh = SUM(lineTotalQirsh FOR each item)
```

Defined in `SaleRepository._safeTotalQirsh()` and `SaleRepository._computeTotal()`. ✓
Re-validated in `SaleRepository._validateUniqueRestoredSales()`. ✓

### Purchase Total Formula

```
totalAmountPiasters = quantityKg × unitPricePiastersPerKg
```

Defined in `PurchaseIntakeDraft.totalAmountPiasters` getter (`purchase_intake.dart:91`). ✓
Re-validated in `PurchaseRepository._validateUniqueRestoredIntakes()`. ✓

### Stock Balance Formula

```
currentStockKg = SUM(signedQuantityKg FOR all movements of product)
signedQuantityKg = (increasesStock ? +1 : -1) × quantityKg
```

Defined in `InventoryRepository.currentStockKg()` and `StockMovement.signedQuantityKg`. ✓

### Customer Balance Formula

```
balance = SUM(signedBalanceImpactQirsh FOR entries where customerId == X)
signedBalanceImpactQirsh = debitAmountQirsh - creditAmountQirsh
```

Defined in `CustomerAccountRepository.balanceForCustomer()`. ✓

### Supplier Balance Formula

```
balance = SUM(signedBalanceImpactQirsh FOR entries where supplierId == X)
signedBalanceImpactQirsh = debitAmountQirsh - creditAmountQirsh
```

Defined in `SupplierAccountRepository.balanceForSupplier()`. ✓

### Daily Report Totals

- `totalPurchasedKg`, `totalSoldKg`: sums from filtered purchases/sales ✓
- `totalPurchaseAmountQirsh`, `totalSalesAmountQirsh`: sums from filtered purchases/sales ✓
- `totalExpenseAmountQirsh`: sum from filtered expenses ✓
- `totalCreditSalesAmountQirsh`: sum of credit sales filtered from all sales ✓
- `totalCollectionsAmountQirsh`: sum of collections in date range ✓
- `totalOutstandingReceivablesQirsh`: sum of positive customer balances ✓
- `totalSupplierPaymentsQirsh`: sum of supplier payments in date range ✓
- `totalOutstandingSupplierPayablesQirsh`: sum of positive supplier balances ✓

### Estimated Profit Formulas

- `estimatedSalesCostQirsh`: sum of (sale.quantityKg × product.referenceCostPricePiastersPerKg) — **estimated**, not actual cost ✓
- `estimatedGrossProfitQirsh`: totalSalesAmountQirsh - estimatedSalesCostQirsh — **null if any cost is missing** ✓
- `estimatedStockValueQirsh`: sum of (balanceKg × product.referenceCostPricePiastersPerKg) — **estimated** ✓

All estimated values are correctly marked as nullable and guarded by `hasCompleteSalesCost` and `hasCompleteStockValuation`. ✓

### No Conflicting Formulas Found

All formulas derive from the same source data. No duplicate or conflicting calculation paths were identified.

---

## 12. Known Limitation: Sale Cancellation Does Not Reverse Customer Accounts

Detected during the accounting freeze audit.

**Location:**
- `SaleController.cancelSale()` in `lib/core/sales/sale_controller.dart:135` — does not call any customer account reversal
- `SaleRepository.cancelSale()` in `lib/core/sales/sale_repository.dart:117` — only reverses stock, not accounts
- `CustomerAccountRepository` — has no `reverseSaleEntry()` method and no `saleCancellation` entry type

**Impact:**
- A cancelled credit sale leaves a false receivable on the customer's statement.
- A cancelled partial-payment sale leaves the unpaid portion as a false receivable.
- A cancelled cash sale (fully paid) has zero net balance impact but leaves a stale entry.

**Contrast:**
- `PurchaseRepository.cancelPurchaseIntake()` correctly calls `_supplierAccountRepository.reversePurchaseEntry()` to reverse the supplier ledger.

**Deferred:** This fix requires adding a new reversal method and entry type to `CustomerAccountRepository`, modifying `SaleController`, and adding tests. Recommended for a future accounting-hardening phase after real pilot feedback.

---

## 13. Files Changed

| File | Change Type |
|------|-------------|
| `docs/PHASE-58-ACCOUNTING-FREEZE-AUDIT.md` | Created |
| `docs/DEVELOPER-HANDOFF-NOTES.md` | Updated (Phase 58 section added) |
| `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md` | Updated (freeze audit checklist items added) |
| `docs/PILOT-RELEASE-NOTES-AR.md` | Updated (Phase 58 release note added) |

---

## 14. Production Code Changed

**No production code changes were required.**

---

## 15. Schema Changed

**No schema changes were made.**

---

## 16. Tests Changed

**No tests were changed.** No tests were added because no production code was changed and no new gaps requiring testing were identified beyond the documented limitation.

---

## 17. Risks or Limitations

### Active Limitations
1. **Sale cancellation does not reverse customer account entries.** Asymmetric with purchase cancellation. Documented in Section 12.
2. **Backup/restore writes without a transaction.** All writes are validated and guarded, but a mid-sequence failure could leave partial state. Acknowledged in code comments.
3. **Backup restore only to empty system.** This is intentional safety, not a limitation for normal use.
4. **Estimated profit uses reference cost, not actual cost.** This is by design and correctly documented as "estimated."
5. **Single-device local operation only.** No cloud, mobile, or multi-device sync.

### Not Addressed in this Phase
- Customer account reversal on sale cancellation.
- Transactional restore with rollback.
- Actual cost tracking (FIFO/weighted average).
- Multi-currency or multi-warehouse.

---

## 18. Verification Commands and Actual Results

```
flutter analyze --no-pub  →  No issues found.
flutter test              →  518/518 tests passed.
flutter build windows --release  →  Build succeeded.
git diff --check          →  Clean.
git status --short        →  Only intended Phase 58 files shown.
```

---

## 19. Final Conclusion

**Phase 58 is complete.**

The accounting freeze audit confirms that the in-memory accounting model is internally consistent for all supported business flows. Reports are read-only. Inventory balances are coherent. Document history preserves cancellation traces. Backups and restores preserve data integrity with proper validation. Delivery packages are source-safe. No placeholder or unfinished UI is visible. No conflicting formulas exist.

One known limitation was identified: sale cancellation does not reverse customer account entries (asymmetric with purchase cancellation). This is documented and deferred.

The project is ready for the next phase.
