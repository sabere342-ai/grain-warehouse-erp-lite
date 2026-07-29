# Phase 105C — Implement Local Drift Product Catalog Read Adapter

## Outcome

**Outcome A — FULL SUCCESS: LOCAL DRIFT READ ADAPTER IMPLEMENTED**

Phase 105C implements the local Drift adapter for the frozen Product Catalog
read contract. It adds no production consumer, Controller migration, UI change,
cloud behavior, synchronization behavior, schema change, or write behavior.

## Repository and Git state

| Item | Value |
| --- | --- |
| Branch | `codex/phase-105c-implement-local-drift-product-catalog-read-adapter` |
| Starting HEAD | `e0b0424f52618f250be44b976a5b9e12b55d7a24` |
| Canonical starting commit message | `PHASE 105B: introduce product catalog read contract` |
| Final commit | The single Phase 105C commit; its hash is recorded in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 105C: implement local drift product catalog read adapter` |
| Starting worktree | Clean |
| Final worktree | Clean after the single commit; verified post-commit |
| Push/Tag | Not performed |

The attachment labels the starting commit message differently, but the exact
governing SHA resolves canonically in Git to the message recorded above. The
SHA matched exactly, there were zero commits after it, and no history operation
was used.

Files added:

- `lib/core/catalog/drift_product_catalog_read_repository.dart`
- `test/phase105c_local_drift_product_catalog_read_adapter_test.dart`
- `docs/PHASE-105C-IMPLEMENT-LOCAL-DRIFT-PRODUCT-CATALOG-READ-ADAPTER.md`

No existing file, generated file, dependency file, database, schema version,
migration, Controller, screen, widget, composition root, or runtime consumer is
modified. Final diff size: 3 added files, 478 insertions, 0 deletions.

## Mandatory discovery findings

The existing Drift schema defines the `Products` table in
`lib/core/persistence/foundation_database.dart`.

| Concern | Existing storage | Adapter decision |
| --- | --- | --- |
| Product ID | Non-null `TextColumn id`, primary key | Read directly as lossless `String`; no parsing or regeneration |
| Name | Non-null `TextColumn name` | Read directly as `String` |
| Code | Nullable `TextColumn code` | Read directly as `String?`; `null` remains `null` |
| Unit | Non-null `TextColumn unit` | Convert with the existing `GrainUnit.fromWireName` production mapping |
| Activity | Non-null `BoolColumn isActive` | Read directly as the stored `bool` |
| Creation order | Non-null `DateTimeColumn createdAt` | SQL/Drift ordering key only; not added to the read model |

The table also contains normalized, pricing, cost, notes, and update timestamp
columns. The adapter does not select or expose them. All frozen source columns
are non-null except `code`, whose nullability exactly matches the contract, so
there is no legacy-null substitution.

The existing production `DriftProductRepository` stores units with
`GrainUnit.wireName` and reads them with `GrainUnit.fromWireName`. The new
adapter uses the same mapper. An unknown stored value throws explicitly; there
is no invented unit or silent fallback.

The existing write-oriented product repository already contains the same
ordering behavior for legacy product reads, but it returns the larger mutable
domain model and owns writes, restore, wipe, and sequence behavior. A separate
read adapter therefore keeps the new boundary narrow and avoids altering any
legacy runtime surface. The Audit Log Drift adapter provided the architectural
reference for implementing a frozen read interface over the existing database.

No schema or migration is needed: every required field and both ordering keys
already exist with lossless governing types in schema version 15.

## Adapter implementation

`DriftProductCatalogReadRepository` implements
`ProductCatalogReadRepository` directly and exposes only:

```dart
Future<List<ProductCatalogReadModel>> listProductCatalog({
  required bool includeInactive,
});
```

The method uses `selectOnly(products)` and selects exactly `id`, `name`, `code`,
`unit`, and `isActive`. It reads no other table, starts no transaction, and
performs no insert, update, delete, cache, merge, or other side effect.

### Frozen field mapping

| Database expression | Read-model field | Proof |
| --- | --- | --- |
| `products.id` | `String id` | Direct typed read preserves values such as `prd-<timestamp>-<sequence>` |
| `products.name` | `String name` | Direct typed read |
| `products.code` | `String? code` | Direct nullable read; no empty-string substitution |
| `products.unit` | `GrainUnit unit` | Existing `GrainUnit.fromWireName` mapper; no parallel enum or fallback |
| `products.isActive` | `bool isActive` | Direct stored boolean read |

### `includeInactive`

When `includeInactive` is `false`, the Drift query adds
`products.isActive.equals(true)`, so inactive rows are excluded by SQLite.
When it is `true`, no activity predicate is added and both stored states are
returned. No in-memory filtering is used.

### Deterministic ordering

The Drift query always applies these database ordering terms:

1. `OrderingTerm.asc(products.createdAt)`
2. `OrderingTerm.asc(products.id)`

The adapter does not sort in memory. The focused test inserts rows in a
different order and includes a real `createdAt` tie with different IDs.

## Focused test coverage

The Phase 105C file contains nine tests:

1. implementation and invocation through `ProductCatalogReadRepository`;
2. active-only filtering with no inactive leakage;
3. inclusion and faithful activity mapping of active and inactive rows;
4. all five frozen fields, textual IDs, nullable code, and both `GrainUnit`
   values;
5. deterministic `createdAt ASC, id ASC` ordering with a real tie-break;
6. a typed empty snapshot for an empty database;
7. read-only preservation of products, timestamps, activity, repository
   sequences, and an unrelated foundation table value;
8. an architectural guard proving the adapter is not wired into production,
   uses a projection-only read, and contains no write/cloud/sync surface; and
9. explicit failure for an unknown stored unit rather than a fallback.

All database tests use `openInMemoryTestDatabase`. They never resolve or open
the production database path.

## Verification gates

| Gate | Result |
| --- | --- |
| Phase 105C focused | PASS — 9 passed, 0 failed, 0 skipped; exit 0; 4.7 s wall time |
| Phase 105B contract regression | PASS — 3 passed, 0 failed, 0 skipped; exit 0; 9.6 s wall time |
| Audit Log repository-boundary regression | PASS — 46 passed, 0 failed, 0 skipped; exit 0; 16.9 s wall time |
| Phase 102J isolated | PASS — 5 passed, 0 failed, 0 skipped; exit 0; 9.9 s wall time |
| Phase 102 related regression | PASS — 61 passed, 0 failed, 0 skipped; exit 0; 14.6 s wall time |
| Full suite | PASS — 1960 passed, 0 failed, 1 unchanged historical skip; exit 0; 153.1 s wall time; exactly 9 new passing tests |
| Formatter | PASS — 372 files checked, 0 changed; exit 0; 3.23 s |
| Analyzer | PASS — no issues found; exit 0; 27.5 s analyzer time (30.7 s wall time) |
| Windows release | PASS — exit 0; 15.3 s Flutter build time (16.7 s wall time) |
| `git diff --check` | PASS — exit 0 |
| Native smoke | NOT RUN — production database isolation not proven |

Windows artifact:

- Path: `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes
- SHA-256: `E6475802545212662F0BBE18C5CAE86BB26AC1A914831E294D57ACD4940AB5F5`

