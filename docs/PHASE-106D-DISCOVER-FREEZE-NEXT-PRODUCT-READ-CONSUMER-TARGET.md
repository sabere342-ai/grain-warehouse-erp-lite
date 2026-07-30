# Phase 106D — Discover and Freeze the Next Product Read Consumer Target

**Outcome A — FULL SUCCESS**

This report is the governing discovery and freeze record for the next product
read consumer. It does not perform the migration.

## Git baseline

| Item | Value |
| --- | --- |
| Previous branch | `codex/phase-106c-prove-genuine-runtime-dashboard-guidance-product-catalog-read-integration` |
| Phase branch | `codex/phase-106d-discover-freeze-next-product-read-consumer-target` |
| Baseline and starting HEAD | `1293bee8b634c45508da7bb91cd70adaf1a21f34` |
| Baseline subject | `PHASE 106C: prove dashboard guidance runtime product catalog integration` |
| Initial worktree | Clean; no tracked or untracked paths |
| Initial commits after baseline | `0` |
| Final commit | The single Phase 106D commit containing this report; its immutable SHA is recorded in the final handoff because a commit cannot contain its own hash |
| Required commit subject | `PHASE 106D: discover and freeze next product read consumer target` |
| Required final commits after baseline | `1` |
| Push | Not performed |
| Tag | Not created |

The initial gate also proved an empty `git diff --check`. No reset, rebase,
merge, cherry-pick, or history rewrite was used.

## Scope

Phase 106D performs source discovery, runtime-call-chain tracing, candidate
classification, one target selection, and behavioral freezing only. It adds
this report and one structural acceptance test. It does not migrate the
selected consumer, change production composition, expand the read contract,
or change any production behavior.

## Governing references

- Phase 105B introduced and froze `ProductCatalogReadModel` with exactly
  `String id`, `String name`, `String? code`, `GrainUnit unit`, and
  `bool isActive`, plus the single required-argument method
  `listProductCatalog({required bool includeInactive})`.
- Phase 105C implemented `DriftProductCatalogReadRepository`, including strict
  unit mapping, active filtering, and `createdAt ASC, id ASC` ordering without
  schema or migration changes.
- Phase 105D migrated only
  `LocalDocumentHistoryRepository._productNamesById`; Phase 105E proved its
  real in-memory Drift/SQLite runtime path; Phase 105F accepted and froze that
  first pilot.
- Phase 106A inventoried the then-current executable surfaces, selected
  `DashboardGuidanceState.load`, and recorded
  `InventoryAttentionService.loadAttention` as the closest reserve.
- Phase 106B migrated only `DashboardGuidanceState.load` to
  `AppRepositories.productCatalogReadRepository`; Phase 106C proved its
  genuine in-memory Drift/SQLite path and the absence of a legacy fallback.

The two previously migrated consumers are historical constraints and cannot be
selected again.

## Discovery methodology

Discovery used only repository source, tests, documentation, and Git metadata.
The user application and production database were never opened. The principal
searches were:

```text
rg -n --glob "*.dart" "productRepository|ProductRepository|listProducts" lib
rg -n --glob "*.dart" "productCatalogReadRepository|listProductCatalog" lib
rg -n --glob "*.dart" "selectOnly|select\(|getSingleOrNull|getSingle" lib
rg -n --glob "*.dart" "ProductsCompanion|productsTable|productId|productCode|productName|barcode" lib
rg -n --glob "*.dart" "InventoryAttentionService|loadAttention" lib test
rg -n --glob "*.dart" "AppRepositories" lib
```

The current tree contains 24 legacy `.listProducts(` calls in 21 files. Two of
those files are infrastructure (`lib/app/app_repositories.dart` and
`lib/core/catalog/drift_product_repository.dart`), leaving 19 legacy consumer
boundaries. It also contains two executable `.listProductCatalog(` calls: the
two consumers already migrated. Definitions in
`lib/core/catalog/product_repository.dart` and
`lib/core/catalog/product_catalog_read_repository.dart` are contracts, not
consumers.

