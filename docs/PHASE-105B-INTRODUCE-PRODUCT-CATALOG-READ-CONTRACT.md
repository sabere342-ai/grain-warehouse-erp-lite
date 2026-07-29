# Phase 105B — Introduce Product Catalog Read Contract

## Outcome

**Outcome A — FULL SUCCESS: FROZEN PRODUCT CATALOG READ CONTRACT INTRODUCED**

Phase 105B adds and tests the frozen Product Master Catalog read model and
repository abstraction only. It does not add an adapter or connect a production
consumer, so runtime behavior remains unchanged.

## Repository and Git state

| Item | Value |
| --- | --- |
| Branch | `codex/phase-105b-introduce-product-catalog-read-contract` |
| Starting HEAD | `5aac69ce06114ca544b137e12671e967597a630e` |
| Final HEAD | The single Phase 105B commit; recorded in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 105B: introduce product catalog read contract` |
| Starting worktree | Clean |
| Final worktree | Clean after the single commit; verified by post-commit status |
| Push/Tag | Not performed |
| Runtime behavior | Unchanged; the contract has no production consumer |

Files added:

- `lib/core/catalog/product_catalog_read_repository.dart`
- `test/phase105b_product_catalog_read_contract_test.dart`
- `docs/PHASE-105B-INTRODUCE-PRODUCT-CATALOG-READ-CONTRACT.md`
- `docs/PHASE-105B-PRODUCT-CATALOG-READ-CONTRACT-FREEZE.md`

Final diff size: 4 added files, 394 insertions, 0 deletions.

No existing file is modified. No generated file, build artifact, database, or
dependency file is included in the change.

## Governing baseline

The branch starts directly from Phase 105A commit
`5aac69ce06114ca544b137e12671e967597a630e`, whose message is
`PHASE 105A: select and freeze first cloud mobile repository target`.

Before the branch was created, `HEAD`, the current Phase 105A branch, the clean
worktree, the commit message, the repository root, and `git diff --check` were
verified. No reset, merge, rebase, stash, clean, or history rewrite was used.

## Frozen read model

```dart
final class ProductCatalogReadModel {
  const ProductCatalogReadModel({
    required this.id,
    required this.name,
    required this.code,
    required this.unit,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? code;
  final GrainUnit unit;
  final bool isActive;
}
```

The model has exactly five fields:

| Field | Governing type | Meaning |
| --- | --- | --- |
| `id` | `String` | Lossless opaque product identity |
| `name` | `String` | Product display name |
| `code` | `String?` | Optional neutral product code; not defined as a barcode |
| `unit` | `GrainUnit` | Existing domain unit type |
| `isActive` | `bool` | Product master active state |

### Why `String id`

Existing product identities follow a textual pattern such as
`prd-<timestamp>-<sequence>`. Keeping `String` preserves each value losslessly
and prevents parsing, hashing, replacement IDs, or schema assumptions.

### Why the existing `GrainUnit`

`GrainUnit` is already the governing domain type for `kilogram` and `ton`.
The read model imports it directly from `core/catalog/grain_unit.dart`; no new
enum, string conversion, mapping, or relocation was introduced.

The model contains no timestamp, barcode field, price, minimum price, cost,
quantity, availability, valuation, COGS, profitability, supplier, category,
database row, JSON serialization, generated behavior, or UI logic.

## Frozen repository contract

```dart
abstract interface class ProductCatalogReadRepository {
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  });
}
```

This is the only repository method.

- `includeInactive` is required and has no default.
- `false` means active products only.
- `true` allows active and inactive products.
- The result is one complete `Future` snapshot, not a `Stream`.
- There is no search, pagination, limit, offset, sorting argument, incremental
  load, write method, or generic query framework.
- The repository owns no cache.
- A successful retry replaces the prior snapshot completely; it does not
  append, merge, or require consumer deduplication.
- A later controller may retain its last successful snapshot after refresh
  failure, but Phase 105B contains no controller or retry implementation.

## Frozen ordering obligation

Future implementations must return results ordered by:

1. `createdAt ASC`
2. `id ASC`

Phase 105B intentionally does not implement this order. `createdAt` is not a
read-model field, no sorting argument or production comparator was added, and
there is no query or adapter. Phase 105C owns the local Drift implementation
and its ordering parity tests.

## Dependency and platform neutrality

The contract production file imports only the existing `GrainUnit` domain
type. It has no dependency on:

- Flutter widgets or bindings;
- Drift, SQLite, database rows, companions, or generated database code;
- controllers, screens, selectors, providers, or composition root;
- HTTP, cloud SDKs, backend DTOs, sync metadata, auth, or caching;
- product pricing, inventory, sales, profitability, or backup/restore logic.

The focused fake exists only inside the test file. No production fake or
implementation was added.

## Explicitly not implemented

- No `DriftProductRepository` or existing repository change.
- No Drift adapter, SQL, table read, mapping, filtering, or ordering code.
- No controller, screen, selector, provider, composition, or navigation change.
- No product create/update/activation/write contract.
- No search, barcode behavior, pagination, stream, cache, retry state, cloud,
  backend, API, synchronization, or mobile UI.
- No schema, schema-version, migration, product-table, DAO, generated-code,
  dependency, authentication, permission, Audit Log, inventory, sales,
  profitability, or backup/restore change.

## Focused contract evidence

The Phase 105B test proves through normal Dart types and a test-only fake:

- construction with an unchanged textual ID;
- exact field types, including `GrainUnit` and nullable `code`;
- `code: null` fidelity;
- implementation of the repository without database/platform setup;
- required `includeInactive` reception for both values;
- exact `Future<List<ProductCatalogReadModel>>` typing; and
- snapshot order and list identity are returned without fake-side merge or
  mutation.

It is a plain test and does not initialize a Flutter binding, Drift, SQLite,
or any cloud service. No source-formatting test was added.

## Verification gates

| Gate | Result |
| --- | --- |
| Phase 105B focused | PASS — 3 passed, 0 failed, 0 skipped; exit 0; 51.6 s wall time |
| Audit Log focused regression | PASS — 46 passed, 0 failed, 0 skipped; exit 0; 10.8 s wall time |
| Phase 102J isolated | PASS — 5 passed, 0 failed, 0 skipped; exit 0; 4.5 s wall time; revenue 250000, COGS 187500, gross profit 62500 |
| Phase 102 related | PASS — 61 passed, 0 failed, 0 skipped; exit 0; 7.6 s wall time |
| Full Suite | PASS — 1951 passed, 0 failed, 1 unchanged historical skip; exit 0; 153.6 s wall time; exactly 3 new passing tests |
| Formatting | PASS — 370 files checked, 0 changed; 7.31 s |
| Analyzer | PASS — no issues found; exit 0; 98.1 s analyzer time (101.7 s wall time) |
| `git diff --check` | PASS — exit 0 |
| Windows Release | PASS — exit 0; 19.6 s Flutter build time (21.2 s wall time) |
| Native smoke | NOT RUN — production database isolation is not proven |

Windows artifact:

- Path: `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes
- SHA-256: `351ECBC46A77AB345017E0F7479F901A6A2738A439828A6DB5195A7F23932F91`

The single unchanged historical skip is
`test/phase9a_inflows_outflows_reports_test.dart:552`, which requires negative
balance approval with actual credentials. The release build completed with the
existing Firebase CMake minimum-version deprecation and `.voltbl` linker
warnings; neither warning prevented artifact creation.

Native smoke was not run because production database isolation was not proven.
No user or production database was opened or touched.

## Governing decision for Phase 105C

After all recorded gates pass and the single commit is created, that commit is
the governing baseline for Phase 105C.

Phase 105C may implement only the local Drift adapter for this exact contract,
using lossless `String` product identifiers and the existing `GrainUnit` type.
It must implement `includeInactive` and `createdAt ASC, id ASC` ordering without
adding model fields or contract parameters. Controller and UI migration remain
prohibited.
