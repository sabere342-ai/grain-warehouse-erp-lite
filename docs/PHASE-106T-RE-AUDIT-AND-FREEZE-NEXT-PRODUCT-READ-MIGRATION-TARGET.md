# Phase 106T — Re-Audit and Freeze the Next Product Read Migration Target

## 14.1 Executive summary

| Item | Value |
| --- | --- |
| Outcome | **Outcome A — FULL SUCCESS** |
| Phase name | `PHASE 106T` |
| Baseline | `7300f5569f0617cf81606eddd062e73ec75c2de6` (`PHASE 106S: prove runtime inventory controller product catalog integration`) |
| Final HEAD | The single Phase 106T commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Commits after baseline | `1` |
| Worktree at start / end | Clean / Clean |
| Production diff under `lib/` | **None** — `git diff <baseline> -- lib` is empty |
| Consumer inventory | Total `24` = Migrated `8` + Remaining `16` |
| Selected target | **Contract expansion for `SaleController.load`**: add `defaultSalePricePiastersPerKg` (`int?`) and `minimumSalePricePiastersPerKg` (`int?`) to `ProductCatalogReadModel` |
| Classification of target | C — Requires a Broader Read Contract |
| Report | `docs/PHASE-106T-RE-AUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md` (this file) |
| Push / Tag | Not performed / not created |

Phase 106T is a discovery, audit, classification, selection, and freeze phase
only. No production consumer is migrated, the `ProductCatalogReadRepository`
contract is not expanded here, no schema or migration changes, and no fallback
is introduced. The single decision for the next phase (106U) is frozen below.

## 14.2 Baseline verification

| Check | Required | Actual |
| --- | --- | --- |
| `git rev-parse HEAD` | `7300f5569f0617cf81606eddd062e73ec75c2de6` | `7300f5569f0617cf81606eddd062e73ec75c2de6` — exact match |
| `git log -1 --oneline` | `7300f55 PHASE 106S: prove runtime inventory controller product catalog integration` | match |
| `git status --short` before start | clean | empty output — clean |
| Branch before start | Phase 106S branch | `codex/phase-106s-prove-runtime-inventory-controller-product-catalog-read-integration` |
| Branch created for this phase | `codex/phase-106t-reaudit-freeze-next-product-read-migration-target` | created |

No rebase, reset, or destructive git operation was used. The baseline and tree
state matched the required values, so the phase proceeded.

## 14.3 Search methodology

All searches below were executed against the current source at HEAD (the Phase
106S commit) plus the working tree. Historical reports (105A–105F, 106A–106S)
were treated as references to be re-verified, not as current truth.

Executable search patterns used:

| Pattern | Role |
| --- | --- |
| `listProducts(` | legacy read surface (dot form `.listProducts(` distinguishes call sites from declarations) |
| `ProductRepository`, `ProductDataRepository`, `LocalProductRepository`, `DriftProductRepository` | legacy contracts and implementations |
| `productRepository`, `_productRepository` | legacy dependency sites |
| `listProductCatalog(`, `ProductCatalogReadRepository`, `ProductCatalogReadModel`, `DriftProductCatalogReadRepository` | migrated boundary and consumers |
| `watchProducts`, `productById`, `getProduct`, `findProduct` | additional legacy read shapes (all confirmed absent as separate production reads) |
| `currentStockKg`, `hasOpeningBalance` | inventory read shapes used by validation paths |

Folders examined:

| Area | Notes |
| --- | --- |
| `lib/app/app_repositories.dart` | composition root; production swap of `_productCatalogReadRepository` to the Drift adapter in `initializeProduction` |
| `lib/core/catalog/` | contract, Drift adapter, legacy repository surface, `ProductController` |
| `lib/core/sales/` | `sale_controller.dart` (candidate), `sale_repository.dart` (`LocalSaleRepository` validation), `drift_sale_repository.dart` delegation |
| `lib/core/purchases/` | `drift_purchase_repository.dart`, `purchase_repository.dart` |
| `lib/core/inventory/` | `drift_inventory_repository.dart`, `inventory_repository.dart` |
| `lib/core/financial_accounts/` | `negative_balance_approval_workflow_service.dart` |
| `lib/core/inventory_valuation/` | `profitability_activation_service.dart`, `synthetic_profitability_activation_service.dart` |
| `lib/core/backup/` | `backup_export.dart`, `backup_restore_service.dart`, `business_data_wipe_service.dart` |
| `lib/features/sales/sales_screen.dart` | production wiring and field consumption of the candidate |
| `lib/features/products/products_screen.dart` | production wiring and field consumption of `ProductController` |
| `lib/features/financial_reports/profitability_report_screen.dart` | G-class consumer |
| `lib/features/dashboard/dashboard_shell.dart` | destination routing proving screen reachability |
| `lib/core/persistence/` | `schemaVersion` and schema stability |
| `test/` | freeze guards and consumer coverage |

