# Phase 106AK - Re-audit and Freeze Next Product Read Migration Target

## 1. Outcome

**Outcome A - FULL SUCCESS**

Phase 106AK is a re-audit, inventory reconciliation, target-selection, contract
assessment, and freeze phase. It does not migrate a production consumer. The
fresh source audit confirms 24 stable logical consumers, 16 migrated consumers,
8 remaining consumers, and a remaining split of 3 Production and 5
Infrastructure/Test consumers. Exactly one future Production target is frozen:
`PRC-105 - NegativeBalanceApprovalWorkflowService._findProduct/_requireProduct`.

## 2. Executive summary, baseline, and branch

| Evidence | Value |
| --- | --- |
| Required and actual starting HEAD | `2fd2ef4519b1007f1080fe004cca8572c1fe0d54` |
| Starting subject | `PHASE 106AJ: migrate drift purchase product validation reads` |
| Direct predecessor | Phase 106AJ |
| Branch | `codex/phase-106ak-reaudit-freeze-next-product-read-migration-target` |
| Starting worktree | clean |
| Commits after baseline before editing | `0` |
| Required final commit | `PHASE 106AK: freeze next product read migration target` |
| Push / tag | none |

Phase 106AJ moved only PRC-109's two product validation calls from
`ProductRepository.listProducts(includeInactive: true)` to
`ProductCatalogReadRepository.listProductCatalog(includeInactive: true)`.
This explains the source delta from Phase 106AI: migrated `15 -> 16`, remaining
`9 -> 8`, Production remaining `4 -> 3`, legacy calls `11 -> 9`, and catalog
calls `15 -> 17`. A single logical consumer can own multiple call sites.

## 3. Scope and explicit non-goals

In scope: re-audit all production Dart source; preserve the stable PRC identity
set; reconcile Phase 106AJ; count direct live calls; classify remaining units;
compare all three remaining Production candidates; freeze exactly one target;
record its current fields, filtering, ordering, duplicate, error, transaction,
write, and accounting semantics; assess the existing catalog contract; create
this report and a dedicated guard; and make only lineage-guard changes proven
necessary by the Phase 106 suite.

Explicit non-goals: any production migration or behavior change; editing a
Production consumer to use the catalog repository; changing validation,
messages, ordering, duplicate handling, rollback, transaction boundaries,
accounting, or writes; changing UI; extending `ProductCatalogReadModel`; adding
a repository method; schema, database migration, generated persistence, or code
generation changes; removing legacy APIs; broad refactoring; cleanup; a second
target; push; or tag.

The governing production-freeze assertion is:

```text
git diff 2fd2ef4519b1007f1080fe004cca8572c1fe0d54 -- lib
```

It must be empty in the final result.

## 4. Search method, evidence commands, and counting rule

Current production source is authoritative. Historical Phase 105/106 reports
and guards establish stable consumer identity, but no historical count was
copied without checking the current tree. The audit used independent searches
for direct calls, repository types, constructor injection, private helpers,
wrappers, implementations, test doubles, and downstream field use. Key commands:

```text
rg -n --glob '*.dart' "\.listProducts\(" lib
rg -n --glob '*.dart' "\.listProductCatalog\(" lib
rg -n "ProductRepository|ProductDataRepository|ProductCatalogReadRepository|DriftProductRepository|LocalProductRepository" lib test tool
rg -n "_findProduct|_requireProduct|productUpdatedAt|listProducts" lib/core/financial_accounts/negative_balance_approval_workflow_service.dart test
rg -n "ProfitabilityActivationService\(|NegativeBalanceApprovalWorkflowService\(|LocalSaleRepository\(" lib test tool
rg -n "PRC-[0-9]+|legacy calls|catalog calls" docs test
git show 2fd2ef4519b1007f1080fe004cca8572c1fe0d54:docs/PHASE-106AJ-MIGRATE-DRIFT-PURCHASE-PRODUCT-VALIDATION-READS.md
```

