# Phase 106P — Migrate `PurchaseController.load` to the Product Catalog Read Contract

## Executive outcome

**Outcome A — FULL SUCCESS**

Phase 106P migrates the single frozen target from Phase 106O —
`PurchaseController.load` in `lib/core/purchases/purchase_controller.dart` — from
the legacy `ProductRepository.listProducts(...)` read path to the accepted
`ProductCatalogReadRepository.listProductCatalog(...)` boundary. The controller
now reads products exclusively through the catalog read contract, stores them as
`List<ProductCatalogReadModel>`, and preserves the full production behavior of
the purchase workflow. No contract expansion, schema change, migration, legacy
contract deletion, or second-consumer migration happens in this phase.

## Governing references

| Item | Value |
| --- | --- |
| Phase branch | `codex/phase-106p-migrate-purchase-controller-product-catalog-read` |
| Starting HEAD (Phase 106O) | `4b7b1f2b2c32675a5c0f3aa0f96ef1227e7dd7b0` |
| Starting subject | `PHASE 106O: freeze next product read migration target` |
| Final HEAD | The single Phase 106P commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Final subject | `PHASE 106P: migrate purchase controller product catalog read` |
| Commits after baseline | `1` |
| Governing report | `docs/PHASE-106O-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md` |
| Governing guard | `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart` |

## Goal

The only migration target is `PurchaseController.load`, classified **A** by Phase
106O (`A — Read-only, fully compatible with the current contract, independent`).
The consumer needs only `id`, `name`, and `isActive`, all already present in
`ProductCatalogReadModel`, so there is **no contract expansion**. No schema or
migration change, no write-path change, no legacy retirement, and no second
consumer migration are in scope.

## Before migration

The real pre-migration product read path inside `PurchaseController.load` was:

```text
PurchaseController.load
→ _productRepository.listProducts(
    includeInactive: user.permissions.canCreatePurchaseIntake)
→ ProductRepository (legacy product read contract)
→ AppRepositories.productRepository
→ DriftProductRepository (production) / LocalProductRepository (tests)
→ Drift / SQLite products table
```

The controller stored the results as `List<Product>`, exposed a `products`
getter of that type, and used only `id`, `name`, and `isActive` from each
product (in `productName`, the UI filter, and the purchase form dropdown).

## After migration

The real post-migration product read path inside `PurchaseController.load` is:

```text
PurchaseController.load
→ _productCatalogReadRepository.listProductCatalog(
    includeInactive: user.permissions.canCreatePurchaseIntake)
→ ProductCatalogReadRepository (accepted catalog read contract)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository (production composition)
→ Drift
→ SQLite products table
```

The controller now stores and exposes `List<ProductCatalogReadModel>` directly;
no mapper or rebuilt `Product` is introduced. The purchase screens wire the
controller with `AppRepositories.productCatalogReadRepository` and the purchase
form consumes `List<ProductCatalogReadModel>`.

## Preserved behavior

| Concern | Value |
| --- | --- |
| `includeInactive` | `user.permissions.canCreatePurchaseIntake` (owner `true` → active + inactive; employee `false` → active only) — identical to the legacy call |
| Ordering | delegated to the catalog contract (`createdAt ASC, id ASC` via `DriftProductCatalogReadRepository`) |
| Loading state | `_isLoading = true` → load → `_isLoading = false`, `notifyListeners` before and after, unchanged |
| Success handling | intakes, suppliers, products assigned; error message cleared |
| Error handling | repository errors propagate unchanged; `errorMessage` stays cleared; no fallback, retry, or new side effect |
| Empty catalog | `products` stays `[]`; no crash; `isLoading` settles |
| Reload | a later `load` performs a fresh uncached catalog read |
| Selection semantics | unchanged; UI still filters `products` by `isActive` before opening the form |
| Writes | `load` performs no writes; only read operations |
| UI | no visual change; only dependency wiring and the dialog product-list type |
| Schema / migrations | untouched |
| Contract | `ProductCatalogReadModel` unmodified and not expanded |

## Files changed