### How production was separated from tests/docs

Classification of production consumers was based solely on the real execution
path inside `lib/`. `test/` matches were treated as fakes, seams, fixtures, or
guard assertions and were never counted as consumers. `docs/` matches were
treated as documentation. The only production-relevant searches used
`git grep ... -- lib`.

### How indirect consumers were discovered

Indirect consumers were found by following dependency injection across
composition boundaries: `AppRepositories` getters, constructor parameters typed
`ProductRepository` / `ProductDataRepository`, and delegation paths (for
example `DriftSaleRepository` delegates to `LocalSaleRepository`, which owns the
sale validation read at `lib/core/sales/sale_repository.dart:565`). A consumer
was counted only when its read path is reached from a real production entry
point. `AppRepositories.initializeProduction()` (invoked from `lib/main.dart:9`)
swaps the composition root to the Drift implementations; rows that are
superseded at initialization or never wired are classified H.

## 14.4 Reconciliation

| Number | Value |
| --- | --- |
| Total identified consumers | 24 |
| Migrated | 8 |
| Remaining | 16 |
| `Total = migrated + remaining` | `24 = 8 + 16` — exact match |

| Class | Count |
| --- | --- |
| C — Requires a Broader Read Contract | 2 |
| F — Write-Coupled / Transaction-Integrity Read | 8 |
| G — Financial / Inventory / Accounting Criticality | 1 |
| H — Not Production-Reachable | 3 |
| I — False Positive (Infrastructure) | 2 |
| Sum of categories | 16 |
| Remaining inventory | 16 |
| Migrated and accepted | 8 |
| Total identified | 24 |

### Variance vs Phase 106Q explained by name

Phase 106Q reported 17 remaining consumers. Phase 106T reports 16. The
difference is exactly one consumer:

| Consumer removed from remaining | Where it went |
| --- | --- |
| `InventoryController.load` (PRC-107) | Migrated in Phase 106R to `ProductCatalogReadRepository.listProductCatalog(...)`, `includeInactive: user.permissions.canCreateStockAdjustment`; its runtime integration was proven in Phase 106S. |

No consumer was added, deleted, de-duplicated, or reclassified. The current
source reproduces `24 total = 8 migrated + 16 remaining` with no variance. The
`I` infrastructure rows (`_LegacyProductCatalogReadRepository`,
`DriftProductRepository`) and the `H` rows (`LocalInventoryRepository`,
`LocalPurchaseRepository`, `SyntheticProfitabilityActivationService`) remain
documented but are never selected as migration targets.

## 14.5 Full consumer inventory

Inventory unit: one production-reachable method/state/workflow with a distinct
product-read behavior. Repository declarations, adapters, and application
composition are evidence but are not consumer rows. PRC-107 was migrated in
Phase 106R and is listed as migrated; remaining rows keep the Phase 106O
identifiers. `includeInactive` values verified against the current source at
HEAD.

