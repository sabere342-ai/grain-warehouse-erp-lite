# Phase 106AE — Re-audit and Freeze Next Product Read Migration Target

## 1. Outcome and Git State

**Outcome A — FULL SUCCESS**

Phase 106AE is an audit-and-freeze phase only. It re-audits every production
product-list read, reconciles Phase 106AD, and freezes exactly one future
migration target. It performs no production migration and changes no file
under `lib/`.

| Evidence | Value |
| --- | --- |
| Branch | `codex/phase-106ae-reaudit-freeze-next-product-read-migration-target` |
| Starting HEAD | `d7e7dcd21644e2f4946458b4394e94679454c932` |
| Starting subject | `PHASE 106AD: migrate backup restore empty-system product read` |
| Starting worktree | clean |
| Final commit message | `PHASE 106AE: freeze next product read migration target` |
| Final HEAD | created after this report is staged; the immutable hash is recorded in the final handoff because a commit cannot contain its own hash |
| Commits after baseline | exactly one after the final commit |
| Final worktree | required clean after the final commit |
| Push / Tag | none |

The baseline and clean-worktree gates passed before the phase branch was
selected. No reset, clean, stash, amend, rebase, merge, push, or tag operation
was used.

## 2. Scope

In scope: source-derived inventory, historical reconciliation, classification,
decision analysis, one frozen future target, source-structure guards, historical
lineage-guard updates, and this report.

Out of scope: any production migration, `lib/` edit, read-contract expansion,
schema or migration change, generated diff, UI change, backup-format change,
transaction change, write-path change, refactor, or migration of a second
consumer.

## 3. Audit Method

Current `lib/` is the authority. Phase 106W/Y/AA/AC/AD reports and tests were
used only to recover stable PRC identities, historical states, and the governing
taxonomy. The audit independently searched all production Dart sources for:

```text
.listProducts(
.listProductCatalog(
ProductRepository
ProductDataRepository
ProductCatalogReadRepository
products.select
select(products)
database.products
db.products
```

It then inspected every matching method, constructor, composition site, raw
Drift access, backup/restore flow, transaction boundary, and write coupling.
The dedicated guard recursively scans only `lib/**/*.dart`, reconciles exact
per-file call multiplicities, and therefore does not count tests, docs, or
tools. Raw Drift selects are repository implementations, not independent
application consumers; write calls are not read consumers. PRC-117 and PRC-118
remain explicitly inventoried so infrastructure reads cannot disappear behind
those exclusions.

## 4. Consumer Definition

A consumer is one stable production method, loader, workflow, or deliberately
tracked compatibility/infrastructure unit that obtains a product list for a
functional behavior. Multiple direct calls inside the same stable workflow are
one consumer but remain multiple call sites. Constructors, interfaces, model
references, write methods, tests, fixtures, and unreachable implementations are
not independently counted merely because they mention a repository type.

PRC identifiers retain their historical meanings. No new consumer was found,
and no existing identifier was renumbered.

## 5. Governing Classification Taxonomy

- A — directly migratable with the current contract.
- B — requires a small consumer-local adaptation.
- C — requires a narrow read-contract expansion.
- D — requires a broader read-contract expansion.
- E — coupled to product mutation behavior.
- F — transactional or domain-command path.
- G — mixed read/write consumer requiring separation.
- H — not safely migratable as one atomic consumer.
- I — not production-reachable, test-only, dead, deferred infrastructure, or
  not an independent application consumer.

These are the established Phase 106AA/106AC meanings. The classification of a
command-bound read remains F even when its product-list slice can be migrated
atomically.

## 6. Source-Derived Summary

