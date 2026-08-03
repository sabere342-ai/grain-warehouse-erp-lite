# Phase 106AI - Re-audit and Freeze the Next Product Read Migration Target

## 1. Outcome

**Outcome A - FULL SUCCESS**

Phase 106AI is an audit and freeze phase only. It re-audits the complete
product-read inventory after Phase 106AH, reconciles the governing counts with
production source, and freezes exactly one future migration target. No product
read migration, runtime behavior change, or production edit is performed here.

## 2. Baseline and branch

| Evidence | Value |
| --- | --- |
| Required baseline | `bd5d287a56fd96f826c673d775226cb4ad45a247` |
| Actual starting HEAD | `bd5d287a56fd96f826c673d775226cb4ad45a247` |
| Starting subject | `PHASE 106AH: migrate drift inventory product lookup read` |
| Direct predecessor | Phase 106AH |
| Branch | `codex/phase-106ai-reaudit-freeze-next-product-read-migration-target` |
| Starting worktree | clean |
| Commits after baseline before editing | `0` |
| Required final commit | `PHASE 106AI: freeze next product read migration target` |
| Push / tag | none |

The final immutable commit hash is recorded in the handoff because a commit
cannot contain its own hash.

## 3. Scope and explicit non-goals

In scope: a fresh production-source audit, stable PRC reconciliation, exact
legacy/catalog call counts, nine independent remaining-consumer analyses,
classification confirmation, candidate comparison, one frozen target, this
governing report, a dedicated Phase 106AI guard, and only the historical guard
updates required to admit this documentation/test-only phase.

Explicit non-goals: production migration; a change under `lib/`; constructor or
dependency injection changes in production; contract, model, adapter, query,
schema, migration, or generated changes; write or transaction changes; UI or
observable runtime changes; refactoring; a second target; push; or tag.

The governing production-freeze command is:

```text
git diff bd5d287a56fd96f826c673d775226cb4ad45a247 -- lib
```

It is empty in the final Phase 106AI result.

## 4. Audit method and commands

Production source is authoritative. Historical reports establish stable PRC
identity and taxonomy, but their counts and descriptions were checked against
the current tree. A consumer remains one stable production method, workflow,
loader, or deliberately tracked compatibility/infrastructure unit. Multiple
legacy calls owned by one stable unit count as multiple calls but one consumer.
Interfaces, tests, fixtures, writes, and raw implementation queries are not
invented as new consumers. PRC-117 and PRC-118 remain explicitly tracked so
the compatibility adapter and snapshot self-read cannot disappear behind those
exclusions.

The audit inspected Phase 106AG and Phase 106AH first, then searched all Dart
production files for direct calls, dependency types, wrappers, private helpers,
constructor wiring, and downstream field use. The principal commands were:

```text
rg -n "\.listProducts\(|\.listProductCatalog\(" lib
rg -n "ProductRepository|ProductDataRepository|ProductCatalogReadRepository" lib test
rg -n -C 65 "listProducts|_findProduct|_requireProduct" lib/core/financial_accounts/negative_balance_approval_workflow_service.dart
rg -n -C 65 "listProducts|activate\(" lib/core/inventory_valuation/profitability_activation_service.dart
rg -n -C 55 "listProducts|_validateProduct" lib/core/purchases/drift_purchase_repository.dart
rg -n -C 65 "listProducts|_validateProduct|_validateAllMinimumPrices" lib/core/sales/sale_repository.dart
rg -n "NegativeBalanceApprovalWorkflowService\(|ProfitabilityActivationService\(|DriftPurchaseRepository\(|LocalSaleRepository\(" lib test tool
git diff bd5d287a56fd96f826c673d775226cb4ad45a247 -- lib
```

Call counts cover only `lib/**/*.dart` member calls containing
`.listProducts(` or `.listProductCatalog(`. Downstream fields were derived from
actual method bodies, not from the full entity type.

## 5. Full reconciled inventory

