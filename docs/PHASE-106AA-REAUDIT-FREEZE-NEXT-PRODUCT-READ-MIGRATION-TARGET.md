# Phase 106AA — Re-audit and Freeze the Next Product Read Migration Target

## 1. Executive Summary

Phase 106AA independently re-audited the production product-read inventory at
the exact Phase 106Z baseline, reconciled direct calls with logical consumers,
reclassified every remaining unit under the governing A-I taxonomy, and froze
exactly one next target. Phase 106AA does not migrate a consumer, expand a
contract, modify a schema, or change any production file.

The source-derived result is:

```text
24 total consumers = 11 migrated + 13 remaining
15 legacy .listProducts(...) calls
11 catalog .listProductCatalog(...) calls
```

The sole eligible next target is `PRC-101 — BackupExportService.createBackup`.
It is a production-reachable, read-only snapshot path, not a product write,
domain command, or transaction. It requires a broader but exact two-field
read-contract expansion: non-null `DateTime createdAt` and `DateTime updatedAt`.

```text
FROZEN_TARGET_ID: PRC-101
FROZEN_TARGET_CONSUMER: BackupExportService.createBackup
FROZEN_TARGET_CATEGORY: D
FROZEN_TARGET_FILE: lib/core/backup/backup_export.dart
FROZEN_TARGET_MEMBER: Future<BackupExportResult> createBackup() async
```

Final outcome: **Outcome A — FULL SUCCESS**.

## 2. Starting State

| Evidence | Value |
| --- | --- |
| Repository | `C:\dev\multi-pos\grain-warehouse-erp-lite` |
| Required baseline | `33dccc824014d44265ab606b9f7d6a01713139e3` |
| Starting branch | `codex/phase-106z-migrate-profitability-report-activation-product-read` |
| Starting HEAD | `33dccc824014d44265ab606b9f7d6a01713139e3` |
| Starting commit subject | `PHASE 106Z: migrate profitability report activation product read` |
| Phase branch | `codex/phase-106aa-reaudit-freeze-next-product-read-migration-target` |
| Starting worktree/index | clean; no tracked, staged, or untracked changes |
| Git operation state | no merge, rebase, cherry-pick, revert, or bisect in progress |
| Commits after baseline before work | `0` |

## 3. Preflight Evidence

The following read-only checks succeeded before branch creation or file edits:

```text
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
git status --short
git diff --check
git diff --cached --check
git merge-base --is-ancestor 33dccc824014d44265ab606b9f7d6a01713139e3 HEAD
git rev-list --count 33dccc824014d44265ab606b9f7d6a01713139e3..HEAD
```

Observed repository root, branch, and HEAD matched the required values. Both
diff checks and `git status --short` produced no output. The ancestry command
returned success and the post-baseline commit count was zero. Only then was the
required Phase 106AA branch created.

## 4. Scope and Non-goals

Phase 106AA changes only this report and test guards. It does not change:

- any file under `lib/`;
- dependency injection, constructors, or repository wiring;
- `ProductCatalogReadModel`, `ProductCatalogReadRepository`, or
  `ProductRepository`;
- Drift adapters, SQL, schema, migrations, or generated files;
- activation, validation, UI, write, or transaction behavior;
- PRC-101 or any other consumer;
- Push or Tag state.

## 5. Audit Method

A logical consumer is one distinct production method, state loader, workflow,
or deliberately tracked compatibility/infrastructure unit that obtains product
data through `ProductRepository.listProducts`,
`ProductCatalogReadRepository.listProductCatalog`, or an actual wrapper leading
to one of them. Multiple calls in one stable workflow remain one consumer.

The audit used current `lib/` as authority and traced:

1. direct legacy and catalog calls;
2. repository types, fields, constructor injection, and composition root;
3. screens, controllers, services, repositories, and delegated implementations;
4. field consumption after each list is returned;
5. transaction/write membership and production reachability after
   `AppRepositories.initializeProduction()`;
6. tests and earlier reports only as lineage corroboration.

Definitions, interfaces, wiring-only references, test-only calls, and adapters
were not silently promoted into application consumers. PRC-117 and PRC-118 are
kept in the canonical 24-unit inventory solely so call-site reconciliation
remains explicit and stable.

## 6. Search Commands