| File | Reason |
| --- | --- |
| `lib/core/purchases/purchase_controller.dart` | Replaced `ProductRepository` dependency with `ProductCatalogReadRepository`; `load` now calls `listProductCatalog(...)`; `_products`/`products` typed `List<ProductCatalogReadModel>` |
| `lib/features/purchases/purchases_screen.dart` | Wires `PurchaseController` with `AppRepositories.productCatalogReadRepository`; `_PurchaseFormDialog.products` typed `List<ProductCatalogReadModel>` |
| `lib/features/purchases/supplier_purchases_screen.dart` | Wires `PurchaseController` with `AppRepositories.productCatalogReadRepository` |
| `test/phase106p_purchase_controller_product_catalog_read_migration_test.dart` | New phase 106P controller tests and architecture freeze guards |
| `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart` | Extended the historical freeze guard so it recognizes the single Phase 106P migration commit and the catalog wiring of the two screens (required to keep the full suite green after the frozen target is migrated) |
| `test/phase36g_ui_clarity_cancellation_safety_test.dart` | Updated `PurchaseController(` call site to inject the catalog read adapter |
| `test/phase21b_pricing_cost_minimum_ui_acceptance_test.dart` | Updated `PurchaseController(` call site to inject the catalog read adapter |
| `test/supplier_purchase_test.dart` | Updated `PurchaseController(` call site to inject the catalog read adapter |
| `test/paid_purchase_ui_completion_test.dart` | Updated `PurchaseController(` call site to inject the catalog read adapter |

## Tests

### New phase 106P tests — `test/phase106p_purchase_controller_product_catalog_read_migration_test.dart` (10 tests)

- `load reads products through ProductCatalogReadRepository only` — proves the
  single read goes through `listProductCatalog` with exactly one catalog call.
- `includeInactive follows the canCreatePurchaseIntake permission` — owner
  passes `true` (active + inactive), employee passes `false` (active only).
- `load exposes id, name, and isActive from the read model` — the controller
  stores and `productName` resolves the frozen fields.
- `empty catalog list loads without crash and stays empty`.
- `catalog error preserves the current error propagation` — the error propagates
  unchanged, `errorMessage` stays cleared, and no writes occur.
- `load is read-only and never writes`.
- `reload reads the catalog again without cache`.
- Architecture freeze: `PurchaseController.load no longer depends on the legacy
  read contract` (no `ProductRepository`, no `listProducts(`, no writes).
- Architecture freeze: `ProductCatalogReadModel contract is not expanded` (field
  set is exactly the frozen six fields).
- Architecture freeze: `no additional consumer migrated beyond
  PurchaseController.load` (catalog callers set unchanged plus the controller;
  both screens wire the catalog repository).

The consumer tests use `ProductCatalogReadModel` fixtures with `code: null` and
`referenceCostPricePiastersPerKg: null`, proving the consumer relies only on
`id`, `name`, and `isActive`.

### Prior contract and guard tests

| Suite | Result |
| --- | --- |
| Phase 106K — daily activity product read | PASS |
| Phase 106M — inventory balance enumeration read | PASS |
| Phase 106N — runtime daily activity integration | PASS |
| Phase 106O — target discovery freeze (updated for the 106P commit) | PASS |
| Phase 106P — migration + freeze (new) | PASS |

Phase 106P + 106K/106M/106N/106O explicitly: **35 passed, 0 failed, 0 skipped**.

### Full suite

`flutter test` → **2102 passed, 1 skipped (pre-existing historical skip), 0 failed.**

## Analysis and build

| Gate | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | PASS — 0 files changed |
| `flutter analyze` | PASS — `No issues found!` |
| Windows Release build | PASS — `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| EXE size | `784384` bytes |
| EXE SHA-256 | `D184FFB0C8F499C2770EB7BF9A1E9D3A9302C90C903E1C23C5B24074955769C9` |

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
- No database schema change and no migration added.
- No legacy contract deleted; no cleanup; no renames.
- No other consumer migrated.
- No UI, navigation, write-path, or purchase-model change.
- No runtime integration proof for a full interface (Phase 106N scope); the 106P
  proof is a focused controller test plus a source/freeze guard.

## Final outcome

**Outcome A — FULL SUCCESS**

`PurchaseController.load` now reads the product catalog exclusively through
`ProductCatalogReadRepository`, with preserved behavior and no contract
expansion. One commit exists after the Phase 106O baseline; no Push and no Tag
are performed.
