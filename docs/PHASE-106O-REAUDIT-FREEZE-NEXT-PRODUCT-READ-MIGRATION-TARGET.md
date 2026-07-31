# Phase 106O — Re-Audit and Freeze the Next Product Read Migration Target

## Executive outcome

**Outcome A — FULL SUCCESS**

Phase 106O re-audits every remaining production product-read consumer after
Phase 106N, classifies all 18 remaining consumers into exactly one category
(A–I), and freezes a single next migration target without implementing it. The
selected target is `PurchaseController.load` in
`lib/core/purchases/purchase_controller.dart`: a read-only, current-contract
eligible, standalone product enumeration that is exercised by two production
screens and needs only `id`, `name`, and `isActive` — every required field is
already present in the frozen `ProductCatalogReadModel`. No contract expansion,
schema change, repository change, or consumer migration happens in this phase.

Phase 106O changes only this report and its discovery/freeze guard. There is no
production diff under `lib/` and the frozen migration is not implemented in this
phase.

## Governing references

| Item | Value |
| --- | --- |
| Phase branch | `codex/phase-106o-reaudit-freeze-next-product-read-migration-target` |
| Governing baseline | `39744e6b2d1581293da9f79bd3b8af79ee897f5c` |
| Baseline subject | `PHASE 106N: prove runtime daily activity product read integration` |
| Previous branch | `codex/phase-106n-prove-runtime-daily-activity-product-read-after-inventory-migration` |
| Initial worktree | Clean |
| Initial commits after baseline | `0` |
| Initial `git diff --check` | PASS — exit 0, no output |
| Phase 106I report | `docs/PHASE-106I-DISCOVER-FREEZE-NEXT-PRODUCT-READ-CONTRACT-EXPANSION.md` |
| Phase 106I guard | `test/phase106i_next_product_read_contract_expansion_discovery_freeze_test.dart` |
| Phase 106M report | `docs/PHASE-106M-MIGRATE-INVENTORY-PRODUCT-BALANCE-ENUMERATION-READ.md` |
| Phase 106N report | `docs/PHASE-106N-PROVE-RUNTIME-DAILY-ACTIVITY-PRODUCT-READ-AFTER-INVENTORY-MIGRATION.md` |
| Phase 106N guard | `test/phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart` |

## Current contract snapshot

The accepted production boundary remains:

```text
ProductCatalogReadRepository.listProductCatalog
→ DriftProductCatalogReadRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

The current, unmodified read model is:

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

The Phase 106I inventory and the Phase 106N proof were treated as historical
references, not as current truth. The following executable searches were
repeated against the current source at HEAD `39744e6`:

- `listProducts`, `getProduct`, `findProduct`, `watchProducts`, `streamProducts`
- `ProductRepository`, `ProductDataRepository`, `DriftProductRepository`
- `productRepository` (composition/DI field names and `AppRepositories` getters)
- `currentStockKg`, `hasOpeningBalance`, `_validateProduct`, `_findProduct`
- `ProductCatalogReadRepository`, `listProductCatalog`, `ProductCatalogReadModel`

Every match was opened and traced through its constructor, entry point,
downstream field use, write boundary, transaction membership, and production
composition. Reachability was proven through real execution paths only: screen
→ controller → service → repository → `AppRepositories` → Drift → SQLite.
Class existence alone was not accepted as proof.

### Folders and files examined

| Area | Notes |
| --- | --- |
| `lib/app/app_repositories.dart` | composition root; legacy wrapper and Drift swap |
| `lib/core/catalog/` | contract, Drift adapter, legacy repository, controller, model |
| `lib/core/inventory/` | drift + local inventory repositories, controller |
| `lib/core/sales/` | sale repositories, sale controller |
| `lib/core/purchases/` | purchase repositories, purchase controller |
| `lib/core/backup/` | backup export, restore, preview, wipe |
| `lib/core/financial_accounts/` | negative-balance approval workflow |
| `lib/core/inventory_valuation/` | profitability activation + synthetic service |
| `lib/features/dashboard/` | `dashboard_shell.dart` destination map |
| `lib/features/products/` | products screen |
| `lib/features/inventory/` | inventory, stock-take, adjustment-report screens |
| `lib/features/purchases/` | purchases, supplier-purchases screens |
| `lib/features/sales/` | sales screen |
| `lib/features/financial_reports/` | financial reports + profitability report screens |
| `test/` | freeze guards and controller coverage files |

## Full consumer inventory

Inventory unit: one production-reachable method/state/workflow with a distinct
product-read behavior. Repository declarations, adapters, and application
composition are evidence but are not consumer rows. Classification uses the
Phase 106O A–I scheme:

- A — Read-only, current-contract fit, standalone read (lowest risk)
- B — Current-contract fit (broader context, still eligible)
- C — Requires a broader read contract
- D — Requires a single-item lookup
- E — Requires a stream / reactive read
- F — Write-coupled / transaction-integrity read
- G — Financial / inventory / accounting criticality
- H — Not production-reachable
- I — False positive (infrastructure, not a consumer)

| ID | Consumer / file | Entry and reachability evidence | Repo type | Legacy method | Direct | Fields actually read | Filter / order / shape | Transaction / write | Class | Eligible with current contract | Covering tests | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-101 | `BackupExportService.createBackup` — `lib/core/backup/backup_export.dart` | backup-export screen; mandatory pre-wipe backup; `AppRepositories.backupExportService` | `ProductRepository` | `listProducts(includeInactive: true)` (line 102) | yes | all 11 fields: `id`, `name`, `code`, `unit.name`, `isActive`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `referenceCostPricePiastersPerKg`, `notes`, `createdAt`, `updatedAt` | inactive included; `createdAt,id`; full snapshot | backup/wipe lifecycle | F | no — needs 5 fields beyond contract | `phase13_backup_export_test.dart`, `phase14_backup_file_save_test.dart`, `phase16_restore_empty_system_test.dart`, `phase17_owner_data_wipe_test.dart` | Critical |
| PRC-102 | `BackupRestoreService._checkEmptySystem` — `lib/core/backup/backup_restore_service.dart` | restore preview/execute via `restoreToEmpty` | `ProductDataRepository` | `listProducts(includeInactive: true)` (line 232) | yes | emptiness (`products.isNotEmpty`, line 258) | inactive included; order irrelevant | guards atomic multi-repository restore | F | no — restore-integrity gate | `phase15_restore_preview_test.dart`, `phase16_restore_empty_system_test.dart` | Critical |
| PRC-103 | `BusinessDataWipeService._currentCounts` — `lib/core/backup/business_data_wipe_service.dart` | owner destructive wipe | `ProductDataRepository` | `listProducts(includeInactive: true)` (line 160) | yes | count only (`products.length`, line 176) | inactive included; order irrelevant | destructive wipe flow | F | no — destructive-workflow coupling | `phase17_owner_data_wipe_test.dart`, `owner_wipe_snapshot_coverage_test.dart` | Critical |
| PRC-104 | `ProductController.loadProducts` — `lib/core/catalog/product_controller.dart` | `DashboardShell` → `ProductsScreen` (line 43) | `ProductRepository` | `listProducts(includeInactive: user.permissions.canManageProducts)` (line 24) | yes | `id`, `name`, `code`, `unit`, `isActive`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `referenceCostPricePiastersPerKg`, `notes` (display + edit form) | permission-shaped inactive; `createdAt,id`; no limit | loader is outside write transactions | C | no — needs broader management projection | `product_catalog_test.dart`, `phase8b_durable_product_repository_test.dart`, `phase21b_pricing_cost_minimum_ui_acceptance_test.dart` | High |
| PRC-105 | `NegativeBalanceApprovalWorkflowService._findProduct` / `_requireProduct` — `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | approval request, revalidation, and execution (paid purchase/sale) | `ProductRepository` | `listProducts(includeInactive: true)` (line 765) | yes | `id`, `isActive`, `updatedAt` (payload fingerprint, lines 266/587) | inactive included; exact-ID scan; no paging | financial approval and posting | F | no — needs `updatedAt` | `phase82_negative_balance_approval_workflow_test.dart`, `phase82_approval_requests_widget_test.dart`, `paid_purchase_ui_completion_test.dart` | High |
| PRC-106 | `DriftInventoryRepository._findProductById` (via `currentStockKg`, `hasOpeningBalance`, `_validateDraftAndLoadProduct`) — `lib/core/inventory/drift_inventory_repository.dart` | `InventoryController` movement flows; purchase/sale stock checks | `ProductRepository` | `listProducts(includeInactive: true)` (lines 196–198) | yes | `id`, `isActive` | inactive included; exact-ID scan | inside `createMovement` transaction (line 25) | F | no — transaction-integrity | `phase8e_durable_inventory_repository_test.dart`, `inventory_test.dart`, `phase49a_stock_take_test.dart`, `phase49b_stock_adjustment_report_test.dart` | Critical |
| PRC-107 | `InventoryController.load` — `lib/core/inventory/inventory_controller.dart` | `DashboardShell` → `InventoryScreen` (45) / `StockTakeScreen` (87) / `StockAdjustmentReportScreen` (93) | `ProductRepository` | `listProducts(includeInactive: user.permissions.canCreateStockAdjustment)` (line 53) | yes | `id`, `name` | permission-shaped inactive; `createdAt,id`; no limit | no | B | yes — `id`, `name` | `inventory_test.dart`, `phase49a_stock_take_test.dart`, `phase49b_stock_adjustment_report_test.dart`, `phase51_real_business_day_simulation_test.dart`, `phase52_accounting_freeze_audit_test.dart`, `phase53_cloud_migration_readiness_test.dart`, `phase102b_transaction_integration_test.dart`, `phase102c_activation_readiness_verification_test.dart` | Low |
| PRC-108 | `ProfitabilityActivationService.activate` — `lib/core/inventory_valuation/profitability_activation_service.dart` | owner profitability activation (report screen button) | `ProductRepository` | `listProducts(includeInactive: true)` | yes | `id` membership | inactive included; full list | atomic valuation + audit activation | F | no — activation safety | `phase102b_profitability_activation_service_test.dart`, `phase102b_transaction_integration_test.dart`, `phase102c_activation_readiness_verification_test.dart` | Critical |
| PRC-109 | `DriftPurchaseRepository._validateProduct` / `_validateProductExists` — `lib/core/purchases/drift_purchase_repository.dart` | `PurchaseController.createPurchaseIntake` / cancel → durable purchase mutation | `ProductRepository` | `listProducts(includeInactive: true)` (lines 332–339, 349–354) | yes | `id`, `isActive` | inactive included; exact-ID scan | purchase transaction boundary | F | no — transaction-integrity | `phase8f_durable_purchase_repository_test.dart`, `supplier_purchase_test.dart`, `supplier_purchase_atomicity_test.dart` | High |
| PRC-110 | `PurchaseController.load` — `lib/core/purchases/purchase_controller.dart` | `DashboardShell` → `PurchasesScreen` (44); suppliers → `SupplierPurchasesScreen` | `ProductRepository` | `listProducts(includeInactive: user.permissions.canCreatePurchaseIntake)` (line 45) | yes | `id`, `name`, `isActive` | permission-shaped inactive; `createdAt,id`; no limit | no | **A — selected** | **yes** — `id`, `name`, `isActive` | `supplier_purchase_test.dart`, `paid_purchase_ui_completion_test.dart`, `phase21b_pricing_cost_minimum_ui_acceptance_test.dart`, `phase36g_ui_clarity_cancellation_safety_test.dart`, `phase51_real_business_day_simulation_test.dart`, `phase52_accounting_freeze_audit_test.dart`, `phase53_cloud_migration_readiness_test.dart` | Low |
| PRC-111 | `LocalSaleRepository._validateProduct` / `_validateAllMinimumPrices` — `lib/core/sales/sale_repository.dart` (reached via `DriftSaleRepository` delegation, lines 27–30) | `SalesScreen` → `SaleController.createSale` → `DriftSaleRepository` → delegate | `ProductRepository` | `listProducts(includeInactive: true)` (lines 555–565) | yes | `id`, `isActive`, `minimumSalePricePiastersPerKg` (lines 530–538) | inactive included; exact-ID scan | sale + COGS + stock + account write | F | no — needs `minimumSalePricePiastersPerKg` | `phase8g_durable_sale_repository_test.dart`, `sales_test.dart`, `phase21b_pricing_cost_minimum_ui_acceptance_test.dart`, `phase59_sale_cancellation_customer_ledger_symmetry_test.dart`, `phase72_transaction_integration_test.dart` | Critical |
| PRC-112 | `SaleController.load` — `lib/core/sales/sale_controller.dart` | `DashboardShell` → `SalesScreen` (41) | `ProductRepository` | `listProducts(includeInactive: false)` (line 65) | yes | `id`, `name`, `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg` | active only; `createdAt,id`; no limit | loader is outside write transactions | C | no — needs two sale-price fields | `sales_test.dart`, `phase21b_pricing_cost_minimum_ui_acceptance_test.dart`, `phase39_customer_bound_multi_item_sales_test.dart`, `phase59_sale_cancellation_customer_ledger_symmetry_test.dart`, `dc_u002_split_payments_test.dart` | Medium |
| PRC-113 | `_ProfitabilityReportScreenState._activate` — `lib/features/financial_reports/profitability_report_screen.dart` | `FinancialReportsScreen` (line 49) → `ProfitabilityReportScreen` → activation button | `ProductRepository` (`AppRepositories.productRepository`) | `listProducts(includeInactive: true)` (lines 140–141) | yes | `id`, `name` (activation dialog, lines 344–476) | inactive included; `createdAt,id`; per dialog | feeds financial activation write | G | no — financially critical owner-only write workflow | `phase21c_profit_stock_valuation_reports_test.dart`, `phase102b_profitability_report_test.dart`, `phase102c_activation_readiness_verification_test.dart` | Critical |
| PRC-114 | `LocalInventoryRepository.allProductBalancesKg` / `_findProductById` — `lib/core/inventory/inventory_repository.dart` | superseded by `DriftInventoryRepository` during `initializeProduction`; test-only | `ProductRepository` | `listProducts(includeInactive: true)` | yes | `id`, `isActive` | caller-shaped | test-only | H | n/a — not production-reachable | `phase8e_durable_inventory_repository_test.dart`, `inventory_test.dart` | N/A |
| PRC-115 | `LocalPurchaseRepository._validateProduct` — `lib/core/purchases/purchase_repository.dart` | superseded by `DriftPurchaseRepository`; test-only | `ProductRepository` | `listProducts(includeInactive: true)` | yes | `id`, `isActive` | inactive included; exact-ID scan | test-only | H | n/a — not production-reachable | `phase8f_durable_purchase_repository_test.dart`, `supplier_purchase_test.dart` | N/A |
| PRC-116 | `SyntheticProfitabilityActivationService.activate` — `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | deliberately not wired into production (file doc lines 15–16); isolated Phase 102 tool | `ProductDataRepository` | `listProducts(includeInactive: true)` | yes | emptiness | inactive included; order irrelevant | creates synthetic catalog/valuation | H | n/a — not production-reachable | `phase102j_synthetic_profitability_activation_test.dart` | N/A |
| PRC-117 | `_LegacyProductCatalogReadRepository.listProductCatalog` — `lib/app/app_repositories.dart` | composition-root adapter; default before `initializeProduction` swaps to Drift | `ProductRepository` | `listProducts(...)` (lines 347–362) | indirect (wrapper) | adapts to `ProductCatalogReadModel` | contract order | none | I | n/a — infrastructure adapter, not a consumer | n/a | N/A |
| PRC-118 | `DriftProductRepository.listProducts` — `lib/core/catalog/drift_product_repository.dart` | legacy read surface definition | Drift / SQLite | `listProducts` | n/a | surface | n/a | none | I | n/a — infrastructure, not a consumer | `phase8b_durable_product_repository_test.dart` | N/A |

The current executable search yields 18 remaining consumers after excluding the
two infrastructure files (I) and the three not-production-reachable rows (H),
plus the six already-migrated consumers. The inventory therefore remains 24
identified consumers total, and each remaining row has exactly one A–I class.

## Classification totals

- A — Read-Only, Current-Contract Fit, Standalone: 1
- B — Current-Contract Fit (broader context): 1
- C — Requires a Broader Read Contract: 2
- D — Requires a Single-Item Lookup: 0
- E — Requires a Stream / Reactive Read: 0
- F — Write-Coupled / Transaction-Integrity Read: 8
- G — Financial / Inventory / Accounting Criticality: 1
- H — Not Production-Reachable: 3
- I — False Positive (Infrastructure): 2
- Remaining inventory: 18
- Migrated and accepted: 6
- Total identified: 24

## Migrated consumers (accepted, do not re-select)

| Consumer | Entry | Guard / proof |
| --- | --- | --- |
| `LocalDocumentHistoryRepository._productNamesById` | document-history screen | `test/phase106d_next_product_read_consumer_target_discovery_freeze_test.dart` |
| `DashboardGuidanceState.load` | protected dashboard lifecycle (`dashboard_screen.dart:257`, `.listProductCatalog(includeInactive: true)`) | `test/phase106b_dashboard_guidance_product_catalog_read_migration_test.dart` |
| `InventoryAttentionService.loadAttention` | dashboard / owner-alert services | `test/phase106e_inventory_attention_product_catalog_read_migration_test.dart` |
| `DashboardService.load` | `DashboardScreen` → `DashboardController.load` | `test/phase106g_genuine_runtime_dashboard_service_product_catalog_read_integration_test.dart`, `test/phase106h_dashboard_service_product_catalog_read_migration_acceptance_freeze_test.dart` |
| Product read inside `LocalReportRepository.dailyActivityReport` | `ReportsScreen` → `ReportController.loadDailyActivity` | `test/phase106k_daily_activity_product_read_contract_migration_test.dart`, `test/phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart` |
| Product balance enumeration inside `DriftInventoryRepository.allProductBalancesKg` | inventory / stock / valuation balance reads | `test/phase106m_drift_inventory_product_balance_enumeration_read_contract_migration_test.dart` |

## Production execution paths

The selected target is reached exclusively through real production composition:

```text
DashboardShell destination "Purchases" (line 44)
→ PurchasesScreen.initState (lines 62–67)
→ PurchaseController(purchaseRepository, supplierRepository, productRepository:
    AppRepositories.productRepository)   [lib/features/purchases/purchases_screen.dart]
