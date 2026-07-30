# Phase 106I — Discover and Freeze the Next Product Read Contract Expansion

## Executive outcome

**Outcome A — FULL SUCCESS**

Phase 106I re-inventories every production product-read consumer after Phase
106H, compares all four consumers previously known to need a broader contract,
and freezes one expansion without implementing it. The smallest coherent safe
expansion is to add one nullable catalog-level field,
`referenceCostPricePiastersPerKg`, to the existing
`ProductCatalogReadModel`. That exact delta is sufficient for
`LocalReportRepository.dailyActivityReport`; no new repository operation,
domain entity, lookup, stream, join, schema change, or write capability is
needed.

Phase 106I changes only this report and its discovery/freeze guard. There is no
production diff under `lib/` and no expansion is implemented in this phase.

## Governing references

| Item | Value |
| --- | --- |
| Phase branch | `codex/phase-106i-discover-freeze-next-product-read-contract-expansion` |
| Governing baseline | `812face11ab3b63f2252402ec0cb8960cc4af563` |
| Baseline subject | `PHASE 106H: accept and close dashboard service product catalog read migration` |
| Previous branch | `codex/phase-106h-accept-close-dashboard-service-product-catalog-read-migration` |
| Initial worktree | Clean |
| Initial commits after baseline | `0` |
| Initial `git diff --check` | PASS — exit 0, no output |
| Phase 106F report | `docs/PHASE-106F-DISCOVER-FREEZE-NEXT-PRODUCT-READ-CONSUMER-TARGET.md` |
| Phase 106F guard | `test/phase106f_next_product_read_consumer_target_discovery_freeze_test.dart` |
| Phase 106H report | `docs/PHASE-106H-ACCEPT-CLOSE-DASHBOARD-SERVICE-PRODUCT-CATALOG-READ-MIGRATION.md` |
| Phase 106H guard | `test/phase106h_dashboard_service_product_catalog_read_migration_acceptance_freeze_test.dart` |

The Phase 106F inventory was treated as a historical baseline, not copied as
current truth. Searches for `ProductRepository`, `ProductDataRepository`,
`listProducts`, `ProductCatalogReadRepository`, `listProductCatalog`, direct
Drift product-table reads, private product lookups, and runtime composition
were repeated against the current source. Every executable match was opened
and traced through its constructor, entry point, downstream field use, write
boundary, and production composition.

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

The sole operation is
`Future<List<ProductCatalogReadModel>> listProductCatalog({required bool includeInactive})`.
`includeInactive: false` filters to active rows; `true` returns active and
inactive rows. Results are ordered by `createdAt ASC, id ASC`, materialized as
a fresh non-growable list, and are empty when no row matches. Query and mapping
errors propagate. There is no cache, retry, fallback, stream, single lookup,
write, or transaction side effect.

## Full consumer inventory

Inventory unit: one production-reachable method/state/workflow with a distinct
product-read behavior. Repository declarations, adapters, and application
composition are evidence but are not consumer rows. The isolated synthetic
activation service remains a row because it is executable product-reading
code, but it is classified G after production reachability was disproved.