| PRC | Consumer / file / member | Current dependency and read | includeInactive | Fields actually consumed | Downstream behavior | Status | Class | Safety / contract / next action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRC-001 | `LocalDocumentHistoryRepository._productNamesById`, `lib/core/documents/document_history.dart` | `ProductCatalogReadRepository.listProductCatalog` | literal `true` | `id`, `name` | Builds the document product-name map | Migrated | Accepted | Contract sufficient; retain |
| PRC-002 | `DashboardGuidanceState.load`, `lib/features/dashboard/dashboard_screen.dart` | catalog read | literal `true` | list length | Drives dashboard guidance state | Migrated | Accepted | Contract sufficient; retain |
| PRC-003 | `InventoryAttentionService.loadAttention`, `lib/core/inventory/inventory_attention_service.dart` | catalog read | literal `true` | `id`, `name`, `isActive` | Builds inventory attention rows | Migrated | Accepted | Contract sufficient; retain |
| PRC-004 | `DashboardService.load`, `lib/core/dashboard/dashboard_service.dart` | catalog read | literal `true` | emptiness, `id`, `name` | Dashboard availability and names | Migrated | Accepted | Contract sufficient; retain |
| PRC-010 | `DriftInventoryRepository.allProductBalancesKg`, `lib/core/inventory/drift_inventory_repository.dart` | catalog read | `!activeProductsOnly` | `id` | Enumerates products before balance aggregation | Migrated | Accepted | Contract sufficient; retain |
| PRC-014 | `LocalReportRepository.dailyActivityReport`, `lib/core/reports/report_repository.dart` | catalog read | literal `true` | `id`, `name`, `unit`, reference cost | Daily activity and financial reporting | Migrated | Accepted | Contract sufficient; retain |
| PRC-101 | `BackupExportService.createBackup`, `lib/core/backup/backup_export.dart` | catalog read | literal `true` | all 11 catalog fields | Lossless product backup serialization | Migrated | Accepted | Contract sufficient; retain |
| PRC-102 | `BackupRestoreService._checkEmptySystem`, `lib/core/backup/backup_restore_service.dart` | catalog read | literal `true` | non-emptiness | Restore empty-system preflight | Migrated | Accepted | Contract sufficient; retain |
| PRC-103 | `BusinessDataWipeService._currentCounts`, `lib/core/backup/business_data_wipe_service.dart` | catalog read | literal `true` | length | Owner-wipe pre-count | Migrated | Accepted | Contract sufficient; retain |
| PRC-104 | `ProductController.loadProducts`, `lib/core/catalog/product_controller.dart` | catalog read | permission expression | nine display/edit fields | UI loading/error/success and editing state | Migrated | Accepted | Contract sufficient; retain |
| PRC-105 | `NegativeBalanceApprovalWorkflowService._findProduct/_requireProduct`, `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | `ProductRepository.listProducts` (1 call) | literal `true` | `id`, `isActive`, `updatedAt` | Creates and later revalidates a purchase-product fingerprint | Remaining | F | Contract sufficient, but multi-stage financial concurrency behavior is high risk; defer |
| PRC-106 | `DriftInventoryRepository._findProductById`, `lib/core/inventory/drift_inventory_repository.dart` | catalog read | literal `true` | `id`, `isActive` | Exact first-match lookup for stock queries and movement validation | Migrated | Accepted | Phase 106AH completed it; retain |
| PRC-107 | `InventoryController.load`, `lib/core/inventory/inventory_controller.dart` | catalog read | permission expression | `id`, `name` | UI product selector state | Migrated | Accepted | Contract sufficient; retain |
| PRC-108 | `ProfitabilityActivationService.activate`, `lib/core/inventory_valuation/profitability_activation_service.dart` | `ProductRepository.listProducts` (1 call) | literal `true` | count, order, membership, `id` | Validates every opening and feeds atomic valuation/audit activation | Remaining | F | Contract sufficient, but once-only accounting activation is critical; defer |
| PRC-109 | `DriftPurchaseRepository._validateProduct/_validateProductExists`, `lib/core/purchases/drift_purchase_repository.dart` | `ProductRepository.listProducts` (2 calls) | literal `true` for both | `id`, `isActive` / existence | Validates create and restore paths before their existing writes | Remaining | F | Contract sufficient; smallest safe functional target; migrate next |
| PRC-110 | `PurchaseController.load`, `lib/core/purchases/purchase_controller.dart` | catalog read | permission expression | `id`, `name`, `isActive` | UI product selector state | Migrated | Accepted | Contract sufficient; retain |
| PRC-111 | `LocalSaleRepository._validateProduct/_validateAllMinimumPrices`, `lib/core/sales/sale_repository.dart` | `ProductRepository.listProducts` (1 source call, repeated per item) | literal `true` | `id`, `isActive`, nullable minimum price | Sale validation, minimum-price enforcement, inventory/accounting writes | Remaining | F | Contract sufficient, but broad construction surface and critical sale coupling; defer |
| PRC-112 | `SaleController.load`, `lib/core/sales/sale_controller.dart` | catalog read | literal `false` | `id`, `name`, default/minimum prices | UI sale-entry state | Migrated | Accepted | Contract sufficient; retain |
| PRC-113 | `ProfitabilityReportScreen._activate`, `lib/features/financial_reports/profitability_report_screen.dart` | catalog read | literal `true` | `id`, `name` | Builds activation input UI | Migrated | Accepted | Contract sufficient; retain |
| PRC-114 | `LocalInventoryRepository.allProductBalancesKg/_findProductById`, `lib/core/inventory/inventory_repository.dart` | `ProductRepository.listProducts` (2 calls) | caller expression / literal `true` | `id`, `isActive` | Superseded local inventory implementation | Remaining | I | Not production-reachable after initialization; not an application migration target |
| PRC-115 | `LocalPurchaseRepository._validateProduct`, `lib/core/purchases/purchase_repository.dart` | `ProductRepository.listProducts` (1 call) | literal `true` | `id`, `isActive` | Superseded local purchase command implementation | Remaining | I | Not production-reachable after initialization; exclude from next production target |
| PRC-116 | `SyntheticProfitabilityActivationService.activate`, `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | `ProductDataRepository.listProducts` (1 call) | literal `true` | emptiness | Guards an isolated synthetic sandbox before product writes | Remaining | I | Deliberately unwired and read/write repository-coupled; exclude |
| PRC-117 | `_LegacyProductCatalogReadRepository.listProductCatalog`, `lib/app/app_repositories.dart` | forwarded `ProductRepository.listProducts` (1 call) | forwarded runtime argument | all 11 fields | Default/local compatibility mapping | Remaining | I | Infrastructure adapter, not an application consumer; architectural cleanup only |
| PRC-118 | `_DriftProductSnapshot.capture`, `lib/core/catalog/drift_product_repository.dart` | repository self-call `listProducts()` (1 call) | default `true` | complete ordered `Product` objects | Captures a rollback snapshot restored by the write repository | Remaining | I | Catalog model is not the snapshot/write contract; do not migrate |