The principal reproducible searches were:

```text
rg -n --glob '*.dart' "\.listProducts\(" lib
rg -n --glob '*.dart' "\.listProductCatalog\(" lib
rg -n --glob '*.dart' "ProductRepository|ProductCatalogReadRepository" lib
rg -n --glob '*.dart' "productRepository|productCatalogReadRepository" lib
rg -n "BackupExportService|createBackup\(" lib test -g '*.dart'
rg -n "ProductCatalogReadModel\(" lib test -g '*.dart'
```

The first search found 15 legacy calls; the second found 11 catalog calls.

## 7. Complete Consumer Inventory

The stable IDs below preserve the earlier inventory lineage. `PRC-001` through
`PRC-004`, `PRC-010`, and `PRC-014` are the original pilot-era IDs; the
`PRC-101` through `PRC-118` IDs are the canonical re-audit IDs introduced for
the later inventory. Every row is represented exactly once.

| Consumer ID | Consumer | File | Lines | Reachability | Current dependency | Current call | includeInactive | Fields consumed | Read/write classification | Migration status | Category | Contract gap | Risk | Recommended action | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-001 | `LocalDocumentHistoryRepository._productNamesById` | `lib/core/documents/document_history.dart` | 132-142; call 136 | document-history production repository | catalog read repository | `listProductCatalog(...)` | `true` | `id`, `name` | pure read | Migrated | Accepted | none | Low | retain | Phase 105D-105F guards |
| PRC-002 | `DashboardGuidanceState.load` | `lib/features/dashboard/dashboard_screen.dart` | 252-267; call 257 | protected dashboard lifecycle | app catalog read repository | `listProductCatalog(...)` | `true` | list length | pure read | Migrated | Accepted | none | Low | retain | Phase 106B-106C guards |
| PRC-003 | `InventoryAttentionService.loadAttention` | `lib/core/inventory/inventory_attention_service.dart` | 39-55; call 42 | dashboard and owner alerts | catalog read repository | `listProductCatalog(...)` | `true` | `id`, `name`, `isActive` | pure read aggregation | Migrated | Accepted | none | Low | retain | Phase 106D-106E guards |
| PRC-004 | `DashboardService.load` | `lib/core/dashboard/dashboard_service.dart` | 96-115; call 102 | dashboard controller/service | catalog read repository | `listProductCatalog(...)` | `true` | emptiness, `id`, `name` | pure read aggregation | Migrated | Accepted | none | Low | retain | Phase 106G-106H guards |
| PRC-014 | `LocalReportRepository.dailyActivityReport` | `lib/core/reports/report_repository.dart` | 45-72; call 55 | reports screen/controller | catalog read repository | `listProductCatalog(...)` | `true` | `id`, `name`, `unit`, reference cost | pure financial report read | Migrated | Accepted | none | Medium | retain | Phase 106J-106N guards |
| PRC-010 | `DriftInventoryRepository.allProductBalancesKg` | `lib/core/inventory/drift_inventory_repository.dart` | 104-119; call 108 | production inventory balance queries | catalog read repository | `listProductCatalog(...)` | `!activeProductsOnly` | `id` | pure read aggregation | Migrated | Accepted | none | Medium | retain | Phase 106M-106N guards |
| PRC-110 | `PurchaseController.load` | `lib/core/purchases/purchase_controller.dart` | 36-55; call 45 | purchases and supplier-purchases screens | catalog read repository | `listProductCatalog(...)` | permission expression | `id`, `name`, `isActive` | read loader outside mutation | Migrated | Accepted | none | Medium | retain | Phase 106P guard |
| PRC-107 | `InventoryController.load` | `lib/core/inventory/inventory_controller.dart` | 44-70; call 53 | inventory, stock-take, adjustment screens | catalog read repository | `listProductCatalog(...)` | permission expression | `id`, `name` | read loader outside mutation | Migrated | Accepted | none | Medium | retain | Phase 106R-106S guards |
| PRC-112 | `SaleController.load` | `lib/core/sales/sale_controller.dart` | 58-82; call 65 | sales screen | catalog read repository | `listProductCatalog(...)` | `false` | `id`, `name`, default/minimum sale prices | read loader outside mutation | Migrated | Accepted | none | Medium | retain | Phase 106U-106V guards |
| PRC-104 | `ProductController.loadProducts` | `lib/core/catalog/product_controller.dart` | 24-34; call 30 | products-management screen | catalog read repository | `listProductCatalog(...)` | permission expression | nine current catalog fields | read loader; writes remain separate | Migrated | Accepted | none | Medium | retain | Phase 106X guard |
| PRC-113 | `_ProfitabilityReportScreenState._activate` dialog enumeration | `lib/features/financial_reports/profitability_report_screen.dart` | 139-170; call 141 | financial reports activation button | app catalog read repository | `listProductCatalog(...)` | `true` | `id`, `name` | read slice feeding a separate command | Migrated | Accepted | none | High | retain; keep PRC-108 legacy | Phase 106Z guard |
| PRC-101 | `BackupExportService.createBackup` | `lib/core/backup/backup_export.dart` | 100-290; call 102; mapper 293-309 | backup screen and mandatory pre-wipe backup | `ProductRepository` | `listProducts(includeInactive: true)` | `true` | all 11 product fields | pure, lossless export read; no product write/transaction | Remaining | D | non-null `createdAt`, `updatedAt` | Critical | **selected: exact two-field expansion plus this consumer only** | backup screen, app wiring, Phase 13-18/81 tests |
| PRC-102 | `BackupRestoreService._checkEmptySystem` | `lib/core/backup/backup_restore_service.dart` | 230-274; call 232 | restore execution | `ProductDataRepository` | `listProducts(includeInactive: true)` | `true` | emptiness | restore domain-command integrity gate | Remaining | F | shape fits, boundary does not | Critical | defer until command-read separation | restore tests and transaction snapshot path |
| PRC-103 | `BusinessDataWipeService._currentCounts` | `lib/core/backup/business_data_wipe_service.dart` | 109-156,159-185; call 160 | owner destructive wipe | `ProductDataRepository` | `listProducts(includeInactive: true)` | `true` | count | destructive domain-command path | Remaining | F | shape fits, boundary does not | Critical | defer until wipe-read separation | pre-backup then clear sequence |
| PRC-105 | `NegativeBalanceApprovalWorkflowService._findProduct/_requireProduct` | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | 575-588,745-768; call 765 | approval request/revalidation/posting | `ProductRepository` | `listProducts(includeInactive: true)` | `true` | `id`, `isActive`, `updatedAt` fingerprint | financial domain-command path | Remaining | F | `updatedAt` plus command coupling | High | do not combine with PRC-101 | approval workflow tests |
| PRC-106 | `DriftInventoryRepository._findProductById` | `lib/core/inventory/drift_inventory_repository.dart` | 79-101,175-203; call 198 | stock query and movement validation | `ProductRepository` | `listProducts(includeInactive: true)` | `true` | `id`, `isActive` | inventory transaction/validation path | Remaining | F | shape fits, transaction boundary does not | Critical | defer; consider dedicated lookup contract | durable inventory tests |
| PRC-108 | `ProfitabilityActivationService.activate` | `lib/core/inventory_valuation/profitability_activation_service.dart` | 32-110; call 49 | owner profitability activation | `ProductRepository` | `listProducts(includeInactive: true)` | `true` | `id`, complete membership/count/order | atomic valuation/audit command | Remaining | F | command coupling | Critical | retain legacy validation read | activation transaction tests |
| PRC-109 | `DriftPurchaseRepository._validateProduct/_validateProductExists` | `lib/core/purchases/drift_purchase_repository.dart` | 332-354; calls 334,350 | durable intake/cancel | `ProductRepository` | two `listProducts(includeInactive: true)` calls | `true` | `id`, `isActive` | purchase transaction validation | Remaining | F | shape fits, transaction boundary does not | High | defer; do not merge calls into another consumer | durable purchase tests |
| PRC-111 | `LocalSaleRepository._validateProduct/_validateAllMinimumPrices` | `lib/core/sales/sale_repository.dart` | 530-581; call 565 | production through `DriftSaleRepository` delegation | `ProductRepository` | `listProducts(includeInactive: true)` | `true` | `id`, `isActive`, minimum sale price | sale/COGS/stock/account command path | Remaining | F | shape fits, command boundary does not | Critical | retain until command-read design | sale transaction tests |
| PRC-114 | `LocalInventoryRepository.allProductBalancesKg/_findProductById` | `lib/core/inventory/inventory_repository.dart` | 125-137,202-212; calls 128,204 | superseded by Drift in production | `ProductRepository` | two `listProducts(...)` calls | caller-shaped / `true` | `id`, `isActive` | test/local implementation | Remaining | I | not production-reachable | N/A | exclude from target selection | production composition at app lines 134-170 |
| PRC-115 | `LocalPurchaseRepository._validateProduct` | `lib/core/purchases/purchase_repository.dart` | 416-438; call 426 | superseded by Drift in production | `ProductRepository` | `listProducts(includeInactive: true)` | `true` | `id`, `isActive` | test/local implementation | Remaining | I | not production-reachable | N/A | exclude from target selection | production composition |
| PRC-116 | `SyntheticProfitabilityActivationService.activate` | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | 48-111; call 84 | deliberately unwired Phase 102 sandbox | `ProductDataRepository` | `listProducts(includeInactive: true)` | `true` | emptiness | synthetic test command | Remaining | I | not production-reachable | N/A | exclude from target selection | required sandbox identity and no app wiring |
| PRC-117 | `_LegacyProductCatalogReadRepository.listProductCatalog` | `lib/app/app_repositories.dart` | 347-378; call 357 | default compatibility adapter, replaced at production init | `ProductRepository` | wrapper `listProducts(...)` | forwards expression | all nine catalog fields | infrastructure adapter | Remaining | I | not an application consumer | N/A | retain for compatibility; never select | app composition swap at lines 134-135 |
| PRC-118 | `DriftProductRepository.listProducts/_DriftProductSnapshot.capture` | `lib/core/catalog/drift_product_repository.dart` | 16-25,256-272; internal call 263 | production repository and rollback infrastructure | repository self-call | `listProducts()` | default `true` | full `Product` snapshot | transaction infrastructure | Remaining | I | not an independent application consumer | N/A | retain; never select | snapshot capture/rollback implementation |

