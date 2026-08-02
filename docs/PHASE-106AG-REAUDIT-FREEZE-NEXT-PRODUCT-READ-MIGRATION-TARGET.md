# Phase 106AG — Re-audit and Freeze Next Product Read Migration Target

## A. Outcome

**Outcome A — FULL SUCCESS**

Phase 106AG is an audit, classification, and target-freeze phase only. It
reconciles the live product-read inventory after Phase 106AF and freezes one
future migration. It does not migrate a production consumer and changes no
file under `lib/`.

## B. Baseline and Branch

| Evidence | Value |
| --- | --- |
| Required baseline | `b786e0869808182614ba301af4fdd615124d7a8e` |
| Actual starting HEAD | `b786e0869808182614ba301af4fdd615124d7a8e` |
| Starting subject | `PHASE 106AF: migrate business data wipe current counts product read` |
| Required branch | `codex/phase-106ag-reaudit-freeze-next-product-read-migration-target` |
| Direct predecessor | Phase 106AF |
| Starting worktree | clean |
| Commits after baseline before editing | `0` |
| Final commit message | `PHASE 106AG: freeze next product read migration target` |
| Push / tag | none |

The exact baseline, clean worktree, branch, subject, and zero-child conditions
were proved before any edit. The final immutable commit hash is recorded in the
handoff because a commit cannot contain its own hash.

## C. Scope

Completed: a fresh `lib/**/*.dart` audit, stable PRC reconciliation, exact call
counts, remaining-consumer classification, decision analysis, one frozen
future target, a governing report, a dedicated static guard, and only the
historical lineage updates required to admit this documentation/test-only
phase.

Not performed: production migration, dependency or constructor change in
`lib/`, read-model expansion, adapter change, query change, schema or migration
change, generated change, write-path change, transaction change, refactor,
push, or tag.

Production-freeze proof:

```text
git diff b786e0869808182614ba301af4fdd615124d7a8e -- lib
```

must remain empty before and after the single Phase 106AG commit.

## D. Audit Method

Current production source is the authority. The audit searched independently
for `.listProducts(`, `.listProductCatalog(`, `ProductRepository`,
`ProductDataRepository`, `ProductCatalogReadRepository`, aliases, wrappers,
private helpers, repository construction, and raw Drift product access. It
cross-checked `rg`, Git search, static method inspection, constructor tracing,
application composition, existing inventory guards, and the Phase 106AF,
106AE, 106AC, 106AA, 106Y, 106W, and 106T reports.

A consumer is one stable production method, workflow, loader, or deliberately
tracked compatibility/infrastructure unit that obtains a product list for one
functional behavior. Multiple calls in the same stable unit remain one PRC but
are counted as multiple calls. Interfaces, tests, fixtures, constructors,
writes, and raw repository implementation queries are not new consumers merely
because they mention products. PRC-117 and PRC-118 remain explicit so the
compatibility wrapper and snapshot self-read cannot disappear behind those
exclusions.

Call counting scans only `lib/**/*.dart`. It counts member calls containing
`.listProducts(` and `.listProductCatalog(`, then reconciles their exact file
sets and per-file multiplicities against the PRC inventory.

## E. Full Inventory