The sole unchanged historical skip remains
`test/phase9a_inflows_outflows_reports_test.dart:552`, which requires negative
balance approval with actual credentials. The release build emitted the
existing Firebase CMake minimum-version deprecation and `.voltbl` linker
warnings; neither warning prevented artifact creation. `git diff --check`
also reported existing line-ending normalization notices for generated Windows
plugin registration files, but returned exit 0 and none of those files is
modified or included in this phase.

Native smoke was not run because production database isolation was not proven.
No user or production database was opened or touched.

## Explicitly unchanged and out of scope

- The frozen `ProductCatalogReadModel` and `ProductCatalogReadRepository` are
  unchanged.
- No `ProductController`, product screen, widget, provider, selector,
  application repository wiring, navigation, or legacy product read is changed.
- No cloud repository, HTTP, REST, GraphQL, Firebase, Supabase, sync queue,
  conflict resolution, cache, offline-first behavior, pagination, search, or
  additional filtering is introduced.
- No write method, create, update, delete, export, restore, schema, generated
  code, migration, schema-version, serialization, or backup format is changed.
- No push or tag is performed.

## Proposed boundary for Phase 105D

Phase 105D is not implemented here. A possible atomic scope is:

> Migrate one Product Catalog controller or application read boundary to depend
> on the frozen `ProductCatalogReadRepository`, without UI redesign and without
> cloud implementation.

This is a proposal only and is not approval to execute Phase 105D.
