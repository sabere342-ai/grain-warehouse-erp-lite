# Phase 106F — Discover and Freeze the Next Product Read Consumer Target

## Outcome

**Outcome A — FULL SUCCESS**

Phase 106F performs discovery, classification, selection, and behavioral
contract freezing only. It does not migrate the selected consumer. The single
frozen next target is `DashboardService.load`.

## Git baseline and scope

| Item | Value |
| --- | --- |
| Previous branch | `codex/phase-106e-migrate-inventory-attention-to-product-catalog-read-contract` |
| Phase branch | `codex/phase-106f-discover-freeze-next-product-read-consumer-target` |
| Starting baseline / HEAD | `9f97637b71b91529a17faa7c2ce316294da02ac7` |
| Baseline subject | `PHASE 106E: migrate inventory attention to product catalog read contract` |
| Initial worktree | Clean |
| Initial commits after baseline | `0` |
| Initial `git diff --check` | PASS |
| Required final subject | `PHASE 106F: discover and freeze next product read consumer target` |
| Final commit | The single Phase 106F commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Required final commit count | Exactly `1` after baseline |

In scope: inspect the actual source and runtime composition, inventory every
product read consumer, classify each consumer exactly once, compare eligible
targets, select one production-reachable target, freeze its existing behavior,
and add one architecture guard test plus this report.

Explicit non-goals: no production migration, no constructor or provider
change, no repository or model change, no new contract method, no schema or
migration change, no UI behavior change, no legacy removal, no mobile/cloud
work, and no unrelated cleanup. No file under `lib/` is changed.

## Governing frozen architecture

The Phase 105B–105F boundary remains:

```text
ProductCatalogReadRepository.listProductCatalog
→ DriftProductCatalogReadRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

`ProductCatalogReadModel` remains exactly `String id`, `String name`, nullable
`String code`, `GrainUnit unit`, and `bool isActive`. The sole operation remains
`listProductCatalog({required bool includeInactive})`. The Drift adapter returns
a fresh, growable-false list ordered by `createdAt ASC, id ASC`; it filters on
`isActive` only when `includeInactive` is false.

The three prior migrated consumers are frozen exclusions:

1. `LocalDocumentHistoryRepository._productNamesById` via `listHistory`.
2. `DashboardGuidanceState.load`.
3. `InventoryAttentionService.loadAttention`.

The Phase 106E runtime path is present and removes the nested legacy product
read that made `DashboardService.load` unsuitable in Phase 106D.

## Discovery methodology

Discovery used Git metadata, source inspection, existing tests, and the prior
Phase 105B–106E reports. Principal searches included:

```text
rg -n "ProductRepository|ProductDataRepository|DriftProductRepository|listProducts|listProductCatalog|getProduct|findProduct|watchProducts|productRepository|productCatalogReadRepository" lib test
rg -n --glob "*.dart" "\.listProducts\(|\.listProductCatalog\(|_findProduct\(" lib
rg -n "defaultSalePricePiastersPerKg|minimumSalePricePiastersPerKg|referenceCostPricePiastersPerKg|\.notes|\.unit|\.code|\.isActive|\.name|\.id" lib/features
```

Text matches were not accepted as consumers without tracing the entry point,
consumer method, dependency, called operation, returned type, downstream use,
and production composition. Contract declarations, adapters, and transaction
snapshot infrastructure were inspected but kept separate from the consumer
count.

At the Phase 106E baseline there are 18 legacy consumer files containing an
executable `.listProducts(` call and three migrated consumer files containing
an executable `.listProductCatalog(` call. Together they form 21 product-read
consumer boundaries. No `watchProducts` stream and no public `getProduct` or
`findProduct` repository operation exists in production source. Private
full-list ID scans are classified below as transactional or single-item safety
lookups, not as catalog list candidates.

Infrastructure, not consumer rows:

- `lib/app/app_repositories.dart` composes `ProductDataRepository`,
  `ProductCatalogReadRepository`, `DriftProductRepository`, and
  `DriftProductCatalogReadRepository`; its legacy bridge maps the broad model
  into the frozen model for pre-production in-memory composition.
- `lib/core/catalog/product_repository.dart` defines the broad read/write
  contract and local implementation.
- `lib/core/catalog/drift_product_repository.dart` is the legacy Drift adapter;
  `_DriftProductSnapshot.capture` is rollback infrastructure.
- `lib/core/catalog/product_catalog_read_repository.dart` and
  `lib/core/catalog/drift_product_catalog_read_repository.dart` are the frozen
  read contract and adapter.

## Complete consumer inventory

Every row has one A–H classification. “Stock” means downstream behavior uses
the inventory boundary; it does not imply that stock may be added to the
catalog contract.

| ID | Consumer / method | File | Entry point | Current dependency / method | Return type | Read shape / fields actually used | Inactive | Stock | Price | Cost | Write coupling | Runtime | Migration | Class | Risk | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-001 | `LocalDocumentHistoryRepository._productNamesById` via `listHistory` | `lib/core/documents/document_history.dart` | document-history screen/controller | catalog / `listProductCatalog` | `List<ProductCatalogReadModel>` | full list; `id`, `name` | yes | no | no | no | no | yes | migrated | A | low | Phase 105D–105F pilot |
| PRC-002 | `DashboardGuidanceState.load` | `lib/features/dashboard/dashboard_screen.dart` | protected dashboard `didChangeDependencies` | catalog / `listProductCatalog` | `List<ProductCatalogReadModel>` | count only | yes | no | no | no | no | yes | migrated | A | low | Phase 106B–106C target |
| PRC-003 | `InventoryAttentionService.loadAttention` | `lib/core/inventory/inventory_attention_service.dart` | dashboard data and owner alerts | catalog / `listProductCatalog` | `List<ProductCatalogReadModel>` | `id`, `name`, `isActive` plus separate balance map | yes | separate repository | no | no | no | yes | migrated | A | low | Phase 106D–106E target |
| PRC-004 | `DashboardService.load` | `lib/core/dashboard/dashboard_service.dart` | `DashboardScreen` → `DashboardController.load` | `ProductRepository.listProducts` | `List<Product>` | list emptiness and first wheat-like `id`, `name`; balances stay separate | yes | separate repository | no | no | no | yes | not migrated | B | low-medium | exact frozen-model fit; former nested blocker is migrated |
| PRC-005 | `ProductController.loadProducts` | `lib/core/catalog/product_controller.dart` | products-management screen and refreshes | `ProductRepository.listProducts` | `List<Product>` | editable full product including code, unit, prices, cost, notes | permission | no | yes | yes | same controller writes | yes | not migrated | D | high | frozen model omits editable price/cost/notes metadata |
| PRC-006 | `InventoryController.load` | `lib/core/inventory/inventory_controller.dart` | inventory, stock-take, adjustment-report screens | `ProductRepository.listProducts` | `List<Product>` | catalog identity exposed across three stateful inventory UIs | permission | yes | no | valuation flow | adjustments/valuation/audit | yes | not migrated | E | high | shared state is coupled to inventory writes and financial activation |
| PRC-007 | `PurchaseController.load` | `lib/core/purchases/purchase_controller.dart` | purchases and supplier-purchases screens | `ProductRepository.listProducts` | `List<Product>` | `id`, `name`, `isActive` in selection/display | permission | indirect | no | no | create/cancel purchase lifecycle | yes | not migrated | E | high | load and refresh are coupled to posted purchase writes |
| PRC-008 | `SaleController.load` | `lib/core/sales/sale_controller.dart` | sales screen entry and refresh | `ProductRepository.listProducts` | `List<Product>` | active products, `id`, `name`, default/minimum prices | no | yes | yes | no | sale/cancellation/payment writes | yes | not migrated | D | high | required sales prices are absent from frozen model |
| PRC-009 | `LocalInventoryRepository.allProductBalancesKg` / `_findProductById` | `lib/core/inventory/inventory_repository.dart` | inventory queries and movement validation | `ProductRepository.listProducts` | `List<Product>` | active-shaped ID set or one product by ID | caller-shaped | yes | no | no | movement/restore/wipe safety | yes | not migrated | E | high | transaction-integrity and write validation reads |
| PRC-010 | `DriftInventoryRepository.allProductBalancesKg` / `_findProductById` | `lib/core/inventory/drift_inventory_repository.dart` | durable inventory queries and movement validation | `ProductRepository.listProducts` | `List<Product>` | active-shaped ID set or one product by ID | caller-shaped | yes | no | no | durable ledger writes | yes | not migrated | E | high | transaction-integrity and single-item validation reads |
| PRC-011 | `LocalPurchaseRepository._validateProduct` | `lib/core/purchases/purchase_repository.dart` | purchase posting | `ProductRepository.listProducts` | `List<Product>` → one `Product` | ID lookup and active validation | yes then rejects inactive | yes | no | possible valuation | purchase/stock/account write | yes | not migrated | E | high | transactional safety read |
| PRC-012 | `DriftPurchaseRepository._validateProduct` / `_validateProductExists` | `lib/core/purchases/drift_purchase_repository.dart` | durable post/cancel/restore flows | `ProductRepository.listProducts` | `List<Product>` → one/boolean | ID lookup and activity/existence validation | yes | yes | no | possible valuation | durable multi-repository transaction | yes | not migrated | E | high | transactional safety read |
| PRC-013 | `LocalSaleRepository._validateProduct` | `lib/core/sales/sale_repository.dart` | sale posting | `ProductRepository.listProducts` | `List<Product>` → one `Product` | ID, active, price and cost fields | yes then rejects inactive | yes | yes | yes | sale/COGS/stock/account write | yes | not migrated | E | high | transactional pricing and costing safety read |
| PRC-014 | `LocalReportRepository.dailyActivityReport` | `lib/core/reports/report_repository.dart` | reports screen/controller | `ProductRepository.listProducts` | `List<Product>` | `id`, `name`, `unit`, reference cost | yes | yes | no | yes | no product write | yes | not migrated | D | high | reference cost is absent from frozen model |
| PRC-015 | `ProfitabilityActivationService.activate` | `lib/core/inventory_valuation/profitability_activation_service.dart` | owner profitability activation | `ProductRepository.listProducts` | `List<Product>` | complete membership and IDs against physical stock | yes | yes | no | opening cost input | valuation/audit transaction | yes | not migrated | E | high | atomic activation safety read |
| PRC-016 | `SyntheticProfitabilityActivationService.activate` | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | isolated synthetic Phase 102 tool | `ProductDataRepository.listProducts` | `List<Product>` | emptiness only | yes | yes | no | yes | creates synthetic catalog/valuation | no production composition | not migrated | H | high | test/tool-only sandbox flow |
| PRC-017 | `NegativeBalanceApprovalWorkflowService._findProduct` / `_requireProduct` | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | approval request/revalidation/execution | `ProductRepository.listProducts` | `List<Product>` → optional/required one | ID lookup, active and payload evidence | yes | transaction payload | possible | possible | financial approval/posting | yes | not migrated | E | high | single-item lookup embedded in transaction safety |
| PRC-018 | `BackupExportService.createBackup` | `lib/core/backup/backup_export.dart` | backup export workflow | `ProductRepository.listProducts` | `List<Product>` | every persisted product field | yes | snapshot | yes | yes | complete backup snapshot | yes | not migrated | D | high | frozen model cannot preserve backup format |
| PRC-019 | `BackupRestoreService._checkEmptySystem` via `restoreToEmpty` | `lib/core/backup/backup_restore_service.dart` | restore preview/execute | `ProductDataRepository.listProducts` | `List<Product>` | emptiness only | yes | safety gate | no | no | atomic multi-repository restore | yes | not migrated | E | high | restore-integrity gate cannot be a catalog pilot |
| PRC-020 | `BusinessDataWipeService._currentCounts` via `wipeBusinessData` | `lib/core/backup/business_data_wipe_service.dart` | owner wipe workflow | `ProductDataRepository.listProducts` | `List<Product>` | count only | yes | no | no | no | backup then destructive wipe | yes | not migrated | E | high | destructive workflow coupling dominates trivial shape |
| PRC-021 | `_ProfitabilityReportScreenState._activate` | `lib/features/financial_reports/profitability_report_screen.dart` | owner activation button | `AppRepositories.productRepository.listProducts` | `List<Product>` | dialog uses `id`, `name`, paired with balances/openings | yes | yes | no | user-supplied cost | immediately invokes activation write | yes | not migrated | E | high | UI read is inseparable from financial activation workflow |

## Classification distribution

- A — Already migrated: 3
- B — Eligible with current frozen contract: 1
- C — Eligible but higher migration risk: 0
- D — Requires broader read contract: 4
- E — Write-coupled or transactional safety read: 12
- F — Single-item lookup requiring another contract: 0
- G — Stream/watch consumer: 0
- H — Not production reachable: 1

The classifications are mutually exclusive. Where more than one exclusion
could apply, the strongest safety boundary wins: transactional/write coupling
is E, missing data is D, and production unreachability is H. Private single-ID
scans inside transactions remain E rather than F because consistency with the
write is the governing constraint.

## Eligible candidate comparison

Only B and C consumers may enter this comparison. After Phase 106E there is
one such consumer, so the ranking is unambiguous.

Scores are 0–3, where 3 is best.

| Rank | Candidate | Contract fit | Behavior | Reachability | Read-only | Isolation | Testability | Blast radius | Error clarity | Order clarity | Inactive clarity | Re-read clarity | Atomicity | Total / 36 |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | `DashboardService.load` | 3 | 3 | 3 | 3 | 3 | 3 | 2 | 3 | 3 | 3 | 3 | 3 | **35** |

The product subread is isolated in one local variable and the constructor
already receives `ProductCatalogReadRepository` for the now-migrated nested
attention service. A future migration can reuse that injected boundary, remove
the broad product dependency from this service, and leave every non-product
repository call unchanged. No new provider, adapter, repository join, schema,
or contract operation is needed.

`DashboardService.load` does read an existing inventory balance map to compute
wheat stock. That stock remains owned by `InventoryRepository`; the frozen
catalog model is not asked to provide quantity. The migration replaces only
the product-catalog half of the existing computation and therefore introduces
no new cross-boundary merge.

## Selected target

Selected target: DashboardService.load

- Class: `DashboardService`
- Method: `Future<DashboardData> load()`
- File: `lib/core/dashboard/dashboard_service.dart`
- Classification: B — Eligible with current frozen contract
- Current broad dependency: injected `ProductRepository`, stored as
  `_productRepository`
- Current repository call:
  `_productRepository.listProducts(includeInactive: true)`
- Returned model today: `List<Product>`
- Frozen replacement model: `List<ProductCatalogReadModel>`

This is not selected merely because its call is short. The protected
production dashboard lifecycle constructs the concrete service and calls it;
its product read affects `wheatStockKg` and `hasData`. It became the safest
remaining target only after Phase 106E moved the nested
`InventoryAttentionService.loadAttention` read to the frozen boundary.

## Frozen behavioral contract

### Dependency and composition

`DashboardScreen.initState` creates `DashboardController(service:
DashboardService(...))`. It injects both
`AppRepositories.productRepository` and the already available
`AppRepositories.productCatalogReadRepository`. Production initialization
binds these to `DriftProductRepository(database)` and
`DriftProductCatalogReadRepository(database)` respectively. The selected
method currently uses only the broad dependency for its direct product read.

### Repository call and include-inactive semantics

- Exactly one direct legacy product-list call per `load` invocation.
- Argument is exactly `includeInactive: true`.
- Active and inactive products participate in wheat detection and catalog
  non-emptiness.
- No filter is applied before the wheat-name predicate.
- No stream/watch behavior exists.

### Data semantics and field-by-field fit

| Frozen field | Selected use | Compatibility |
| --- | --- | --- |
| `String id` | key into the separately read inventory balance map | exact |
| `String name` | wheat-like substring matching | exact |
| `String? code` | ignored | harmless surplus |
| `GrainUnit unit` | ignored | harmless surplus |
| `bool isActive` | ignored because inactive products are intentionally included | harmless surplus |

No default sale price, minimum price, reference cost, notes, timestamps,
supplier/category metadata, unit conversion, or full `Product` behavior is
used. Product names and IDs are non-null in both models. Nullable code is not
read and therefore needs no fallback. Units are not converted by the consumer.

### Filtering, duplicate-like data, and ordering semantics

The exact predicate remains three case-sensitive substring checks on `name`:
the existing Arabic wheat token, the existing leading-space/capitalized
English token, or lowercase `wheat`. Phase 106G must preserve these strings
without normalization or broadening.

Matches are materialized in source order and the first match wins. There is no
deduplication. Duplicate-like wheat names therefore remain distinct, and the
first row under `createdAt ASC, id ASC` determines `wheatStockKg`. Both the
legacy Drift adapter and frozen catalog adapter already share that ordering.

### Result, empty-state, and stock semantics

The product list is local and never returned or mutated. If there is no wheat
match, `wheatStockKg` remains zero. If the first matching ID has no balance,
`balances[id] ?? 0` yields zero. `hasData` is true when either the complete
product list is non-empty or the complete sales list is non-empty. An empty
catalog with no sales therefore produces `hasData == false`; an inactive-only
catalog still produces `hasData == true`.

The existing `InventoryRepository.allProductBalancesKg()` call, its result,
and all inventory semantics are outside the product migration and must remain
unchanged.

### Error, retry, fallback, cache, and re-read semantics

- Repository exceptions propagate out of `DashboardService.load` unchanged.
- `DashboardController.load` catches them, clears loading, and exposes the
  existing generic dashboard error message.
- No retry.
- No fallback.
- No cache.
- Each invocation rereads products and every other dashboard source.
- Reads execute sequentially in their current order; Phase 106G must not add
  concurrency or reorder failures.

### Write and side-effect proof

The selected method calls only read methods and constructs `DashboardData`.
There is No product write, no inventory write, no transaction, no audit log,
no persistence mutation, and no direct table access. Its only observable
state handling occurs later in `DashboardController`, which publishes loading,
data, or error notifications; that controller behavior is frozen unchanged.

## Runtime reachability proof

Current production path:

```text
DashboardShell
→ DashboardScreen.didChangeDependencies
→ DashboardController.load
→ DashboardService.load
→ ProductRepository.listProducts(includeInactive: true)
→ AppRepositories.productRepository
→ ProductDataRepository / DriftProductRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

The protected lifecycle runs once when an authenticated user has
`canViewFinancialReports`. `DashboardController` stores `service.load` as its
default `_loadData` callback and awaits it.

Expected Phase 106G production path:

```text
DashboardShell
→ DashboardScreen.didChangeDependencies
→ DashboardController.load
→ DashboardService.load
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

The already migrated nested attention path remains independently:

```text
DashboardService.load
→ InventoryAttentionService.loadAttention
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ DriftProductCatalogReadRepository
```

Phase 106G migrates only the direct read owned by `DashboardService.load`; it
does not merge, remove, cache, or otherwise alter the nested attention read.

## Reasons other candidates were rejected

- The three A consumers are already migrated and cannot be selected again.
- Product management, sales, reporting, and backup export require full-model
  price, cost, note, timestamp, or serialization data absent from the frozen
  model.
- Inventory, purchase, sale, profitability, approval, restore, and wipe reads
  are coupled to writes or transaction-integrity gates.
- The profitability activation UI immediately feeds a financially sensitive
  write and combines catalog values with stock and cost input.
- The synthetic activation service is not production-composed.
- Private ID scans need dedicated lookup/safety treatment; widening the frozen
  list contract is forbidden.
- No stream/watch consumer exists.

## Required Phase 106G shape

Phase 106G may migrate only the direct product read in
`DashboardService.load` to the already injected
`ProductCatalogReadRepository`. It must preserve include-inactive, predicate,
ordering, first-match, empty, error, sequential-read, stock lookup, `hasData`,
controller, and nested attention behavior. It must not alter the frozen model
or adapter, migrate another consumer, add a query, change dashboard UI, or
change persistence.

Required runtime proof uses a real isolated in-memory Drift/SQLite database
through `AppRepositories.productCatalogReadRepository` and
`DriftProductCatalogReadRepository`; a fake-only test is insufficient.

## Files changed

Only these files belong to Phase 106F:

- `docs/PHASE-106F-DISCOVER-FREEZE-NEXT-PRODUCT-READ-CONSUMER-TARGET.md`
- `test/phase106f_next_product_read_consumer_target_discovery_freeze_test.dart`

Staged diff before commit: 2 files changed, 733 insertions, 0 deletions
(report: 423/0; test: 310/0). No diff under `lib/`. No existing test helper
is changed.

## Commands executed

The phase records the required initial Git gate, branch creation, repository
searches, focused and regression tests, formatter, analyzer, full suite,
quality checks, Windows release build, artifact hash, staging, commit, and
post-commit Git evidence. Exact final results appear below and in the handoff.

## Verification evidence

| Gate | Result |
| --- | --- |
| Focused Phase 106F test | PASS — 9 passed, 0 failed, 0 skipped |
| Phase 105B–106E and related focused regression | PASS — 117 passed, 0 failed, 0 skipped across 16 files |
| Full `flutter test` | PASS — 2034 passed, 0 failed, 1 unchanged historical skip; 139.8 s wall time |
| `dart format .` | PASS — 384 files checked, 0 changed; 5.57 s |
| `flutter analyze` | PASS — no issues found; 49.5 s |
| `git diff --check` | PASS — exit 0; only existing Windows generated-file line-ending notices were emitted |
| `git diff -- lib` | PASS — empty after every quality gate and release build |
| Windows release build | PASS — 21.6 s Flutter build time; exit 0 |
| Native smoke | NOT RUN — production database isolation for a native launch is not proven |

The focused regression command covered the Phase 105B contract, Phase 105C
Drift adapter, Phase 105D–105F pilot, Phase 106A–106E discovery/migrations and
runtime proofs, Dashboard guidance, Inventory Attention service/tool,
Document History, dashboard readiness, and owner dashboard alerts.

The Windows build emitted the existing non-fatal Firebase CMake
minimum-version deprecation and `.voltbl` linker warnings. Artifact:

- Path:
  `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes.
- SHA-256:
  `C94569FB3494BBAC03F9E39C0BCBAB9D7D82BED8E9ECB1E99BA16ACC4FB4E9C1`.

Before staging, `git status --short` listed only the two expected new files,
the commit count after baseline was `0`, `git diff --check` passed, and
`git diff -- lib` was empty. The cached diff contained only those files and
passed `git diff --cached --check`. Required post-commit state is clean with
exactly one commit after baseline; the final status, immutable commit SHA, and
post-commit count are recorded in the final handoff. No Push and no Tag are
performed.

Tooling note: two formatter attempts through the Flutter `dart.bat` wrapper
timed out before output because its SDK lock was inaccessible in the sandbox.
The same Dart 3.5.4 SDK executable was then invoked directly; formatting
completed successfully. Flutter test/analyze/build commands ran through the
approved Flutter tool and completed normally. No quality gate was waived.

## User database safety

Discovery and verification use source inspection, Git, tests, in-memory
SQLite, temporary test stores, and build commands only.

The user database was not opened, read, copied, or modified.

لم تُفتح أو تُقرأ أو تُعدّل قاعدة بيانات المستخدم.

The native application is not launched because isolation from the real user
database is not proven.

## Next phase only

**Phase 106G — Migrate DashboardService.load to ProductCatalogReadRepository**
