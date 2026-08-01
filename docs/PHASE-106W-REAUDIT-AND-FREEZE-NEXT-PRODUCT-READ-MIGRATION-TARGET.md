# Phase 106W — Re-audit and Freeze the Next Product Read Migration Target

## 1. Title and objective

Phase 106W re-audits every product-catalog read inventory unit reachable from
`lib/` after the accepted Phase 106V runtime proof. It selects and freezes one
next production migration target. It does not execute a production migration,
expand a read contract, change repository behavior, or modify `lib/`.

Final result: **Outcome A — FULL SUCCESS**.

## 2. Complete starting point

| Evidence | Value |
| --- | --- |
| Repository | `C:\dev\multi-pos\grain-warehouse-erp-lite` |
| Starting branch | `codex/phase-106v-prove-runtime-sale-controller-product-catalog-integration` |
| Phase branch | `codex/phase-106w-reaudit-freeze-next-product-read-migration-target` |
| Starting HEAD | `2b90ca07a38c6890260d3c2df991d8b42fb5a200` |
| Starting log | `2b90ca0 PHASE 106V: prove runtime sale controller product catalog integration` |
| Baseline ancestry | `2b90ca0` is `HEAD` itself and therefore its own complete descendant |

## 3. Tree state before execution

`git status --short` returned no output. The worktree started clean. No user
change was removed, hidden, or overwritten.

## 4. Search methodology

The audit used the current source as authority and the Phase 106Q and Phase
106T reports only as stable-ID/history references. It performed four passes:

1. direct legacy calls and declarations;
2. catalog-boundary calls, injection, and composition;
3. repository aliases, helpers, indirect lookup paths, and runtime wiring;
4. post-return field usage in controllers, screens, services, serialization,
   validation, and transaction workflows.

An inventory unit is a distinct method/state/workflow or a deliberately
tracked shared-infrastructure surface. Multiple calls inside one workflow are
one unit. PRC-117 and PRC-118 remain counted for exact continuity with 106Q and
106T, but they are explicitly infrastructure, not selectable product workflows.

## 5. Principal search commands

```text
rg -n --glob 'lib/**' "listProducts\s*\(|ProductRepository|listProductCatalog\s*\(|ProductCatalogReadRepository"
rg -n -C 2 --glob 'lib/**' "\.listProductCatalog\("
rg -n --glob 'lib/**' "ProductController|ProductDataRepository|productRepository"
rg -n --glob 'docs/**' --glob 'test/**' "PRC-[0-9]+|Phase 106Q|Phase 106T"
git diff 2b90ca07a38c6890260d3c2df991d8b42fb5a200 -- lib
```

The audit also read the complete relevant method bodies, the current contract,
the Drift adapter, the `Products` schema, `Product`, production composition,
and the widgets that consume controller results.

## 6. Current contract, in full

`ProductCatalogReadRepository.listProductCatalog({required bool includeInactive})`
returns `Future<List<ProductCatalogReadModel>>`. The model has exactly these
eight fields at the baseline:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `String` | stable read identifier |
| `name` | `String` | product display name |
| `code` | `String?` | optional product code; not defined as a barcode |
| `unit` | `GrainUnit` | product grain unit |
| `isActive` | `bool` | active status |
| `referenceCostPricePiastersPerKg` | `int?` | optional reference cost, piasters/kg |
| `defaultSalePricePiastersPerKg` | `int?` | optional default sale price, piasters/kg |
| `minimumSalePricePiastersPerKg` | `int?` | optional minimum sale price, piasters/kg |

Frozen semantics verified in the Drift adapter:

- `includeInactive: false` applies `isActive == true`.
- `includeInactive: true` returns active and inactive rows.
- ordering is `createdAt ASC`, then `id ASC`;
- nullable monetary values remain `null`;
- integer piaster/kg values pass without rounding or conversion;
- reads perform no write or mutation.

## 7. All migrated and accepted consumers

These nine units are on the catalog boundary and cannot be reselected:

| Consumer | File and current call line | Current call | `includeInactive` | Decision |
| --- | --- | --- | --- | --- |
| `LocalDocumentHistoryRepository._productNamesById` | `lib/core/documents/document_history.dart:136` | direct `.listProductCatalog` | `true` | migrated/accepted |
| `DashboardGuidanceState.load` | `lib/features/dashboard/dashboard_screen.dart:257` | direct `.listProductCatalog` | `true` | migrated/accepted |
| `InventoryAttentionService.loadAttention` | `lib/core/inventory/inventory_attention_service.dart:42` | direct `.listProductCatalog` | `true` | migrated/accepted |
| `DashboardService.load` | `lib/core/dashboard/dashboard_service.dart:102` | direct `.listProductCatalog` | `true` | migrated/accepted |
| `LocalReportRepository.dailyActivityReport` | `lib/core/reports/report_repository.dart:55` | direct `.listProductCatalog` | `true` | migrated/accepted |
| `DriftInventoryRepository.allProductBalancesKg` | `lib/core/inventory/drift_inventory_repository.dart:108` | direct `.listProductCatalog` | `!activeProductsOnly` | migrated/accepted |
| `PurchaseController.load` | `lib/core/purchases/purchase_controller.dart:45` | direct `.listProductCatalog` | `user.permissions.canCreatePurchaseIntake` | migrated/accepted |
| `InventoryController.load` | `lib/core/inventory/inventory_controller.dart:53` | direct `.listProductCatalog` | `user.permissions.canCreateStockAdjustment` | migrated/accepted |
| `SaleController.load` | `lib/core/sales/sale_controller.dart:65` | direct `.listProductCatalog` | `false` | migrated/accepted and runtime-proved in 106V |

## 8. Full remaining inventory

Each row occurs once and has exactly one current A-I classification.