Every potential consumer was followed upward to a controller, screen, service,
owner workflow, or deliberately isolated tool, and downward through the
runtime repository to the products table. Reads used inside validation,
transactions, restore, wipe, or activation were separated from read-only
catalog projections. Direct table searches found no consumer bypass: direct
product-table access is confined to
`lib/core/catalog/drift_product_repository.dart` and
`lib/core/catalog/drift_product_catalog_read_repository.dart`, plus schema and
migration infrastructure.

The governing Phase 105B–105F and Phase 106A–106C reports and tests were
reviewed. Candidate behavior was also checked against
`test/inventory_attention_service_test.dart`,
`test/inventory_attention_tool_test.dart`,
`test/phase64_owner_dashboard_alerts_test.dart`, dashboard controller/UI tests,
and the Phase 102 profitability tests.

## Complete consumer inventory

| ID | Consumer | File | Method | Trigger | Current read path | Query shape | Fields used | Active policy | Writes nearby | Runtime reachable | Status | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-001 | `LocalDocumentHistoryRepository` | `lib/core/documents/document_history.dart` | `_productNamesById` via `listHistory` | Document history screen/repository | catalog repository → Drift catalog adapter → products | full snapshot | `id`, `name` | includes inactive | none in product read | yes | Already migrated | Exclude: Phase 105D–105F pilot |
| PRC-002 | `DashboardGuidanceState` | `lib/features/dashboard/dashboard_screen.dart` | `load` | `DashboardScreen.didChangeDependencies` | AppRepositories catalog repository → Drift catalog adapter → products | full snapshot, consumes count | list length only | includes inactive | none | yes | Already migrated | Exclude: Phase 106A–106C target |
| PRC-003 | `InventoryAttentionService` | `lib/core/inventory/inventory_attention_service.dart` | `loadAttention` | dashboard controller and owner-alert loader | legacy product repository → Drift product repository → products | full snapshot plus inventory balance map | `id`, `name`, `isActive` | includes inactive | none; local projection only | yes, two dashboard paths | Eligible | **Selected** |
| PRC-004 | `DashboardService` | `lib/core/dashboard/dashboard_service.dart` | `load` | `DashboardController.load` from protected dashboard lifecycle | legacy repository → Drift product repository → products | full snapshot, wheat-name search, emptiness | `id`, `name`, list emptiness | includes inactive | read-only aggregation, but invokes PRC-003 | yes | Eligible but higher risk | Defer: nested second consumer breaks atomicity |
| PRC-005 | `ProductController` | `lib/core/catalog/product_controller.dart` | `loadProducts` | `ProductsScreen.initState` post-frame and write refreshes | legacy read/write repository | permission-shaped full list | all display/edit fields including prices and notes | owner sees all; others active only | create/update/activation use same dependency | yes | Requires broader read contract | Exclude |
| PRC-006 | `InventoryController` | `lib/core/inventory/inventory_controller.dart` | `load` | inventory, stock-take, and adjustment screens | legacy repository plus inventory reads | permission-shaped full list | full `Product` values across three UIs | permission-dependent | movement, valuation, financial, audit writes | yes | Requires broader read contract | Exclude broad multi-screen workflow |
| PRC-007 | `PurchaseController` | `lib/core/purchases/purchase_controller.dart` | `load` | purchases and supplier-purchases screens | legacy repository with suppliers/intakes | permission-shaped full list | `id`, `name`, `isActive` exposed as `Product` | permission-dependent | create/cancel posted purchases | yes | Eligible but higher risk | Exclude transactional controller |
| PRC-008 | `SaleController` | `lib/core/sales/sale_controller.dart` | `load` | sales screen entry and refresh | legacy repository plus stock/customer/account reads | active full list | selection/display product fields | active only | sale, cancellation, stock, money writes | yes | Eligible but higher risk | Exclude transactional controller |
| PRC-009 | `LocalInventoryRepository` | `lib/core/inventory/inventory_repository.dart` | `allProductBalancesKg`, `_findProductById` | inventory queries and movement validation | legacy full-list scan | active-shaped balance keys or ID lookup | `id`, `isActive` | caller-shaped or includes inactive | inventory-ledger writes and restore/wipe | yes | Write-integrity read | Exclude |
| PRC-010 | `DriftInventoryRepository` | `lib/core/inventory/drift_inventory_repository.dart` | `allProductBalancesKg`, `_findProductById` | durable inventory queries and movement validation | legacy full-list scan plus Drift movements | active-shaped balance keys or ID lookup | `id`, `isActive` | caller-shaped or includes inactive | durable ledger writes | yes | Write-integrity read | Exclude |
| PRC-011 | `LocalPurchaseRepository` | `lib/core/purchases/purchase_repository.dart` | `_validateProduct` | purchase posting | legacy full-list ID scan | single lookup through full list | complete `Product` returned; activity checked | includes inactive then rejects inactive | purchase, stock, supplier account writes | yes | Write-integrity read | Exclude |
| PRC-012 | `DriftPurchaseRepository` | `lib/core/purchases/drift_purchase_repository.dart` | `_validateProduct`, `_validateProductExists` | durable post/cancel/restore flows | legacy full-list ID scan | validation lookup | `id`, `isActive`, complete `Product` return | includes inactive | durable financial/inventory transaction | yes | Write-integrity read | Exclude |
| PRC-013 | `LocalSaleRepository` | `lib/core/sales/sale_repository.dart` | `_validateProduct` | sale posting | legacy full-list ID scan | validation lookup | `id`, `isActive`, prices/cost fields through returned `Product` | includes inactive then rejects inactive | sale, COGS, stock, account writes | yes | Requires broader read contract | Exclude |
| PRC-014 | `LocalReportRepository` | `lib/core/reports/report_repository.dart` | `dailyActivityReport` | reports screen/controller | legacy repository plus sales/purchases/inventory | full snapshot and derived maps | `id`, `name`, `unit`, reference cost | includes inactive | read-only but financially derived | yes | Requires broader read contract | Exclude: reference cost absent |
| PRC-015 | `ProfitabilityActivationService` | `lib/core/inventory_valuation/profitability_activation_service.dart` | `activate` | owner profitability activation | legacy repository plus stock/valuation | full snapshot/cardinality | `id` and complete catalog membership | includes inactive | valuation/audit transaction | yes | Write-integrity read | Exclude |
| PRC-016 | `SyntheticProfitabilityActivationService` | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | `activate` | isolated Phase 102J synthetic tool | legacy emptiness read | catalog emptiness | emptiness only | includes inactive | deliberately creates synthetic products and valuation | no production composition | Dead/unreachable | Exclude |
| PRC-017 | `NegativeBalanceApprovalWorkflowService` | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | `_findProduct` / `_requireProduct` | approval submit/revalidation/execution | legacy full-list ID scan | optional/single lookup | complete `Product`; `id`, activity and payload fields | includes inactive | financial approval and posting | yes | Write-integrity read | Exclude high semantic risk |
| PRC-018 | `BackupExportService` | `lib/core/backup/backup_export.dart` | `createBackup` | backup export screen | legacy repository full snapshot | complete serialization | every persisted product field | includes inactive | no product write, but complete backup snapshot | yes | Requires broader read contract | Exclude backup-format boundary |
| PRC-019 | `BackupRestoreService` | `lib/core/backup/backup_restore_service.dart` | `_checkEmptySystem` via `restoreToEmpty` | restore preview/execute | legacy repository emptiness read | full list used for emptiness | emptiness only | includes inactive | atomic multi-repository restore writes | yes | Eligible but higher risk | Exclude restore safety path |
| PRC-020 | `BusinessDataWipeService` | `lib/core/backup/business_data_wipe_service.dart` | `_currentCounts` via `wipeBusinessData` | owner wipe screen | legacy repository full list | count | list length only | includes inactive | backup followed by destructive wipe | yes | Eligible but higher risk | Exclude destructive path |
| PRC-021 | `_ProfitabilityReportScreenState` | `lib/features/financial_reports/profitability_report_screen.dart` | `_activate` | owner presses activation button | AppRepositories legacy repository → Drift product repository | full snapshot supplied to dialog | dialog uses `id`, `name`; service later validates openings | includes inactive | launches profitability activation write | yes | Eligible but higher risk | Defer UI/financial coupling |