## 8. Call-site Reconciliation

| Measure | Count |
| --- | ---: |
| Textual legacy `.listProducts(` calls in `lib/` | 15 |
| Files containing a legacy call | 13 |
| Logical remaining inventory units | 13 |
| Textual catalog `.listProductCatalog(` calls in `lib/` | 11 |
| Files containing a catalog call | 11 |
| Logical migrated inventory units | 11 |

The 15 legacy calls map to 13 remaining units because PRC-109 owns two calls in
one durable purchase workflow and PRC-114 owns two calls in one superseded local
inventory implementation. PRC-117 accounts for the compatibility-wrapper call;
PRC-118 accounts for the internal snapshot call. The 11 catalog calls map
one-to-one to the 11 migrated consumers. Definitions, constructor references,
and tests add no production call site.

## 9. Migrated vs Remaining Reconciliation

```text
Total = Migrated + Remaining
24 = 11 + 13
```

The total is unchanged from Phase 106Y. Exactly PRC-113 moved from remaining to
migrated in Phase 106Z:

```text
Phase 106Y: 24 = 10 + 14; 16 legacy; 10 catalog
Phase 106Z: 24 = 11 + 13; 15 legacy; 11 catalog
Phase 106AA audit: 24 = 11 + 13; 15 legacy; 11 catalog
```

