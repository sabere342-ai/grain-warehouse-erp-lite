# Phase 106Y — Re-audit and Freeze the Next Product Read Migration Target

## 1. Objective and outcome

Phase 106Y independently re-audits every product-read inventory unit reachable
from the current `lib/` tree after Phase 106X, reconciles the legacy and catalog
surfaces, classifies every remaining unit, and freezes exactly one next
migration target. It does not migrate that target, expand the read contract,
change a schema, or modify any production file.

Final result: **Outcome A — FULL SUCCESS**.

## 2. Git baseline

| Evidence | Value |
| --- | --- |
| Required branch | `codex/phase-106y-reaudit-freeze-next-product-read-migration-target` |
| Starting HEAD | `30021696ab2667340e032832892d3c2ecc5dadd7` |
| Starting log | `3002169 PHASE 106X: extend product catalog notes and migrate product controller` |
| Initial `git status --short` | empty |
| Baseline validity | exact required commit |
| Baseline tree | clean |

No history repair, merge, reset, Push, or Tag was performed.

## 3. Counting rule and discovery method

An inventory unit is one distinct production method, state object, workflow, or
deliberately tracked shared-infrastructure surface that enumerates product
data. Repeated calls inside the same logical workflow do not create additional
units. Tests, constructors, dependency wiring, re-exports, and transparent
adapters do not create a second consumer, although indirect and test-only
paths are recorded and reconciled.

The current code, rather than an earlier report, was the authority. The audit
used complementary passes over:

1. all `.listProducts(` and `.listProductCatalog(` calls in `lib/`;
2. `ProductRepository`, `ProductDataRepository`,
   `ProductCatalogReadRepository`, and `ProductCatalogReadModel` dependencies;
3. controllers, services, repositories, screens, dialogs, reports, backup,
   restore, wipe, snapshot, and transaction paths;
4. runtime composition in `AppRepositories.initializeProduction`;
5. field use after each returned list, including indirect delegation;
6. tests and Phase 105/106 guards as corroborating evidence only.

Principal reproducible searches:

```text
rg -n --glob '*.dart' "\.listProducts\(" lib
rg -n --glob '*.dart' "\.listProductCatalog\(" lib
rg -n --glob '*.dart' "ProductRepository|ProductDataRepository|ProductCatalogReadRepository|ProductCatalogReadModel" lib test
rg -n "ProfitabilityReportScreen|profitabilityActivationService" lib
git diff 30021696ab2667340e032832892d3c2ecc5dadd7 -- lib
```

## 4. Current catalog read contract

`ProductCatalogReadRepository.listProductCatalog({required bool
includeInactive})` returns `Future<List<ProductCatalogReadModel>>`. The current
model has exactly nine fields:

| Field | Type | Frozen meaning |
| --- | --- | --- |
| `id` | `String` | stable product identifier |
| `name` | `String` | stored display name |
| `code` | `String?` | optional code; not defined as a barcode |
| `unit` | `GrainUnit` | stored grain unit |
| `isActive` | `bool` | active status |
| `referenceCostPricePiastersPerKg` | `int?` | optional reference cost in piasters/kg |
| `defaultSalePricePiastersPerKg` | `int?` | optional default sale price in piasters/kg |
| `minimumSalePricePiastersPerKg` | `int?` | optional minimum sale price in piasters/kg |
| `notes` | `String?` | nullable stored notes, passed through verbatim |

`DriftProductCatalogReadRepository` proves the current semantics:

- `includeInactive: false` applies `isActive == true`;
- `includeInactive: true` returns active and inactive rows;
- ordering is `createdAt ASC`, then `id ASC`;
- all nullable values, including `notes`, remain nullable;
- no trimming, fallback, normalization, monetary conversion, or unit
  conversion beyond `GrainUnit.fromWireName` occurs;
- the projection is one query, performs no write, and creates no N+1 query.

Phase 106Y does not change this contract or its adapter.

## 5. Migrated and accepted inventory

The following ten logical units currently call `listProductCatalog` and are
not eligible for reselection:

| Consumer | Current file and call | `includeInactive` | Status |
| --- | --- | --- | --- |
| `LocalDocumentHistoryRepository._productNamesById` | `lib/core/documents/document_history.dart:136` | `true` | migrated |
| `DashboardGuidanceState.load` | `lib/features/dashboard/dashboard_screen.dart:257` | `true` | migrated |
| `InventoryAttentionService.loadAttention` | `lib/core/inventory/inventory_attention_service.dart:42` | `true` | migrated |
| `DashboardService.load` | `lib/core/dashboard/dashboard_service.dart:102` | `true` | migrated |
| `LocalReportRepository.dailyActivityReport` | `lib/core/reports/report_repository.dart:55` | `true` | migrated |
| `DriftInventoryRepository.allProductBalancesKg` | `lib/core/inventory/drift_inventory_repository.dart:105-116`, call at 108 | `!activeProductsOnly` | migrated |
| `PurchaseController.load` | `lib/core/purchases/purchase_controller.dart:45` | `user.permissions.canCreatePurchaseIntake` | migrated |
| `InventoryController.load` | `lib/core/inventory/inventory_controller.dart:53` | `user.permissions.canCreateStockAdjustment` | migrated |
| `SaleController.load` | `lib/core/sales/sale_controller.dart:65` | `false` | migrated and runtime-proved |
| `ProductController.loadProducts` | `lib/core/catalog/product_controller.dart:24-32`, call at 30 | `user.permissions.canManageProducts` | migrated in 106X |

The Phase 106X unit still reads through
`_productCatalogReadRepository.listProductCatalog`, while
`createProduct`, `updateProduct`, and `setProductActive` still use
`ProductRepository`. Its `notes` value remains nullable and verbatim.

## 6. Complete remaining inventory and classification

The supplied A-I definitions were reapplied to current behavior. In
particular, non-production local/synthetic implementations are H, internal
adapter/snapshot surfaces are G, and the full-fidelity backup export is I
rather than a catalog-contract expansion candidate. That is a definition
correction supported by the current code, not a change in the underlying
consumer or its historical risk.

| ID | Consumer | File and method | Current dependency/read | Required data | Class | Reason | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-101 | Backup export product snapshot | `lib/core/backup/backup_export.dart:100-104`, `BackupExportService.createBackup` | `ProductRepository.listProducts(true)` | all 11 `Product` fields, including `createdAt` and `updatedAt` | I | full-fidelity archival/restore shape is a separate architectural boundary; the catalog projection must not manufacture `Product` objects or grow persistence timestamps for backup | Critical |
| PRC-102 | Restore empty-system gate | `lib/core/backup/backup_restore_service.dart:230-274`, `_checkEmptySystem` | `ProductRepository.listProducts(true)` | emptiness only | E | read is embedded in restore validation and coordinated restore writes | Critical |
| PRC-103 | Owner wipe counts | `lib/core/backup/business_data_wipe_service.dart:159-185`, `_currentCounts` | `ProductRepository.listProducts(true)` | count only | E | read is part of the destructive backup-before-wipe workflow | Critical |
| PRC-105 | Negative-balance product lookup | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart:745-769`, `_requireProduct` / `_findProduct` | `ProductRepository.listProducts(true)` | `id`, `isActive`, and downstream `updatedAt` fingerprint | E | financially sensitive approval, revalidation, and posting workflow | High |
| PRC-106 | Durable inventory product validation | `lib/core/inventory/drift_inventory_repository.dart:196-203`, `_findProductById` | `ProductRepository.listProducts(true)` | `id`, `isActive` | E | validation is coupled to durable stock movement writes | Critical |
| PRC-108 | Production profitability activation validation | `lib/core/inventory_valuation/profitability_activation_service.dart:32-110`, `activate` | `ProductRepository.listProducts(true)` | `id`, membership, count, deterministic iteration | E | read validates and orders an atomic valuation/audit write | Critical |
| PRC-109 | Durable purchase product validation | `lib/core/purchases/drift_purchase_repository.dart:332-354`, `_validateProduct` / `_validateProductExists` | two `ProductRepository.listProducts(true)` calls | `id`, `isActive` | E | durable intake/cancellation transaction-integrity path | High |
| PRC-111 | Shared sale product/minimum validation | `lib/core/sales/sale_repository.dart:555-581`, `_validateProduct` and downstream validation | `ProductRepository.listProducts(true)` | `id`, `isActive`, `minimumSalePricePiastersPerKg` | E | sale, inventory, COGS, account, and minimum-price write coupling | Critical |
| PRC-113 | Profitability activation dialog enumeration | `lib/features/financial_reports/profitability_report_screen.dart:139-170`, `_ProfitabilityReportScreenState._activate` | `AppRepositories.productRepository.listProducts(true)` | `id`, `name` | E | one method combines dialog read preparation with the later activation command; the read slice is locally separable | Medium |
| PRC-114 | Local inventory implementation | `lib/core/inventory/inventory_repository.dart:125-137,202-212`, `allProductBalancesKg` / `_findProductById` | two `ProductRepository.listProducts` calls | `id`, `isActive` | H | replaced by Drift during production initialization; retained for tests/local fixtures | N/A |
| PRC-115 | Local purchase validation | `lib/core/purchases/purchase_repository.dart:416-438`, `_validateProduct` | `ProductRepository.listProducts(true)` | `id`, `isActive` | H | replaced by Drift during production initialization; retained for tests/local fixtures | N/A |
| PRC-116 | Synthetic activation empty-sandbox guard | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart:48-90`, `activate` | `ProductRepository.listProducts(true)` | emptiness only | H | deliberately unwired synthetic/test tool | N/A |
| PRC-117 | Legacy catalog adapter | `lib/app/app_repositories.dart:347-379`, `_LegacyProductCatalogReadRepository.listProductCatalog` | indirect `ProductRepository.listProducts` adaptation | all nine catalog fields | G | compatibility adapter, replaced by the Drift catalog adapter in production | N/A |
| PRC-118 | Product repository list/snapshot infrastructure | `lib/core/catalog/drift_product_repository.dart:16-25,256-272`, `listProducts` / `_DriftProductSnapshot.capture` | repository-internal legacy surface; snapshot calls `listProducts()` | full `Product` | G | repository and rollback infrastructure, not an application consumer | N/A |