A **consumer count** counts one stable logical loader, service workflow,
repository workflow, or deliberately tracked compatibility/infrastructure
unit. A **call count** counts each live member call in `lib/**/*.dart` containing
`.listProducts(` or `.listProductCatalog(`. PRC-109 and PRC-114 each own two
call sites but remain one consumer each. Declarations, tests, fakes, and raw
query implementation details are not extra consumers or live calls. PRC-117
and PRC-118 remain explicit inventory units so the compatibility wrapper and
rollback snapshot self-read cannot disappear behind those exclusions.

## 5. Complete reconciled 24-consumer inventory

`P` means Production and `I` means Infrastructure/Test. `Migrated` means the
consumer currently uses `ProductCatalogReadRepository`; `Legacy` means it still
uses the named legacy product repository. Every row records the repository
method, `includeInactive`, consumed fields/purpose, important semantics, and
selection decision.

| ID | File; class/member | Reach; state; current read | `includeInactive` | Fields and purpose | Ordering/filtering/validation semantics | Next-target decision |
| --- | --- | --- | --- | --- | --- | --- |
| PRC-001 | `lib/core/documents/document_history.dart`; `LocalDocumentHistoryRepository._productNamesById` | P; Migrated; `ProductCatalogReadRepository.listProductCatalog` | literal `true` | `id`, `name`; document-name map | preserves catalog order; map overwrite behavior unchanged | no; already migrated |
| PRC-002 | `lib/features/dashboard/dashboard_screen.dart`; `DashboardGuidanceState.load` | P; Migrated; catalog `listProductCatalog` | literal `true` | length; dashboard guidance | all rows; list length only | no; already migrated |
| PRC-003 | `lib/core/inventory/inventory_attention_service.dart`; `InventoryAttentionService.loadAttention` | P; Migrated; catalog `listProductCatalog` | literal `true` | `id`, `name`, `isActive`; attention rows | all rows; service filtering remains downstream | no; already migrated |
| PRC-004 | `lib/core/dashboard/dashboard_service.dart`; `DashboardService.load` | P; Migrated; catalog `listProductCatalog` | literal `true` | emptiness, `id`, `name`; dashboard availability | ordered catalog snapshot | no; already migrated |
| PRC-010 | `lib/core/inventory/drift_inventory_repository.dart`; `allProductBalancesKg` | P; Migrated; catalog `listProductCatalog` | `!activeProductsOnly` | `id`; balance enumeration | caller-shaped active filter; catalog order | no; already migrated |
| PRC-014 | `lib/core/reports/report_repository.dart`; `LocalReportRepository.dailyActivityReport` | P; Migrated; catalog `listProductCatalog` | literal `true` | `id`, `name`, `unit`, reference cost; daily financial report | all rows; report aggregation/order unchanged | no; already migrated |
| PRC-101 | `lib/core/backup/backup_export.dart`; `BackupExportService.createBackup` | P; Migrated; catalog `listProductCatalog` | literal `true` | all 11 catalog fields; lossless product backup | created-time/id ordering; all active states | no; already migrated |
| PRC-102 | `lib/core/backup/backup_restore_service.dart`; `_checkEmptySystem` | P; Migrated; catalog `listProductCatalog` | literal `true` | non-emptiness; restore preflight | all rows; order irrelevant | no; already migrated |
| PRC-103 | `lib/core/backup/business_data_wipe_service.dart`; `_currentCounts` | P; Migrated; catalog `listProductCatalog` | literal `true` | length; owner-wipe count | all rows; order irrelevant | no; already migrated |
| PRC-104 | `lib/core/catalog/product_controller.dart`; `ProductController.loadProducts` | P; Migrated; catalog `listProductCatalog` | permission expression | display/edit fields: `id`, `name`, `code`, `unit`, `isActive`, three prices, `notes` | permission-shaped active filtering; catalog order; UI state/errors preserved | no; already migrated |
| PRC-105 | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart`; `NegativeBalanceApprovalWorkflowService._findProduct/_requireProduct` | P; Legacy; `ProductRepository.listProducts` (one source call) | literal `true` | `id`, `isActive`, `updatedAt`; paid-purchase validation and durable fingerprint | blank/null ID returns null; input ID trimmed; first exact match; inactive/missing handling differs between required and stale paths; read errors propagate | **yes; selected as the sole next target** |
| PRC-106 | `lib/core/inventory/drift_inventory_repository.dart`; `_findProductById` | P; Migrated; catalog `listProductCatalog` | literal `true` | `id`, `isActive`; stock/movement validation | exact first match; validation/messages retained | no; already migrated |
| PRC-107 | `lib/core/inventory/inventory_controller.dart`; `InventoryController.load` | P; Migrated; catalog `listProductCatalog` | permission expression | `id`, `name`; selector state | permission-shaped active filtering; catalog order | no; already migrated |
| PRC-108 | `lib/core/inventory_valuation/profitability_activation_service.dart`; `ProfitabilityActivationService.activate` | P; Legacy; `ProductRepository.listProducts` | literal `true` | count, order, membership, `id`; opening valuation activation | every product required; input IDs unique; returned order drives stock checks and write order | no; once-only accounting activation is higher risk |
| PRC-109 | `lib/core/purchases/drift_purchase_repository.dart`; `_validateProduct/_validateProductExists` | P; Migrated; catalog `listProductCatalog` (two calls) | literal `true` at both calls | `id`, `isActive`/existence; create and restore validation | first exact match on create; inactive allowed for restore existence; exact messages and transaction order | no; Phase 106AJ migrated it |
| PRC-110 | `lib/core/purchases/purchase_controller.dart`; `PurchaseController.load` | P; Migrated; catalog `listProductCatalog` | permission expression | `id`, `name`, `isActive`; selector state | permission-shaped filtering; catalog order | no; already migrated |
| PRC-111 | `lib/core/sales/sale_repository.dart`; `LocalSaleRepository._validateProduct/_validateAllMinimumPrices` | P; Legacy; `ProductRepository.listProducts` (one source call, invoked repeatedly) | literal `true` | `id`, `isActive`, nullable minimum price; sale validation | untrimmed exact ID after blank check; first exact match; per-line read multiplicity; Arabic errors; minimum-price enforcement | no; critical sale/inventory/accounting coupling and wide constructor surface |
| PRC-112 | `lib/core/sales/sale_controller.dart`; `SaleController.load` | P; Migrated; catalog `listProductCatalog` | literal `false` | `id`, `name`, default/minimum prices; sale-entry state | active only; catalog order | no; already migrated |
| PRC-113 | `lib/features/financial_reports/profitability_report_screen.dart`; `_ProfitabilityReportScreenState._activate` | P; Migrated; catalog `listProductCatalog` | literal `true` | `id`, `name`; activation dialog | all rows; catalog order | no; already migrated |
| PRC-114 | `lib/core/inventory/inventory_repository.dart`; `LocalInventoryRepository.allProductBalancesKg/_findProductById` | I; Legacy; `ProductRepository.listProducts` (two calls) | caller expression / literal `true` | `id`, `isActive`; local balances and validation | caller active filtering; first exact match; local messages | no; superseded local implementation, not Production-reachable |
| PRC-115 | `lib/core/purchases/purchase_repository.dart`; `LocalPurchaseRepository._validateProduct` | I; Legacy; `ProductRepository.listProducts` | literal `true` | `id`, `isActive`; local purchase validation | first exact match; errors before local writes | no; superseded local implementation |
| PRC-116 | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart`; `SyntheticProfitabilityActivationService.activate` | I; Legacy; `ProductDataRepository.listProducts` | literal `true` | emptiness; isolated sandbox guard | first emptiness condition before synthetic writes | no; deliberately unwired synthetic/test tool |
| PRC-117 | `lib/app/app_repositories.dart`; `_LegacyProductCatalogReadRepository.listProductCatalog` | I; Legacy wrapper; `ProductRepository.listProducts` | forwards caller argument | all 11 fields; compatibility mapping | forwards filtering; preserves order/errors | no; compatibility infrastructure, replaced in Production composition |
| PRC-118 | `lib/core/catalog/drift_product_repository.dart`; `_DriftProductSnapshot.capture` | I; Legacy self-read; `DriftProductRepository.listProducts` | omitted, default `true` | complete ordered `Product`; rollback snapshot | full domain objects and repository order restored on rollback | no; catalog model is not a write/rollback contract |

