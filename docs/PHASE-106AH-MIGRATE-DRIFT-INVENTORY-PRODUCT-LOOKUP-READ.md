# Phase 106AH — Migrate Drift Inventory Product Lookup Read

## Outcome

**Outcome A — FULL SUCCESS**

| Evidence | Value |
| --- | --- |
| Branch | `codex/phase-106ah-migrate-drift-inventory-product-lookup-read` |
| Starting HEAD | `25f4896b45fd8848a3aa5390e57a30926b9a9a24` |
| Starting worktree | clean |
| Commits after baseline at start | `0` |
| Final commit message | `PHASE 106AH: migrate drift inventory product lookup read` |
| Final HEAD | Created after this report is staged; the immutable hash is recorded in the final handoff because a commit cannot contain its own hash |
| Changed files | `26` including this report |
| Production files | `2` |
| Push / Tag | none |

## Migration

| Item | Before | After |
| --- | --- | --- |
| PRC | `PRC-106` | `PRC-106` migrated |
| Consumer | `DriftInventoryRepository._findProductById` | unchanged consumer |
| Dependency | `ProductRepository _productRepository` | existing `ProductCatalogReadRepository _productCatalogReadRepository` |
| Call | `_productRepository.listProducts(includeInactive: true)` | `_productCatalogReadRepository.listProductCatalog(includeInactive: true)` |
| Fields consumed | `id`, `isActive` | `id`, `isActive` |
| Contract expansion | none | none |

`ProductRepository` was removed completely from the
`DriftInventoryRepository` constructor, field list, and imports. The production
composition in `AppRepositories.initializeProduction` now passes only the
already-composed `ProductCatalogReadRepository` to `DriftInventoryRepository`.
The compatibility tool construction and direct test constructions were updated
only for the removed constructor argument.

The production chain is now:

`AppRepositories.initializeProduction` → `DriftInventoryRepository` →
`ProductCatalogReadRepository.listProductCatalog(includeInactive: true)`.

It no longer reaches `ProductRepository.listProducts` for PRC-106.

## Contract sufficiency

`ProductCatalogReadModel` already exposes both required fields: `id` for the
exact lookup and `isActive` for the existing movement validation. No field,
method, type, adapter behavior, query, schema, migration, schema version, or
generated file changed.

## Behavior preservation

- `includeInactive: true` remains literal, so inactive products reach the
  existing validation instead of becoming indistinguishable from missing rows.
- The helper still scans in returned order and returns the first product whose
  `product.id == id`; matching remains exact and case-sensitive.
- It still returns `null` only after the snapshot contains no exact match.
- Missing products still produce `StateError('Product was not found.')` at the
  existing callers.
- Inactive products still produce
  `StateError('Inactive product cannot accept stock movements.')` at the same
  validation point.
- Product Catalog read errors propagate unchanged. There is no catch, fallback,
  retry, dual read, logging, or error translation.
- Movement inserts, stock balance reads, negative-stock prevention, sequence
  allocation, operation order, and transaction boundaries are unchanged.
- Executable guards prove that catalog reads occur before movement/sequence
  writes and that a read failure leaves both tables unchanged.

## Production diff

Only these production files differ from the baseline:

- `lib/core/inventory/drift_inventory_repository.dart`: removes the legacy
  dependency and migrates `_findProductById` to the catalog snapshot.
- `lib/app/app_repositories.dart`: stops passing `productRepository` to the
  inventory repository.

There are no side changes under persistence, schema, migrations, generated
files, UI, cloud, mobile, backup formats, controllers, accounting, or inventory
write logic.

## Updated inventory

The final `lib/**/*.dart` inventory was measured from source:

| Measure | Count |
| --- | ---: |
| Total consumers | 24 |
| Migrated | 15 |
| Remaining | 9 |
| Legacy calls | 11 |
| Product Catalog calls | 15 |
| Remaining classification | `F4 / I5` |

PRC-106 moved from the functional remaining group to migrated. The remaining
functional consumers are PRC-105, PRC-108, PRC-109, and PRC-111. The remaining
infrastructure consumers are PRC-114 through PRC-118.

## Tests and verification

| Check | Result |
| --- | --- |
| Dedicated Phase 106AH guard | PASS — 9 tests |
| Direct inventory and composition tests | PASS |
| All Phase 106 guards | PASS — 326 tests across 35 files |
| Product Catalog contract/repository guards | PASS — 203 tests across 21 files |
| Full suite, `--concurrency=1` | PASS — 2312 passed, 1 existing skip |
| Full suite, default concurrency | PASS — 2312 passed, 1 existing skip |
| Analyzer | PASS — `No issues found!` |
| Formatter | PASS — final run produced zero changes |
| `git diff --check` | PASS |
| Production diff review | PASS — exactly the two production files above |
| Schema/generated/migration review | PASS — no changes |
| Final commit count after baseline | verified as `1` after commit |
| Final worktree | verified clean after commit |

The dedicated guard covers constructor/dependency removal, production wiring,
literal inactive visibility, exact-ID matching, first-match behavior,
not-found behavior, unchanged inactive rejection text, single-attempt error
propagation, no legacy fallback, and write/sequence ordering. Historical guards
were updated only where their forward-lineage allowlists, live inventory, or
post-106AG lineage became obsolete.

## Artifacts

- Governing report:
  `docs/PHASE-106AH-MIGRATE-DRIFT-INVENTORY-PRODUCT-LOOKUP-READ.md`
- Dedicated guard:
  `test/phase106ah_migrate_drift_inventory_product_lookup_read_test.dart`
- Updated historical guards: Phase 106AA through Phase 106AG and the applicable
  Phase 106M/106O/106Q/106T/106U/106V/106W/106Y/106Z forward-lineage guards.
- Updated direct construction tests: Phase 8E/8F/8G and Phase 106M/106N/106S/106V.
- Tool created: none.
- Existing tool updated:
  `tool/run_phase102j_synthetic_trial.dart` only to remove the deleted
  constructor argument.

## Recommended next phase

Re-audit the nine remaining product-read consumers against the final 106AH
tree, then select the next safe migration target in a separate phase. This
report does not freeze a new target beyond Phase 106AH.