Every PRC appears exactly once. No stable identity was created, deleted, or
renumbered.

## 6. Inventory comparison and number reconciliation

Phase 106AG recorded 14 migrated, 10 remaining, 12 legacy calls, 14 catalog
calls, and F5/I5. Phase 106AH migrated PRC-106 exactly once, converting its one
legacy call to one catalog call and moving it out of F. The fresh Phase 106AI
source audit confirms the expected delta without another discrepancy:

```text
Total consumers: 24
Migrated: 15
Remaining: 9
Legacy calls: 11
Product Catalog calls: 15
24 = 15 + 9
Remaining classification: F4 / I5
9 = 4 + 5
```

The 11 legacy call sites occur in nine files. PRC-109 and PRC-114 own two
sites each; every other remaining PRC owns one. The 15 catalog sites belong to
15 migrated consumers, although PRC-010 and PRC-106 share one file. There is no
historical inventory error, missing consumer, extra call, or reclassification
to correct in Phase 106AI.

Migrated PRCs:

```text
PRC-001, PRC-002, PRC-003, PRC-004, PRC-010, PRC-014, PRC-101,
PRC-102, PRC-103, PRC-104, PRC-106, PRC-107, PRC-110, PRC-112,
PRC-113
```

Remaining classification:

```text
F: 4 - PRC-105, PRC-108, PRC-109, PRC-111
I: 5 - PRC-114, PRC-115, PRC-116, PRC-117, PRC-118
```

The historical taxonomy remains valid: F is a production transactional or
domain-command path; I is superseded/unwired/infrastructure behavior or is not
an independent application migration target.

## 7. Independent analysis of the nine remaining consumers

### PRC-105 - Negative-balance purchase product fingerprint

- Identity: one direct legacy call hidden behind `_findProduct`; `_requireProduct`
  and approval revalidation share it.