| ID | Consumer | File and lines | Current call | Runtime reachability | Required fields | includeInactive semantics | Category | Migration risk | Decision |
| -- | -- | -- | -- | -- | -- | -- | -- | -- | -- |
| PRC-101 | `BackupExportService.createBackup` | `lib/core/backup/backup_export.dart:100-104` | direct `listProducts(includeInactive: true)` at 102 | production backup export and mandatory pre-wipe backup | all 11 `Product` fields: `id`, `name`, `code`, `unit`, `isActive`, three price fields, `notes`, `createdAt`, `updatedAt` | all rows; ordered snapshot | D | Critical | reject: full-fidelity backup shape is broader and high-risk |
| PRC-102 | `BackupRestoreService._checkEmptySystem` | `lib/core/backup/backup_restore_service.dart:230-232` | direct `listProducts(includeInactive: true)` at 232 | production restore preview/execution | emptiness only | all rows; order irrelevant | E | Critical | reject: restore transaction/integrity gate |
| PRC-103 | `BusinessDataWipeService._currentCounts` | `lib/core/backup/business_data_wipe_service.dart:159-162` | direct `listProducts(includeInactive: true)` at 160 | owner data wipe | count only | all rows; order irrelevant | E | Critical | reject: destructive workflow coupling |
| PRC-104 | `ProductController.loadProducts` | `lib/core/catalog/product_controller.dart:19-29`; call at 24 | direct `listProducts(includeInactive: user.permissions.canManageProducts)` | `ProductsScreen.initState` lines 29-38 creates controller at 32-33 and calls loader at 37 | `id`, `name`, `code`, `unit`, `isActive`, three price fields, `notes` | permission-shaped; managers see all, others active only; `createdAt,id` | C | Medium | **selected: smallest contract expansion (`String? notes`)** |
| PRC-105 | `NegativeBalanceApprovalWorkflowService._findProduct` / `_requireProduct` | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart:745-769`; call at 765 | direct `listProducts(includeInactive: true)` | paid purchase/sale approval, revalidation, posting | `id`, `isActive`, `updatedAt` | all rows; exact-ID scan | E | High | reject: financial workflow and fingerprint coupling |
| PRC-106 | `DriftInventoryRepository._findProductById` | `lib/core/inventory/drift_inventory_repository.dart:196-203`; call at 198 | direct `listProducts(includeInactive: true)` | production stock checks and movement validation | `id`, `isActive` | all rows; exact-ID scan | E | Critical | reject: lookup inside movement transaction boundary |
| PRC-108 | `ProfitabilityActivationService.activate` | `lib/core/inventory_valuation/profitability_activation_service.dart:32-64`; call at 49 | direct `listProducts(includeInactive: true)` | owner profitability activation | `id`, membership, count | all rows | E | Critical | reject: atomic valuation/audit write coupling |
| PRC-109 | `DriftPurchaseRepository._validateProduct` / `_validateProductExists` | `lib/core/purchases/drift_purchase_repository.dart:332-354`; calls at 334,350 | two direct calls within one durable purchase workflow | production intake and cancellation | `id`, `isActive` | all rows; exact-ID scans | E | High | reject: transaction-integrity validation |
| PRC-111 | `LocalSaleRepository._validateProduct` / `_validateAllMinimumPrices` | `lib/core/sales/sale_repository.dart:555-581`; call at 565; indirect production reach through `DriftSaleRepository` delegation | direct call in shared delegate | production sale, COGS, stock, accounts | `id`, `isActive`, `minimumSalePricePiastersPerKg` | all rows; exact-ID scan | E | Critical | reject: sale transaction/write coupling |
| PRC-113 | `_ProfitabilityReportScreenState._activate` | `lib/features/financial_reports/profitability_report_screen.dart:139-160`; call at 141 | direct `AppRepositories.productRepository.listProducts(includeInactive: true)` | production owner activation button | `id`, `name` | all rows for activation dialog | E | Critical | reject: catalog read feeds financial activation write |
| PRC-114 | `LocalInventoryRepository.allProductBalancesKg` / `_findProductById` | `lib/core/inventory/inventory_repository.dart:125-137,202-212`; calls at 128,204 | two direct calls in one local implementation | replaced by Drift at `initializeProduction`; test-only | `id`, `isActive` | caller-shaped/all rows | I | N/A | exclude from selection: not production-reachable |
| PRC-115 | `LocalPurchaseRepository._validateProduct` | `lib/core/purchases/purchase_repository.dart:416-438`; call at 426 | direct `listProducts(includeInactive: true)` | replaced by Drift at `initializeProduction`; test-only | `id`, `isActive` | all rows; exact-ID scan | I | N/A | exclude from selection: not production-reachable |
| PRC-116 | `SyntheticProfitabilityActivationService.activate` | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart:48-87`; call at 84 | direct `listProducts(includeInactive: true)` | deliberately unwired synthetic tool | emptiness | all rows; order irrelevant | I | N/A | exclude from selection: not production-reachable |
| PRC-117 | `_LegacyProductCatalogReadRepository.listProductCatalog` | `lib/app/app_repositories.dart:347-377`; legacy call at 357 | indirect wrapper/adaptation call | pre-production/default composition; replaced by Drift adapter at production initialization | all eight catalog fields | forwards caller flag | H | N/A | infrastructure continuity row; not a consumer target |
| PRC-118 | `DriftProductRepository.listProducts` and `_DriftProductSnapshot.capture` | `lib/core/catalog/drift_product_repository.dart:16-25,258-264`; internal call at 263 | legacy read surface and shared snapshot infrastructure | production repository implementation/snapshot support | full `Product` | caller flag/default true | H | N/A | shared infrastructure; not a consumer target |

## 9. Mathematical reconciliation

| Measure | Count |
| --- | ---: |
| Total identified inventory units | 24 |
| Migrated and accepted | 9 |
| Remaining classified units | 15 |
| Legacy direct call sites | 17 |
| Catalog direct call sites | 9 |

The governing equation is `24 = 9 + 15`.

The 17 legacy direct call sites reconcile to 15 remaining units because
PRC-109 and PRC-114 each contain two calls inside one distinct workflow/unit.
The nine catalog calls map one-to-one to the nine migrated units. PRC-117
captures the indirect legacy wrapper explicitly. No consumer is missing, no
unit is duplicated across classifications, and no hidden alias creates an
additional catalog enumeration.

## 10. Comparison with Phase 106Q and Phase 106T

| Audit | Total | Migrated | Remaining | Explanation |
| --- | ---: | ---: | ---: | --- |
| Phase 106Q | 24 | 7 | 17 | `PurchaseController.load` accepted; `InventoryController.load` frozen next |
| Phase 106T | 24 | 8 | 16 | inventory controller accepted; `SaleController.load` frozen next |
| Phase 106W | 24 | 9 | 15 | sale controller migrated in 106U and runtime-proved in 106V |