Each PRC appears exactly once. No identity was added, removed, split, merged, or
renumbered.

## 6. Migrated and remaining tables; numerical reconciliation

### Migrated: 16

| IDs | Live catalog calls |
| --- | ---: |
| PRC-001, PRC-002, PRC-003, PRC-004, PRC-010, PRC-014, PRC-101, PRC-102, PRC-103, PRC-104, PRC-106, PRC-107, PRC-109, PRC-110, PRC-112, PRC-113 | 17 |

PRC-109 owns two catalog calls; each other migrated PRC owns one.

### Remaining: 8

| Class | IDs | Consumers | Live legacy calls |
| --- | --- | ---: | ---: |
| Production | PRC-105, PRC-108, PRC-111 | 3 | 3 |
| Infrastructure/Test | PRC-114, PRC-115, PRC-116, PRC-117, PRC-118 | 5 | 6 |
| Total | all remaining IDs above | 8 | 9 |

The governing equations are:

```text
Total consumers: 24
Migrated: 16
Remaining: 8
24 = 16 + 8
Remaining Production: 3
Remaining Infrastructure/Test: 5
8 = 3 + 5
Legacy calls: 9
Product Catalog calls: 17
```

This exactly reconciles Phase 106AJ. Its one migrated consumer, PRC-109, owns
two calls, so the consumer delta is one while each call count moves by two.

