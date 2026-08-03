# Phase 106AJ - Migrate Drift Purchase Product Validation Reads

## 1. Identity and outcome

| Evidence | Value |
| --- | --- |
| Outcome | Outcome A - FULL SUCCESS |
| Branch | `codex/phase-106aj-migrate-drift-purchase-product-validation-reads` |
| Starting HEAD | `7acac87799fc8345671f356cce273d345c38b565` |
| Final HEAD | immutable commit recorded in the final handoff |
| Required commit subject | `PHASE 106AJ: migrate drift purchase product validation reads` |
| Required parent | `7acac87799fc8345671f356cce273d345c38b565` |
| Commits after baseline | `1` after the final commit |
| Starting worktree | clean |
| Final worktree | clean after the final commit |
| Push / tag | none |

Phase 106AJ migrates only the frozen `PRC-109` consumer and removes its
product-validation dependency on the legacy product repository. No other
consumer or runtime behavior is changed.

## 2. Scope and implementation

- Consumer: `PRC-109`.
- Members: `DriftPurchaseRepository._validateProduct` and
  `DriftPurchaseRepository._validateProductExists`.
- Old dependency: `ProductRepository`.
- Old read: `listProducts(includeInactive: true)` at two call sites.
- New dependency: `ProductCatalogReadRepository`.
- New read: `listProductCatalog(includeInactive: true)` at two call sites.
- Consumed data: existence, `id`, and `isActive`.
- Contract expansion: none. The existing non-null `id` and `isActive` fields
  are sufficient.

Production changes are confined to:

```text
lib/core/purchases/drift_purchase_repository.dart
lib/app/app_repositories.dart
```

The repository file replaces only its read contract, field, constructor
parameter, helper return type, and two calls. The composition root passes the
already-existing production catalog repository. Direct constructor fixtures in
`phase8f` and `phase106n` receive the same mechanical dependency update.

Non-production changes comprise the dedicated 106AJ guard, those two direct
constructor fixtures, and 21 historical inventory/caller/scope/lineage guards.
The historical changes only move `PRC-109` from legacy to catalog, reconcile
the measured 9/17 call counts, admit the exact 106AJ child of Phase 106AI, and
add the one new production path to cumulative forward scopes. No unrelated
assertion was removed or weakened.

## 3. Behavior preservation

| Case | Before Phase 106AJ | After Phase 106AJ |
| --- | --- | --- |
| Active product on create | first exact ID match succeeds | identical |
| Inactive product on create | `StateError('Inactive product cannot be used.')` | identical |
| Missing product on create | `StateError('Product was not found.')` | identical |
| Duplicate IDs on create | first exact catalog-order match controls the result | identical |
| Inactive product on restore | existence is sufficient; restore is allowed | identical |
| Missing product on restore | `StateError('Product was not found.')` | identical |
| Catalog/read failure | propagates without catch, retry, or fallback | identical |

Create still validates the supplier and then the product before draft/payment
checks and before transaction-backed writes. Restore still validates intake
shape, supplier existence, and product existence for every row inside the
existing Drift transaction before the first insert. The two reads remain
separate. Validation failures and read failures produce no purchase, inventory,
financial, valuation, supplier-account, or audit write.

No error type or message, active-product policy, search rule, call ordering,
transaction boundary, write operation, or side effect changed.

## 4. Inventory reconciliation

### Before Phase 106AJ

```text
Total consumers: 24
Migrated: 15
Remaining: 9
Remaining production consumers: 4
Remaining infrastructure/test consumers: 5
Legacy listProducts calls: 11
Product Catalog listProductCatalog calls: 15
```

### After Phase 106AJ

```text
Total consumers: 24
Migrated: 16
Remaining: 8
Remaining production consumers: 3
Remaining infrastructure/test consumers: 5
Legacy listProducts calls: 9
Product Catalog listProductCatalog calls: 17
```

The call delta is two rather than one because the single `PRC-109` consumer
owns two validation call sites. `PRC-109` still counts exactly once in the
24-consumer inventory.

Remaining production targets:

```text
PRC-105, PRC-108, PRC-111
```

Remaining infrastructure/test consumers:

```text
PRC-114, PRC-115, PRC-116, PRC-117, PRC-118
```

## 5. Verification

All results below are from commands executed at the application root. The
final measured results are recorded after the complete verification run.

| Check | Command | Result |
| --- | --- | --- |
| Dedicated Phase 106AJ guard | `flutter test test/phase106aj_migrate_drift_purchase_product_validation_reads_test.dart` | PASS - 11 passed, 0 failed |
| Drift purchase tests | `flutter test test/phase8f_durable_purchase_repository_test.dart test/phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart` | PASS - 13 passed, 0 failed |
| All Phase 106 tests | bounded Phase 106 test groups | PASS - 335 passed across 37 files, 0 failed |
| Expanded Product Catalog suite | 40 live Phase 105B-F / Phase 106 files importing `ProductCatalogReadRepository` | PASS - 357 passed, 0 failed |
| Full suite, serialized | `flutter test --concurrency=1` | PASS - 2,332 passed, 1 unchanged historical skip, 0 failed |
| Full suite, default concurrency | `flutter test` | PASS - 2,332 passed, 1 unchanged historical skip, 0 failed |
| Analyzer | `flutter analyze` | PASS - `No issues found!` |
| Formatter | Dart SDK formatter on changed Dart files | PASS - 26 files checked, 0 changed on final run |
| Diff whitespace | `git diff --check` | PASS - exit 0 |
| Production scope | `git diff 7acac877... --name-only -- lib` | PASS - exactly the two allowed files |

The 40-file Product Catalog list was derived from the current tree by selecting
Phase 105B-F and Phase 106 tests that import the catalog read contract. Its
Phase 106 members are included in the 37-file Phase 106 run; the five Phase
105B-F files contributed 38 additional passing tests. A single 40-file process
exceeded the stable Windows command timeout, so the same exact files were
verified in bounded successful runs and the totals above are reconciled from
their actual terminal counters. No success is inferred from the timed-out
process.

## 6. Explicit exclusions

- No contract or `ProductCatalogReadModel` expansion.
- No schema changes.
- No migrations.
- No generated changes.
- No product query or adapter changes.
- No financial behavior changes.
- No accounting changes.
- No inventory, purchase-write, supplier, replay, cancellation, or valuation
  behavior changes.
- No unrelated production changes.
- No legacy fallback, dual read, retry, cache, or adapter.
- No push.
- No tag.

## 7. Lineage and recommendation

The direct predecessor is Phase 106AI at
`7acac87799fc8345671f356cce273d345c38b565`. The final Phase 106AJ commit has
that commit as its direct parent, and the final handoff records its immutable
hash and clean-worktree assertions.

Recommended next phase title:

```text
Phase 106AK - Re-audit and Freeze Next Product Read Migration Target
```