The total stays 24 because the current source adds no new unique unit and
removes none. Exactly one previously remaining unit moved to migrated status
after 106T. Stable PRC identifiers are unchanged.

## 11. A-I classification summary

The counts below cover the 15 remaining rows exactly:

| Category | Count |
| --- | ---: |
| A | 0 |
| B | 0 |
| C | 1 |
| D | 1 |
| E | 8 |
| F | 0 |
| G | 0 |
| H | 2 |
| I | 3 |

Check: `0 + 0 + 1 + 1 + 8 + 0 + 0 + 2 + 3 = 15`.

## 12. The single selected target

FROZEN_TARGET_ID: PRC-104

FROZEN_TARGET_CONSUMER: ProductController.loadProducts

FROZEN_TARGET_CATEGORY: C

FROZEN_TARGET_FILE: lib/core/catalog/product_controller.dart

FROZEN_TARGET_MEMBER: loadProducts(AppUser user)

No A or B candidate remains. PRC-104 is the smallest C candidate: all data it
uses after loading is already present in the eight-field read model except one
nullable text field, `notes`.

## 13. Why PRC-104 was selected

- It is production-reachable from `ProductsScreen.initState`.
- Its catalog enumeration is outside a repository transaction.
- It preserves a simple permission-shaped inactive filter.
- Its one missing field already exists in the schema and domain model.
- The addition is non-financial, non-quantitative, and nullable.
- It advances the application boundary while keeping product mutation on
  `ProductRepository`.
- Its behavior can be proved through controller and genuine SQLite runtime
  tests.

## 14. Why the nearest alternatives were not selected

1. PRC-113 already needs only `id` and `name`, but the read is embedded in the
   owner-only profitability activation flow and feeds a financially sensitive
   write. It is Category E, not A.
2. PRC-105 needs `updatedAt` and participates in financial approval,
   revalidation, and posting. It is Category E and materially riskier.
3. PRC-101 also needs `notes`, but additionally requires `createdAt` and
   `updatedAt` and exact full-snapshot fidelity for backup/restore. It is
   Category D and broader than PRC-104.

## 15. Current file, lines, and call

Current production path:

```text
DashboardShell -> ProductsScreen
ProductsScreen.initState                    [products_screen.dart:29-38]
ProductController(repository: AppRepositories.productRepository)
ProductController.loadProducts              [product_controller.dart:19-29]
_repository.listProducts(                   [product_controller.dart:24-26]
  includeInactive: user.permissions.canManageProducts,
)
```

Current legacy call:

```dart
ProductRepository.listProducts(
  includeInactive: user.permissions.canManageProducts,
)
```

## 16. Required future call

The next phase must replace only PRC-104's catalog read with:

```dart
ProductCatalogReadRepository.listProductCatalog(
  includeInactive: user.permissions.canManageProducts,
)
```

`ProductRepository` remains the write dependency for `createProduct`,
`updateProduct`, and `setProductActive`. The read contract must never be used
for those mutations.

## 17. Frozen `includeInactive` semantics

The expression is not simplified or replaced:

```text
includeInactive: user.permissions.canManageProducts
```

- product managers receive active and inactive products;
- other users receive active products only;
- result ordering stays `createdAt ASC`, then `id ASC`.

## 18. Complete required field set

PRC-104 consumes `id`, `name`, `code`, `unit`, `isActive`,
`referenceCostPricePiastersPerKg`, `defaultSalePricePiastersPerKg`,
`minimumSalePricePiastersPerKg`, and `notes` through `ProductsScreen` display,
toggle, and edit-form initialization. The first eight exist today.

The only future contract addition is:

| Field | Type | Schema source | Nullability/unit semantics |
| --- | --- | --- | --- |
| `notes` | `String?` | `Products.notes` / `products.notes`, Drift nullable text column at `foundation_database.dart:27` | nullable text; null remains null; no unit |

No trimming, defaulting, or normalization is permitted. The adapter passes the
stored string through exactly; `null` remains `null`.

## 19. Frozen scope of the next phase