No remaining unit is unclassified.

## 7. Reconciliation

| Measure | Count |
| --- | ---: |
| Total identified logical units | 24 |
| Migrated and accepted units | 10 |
| Remaining classified units | 14 |
| Legacy `.listProducts(` call sites in `lib/` | 16 |
| Catalog `.listProductCatalog(` call sites in `lib/` | 10 |
| Files containing a legacy call | 14 |
| Files containing a catalog call | 10 |

Governing equation: `24 = 10 + 14`.

The 16 legacy call sites map to 14 remaining units because PRC-109 and PRC-114
each contain two calls in one deliberately stable logical unit. PRC-117 is the
compatibility wrapper call, and PRC-118 includes the repository snapshot call.
The ten catalog calls map one-to-one to the ten migrated units. Test calls and
test adapters corroborate behavior but are not production consumers. Wiring
and constructors do not add reads. No unexplained direct, indirect,
write-coupled, test-only, or non-production call remains.

Compared with the independently verified Phase 106W baseline, the total stays
24, and exactly PRC-104 moves from remaining to migrated after Phase 106X:

```text
Phase 106W: 24 = 9 + 15
Phase 106Y: 24 = 10 + 14
```

## 8. Classification totals

| Category | Count |
| --- | ---: |
| A | 0 |
| B | 0 |
| C | 0 |
| D | 0 |
| E | 8 |
| F | 0 |
| G | 2 |
| H | 3 |
| I | 1 |

Check: `0 + 0 + 0 + 0 + 8 + 0 + 2 + 3 + 1 = 14`.

There is no A, B, or C candidate. PRC-101 is explicitly deferred as I because
using an application catalog projection for a lossless backup/restore payload
would cross architectural boundaries and require prohibited `Product`
manufacturing or a broader archival contract. Among D/E candidates, PRC-113
has the smallest safe production surface and the lowest coupling.

## 9. Single selected target

FROZEN_TARGET_ID: PRC-113

FROZEN_TARGET_CONSUMER: Profitability activation dialog enumeration

FROZEN_TARGET_CATEGORY: E

FROZEN_TARGET_FILE: lib/features/financial_reports/profitability_report_screen.dart

