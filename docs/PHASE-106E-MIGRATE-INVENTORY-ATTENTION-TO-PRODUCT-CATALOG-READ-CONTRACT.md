# Phase 106E — Migrate Inventory Attention to Product Catalog Read Contract

## Outcome

**Outcome A — FULL SUCCESS**

`InventoryAttentionService.loadAttention` now consumes the frozen
`ProductCatalogReadRepository` contract. All Phase 106D semantics, both real
dashboard call chains, production Drift composition, and the independent
legacy product read owned by `DashboardService.load` remain intact.

## Git evidence

| Item | Value |
| --- | --- |
| Branch | `codex/phase-106e-migrate-inventory-attention-to-product-catalog-read-contract` |
| Baseline | `aa97774553a17ab707e5ce271346f873173f0c58` |
| Baseline subject | `PHASE 106D: discover and freeze next product read consumer target` |
| Initial worktree | Clean |
| Final commit | The single Phase 106E commit containing this report; the immutable SHA is recorded in the final handoff |
| Commit message | `PHASE 106E: migrate inventory attention to product catalog read contract` |
| Commits after baseline | Exactly `1` after the final commit |
| Push / tag | Neither performed |

## Scope and files

Production changes are limited to four files:

- `lib/core/inventory/inventory_attention_service.dart`
- `lib/core/dashboard/dashboard_service.dart`
- `lib/features/dashboard/dashboard_alerts_section.dart`
- `lib/features/dashboard/dashboard_screen.dart`

Test changes update direct constructors, production-chain fixtures, and
revision-pin historical phase assertions whose original purpose is to prove an
earlier commit rather than the current worktree. The new governing acceptance
test is:

- `test/phase106e_inventory_attention_product_catalog_read_migration_test.dart`

The governing report is this file. No contract, adapter, schema, migration,
generated Drift file, backup format, financial rule, UI text, or dependency was
changed.

## Runtime path before migration

```text
Dashboard callers / InventoryAttentionTool
→ InventoryAttentionService.loadAttention
→ ProductRepository.listProducts(includeInactive: true)
→ ProductDataRepository / DriftProductRepository
→ products table
→ InventoryRepository.allProductBalancesKg()
```

## Runtime path after migration

```text
Dashboard callers / InventoryAttentionTool
→ InventoryAttentionService.loadAttention
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository
→ Drift / in-memory-or-production SQLite products table
→ InventoryRepository.allProductBalancesKg()
```

The dependency is constructor-injected as
`ProductCatalogReadRepository productCatalogReadRepository`. Production path A
(`OwnerAlertData.load`) defaults it from
`AppRepositories.productCatalogReadRepository`. Production path B passes the
same composition dependency through `DashboardScreen` into `DashboardService`,
which constructs `InventoryAttentionService` with it.

`DashboardService` still receives and stores its separate `ProductRepository`.
Its own direct `listProducts(includeInactive: true)` read is deliberately not
migrated in Phase 106E.

## Phase 106D semantic preservation

The new unit, structural, and genuine in-memory Drift tests prove all frozen
behavior:

- `includeInactive: true` is passed exactly once and inactive qualifying
  products remain visible with their original `isActive` value.
- Product identity uses only `id`, `name`, and `isActive`; code, unit, prices,
  cost, notes, and timestamps are not inspected by the consumer.
- `balances[product.id] ?? 0` is unchanged, so a missing balance is out of
  stock at exactly zero.
- Quantities `<= 0` are `outOfStock`, `1..5` are `lowStock`, and values above
  `5` are omitted.
- Ordering remains attention type, quantity ascending, name ascending, then ID
  ascending.
- The result remains `List<InventoryAttentionItem>.unmodifiable`.
- Catalog errors propagate unchanged. The catalog is called once, there is no
  retry, and the inventory read is not used as a fallback.
- Every invocation rereads both repositories; a changed second snapshot is
  observed and no cache is retained.
- Structural assertions exclude `try/catch`, product writes, inventory writes,
  transactions, direct Drift/SQLite bypass, and cache behavior.
- SQLite before/after snapshots prove that the genuine runtime read does not
  modify products or inventory movements.

## Production composition proof

The runtime test initializes `AppRepositories.initializeProduction` with
`openInMemoryTestDatabase()`, verifies that
`AppRepositories.productCatalogReadRepository` is a
`DriftProductCatalogReadRepository`, constructs the service from production
composition, and reads synthetic active/inactive products and real inventory
movements. It also inserts a product between two calls and proves that the
second call sees the new row.

Only an in-memory SQLite database and synthetic fixtures were used. The user
database was not opened, read, copied, migrated, backed up, or modified.

## Verification results

| Gate | Result |
| --- | --- |
| Phase 106E focused test alone | PASS — 9 passed, 0 failed, 0 skipped |
| Selected consumer and dashboard regressions | PASS — 86 passed, 0 failed, 0 skipped; 12.5 s |
| Phases 105B–105F and 106A–106D | PASS — 68 passed, 0 failed, 0 skipped; 10.6 s |
| Audit Log plus Phase 102 regressions | PASS — 107 passed, 0 failed, 0 skipped; 14.4 s |
| Full suite | PASS — 2025 passed, 0 failed, 1 unchanged historical skip; Flutter 2:26, 155.6 s wall time |
| Formatter | PASS — `dart format .` checked 383 files, 0 changed; 5.14 s |
| Analyzer | PASS — `No issues found!` |
| Windows release build | PASS — compiler/build 58.0 s, 60.4 s wall time |
| `git diff --check` | PASS |
| Native smoke | Not run; isolation from the user production database was not proven |

The successful build retained only the existing non-fatal Firebase CMake
minimum-version deprecation warning and MSVC `LNK4078` `.voltbl` warning. The
first sandboxed build attempt timed out without a compiler diagnostic; the
same build command succeeded when Flutter and MSVC were allowed their required
SDK/toolchain access.

## Windows artifact

| Item | Value |
| --- | --- |
| Path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| Size | `784384` bytes |
| SHA-256 | `4D63BC3CDFBE7A68B36347262CC38217C06A2D46D257A0C20561AE685C082C5E` |
| Build timestamp | `2026-07-30 17:26:52` local time |

The executable was not launched. Native smoke was not run.

## Diff and repository state

The final staged diff is `19 files changed, 793 insertions(+), 124 deletions(-)`:
17 modified files and two new Phase 106E artifacts. `git diff --check` passes. After
the single final commit, `git status --short` must be empty and the revision
count from the baseline must be exactly one.

## Residual risk

The inventory balance repository still performs its own legacy product read as
part of its existing contract. Phase 106E does not migrate or redesign that
independent dependency. The selected consumer itself has no legacy product
read or fallback.

## Next atomic phase

Proposed only: **Phase 106F — Discover and Freeze the Next Product Read
Consumer Target**. No Phase 106F work is implemented here.