The next phase is a minimal contract-expansion plus migration of one consumer only:
PRC-104 `ProductController.loadProducts`.

ProductRepository remains the write dependency; the catalog contract is only
the read dependency.

It must:

1. add only `String? notes` to `ProductCatalogReadModel`;
2. map only `products.notes` in both catalog adapters;
3. inject `ProductCatalogReadRepository` into `ProductController` for reads;
4. retain `ProductRepository` for writes;
5. adapt `ProductsScreen` read-side types without changing visible behavior;
6. add contract, controller, and genuine runtime tests.

No other PRC row may migrate in that phase.

## 20. Provisional next-phase production-file allowlist

- `lib/app/app_repositories.dart`
- `lib/core/catalog/drift_product_catalog_read_repository.dart`
- `lib/core/catalog/product_catalog_read_repository.dart`
- `lib/core/catalog/product_controller.dart`
- `lib/features/products/products_screen.dart`

Test files specific to the next phase may also change. If implementation
evidence proves a production file outside this list is unavoidable, the next
phase must stop and re-audit instead of silently broadening scope.

## 21. Explicit prohibitions

- Do not migrate PRC-104 during Phase 106W.
- Do not expand ProductCatalogReadModel during Phase 106W.
- No other consumer migration; No other PRC row may migrate.
- No unrelated refactor or behavior change.
- No schema change or schemaVersion bump.
- No change to `ProductRepository`, `ProductDataRepository`, or their methods.
- No change to Drift query filtering or ordering.
- No conversion of `null`, no string normalization, and no fallback read.
- No use of the read contract for create/update/activate/deactivate operations.
- No reintroduction of `ProductRepository.listProducts` into any of the nine
  migrated/accepted paths.
- No Push and no Tag.

## 22. Risks

- Medium: `ProductController` owns read state and write operations; dependencies
  must be separated without routing writes through the read contract.
- Medium: `ProductsScreen` currently types cards/forms as `Product`; read-side
  type adaptation must preserve edit prefill and all displayed values.
- Low: `notes` is nullable and must not be coerced to an empty string by the
  repository boundary.
- Low: permission-shaped `includeInactive` must remain byte-for-byte equivalent
  in meaning.

## 23. Phase 106W files

Phase 106W introduces the report and freeze test and minimally extends four
historical lineage guards that otherwise rejected the already accepted 106V
baseline:

- `docs/PHASE-106W-REAUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md`
- `test/phase106w_next_product_read_migration_target_freeze_test.dart`
- `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart`
- `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart`
- `test/phase106t_next_product_read_migration_target_freeze_test.dart`
- `test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart`

No production file was changed in Phase 106W.

## 24. Tests and verification

The required verification set is:

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | PASS |
| `flutter analyze` | PASS |
| `flutter test` | PASS |
| `flutter test test/phase106w_next_product_read_migration_target_freeze_test.dart` | PASS |
| available nearby Phase 105F/106O/106Q/106S/106T/106V tests | PASS |
| `git diff --check` | PASS |
| `git diff 2b90ca07a38c6890260d3c2df991d8b42fb5a200 -- lib` | PASS, empty |

## 25. Analyzer and formatting status

`flutter analyze` completes without issues. The repository-wide format check
completes without changes. `git diff --check` succeeds.

## 26. Final tree and Git state

The phase is prepared as exactly one child commit of the baseline with subject:

```text
PHASE 106W: freeze next product read migration target
```

The commit contains only the report, the new freeze test, and the four minimal
historical-lineage guard updates. The resulting hash is recorded in the
executive handoff because a commit cannot contain its own hash.
Post-commit checks must show a clean worktree, commit count `1`, and an empty
`git diff 2b90ca07a38c6890260d3c2df991d8b42fb5a200 -- lib`.

No Push was performed. No Tag was created.

## 27. Final outcome

**Outcome A — FULL SUCCESS**

The current source proves 24 stable inventory units, exactly nine migrated and
15 remaining. Every remaining row is classified once. The unique next target
is frozen as PRC-104 `ProductController.loadProducts`, Category C, requiring
only `String? notes` to be added in the next phase. Phase 106W itself performs
no contract expansion, migration, or production change.