Infrastructure reviewed but not assigned consumer IDs:

- `lib/app/app_repositories.dart` composes both repository surfaces and contains
  the in-memory legacy bridge used before production initialization.
- `lib/core/catalog/product_repository.dart` defines the broad read/write
  contract and in-memory implementation.
- `lib/core/catalog/drift_product_repository.dart` is the legacy Drift data
  source; its snapshot holder is transaction infrastructure, not an end
  consumer.
- `lib/core/catalog/product_catalog_read_repository.dart` is the frozen
  contract, and
  `lib/core/catalog/drift_product_catalog_read_repository.dart` is its adapter.

## Candidate analysis

### `InventoryAttentionService.loadAttention` — eligible and selected

Runtime path: protected dashboard lifecycle → either `OwnerAlertData.load` or
`DashboardController.load`/`DashboardService.load` → selected service → legacy
product repository → Drift/SQLite products, followed by the inventory balance
read. It uses only `id`, `name`, and `isActive`, all present without conversion
in the frozen model. Its product dependency is read-only, and the existing
tests isolate classification, ordering, immutability, empty results, and tool
error handling. The migration will require narrow wiring changes, but it still
changes one consumer method only.

### `DashboardService.load` — eligible but higher risk

The dashboard constructs the service in `DashboardScreen.initState`, then
`didChangeDependencies` invokes `DashboardController.load`. The method reads
all products with `includeInactive: true`, finds the first name containing
Arabic or English wheat text, uses its `id` for a balance, and uses catalog
emptiness for `hasData`. The frozen fields fit, but the same method invokes a
default `InventoryAttentionService`, producing a second product read. Migrating
both would violate one-consumer atomicity; migrating only the direct read would
need parallel old/new product dependencies and leave the nested bypass.

