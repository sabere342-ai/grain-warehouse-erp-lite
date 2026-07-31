# Phase 106S — Prove Genuine Runtime `InventoryController.load` Product Catalog Read Integration

## Outcome

**Outcome A — FULL SUCCESS**

Phase 106S proves that the production `InventoryController.load` path runs
end-to-end through genuine runtime SQLite (Drift in-memory), the real
`DriftProductCatalogReadRepository` adapter, and the Phase 106R migrated
`ProductCatalogReadRepository.listProductCatalog(...)` boundary — wired through
the genuine `AppRepositories` production composition exactly as the three
production inventory screens (`InventoryScreen`, `StockTakeScreen`,
`StockAdjustmentReportScreen`) construct it. `load` executes with no call —
direct or indirect — to the legacy `ProductRepository.listProducts()` surface.

## Phase data

| Item | Value |
| --- | --- |
| Branch | `codex/phase-106s-prove-runtime-inventory-controller-product-catalog-read-integration` |
| Starting HEAD | `ad03bd0b27109ac2ec97d80ffa32fca22d0f41d9` (`PHASE 106R: migrate inventory controller product catalog read`) |
| Initial worktree | Clean |
| Final HEAD | The single Phase 106S commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 106S: prove runtime inventory controller product catalog integration` |
| Commits after baseline | Exactly `1` required and verified after commit |
| Final worktree | Clean required and verified after commit |
| Final phase diff | `3 files changed` (1 new test file, 2 historical freeze guards extended) |
| Push / Tag | Not performed / not created |

## Why a runtime proof for this target is required

Phase 106R migrated `InventoryController.load` to the catalog read contract but
was, by its own scope, a controller-level migration plus source/freeze guards —
explicitly **not** a full-interface runtime integration proof (106N scope).
Phase 106S closes that gap: it executes the genuine production composition and
the genuine Drift stack over real SQLite with real data seeded directly into the
`products` and `inventory_movements` tables.

The proof also defends against the exact failure class that blocked Phase 106L:
a legacy indirect `listProducts()` call remaining reachable inside the runtime
path. The audit confirmed the migrated path — `InventoryController.load` →
`ProductCatalogReadRepository.listProductCatalog` plus
`DriftInventoryRepository.allProductBalancesKg` (itself on the catalog contract
since Phase 106M) — has no remaining legacy product read. The
`allProductBalancesKg` legacy `listProducts(` call site in
`drift_inventory_repository.dart` lives in a different method
(`restoreMovementsIntoEmpty`) that is not reachable from `load`.

## Executable path proven in Phase 106S

```text
InventoryController.load(AppUser user)
→ ProductCatalogReadRepository.listProductCatalog(
    includeInactive: user.permissions.canCreateStockAdjustment)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository
→ Drift select on the real products table
→ SQLite in-memory (NativeDatabase.memory)

InventoryController.load
→ InventoryRepository.allProductBalancesKg(
    activeProductsOnly: !user.permissions.canCreateStockAdjustment)
→ ProductCatalogReadRepository.listProductCatalog (Phase 106M contract)
→ Drift listMovementsByProduct(product.id) / StockMovement.signedQuantityKg fold
→ SQLite in-memory
```

`load` also reads `InventoryRepository.listAllMovements()` through the same
genuine Drift stack; all three reads are pure SQLite reads.

## Production composition proven

### Genuine `AppRepositories` composition root

The primary group calls `AppRepositories.initializeProduction()` against an
in-memory `FoundationDatabase` and constructs `InventoryController` with the
exact `AppRepositories.*` arguments the three production screens use. The test
asserts the resolved production composition identity:

- `AppRepositories.database` is the injected in-memory database.
- `AppRepositories.productCatalogReadRepository` is a real
  `DriftProductCatalogReadRepository`.
- `AppRepositories.inventoryRepository` is a real `DriftInventoryRepository`.

### Manual fixture (runtime tripwire proof)

A second group composes the genuine Drift stack manually with a **throwing
legacy sentinel** at the `productRepository` seam — exactly where production
injects `DriftProductRepository`:

```text
DriftProductCatalogReadRepository(database)
DriftInventoryValuationRepository(database)
DriftInventoryRepository(
  database,
  productRepository: <throwing legacy sentinel>,
  productCatalogReadRepository: DriftProductCatalogReadRepository(database),
)
InventoryController(
  inventoryRepository: <DriftInventoryRepository>,
  productCatalogReadRepository: <DriftProductCatalogReadRepository>,
  inventoryValuationRepository: <DriftInventoryValuationRepository>,
  financialAccountRepository: null,
  auditLogRepository: null,
)
```

The `<throwing legacy sentinel>` is a real `ProductRepository` implementation
whose `listProducts()` throws `StateError` and increments a counter. It is a
test double only for the side component not under proof; every repository under
proof — `ProductCatalogReadRepository`, `DriftProductCatalogReadRepository`,
`DriftInventoryRepository`, the Drift valuation adapter, and SQLite — is real.
Both scenarios assert `legacy.listProductCalls == 0` after `load`. Any legacy
read inside the load path would throw and fail the test.

## SQLite data used

Products are seeded into the real `products` table with id, name,
`normalizedName`, code, `normalizedCode`, unit (`GrainUnit.kilogram`), isActive,
reference cost, and fixed `createdAt`/`updatedAt` timestamps. Movements are
seeded into the real `inventory_movements` table (id, productId, movementType,
quantityKg, createdByUserId, createdAt). The owner role is `UserRole.owner`
(`canCreateStockAdjustment: true`); the employee role is `UserRole.employee`
(`canCreateStockAdjustment: false`).

## Assertions proven

1. **Production composition identity** — `AppRepositories` resolves to the
   Drift adapters; `load` through `_productionController()` returns the seeded
   catalog row by id and name.
2. **Owner sees active and inactive** — owner `load` returns both the active and
   the inactive product, preserving `referenceCostPricePiastersPerKg` exactly.
3. **Employee sees active only** — employee `load` filters inactive products
   through `includeInactive: false`.
4. **Empty products table** — `load` completes with `isLoading` false,
   `errorMessage` null, and `products` empty.
5. **Re-read without cache** — after a second `load`, a product added later and
   a product renamed directly in SQLite are both reflected; no hidden cache.
6. **No writes** — a full snapshot of the `products` rows, `inventory_movements`
   rows, and the four valuation/sequence table counts is identical before and
   after `load`; the balance from the seeded 40 kg opening-balance movement is
   exposed via `balanceForProduct`.
7. **Ordering** — products preserve `createdAt ASC, then id ASC` through the
   real adapter (`prd-106s-order-c` at 08:01 before `prd-106s-order-a` /
   `prd-106s-order-b` at 08:02 in id order).
8. **Tripwire (owner)** — `load` succeeds with the throwing legacy
   `ProductRepository` injected and `listProductCalls == 0`.
9. **Tripwire (employee)** — the same, and inactive filtering still applies.

## Architecture guards

- **`InventoryController.load` never calls the legacy product read** — the
  compacted `load` body names `_productCatalogReadRepository.listProductCatalog(`
  with `includeInactive: user.permissions.canCreateStockAdjustment` and contains
  no `listProducts(`, `productRepository`, write call, `.transaction(`,
  `try{`, or `catch(`.
- **`DriftInventoryRepository.allProductBalancesKg` stays on the catalog
  contract** — the compacted `allProductBalancesKg` body calls
  `_productCatalogReadRepository.listProductCatalog(`, with no `listProducts(`,
  `_findProductById`, `currentStockKg(`, or `try{`; `listAllMovements` is also
  legacy-free.
- **Production inventory screens wire the genuine catalog repository** — all
  three screens construct `InventoryController(...)` with
  `productCatalogReadRepository: AppRepositories.productCatalogReadRepository`
  and pass no `productRepository:` argument.
- **No production code changed and no consumer migrated in Phase 106S** —
  `git diff --name-only <106R> -- lib` is empty, and the production
  `.listProductCatalog(` callers set is exactly the eight frozen files
  (including `inventory_controller.dart`).
- **`schemaVersion` stays 15 and persistence is untouched** — no
  `lib/core/persistence` diff; `schemaVersion => 15`.
- **No fallback from the catalog contract to the legacy `listProducts` in the
  load path** — the catalog adapter contains no `listProducts(`,
  `ProductRepository`, or `try{`; the `load` body contains no `catch(`,
  `retry`, `fallback`, or `listProducts(`; the Drift valuation adapter contains
  no `listProducts(` or `ProductRepository`.

## Historical freeze guards

The freeze guards must recognize the new HEAD lineage. Following the exact
pattern established by Phases 106P, 106Q, and 106R:

- `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart`
  now also accepts the single Phase 106R migration commit (parent exactly the
  106Q commit) and the single Phase 106S proof commit (parent exactly the 106R
  commit).
- `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart`
  now also accepts the single Phase 106S proof commit (parent exactly the 106R
  commit) and allows zero to three commits after the 106P baseline.

No historical report, classification, or consumer inventory was rewritten; the
freeze reports remain byte-identical to their phase commits.

## Verification results

| Gate | Result |
| --- | --- |
| Phase 106S focused test | PASS — 15 passed, 0 failed, 0 skipped |
| Phase 106O freeze guard (extended) | PASS |
| Phase 106Q freeze guard (extended) | PASS |
| Phase 106R migration guard | PASS |
| Full `flutter test` | PASS — 2144 passed, 1 historical skip, 0 failed |
| Historical skip | Unchanged credential-dependent skip in `test/phase9a_inflows_outflows_reports_test.dart` |
| `dart format --output=none --set-exit-if-changed .` | PASS — 396 files checked, 2 formatted |
| `flutter analyze` | PASS — `No issues found!` |
| Windows release build | PASS — `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`; only the existing non-fatal Firebase CMake deprecation and `.voltbl` linker warnings |
| EXE size | `784384` bytes |
| EXE SHA-256 | `ECDB76F3C144CF102A5A83AF6AAC4AF851DE7360A63AA6C477573BC3D8910889` |
| Native smoke | NOT RUN — user database isolation is not proven |
| `git diff --check` | PASS — exit 0, no whitespace errors |

## Changed files

Tests:

- `test/phase106s_inventory_controller_product_catalog_runtime_integration_test.dart` (new — 15 tests)
- `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart` (lineage extended for the 106R/106S commits)
- `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart` (lineage extended for the 106S commit)

Documentation:

- `docs/PHASE-106S-PROVE-RUNTIME-INVENTORY-CONTROLLER-PRODUCT-CATALOG-READ-INTEGRATION.md` (new)

Production code: none. No production file, schema, migration, adapter,
contract, controller, UI, report format, financial calculation, valuation
rule, or product ordering was modified.

## Scope exclusions and user-data safety

No consumer was migrated. No contract or read model was expanded. No schema or
migration was added. No UI, controller, write path, report format, financial
calculation, or valuation rule changed. No caching or fallback was added. No
test was disabled, skipped, hidden, or weakened. `ProductCatalogReadRepository`
and `ProductCatalogReadModel` are unchanged; the contract under proof is not
reimplemented by a fake or mock anywhere in the load path.

All runtime verification used SQLite in-memory databases. The production
application and release EXE were not launched. The user database was not
opened, read, copied, modified, deleted, moved, renamed, backed up, or
migrated.

## Confirmation

No Push was performed. No Tag was created. Exactly one commit exists after the
106R baseline, and the final worktree is clean.