| ID | Consumer / file | Entry and reachability evidence | Current source / shape | Fields actually used | Filter, order, limit, refresh | Write / transaction coupling | Failure semantics | Class | Expansion candidate and reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-001 | `LocalDocumentHistoryRepository._productNamesById` via `listHistory` — `lib/core/documents/document_history.dart` | document-history screen/controller; composed by `AppRepositories.documentHistoryRepository` | catalog `listProductCatalog`; list | `id`, `name` | inactive included; adapter `createdAt,id`; no limit; per history load | no / no | catalog error propagates | A | no — accepted Phase 105D–105F |
| PRC-002 | `DashboardGuidanceState.load` — `lib/features/dashboard/dashboard_screen.dart` | protected dashboard lifecycle invokes loader | catalog `listProductCatalog`; list/count | list length only | inactive included; adapter order irrelevant; per load | no / no | error converted to guidance failure state | A | no — accepted Phase 106B–106C |
| PRC-003 | `InventoryAttentionService.loadAttention` — `lib/core/inventory/inventory_attention_service.dart` | dashboard and owner-alert services inject production composition | catalog list plus independent inventory balances | `id`, `name`, `isActive` | inactive included; adapter order preserved; per attention load | no product write / no | errors propagate | A | no — accepted Phase 106D–106E |
| PRC-004 | `DashboardService.load` — `lib/core/dashboard/dashboard_service.dart` | `DashboardScreen` → `DashboardController.load` → service | catalog list plus independent inventory/sales reads | `id`, `name`; list emptiness | inactive included; `createdAt,id`; first wheat-name match; no limit; per load | no / no | errors propagate | A | no — accepted and closed Phase 106G–106H |
| PRC-005 | `ProductController.loadProducts` — `lib/core/catalog/product_controller.dart` | `ProductsScreen.initState`, retry, and post-write refresh; production repository injected | legacy `listProducts`; list | all displayed/editable product fields: `id`, `name`, `code`, `unit`, activity, three prices, notes; domain object also feeds edit form | inactive policy follows manage permission; `createdAt,id`; no limit; initial/retry/post-write reload | loader separable; same controller owns product writes, but read is outside their transaction | load errors propagate; write methods catch and map | C | yes — coherent only with a much broader management projection |
| PRC-006 | `InventoryController.load` — `lib/core/inventory/inventory_controller.dart` | inventory, stock-take, and adjustment-report screens | legacy list plus inventory state | identity/name/activity presented across stateful inventory UI | permission-shaped inactive filter; `createdAt,id`; reload lifecycle | yes / financially sensitive inventory and valuation flows | load error handling owned by controller | E | no — stock mutation and valuation boundary dominates |
| PRC-007 | `PurchaseController.load` — `lib/core/purchases/purchase_controller.dart` | purchases and supplier-purchases screens | legacy list | `id`, `name`, `isActive` for selection/display | permission-shaped inactive policy; `createdAt,id`; reload after writes | yes / purchase posting and cancellation lifecycle | controller maps operation errors | E | no — posted-purchase workflow |
| PRC-008 | `SaleController.load` — `lib/core/sales/sale_controller.dart` | `SalesScreen` creates controller with `AppRepositories.productRepository` | legacy active list plus independent stock/customer/account reads | `id`, `name`, default and minimum sale prices | active only; `createdAt,id`; no limit; initial/reload | loader is outside transaction; loaded price data feeds sale-entry UI | load error propagates; create path catches | C | yes — needs two nullable sales-price fields and carries financial behavior risk |
| PRC-009 | `LocalInventoryRepository.allProductBalancesKg` / `_findProductById` — `lib/core/inventory/inventory_repository.dart` | production inventory abstraction and movement validation | legacy list used as active ID set or private ID lookup | `id`, `isActive`, selected product | caller-shaped inactive policy; full scan; no paging | yes / movement, restore, wipe safety | errors propagate | E | no — integrity read |
| PRC-010 | `DriftInventoryRepository.allProductBalancesKg` / `_findProductById` — `lib/core/inventory/drift_inventory_repository.dart` | durable production inventory repository | legacy full-list scan | `id`, `isActive`, selected product | caller-shaped filter; `createdAt,id`; no limit | yes / durable ledger writes | errors propagate | E | no — transaction safety and lookup semantics |
| PRC-011 | `LocalPurchaseRepository._validateProduct` — `lib/core/purchases/purchase_repository.dart` | purchase posting | legacy list → one match | `id`, `isActive` | inactive included then rejected; first exact ID; no paging | yes / validation before stock/account write | validation exceptions propagate | E | no — transaction-integrity validation |
| PRC-012 | `DriftPurchaseRepository._validateProduct` / `_validateProductExists` — `lib/core/purchases/drift_purchase_repository.dart` | durable post/cancel/restore flows | legacy list → one/boolean | `id`, `isActive` | inactive included; exact ID; no paging | yes / durable multi-repository transaction | validation errors propagate | E | no — transaction-integrity validation |
| PRC-013 | `LocalSaleRepository._validateProduct` — `lib/core/sales/sale_repository.dart` | sale posting | legacy list → one product | `id`, activity, price and reference-cost fields | inactive included then validates exact ID/activity; no paging | yes / sale, COGS, stock and account write | validation errors propagate | E | no — transactional pricing/costing safety |
| PRC-014 | `LocalReportRepository.dailyActivityReport` — `lib/core/reports/report_repository.dart` | `ReportsScreen` → `ReportController.loadDailyActivity` → `AppRepositories.reportRepository` | legacy list combined with read-only purchases, sales, movements, balances and expenses | `id`, `name`, `unit`, nullable reference cost | inactive included; `createdAt,id`; no search/limit/paging; fresh per report load | no product write / no transaction | repository errors propagate; controller catches and exposes report-load error | C | **yes — selected; only one catalog field is missing** |
| PRC-015 | `ProfitabilityActivationService.activate` — `lib/core/inventory_valuation/profitability_activation_service.dart` | owner profitability activation | legacy list plus physical stock | membership and IDs | inactive included; full list; one activation invocation | yes / atomic valuation and audit activation | fail-closed errors | E | no — activation safety read |
| PRC-016 | `SyntheticProfitabilityActivationService.activate` — `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | isolated Phase 102 test/tool only; absent from production `AppRepositories` and screens | `ProductDataRepository.listProducts`; list emptiness | emptiness | inactive included; no semantic ordering; per tool run | creates synthetic catalog and valuation | errors propagate | G | no — not production reachable, rather than H because no later production consumer supersedes it |
| PRC-017 | `NegativeBalanceApprovalWorkflowService._findProduct` / `_requireProduct` — `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | production approval request, revalidation, and execution | legacy list → optional/required lookup | ID, activity, payload evidence | inactive included; exact ID scan; no paging | yes / financial approval and posting | fail-closed validation | E | no — approval consistency boundary |
| PRC-018 | `BackupExportService.createBackup` — `lib/core/backup/backup_export.dart` | backup export screen and pre-wipe mandatory backup; composed by `AppRepositories.backupExportService` | legacy list serialized into versioned JSON snapshot | all 11 persisted/domain fields including timestamps and three prices | inactive included; `createdAt,id`; all rows; fresh per export | no product write / no repository transaction | errors propagate except separately documented optional-logo fallback | C | yes — full snapshot projection, but far larger and format-sensitive |
| PRC-019 | `BackupRestoreService._checkEmptySystem` via `restoreToEmpty` — `lib/core/backup/backup_restore_service.dart` | restore preview/execute | `ProductDataRepository.listProducts`; emptiness gate | emptiness | inactive included; order irrelevant; once per restore | yes / atomic multi-repository restore | fail closed | E | no — restore-integrity gate |
| PRC-020 | `BusinessDataWipeService._currentCounts` via `wipeBusinessData` — `lib/core/backup/business_data_wipe_service.dart` | owner destructive wipe | `ProductDataRepository.listProducts`; count | count | inactive included; order irrelevant; pre-wipe snapshot | yes / backup then destructive clear | aborts on error | E | no — destructive workflow coupling |
| PRC-021 | `_ProfitabilityReportScreenState._activate` — `lib/features/financial_reports/profitability_report_screen.dart` | owner activation button | direct legacy list plus balances/opening input | `id`, `name` | inactive included; `createdAt,id`; per activation dialog | yes / immediately invokes financial activation | UI reports activation error | E | no — financially sensitive write workflow |