### `_ProfitabilityReportScreenState._activate` — eligible but higher risk

The owner button reads all active and inactive products, reads balances, shows
an activation dialog, then sends `OpeningValuationInput` values into a
financially sensitive activation transaction. The dialog currently uses only
product `id` and `name`, so the frozen contract can represent this read, but
the UI type boundary, mounted checks, cancellation, loading state, error state,
and subsequent write make it a riskier next step.

### `BackupRestoreService._checkEmptySystem` — compatible but excluded

The product value is used only to determine whether the target is empty, so the
contract is sufficient. The read is an integrity gate immediately preceding an
atomic restore across repositories and backup formats. It should not be the
next cloud/mobile catalog pilot.

### `BusinessDataWipeService._currentCounts` — compatible but excluded

Only the complete product count is consumed, and `includeInactive: true` is
correct. The method is embedded in the backup-before-destructive-wipe workflow;
low frequency and extreme consequence outweigh its small apparent read diff.

All other consumers either expose a complete editable `Product`, require price
or cost data absent from the frozen model, validate product integrity inside a
write transaction, combine multiple screens, or are not production reachable.
No contract widening is authorized.

## Scoring matrix

Scores use the required `0..3` scale. Higher is better; total is evidence, not
an automatic decision.

| Candidate | Atomic isolation | Catalog-read fit | Runtime importance | Testability | Production diff size | Contract compatibility | Regression risk | No-write separation | Mobile/cloud value | Evidence readiness | Total / 30 | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `InventoryAttentionService.loadAttention` | 2 | 3 | 3 | 3 | 2 | 3 | 3 | 3 | 3 | 3 | **28** | Selected |
| `DashboardService.load` | 1 | 3 | 3 | 2 | 1 | 3 | 1 | 3 | 2 | 3 | **22** | Defer: nested consumer |
| `_ProfitabilityReportScreenState._activate` | 2 | 3 | 2 | 1 | 2 | 3 | 1 | 1 | 2 | 2 | **19** | Defer: UI/write coupling |
| `BackupRestoreService._checkEmptySystem` | 2 | 3 | 1 | 2 | 2 | 3 | 0 | 1 | 1 | 2 | **17** | Exclude: restore integrity |
| `BusinessDataWipeService._currentCounts` | 2 | 3 | 1 | 2 | 2 | 3 | 0 | 0 | 1 | 2 | **16** | Exclude: destructive workflow |