→ PurchaseController.load (lib/core/purchases/purchase_controller.dart:36–51)
→ _productRepository.listProducts(includeInactive: user.permissions.canCreatePurchaseIntake)  (line 45)
→ DriftProductRepository.listProducts → Drift / SQLite products table
```

```text
Suppliers screen → SupplierPurchasesScreen.initState (lines 39–43)
→ PurchaseController(purchaseRepository, supplierRepository, productRepository:
    AppRepositories.productRepository)   [lib/features/purchases/supplier_purchases_screen.dart]
→ PurchaseController.load → legacy listProducts (line 45)
→ DriftProductRepository.listProducts → Drift / SQLite products table
```

The loaded `_products` list is consumed by:

- `purchases_screen.dart:226–228` — dropdown candidates filtered by `product.isActive`;
- `purchases_screen.dart:536–539` — dropdown values `product.id`, labels `product.name`;
- `purchases_screen.dart:484` — default selection `widget.products.first.id`;
- `purchase_controller.dart:120–121` — `productName(productId)` resolves intake row
  names from `_products` (used by `supplier_purchases_screen.dart:155, 203–204`).

No write path in `PurchaseController` reads `_products` for validation; purchase
posting writes go to `DriftPurchaseRepository`, which has its own separate
transaction-integrity product validation (PRC-109). The product read is,
therefore, a standalone display/enumeration read.

## Field analysis

For the selected target, the exact fields consumed are:

| Field | Consumer of the field | In frozen contract |
| --- | --- | --- |
| `product.id` | dropdown value (`purchases_screen.dart:538`); default selection (`:484`); `productName` scan (`purchase_controller.dart:120–121`) | yes |
| `product.name` | dropdown label (`purchases_screen.dart:539`); intake row name resolution | yes |
| `product.isActive` | dropdown candidate filter (`purchases_screen.dart:226–227`) | yes |

Fields present in the contract but not consumed by the target: `code`, `unit`,
`referenceCostPricePiastersPerKg` — a superset that cannot regress the target.

## Contract fit analysis

The frozen operation `listProductCatalog({required bool includeInactive})`
provides every field the target consumes. The `includeInactive` policy
(`user.permissions.canCreatePurchaseIntake`) maps 1:1 onto the operation's
parameter. The adapter's `createdAt ASC, id ASC` ordering matches the legacy
`DriftProductRepository.listProducts` ordering, so the purchases dropdown and
`productName` resolution preserve their current behavior. No new field, no
single-lookup operation, no stream, no schema change, and no write capability is
needed. The current contract is a strict superset of the target's needs.

## Ranking matrix (current-contract-eligible candidates)

| Rank | Candidate | Class | Evidence of fit | Rejected because |
| --- | --- | --- | --- | --- |
| 1 | `PurchaseController.load` | A | read-only; `id`, `name`, `isActive`; two production screens; no transaction/write coupling; smallest consumer surface | — selected |
| 2 | `InventoryController.load` | B | read-only; `id`, `name`; three production screens | same controller also drives financially sensitive inventory/valuation mutation flows; balance reads already migrated; strictly larger blast radius than the selected target |

No other remaining consumer fits the current contract. All F rows require either
a single-item lookup or live inside write/transaction boundaries; C rows need
fields absent from the contract; G is financially critical; H rows are not
production-reachable; I rows are infrastructure.

## Selected expansion

Selected migration target: PurchaseController.load

```text
File:          lib/core/purchases/purchase_controller.dart
Class:         PurchaseController
Method:        load (lines 36–51)
Legacy read:   _productRepository.listProducts(
                 includeInactive: user.permissions.canCreatePurchaseIntake)  (line 45)