The current executable search yields 17 legacy consumer files after excluding
two infrastructure files, plus four migrated catalog consumer files. The
inventory therefore remains 21 and each row has exactly one A–H class.

## Classification totals

- A — Already Migrated and Accepted: 4
- B — Eligible Under Current Contract: 0
- C — Requires a Broader Read Contract: 4
- D — Higher-Risk Read Migration: 0
- E — Write-Coupled or Transaction-Safety Read: 12
- F — Single Lookup or Stream Requirement: 0
- G — Not Production-Reachable: 1
- H — Already Superseded or Duplicated: 0
- Total: 21

## Delta from Phase 106F

| Classification | Phase 106F | Phase 106I | Reason |
| --- | ---: | ---: | --- |
| Total consumers | 21 | 21 | no new or removed executable consumer boundary |
| Migrated and accepted | 3 | 4 | `DashboardService.load` migrated in 106G and was accepted in 106H |
| Eligible under current contract | 1 | 0 | the sole Phase 106F eligible target is now closed |
| Requires broader contract | 4 | 4 | the same four field-shape gaps remain; Phase 106G–H did not modify them |
| Higher-risk read migration | 0 | 0 | no standalone ordering/search/paging/stream risk was discovered |
| Write/transaction coupled | 12 | 12 | transaction and write topology is unchanged |
| Lookup/stream | 0 | 0 | private ID scans remain transaction-safety reads, not independent lookup consumers |
| Not production reachable | 1 | 1 | synthetic activation remains isolated |
| Superseded/duplicated | not a separate 106F class | 0 | dashboard moved to A rather than becoming a duplicate row |

The only numerical movement is exactly the expected B → A transition for
`DashboardService.load`. No hardcoded count is accepted without the source-set
guard in the Phase 106I test.

## Broader-contract candidates

### ProductController.loadProducts

