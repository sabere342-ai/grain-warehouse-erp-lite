# Phase 106AN — PRC-111 Product Read Migration & Production Holdout Elimination

## Status

All code, behavioral, static-analysis, release, and diff gates passed on the
pre-commit worktree. Final closure is intentionally recorded by the Git commit,
annotated tag, and clean-tree evidence outside this self-referential document;
this document does not claim `CLOSED` before those Git gates exist.

## Baseline and governance

- Starting branch: `codex/phase-106am-migrate-prc-108-product-read`.
- Starting HEAD: `8802c2115a45785f8705764514f9c7d0250a050d`.
- Previous tag: `phase-106am-profitability-activation-product-read-migration-verified`.
- Git proved the previous tag is an annotated tag and its peeled target is the
  exact starting HEAD.
- The starting worktree was clean. No pre-existing Phase 106AN branch, tag,
  reserved document, or incomplete PRC-111 work was found.
- Work proceeded on
  `codex/phase-106an-migrate-prc-111-product-read` without moving any historical
  tag or rewriting history.

## PRC-111 identity and discovery

The source-defined PRC-111 is
`LocalSaleRepository._validateProduct`, together with its downstream
`_validateAllProducts` and `_validateAllMinimumPrices` use in
`lib/core/sales/sale_repository.dart`. It is production-reachable because
`DriftSaleRepository` delegates sale creation to `LocalSaleRepository`, and
`AppRepositories.initializeProduction` constructs that durable repository.

Before migration, `_validateProduct` called
`ProductRepository.listProducts(includeInactive: true)`, scanned the returned
list in its existing order for the first exact ID, rejected that first match if
inactive, and otherwise returned the product used for minimum-sale-price
validation. Missing products and read errors propagated before persistence.
The validation is invoked once before the durable sale transaction and again
inside it, so a successful one-line sale performs two reads; that snapshot and
transaction behavior was deliberately retained.

The read affects sale validation before stock, COGS, financial-account, audit,
and sale-record writes. It does not itself mutate data. Existing sale, durable
sale, accounting, document-history, split-payment, UI, recovery, backup, and
financial-decision tests cover those downstream consumers.

## GO decision and canonical path

Migration was safe without contract expansion. `ProductCatalogReadModel`
already exposes the exact consumed values with compatible types and nullability:
`id`, `isActive`, and nullable `minimumSalePricePiastersPerKg`. The Drift legacy
and catalog list implementations both query a fresh snapshot, apply the same
active/inactive predicate, and order by `createdAt` followed by `id`. Neither
adds caching or side effects.

After migration, the exact read is:

```dart
productCatalogReadRepository.listProductCatalog(includeInactive: true)
```

The exact-ID sequential scan, first-duplicate behavior, inactive and missing
Arabic `StateError` messages, nullable minimum-price handling, read
multiplicity, mutation visibility, and transaction placement remain unchanged.

## Production wiring and scope

Only these production files changed:

- `lib/core/sales/sale_repository.dart`: replaces the legacy product-read
  dependency and returned model with the canonical read contract/model.
- `lib/core/sales/drift_sale_repository.dart`: forwards the canonical dependency
  to the shared sale delegate.
- `lib/app/app_repositories.dart`: injects the existing production
  `productCatalogReadRepository` into both durable and default local sale
  compositions.

No adapter, fallback, UI change, business-rule change, schema change, database
migration, or generated-file change was introduced. Test fixtures that directly
construct sale repositories were changed only to supply an equivalent catalog
read adapter.

## Behavioral guards

`test/phase106an_prc111_product_read_migration_test.dart` proves:

- the PRC-111 source and durable delegate no longer import or accept
  `ProductRepository`, and the callsite contains no `listProducts` call;
- the canonical read is called with `includeInactive: true` and production
  composition injects it;
- success retains two reads, inventory delta, and persisted sale behavior;
- minimum-price rejection retains its typed fields and causes no writes;
- the first exact duplicate remains authoritative, including inactive rejection;
- missing-product and catalog-read failures propagate before any write; and
- the live Phase 106 call map is exactly six legacy calls and twenty canonical
  calls, with no remaining sale legacy caller.

Historical Phase 106 guards were updated only where the live ratio, cumulative
production scope, accepted canonical caller set, constructor dependency, or
linear Git lineage is directly affected. Assertions that freeze a historical
phase report remain historical.

## Verification evidence

- Focused PRC-111/sales/durable-sale run: **32 passed, 0 failed, 0 skipped**.
- All Phase 106 guard files, run in five bounded batches: **377 passed, 0
  failed, 0 skipped**.
- Full Flutter suite: **2368 passed, 0 failed, 1 skipped**, exit code 0.
- `flutter analyze`: **No issues found**.
- `dart format --output=none --set-exit-if-changed lib test`: **417 files,
  0 changed**, exit code 0.
- `git diff --check`: passed.
- `flutter build windows --release`: passed; fresh output
  `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`.

The CMake minimum-version and MSVC duplicate `.voltbl` messages were warnings;
the release command completed with exit code 0 and produced the executable.

## Persistence and diff audit

The tracked diff contains no Drift schema, schema version, migration, generated,
database, backup-contract, or restore-contract file. Production review confirms
that every changed line is dependency substitution, canonical model typing, the
canonical list call, or production composition for PRC-111. There is no debug
code, commented legacy implementation, temporary compatibility shim, or second
PRC migration.

## Phase 106 map and hold

The code-derived map moved exactly PRC-111:

| State | known | migrated | remaining | production | infrastructure | legacy calls | canonical calls |
|---|---:|---:|---:|---:|---:|---:|---:|
| Phase 106AM baseline | 24 | 18 | 6 | 1 | 5 | 7 | 19 |
| Phase 106AN | 24 | 19 | 5 | 0 | 5 | 6 | 20 |

Production holdouts are therefore zero, so Phase 106AN stops here. The remaining
tracked units are the five non-production/infrastructure rows PRC-114 through
PRC-118. If a later, separately governed phase chooses to reduce that surface,
the next candidate to re-audit is **PRC-114 — `LocalInventoryRepository` local
inventory product reads**. This is a suggestion only; it was not migrated here.

## Git closure and push policy

The intended single commit subject is
`Phase 106AN: migrate PRC-111 product read`, followed by the new annotated tag
`phase-106an-prc-111-product-read-migration-verified` on that exact commit. No
push has occurred, and Phase 106AN does not authorize one.