## Selected target

Selected target: InventoryAttentionService.loadAttention

Selected next product read consumer:
`InventoryAttentionService.loadAttention` in
`lib/core/inventory/inventory_attention_service.dart`.

## Selection rationale

The selected method is the best next atomic boundary because it is a reusable,
read-only domain projection reached twice by the production owner dashboard,
not merely a syntactically convenient call. It removes a broad write-capable
product dependency from a service that never writes products. Its exact fields
(`id`, `name`, `isActive`) are a strict subset of the frozen read model; no
price, cost, stock field, supplier/customer field, schema change, or new query
operation is required.

Compared with `DashboardService.load`, it does not own the broader financial
dashboard aggregation and does not contain a nested second consumer. Compared
with the profitability, restore, and wipe candidates, its side-effect boundary
is unambiguously read-only and its failure/empty/order behavior already has
focused tests. Four future wiring sites are more code than the one-file Phase
106B migration, but the semantic surface remains one consumer.

## Frozen current runtime path

Production path A:

```text
DashboardShell
→ DashboardScreen.didChangeDependencies
→ OwnerAlertData.load
→ InventoryAttentionService.loadAttention
→ ProductRepository.listProducts(includeInactive: true)
→ ProductDataRepository / DriftProductRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
→ InventoryRepository.allProductBalancesKg()
```

Production path B:

```text
DashboardShell
→ DashboardScreen.didChangeDependencies
→ DashboardController.load
→ DashboardService.load
→ InventoryAttentionService.loadAttention
→ ProductRepository.listProducts(includeInactive: true)
→ ProductDataRepository / DriftProductRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
→ InventoryRepository.allProductBalancesKg()
```

`InventoryAttentionTool.execute` also calls the same reader abstraction, but
the concrete tool is only exported and test-composed in the current tree; it is
not used as the proof of production reachability.

## Frozen Migration Contract

### Identity

```text
Consumer class: InventoryAttentionService
Consumer method: loadAttention
Source file: lib/core/inventory/inventory_attention_service.dart
Trigger: protected owner DashboardScreen.didChangeDependencies through two dashboard paths
```

### Current query semantics

- Exactly one product snapshot is awaited first through
  `ProductRepository.listProducts(includeInactive: true)`.
- `includeInactive: true` means active and inactive products participate; the
  service does not filter inactive products. The output preserves each
  qualifying product's `isActive` value.
- The complete inventory balance map is awaited second through
  `InventoryRepository.allProductBalancesKg()` with its default
  `activeProductsOnly: false` semantics.
- Product/balance association is by textual product ID. A missing balance is
  treated as `0` kilograms.
- There is no pagination, search, barcode/code lookup, repository-side sort,
  fallback, cache, stream, or retry.

### Data dependencies

The consumer reads exactly:

```text
String id
String name
bool isActive
```

`String? code` and `GrainUnit unit` remain valid frozen model fields but are not
read by this consumer. Price, minimum price, reference cost, notes, timestamps,
stock, balances, suppliers, customers, and financial computations are not
requested from the product contract. Inventory quantities remain owned by
`InventoryRepository`.

### Classification and ordering

- `quantityKg <= 0` becomes `InventoryAttentionType.outOfStock`.
- `1..5 kg` becomes `InventoryAttentionType.lowStock` because
  `lowStockMaximumKg == 5`.
- Values above `5 kg` are omitted.
- Results sort by attention-type enum index, then quantity ascending, product
  name ascending, then textual product ID ascending.
- The returned list is unmodifiable.

### State behavior

- Loading: the service owns no loading flag and emits no notification; its
  single `Future` remains pending while the two reads complete.