Frozen read:   _productCatalogReadRepository.listProductCatalog(
                 includeInactive: user.permissions.canCreatePurchaseIntake)
Classification: A — read-only, current-contract fit, standalone
Required fields: id, name, isActive — all already frozen
Contract delta: none (strict superset today)
Risk: Low
```

Selection rationale (highest-priority justification wins):

1. Production-reachable through two independent real screens (Purchases and
   Supplier Purchases), each composing `AppRepositories` at runtime.
2. Read-only standalone enumeration; no transaction membership; no write
   coupling; the controller's own posting writes validate separately in
   `DriftPurchaseRepository` and do not read `_products`.
3. Current-contract eligible — `id`, `name`, `isActive` only; no contract
   expansion, no single-lookup op, no stream, no schema change.
4. Smallest diff: one constructor parameter + one replacement line in `load`
   plus the two screen composition sites and the `products` getter projection.
5. Existing coverage (`supplier_purchase_test.dart`,
   `paid_purchase_ui_completion_test.dart`, `phase21b`, `phase36g`,
   `phase51/52/53`) exercises the two screens and the controller end to end,
   so the later atomic migration is verifiable without new UI tests.
6. No ordering, filtering, permission, or naming semantics change: adapter
   ordering (`createdAt ASC, id ASC`) equals the legacy ordering.

## Rejected candidates

| Candidate | Category now | Rejection reason |
| --- | --- | --- |
| `InventoryController.load` | B | Eligible, but the controller also owns inventory/valuation mutation flows and the balances already migrated; larger blast radius than `PurchaseController.load`. Not selected only because the other A/B candidate is strictly smaller and equally production-proven. |
| `ProductController.loadProducts` | C | Product management projection needs `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `notes` (plus the contract fields). Would require a broad management projection. |
| `SaleController.load` | C | Sale-entry UI needs `defaultSalePricePiastersPerKg` and `minimumSalePricePiastersPerKg` (sales_screen.dart:400–401). Not in contract. |
| `BackupExportService.createBackup` | F | Full-fidelity snapshot serialization of all 11 product fields incl. timestamps; format-sensitive backup artifact. |
| `BackupRestoreService._checkEmptySystem` | F | Emptiness gate guarding atomic multi-repository restore. |
| `BusinessDataWipeService._currentCounts` | F | Pre-wipe count in a destructive workflow. |
| `NegativeBalanceApprovalWorkflowService._findProduct` / `_requireProduct` | F | Approval revalidation uses `updatedAt` payload fingerprints (lines 266, 587) — not in contract. |
| `DriftInventoryRepository._findProductById` | F | Single-lookup existence/activity checks inside movement transactions. |
| `ProfitabilityActivationService.activate` | F | Atomic valuation + audit activation must enumerate every existing product. |
| `DriftPurchaseRepository._validateProduct` / `_validateProductExists` | F | Transaction-integrity validation for durable purchase mutation. |
| `LocalSaleRepository._validateProduct` / `_validateAllMinimumPrices` | F | Sale validation needs `minimumSalePricePiastersPerKg` (lines 530–538). |
| `_ProfitabilityReportScreenState._activate` | G | Owner-only financial activation read feeding the activation write. |
| `LocalInventoryRepository` / `LocalPurchaseRepository` / `SyntheticProfitabilityActivationService` | H | Not production-reachable after `initializeProduction`. |
| `_LegacyProductCatalogReadRepository` / `DriftProductRepository` | I | Infrastructure, not consumers. |