## 10. Remaining-category Reconciliation

The governing category definitions are applied literally:

- A — directly migratable with the current contract.
- B — a small consumer-local adaptation is required.
- C — a narrow read-contract expansion is required.
- D — a broader read-contract expansion is required.
- E — coupled to product mutation behavior.
- F — transactional or domain-command path.
- G — mixed read/write consumer requiring separation.
- H — not safely migratable as one atomic consumer.
- I — not production-reachable, test-only, dead, deferred infrastructure, or
  not an independent application consumer.

| Category | Count | Members |
| --- | ---: | --- |
| A | 0 | — |
| B | 0 | — |
| C | 0 | — |
| D | 1 | PRC-101 |
| E | 0 | — |
| F | 7 | PRC-102, PRC-103, PRC-105, PRC-106, PRC-108, PRC-109, PRC-111 |
| G | 0 | — |
| H | 0 | — |
| I | 5 | PRC-114, PRC-115, PRC-116, PRC-117, PRC-118 |

```text
Remaining = A + B + C + D + E + F + G + H + I
13 = 0 + 0 + 0 + 1 + 0 + 7 + 0 + 0 + 5
```

PRC-101 is D, not I: current source proves it is production-reachable and a
real read. Its deferral in Phase 106Y described architectural caution, but the
governing taxonomy reserves I for unreachable/test/dead/deferred units. The
current audit establishes a concrete, closed, lossless expansion and therefore
promotes it to the actionable broader-expansion category without weakening its
Critical risk rating.