- Filtering: literal `includeInactive: true`; IDs are rejected when null/blank,
  then compared after trimming the supplied ID. No later list filtering.
- Fields: `id`, `isActive`, and non-null `updatedAt`.
- Behavior: first exact match; null on missing; the request stores the UTC
  timestamp and later requires an exact fingerprint match. Read errors
  propagate. The result participates in approval creation and resolution.
- Risk/action: catalog contract is sufficient, but dependency replacement must
  preserve multi-stage concurrency/fingerprint behavior and financial messages.
  It is not the smallest safe next step.

### PRC-108 - Profitability activation product set

- Identity: one direct legacy read in `activate`.
- Filtering: literal `includeInactive: true`; no later active filtering.
- Fields: product count, order, membership, and `id`.
- Behavior: validates a one-to-one set of opening decisions, checks stock for
  every returned product in returned order, then writes valuation activation
  and audit records atomically. Errors propagate; validation precedes writes.
- Risk/action: catalog contract is sufficient, but count/order changes could
  affect a once-only accounting activation. Keep deferred behind a dedicated
  accounting-focused migration.

### PRC-109 - Drift purchase product validations

- Identity: one consumer with two direct calls: `_validateProduct` for create
  and `_validateProductExists` for restore.
- Filtering: both calls use literal `includeInactive: true`; there is no
  post-read filtering beyond exact ID matching and the create-path active check.
- Fields: create uses `id` and `isActive`; restore uses exact `id` existence.
- Behavior: create uses `where(...).firstOrNull`, preserves first exact match,
  throws `Product was not found.` or `Inactive product cannot be used.`, and
  uses the returned ID. Restore uses `any`, allows inactive historical products,
  and validates every row inside the existing Drift transaction before inserts.
  Read errors propagate without catch, fallback, retry, or dual read.
- Risk/action: the existing catalog contract is exact. The repository has only
  two direct test construction sites plus production composition. Freeze as the
  next target, guarding both call sites, validation order, messages, and restore
  transaction/write ordering.

### PRC-111 - Sale validation and minimum-price enforcement

- Identity: one legacy source call inside `_validateProduct`, invoked repeatedly
  for line validation and transactional sale work.
- Filtering: literal `includeInactive: true`; exact untrimmed ID comparison after
  rejecting blank input.
- Fields: `id`, `isActive`, nullable `minimumSalePricePiastersPerKg`.
- Behavior: preserves per-item read multiplicity, inactive/not-found Arabic
  messages, minimum-price exception values, stock checks, transaction snapshots,
  and accounting/inventory sequencing.
- Risk/action: contract is sufficient, but `LocalSaleRepository` has a very wide
  construction surface and is the delegate used by the durable repository.
  Migration would create a much larger test diff and critical sale risk.

### PRC-114 - Superseded local inventory implementation

- Identity: one local consumer with two legacy calls, one direct and one private
  helper.
- Filtering: caller-derived `includeInactive` for enumeration and literal `true`
  for exact lookup.
- Fields/behavior: `id`, `isActive`, balance enumeration, not-found and inactive
  validation for in-memory writes.
- Risk/action: contract is sufficient, but this implementation is not production
  reachable after durable initialization. Keep I and exclude from a production
  migration target.

### PRC-115 - Superseded local purchase implementation

- Identity: one helper with one legacy call.
- Filtering/fields: literal `true`; exact first match; `id`, `isActive`.
- Behavior: returns the domain product into an in-memory purchase command and
  preserves not-found/inactive messages before writes.
- Risk/action: technically narrow but not production-reachable after durable
  initialization. Keep I; selecting it would not advance the production read
  migration.

### PRC-116 - Synthetic profitability sandbox

- Identity: one `ProductDataRepository` read in an explicitly unwired service.
- Filtering/fields: literal `true`; emptiness only.
- Behavior: product emptiness is the first repository emptiness condition before
  an atomic sequence that creates products, stock, valuation, and audit data.
- Risk/action: the same repository supplies writes and transaction snapshots.
  Splitting the read is an architecture decision for a non-production sandbox,
  not the next production migration.

### PRC-117 - Legacy catalog compatibility adapter

- Identity: one wrapper call, not an application loader.
- Filtering: forwards the required runtime `includeInactive` argument exactly.
- Fields/behavior: maps all 11 `Product` fields losslessly and preserves order
  and errors.