```text
ProductsScreen.initState / retry / product-write refresh
→ ProductController.loadProducts
→ ProductRepository.listProducts
→ AppRepositories.productRepository
→ DriftProductRepository
→ FoundationDatabase.products
```

The loader supplies product management cards and edit forms. It consumes every
user-maintained product field: identity, code, unit, activity, default sale
price, minimum sale price, reference cost, and notes; the domain object also
carries timestamps. Inactive inclusion depends on management permission.
Rows retain `createdAt ASC, id ASC`, with no search, limit, paging, deduplication,
or cache. The loader itself is outside a write transaction, although the same
controller invokes it after create/update/activity writes. The current catalog
contract is insufficient by default/minimum prices, reference cost, notes, and
edit-domain needs. A safe migration needs a dedicated management projection or
larger design; expanding the shared catalog into the editable domain entity is
rejected.

### SaleController.load

```text
SalesScreen.initState / reload
→ SaleController.load
→ ProductRepository.listProducts(includeInactive: false)
→ AppRepositories.productRepository
→ DriftProductRepository
→ FoundationDatabase.products
```

The loader builds active product selection/cards and combines them with stock,
customers, and financial accounts. Product reads are `id`, `name`, nullable
default sale price, and nullable minimum sale price. The active-only list uses
`createdAt ASC, id ASC`, no search/paging, and a fresh read per load. The loader
is not transaction-local, so it remains C; nevertheless the values seed and
constrain a financial sale workflow. The current catalog lacks both price
fields. A dedicated sales-selection read model is safer than adding pricing to
the general catalog, and its behavioral risk is higher than the selected
report field.

### LocalReportRepository.dailyActivityReport

```text
ReportsScreen.initState / date reload
→ ReportController.loadDailyActivity
→ LocalReportRepository.dailyActivityReport
→ ProductRepository.listProducts(includeInactive: true)
→ AppRepositories.productRepository
→ DriftProductRepository
→ FoundationDatabase.products
```

The report uses `id` and `name` for movement labels and missing-cost evidence,
`unit` for stock rows, and `referenceCostPricePiastersPerKg` for estimated sales
cost, gross profit, stock value, and completeness flags. It does not read code,
activity, sales prices, notes, or timestamps. It intentionally includes
inactive products so historical sales/movements retain names and costs. It has
no product filter, search, paging, limit, deduplication, or local sort; legacy
and catalog adapters both supply `createdAt ASC, id ASC`. Empty products yield
empty stock rows and unknown/missing-cost behavior through the existing
calculator. Nullable reference cost remains null and drives incomplete-cost
semantics; it must never become zero. Product read errors propagate from the
repository, while `ReportController` catches the complete report error and
shows the existing load failure. Every report load is fresh. The path performs
no product write and is not inside a transaction.

The existing model already provides `id`, `name`, and `unit`. Its sole exact
gap is nullable `referenceCostPricePiastersPerKg`.

### BackupExportService.createBackup

```text
BackupExportScreen or BusinessDataWipeService
→ BackupExportService.createBackup
→ ProductRepository.listProducts(includeInactive: true)
→ AppRepositories.productRepository
→ DriftProductRepository
→ FoundationDatabase.products
```

Backup export serializes every product field: ID, name, code, unit, activity,
three nullable price/cost values, notes, created timestamp, and updated
timestamp. It includes every row in `createdAt ASC, id ASC`, without paging or
search, once per export. The workflow is read-only for direct export, while the
same operation is also a mandatory precondition for destructive wipe. Product
read errors propagate. The current catalog omits six fields and both
timestamps. The correct future abstraction is a versioned backup snapshot
projection, not enlargement of a general catalog contract.

## Ranking matrix

Scores use 0 = unsuitable, 1 = high risk, 2 = acceptable with conditions, and
3 = clearly suitable. Higher is safer/smaller. Contract-delta and risk scores
are explained by the candidate analyses above.

| Rank | Candidate | Reach | Read-only | Delta | Clarity | Reuse | Behavior | Order | Refresh | Performance | Cloud/mobile | Testability | Atomic migration | Total / 36 |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | `LocalReportRepository.dailyActivityReport` | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | **36** |
| 2 | `SaleController.load` | 3 | 2 | 2 | 3 | 2 | 1 | 3 | 3 | 3 | 3 | 3 | 2 | **30** |
| 3 | `BackupExportService.createBackup` | 3 | 2 | 0 | 3 | 1 | 1 | 3 | 3 | 1 | 2 | 2 | 1 | **22** |
| 4 | `ProductController.loadProducts` | 3 | 2 | 0 | 2 | 1 | 1 | 3 | 2 | 2 | 2 | 2 | 1 | **21** |