FROZEN_TARGET_MEMBER: _ProfitabilityReportScreenState._activate(AppUser user)

PRC-113 is selected because:

- it is genuinely production reachable through `DashboardShell` ->
  `FinancialReportsScreen` -> `ProfitabilityReportScreen`;
- the current contract already supplies its complete `id` and `name` set;
- its inactive behavior is the constant and unambiguous `true`;
- catalog and legacy Drift ordering are both `createdAt ASC`, then `id ASC`,
  preserving activation-dialog order;
- only one production file needs read-side type adaptation;
- the actual activation service remains a separate, unchanged dependency and
  revalidates products before its atomic write.

Nearest alternatives were rejected as follows:

1. PRC-102 needs only emptiness but is inside restore safety and has broad
   constructor/test coupling.
2. PRC-103 needs only a count but is inside destructive owner wipe.
3. PRC-108 is the authoritative transactional activation validation and must
   not be bundled with the dialog enumeration.
4. PRC-101 is a lossless backup boundary, not a catalog UI read.

## 10. Target Freeze Card

| Field | Frozen value |
| --- | --- |
| Consumer ID | `PRC-113` |
| Consumer name | Profitability activation dialog enumeration |
| Primary file | `lib/features/financial_reports/profitability_report_screen.dart:139-170` |
| Exact method/function | `_ProfitabilityReportScreenState._activate(AppUser user)` |
| Current read path | `AppRepositories.productRepository.listProducts(includeInactive: true)` at lines 140-141 |
| Current repository dependency | `AppRepositories.productRepository`, exposed as `ProductDataRepository` and implementing `ProductRepository` |
| Current returned type | `Future<List<Product>>` |
| Required fields | exactly `String id` and `String name` |
| Required semantics | one complete snapshot; verbatim IDs/names; stable repository order; no writes, fallback, trimming, or normalization |
| `includeInactive` behavior | exactly `true`; both active and inactive products must be offered for complete opening-valuation decisions |
| Ordering dependency | dialog and submitted openings iterate repository order; preserve `createdAt ASC`, then `id ASC` |
| Nullability behavior | neither required field is nullable; no nullable catalog field is read or defaulted |
| UI/runtime dependents | `_ActivationDialog` at lines 323-491; controller maps keyed by `product.id`; label uses `product.name`; route comes from `DashboardShell` and `FinancialReportsScreen` |
| Write operations that must remain on `ProductRepository` | none in the dialog itself; PRC-108 `ProfitabilityActivationService.activate` and its legacy product revalidation remain unchanged and out of scope; the catalog contract performs no mutation |
| Expected production files for next phase | only `lib/features/financial_reports/profitability_report_screen.dart` |
| Expected test files for next phase | add `test/phase106z_profitability_activation_dialog_product_catalog_read_migration_test.dart`; modify no historical test unless a strict timeline guard must admit the new commit |
| Contract expansion required | no |
| Exact contract fields required | none; existing `id` and `name` are sufficient |
| Explicit non-goals | PRC-108 service migration; any second consumer; contract/schema/generated changes; activation behavior/UI changes; Product construction/casts/fallbacks; repository refactor |
| Runtime proof after migration | Phase 106AA will initialize real production composition on a temporary SQLite database, seed active and inactive rows, prove the concrete Drift catalog path, order, and dialog data while a sentinel legacy screen read fails if called |

## 11. Frozen Phase 106Z plan — do not execute in 106Y

Proposed title:

```text
Phase 106Z — Migrate Profitability Activation Dialog Product Catalog Read
```

Closed production allowlist:

- `lib/features/financial_reports/profitability_report_screen.dart`

Implementation plan:

1. Replace only the PRC-113 call with
   `AppRepositories.productCatalogReadRepository.listProductCatalog(
   includeInactive: true)`.
2. Change only `_ActivationDialog.products` and its local iterations from
   `List<Product>` to `List<ProductCatalogReadModel>`.
3. Replace the `product.dart` import with
   `product_catalog_read_repository.dart` if no other `Product` symbol remains.
4. Preserve `id`, `name`, iteration order, loading, dialog, validation,
   cancellation, and activation submission behavior exactly.
5. Leave `AppRepositories.profitabilityActivationService` and PRC-108 on its
   current `ProductRepository` dependency.