- Risk/action: production initialization replaces it with the Drift catalog
  adapter. Removing the wrapper is infrastructure cleanup and must not be
  misrepresented as a migrated application consumer.

### PRC-118 - Product transaction snapshot self-read

- Identity: one repository self-call in `_DriftProductSnapshot.capture`.
- Filtering: omitted argument uses the repository default `true`.
- Fields/behavior: captures complete ordered domain `Product` objects, then
  rollback clears and restores them through write-repository methods.
- Risk/action: the catalog read model is not a rollback/write snapshot contract.
  Contract substitution would be architecturally wrong; keep I.

## 8. Candidate comparison

| Candidate | Calls / fields | Production diff shape | Coupling | Contract expansion | Decision |
| --- | --- | --- | --- | --- | --- |
| PRC-109 | 2; `id`, `isActive` | repository plus production composition; two direct construction tests | Purchase create and restore, but reads are narrow and independently guardable | No | **Selected** |
| PRC-105 | 1; `id`, `isActive`, `updatedAt` | workflow plus composition and approval fixtures | Multi-stage financial approval fingerprint | No | Defer |
| PRC-108 | 1; set/count/order/`id` | service plus composition and activation fixtures | Once-only profitability/accounting activation | No | Defer |
| PRC-111 | 1 source call repeated per item; `id`, `isActive`, minimum price | sale repository, durable delegate, composition, and many constructors | Critical sales, inventory, valuation, and financial writes | No | Defer |

The I rows are not candidates for the next production migration. PRC-109 wins
despite owning two call sites because its contract is already complete, both
reads are inside one repository and share simple exact-ID semantics, and its
constructor surface is much smaller than PRC-111. It avoids the approval
fingerprint of PRC-105 and the once-only accounting activation of PRC-108.

## 9. Frozen next target

```text
Frozen next target:
PRC: PRC-109
Consumer: DriftPurchaseRepository._validateProduct / _validateProductExists
File: lib/core/purchases/drift_purchase_repository.dart
Member/method: _validateProduct and _validateProductExists
Current dependency: ProductRepository _productRepository
Current call: _productRepository.listProducts(includeInactive: true) at two call sites
Current includeInactive behavior: literal true at both call sites
Fields consumed: id, isActive; exact id existence on restore
Required ProductCatalogReadModel fields: id (String, non-null), isActive (bool, non-null)
Contract expansion required: no
Expected new dependency: ProductCatalogReadRepository _productCatalogReadRepository
Expected new call: _productCatalogReadRepository.listProductCatalog(includeInactive: true) at both call sites
Expected Production files: lib/core/purchases/drift_purchase_repository.dart; lib/app/app_repositories.dart
Behavior that must remain identical: exact and case-sensitive ID matching; first-match create behavior; any-match restore behavior; inactive visibility; create-path inactive rejection; restore-path inactive acceptance; exact errors; error propagation; call ordering; transaction boundaries; no writes before completed restore validation
Forbidden scope: every other PRC; ProductCatalogReadModel or adapter expansion; query/schema/migration/generated changes; purchase write, accounting, inventory, valuation, supplier, replay, cancellation, restore, or transaction redesign; fallback, retry, dual read, normalization, UI, logging, or refactor
Required dedicated tests: both legacy calls removed; literal includeInactive true twice; exact/first-match/not-found/inactive create behavior; inactive restore acceptance; restore missing-product rollback; read error propagation once; validation-before-write and transaction ordering; production composition; no legacy fallback; exact production diff
Primary risks: collapsing two distinct validation semantics; filtering inactive rows; changing firstOrNull to another lookup rule; changing messages; moving restore validation outside its Drift transaction; writes before all restored rows validate; accidental second-consumer migration
Recommended next phase title: Phase 106AJ - Migrate Drift Purchase Product Validation Reads
Recommended branch: codex/phase-106aj-migrate-drift-purchase-product-validation-reads
```

No contract expansion is required. `ProductCatalogReadModel.id` is a non-null
`String` and `isActive` is a non-null `bool`, already sourced directly by the
Drift catalog adapter from the product table. No normalization is permitted.

## 10. Frozen next-phase production diff and contract

Only these production files may change in Phase 106AJ:

```text
lib/core/purchases/drift_purchase_repository.dart
lib/app/app_repositories.dart
```

