# Phase 106R — Migrate `InventoryController.load` to the Product Catalog Read Contract

## Executive outcome

**Outcome A — FULL SUCCESS**

Phase 106R migrates the single frozen target from Phase 106Q —
`InventoryController.load` in `lib/core/inventory/inventory_controller.dart` —
from the legacy `ProductRepository.listProducts(...)` read path to the accepted
`ProductCatalogReadRepository.listProductCatalog(...)` boundary. The controller
now reads products exclusively through the catalog read contract, stores them as
`List<ProductCatalogReadModel>`, and preserves the full production behavior of
the inventory workflow (opening balances, manual adjustments, stock take, stock
balance enumeration). No contract expansion, schema change, migration, legacy
contract deletion, or second-consumer migration happens in this phase.

## Governing references

| Item | Value |
| --- | --- |
| Phase branch | `codex/phase-106r-migrate-inventory-controller-product-catalog-read` |
| Starting HEAD (Phase 106Q) | `f0341e9e070012953bce487c20401bf36eec1b87` |
| Starting subject | `PHASE 106Q: freeze next product read migration target` |
| Final HEAD | The single Phase 106R commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Final subject | `PHASE 106R: migrate inventory controller product catalog read` |
| Commits after baseline | `1` |
| Governing report | `docs/PHASE-106Q-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md` |
| Governing guard | `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart` |

## Goal

The only migration target is `InventoryController.load`, classified **B** by Phase
106Q (`B — Current-contract fit (broader context)`, row `PRC-107`). The consumer
needs only `id` and `name` from each catalog item, both already present in
`ProductCatalogReadModel`, so there is **no contract expansion**. No schema or
migration change, no write-path change, no legacy retirement, and no second
consumer migration are in scope.

## Before migration

The real pre-migration product read path inside `InventoryController.load` was:

```text
InventoryController.load
→ _productRepository.listProducts(
    includeInactive: user.permissions.canCreateStockAdjustment)
→ ProductRepository (legacy product read contract)
→ AppRepositories.productRepository
→ DriftProductRepository (production) / LocalProductRepository (tests)
→ Drift / SQLite products table
```

The controller stored the results as `List<Product>` and exposed a `products`
getter of that type; the three inventory screens (`InventoryScreen`,
`StockTakeScreen`, `StockAdjustmentReportScreen`) consumed `Product` objects
using only `id` and `name`.

## After migration

The real post-migration product read path inside `InventoryController.load` is:

```text
InventoryController.load
→ _productCatalogReadRepository.listProductCatalog(
    includeInactive: user.permissions.canCreateStockAdjustment)
→ ProductCatalogReadRepository (accepted catalog read contract)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository (production composition)
→ Drift
→ SQLite products table
```

The controller now stores and exposes `List<ProductCatalogReadModel>` directly;
no mapper or rebuilt `Product` is introduced. The three inventory screens wire
the controller with `AppRepositories.productCatalogReadRepository` and consume
`ProductCatalogReadModel` locally; `LocalInventoryRepository` continues to
receive `AppRepositories.productRepository` unchanged.

## Preserved behavior

| Concern | Value |
| --- | --- |
| `includeInactive` | `user.permissions.canCreateStockAdjustment` (owner `true` → active + inactive; employee `false` → active only) — identical to the legacy call |
| Ordering | delegated to the catalog contract (`createdAt ASC, id ASC` via `DriftProductCatalogReadRepository`) |
| Loading state | `_isLoading = true` → load → `_isLoading = false`, `notifyListeners` before and after, unchanged |
| Balance enumeration | `allProductBalancesKg(activeProductsOnly: !user.permissions.canCreateStockAdjustment)` unchanged; still read from the inventory repository |
| Success handling | products, movements, balances, opening-balance set, profitability activation assigned; error message cleared |
| Error handling | catalog repository errors propagate unchanged; `errorMessage` stays cleared; no fallback, retry, or new side effect |
| Empty catalog | `products` stays `[]`; no crash; `isLoading` settles |
| Reload | a later `load` performs a fresh uncached catalog read |
| Read-only integrity | `load` performs no writes; only read operations |
| UI | no visual change; only dependency wiring and the product-list row types |
| Schema / migrations | untouched (`schemaVersion` stays `15`) |
| Contract | `ProductCatalogReadModel` unmodified and not expanded |

## Files changed

