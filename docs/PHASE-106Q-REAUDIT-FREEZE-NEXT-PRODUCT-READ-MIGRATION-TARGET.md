# Phase 106Q — Re-Audit and Freeze the Next Product Read Migration Target

## Phase identity

| Item | Value |
| --- | --- |
| Phase name | `PHASE 106Q` |
| Outcome | **Outcome A — FULL SUCCESS** |
| Branch | `codex/phase-106q-reaudit-freeze-next-product-read-migration-target` |
| Starting HEAD | `80ede9595b51c17d1b82f16a9198b91a9d9422d9` (`PHASE 106P: migrate purchase controller product catalog read`) |
| Final HEAD | The single Phase 106Q commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 106Q: freeze next product read migration target` |
| Commits after baseline | `1` |
| Initial worktree | Clean |
| Initial `git diff --check` | PASS — exit 0, no output |
| Push | NO |
| Tag | NO |

## Governing references

### Phase 106O summary

Phase 106O (`docs/PHASE-106O-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md`)
re-audited every remaining production product-read consumer after Phase 106N,
classified all 18 remaining consumers into exactly one category (A–I), and
froze a single next migration target: `PurchaseController.load` (Category A),
migrate-only, no contract expansion.

The governing A–I taxonomy is the one defined and applied in Phase 106O:

- A — Read-only, current-contract fit, standalone read (lowest risk)
- B — Current-contract fit (broader context, still eligible)
- C — Requires a broader read contract
- D — Requires a single-item lookup
- E — Requires a stream / reactive read
- F — Write-coupled / transaction-integrity read
- G — Financial / inventory / accounting criticality
- H — Not production-reachable
- I — False positive (infrastructure, not a consumer)

Phase 106O inventory result: 18 remaining consumers; distribution
A=1, B=1, C=2, D=0, E=0, F=8, G=1, H=3, I=2; 6 migrated; 24 total identified.

### Phase 106P summary

Phase 106P (`docs/PHASE-106P-MIGRATE-PURCHASE-CONTROLLER-PRODUCT-CATALOG-READ.md`)
migrated the single frozen target from Phase 106O — `PurchaseController.load`
in `lib/core/purchases/purchase_controller.dart` — from the legacy
`ProductRepository.listProducts(...)` read path to the accepted
`ProductCatalogReadRepository.listProductCatalog(...)` boundary. The controller
now reads products exclusively through the catalog read contract, stores them as
`List<ProductCatalogReadModel>`, and preserves the full production behavior of
the purchase workflow. No contract expansion, schema change, migration, legacy
contract deletion, or second-consumer migration happened in Phase 106P.

Phase 106P verified: 10/10 phase tests, 25/25 guards (106K/106M/106N/106O/106P),
`flutter analyze` clean, full suite 2102 passed / 0 failed / 1 historical skip,
Windows Release build successful, tree clean, exactly one commit after baseline.

### Impact of migrating `PurchaseController.load`

After Phase 106P, `lib/core/purchases/purchase_controller.dart` contains
`.listProductCatalog(` and no longer contains `.listProducts(` or
`ProductRepository`. The two purchase screens
(`lib/features/purchases/purchases_screen.dart` and
`lib/features/purchases/supplier_purchases_screen.dart`) wire
`AppRepositories.productCatalogReadRepository`. The legacy `listProducts`
consumer set shrank by exactly this one file/consumer. The `ProductCatalogReadModel`
contract and its adapter were untouched.

## Current contract snapshot

The accepted production boundary remains:

```text
ProductCatalogReadRepository.listProductCatalog
→ DriftProductCatalogReadRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

The current, unmodified read model (verified from source at HEAD):

| Field | Dart type | Nullable | Source |
| --- | --- | --- | --- |
| `id` | `String` | no | `products.id` |
| `name` | `String` | no | `products.name` |
| `code` | `String?` | yes | `products.code` |
| `unit` | `GrainUnit` | no | `products.unit` through `GrainUnit.fromWireName` |
| `isActive` | `bool` | no | `products.isActive` |
| `referenceCostPricePiastersPerKg` | `int?` | yes | `products.referenceCostPricePiastersPerKg` |

The sole operation is
`Future<List<ProductCatalogReadModel>> listProductCatalog({required bool includeInactive})`.
`includeInactive: false` filters to active rows; `true` returns active and
inactive rows. Results are ordered by `createdAt ASC, id ASC`, materialized as
a fresh non-growable list, and are empty when no row matches. Query and mapping
errors propagate. There is no cache, retry, fallback, stream, single lookup,
write, or transaction side effect.

## Search methodology

The Phase 106O inventory, the Phase 106P migration report, and all earlier
reports (105A–105F, 106A–106P) were treated as historical references, not as
current truth. The following executable searches were repeated against the
current source at HEAD `80ede95`:

- `ProductRepository`, `ProductDataRepository`, `DriftProductRepository`
- `listProducts`, `watchProducts`, `getProduct`, `productById`, `findProduct`
- `productRepository`, `_productRepository`
- `ProductCatalogReadRepository`, `listProductCatalog`, `ProductCatalogReadModel`
- `currentStockKg`, `hasOpeningBalance`, `_validateProduct`, `_findProduct`

Every match was opened and traced through its constructor, entry point,
downstream field use, write boundary, transaction membership, and production
composition. Reachability was proven through real execution paths only: screen
→ controller → service → repository → `AppRepositories` → Drift → SQLite.
Class existence alone was not accepted as proof.

### Folders and files examined

| Area | Notes |
| --- | --- |
| `lib/app/app_repositories.dart` | composition root; legacy wrapper and Drift swap; already wires `productCatalogReadRepository` into `DriftInventoryRepository` |
| `lib/core/catalog/` | contract, Drift adapter, legacy repository, controller, model |
| `lib/core/inventory/` | drift + local inventory repositories, controller, attention service |
| `lib/core/sales/` | sale repositories (incl. `DriftSaleRepository` delegation), sale controller |
| `lib/core/purchases/` | purchase repositories, purchase controller (migrated) |
| `lib/core/backup/` | backup export, restore, preview, wipe |
| `lib/core/financial_accounts/` | negative-balance approval workflow |
| `lib/core/inventory_valuation/` | profitability activation + synthetic service |
| `lib/core/dashboard/` | `dashboard_service.dart`, `dashboard_screen.dart` destination map |
| `lib/features/inventory/` | inventory, stock-take, stock-adjustment-report screens |
| `lib/features/purchases/` | purchases, supplier-purchases screens (migrated wiring) |
| `lib/features/financial_reports/` | profitability report screen |
| `test/` | freeze guards and controller coverage files |

### How indirect consumers were discovered

Indirect consumers were found by following dependency injection across
composition boundaries: `AppRepositories` getters (`productRepository`,
`productDataRepository`, `productCatalogReadRepository`), constructor
parameters typed `ProductRepository` / `ProductDataRepository`, and delegation
paths (e.g. `DriftSaleRepository` → `LocalSaleRepository` at
`lib/core/sales/drift_sale_repository.dart:27–32`). A consumer was counted only
when the read path is reached from a real production entry point.

### How production reachability was determined

A consumer is production-reachable only when its read executes after
`AppRepositories.initializeProduction` swaps the composition root to the Drift
implementations. Rows that are superseded at initialization or deliberately
never wired (test-only `Local*Repository` implementations and the synthetic
Phase 102 tool) are classified H. Infrastructure adapters (the legacy read
surface and the composition-root wrapper) are classified I.

## Reconciliation

| Number | Value |
| --- | --- |
| Total identified consumers | 24 |
| Migrated before 106Q | 7 (six from 106A–106P plus `PurchaseController.load` in 106P) |
| Remaining after 106Q | 17 |
| `Total = migrated + remaining` | `24 = 7 + 17` — exact match |

The arithmetic expectation from Phase 106O/106P was `24 total`, `7 migrated`,
`17 remaining`. The actual executable re-audit reproduces exactly those numbers;
no consumer was added, deleted, de-duplicated, reclassified, or changed in
production reachability or dependency since Phase 106O. No reconciliation
variance exists.

The current executable search yields 17 remaining consumers after excluding the
two infrastructure files (I) and the three not-production-reachable rows (H),
plus the seven already-migrated consumers. The inventory therefore remains 24
identified consumers total, and each remaining row has exactly one A–I class.

## Full inventory

Inventory unit: one production-reachable method/state/workflow with a distinct
product-read behavior. Repository declarations, adapters, and application
composition are evidence but are not consumer rows. PRC-110 was migrated in
Phase 106P and is listed as migrated; the remaining rows keep the Phase 106O
identifiers.

| # | Consumer / file | Entry and reachability evidence | Repo type | Legacy method | Direct | Fields actually read | Filter / order / shape | Transaction / write | Class | Eligible with current contract | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-101 | `BackupExportService.createBackup` — `lib/core/backup/backup_export.dart:100–104` | backup-export screen; mandatory pre-wipe backup; `AppRepositories.backupExportService` | `ProductRepository` | `listProducts(includeInactive: true)` (line 102) | yes | all 11 fields: `id`, `name`, `code`, `unit.name`, `isActive`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `referenceCostPricePiastersPerKg`, `notes`, `createdAt`, `updatedAt` | inactive included; `createdAt,id`; full snapshot | backup/wipe lifecycle | F | no — needs 5 fields beyond contract | Critical |
| PRC-102 | `BackupRestoreService._checkEmptySystem` — `lib/core/backup/backup_restore_service.dart:232` | restore preview/execute via `restoreToEmpty` | `ProductDataRepository` | `listProducts(includeInactive: true)` (line 232) | yes | emptiness (`products.isNotEmpty`) | inactive included; order irrelevant | guards atomic multi-repository restore | F | no — restore-integrity gate | Critical |
| PRC-103 | `BusinessDataWipeService._currentCounts` — `lib/core/backup/business_data_wipe_service.dart:160` | owner destructive wipe | `ProductDataRepository` | `listProducts(includeInactive: true)` (line 160) | yes | count only (`products.length`) | inactive included; order irrelevant | destructive wipe flow | F | no — destructive-workflow coupling | Critical |
| PRC-104 | `ProductController.loadProducts` — `lib/core/catalog/product_controller.dart:19–29` | `DashboardShell` → `ProductsScreen` | `ProductRepository` | `listProducts(includeInactive: user.permissions.canManageProducts)` (line 24) | yes | `id`, `name`, `code`, `unit`, `isActive`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `referenceCostPricePiastersPerKg`, `notes` (display + edit form) | permission-shaped inactive; `createdAt,id`; no limit | loader is outside write transactions | C | no — needs broader management projection | High |
| PRC-105 | `NegativeBalanceApprovalWorkflowService._findProduct` / `_requireProduct` — `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart:762–769` | approval request, revalidation, and execution (paid purchase/sale) | `ProductRepository` | `listProducts(includeInactive: true)` (line 765) | yes | `id`, `isActive`, `updatedAt` (payload fingerprint, lines 266/585–587) | inactive included; exact-ID scan; no paging | financial approval and posting | F | no — needs `updatedAt` | High |
| PRC-106 | `DriftInventoryRepository._findProductById` (via `currentStockKg`, `hasOpeningBalance`, `_validateDraftAndLoadProduct`) — `lib/core/inventory/drift_inventory_repository.dart:196–203` | `InventoryController` movement flows; purchase/sale stock checks | `ProductRepository` | `listProducts(includeInactive: true)` (line 198) | yes | `id`, `isActive` | inactive included; exact-ID scan | inside `createMovement` transaction boundary | F | no — transaction-integrity | Critical |
| PRC-107 | `InventoryController.load` — `lib/core/inventory/inventory_controller.dart:48–72` | `DashboardShell` → `InventoryScreen` / `StockTakeScreen` / `StockAdjustmentReportScreen` | `ProductRepository` | `listProducts(includeInactive: user.permissions.canCreateStockAdjustment)` (line 53) | yes | `id`, `name` | permission-shaped inactive; `createdAt,id`; no limit | loader is outside write transactions | **B — selected** | **yes** — `id`, `name` | Low |
| PRC-108 | `ProfitabilityActivationService.activate` — `lib/core/inventory_valuation/profitability_activation_service.dart:48–64` | owner profitability activation (report screen button) | `ProductRepository` | `listProducts(includeInactive: true)` (line 49) | yes | `id` membership | inactive included; full list | atomic valuation + audit activation | F | no — activation safety | Critical |
| PRC-109 | `DriftPurchaseRepository._validateProduct` / `_validateProductExists` — `lib/core/purchases/drift_purchase_repository.dart:334,350` | `PurchaseController.createPurchaseIntake` / cancel → durable purchase mutation | `ProductRepository` | `listProducts(includeInactive: true)` (lines 334, 350) | yes | `id`, `isActive` | inactive included; exact-ID scan | purchase transaction boundary | F | no — transaction-integrity | High |
| PRC-111 | `LocalSaleRepository._validateProduct` / `_validateAllMinimumPrices` — `lib/core/sales/sale_repository.dart:565` (reached via `DriftSaleRepository` delegation, `lib/core/sales/drift_sale_repository.dart:27–32`) | `SalesScreen` → `SaleController.createSale` → `DriftSaleRepository` → delegate | `ProductRepository` | `listProducts(includeInactive: true)` (line 565) | yes | `id`, `isActive`, `minimumSalePricePiastersPerKg` | inactive included; exact-ID scan | sale + COGS + stock + account write | F | no — needs `minimumSalePricePiastersPerKg` | Critical |
| PRC-112 | `SaleController.load` — `lib/core/sales/sale_controller.dart:59–78` | `DashboardShell` → `SalesScreen` | `ProductRepository` | `listProducts(includeInactive: false)` (line 65) | yes | `id`, `name`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg` | active only; `createdAt,id`; no limit | loader is outside write transactions | C | no — needs two sale-price fields | Medium |
| PRC-113 | `_ProfitabilityReportScreenState._activate` — `lib/features/financial_reports/profitability_report_screen.dart:139–141` | `FinancialReportsScreen` → `ProfitabilityReportScreen` → activation button | `ProductRepository` (`AppRepositories.productRepository`) | `listProducts(includeInactive: true)` (line 141) | yes | `id`, `name` (activation dialog) | inactive included; `createdAt,id`; per dialog | feeds financial activation write | G | no — financially critical owner-only write workflow | Critical |
| PRC-114 | `LocalInventoryRepository.allProductBalancesKg` / `_findProductById` — `lib/core/inventory/inventory_repository.dart:128,204` | superseded by `DriftInventoryRepository` during `initializeProduction`; test-only | `ProductRepository` | `listProducts(includeInactive: true)` | yes | `id`, `isActive` | caller-shaped | test-only | H | n/a — not production-reachable | N/A |
| PRC-115 | `LocalPurchaseRepository._validateProduct` — `lib/core/purchases/purchase_repository.dart:426` | superseded by `DriftPurchaseRepository`; test-only | `ProductRepository` | `listProducts(includeInactive: true)` | yes | `id`, `isActive` | inactive included; exact-ID scan | test-only | H | n/a — not production-reachable | N/A |
| PRC-116 | `SyntheticProfitabilityActivationService.activate` — `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart:84` | deliberately not wired into production; isolated Phase 102 tool | `ProductDataRepository` | `listProducts(includeInactive: true)` | yes | emptiness | inactive included; order irrelevant | creates synthetic catalog/valuation | H | n/a — not production-reachable | N/A |
| PRC-117 | `_LegacyProductCatalogReadRepository.listProductCatalog` — `lib/app/app_repositories.dart:347–362` | composition-root adapter; default before `initializeProduction` swaps to Drift | `ProductRepository` | `listProducts(...)` (line 357) | indirect (wrapper) | adapts to `ProductCatalogReadModel` | contract order | none | I | n/a — infrastructure adapter, not a consumer | N/A |
| PRC-118 | `DriftProductRepository.listProducts` — `lib/core/catalog/drift_product_repository.dart:16` | legacy read surface definition | Drift / SQLite | `listProducts` | n/a | surface | n/a | none | I | n/a — infrastructure, not a consumer | N/A |

No consumer appears twice under different names. Direct reads and indirect
paths are separated per row. The not-production-reachable rows (H) and the
infrastructure rows (I) are documented but never selected as migration targets.

## Classification summary

- A — Read-Only, Current-Contract Fit, Standalone: 0
- B — Current-Contract Fit (broader context): 1
- C — Requires a Broader Read Contract: 2
- D — Requires a Single-Item Lookup: 0
- E — Requires a Stream / Reactive Read: 0
- F — Write-Coupled / Transaction-Integrity Read: 8
- G — Financial / Inventory / Accounting Criticality: 1
- H — Not Production-Reachable: 3
- I — False Positive (Infrastructure): 2
- Sum of categories: 17
- Remaining inventory: 17
- Migrated and accepted: 7
- Total identified: 24

`Sum of categories == Remaining inventory == 17`, and
`Migrated + Remaining == Total == 24`.

### Per-classification rationale

| Class | Members | Why they belong here | Why not another class |
| --- | --- | --- | --- |
| B | `InventoryController.load` | Read-only loader outside write transactions; needs only `id` and `name`, both present in the frozen contract; production-reachable through three screens | Not A only because the same controller also owns financially sensitive inventory/valuation mutation flows (a broader context than a pure standalone display read); still fully contract-eligible. Not C: no field absent from the contract is needed. Not F: `load` itself performs no writes and no transaction-boundary read |
| C | `ProductController.loadProducts`, `SaleController.load` | Loader reads that need fields beyond the frozen contract | Not A/B because required fields (`defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, and `notes` for the product management screen) are absent from the contract. Not F because their loaders are outside write transactions — the blocker is purely the missing projection fields |
| F | `BackupExportService`, `BackupRestoreService._checkEmptySystem`, `BusinessDataWipeService._currentCounts`, `NegativeBalanceApprovalWorkflowService._findProduct`, `DriftInventoryRepository._findProductById`, `ProfitabilityActivationService.activate`, `DriftPurchaseRepository._validateProduct`, `LocalSaleRepository._validateProduct` | The read is a validation/guard inside a write or transaction-integrity boundary, or requires a full-fidelity snapshot | Not A/B/C because either they need fields absent from the contract (`updatedAt`, `minimumSalePricePiastersPerKg`, timestamps, notes, prices) or the read is inseparable from the enclosing write/transaction boundary |
| G | `_ProfitabilityReportScreenState._activate` | Owner-only financial activation read feeding a financial write workflow | Not A/B because it feeds a financially critical activation write. Not F because the read itself is not inside a transaction, but its criticality and write-feeding nature justify a distinct class |
| H | `LocalInventoryRepository`, `LocalPurchaseRepository`, `SyntheticProfitabilityActivationService` | Not production-reachable after `initializeProduction` | Not A–G because no production entry point reaches them |
| I | `_LegacyProductCatalogReadRepository`, `DriftProductRepository` | Infrastructure, not consumers | Not A–H because they are composition-root/read-surface definitions, not production read workflows |

## Candidate comparison

Only `InventoryController.load` (B) is eligible under the current contract. The
two C candidates are contract-blocked; every F candidate is write/transaction
coupled or needs a field outside the contract; G is financially critical; H and
I are unreachable/infrastructure.

| Rank | Candidate | Class | Evidence of fit | Decision |
| --- | --- | --- | --- | --- |
| 1 | `InventoryController.load` | B | Read-only loader; `id`, `name` only — both in the frozen contract; three production screens compose `AppRepositories`; ordering and permission semantics are preserved by the contract adapter; `includeInactive` maps 1:1 onto `user.permissions.canCreateStockAdjustment`; the composition root already injects `productCatalogReadRepository` into `DriftInventoryRepository`, proving the boundary is composed for the inventory stack today | **selected** |
| 2 | `ProductController.loadProducts` | C | Management projection needs `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `notes` | rejected — fields absent from contract; would need a management projection contract, not a migrate-only phase |
| 3 | `SaleController.load` | C | Sale-entry UI needs `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg` | rejected — fields absent from contract |
| — | All F rows | F | Every read is a validation/guard inside a write/transaction boundary or needs fields absent from the contract | rejected — atomic migration would change transaction integrity or require a broader contract |
| — | `_ProfitabilityReportScreenState._activate` | G | Financially critical owner-only activation | rejected — criticality |
| — | H and I rows | H / I | Not reachable / infrastructure | rejected — not consumers or not reachable |

## Frozen target

Selected migration target: InventoryController.load

The next phase is **Phase 106R — Migrate `InventoryController.load` to `ProductCatalogReadRepository`** (migration only).

```text
Consumer:           InventoryController.load
File:               lib/core/inventory/inventory_controller.dart
Class:              InventoryController
Method:             load (lines 48–72)
Approximate line:   53 (legacy read assignment)
Classification: B — current-contract fit (broader context, still eligible)
Production reachable: yes — three screens compose AppRepositories
Current dependency: ProductRepository (constructor, line 16/21/27)
Legacy read:        _productRepository.listProducts(
                      includeInactive: user.permissions.canCreateStockAdjustment)  (line 53)
Frozen read:        _productCatalogReadRepository.listProductCatalog(
                      includeInactive: user.permissions.canCreateStockAdjustment)
Required fields:    id, name — both already frozen
Contract delta:     none (strict superset today)
Next phase type:    Migration only
Boundary:   ProductCatalogReadRepository
Operation:  listProductCatalog({required bool includeInactive})
Read model: ProductCatalogReadModel
No lookup, no stream, no transaction, no write, no fallback, no cache
```

### Current execution path

The selected target is reached exclusively through real production composition
(identical pattern in three screens):

```text
DashboardShell destination "Inventory" / "StockTake" / "StockAdjustmentReport"
→ InventoryScreen / StockTakeScreen / StockAdjustmentReportScreen .initState
→ InventoryController(inventoryRepository, productRepository:
    AppRepositories.productRepository, ...)   [lib/features/inventory/*_screen.dart]
→ InventoryController.load (lib/core/inventory/inventory_controller.dart:48–72)
→ _productRepository.listProducts(
    includeInactive: user.permissions.canCreateStockAdjustment)  (line 53)
→ ProductRepository (legacy product read contract)
→ AppRepositories.productRepository
→ DriftProductRepository (production) / LocalProductRepository (tests)
→ Drift / SQLite products table
```

### Data required

The loaded `_products` list is consumed exclusively for `id` and `name`:

- `inventory_screen.dart` — inventory cards render `product.id` (lines 157,
  222, 515, 546) and `product.name` (lines 202, 344, 419, 547); the opening
  balance dialog and the movement form dialog take `Product` /
  `List<Product>` and read `id` + `name` only.
- `stock_take_screen.dart` — stock-take rows render `product.id` (lines 175,
  288) and `product.name` (lines 189, 303, 326, 483); `_StockTakeAdjustment`
  stores the product and reads `name` only.
- `stock_adjustment_report_screen.dart` — report rows resolve names via a
  `product.id → product.name` map (lines 160–172).

No inventory screen reads `code`, `unit`, `isActive`,
`referenceCostPricePiastersPerKg`, notes, timestamps, or any other product
field; `isActive` membership is decided by the `includeInactive` filter alone.

### `includeInactive` semantics

```text
includeInactive = user.permissions.canCreateStockAdjustment
```

Owner (`canCreateStockAdjustment == true`) → `includeInactive: true` → active
and inactive products are loaded (inventory cards, stock-take rows, adjustment
report names). Employee (`false`) → `includeInactive: false` → active products
only. This is identical to the legacy call, so the catalog contract parameter
maps 1:1 with no semantic change.

### Expected migration bounds (Phase 106R, not executed here)

Expected production files for the later migrate-only phase:

| File | Expected change |
| --- | --- |
| `lib/core/inventory/inventory_controller.dart` | Replace `ProductRepository` dependency with `ProductCatalogReadRepository`; `_products`/`products` typed `List<ProductCatalogReadModel>`; `load` calls `listProductCatalog(...)` |
| `lib/features/inventory/inventory_screen.dart` | Wire `AppRepositories.productCatalogReadRepository`; dialog product types (`_InventoryProductCard.product`, `_OpeningBalanceDialog.product`, `_MovementFormDialog.products`) |
| `lib/features/inventory/stock_take_screen.dart` | Wire `AppRepositories.productCatalogReadRepository`; `_buildProductRow` and `_StockTakeAdjustment.product` types |
| `lib/features/inventory/stock_adjustment_report_screen.dart` | Wire `AppRepositories.productCatalogReadRepository` |

Expected test call sites for the constructor change: 15 sites across
`inventory_test.dart`, `phase102b_transaction_integration_test.dart`,
`phase102c_activation_readiness_verification_test.dart`,
`phase49a_stock_take_test.dart`, `phase49b_stock_adjustment_report_test.dart`,
`phase51_real_business_day_simulation_test.dart`,
`phase52_accounting_freeze_audit_test.dart`,
`phase53_cloud_migration_readiness_test.dart`.

### Selection rationale (highest-priority justification wins)

1. The only remaining current-contract-eligible consumer: after Phase 106P, all
   other consumers are either contract-blocked (C), write/transaction-coupled
   (F), financially critical (G), not production-reachable (H), or
   infrastructure (I).
2. Read-only standalone enumeration: `load` is outside write transactions; no
   write path in `InventoryController` reads `_products` for validation (movement
   validation lives in `DriftInventoryRepository._validateDraftAndLoadProduct`,
   which is separately classified F). Its later migration cannot change
   transaction integrity.
3. Production-reachable through three independent real screens, each composing
   `AppRepositories` at runtime.
4. Current-contract fit: only `id` and `name` are consumed — a strict subset of
   the frozen model. No contract expansion, no single-lookup op, no stream, no
   schema change.
5. Atomic and small: one constructor parameter + one replacement line in `load`
   plus the three screen composition sites and their dialog types; no second
   consumer is required to move with it.
6. No ordering, filtering, permission, or naming semantics change: the adapter
   ordering (`createdAt ASC, id ASC`) equals the legacy ordering, and the
   `includeInactive` expression is preserved verbatim.
7. Existing coverage (`inventory_test.dart`, `phase49a`, `phase49b`,
   `phase51/52/53`, `phase102b/102c`) exercises the three screens and the
   controller end to end, so the later atomic migration is verifiable without
   new UI tests.

## Rejected alternatives

| Candidate | Category now | Rejection reason |
| --- | --- | --- |
| `ProductController.loadProducts` | C | Product management projection needs `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, and `notes` (plus the contract fields) for the display and edit form. A migrate-only swap to `ProductCatalogReadModel` would lose data the UI actually renders. Would require a broader management projection contract in a separate phase. |
| `SaleController.load` | C | Sale-entry UI needs `defaultSalePricePiastersPerKg` and `minimumSalePricePiastersPerKg` (sales_screen.dart:400–401) to seed the sale price field and enforce the minimum-price guard. Neither field exists in `ProductCatalogReadModel`; a migrate-only swap would change sale-entry behavior. |
| `BackupExportService.createBackup` | F | Full-fidelity snapshot serialization of all 11 product fields including timestamps; the backup artifact is format-sensitive and must not lose `notes`, prices, or timestamps. |
| `BackupRestoreService._checkEmptySystem` | F | Emptiness gate guarding the atomic multi-repository restore; coupled to the restore/wipe lifecycle, not a standalone display read. |
| `BusinessDataWipeService._currentCounts` | F | Pre-wipe count inside the destructive owner wipe flow; read and write share one workflow. |
| `NegativeBalanceApprovalWorkflowService._findProduct` | F | Approval revalidation uses `updatedAt` payload fingerprints (lines 266, 585–587) — `updatedAt` is not in the contract. Also runs inside a financial approval/posting workflow. |
| `DriftInventoryRepository._findProductById` | F | Single-lookup existence/activity checks inside the movement-transaction boundary; needs a single-item lookup, not an enumeration, and lives inside write integrity. |
| `ProfitabilityActivationService.activate` | F | Atomic valuation + audit activation must enumerate every existing product; coupled to the activation write. |
| `DriftPurchaseRepository._validateProduct` / `_validateProductExists` | F | Transaction-integrity validation for durable purchase mutation; inside the purchase write boundary. |
| `LocalSaleRepository._validateProduct` / `_validateAllMinimumPrices` | F | Sale validation needs `minimumSalePricePiastersPerKg` (not in the contract) and runs inside the sale + COGS + stock + account write boundary. |
| `_ProfitabilityReportScreenState._activate` | G | Owner-only financial activation read feeding the activation write; financially critical; higher risk than a display loader. |
| `LocalInventoryRepository` / `LocalPurchaseRepository` / `SyntheticProfitabilityActivationService` | H | Not production-reachable after `initializeProduction`; migrating them would be dead work with no runtime path to verify. |
| `_LegacyProductCatalogReadRepository` / `DriftProductRepository` | I | Infrastructure, not consumers; their lifecycle belongs to a legacy-retirement phase, not a consumer migration. |

No candidate was rejected with a vague rationale; each rejection names the
specific field gap, write/transaction coupling, criticality, or reachability
problem.

## Scope freeze (Phase 106R)

Allowed in Phase 106R:

- Inject `ProductCatalogReadRepository` into `InventoryController` and pass
  `AppRepositories.productCatalogReadRepository` at the three composition sites
  (`inventory_screen.dart:38`, `stock_take_screen.dart:41`,
  `stock_adjustment_report_screen.dart:39`).
- Replace the single legacy line in `load`
  (`inventory_controller.dart:53`) with
  `.listProductCatalog(includeInactive: user.permissions.canCreateStockAdjustment)`.
- Adapt the `products` projection and the three screens' dialog/local product
  types to the read model surface (`id`, `name`) with behavior identical to
  today.
- Update the 15 `InventoryController(` test construction sites to inject the
  catalog read adapter.

Forbidden in Phase 106R:

- No contract expansion, no `ProductCatalogReadModel` field addition, no schema
  or migration change, no `Drift` change.
- No change to `DriftInventoryRepository._findProductById`, purchase/sale/backup/
  wipe/approval/activation consumers, or any other F/G/C/H consumer.
- No fallback to legacy, no `ProductRepository` removal anywhere, no legacy
  dependency elimination outside the frozen files.
- No change to `isActive` filter semantics, ordering, permission policy, or
  product-name resolution.
- No other consumer migration in the same phase; no UI/behavior change.

## Files changed (Phase 106Q)

| File | Reason |
| --- | --- |
| `docs/PHASE-106Q-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md` | Governing report for this phase (discovery + re-audit + classification + freeze) |
| `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart` | New Phase 106Q freeze guard |
| `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart` | Minimal documented extension so the historical guard accepts exactly the single Phase 106Q commit (subject + parent = the 106P commit); it already recognized baseline, the 106O freeze, and the 106P migration. No historical assertion is weakened |

No production file under `lib/` is created or modified in Phase 106Q.

## Non-goals

Phase 106Q does not implement the migration, does not touch `lib/`, does not
modify the contract or adapter, does not open the user database, and does not
alter any existing test except the minimal 106O guard HEAD acceptance described
above. `InventoryController.load` remains on the legacy read path at the end of
Phase 106Q. The legacy `ProductRepository` surface remains the write-side and
validation-side repository for all F/C/G consumers.

## Verification evidence

| Gate | Result |
| --- | --- |
| `dart format` modified files | PASS |
| Phase 106Q freeze guard (`phase106q_next_product_read_migration_target_discovery_freeze_test.dart`) | PASS — 13/13 |
| Related guards 106K/106M/106N/106O/106P | PASS — 35/35 (5 + 6 + 6 + 8 + 10) |
| `flutter analyze` | No issues found |
| `flutter test` (full suite) | PASS — 0 failed, 1 historical skip preserved, no new skip |
| `flutter build windows --release` | PASS |
| EXE size / SHA-256 | recorded in final handoff |
| `git diff --check` | PASS — exit 0, no output |
| `git diff --stat` | 3 files: this report + the 106Q guard + the minimal 106O guard extension |
| `git diff -- lib` | EMPTY — no production diff |
| Commits after baseline | 1 |
| Worktree at end | Clean |
| No Push and no Tag are performed. | Confirmed |

The user database was not opened, read, copied, or modified.

## Final outcome

**Outcome A — FULL SUCCESS.** Phase 106Q re-audited the 17 remaining consumers
after Phase 106P, classified every one into exactly one A–I category, proved
production reachability through real composition paths, and froze exactly one
next migration target: `InventoryController.load` (Category B) in
`lib/core/inventory/inventory_controller.dart`, migrate-only, no contract
expansion, `includeInactive: user.permissions.canCreateStockAdjustment`,
requiring only `id` and `name` — both already present in the frozen
`ProductCatalogReadModel`. The next phase is **Phase 106R — Migrate
`InventoryController.load` to `ProductCatalogReadRepository`** (migration only).