## 11. Changes Since Phase 106Y

Phase 106Y froze PRC-113 while reporting 10 migrated, 14 remaining, 16 legacy
calls, and 10 catalog calls. Phase 106Z changed only the profitability report
screen read boundary and its guards/report. No contract, adapter, schema,
generated, activation-service, or PRC-108 change occurred.

The only inventory delta is PRC-113:

- `AppRepositories.productRepository.listProducts(includeInactive: true)` was
  replaced by
  `AppRepositories.productCatalogReadRepository.listProductCatalog(includeInactive: true)`;
- the dialog list type changed from `Product` to `ProductCatalogReadModel`;
- `id`, `name`, inactive inclusion, ordering, loading, error, success, dialog,
  and activation behavior stayed fixed.

## 12. Phase 106Z Impact

Phase 106Z removed the final standalone/current-contract candidate. The live
remaining set now contains one pure read requiring a broader contract
expansion, seven command/transaction reads, and five unreachable or
infrastructure units. PRC-108 did not become eligible merely because the dialog
read migrated; it remains the authoritative validation inside atomic valuation
and audit writes.

## 13. Candidate Shortlist

Only PRC-101 satisfies every target eligibility rule. The two nearest-looking
alternatives are shown to make the rejection boundary explicit.

| Candidate | Current path | Fields needed | Contract status | Production files expected | Main risk | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| PRC-101 `BackupExportService.createBackup` | read-only full snapshot export | current nine fields plus non-null `createdAt`, `updatedAt` | broader exact two-field expansion | contract, Drift adapter, legacy adapter/app wiring, backup export | lossless backup/checksum compatibility | **selected** |
| PRC-102 `BackupRestoreService._checkEmptySystem` | restore command integrity gate | emptiness only | current shape is sufficient | restore service and composition | moving a guard inside atomic multi-repository restore | rejected: F, not a pure read target |
| PRC-103 `BusinessDataWipeService._currentCounts` | destructive wipe command | count only | current shape is sufficient | wipe service and composition | backup-then-delete safety sequence | rejected: F, not a pure read target |

PRC-101 wins because it is the only production-reachable remaining legacy read
that performs no product mutation, domain write, transaction validation, or
command authorization. It is one logical consumer and does not require another
consumer to move. Its four-file production boundary is larger than earlier UI
loaders because timestamps must cross the accepted read projection and both
catalog adapters, but it remains closed and atomic. PRC-102 and PRC-103 look
smaller by fields yet fail the mandatory purity criterion.

## 14. Selected Target

```text
Selected next target: PRC-101 — BackupExportService.createBackup
Classification: D — Requires a Broader Read-contract Expansion
Production reachable: yes
Pure read: yes
Product write or mutation: no
Transaction/domain command: no
Can migrate alone: yes
Contract expansion: exactly two non-null DateTime fields
```

Production reachability is:

```text
DashboardShell backup destination
→ BackupExportScreen._createBackup
→ AppRepositories.backupExportService
→ BackupExportService.createBackup
→ ProductRepository.listProducts(includeInactive: true)
→ DriftProductRepository → SQLite products
```

The same service is also invoked as the mandatory backup step before an owner
data wipe. That second entry does not make the export read a write path: the
export completes and is validated/saved before the wipe service begins its own
clear operations.

## 15. Rejected Candidates and Reasons

- PRC-102 and PRC-103 are command-integrity reads in restore/wipe flows.
- PRC-105 is a product fingerprint inside financial approval/revalidation.
- PRC-106 is inventory lookup/validation used at a durable movement boundary.
- PRC-108 is the authoritative atomic profitability activation validation.
- PRC-109 is purchase transaction validation and owns two calls that must not
  be split accidentally.