| File | Reason |
| --- | --- |
| `lib/core/inventory/inventory_controller.dart` | Replaced `ProductRepository` dependency with `ProductCatalogReadRepository`; `load` now calls `listProductCatalog(...)`; `_products`/`products` typed `List<ProductCatalogReadModel>` |
| `lib/features/inventory/inventory_screen.dart` | Wires `InventoryController` with `AppRepositories.productCatalogReadRepository`; product rows typed `ProductCatalogReadModel` |
| `lib/features/inventory/stock_take_screen.dart` | Wires `InventoryController` with `AppRepositories.productCatalogReadRepository`; product rows and adjustments typed `ProductCatalogReadModel` |
| `lib/features/inventory/stock_adjustment_report_screen.dart` | Wires `InventoryController` with `AppRepositories.productCatalogReadRepository` |
| `test/phase106r_inventory_controller_product_catalog_read_migration_guard_test.dart` | New phase 106R controller tests and architecture freeze guards |
| `test/inventory_test.dart` | Updated `InventoryController(` call sites to inject `ProductCatalogReadRepositoryTestAdapter` |
| `test/phase49a_stock_take_test.dart` | Updated `InventoryController(` call sites to inject the catalog read adapter |
| `test/phase49b_stock_adjustment_report_test.dart` | Updated `InventoryController(` call sites to inject the catalog read adapter |
| `test/phase51_real_business_day_simulation_test.dart` | Updated `InventoryController(` call sites to inject the catalog read adapter |
| `test/phase52_accounting_freeze_audit_test.dart` | Updated `InventoryController(` call sites to inject the catalog read adapter |
| `test/phase53_cloud_migration_readiness_test.dart` | Updated `InventoryController(` call sites to inject the catalog read adapter |
| `test/phase102b_transaction_integration_test.dart` | Updated `InventoryController(` call sites to inject the catalog read adapter |
| `test/phase102c_activation_readiness_verification_test.dart` | Updated `InventoryController(` call sites to inject the catalog read adapter |
| `test/phase106p_purchase_controller_product_catalog_read_migration_test.dart` | Extended `_catalogCallers` with `inventory_controller.dart` so the 106P guard stays green after the 106R target becomes a legitimate catalog consumer |
| `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart` | Extended the historical freeze guard so it recognizes the single Phase 106R migration commit and the catalog wiring of the three screens (required to keep the full suite green after the frozen target is migrated) |

## Tests

### New phase 106R tests — `test/phase106r_inventory_controller_product_catalog_read_migration_guard_test.dart` (14 tests)

Functional migration proofs (7):

- `load reads products through ProductCatalogReadRepository only` — the single
  catalog read plus the two inventory reads happen; products come from the read
  model.
- `includeInactive follows the canCreateStockAdjustment permission` — owner
  passes `true` (active + inactive), employee passes `false` (active only).
- `load exposes id and name from the read model` — the controller stores the
  frozen fields and balances resolve from movements.
- `empty catalog list loads without crash and stays empty`.
- `catalog error preserves the current error propagation` — the error propagates
  unchanged, `errorMessage` stays cleared, and no writes occur.
- `load is read-only and never writes`.
- `reload reads the catalog again without cache`.

Architecture freeze guards (7):

- `InventoryController.load no longer depends on the legacy read contract` (no
  `ProductRepository`, no `listProducts(`, no writes in `load`).
- `migrated controller carries no TODO, placeholder, or shim`.
- `ProductCatalogReadModel contract is not expanded` (field set is exactly the
  frozen six fields).
- `ProductCatalogReadRepository contract is not expanded` (only
  `listProductCatalog`, no write operations).
- `no additional consumer migrated beyond InventoryController.load` (catalog
  callers set unchanged plus the controller; all three screens wire the catalog
  repository and no screen still passes `productRepository:` to the controller).
- `production scope is limited to the migration files` (the working-tree `lib/`
  diff is exactly the controller plus the three inventory screens).
- `no schema or persistence migration changes` (no `lib/core/persistence` diff;
  `schemaVersion` stays `15`).

The consumer tests use `ProductCatalogReadModel` fixtures with `code: null` and
`referenceCostPricePiastersPerKg: null`, proving the consumer relies only on
`id` and `name`.

### Prior contract and guard tests

| Suite | Result |
| --- | --- |
| Phase 106K — daily activity product read | PASS |
| Phase 106M — inventory balance enumeration read | PASS |
| Phase 106N — runtime daily activity integration | PASS |
| Phase 106O — target discovery freeze | PASS |
| Phase 106P — purchase controller migration guard (updated for the 106R caller) | PASS |
| Phase 106Q — target discovery freeze (updated for the 106R commit) | PASS |
| Phase 106R — migration + freeze (new) | PASS |

Focused run (106R guard + 106Q guard + 106P guard + `inventory_test` +
`phase49a` + `phase49b`): **106 passed, 0 failed, 0 skipped**.

### Full suite

`flutter test` → **2129 passed, 1 skipped (pre-existing historical skip), 0 failed.**

## Analysis and build

| Gate | Result |
| --- | --- |
| `dart format` on modified files | PASS |
| `flutter analyze` | PASS — `No issues found!` |
| Windows Release build | PASS — `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| EXE size | `784384` bytes |
| EXE SHA-256 | `BEAB4596772DFA28E275BC78EB385AD78F5F6186D43E8F29A74C5479D7980851` |

## Git hygiene

| Item | Value |
| --- | --- |
| `git diff --check` | PASS |
| Working tree | Clean after commit |
| Commits after baseline | `1` |
| Push | NO |
| Tag | NO |

## Non-goals

- No contract expansion; `ProductCatalogReadModel` and the read contract are untouched.
- No database schema change and no migration added; `schemaVersion` remains `15`.
- No legacy contract deleted; no cleanup; no renames.
- No other consumer migrated (`PurchaseController`, `DashboardService`,
  `DashboardGuidanceState`, `InventoryAttentionService`, `LocalReportRepository`
  stay untouched in this phase).
- No UI, navigation, or write-path change; only dependency wiring and the
  product-list row types in the three inventory screens.
- No runtime integration proof for a full interface (Phase 106N scope); the 106R
  proof is a focused controller test plus a source/freeze guard.
- The user database was not opened, read, copied, or modified.

## Final outcome

**Outcome A — FULL SUCCESS**

`InventoryController.load` now reads the product catalog exclusively through
`ProductCatalogReadRepository`, with preserved behavior and no contract
expansion. One commit exists after the Phase 106Q baseline; no Push and no Tag
are performed.