## 7. Live-call inventory

### Nine legacy calls

| File:line | Unit |
| --- | --- |
| `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart:765` | PRC-105 |
| `lib/core/inventory_valuation/profitability_activation_service.dart:49` | PRC-108 |
| `lib/core/sales/sale_repository.dart:565` | PRC-111 |
| `lib/core/inventory/inventory_repository.dart:128,204` | PRC-114 (two) |
| `lib/core/purchases/purchase_repository.dart:426` | PRC-115 |
| `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart:84` | PRC-116 |
| `lib/app/app_repositories.dart:358` | PRC-117 |
| `lib/core/catalog/drift_product_repository.dart:263` | PRC-118 |

### Seventeen catalog calls

The 17 calls are owned by the 16 migrated PRCs. They occur in backup export,
restore and wipe; product, inventory, purchase and sale controllers; dashboard
guidance and dashboard service; inventory attention; two Drift inventory
members; report and document history; profitability dialog; and the two
PRC-109 Drift purchase validation members. Source locations were measured by
the commands in section 4 and are structurally asserted by the 106AK guard.

## 8. Three Production candidates and comparison

### PRC-105

One helper call serves paid-purchase submission and later stale-request
revalidation. It consumes only non-null `id`, `isActive`, and `updatedAt`, all
already present in `ProductCatalogReadModel`. Its future production diff is the
service dependency/type plus the application composition root. There are three
direct test construction sites. The financial workflow is sensitive, but its
read seam and fingerprint semantics are explicit and independently guardable.

### PRC-108

One read determines the complete product set, product count, validation order,
stock-check order, and opening-write order in a once-only profitability
activation. The contract is sufficient, but a regression could affect the
valuation baseline and audit atomically. It needs an accounting-focused phase
after the narrower approval lookup.

### PRC-111

One source call is invoked per validation and feeds active-product checks plus
nullable minimum-sale-price enforcement. The shared local delegate participates
in durable sale, inventory, COGS, account, and rollback behavior and has a wide
constructor/test surface. It is the largest and riskiest remaining target.