```text
24 total consumers
24 = 13 + 11
13 migrated and accepted
11 remaining
13 legacy `.listProducts(` call sites
13 catalog `.listProductCatalog(` call sites
Remaining classification: F = 6, I = 5
11 = 6 + 5
```

The 13 legacy calls occur in 11 files. PRC-109 and PRC-114 each own two calls;
the other nine remaining units own one. The 13 catalog calls occur in 13 files
and map one-to-one to the 13 migrated consumers.

## 7. Complete Current Inventory

| PRC | File | Stable consumer/member | Current read | includeInactive | Fields/operation | Status | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-001 | `lib/core/documents/document_history.dart` | `LocalDocumentHistoryRepository._productNamesById` | catalog | `true` | `id`, `name` | Migrated | Accepted |
| PRC-002 | `lib/features/dashboard/dashboard_screen.dart` | `DashboardGuidanceState.load` | catalog | `true` | list length | Migrated | Accepted |
| PRC-003 | `lib/core/inventory/inventory_attention_service.dart` | `InventoryAttentionService.loadAttention` | catalog | `true` | `id`, `name`, `isActive` | Migrated | Accepted |
| PRC-004 | `lib/core/dashboard/dashboard_service.dart` | `DashboardService.load` | catalog | `true` | emptiness, `id`, `name` | Migrated | Accepted |
| PRC-010 | `lib/core/inventory/drift_inventory_repository.dart` | `allProductBalancesKg` | catalog | `!activeProductsOnly` | `id` | Migrated | Accepted |
| PRC-014 | `lib/core/reports/report_repository.dart` | `dailyActivityReport` | catalog | `true` | `id`, `name`, `unit`, reference cost | Migrated | Accepted |
| PRC-101 | `lib/core/backup/backup_export.dart` | `BackupExportService.createBackup` | catalog | `true` | all 11 catalog fields | Migrated | Accepted |
| PRC-102 | `lib/core/backup/backup_restore_service.dart` | `BackupRestoreService._checkEmptySystem` | catalog | `true` | `List.isNotEmpty` only | Migrated | Accepted |
| PRC-103 | `lib/core/backup/business_data_wipe_service.dart` | `BusinessDataWipeService._currentCounts` | legacy | `true` | `List.length` only | Remaining | F |
| PRC-104 | `lib/core/catalog/product_controller.dart` | `ProductController.loadProducts` | catalog | permission expression | nine display/edit fields | Migrated | Accepted |
| PRC-105 | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | `_findProduct` / `_requireProduct` | legacy | `true` | `id`, `isActive`, `updatedAt` | Remaining | F |
| PRC-106 | `lib/core/inventory/drift_inventory_repository.dart` | `_findProductById` | legacy | `true` | `id`, `isActive` | Remaining | F |
| PRC-107 | `lib/core/inventory/inventory_controller.dart` | `InventoryController.load` | catalog | permission expression | `id`, `name` | Migrated | Accepted |
| PRC-108 | `lib/core/inventory_valuation/profitability_activation_service.dart` | `ProfitabilityActivationService.activate` | legacy | `true` | membership, count, order, `id` | Remaining | F |
| PRC-109 | `lib/core/purchases/drift_purchase_repository.dart` | `_validateProduct` / `_validateProductExists` | legacy, two calls | `true` | `id`, `isActive` / `id` | Remaining | F |
| PRC-110 | `lib/core/purchases/purchase_controller.dart` | `PurchaseController.load` | catalog | permission expression | `id`, `name`, `isActive` | Migrated | Accepted |
| PRC-111 | `lib/core/sales/sale_repository.dart` | `_validateProduct` / `_validateAllMinimumPrices` | legacy | `true` | `id`, `isActive`, minimum sale price | Remaining | F |
| PRC-112 | `lib/core/sales/sale_controller.dart` | `SaleController.load` | catalog | `false` | `id`, `name`, default/minimum prices | Migrated | Accepted |
| PRC-113 | `lib/features/financial_reports/profitability_report_screen.dart` | `_ProfitabilityReportScreenState._activate` | catalog | `true` | `id`, `name` | Migrated | Accepted |
| PRC-114 | `lib/core/inventory/inventory_repository.dart` | `LocalInventoryRepository.allProductBalancesKg` / `_findProductById` | legacy, two calls | caller expression / `true` | `id`, `isActive` | Remaining | I |
| PRC-115 | `lib/core/purchases/purchase_repository.dart` | `LocalPurchaseRepository._validateProduct` | legacy | `true` | `id`, `isActive` | Remaining | I |
| PRC-116 | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | `SyntheticProfitabilityActivationService.activate` | legacy | `true` | emptiness | Remaining | I |
| PRC-117 | `lib/app/app_repositories.dart` | `_LegacyProductCatalogReadRepository.listProductCatalog` | legacy wrapper | forwarded expression | all 11 fields | Remaining | I |
| PRC-118 | `lib/core/catalog/drift_product_repository.dart` | `_DriftProductSnapshot.capture` | legacy self-read | default `true` | complete `Product` snapshot | Remaining | I |

Migrated IDs: PRC-001, PRC-002, PRC-003, PRC-004, PRC-010, PRC-014,
PRC-101, PRC-102, PRC-104, PRC-107, PRC-110, PRC-112, PRC-113.

Remaining IDs: PRC-103, PRC-105, PRC-106, PRC-108, PRC-109, PRC-111,
PRC-114, PRC-115, PRC-116, PRC-117, PRC-118.

## 8. Reconciliation and Delta from 106AC

Phase 106AC proved 24 consumers = 12 migrated + 12 remaining, 14 legacy
calls, 12 catalog calls, and remaining F7/I5. Phase 106AD changed only PRC-102:

| Fact | 106AC | Current after 106AD | Delta |
| --- | ---: | ---: | ---: |
| Total consumers | 24 | 24 | 0 |
| Migrated | 12 | 13 | +1 |
| Remaining | 12 | 11 | -1 |
| Legacy calls | 14 | 13 | -1 |
| Catalog calls | 12 | 13 | +1 |
| F remaining | 7 | 6 | -1 |
| I remaining | 5 | 5 | 0 |

No other PRC status, identity, reachability, call multiplicity, or
classification changed.

## 9. Phase 106AD / PRC-102 Proof

Current source proves that `BackupRestoreService._checkEmptySystem`:

- injects and stores `ProductCatalogReadRepository`;
- calls `_productCatalogReadRepository.listProductCatalog` exactly once;
- passes literal `includeInactive: true`;
- uses the result only as `products.isNotEmpty` and reads no row field;
- contains no `_productRepository.listProducts` fallback or dual read;
- retains `ProductDataRepository` only for snapshots and restore writes;
- is wired by `AppRepositories.backupRestoreService` with the catalog
  dependency;
- remains before snapshot capture and `RepositoryTransaction.execute`.

The two Phase 106AD production files were
`lib/core/backup/backup_restore_service.dart` and
`lib/app/app_repositories.dart`. They are part of the starting baseline, not a
Phase 106AE production diff.

## 10. Detailed Remaining Classification

| PRC | Legacy dependency/call | Fields | Order / mapping | Transaction or write coupling | Contract status | Risk / atomic eligibility | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-103 | `ProductDataRepository.listProducts(true)` | none; length only | none / none | count after saved backup immediately before destructive clears; same repository performs product clear | current contract sufficient; no expansion | medium-high; one isolated read slice | F because it is inside the wipe command, but its result is only the reported pre-wipe count |
| PRC-105 | `ProductRepository.listProducts(true)` | `id`, `isActive`, `updatedAt` | ID lookup; timestamp fingerprint | approval creation, revalidation, and posting | current contract sufficient | high; shared multi-stage behavior | F financial command and concurrency-sensitive fingerprint |
| PRC-106 | `ProductRepository.listProducts(true)` | `id`, `isActive` | ID lookup | stock query validation and durable movement transaction | current contract sufficient | high; shared helper affects multiple behaviors | F inventory command/query boundary |
| PRC-108 | `ProductRepository.listProducts(true)` | membership/count/order, `id` | set plus stable sequence | atomic valuation and audit writes | current contract sufficient | critical; not the smallest behavior | F accounting activation command |
| PRC-109 | two `ProductRepository.listProducts(true)` calls | `id`, `isActive` / `id` | two lookups | purchase create/cancel/restore transaction behavior | current contract sufficient | high; two validations | F durable purchase command |
| PRC-111 | `ProductRepository.listProducts(true)` | `id`, `isActive`, nullable minimum price | lookup and minimum-price map | sale, COGS, stock, and account writes | current contract sufficient | critical; broad financial behavior | F durable sale command |
| PRC-114 | two local `ProductRepository` calls | `id`, `isActive` | map and lookup | local in-memory write implementation | contract fields sufficient | not production reachable | I superseded by Drift composition |
| PRC-115 | local `ProductRepository.listProducts(true)` | `id`, `isActive` | lookup | local purchase write implementation | contract fields sufficient | not production reachable | I superseded by Drift composition |
| PRC-116 | `ProductDataRepository.listProducts(true)` | none; emptiness | none | synthetic command | current contract sufficient | deliberately unwired | I synthetic sandbox |
| PRC-117 | wrapper `ProductRepository.listProducts(flag)` | all 11 fields | lossless mapping and legacy order | compatibility infrastructure | exactly current contract | not an application consumer | I production startup replaces adapter with Drift catalog adapter |
| PRC-118 | repository self-call `listProducts()` | complete `Product` objects | complete snapshot order | rollback restore infrastructure | catalog model is not the write snapshot contract | not safely substitutable | I transaction infrastructure, not an application read target |

All production-reachable remaining units are F. None is reclassified merely to
make selection convenient.

## 11. Decision Matrix

| PRC | Consumer | Class | Expected production files | Required fields | Expansion | Transaction/write coupling | Behavioral risk | Testability | Decision |
| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| PRC-103 | `BusinessDataWipeService._currentCounts` | F | 2 | none; length only | none | read after backup and before destructive clears; legacy dependency retained for clear | medium-high but narrow | strong: exact count, inactive inclusion, failure-before-clear | selected; smallest isolated read result |
| PRC-106 | `DriftInventoryRepository._findProductById` | F | 2 | `id`, `isActive` | none | shared by stock queries and movement validation inside durable transactions | high | possible but spans several callers and failure paths | rejected in favor of a single count slice |
| PRC-105 | `NegativeBalanceApprovalWorkflowService._findProduct` | F | 2 | `id`, `isActive`, `updatedAt` | none | approval creation, stale-request revalidation, and posting | high | requires timestamp and multi-stage financial cases | rejected; broader financial behavior |
| PRC-108 | `ProfitabilityActivationService.activate` | F | 2 | `id`, complete membership/count/order | none | atomic valuation and audit command | critical | broad activation suite required | rejected; ordering and transaction coupling |

PRC-103 wins on the first criterion: its product-list read is one independently
replaceable value calculation (`products.length`). It ties the best alternatives
on expected production-file count and needs neither row fields nor contract
expansion. PRC-106 affects a shared helper across multiple behaviors, while
PRC-105 and PRC-108 carry materially broader financial semantics.

## 12. Sole Frozen Next Target

```text
FROZEN_TARGET_ID: PRC-103
FROZEN_TARGET_CONSUMER: BusinessDataWipeService._currentCounts
FROZEN_TARGET_MEMBER: BusinessDataWipeService._currentCounts
FROZEN_TARGET_FILE: lib/core/backup/business_data_wipe_service.dart
FROZEN_TARGET_APPROXIMATE_LINE: 159
FROZEN_CATEGORY: F
FROZEN_CURRENT_DEPENDENCY: ProductDataRepository _productRepository
FROZEN_CURRENT_CALL: _productRepository.listProducts(includeInactive: true)
FROZEN_TARGET_DEPENDENCY: ProductCatalogReadRepository _productCatalogReadRepository
FROZEN_TARGET_CALL: _productCatalogReadRepository.listProductCatalog(includeInactive: true)
FROZEN_INCLUDE_INACTIVE: true
FROZEN_FIELDS: none; List.length only
FROZEN_CONTRACT_EXPANSION: none
```

Exactly one consumer is frozen. Phase 106AE does not migrate it.

## 13. Frozen Current Behavior

- Purpose: capture the product count returned in `BusinessDataWipeCounts`
  after a valid backup has been saved and immediately before destructive clears.
- Empty list: reported product count is `0`.
- Active products: each row contributes one to the count.
- Inactive products: each row also contributes one because
  `includeInactive: true` is literal and mandatory.
- Fields: no `Product` field is read; only `List.length` is consumed.
- Ordering: irrelevant to the count and must not become observable.
- Mapping, normalization, filtering, null, unit, price, enum, and timestamp
  semantics: none.
- Error behavior: a product-read failure propagates to the existing outer
  `try/catch`, returns `backup-required-failed`, and no clear operation begins.
- Sequencing: backup creation, validation, preview, file save, `_currentCounts`,
  and every clear remain in their current order.
- `ProductDataRepository` remains required for
  `clearForOwnerDataWipe`; this migration must not move or change the write.

## 14. Frozen Required State for the Next Phase

The next phase may add `ProductCatalogReadRepository` to
`BusinessDataWipeService`, wire the existing app catalog repository, and replace
only the one PRC-103 list call. The current catalog contract is more than
sufficient because no row field is consumed. There is no contract or adapter
change, fallback, dual read, cache, data conversion, or ordering change.

### Expected production files

```text
lib/core/backup/business_data_wipe_service.dart
lib/app/app_repositories.dart
```

### Forbidden production paths

```text
lib/core/catalog/product_catalog_read_repository.dart
lib/core/catalog/drift_product_catalog_read_repository.dart
lib/core/persistence
```

Also forbidden: schema, migrations, generated files, backup export/restore,
other consumers, screens, navigation, localization, permissions, transaction
helpers, repositories' write APIs, data formats, backup version, and any
production file outside the two-file allowlist.

## 15. Required Tests for the Next Migration Phase

- active-only catalog rows produce the exact product count;
- inactive-only rows are included and prove literal `includeInactive: true`;
- an empty catalog produces zero;
- mixed rows preserve exact list length without filtering or deduplication;
- catalog failure preserves the existing failure result and proves that no
  clear starts;
- source guard proves one catalog call, no legacy call in `_currentCounts`, and
  no row-field access;
- DI guard proves app composition passes the existing catalog dependency;
- scope guard freezes the two production files and forbids contract/adapter,
  schema, transaction, backup-format, and other-consumer changes;
- existing Phase 17/18 wipe and release tests remain green.

## 16. Explicitly Excluded Next-Phase Scope

One consumer only: PRC-103. No general refactor; no second PRC; no change to
the clear operation; no transaction redesign; no error-message or UI change;
no schema, migration, generated, backup-format, checksum, restore, export, or
file-writing change; no legacy-surface removal beyond what is directly required
by PRC-103; and no contract expansion.

## 17. Phase 106AE Guards and Historical Updates

The dedicated test freezes the exact 24-row identity set, uniqueness, 13/11
split, F6/I5 split, call counts and file sets, PRC-102 migration, PRC-103 sole
selection, zero target fields, literal inactive inclusion, closed future
allowlist, forbidden paths, report parity, production-only discovery, and empty
Phase 106AE `lib/` diff.

Historical Phase 106 guards retain their original baseline assertions and
historical inventories. Their lineage gates are extended only to admit the
single audit-only 106AE child of the immutable 106AD commit; historical counts
are not rewritten as if they had been current at those older phases.

## 18. Verification Results

| Gate | Result |
| --- | --- |
| Dedicated Phase 106AE | PASS — 9 passed, 0 failed |
| Phase 106W–106AE guards, including updated lineage guards | PASS — 134 passed, 0 failed |
| Product Catalog contract, adapter, migration, runtime, and freeze guards | PASS — 226 passed, 0 failed |
| Backup/restore, wipe, composition, and directly affected guards | PASS — 188 passed, 0 failed |
| Full suite, `--concurrency=1` | PASS on final content — 2,290 passed, 1 historical skip, 0 failed; 449.5 seconds |
| Full suite, default concurrency | PASS on final content — 2,290 passed, 1 historical skip, 0 failed; 206.4 seconds |
| `flutter analyze` | PASS — `No issues found!` |
| Formatter stability | PASS — `dart format` reported 12 files, 0 changes on the final rerun |
| `git diff --check` | PASS — no errors |
| Production diff from `d7e7dcd...` | PASS — `git diff d7e7dcd... -- lib` returned no output |
| Final worktree | required clean after commit |

The single skipped test is the pre-existing historical skip. Phase 106AE adds
no skip and does not change the skipped test.

## 19. Changed Files

Phase-owned artifacts are exactly:

```text
docs/PHASE-106AE-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md
test/phase106ae_reaudit_freeze_next_product_read_migration_target_test.dart
test/phase106aa_reaudit_freeze_next_product_read_migration_target_test.dart
test/phase106ac_reaudit_freeze_next_product_read_migration_target_test.dart
test/phase106ad_migrate_backup_restore_empty_system_product_read_test.dart
test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart
test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart
test/phase106t_next_product_read_migration_target_freeze_test.dart
test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart
test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart
test/phase106w_next_product_read_migration_target_freeze_test.dart
test/phase106y_next_product_read_migration_target_freeze_test.dart
test/phase106z_profitability_report_activation_product_read_migration_test.dart
```

No tool is created. No production file is changed.

## 20. Final Integrity Contract

After verification and the single final commit:

```text
git rev-list --count d7e7dcd21644e2f4946458b4394e94679454c932..HEAD
1

git status --short
<empty>

git diff d7e7dcd21644e2f4946458b4394e94679454c932 -- lib
<empty>
```

No push or tag is performed.