The repository file may replace the legacy import, constructor parameter,
field, return type, and the two list calls with the existing catalog contract.
The composition file may replace only the named dependency passed to
`DriftPurchaseRepository`. Known direct constructor tests requiring mechanical
dependency updates are:

```text
test/phase8f_durable_purchase_repository_test.dart
test/phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart
```

Required preservation details:

- Create still validates supplier, then product, then draft/payment/replay
  state in the current order.
- `_validateProduct` still scans catalog order and selects the first exact
  `value.id == id` match, rejects null with `Product was not found.`, rejects
  inactive with `Inactive product cannot be used.`, and returns the selected ID.
- Restore still checks each intake's shape, supplier existence, then product
  existence, permits inactive historical products, completes validation before
  any purchase insert, and remains inside the same database transaction.
- Empty lists, missing IDs, duplicates, and read failures retain current
  behavior. No catch, fallback, retry, cache, map rewrite, normalization, or
  direct SQL lookup may be added.
- Purchase writes, stock movements, supplier/financial entries, valuation,
  audit, replay/idempotency, cancellation, sequence allocation, messages, and
  side effects remain byte-for-byte outside the narrow dependency substitution.

## 11. Risk and next-phase test plan

Primary migration risks are confusing create and restore active-state rules,
losing first-match behavior, reducing two reads to a semantically different
shared cache, changing exception timing/text, or moving catalog IO relative to
writes and the restore transaction. The next phase must add executable catalog
spies/sentinels for both helpers, inactive and duplicate cases, errors, and
database rollback evidence, plus static guards for imports, constructor wiring,
exact call multiplicity, production scope, and absence of legacy fallback.

## 12. Phase 106AI changed files and production-diff proof

Phase 106AI changes only this report, its dedicated guard, and the minimum
historical Phase 106 lineage guards that must recognize the exact documentation
and test-only child. No audit tool was created.

Changed files are one governing report and 16 guard files: the new Phase 106AI
guard plus the lineage guards for Phase 106AA, 106AC through 106AH, 106O, 106Q,
106T, 106U, 106V, 106W, 106Y, and 106Z. All 17 paths are under `docs/` or
`test/`.

```text
Production files changed: none
Contract expansion implemented: none
Schema/migration/generated changes: none
Product migration implemented: none
```

The baseline-to-final `lib` diff is empty. The final changed-file list and
immutable commit are recorded by Git and in the handoff after the single commit.

## 13. Verification results

The completed verification result is:

| Check | Result |
| --- | --- |
| Dedicated Phase 106AI guard | PASS - 9 tests, 0 failed |
| All Phase 106 guards | PASS - 335 tests across 36 files, 0 failed |
| Product Catalog guards | PASS - expanded relevant set, 204 tests across 22 files, 0 failed; baseline was 203 |
| Full suite, `--concurrency=1` | PASS - 2,321 passed, 1 unchanged historical skip, 0 failed |
| Full suite, default concurrency | PASS - 2,321 passed, 1 unchanged historical skip, 0 failed |
| Analyzer | PASS - `No issues found!` |
| Formatter | PASS - final rerun produced zero changes |
| `git diff --check` | PASS |
| `git diff bd5d287a56fd96f826c673d775226cb4ad45a247 -- lib` | empty |
| Final worktree | clean after the single commit |

The Phase 106 set was run in five bounded groups because one combined Windows
command exceeded the stable command-line shape; the five actual totals were
58, 71, 57, 103, and 46, which reconcile to 335. No test result is inferred
from a historical baseline.

## 14. Git and release evidence

- Starting HEAD and worktree matched the required Phase 106AH baseline.
- The exact Phase 106AI branch was created before editing.
- Exactly one commit follows the baseline, with subject
  `PHASE 106AI: freeze next product read migration target`.
- The commit contains only allowed documentation and test files.
- Final worktree is clean.
- No push or tag was performed.

## 15. Recommendation

```text
Phase 106AJ - Migrate Drift Purchase Product Validation Reads
Branch: codex/phase-106aj-migrate-drift-purchase-product-validation-reads
Commit: PHASE 106AJ: migrate drift purchase product validation reads
```

Phase 106AJ must migrate only PRC-109 under the frozen contract above.
Phase 106AI does not implement that migration.