| Rank | Candidate | Fields | Contract | Main coupling | Decision |
| ---: | --- | --- | --- | --- | --- |
| 1 | PRC-105 | `id`, `isActive`, `updatedAt` | sufficient | paid-purchase approval fingerprint/revalidation | **selected** |
| 2 | PRC-108 | set/count/order, `id` | sufficient | once-only valuation activation and audit | defer |
| 3 | PRC-111 | `id`, `isActive`, nullable minimum price | sufficient | sale, stock, COGS, accounts, rollback | defer |

No Infrastructure/Test unit is eligible while Production candidates remain.

## 9. Frozen next target specification

```text
FROZEN_TARGET_COUNT: 1
FROZEN_TARGET_ID: PRC-105
FROZEN_TARGET_CLASS: Production
FROZEN_TARGET_CONSUMER: NegativeBalanceApprovalWorkflowService._findProduct/_requireProduct
FROZEN_TARGET_FILE: lib/core/financial_accounts/negative_balance_approval_workflow_service.dart
FROZEN_TARGET_METHODS: _findProduct; _requireProduct; submitPurchase and _staleReason call the shared lookup
CURRENT_REPOSITORY: ProductRepository _productRepository
CURRENT_CALL: _productRepository.listProducts(includeInactive: true)
CURRENT_CALL_SITES: 1 source call in _findProduct
INCLUDE_INACTIVE: literal true, selected by the consumer, not permission/runtime state
FIELDS_CONSUMED: id; isActive; updatedAt
CONTRACT_SUFFICIENT: yes
REQUIRED_EXPANSION: none
EXPECTED_NEW_REPOSITORY: ProductCatalogReadRepository _productCatalogReadRepository
EXPECTED_NEW_CALL: _productCatalogReadRepository.listProductCatalog(includeInactive: true)
RECOMMENDED_NEXT_PHASE: PHASE 106AL - Migrate Negative Balance Approval Product Fingerprint Read
```

### Frozen current semantics

- `_findProduct` returns `null` without a repository read when the nullable ID
  is null, empty, or whitespace-only.
- A nonblank input is trimmed for comparison. Returned product IDs are not
  normalized. The first exact match in repository/catalog order wins. Duplicate
  handling must therefore remain first-match behavior.
- The one call requests inactive rows because submission must distinguish an
  inactive match and later revalidation must detect an inactive product. The
  literal `true` is not permission-derived or runtime-configurable.
- `_requireProduct` treats missing and inactive identically and throws the same
  existing Arabic `StateError`; it returns the matched record otherwise.
- `submitPurchase` reads a product only for the paid-purchase path after request,
  payment-shape, account, and supplier checks and before quantity, balance,
  pending-request, or purchase writes. Credit purchases take their existing
  early path.
- For a pending paid purchase, the payload stores the matched `id` and the
  exact `updatedAt.toUtc().toIso8601String()` value.
- `_staleReason` invokes the same lookup during approval revalidation. Missing,
  inactive, or timestamp-mismatched products produce the same existing Arabic
  stale reason. No timestamp rounding, local-time conversion, fallback, or
  synthesized timestamp is allowed.
- Repository errors propagate. There is no catch, retry, cache, dual read, or
  legacy fallback to add.
- Approval execution remains inside its existing durable transaction and
  repository snapshot boundary. Validation ordering, stale resolution, request
  resolution, audit, purchase, inventory, supplier-account, financial-account,
  and valuation writes remain unchanged.

Nullability is frozen as: `id: String` non-null, `isActive: bool` non-null, and
`updatedAt: DateTime` non-null. The nullable element is only the `_findProduct`
result and its nullable input, not these model fields.

## 10. Contract sufficiency assessment

**Contract sufficient.** `ProductCatalogReadModel` currently declares non-null
`String id`, non-null `bool isActive`, and non-null `DateTime updatedAt`.
`DriftProductCatalogReadRepository` reads all three directly from the Drift
products row, requests `updatedAt` without normalization or fallback, filters
only when `includeInactive` is false, and orders by `createdAt` ascending then
`id` ascending. That order is compatible with the frozen first-match rule.

No contract expansion, new method, schema change, migration, generated change,
financial precision conversion, unit conversion, or fallback is required.