| PRC | File | Consumer/member | Current dependency/read | includeInactive | Result use / fields | Runtime / coupling | Status | Class |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-001 | `lib/core/documents/document_history.dart` | `LocalDocumentHistoryRepository._productNamesById` | catalog | `true` | map by `id`, `name` | production read | Migrated | Accepted |
| PRC-002 | `lib/features/dashboard/dashboard_screen.dart` | `DashboardGuidanceState.load` | catalog | `true` | list length | production UI read | Migrated | Accepted |
| PRC-003 | `lib/core/inventory/inventory_attention_service.dart` | `InventoryAttentionService.loadAttention` | catalog | `true` | `id`, `name`, `isActive` | production read | Migrated | Accepted |
| PRC-004 | `lib/core/dashboard/dashboard_service.dart` | `DashboardService.load` | catalog | `true` | emptiness, `id`, `name` | production read | Migrated | Accepted |
| PRC-010 | `lib/core/inventory/drift_inventory_repository.dart` | `allProductBalancesKg` | catalog | `!activeProductsOnly` | enumerate `id` | production inventory read | Migrated | Accepted |
| PRC-014 | `lib/core/reports/report_repository.dart` | `dailyActivityReport` | catalog | `true` | `id`, `name`, `unit`, reference cost | production financial read | Migrated | Accepted |
| PRC-101 | `lib/core/backup/backup_export.dart` | `BackupExportService.createBackup` | catalog | `true` | all 11 fields | production backup read | Migrated | Accepted |
| PRC-102 | `lib/core/backup/backup_restore_service.dart` | `_checkEmptySystem` | catalog | `true` | `isNotEmpty` | production restore preflight | Migrated | Accepted |
| PRC-103 | `lib/core/backup/business_data_wipe_service.dart` | `_currentCounts` | catalog | `true` | `length` | production wipe pre-count | Migrated | Accepted |
| PRC-104 | `lib/core/catalog/product_controller.dart` | `loadProducts` | catalog | permission expression | nine display/edit fields | production UI read | Migrated | Accepted |
| PRC-105 | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | `_findProduct` / `_requireProduct` | legacy | `true` | `id`, `isActive`, `updatedAt` | production financial command | Remaining | F |
| PRC-106 | `lib/core/inventory/drift_inventory_repository.dart` | `_findProductById` | legacy | `true` | first exact `id`, then `isActive` | production inventory command/query | Remaining | F |
| PRC-107 | `lib/core/inventory/inventory_controller.dart` | `load` | catalog | permission expression | `id`, `name` | production UI read | Migrated | Accepted |
| PRC-108 | `lib/core/inventory_valuation/profitability_activation_service.dart` | `activate` | legacy | `true` | membership, count, order, `id` | atomic valuation/audit command | Remaining | F |
| PRC-109 | `lib/core/purchases/drift_purchase_repository.dart` | `_validateProduct` / `_validateProductExists` | legacy; two calls | `true` | `id`, `isActive` / existence | durable purchase transactions | Remaining | F |
| PRC-110 | `lib/core/purchases/purchase_controller.dart` | `load` | catalog | permission expression | `id`, `name`, `isActive` | production UI read | Migrated | Accepted |
| PRC-111 | `lib/core/sales/sale_repository.dart` | `_validateProduct` / `_validateAllMinimumPrices` | legacy | `true` | `id`, `isActive`, minimum price | durable sale command | Remaining | F |
| PRC-112 | `lib/core/sales/sale_controller.dart` | `load` | catalog | `false` | `id`, `name`, default/minimum prices | production UI read | Migrated | Accepted |
| PRC-113 | `lib/features/financial_reports/profitability_report_screen.dart` | `_activate` | catalog | `true` | `id`, `name` | production activation UI | Migrated | Accepted |
| PRC-114 | `lib/core/inventory/inventory_repository.dart` | `allProductBalancesKg` / `_findProductById` | legacy; two calls | caller expression / `true` | `id`, `isActive` | superseded local implementation | Remaining | I |
| PRC-115 | `lib/core/purchases/purchase_repository.dart` | `_validateProduct` | legacy | `true` | `id`, `isActive` | superseded local implementation | Remaining | I |
| PRC-116 | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | `activate` | legacy | `true` | emptiness | deliberately unwired sandbox | Remaining | I |
| PRC-117 | `lib/app/app_repositories.dart` | `_LegacyProductCatalogReadRepository.listProductCatalog` | legacy wrapper | forwarded expression | all 11 fields | startup compatibility infrastructure | Remaining | I |
| PRC-118 | `lib/core/catalog/drift_product_repository.dart` | `_DriftProductSnapshot.capture` | legacy self-read | default `true` | full `Product` snapshot | transaction rollback infrastructure | Remaining | I |

Every PRC appears exactly once. No identity was created, removed, or renumbered.

## F. Migrated Consumers

The 14 migrated consumers are:

```text
PRC-001, PRC-002, PRC-003, PRC-004, PRC-010, PRC-014, PRC-101,
PRC-102, PRC-103, PRC-104, PRC-107, PRC-110, PRC-112, PRC-113
```

Each owns one catalog call. Phase 106AF moved only PRC-103 and preserved its
literal `includeInactive: true`, length-only result use, error envelope, wipe
ordering, and separate product clear dependency.

## G. Remaining Consumers