6. Add focused behavior/source guards for active plus inactive inclusion,
   ordering, field sufficiency, absence of the legacy screen call, and exactly
   one newly migrated consumer.

Contract expansion: **no**. New fields: **none**. Drift field sources used by
the target remain `products.id` and `products.name`. Neither field is nullable;
text must pass through unchanged. No price or unit is consumed or converted.

Outcome A criteria for Phase 106Z:

- exactly PRC-113 moves to `listProductCatalog`;
- the only production diff is the single allowlisted file;
- `includeInactive: true` and `createdAt ASC`, `id ASC` semantics remain;
- `_ActivationDialog` uses `ProductCatalogReadModel` without constructing or
  casting `Product`;
- PRC-108 and all other remaining legacy units are unchanged;
- no contract, schema, migration, generated, visible UI, or write change;
- focused tests, full `flutter test`, `flutter analyze`, formatter, and diff
  checks pass.

SAFE BLOCKED conditions for Phase 106Z:

- a second production file is required;
- a new contract field or schema/generated change is required;
- PRC-108 or another consumer must move with PRC-113;
- exact inactive/order/field semantics cannot be proved;
- the type adaptation requires `Product` construction, unsafe casts, or a
  fallback;
- focused, full-suite, analyzer, formatter, or timeline verification fails for
  a genuine reason.

No later phase may infer permission to migrate a second consumer from this
plan.

## 12. Phase 106Y guard scope and non-goals

Phase 106Y adds its report and guard, and minimally extends one historical
lineage guard that otherwise rejects both the accepted 106X baseline and its
single 106Y documentation/test child:

- `docs/PHASE-106Y-RE-AUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md`
- `test/phase106y_next_product_read_migration_target_freeze_test.dart`
- `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart`

The 106O inventory, assertions, and architectural restrictions are unchanged;
only its exact allowed-HEAD timeline is extended through 106X and 106Y.

Explicit non-goals:

- do not migrate PRC-113 or any other consumer;
- do not add a field to `ProductCatalogReadModel`;
- do not change `includeInactive`, ordering, null, text, price, or unit
  semantics;
- do not alter `ProductRepository`, Drift schema, schema version, migrations,
  or generated files;
- do not change visible UI, reports, export, restore, wipe, transactions, or
  product writes;
- do not construct `Product` from the read model, add unsafe casts, or add a
  fallback;
- no unrelated refactor, Push, or Tag.

## 13. Timeline guard

The verified ancestry remains linear from the Phase 105 product-catalog
foundation through 106X. In particular:

```text
e0b0424 PHASE 105B: introduce product catalog read contract
edda4ec PHASE 105C: implement local drift product catalog read adapter
ea804cb PHASE 105D: migrate one product catalog application read boundary
6d27467 PHASE 105E: prove genuine runtime product catalog read integration
a813a70 PHASE 105F: accept and freeze product catalog read boundary pilot
...
b7d5086 PHASE 106W: freeze next product read migration target
3002169 PHASE 106X: extend product catalog notes and migrate product controller
```

The automated guard verifies ancestry and that Phase 106Y has no production
diff from `30021696ab2667340e032832892d3c2ecc5dadd7`.

## 14. Verification record

The final command results are recorded after execution:

| Verification | Result |
| --- | --- |
| Phase 106Y focused test | PASS — 17 tests |
| Product Catalog / Phase 106X focused tests | PASS — included in a 65-test focused batch |
| ProductController focused tests | PASS — Phase 106X behavior/source guards and `product_catalog_test.dart` |
| Phase 105/106 timeline/freeze tests | PASS — focused batches completed with 102 and 143 tests; repaired 106O guard rerun 8/8 |
| Full `flutter test` | PASS — 2243 passed, 1 skipped, 0 failed |
| `flutter analyze` | PASS — no issues found in 25.3 seconds |
| `dart format --output=none --set-exit-if-changed .` | PASS — 404 files checked, 0 changed, using the same SDK formatter executable directly because the Windows `dart.bat` wrapper stalled in this shell |
| `git diff --check` | PASS — staged diff has no whitespace errors |

No production file was changed in Phase 106Y. No migration, schema, generated, Push, or Tag action was performed.