## 11. Expected Phase 106AL scope, risks, and test strategy

Expected Production files, and no others:

```text
lib/core/financial_accounts/negative_balance_approval_workflow_service.dart
lib/app/app_repositories.dart
```

Expected mechanical changes: replace the target's read-only dependency and
helper return type with the existing catalog contract, inject the existing
`productCatalogReadRepository` from composition, and update the three direct
test construction sites to supply a catalog adapter/fake. Do not alter any
write repository dependency that another concern still needs.

Primary risks are timestamp fingerprint drift; changing trimming or duplicate
selection; excluding inactive rows; shifting validation relative to balance or
transaction work; swallowing read errors; or accidentally changing the much
larger approval workflow. Future regression tests must cover blank/null IDs
without a read, first duplicate wins, active and inactive matches, missing
matches, exact UTC `updatedAt` payload, unchanged stale detection for missing,
inactive, and timestamp-changed rows, successful unchanged timestamp approval,
read-error propagation, no side effects on failure, call count and literal
`includeInactive: true`, and exact production-file scope. Existing Phase 82
workflow/widget and paid-purchase UI suites must remain green.

## 12. Phase guards, verification, Git lineage, and changed files

The dedicated guard is:

```text
test/phase106ak_reaudit_freeze_next_product_read_migration_target_test.dart
```

It asserts the 24/16/8 and F3/I5 inventory, 9/17 calls by exact source path,
PRC-109's migrated state and two methods, the sole PRC-105 target, fields and
`includeInactive`, contract sufficiency, no Production diff, no schema/generated
change, exact branch/lineage, and the precise next-phase title.

Historical Phase 106 guards are changed only where their forward-lineage
assertion must admit the exact Phase 106AK audit child. Historical snapshot
counts and past report claims remain unchanged.

Changed-file classification for Phase 106AK:

| Class | Expected count/scope |
| --- | --- |
| Production | `0` |
| Docs | this one governing report |
| Tests | 18 files: the dedicated guard plus 17 proven lineage-guard updates |
| Tools | `0` |
| Generated | `0` |
| Schema/migrations | `0` |

Verification results from the final pre-commit executions:

| Gate | Command | Passed | Skipped | Failed | Result |
| --- | --- | ---: | ---: | ---: | --- |
| Dedicated Phase 106AK guard | `flutter test test/phase106ak_reaudit_freeze_next_product_read_migration_target_test.dart` | 10 | 0 | 0 | PASS |
| All Phase 106 tests | all 38 `test/phase106*.dart` files, run in bounded named groups with `--concurrency=1` | 357 | 0 | 0 | PASS |
| Expanded catalog suite | the Phase 106 set plus Phase 105B-F contract/adapter/pilot files | 395 | 0 | 0 | PASS |
| Full serialized suite | `flutter test --concurrency=1` | 2,342 | 1 historical | 0 | PASS |
| Full default suite | `flutter test` | 2,342 | 1 historical | 0 | PASS |
| Analyzer | `flutter analyze` | N/A | N/A | 0 issues | PASS - `No issues found!` |
| Formatter | Dart SDK `format --output=none --set-exit-if-changed .` | 416 files | 0 changed | 0 | PASS |
| Diff whitespace | `git diff --check` | N/A | N/A | 0 | PASS |

The first attempt to run all Phase 106 files in one Windows process was stopped
after it remained buffered without a result; it was not counted as a pass or
failure. The same exact 38-file list was then executed in bounded successful
groups, and the 357 total above is the sum of the emitted Flutter counters.
The full serialized and default commands each completed normally and supplied
their own final counters.

The final commit must be the single direct child of
`2fd2ef4519b1007f1080fe004cca8572c1fe0d54`, with subject exactly
`PHASE 106AK: freeze next product read migration target`. The final worktree
must be clean; no push or tag is permitted.

## 13. Final recommendation

Freeze PRC-105 only. Phase 106AK does not implement that migration. The exact
recommended next phase is:

```text
PHASE 106AL - Migrate Negative Balance Approval Product Fingerprint Read
```