| PRC | Current call(s) | Legacy calls | Result use / fields | Runtime reachability | Write/transaction coupling | Contract sufficient | Class and reason | Migration risk | Composition | Expected affected tests |
| --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-105 | `_productRepository.listProducts(includeInactive: true)` | 1 | exact-ID lookup; `id`, `isActive`, `updatedAt` fingerprint | production | approval creation, revalidation, posting | yes | F: financial command and concurrency fingerprint | high, multi-stage | `AppRepositories.negativeBalanceApprovalWorkflowService` | Phase 82/approval workflow tests |
| PRC-106 | `_productRepository.listProducts(includeInactive: true)` | 1 | first exact-ID match; `id`, then `isActive` | production | stock queries and movement validation; create path remains inside Drift transaction | yes | F: inventory command/query boundary | medium, isolated shared helper | `AppRepositories.initializeProduction` → `DriftInventoryRepository` | Phase 8E, 8F, 8G, 106M, 106N, 106S, 106V plus new Phase 106AH |
| PRC-108 | `_productRepository.listProducts(includeInactive: true)` | 1 | full membership/count/order; `id` | production | atomic valuation and audit writes | yes | F: accounting activation command | critical | `AppRepositories.profitabilityActivationService` | profitability activation suites |
| PRC-109 | two `_productRepository.listProducts(includeInactive: true)` calls | 2 | active lookup and existence lookup; `id`, `isActive` | production | purchase create/cancel/restore transactions | yes | F: durable purchase command | high, two read slices | `AppRepositories.initializeProduction` → `DriftPurchaseRepository` | Phase 8F and purchase transaction suites |
| PRC-111 | `_productRepository.listProducts(includeInactive: true)` | 1 | lookup/minimum-price map; `id`, `isActive`, nullable minimum price | production through Drift delegation | sale, COGS, stock and account writes | yes | F: durable sale command | critical | `AppRepositories.initializeProduction` → `DriftSaleRepository` delegate | sales and Phase 8G suites |
| PRC-114 | two local `_productRepository.listProducts(...)` calls | 2 | balance map and lookup; `id`, `isActive` | not production-reachable after initialization | local in-memory writes | yes | I: superseded local implementation | excluded | default local composition only | local inventory tests |
| PRC-115 | `_productRepository.listProducts(includeInactive: true)` | 1 | lookup; `id`, `isActive` | not production-reachable after initialization | local in-memory purchase writes | yes | I: superseded local implementation | excluded | default local composition only | local purchase tests |
| PRC-116 | `_productRepository.listProducts(includeInactive: true)` | 1 | emptiness only | deliberately unwired | synthetic command | yes | I: sandbox tool | excluded | none | synthetic activation tests |
| PRC-117 | `_repository.listProducts(includeInactive: includeInactive)` | 1 | lossless 11-field mapping | replaced by Drift adapter at production initialization | none | exactly | I: compatibility infrastructure, not an application target | excluded | `AppRepositories` default adapter | catalog adapter guards |
| PRC-118 | `repository.listProducts()` | 1 | complete ordered `Product` snapshot | production infrastructure | rollback capture/restore | no; catalog model is not the write snapshot contract | I: transaction infrastructure | excluded | `DriftProductRepository.createTransactionSnapshot` | rollback/snapshot tests |

## H. Call Counts

```text
Total consumers: 24
Migrated: 14
Remaining: 10
Legacy calls: 12
Product Catalog calls: 14
24 = 14 + 10
```

The 12 legacy calls occur in 10 files: PRC-109 and PRC-114 own two each; the
other eight remaining PRCs own one. The 14 catalog calls occur in 14 consumer
files; `drift_inventory_repository.dart` contains both PRC-010's catalog call
and PRC-106's legacy call.

These figures are confirmed without correction from the Phase 106AF governing
state. No source drift or historical inventory error was found.

## I. Classification Reconciliation

```text
F: 5 — PRC-105, PRC-106, PRC-108, PRC-109, PRC-111
I: 5 — PRC-114, PRC-115, PRC-116, PRC-117, PRC-118
10 = 5 + 5
```

The governing taxonomy remains: F is a transactional or domain-command path;
I is not production-reachable, test-only, deliberately unwired, deferred
infrastructure, or not an independent application consumer. A command-bound
read remains F even when its read slice is independently migratable.

## J. Selected Target

Exactly one next target is frozen:

```text
FROZEN_TARGET_ID: PRC-106
FROZEN_TARGET_CONSUMER: DriftInventoryRepository._findProductById
FROZEN_TARGET_FILE: lib/core/inventory/drift_inventory_repository.dart
FROZEN_TARGET_CLASS: F
```