- Success: a fresh unmodifiable projection is returned on every invocation.
- Empty: no products, or no qualifying products, returns an empty unmodifiable
  list. Missing balances are not empty; they classify as out of stock.
- Error: the service has no `try/catch`; product-read and balance-read failures
  propagate through the returned `Future` unchanged.
- Retry: No retry. A caller retry is a completely fresh invocation.
- Cache: No cache, append, merge, retained snapshot, `setState`, or
  `notifyListeners`.

The two wrappers keep their current behavior. `DashboardController.load`
converts a failure from its `DashboardService` path to the existing dashboard
error state. `OwnerAlertsSection` shows no widget while its `FutureBuilder` is
pending and uses `OwnerAlertData.empty()` when a completed snapshot has no
data, including its current error presentation. Phase 106E must not change
these UI/lifecycle rules.

### Side-effect boundary

`loadAttention` is read-only. It performs no product, inventory, audit,
analytics, transaction, or persistence write. It allocates and sorts a local
list only. The surrounding dashboard consumers change controller/widget state,
but the selected service itself has no state. The product read must remain
before the inventory-balance read.

### Migration invariants

- UI, Arabic text, dashboard lifecycle, permissions, and callers unchanged.
- Exactly one selected consumer migrated in the future phase.
- `includeInactive: true`, read order, classification thresholds, missing-zero
  behavior, output fields, ordering, immutability, empty behavior, and error
  propagation unchanged.
- No fallback to `ProductRepository` after migration.
- No change to inventory reads or inventory writes.
- No contract, adapter, schema, migration, generated Drift, backup, financial,
  or other consumer change.
- No new cache, stream, pagination, search, retry, loading, or error behavior.

## Required future migration shape

Phase 106E is expected to produce this shape and no broader migration:

```text
Dashboard callers
→ InventoryAttentionService.loadAttention
→ AppRepositories.productCatalogReadRepository
→ listProductCatalog(includeInactive: true)
→ DriftProductCatalogReadRepository
→ Drift / SQLite products table
```

This report does not implement that path. Future wiring must provide the frozen
interface to the service without migrating `DashboardService.load`'s separate
direct product read and without changing any classification or UI behavior.

## Explicit exclusions

Phase 106D excludes all production edits, the actual PRC-003 migration, either
previously migrated consumer, `DashboardService.load`, controllers, product
writes, validation reads, direct database refactoring, contract/model/adapter
changes, schema/migrations/generated files, backup formats, financial logic,
profitability activation, Audit Log behavior, UI/lifecycle/text changes,
dependencies, cloud/sync implementation, native smoke, push, and tag.

## Production diff

No production code changes.
No diff under lib/.

Only these two Phase 106D files are permitted:

```text
test/phase106d_next_product_read_consumer_target_discovery_freeze_test.dart
docs/PHASE-106D-DISCOVER-FREEZE-NEXT-PRODUCT-READ-CONSUMER-TARGET.md
```

## Tests

The Phase 106D structural acceptance test proves:

1. the exact baseline exists and the current Phase 106D tree has no `lib/`
   diff or status entry;
2. the exact set of 19 legacy consumer files and two migrated consumer files;
3. all 21 stable `PRC-xxx` inventory records appear in this report;
4. exactly one target is selected, and the Phase 105/106 targets are excluded;
5. the selected class, method, legacy `ProductRepository` field, one
   `listProducts` call, and `includeInactive: true` remain present;
6. `productCatalogReadRepository` and `listProductCatalog` are still absent
   from the selected consumer, proving Phase 106E has not started;
7. `id`, `name`, `isActive`, balance merge, missing-zero behavior,
   classification thresholds, ordering, and immutable output are frozen;
8. the selected method contains no write, cache, retry, or error-catching path;
9. both production dashboard call chains are source-reachable; and
10. this report includes the complete frozen contract and the non-executed
    future migration shape.

## Verification results