The backup snapshot purpose is clearer than the management projection, but its
six-field-plus-timestamp delta still requires a separate versioned backup
design. No rejected-candidate ranking affects the selected expansion.

## Selected expansion

Selected expansion: LocalReportRepository.dailyActivityReport

The selected design is **Option 1 — Extend Existing Catalog Read Model** with
one field. Reference cost is product master/catalog data, nullable for every
product, already stored on the product row, independent of any report date or
transaction, and reusable without introducing a report-specific name into the
catalog boundary. The current list shape, filter flag, ordering, freshness, and
errors already exactly match the consumer.

Frozen boundary: ProductCatalogReadRepository

Frozen method: listProductCatalog

Frozen read model: ProductCatalogReadModel

Frozen added field: int? referenceCostPricePiastersPerKg

No second consumer is selected. The field happens to appear elsewhere, but
Phase 106I does not widen scope to product management, sales, transactional
sale validation, or backup.

## Rejected candidates

Rejected broader candidate: ProductController.loadProducts

Rejected because matching its edit/display semantics would turn the catalog
model into nearly the entire mutable `Product` domain and would entangle a
read migration with product-management write refreshes.

Rejected broader candidate: SaleController.load

Rejected because it needs two sales-specific nullable prices and feeds a
financial transaction UI. A later sales-selection model can be frozen
independently; adding those fields is a larger, riskier delta than one nullable
reference-cost field.

Rejected broader candidate: BackupExportService.createBackup

Rejected because a faithful export requires every persisted field,
timestamps, stable JSON names, versioning, checksum behavior, and future
restore compatibility. A backup snapshot boundary is not a catalog list.

All A consumers are closed exclusions. All E consumers are excluded by write
or transaction safety. The G consumer is excluded by production
unreachability. There is no B, D, F, or H target.

## Frozen interface

The repository interface remains exactly one operation; no method is added:

```dart
abstract interface class ProductCatalogReadRepository {
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  });
}
```

For the selected consumer the call remains exactly:

```dart
await productCatalogReadRepository.listProductCatalog(
  includeInactive: true,
);
```

The return is a `Future`, never a stream. It is a complete list, never a
nullable single item. Errors propagate unchanged. There is no retry, fallback,
cache, swallowing, or partial result.

No retry, fallback, cache, swallowing, or partial result.

## Frozen read model

The future model is frozen as the current model plus one optional nullable
constructor parameter. Making the parameter optional keeps contract
introduction atomic: existing fakes and accepted consumers remain source
compatible until the Drift adapter begins supplying the column.

```dart
final class ProductCatalogReadModel {
  const ProductCatalogReadModel({
    required this.id,
    required this.name,
    required this.code,
    required this.unit,
    required this.isActive,
    this.referenceCostPricePiastersPerKg,
  });

  final String id;
  final String name;
  final String? code;
  final GrainUnit unit;
  final bool isActive;
  final int? referenceCostPricePiastersPerKg;
}
```

No equality package, JSON support, `copyWith`, timestamps, write behavior,
default/minimum sale price, notes, or speculative field is added.

## Mapping matrix

| Drift / SQLite source | Source type | Read-model field | Dart type | Null policy | Conversion |
| --- | --- | --- | --- | --- | --- |
| `products.id` | non-null text | `id` | `String` | impossible in valid row | none |
| `products.name` | non-null text | `name` | `String` | impossible in valid row | none |
| `products.code` | nullable text | `code` | `String?` | preserve null | none; not interpreted as barcode |
| `products.unit` | non-null text | `unit` | `GrainUnit` | invalid/missing value propagates mapping error | `GrainUnit.fromWireName` |
| `products.isActive` | non-null boolean | `isActive` | `bool` | impossible in valid row | Drift boolean mapping |
| `products.referenceCostPricePiastersPerKg` | nullable integer | `referenceCostPricePiastersPerKg` | `int?` | preserve null; never coerce to zero | none; integer piasters/qirsh per kg remains unchanged |

No kg/ton, EGP/piaster, timestamp, rounding, or sign conversion is introduced.

## Query semantics

- Source table: `FoundationDatabase.products` only.
- Joins: none.
- Selected columns: the five current columns plus
  `products.referenceCostPricePiastersPerKg`.
- Filter: when `includeInactive` is false, `products.isActive == true`; when
  true, no activity predicate is added.