| # | Consumer / file | Entry and reachability evidence | Repo type | Legacy method | Fields actually read | Filter / order / shape | Transaction / write | Class | Eligible with current contract | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-101 | `BackupExportService.createBackup` — `lib/core/backup/backup_export.dart:100–104` | backup-export screen; mandatory pre-wipe backup; `AppRepositories.backupExportService` | `ProductRepository` | `listProducts(includeInactive: true)` | all 11 fields: `id`, `name`, `code`, `unit.name`, `isActive`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `referenceCostPricePiastersPerKg`, `notes`, `createdAt`, `updatedAt` | inactive included; `createdAt,id`; full snapshot | backup/wipe lifecycle | F | no — needs 5 fields beyond contract | Critical |
| PRC-102 | `BackupRestoreService._checkEmptySystem` — `lib/core/backup/backup_restore_service.dart:230–232` | restore preview/execute via `restoreToEmpty` | `ProductDataRepository` | `listProducts(includeInactive: true)` | emptiness (`products.isNotEmpty`) | inactive included; order irrelevant | guards atomic multi-repository restore | F | no — restore-integrity gate | Critical |
| PRC-103 | `BusinessDataWipeService._currentCounts` — `lib/core/backup/business_data_wipe_service.dart:159–162` | owner destructive wipe | `ProductDataRepository` | `listProducts(includeInactive: true)` | count only (`products.length`) | inactive included; order irrelevant | destructive wipe flow | F | no — destructive-workflow coupling | Critical |
| PRC-104 | `ProductController.loadProducts` — `lib/core/catalog/product_controller.dart:19–29` | `DashboardShell` → `ProductsScreen` | `ProductRepository` | `listProducts(includeInactive: user.permissions.canManageProducts)` | `id`, `name`, `code`, `unit`, `isActive`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `referenceCostPricePiastersPerKg`, `notes` (display + edit form) | permission-shaped inactive; `createdAt,id`; no limit | loader is outside write transactions | C | no — needs broader management projection | High |
| PRC-105 | `NegativeBalanceApprovalWorkflowService._findProduct` / `_requireProduct` — `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart:745–769` | approval request, revalidation, and execution (paid purchase/sale) | `ProductRepository` | `listProducts(includeInactive: true)` | `id`, `isActive`, `updatedAt` (payload fingerprint, lines 266, 585–587) | inactive included; exact-ID scan; no paging | financial approval and posting | F | no — needs `updatedAt` | High |
| PRC-106 | `DriftInventoryRepository._findProductById` (via `currentStockKg`, `hasOpeningBalance`, `_validateDraftAndLoadProduct`) — `lib/core/inventory/drift_inventory_repository.dart:196–203` | `InventoryController` movement flows; purchase/sale stock checks | `ProductRepository` | `listProducts(includeInactive: true)` | `id`, `isActive` | inactive included; exact-ID scan | inside `createMovement` transaction boundary | F | no — transaction-integrity | Critical |
| PRC-108 | `ProfitabilityActivationService.activate` — `lib/core/inventory_valuation/profitability_activation_service.dart:48–64` | owner profitability activation (report screen button) | `ProductRepository` | `listProducts(includeInactive: true)` | `id` membership + count | inactive included; full list | atomic valuation + audit activation | F | no — activation safety | Critical |
| PRC-109 | `DriftPurchaseRepository._validateProduct` / `_validateProductExists` — `lib/core/purchases/drift_purchase_repository.dart:332–354` | `PurchaseController.createPurchaseIntake` / cancel → durable purchase mutation | `ProductRepository` | `listProducts(includeInactive: true)` | `id`, `isActive` | inactive included; exact-ID scan | purchase transaction boundary | F | no — transaction-integrity | High |
| PRC-111 | `LocalSaleRepository._validateProduct` / `_validateAllMinimumPrices` — `lib/core/sales/sale_repository.dart:555–581` (reached via `DriftSaleRepository` delegation, `lib/core/sales/drift_sale_repository.dart:27–32`) | `SalesScreen` → `SaleController.createSale` → `DriftSaleRepository` → delegate | `ProductRepository` | `listProducts(includeInactive: true)` | `id`, `isActive`, `minimumSalePricePiastersPerKg` | inactive included; exact-ID scan | sale + COGS + stock + account write | F | no — needs `minimumSalePricePiastersPerKg` | Critical |
| PRC-112 | `SaleController.load` — `lib/core/sales/sale_controller.dart:59–78` | `DashboardShell` → `SalesScreen` | `ProductRepository` | `listProducts(includeInactive: false)` (line 65) | `id`, `name`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg` | active only; `createdAt,id`; no limit | loader is outside write transactions | **C — selected (expansion)** | no — needs two sale-price fields | Medium |
| PRC-113 | `_ProfitabilityReportScreenState._activate` — `lib/features/financial_reports/profitability_report_screen.dart:139–141` | `FinancialReportsScreen` → `ProfitabilityReportScreen` → activation button | `ProductRepository` (`AppRepositories.productRepository`) | `listProducts(includeInactive: true)` | `id`, `name` (activation dialog) | inactive included; `createdAt,id`; per dialog | feeds financial activation write | G | no — financially critical owner-only write workflow | Critical |
| PRC-114 | `LocalInventoryRepository.allProductBalancesKg` / `_findProductById` — `lib/core/inventory/inventory_repository.dart:125–137,202–212` | superseded by `DriftInventoryRepository` during `initializeProduction`; test-only | `ProductRepository` | `listProducts(includeInactive: true)` | `id`, `isActive` | caller-shaped | test-only | H | n/a — not production-reachable | N/A |
| PRC-115 | `LocalPurchaseRepository._validateProduct` — `lib/core/purchases/purchase_repository.dart:416–438` | superseded by `DriftPurchaseRepository`; test-only | `ProductRepository` | `listProducts(includeInactive: true)` | `id`, `isActive` | inactive included; exact-ID scan | test-only | H | n/a — not production-reachable | N/A |
| PRC-116 | `SyntheticProfitabilityActivationService.activate` — `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart:84` | deliberately not wired into production; isolated Phase 102 tool | `ProductDataRepository` | `listProducts(includeInactive: true)` | emptiness | inactive included; order irrelevant | creates synthetic catalog/valuation | H | n/a — not production-reachable | N/A |
| PRC-117 | `_LegacyProductCatalogReadRepository.listProductCatalog` — `lib/app/app_repositories.dart:347–373` | composition-root default adapter; superseded at `initializeProduction` by `DriftProductCatalogReadRepository` (`lib/app/app_repositories.dart:135`) | `ProductRepository` | `listProducts(...)` (line 357) | adapts to `ProductCatalogReadModel` | contract order | none | I | n/a — infrastructure adapter, not a consumer | N/A |
| PRC-118 | `DriftProductRepository.listProducts` — `lib/core/catalog/drift_product_repository.dart:15–25` (+ internal snapshot `_DriftProductSnapshot.capture` at line 262–264) | legacy read surface definition | Drift / SQLite | `listProducts` | surface | n/a | none | I | n/a — infrastructure, not a consumer | N/A |

No consumer appears twice under different names. Direct reads and indirect
paths are separated per row. The not-production-reachable rows (H) and the
infrastructure rows (I) are documented but never selected as migration targets.

### Executable file-set evidence at HEAD

`git grep -l -F '.listProducts(' HEAD -- lib` (16 files) minus the two
infrastructure files (I) yields exactly the 14 remaining consumer files:

| Remaining legacy consumer file | PRC |
| --- | --- |
| `lib/core/backup/backup_export.dart` | PRC-101 |
| `lib/core/backup/backup_restore_service.dart` | PRC-102 |
| `lib/core/backup/business_data_wipe_service.dart` | PRC-103 |
| `lib/core/catalog/product_controller.dart` | PRC-104 |
| `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | PRC-105 |
| `lib/core/inventory/drift_inventory_repository.dart` | PRC-106 |
| `lib/core/inventory/inventory_repository.dart` | PRC-114 |
| `lib/core/inventory_valuation/profitability_activation_service.dart` | PRC-108 |
| `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | PRC-116 |
| `lib/core/purchases/drift_purchase_repository.dart` | PRC-109 |
| `lib/core/purchases/purchase_repository.dart` | PRC-115 |
| `lib/core/sales/sale_controller.dart` | PRC-112 |
| `lib/core/sales/sale_repository.dart` | PRC-111 |
| `lib/features/financial_reports/profitability_report_screen.dart` | PRC-113 |

`git grep -l -F '.listProductCatalog(' HEAD -- lib` (8 files) yields exactly
the 8 migrated consumer files:

| Migrated consumer file | Consumer |
| --- | --- |
| `lib/core/dashboard/dashboard_service.dart` | `DashboardService.load` |
| `lib/core/documents/document_history.dart` | `LocalDocumentHistoryRepository.listHistory` |
| `lib/core/inventory/drift_inventory_repository.dart` | `DriftInventoryRepository.allProductBalancesKg` |
| `lib/core/inventory/inventory_attention_service.dart` | `InventoryAttentionService.loadAttention` |
| `lib/core/inventory/inventory_controller.dart` | `InventoryController.load` |
| `lib/core/purchases/purchase_controller.dart` | `PurchaseController.load` |
| `lib/core/reports/report_repository.dart` | `LocalReportRepository` daily activity |
| `lib/features/dashboard/dashboard_screen.dart` | `DashboardGuidanceState.load` |

`lib/core/inventory/drift_inventory_repository.dart` appears in both sets
because it owns one migrated consumer (`allProductBalancesKg`) and one remaining
legacy consumer (`_findProductById`, PRC-106). This is not a duplicate row in
the consumer inventory — each PRC row maps to exactly one consumer workflow.

## 14.6 Migrated consumers

All eight migrated consumers are verified on the catalog boundary at HEAD and
are explicitly **not** re-selectable:

| Consumer | File | Catalog call | `includeInactive` |
| --- | --- | --- | --- |
| `LocalDocumentHistoryRepository.listHistory` | `lib/core/documents/document_history.dart:136` | `.listProductCatalog(` | name/type resolution context |
| `DashboardGuidanceState.load` | `lib/features/dashboard/dashboard_screen.dart:257` | `.listProductCatalog(includeInactive: true)` | `true` |
| `InventoryAttentionService.loadAttention` | `lib/core/inventory/inventory_attention_service.dart:42` | `.listProductCatalog(` | low-stock alert enumeration |
| `DashboardService.load` | `lib/core/dashboard/dashboard_service.dart:102` | `.listProductCatalog(` | dashboard aggregation |
| `LocalReportRepository` daily activity | `lib/core/reports/report_repository.dart:55` | `.listProductCatalog(` | daily activity report |
| `DriftInventoryRepository.allProductBalancesKg` | `lib/core/inventory/drift_inventory_repository.dart:108` | `.listProductCatalog(includeInactive: !activeProductsOnly)` | `!activeProductsOnly` |
| `PurchaseController.load` | `lib/core/purchases/purchase_controller.dart:45` | `.listProductCatalog(` | `user.permissions.canCreatePurchaseIntake` |
| `InventoryController.load` | `lib/core/inventory/inventory_controller.dart:53` | `.listProductCatalog(includeInactive: user.permissions.canCreateStockAdjustment)` | `user.permissions.canCreateStockAdjustment` |

Phase 106S proved the `InventoryController.load` runtime path end-to-end on
genuine SQLite with no legacy `listProducts` call — direct or indirect. No
regression has appeared since; this target is not reopened.

## 14.7 Remaining consumers

| Consumer | Location | Runtime path | Fields | Class | Risk | Reason not yet migrated |
| --- | --- | --- | --- | --- | --- | --- |
| `BackupExportService.createBackup` | `lib/core/backup/backup_export.dart:100–104` | backup-export screen → `createBackup` | 11 fields | F | Critical | Full-fidelity snapshot serialization; 5 fields (`defaultSalePrice`, `minimumSalePrice`, `notes`, `createdAt`, `updatedAt`) absent from the contract |
| `BackupRestoreService._checkEmptySystem` | `lib/core/backup/backup_restore_service.dart:230–232` | restore preview/execute → `_checkEmptySystem` | emptiness only | F | Critical | Read is inseparable from the atomic multi-repository restore gate |
| `BusinessDataWipeService._currentCounts` | `lib/core/backup/business_data_wipe_service.dart:159–162` | owner destructive wipe → `_currentCounts` | count only | F | Critical | Destructive wipe workflow coupling; read and write share one workflow |
| `ProductController.loadProducts` | `lib/core/catalog/product_controller.dart:19–29` | `DashboardShell` → `ProductsScreen` → `loadProducts` | 9 fields | C | High | Management projection needs `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, and `notes`; requires a broader projection contract |
| `NegativeBalanceApprovalWorkflowService._findProduct` | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart:762–769` | paid purchase/sale approval + revalidation → `_findProduct` | `id`, `isActive`, `updatedAt` | F | High | `updatedAt` payload fingerprint is absent from the contract; runs inside financial approval/posting |
| `DriftInventoryRepository._findProductById` | `lib/core/inventory/drift_inventory_repository.dart:196–203` | movement validation inside `createMovement` transaction → `_findProductById` | `id`, `isActive` | F | Critical | Single-ID lookup inside the movement transaction boundary; needs a lookup, not an enumeration |
| `ProfitabilityActivationService.activate` | `lib/core/inventory_valuation/profitability_activation_service.dart:48–64` | owner activation button → `activate` | `id` membership + count | F | Critical | Atomic valuation + audit activation must enumerate every existing product; coupled to the activation write |
| `DriftPurchaseRepository._validateProduct` / `_validateProductExists` | `lib/core/purchases/drift_purchase_repository.dart:332–354` | purchase intake/cancel → validation | `id`, `isActive` | F | High | Transaction-integrity validation inside the durable purchase write boundary |
| `LocalSaleRepository._validateProduct` / `_validateAllMinimumPrices` | `lib/core/sales/sale_repository.dart:555–581` | `createSale` → `DriftSaleRepository` → delegate | `id`, `isActive`, `minimumSalePricePiastersPerKg` | F | Critical | Needs `minimumSalePricePiastersPerKg` and runs inside the sale + COGS + stock + account write boundary |
| `SaleController.load` | `lib/core/sales/sale_controller.dart:59–78` | `DashboardShell` → `SalesScreen` → `load` | `id`, `name`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg` | C | Medium | Needs `defaultSalePricePiastersPerKg` and `minimumSalePricePiastersPerKg` to render the sale product cards; both fields absent from the current contract |
| `_ProfitabilityReportScreenState._activate` | `lib/features/financial_reports/profitability_report_screen.dart:139–141` | activation button → `_activate` | `id`, `name` | G | Critical | Owner-only financial activation read feeding a financially critical write workflow |
| `LocalInventoryRepository` | `lib/core/inventory/inventory_repository.dart:125–137,202–212` | superseded at `initializeProduction` | `id`, `isActive` | H | N/A | Not production-reachable after `initializeProduction`; test-only |
| `LocalPurchaseRepository._validateProduct` | `lib/core/purchases/purchase_repository.dart:416–438` | superseded at `initializeProduction` | `id`, `isActive` | H | N/A | Not production-reachable after `initializeProduction`; test-only |
| `SyntheticProfitabilityActivationService.activate` | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart:84` | never wired into production | emptiness | H | N/A | Deliberately isolated Phase 102 synthetic sandbox tool |
| `_LegacyProductCatalogReadRepository` | `lib/app/app_repositories.dart:347–373` | composition-root default; replaced by Drift adapter at `initializeProduction` | n/a | I | N/A | Infrastructure adapter, not a consumer |
| `DriftProductRepository.listProducts` | `lib/core/catalog/drift_product_repository.dart:15–25` | legacy read surface definition | n/a | I | N/A | Infrastructure, not a consumer |

## 14.8 Candidate comparison

After Phase 106S no remaining consumer is eligible for a migrate-only phase:
every A/B candidate was already migrated, and the remaining rows are either
contract-blocked (C), write/transaction-coupled (F), financially critical (G),
not production-reachable (H), or infrastructure (I).

The two C-class candidates are the only serious targets for a
contract-expansion phase:

| Criterion | `SaleController.load` (PRC-112) | `ProductController.loadProducts` (PRC-104) |
| --- | --- | --- |
| Contract fit | Needs `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg` — **2 fields** | Needs `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `notes` — **3 fields** |
| Runtime reachability | Proven — `DashboardShell` "Sales" destination → `SalesScreen` → `SaleController.load` | Proven — `DashboardShell` "Products" destination → `ProductsScreen` → `ProductController.loadProducts` |
| Read-only purity | `load` is outside write transactions; `createSale`/`cancelSale` do not read `_products` | `loadProducts` is outside write transactions but is re-invoked after each `createProduct`/`updateProduct`/`setProductActive` |
| Transaction coupling | None in `load` | None in `loadProducts` |
| Production diff size | Small — contract + adapter + `sale_controller.dart` + `sales_screen.dart` wiring and product-card types | Larger — contract + adapter + `product_controller.dart` + `products_screen.dart` wiring, list cards, and the edit-form seeding |
| `includeInactive` semantics | Fixed `false` (active only) — simplest to prove | Permission-derived `user.permissions.canManageProducts` |
| Testability | Atomic; 12 `SaleController(` test sites; single screen | Atomic; single `ProductController(` production site; existing product tests |
| Business risk | Sale card renders default/minimum price text; a read-model swap carrying identical column values cannot change behavior | Management display + edit-form seeding; more UI surface changes |
| Verification after migration | Independent runtime proof possible | Independent runtime proof possible |

**Decision:** `SaleController.load` — the smallest possible expansion (2 fields,
no `notes`), the clearest `includeInactive` semantics (fixed `false`), the
smallest production diff, and a pure display-loader with no write-transaction
coupling.

## 14.9 Selected target

```text
The single frozen target for Phase 106U is:
Extend ProductCatalogReadModel with
  defaultSalePricePiastersPerKg (int?)
  and minimumSalePricePiastersPerKg (int?)
for SaleController.load.
```

Why this is a contract-expansion target and not a migrate-only target: no
remaining consumer can be served by the current six-field contract. Both
C-class consumers need sale-price fields; `SaleController.load` needs exactly
the two smallest additions, which are also a strict subset of what
`ProductController.loadProducts` would need later. The expansion is a
prerequisite for the selected consumer's migration, so Phase 106U is a
**contract-expansion + single-consumer migration** phase for `SaleController.load`
only.

### Current execution path of the selected target

```text
DashboardShell destination "Sales"
→ SalesScreen.initState  (lib/features/sales/sales_screen.dart:36–56)
→ SaleController(
    saleRepository: AppRepositories.saleRepository,
    productRepository: AppRepositories.productRepository,   [sales_screen.dart:41–49]
    inventoryRepository: AppRepositories.inventoryRepository,
    ...)
→ SaleController.load (lib/core/sales/sale_controller.dart:59–78)
→ _productRepository.listProducts(includeInactive: false)  (sale_controller.dart:65)
→ ProductRepository (legacy product read contract)
→ AppRepositories.productRepository
→ DriftProductRepository (production) / LocalProductRepository (pre-initialization)
→ Drift / SQLite products table
```

### Data required by the selected target

The `_products` list consumed by `SalesScreen` uses only:

| Field | Evidence |
| --- | --- |
| `id` | `sales_screen.dart` lines 145, 372, 653, 656, 1255, 1342, 1348 |
| `name` | `sales_screen.dart` lines 184, 415, 1257; `sale_controller.dart` `productName` |
| `defaultSalePricePiastersPerKg` | `sales_screen.dart:400, 424–426` (sale card "default price") |
| `minimumSalePricePiastersPerKg` | `sales_screen.dart:401, 430–432` (sale card "minimum sale price") |

The local widget types that must adapt to `ProductCatalogReadModel` in the
migration phase: `_ProductSaleCard.product` (`sales_screen.dart:393`),
`_ProductSaleCards.products` / `onSelect` (`sales_screen.dart:328,330`),
`_SaleFormDialog.products` (`sales_screen.dart:616`), and
`_LineItemEntry` product list propagation (`sales_screen.dart:610,645`).

### `includeInactive` semantics

```text
includeInactive = false   (fixed, active products only)
```

The legacy call passes `false` literally. The required future call preserves
the exact value:

```dart
_productCatalogReadRepository.listProductCatalog(includeInactive: false)
```

This is the simplest possible semantics to prove — no permission expression.

### Ordering

Legacy `DriftProductRepository.listProducts` orders by `createdAt ASC, id ASC`
(`lib/core/catalog/drift_product_repository.dart:19–22`); the catalog adapter
orders identically (`drift_product_catalog_read_repository.dart:27–30`). No
ordering change occurs on migration.

## 14.10 Frozen migration contract (Phase 106U)

```text
Frozen next target:
SaleController.load

Current call:
ProductRepository.listProducts(includeInactive: false)          [sale_controller.dart:65]

Required future call:
ProductCatalogReadRepository.listProductCatalog(includeInactive: false)

Contract expansion (Phase 106U only):
ProductCatalogReadModel.defaultSalePricePiastersPerKg  — int?, nullable, piasters per kg
ProductCatalogReadModel.minimumSalePricePiastersPerKg  — int?, nullable, piasters per kg

Field source (already present in the schema — no migration):
products.defaultSalePricePiastersPerKg  (column exists)
products.minimumSalePricePiastersPerKg  (column exists)

Nullability and unit:
Both nullable int in piasters per kg, exactly like the frozen
referenceCostPricePiastersPerKg. A null value is preserved as null — never
coerced to zero.

Expected ordering:
createdAt ASC, id ASC (identical to today)

Runtime entry points:
DashboardShell "Sales" destination → SalesScreen.initState → SaleController.load

Screens affected:
lib/features/sales/sales_screen.dart

Repositories involved:
ProductCatalogReadRepository (new read dependency)
ProductRepository (kept only for the sale write-side validation in
LocalSaleRepository, which is NOT migrated in 106U)

Permitted production files for Phase 106U:
- lib/core/catalog/product_catalog_read_repository.dart   (add the 2 read-model fields)
- lib/core/catalog/drift_product_catalog_read_repository.dart (read the 2 columns)
- lib/core/sales/sale_controller.dart                     (swap the load read + type)
- lib/features/sales/sales_screen.dart                    (wire the catalog repository;
  adapt _ProductSaleCard/_ProductSaleCards/_SaleFormDialog/_LineItemEntry types)

Expected test files for Phase 106U:
- new migration guard for SaleController.load
- new runtime proof phase after the migration
- the 12 existing SaleController( construction sites updated to inject the
  catalog repository (sales_test, phase72, phase59, phase39 x3, phase35,
  phase32, phase21b, phase11, dc_u002_split_payments_ui, dc_u002_split_payments)

Expected wiring changes:
- sales_screen.dart:41–49 — pass productCatalogReadRepository:
  AppRepositories.productCatalogReadRepository instead of productRepository:
  AppRepositories.productRepository for the load read.

Prohibited changes (Phase 106U):
- No change to ProductRepository, ProductDataRepository, or their Drift/local implementations.
- No change to DriftProductCatalogReadRepository query semantics beyond the two added columns.
- No schema change, no migration, no schemaVersion bump.
- No change to LocalSaleRepository._validateProduct / _validateAllMinimumPrices (PRC-111, F).
- No other consumer migration (ProductController.loadProducts stays legacy).
- No fallback to the legacy listProducts anywhere.
- No cache, no single lookup, no stream added to the contract.
- No behavior change to sale entry, pricing, validation, or reporting.

Known risks:
- Medium: the sale card and sale dialog change their product widget types; the
  migration must keep rendering identical id/name/price text.
- Low: the contract grows by two nullable fields that other consumers (e.g.
  ProductController in a later phase) may reuse.

Required gates for Phase 106U:
- format, analyze, full flutter test, git diff --check, no production diff
  outside the five permitted files, clean tree, one commit.

Expected follow-up runtime proof phase:
- Phase 106W (or the immediately following runtime phase): genuine
  AppRepositories composition over SQLite proving SaleController.load executes
  listProductCatalog with zero legacy listProducts calls and null prices are
  preserved.
```

## 14.11 Non-goals

Phase 106T does not:

- migrate any consumer;
- modify `lib/` (any file under `lib/` is byte-identical to the 106S baseline);
- expand `ProductCatalogReadModel` or `ProductCatalogReadRepository`;
- modify `DriftProductCatalogReadRepository`;
- add any fallback, cache, stream, or lookup;
- touch the schema, migrations, or `schemaVersion`;
- alter permission behavior or UI;
- change any report format, ordering, or financial/valuation rule;
- delete, weaken, or skip any prior test;
- select a second target or combine the freeze with implementation;
- open, read, copy, or modify the user database.

## 14.12 Files changed

| Category | File |
| --- | --- |
| Tests | `test/phase106t_next_product_read_migration_target_freeze_test.dart` (new) |
| Freeze guards | `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart` (lineage extended for the single Phase 106T commit) |
| Freeze guards | `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart` (lineage extended for the single Phase 106T commit; commit-count bound raised from 3 to 4 after the 106P baseline) |
| Documentation | `docs/PHASE-106T-RE-AUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md` (this report) |
| Production | **none** — `git diff 7300f5569f0617cf81606eddd062e73ec75c2de6 -- lib` is empty |

The two guard extensions are the minimal lineage acceptance required for HEAD
to advance to the single Phase 106T commit while preserving every historical
guarantee. No historical report, classification, or consumer inventory was
rewritten.

## 14.13 Verification

| Gate | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | PASS |
| Phase 106T freeze test (run solo) | PASS |
| Phase 106O freeze guard (extended, run solo) | PASS |
| Phase 106Q freeze guard (extended, run solo) | PASS |
| Phase 106R migration guard (run solo) | PASS |
| Phase 106S runtime proof test (run solo) | PASS |
| `flutter analyze` | No issues found |
| `flutter test` (full suite) | PASS — 0 failed, 1 historical skip preserved |
| `git diff --check` | PASS — exit 0, no output |
| `git diff <baseline> -- lib` | EMPTY |
| `git status --short` after commit | clean |
| Commits after baseline | 1 |
| `flutter build windows --release` | PASS (environment permitting) |

## 14.14 Git evidence

| Item | Value |
| --- | --- |
| Baseline | `7300f5569f0617cf81606eddd062e73ec75c2de6` |
| Final HEAD | the single Phase 106T commit (`git log -1` at handoff) |
| Branch | `codex/phase-106t-reaudit-freeze-next-product-read-migration-target` |
| Commits after baseline | `1` |
| Commit subject | `PHASE 106T: freeze next product read migration target` |
| `git diff --stat` | 4 files (1 report, 1 new test, 2 guard extensions) |
| `git diff -- lib` | empty |
| Push | NO |
| Tag | NO |

## Final outcome

**Outcome A — FULL SUCCESS.** Phase 106T re-audited the 16 remaining product
read consumers after Phase 106S, classified every one into exactly one A–I
category, proved the candidate's production reachability through the genuine
`DashboardShell` → `SalesScreen` → `SaleController.load` path, and froze exactly
one next-phase decision: extend `ProductCatalogReadModel` with
`defaultSalePricePiastersPerKg` (`int?`) and `minimumSalePricePiastersPerKg`
(`int?`) so that `SaleController.load` can migrate to
`ProductCatalogReadRepository.listProductCatalog(includeInactive: false)`.
No production code changed, the contract was not expanded in this phase,
`schemaVersion` stays 15, and exactly one commit exists after the 106S baseline
with a clean worktree.

No Push was performed. No Tag was created.