| Gate | Actual result |
| --- | --- |
| Phase 106D focused | PASS — 8 passed, 0 failed, 0 skipped; 9.3 s wall time |
| Phase 106A | PASS — 7 passed, 0 failed, 0 skipped; 4.7 s wall time |
| Phase 106B | PASS — 9 passed, 0 failed, 0 skipped; 6.4 s wall time |
| Phase 106C | PASS — 7 passed, 0 failed, 0 skipped; 5.3 s wall time |
| Phase 105B–105F regressions | PASS — 37 passed, 0 failed, 0 skipped; 8.0 s wall time |
| Selected consumer regressions | PASS — 22 passed across `inventory_attention_service_test.dart`, `inventory_attention_tool_test.dart`, and `phase64_owner_dashboard_alerts_test.dart`; 0 failed, 0 skipped; 6.2 s wall time |
| Related dashboard regressions | PASS — 60 passed across six dashboard/UI files; 0 failed, 0 skipped; 13.0 s wall time |
| Audit Log repository-boundary regressions | PASS — 46 passed, 0 failed, 0 skipped; 12.2 s wall time |
| Phase 102 sensitive regressions | PASS — 61 passed, 0 failed, 0 skipped; 8.3 s wall time |
| Formatter | PASS — 382 Dart files checked, 0 changed; 4.17 s formatter time |
| Analyzer | PASS — `No issues found!`; 78.8 s analyzer time |
| Full suite | PASS — 2016 passed, 0 failed, 1 unchanged historical skip; 144.2 s wall time |
| Windows release | PASS — 24.8 s Flutter build, 26.8 s wall time; exit 0 |
| Production diff | PASS — no path under `lib/` |

The related dashboard run used
`phase12_help_guidance_test.dart`,
`competition04_dashboard_readiness_test.dart`,
`phase37c_dashboard_labels_test.dart`,
`phase36_supplier_accounts_dashboard_test.dart`,
`phase36e_supplier_payment_ui_test.dart`, and
`phase36g_ui_clarity_cancellation_safety_test.dart`.

The Audit Log run used Phase 8I and Phases 104B, 104C, 104E, 104F, 104G,
104H, and 104J. The Phase 102 run used Phase 102J, Phase 102C, and all five
Phase 102B files. The full suite retained the same single historical skip in
`phase9a_inflows_outflows_reports_test.dart`; Phase 106D adds no skip.

The first sandboxed Windows build attempt reached the 360-second command
timeout without a compiler diagnostic because SDK/build-tool access was
constrained. Re-running the same command with the required Flutter SDK and
MSVC access succeeded. The successful build emitted the existing non-fatal
Firebase CMake minimum-version deprecation warning and MSVC `LNK4078`
`.voltbl` warning.

Windows artifact:

| Item | Value |
| --- | --- |
| Path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| Size | `784384` bytes |
| SHA-256 | `C1864E15A94962982E646DBE144E26344060A97485CA4778036B1D44668723FE` |
| Build timestamp | `2026-07-30 16:43:32` local time |

The executable was built but not launched. Native smoke was not run because
isolation from the user's production database is not proven.

## User database safety

Discovery did not open, read, copy, resolve, or modify the user production
database. No application executable was launched. Tests that require SQLite
must use the repository's in-memory test database only. Native smoke is not run
because native-launch isolation from the user's database is not proven.

## Residual risks

- Phase 106E must prove genuine runtime composition through the real Drift
  adapter after migration; Phase 106D proves current reachability only.
- The service is constructed in more than one production location, so future
  wiring must cover both dashboard paths without changing the separate direct
  product read in `DashboardService.load`.
- Inactive products and missing balances intentionally produce attention items;
  an accidental active-only read would be a behavioral regression.
- `OwnerAlertsSection` currently masks a completed failed alert future as empty
  data; this discovery freezes rather than redesigns that behavior.
- The AI tool wrapper is not currently production-composed and cannot replace
  the two dashboard paths as runtime evidence.
- Native smoke remains unexecuted.

## Next atomic phase

**Phase 106E — Migrate InventoryAttentionService.loadAttention to Product Catalog Read Contract**