- PRC-111 is sale, minimum-price, COGS, stock, and account command validation.
- PRC-114 through PRC-116 are not production-reachable.
- PRC-117 and PRC-118 are infrastructure, not selectable application reads.

## 16. Frozen Current Behavior

The next phase must preserve all of the following PRC-101 behavior explicitly:

- `includeInactive` is the constant `true`; active and inactive rows are backed
  up.
- Product ordering is `createdAt ASC`, then `id ASC`, and the JSON array retains
  that order.
- Exactly 11 fields are serialized for every product: `id`, `name`, `code`,
  `unit`, `isActive`, default/minimum/reference piasters-per-kg prices, `notes`,
  `createdAt`, and `updatedAt`.
- `id`, `name`, `unit`, `isActive`, `createdAt`, and `updatedAt` are non-null.
- `code`, all three price fields, and `notes` preserve null exactly; no fallback,
  trimming, normalization, rounding, or manufactured value is allowed.
- `unit` remains `product.unit.name`; no wire-name change is allowed.
- Monetary integers remain piasters per kilogram with no unit or currency
  conversion.
- Timestamps remain the stored `DateTime` values until serialization, where the
  existing mapper applies `toUtc().toIso8601String()` exactly once.
- `products.length` continues to drive the backup count.
- An empty product table produces count `0` and an empty `products` JSON array.
- The product snapshot is read before the other repository snapshots in the
  current sequential `createBackup` flow.
- Read or mapping errors continue to propagate to the caller; the service adds
  no retry, cache, fallback, partial success, or UI message.
- Backup version, metadata, checksum calculation, file name, result object,
  loading state, screen error handling, copy/save behavior, and wipe pre-backup
  behavior are unchanged.
- No callback, object-identity assumption, `Product` construction, product
  mutation, or activation behavior is attached to an item.

## 17. Frozen Next-phase Contract

| Field | Frozen value |
| --- | --- |
| Phase number | `106AB` |
| Phase title | `Expand Product Catalog Timestamps and Migrate Backup Export Product Read` |
| Consumer ID | `PRC-101` |
| Exact class | `BackupExportService` |
| Exact method | `Future<BackupExportResult> createBackup() async` |
| Exact file | `lib/core/backup/backup_export.dart` |
| Current legacy dependency | constructor/field type `ProductRepository` |
| Current legacy call | `_productRepository.listProducts(includeInactive: true)` |
| Required catalog dependency | `ProductCatalogReadRepository` |
| Required catalog call | `_productCatalogReadRepository.listProductCatalog(includeInactive: true)` |
| includeInactive semantics | exactly `true` |
| Fields consumed | all 11 fields listed in section 16 |
| Contract expansion allowed | yes, exactly two fields |
| Expansion field 1 | `DateTime createdAt`, required, non-null, direct `products.createdAt` value |
| Expansion field 2 | `DateTime updatedAt`, required, non-null, direct `products.updatedAt` value |
| Adapter rules | select both columns in the existing single query; pass through unchanged; no UTC conversion, fallback, truncation, normalization, or new query |
| Serialization rule | keep existing UTC ISO-8601 conversion in `_productToJson`; do not move it into the repository |
| Expected commit message | `PHASE 106AB: expand product catalog timestamps and migrate backup export product read` |

The timestamps are not nullable in the domain model or products table. Making
them nullable or defaulted would permit a lossy backup and is forbidden. A
simpler current-contract target does not exist: all seven other production
legacy consumers are F command/transaction paths.

## 18. Expected Production Diff

The closed production allowlist for Phase 106AB is:

```text
lib/core/catalog/product_catalog_read_repository.dart
lib/core/catalog/drift_product_catalog_read_repository.dart
lib/core/backup/backup_export.dart
lib/app/app_repositories.dart
```

Expected changes are only:

1. add the two required fields to `ProductCatalogReadModel`;
2. select/map the two existing product columns in the Drift adapter;
3. map them in `_LegacyProductCatalogReadRepository`;
4. inject/use the catalog read repository in `BackupExportService` and app
   composition;
5. change `_productToJson`'s parameter type to `ProductCatalogReadModel` while
   leaving its JSON body byte-for-byte equivalent in meaning.