## Frozen target contract

```text
Boundary:   ProductCatalogReadRepository
Operation:  listProductCatalog({required bool includeInactive})
Read model: ProductCatalogReadModel
Required fields: id, name, isActive
No lookup, no stream, no transaction, no write, no fallback, no cache
```

The next phase is a **migrate-only** phase (no contract expansion):

- **Phase 106P — Migrate `PurchaseController.load` to `ProductCatalogReadRepository`.**

Allowed in Phase 106P:

- Inject `ProductCatalogReadRepository` into `PurchaseController` and pass
  `AppRepositories.productCatalogReadRepository` at the two composition sites
  (`purchases_screen.dart:62–67`, `supplier_purchases_screen.dart:39–43`).
- Replace the single legacy line in `load`
  (`purchase_controller.dart:45`) with
  `.listProductCatalog(includeInactive: user.permissions.canCreatePurchaseIntake)`.
- Adapt the `products` projection / the two screen references to the read model
  surface (`id`, `name`, `isActive`) with behavior identical to today.
- Extend the two screens' controller construction only; no other consumer may be
  touched in the same phase.

Forbidden in Phase 106P:

- No contract expansion, no `ProductCatalogReadModel` field addition, no schema
  or migration change, no `Drift` change.
- No change to `DriftPurchaseRepository`, `LocalPurchaseRepository`,
  `LocalSaleRepository`, sale/backup/wipe/approval/activation consumers.