PRC-106 is the smallest safe F migration now available. The repository already
owns and receives `ProductCatalogReadRepository` for PRC-010, the current
catalog model already exposes `id` and `isActive`, the target owns one legacy
call, and no query, schema, adapter, read-model, write, or transaction change is
needed. PRC-105 has multi-stage financial fingerprint behavior, PRC-108 is an
atomic valuation/audit command, PRC-109 owns two transaction validations, and
PRC-111 is coupled to the full sale/accounting command.

## K. Proposed Migration Contract

```text
PRC: PRC-106
Consumer: DriftInventoryRepository._findProductById
File: lib/core/inventory/drift_inventory_repository.dart
Method: Future<Product?> _findProductById(String id) async
Current dependency: ProductRepository _productRepository
Current call: _productRepository.listProducts(includeInactive: true)
Current includeInactive: true
Current result usage: sequential first exact-id lookup; null when absent
Fields consumed: id; isActive is consumed by _validateDraftAndLoadProduct
Proposed dependency: existing ProductCatalogReadRepository _productCatalogReadRepository
Proposed call: _productCatalogReadRepository.listProductCatalog(includeInactive: true)
Required includeInactive: true
Contract expansion: none
Composition location: AppRepositories.initializeProduction, DriftInventoryRepository construction
Legacy repository retained or removed: removed from DriftInventoryRepository constructor and field
Reason for removal: PRC-106 is its only use in this class after PRC-010 already migrated
Expected production files: lib/core/inventory/drift_inventory_repository.dart; lib/app/app_repositories.dart
Expected affected tests: phase8e_durable_inventory_repository_test.dart; phase8f_durable_purchase_repository_test.dart; phase8g_durable_sale_repository_test.dart; phase106m_drift_inventory_product_balance_enumeration_read_contract_migration_test.dart; phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart; phase106s_inventory_controller_product_catalog_runtime_integration_test.dart; phase106v_sale_controller_product_catalog_runtime_integration_test.dart; new Phase 106AH guard
Behavior invariants: exact id lookup, inactive visibility, null/not-found behavior, inactive rejection, error propagation, and call ordering
Failure behavior: read errors propagate unchanged; missing id remains null in helper and StateError in existing callers
Write behavior: unchanged
Transaction behavior: unchanged; createMovement lookup remains inside the existing database transaction
Explicit exclusions: every other PRC; contract/adapter/query/schema/generated changes; transaction or write redesign
```

The proposed helper return type becomes `ProductCatalogReadModel?`, and
`_validateDraftAndLoadProduct` becomes `Future<ProductCatalogReadModel>`.
`Product` construction and conversion are forbidden.

## L. Behavior Preservation Matrix

| Current behavior | Required behavior after migration | Evidence |
| --- | --- | --- |
| Literal `includeInactive: true` | same literal; no permission/caller expression | current helper source and catalog contract |
| Sequential first exact `product.id == id` match | same first exact match; no trim, normalization, set/map rewrite, or lookup API | `_findProductById` loop |
| Empty list or absent ID returns `null` | same | helper final `return null` |
| `currentStockKg` and `hasOpeningBalance` throw `StateError('Product was not found.')` for null | same message and timing | both public methods call helper before movement reads |
| Movement validation throws the same not-found error | same | `_validateDraftAndLoadProduct` |
| Inactive products remain discoverable | same, because `includeInactive: true` | current call and contract |
| `currentStockKg` and `hasOpeningBalance` do not reject inactive products | same | callers only test null |
| `createMovement` rejects inactive product with `Inactive product cannot accept stock movements.` | same exact error | `_validateDraftAndLoadProduct` consumes `isActive` |
| Catalog/legacy read error propagates | same; no catch, translation, retry, fallback, or dual read | helper has no catch |
| Catalog order is creation time then ID | remains supplied, but only first exact unique ID is observable | contract and Drift adapter |
| `createMovement` validation occurs inside `_database.transaction` | same transaction scope and sequence | `createMovement` body |
| No writes in helper | same | read-only helper |
| Movement inserts, sequence writes, clears, restores, snapshots | unchanged | outside the target read slice |
| Empty-list behavior | null, then existing caller-specific not-found error | current helper/callers |
| Null field behavior | not applicable; `id` and `isActive` are non-null contract fields | catalog model |
| Filtering/mapping | no filtering or mapping beyond exact-ID comparison | current loop |
| Cache/fallback/retry | not applicable; none exists and none may be added | source inspection |
| UI/localization/logging/audit | not applicable; no direct UI, localization, log, or audit effect in helper | composition trace |