## 19. Explicit Exclusions

Phase 106AB must not migrate a second consumer; change PRC-102, PRC-103,
PRC-105, PRC-106, PRC-108, PRC-109, or PRC-111; modify backup JSON keys,
version, ordering, checksum, restore parsing, or validation; add lookup/stream/
write methods; change schema, migrations, or generated files; manufacture
`Product` objects; add timestamp defaults; alter UI; or perform Push/Tag.

## 20. Automated Freeze Guard

`test/phase106aa_reaudit_freeze_next_product_read_migration_target_test.dart`
guards:

- exact baseline ancestry and the single allowed Phase 106AA child;
- no Phase 106AA `lib/` diff;
- 15 legacy and 11 catalog calls;
- 24 = 11 + 13 and the D/F/I category equation;
- the sole frozen target ID, file, method, dependency, and legacy call;
- PRC-101's 11-field serialization and timestamp semantics;
- the exact two-field next-phase expansion and four-file allowlist;
- no early target or second-consumer migration;
- no schema/generated change.

Historical lineage guards are minimally extended only to recognize the
legitimate Phase 106AA child after Phase 106Z; their historical source and
behavior assertions remain unchanged.

## 21. Verification Results

| Gate | Result |
| --- | --- |
| Phase 106AA dedicated guard | PASS |
| Product-catalog / Phase 106 lineage guards | PASS |
| Full `flutter test` | PASS — 2,263 passed, 1 skipped, 0 failed |
| `flutter analyze` | PASS — 0 issues |
| `dart format --output=none --set-exit-if-changed .` | PASS — 0 changes required |
| `git diff --check` | PASS — 0 errors |
| `git diff 33dccc8... -- lib` | empty |

The one skip is the historical
`phase9a_inflows_outflows_reports_test.dart` case marked
`Requires negative balance approval with actual credentials`. It is not a
failure and is unchanged from the baseline.

## 22. Git Evidence

Before commit, only this report and test guard/lineage files are permitted.
The production diff against `33dccc824014d44265ab606b9f7d6a01713139e3`
must remain empty. After commit, the branch must contain exactly one commit
after the baseline, the worktree must be clean, and no Push or Tag may occur.

## 23. Final Outcome

**Outcome A — FULL SUCCESS**.

The audit reconciles every current call and logical unit, freezes exactly
PRC-101, leaves production untouched, and defines a closed next phase that is
larger than a loader migration but still one atomic consumer with an exact,
lossless contract delta.

## 24. Exact Recommended Super Prompt Summary for the Next Phase

```text
Phase 106AB — Expand Product Catalog Timestamps and Migrate Backup Export Product Read

Start exactly from the Phase 106AA final commit on its clean branch lineage.
Migrate only PRC-101, BackupExportService.createBackup in
lib/core/backup/backup_export.dart, from
_productRepository.listProducts(includeInactive: true) to
_productCatalogReadRepository.listProductCatalog(includeInactive: true).

Expand ProductCatalogReadModel with exactly two required non-null fields:
DateTime createdAt and DateTime updatedAt. Source them directly from
products.createdAt and products.updatedAt in the existing one-query Drift
adapter and legacy compatibility adapter. Do not normalize, default, convert,
truncate, or manufacture either timestamp. Keep UTC ISO-8601 conversion only
in the existing backup serializer.

Allowed production files only:
- lib/core/catalog/product_catalog_read_repository.dart
- lib/core/catalog/drift_product_catalog_read_repository.dart
- lib/core/backup/backup_export.dart
- lib/app/app_repositories.dart

Preserve all 11 product JSON fields, nulls, units, piasters-per-kg values,
createdAt/id ordering, inactive inclusion, counts, empty state, backup version,
checksum, UI/error behavior, and wipe pre-backup behavior. Do not migrate any
other PRC, especially command/transaction consumers PRC-102, PRC-103, PRC-105,
PRC-106, PRC-108, PRC-109, or PRC-111. No schema, migration, generated, UI,
Push, or Tag changes. Add focused contract, adapter, backup-equivalence, and
runtime tests; update only constructor fixtures forced by the two required
fields and the migrated dependency. Expected commit message:
PHASE 106AB: expand product catalog timestamps and migrate backup export product read
```