- No fallback to legacy, no `ProductRepository` removal anywhere, no legacy
  dependency elimination outside the frozen file.
- No change to `isActive` filter semantics, ordering, permission policy, or
  `productName` behavior.
- No other consumer migration in the same phase; no UI/behavior change.

## Non-goals

Phase 106O does not implement the migration, does not touch `lib/`, does not
modify the contract or adapter, does not open the user database, and does not
alter any existing test. `SyntheticProfitabilityActivationService` remains a
deliberately isolated, non-production tool. The legacy `ProductRepository`
surface remains the write-side and validation-side repository for all F/C/G
consumers.

## Atomic follow-up plan

1. `git checkout -b codex/phase-106p-migrate-purchase-controller-product-read`
   from this phase's commit.
2. Inject `ProductCatalogReadRepository` into `PurchaseController` and its two
   composition sites.
3. Swap `load` to `listProductCatalog`; map `id` / `name` / `isActive`.
4. Add an integration guard mirroring
   `phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart`
   proving the runtime purchase flow reads through the catalog boundary.
5. Run the same quality gates as this phase; verify `git diff -- lib` is limited
   to the three files above plus the new test.

## Verification evidence

| Gate | Result |
| --- | --- |
| `dart format` new files | PASS |
| Phase 106O freeze guard (`phase106o_next_product_read_migration_target_discovery_freeze_test.dart`) | PASS — N/N |
| Related product-read contract guards (106K/106M/106N) | PASS — 11/11 |
| `flutter analyze` | No issues found |
| `flutter test` (full suite) | PASS — 2084 passed, 0 failed, 1 historical skip, plus N new Phase 106O tests |
| `flutter build windows --release` | PASS |
| `git diff --check` | PASS — exit 0, no output |
| `git diff --stat` | 2 files: this report + the Phase 106O guard |
| `git diff -- lib` | EMPTY — no production diff |
| Files changed vs baseline | 2 (report + guard only) |
| Commits after baseline | 1 |
| Worktree at end | Clean |
| No Push and no Tag are performed. | Confirmed |

The user database was not opened, read, copied, or modified.

## Final outcome

**Outcome A — FULL SUCCESS.** Phase 106O re-audited 18 remaining consumers,
classified every one into exactly one A–I category, proved production
reachability through real composition paths, and froze exactly one next
migration target: `PurchaseController.load` (Category A), migrate-only, no
contract expansion, to be executed in Phase 106P.