## M. Expected Production Scope for Next Phase

Only these production files may change in Phase 106AH:

```text
lib/core/inventory/drift_inventory_repository.dart
lib/app/app_repositories.dart
```

The first file may substitute the helper dependency/call and remove the
obsolete legacy constructor field/import. The second may only remove the
obsolete `productRepository:` argument at the genuine construction site.

Known test construction files that will require the same constructor cleanup:

```text
test/phase8e_durable_inventory_repository_test.dart
test/phase8f_durable_purchase_repository_test.dart
test/phase8g_durable_sale_repository_test.dart
test/phase106m_drift_inventory_product_balance_enumeration_read_contract_migration_test.dart
test/phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart
test/phase106s_inventory_controller_product_catalog_runtime_integration_test.dart
test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart
```

## N. Risks and Explicit Exclusions

Risks to guard are accidental active-only filtering, ID normalization, changed
not-found or inactive errors, moving the lookup outside the transaction,
constructing a write-domain `Product`, changing public stock-query treatment of
inactive products, altering movement ordering/writes, or migrating PRC-010 or a
second remaining consumer again.

Excluded: PRC-105, PRC-108, PRC-109, PRC-111, all I rows, read-model or adapter
expansion, direct SQL changes, schema/migration/generated files, transaction
redesign, write repository changes, caching, fallback, retries, UI,
localization, logging, auditing, and broad refactoring.

## O. Verification

| Command / group | Actual result |
| --- | --- |
| Dedicated Phase 106AG guard | 8 passed, 0 failed |
| All 34 `phase106*.dart` guard files, five stable groups | 317 passed, 0 failed |
| Product Catalog base, contract, Drift adapter, application boundary, runtime, and acceptance set | 53 passed, 0 failed |
| `flutter test --concurrency=1` | 2,303 passed, 1 historical skip, 0 failed |
| `flutter test` | 2,303 passed, 1 historical skip, 0 failed |
| `flutter analyze` | `No issues found!` |
| Stable formatter rerun on 14 changed Dart files | `Formatted 14 files (0 changed)` |
| `git diff --check` | exit 0; no whitespace errors |
| `git diff b786e0869808182614ba301af4fdd615124d7a8e -- lib` | empty |

The historical skip is unchanged. The dedicated guard and analyzer are rerun
after the final commit, together with the history-sensitive lineage guards.

Historical guards updated only to admit the exact Phase 106AG no-production
child of `b786e0869808182614ba301af4fdd615124d7a8e`:

```text
test/phase106aa_reaudit_freeze_next_product_read_migration_target_test.dart
test/phase106ac_reaudit_freeze_next_product_read_migration_target_test.dart
test/phase106ad_migrate_backup_restore_empty_system_product_read_test.dart
test/phase106ae_reaudit_freeze_next_product_read_migration_target_test.dart
test/phase106af_migrate_business_data_wipe_current_counts_product_read_test.dart
test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart
test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart
test/phase106t_next_product_read_migration_target_freeze_test.dart
test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart
test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart
test/phase106w_next_product_read_migration_target_freeze_test.dart
test/phase106y_next_product_read_migration_target_freeze_test.dart
test/phase106z_profitability_report_activation_product_read_migration_test.dart
```

No historical assertion was removed or weakened. No audit tool was created.

## P. Git Evidence

- Starting worktree: clean.
- Starting HEAD: exact required Phase 106AF commit.
- Branch: exact required Phase 106AG branch.
- Phase 106AG production diff: required empty.
- Final history: exactly one commit after baseline with the required subject.
- Staging: explicit `docs` and affected `test` files only.
- Push/tag: none.

## Q. Final Recommendation

```text
Phase 106AH — Migrate Drift Inventory Product Lookup Read
Branch: codex/phase-106ah-migrate-drift-inventory-product-lookup-read
Commit: PHASE 106AH: migrate drift inventory product lookup read
```

Phase 106AH must migrate only PRC-106 under the frozen contract above. Phase
106AG does not implement that migration.