- Selected consumer argument: `includeInactive: true`.
- Ordering: `createdAt ASC, id ASC` with ID as deterministic tie-breaker.
- Search/name/code/category filters: none.
- Limit/pagination: none.
- Deduplication/grouping: none; every product row appears once by primary key.
- Null cost: preserved as null and used by existing report completeness logic.
- Empty database: returns an empty non-growable list.
- No match under active filter: returns an empty non-growable list.
- Freshness: Every invocation performs a fresh source read.
- Failures: query and mapping exceptions propagate unchanged.
- Prohibitions: No product, inventory, or transaction write.

## Non-goals

- No production change in Phase 106I.
- No schema, migration, database-version, generated-code, dependency, or
  lockfile change.
- No new repository method, lookup, search, pagination, aggregate, or stream.
- No change to `includeInactive`, `createdAt ASC, id ASC`, empty-list, failure,
  or fresh-read semantics.
- No migration of the report or another consumer.
- No default/minimum sale price, notes, timestamps, stock, or full `Product`.
- No fallback to `ProductRepository` after the later migration.
- No cloud/mobile implementation.
- No user-database access or native application launch.

Existing accepted consumers continue to use only their current fields. The
new nullable field is inert for Document History, Dashboard Guidance,
Inventory Attention, and Dashboard Service.

## Atomic follow-up plan

1. **Phase 106J — Extend ProductCatalogReadModel with Reference Cost**: add only
   the optional nullable field and contract-level tests; do not modify the
   adapter or consumers.
2. **Phase 106K — Map Reference Cost in the Local Drift Catalog Adapter**: add
   the selected column and exact nullable mapping with isolated in-memory
   adapter tests; do not migrate a consumer.
3. **Phase 106L — Migrate LocalReportRepository to the Expanded Catalog Read**:
   inject the narrow boundary, adapt the report-only calculator input, preserve
   every report result/error/read-order behavior, and remove only that legacy
   product dependency.
4. **Phase 106M — Prove Genuine Runtime Report Integration**: exercise the
   production composition and Drift adapter in isolated in-memory SQLite,
   including null/non-null cost, inactive rows, ordering, fresh read, errors,
   and no writes.
5. **Phase 106N — Accept, Close, and Freeze the Report Migration**: audit
   historical tests and production scope, run all quality gates, and close only
   this consumer.

No follow-up phase is implemented here. The next phase only is:

Phase 106J — Extend ProductCatalogReadModel with Reference Cost

## Verification evidence

| Gate | Result |
| --- | --- |
| Initial baseline and worktree gate | PASS — exact baseline, clean tree, 0 commits after baseline |
| Phase 106I focused test | PASS — 8 passed, 0 failed, 0 skipped |
| Related product-read regression | PASS — 126 passed, 0 failed, 0 skipped across 17 files; 21.3 s wall time |
| Full `flutter test` | PASS — 2062 passed, 0 failed, 1 unchanged historical skip; 165.2 s wall time |
| Skip audit | One unchanged skip in `test/phase9a_inflows_outflows_reports_test.dart`; no new skip |
| `dart format .` | PASS — 387 files checked, 1 Phase 106I test file formatted, 6.31 s formatter time |
| `flutter analyze` | PASS — no issues found; 26.7 s analyzer time |
| `git diff --check` | PASS — exit 0, no output |
| `git diff -- lib` | PASS — empty |
| Windows release | PASS — exit 0; 18.9 s Flutter build time, 20.8 s command wall time |
| Native smoke | NOT RUN — isolation from user database not proven |

Only the report and
`test/phase106i_next_product_read_contract_expansion_discovery_freeze_test.dart`
belong to Phase 106I. The first `dart format .` wrapper attempt timed out before
output because the Flutter SDK lock was inaccessible; invoking the same Dart
3.5.4 SDK executable directly completed successfully. The first sandboxed
Windows build attempt likewise timed out before output; the identical build
outside that SDK-lock restriction completed successfully. No gate was waived.

Windows release artifact:

- Path:
  `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes.
- SHA-256:
  `46BE86384394C48F86D491CA6B29F7FF85FD32E000AD1289A37DF1821B68CF5F`.

The build emitted only the previously known non-fatal Firebase CMake
minimum-version deprecation and `.voltbl` linker warnings.

The user database was not opened, read, copied, or modified.

لم تُفتح أو تُقرأ أو تُنسخ أو تُعدّل قاعدة بيانات المستخدم.

No Push and no Tag are performed.
