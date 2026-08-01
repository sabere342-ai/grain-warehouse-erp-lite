# Phase 106U — Expand the Product Catalog Read Contract and Migrate `SaleController.load`

## 22.1 Executive summary

**Outcome A — FULL SUCCESS**

Phase 106U implements the single frozen target from Phase 106T — `SaleController.load`
in `lib/core/sales/sale_controller.dart` (row `PRC-112`, classified **C** — Requires
a Broader Read Contract). It performs the **contract expansion** frozen by Phase 106T
by adding `defaultSalePricePiastersPerKg` and `minimumSalePricePiastersPerKg`
(both `int?`, nullable, piasters per kg) to `ProductCatalogReadModel`, then migrates
`SaleController.load` from the legacy `ProductRepository.listProducts(includeInactive: false)`
path to `ProductCatalogReadRepository.listProductCatalog(includeInactive: false)`.

The sales screen wires the controller with `AppRepositories.productCatalogReadRepository`
and consumes `ProductCatalogReadModel` directly. No schema change, no migration, no
`schemaVersion` bump, no fallback to the legacy `listProducts`, and no second-consumer
migration happens in this phase. One commit exists after the Phase 106T baseline;
no Push and no Tag are performed.

## 22.2 Baseline verification

| Item | Value |
| --- | --- |
| Phase branch | `codex/phase-106u-expand-product-catalog-read-and-migrate-sale-controller` |
| Starting HEAD (Phase 106T) | `ff60b6ad9d759bedac72948dc6544b15bdbc925c` |
| Starting subject | `PHASE 106T: freeze next product read migration target` |
| Final HEAD | The single Phase 106U commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Final subject | `PHASE 106U: expand product catalog read and migrate sale controller` |
| Commits after baseline | `1` |
| Governing report | `docs/PHASE-106T-RE-AUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md` |
| Governing guard | `test/phase106t_next_product_read_migration_target_freeze_test.dart` |

The branch was created from `ff60b6a` (the single Phase 106T freeze commit) and
verified with `git rev-parse`. The Phase 106T report already audited the full
consumer inventory; Phase 106U does not re-run the discovery search.

## 22.3 Scope

The only migration target is `SaleController.load`, classified **C** by Phase 106T
(`C — Requires a Broader Read Contract`, row `PRC-112`). The consumer needs `id`,
`name`, and the two sale price fields from each catalog item, so the contract is
expanded exactly by those two fields. No other consumer migrates in this phase:
`ProductController.loadProducts` stays on the legacy `listProducts` path.

The five permitted production files under `lib/` are:

| File | Role |
| --- | --- |
| `lib/core/catalog/product_catalog_read_repository.dart` | `ProductCatalogReadModel` gains the two frozen sale-price fields |
| `lib/core/catalog/drift_product_catalog_read_repository.dart` | Selects and maps the two columns (no conversion, no fallback) |
| `lib/app/app_repositories.dart` | Legacy adapter forwards the two fields from `Product` so every call site keeps compiling |
| `lib/core/sales/sale_controller.dart` | `load` migrates to `listProductCatalog(includeInactive: false)` |
| `lib/features/sales/sales_screen.dart` | Wires the controller with `AppRepositories.productCatalogReadRepository`; consumes the read model |

## 22.4 Reconciliation

| Total identified consumers | 24 |
| --- | --- |
| Migrated | 9 |
| Remaining | 15 |
| `24 = 9 + 15` — exact match | |

| Category | Remaining |
| --- | --- |
| C — Requires a Broader Read Contract | 1 |
| F — Write-Coupled / Transaction-Integrity Read | 8 |
| G — Financial / Inventory / Accounting Criticality | 1 |
| H — Not Production-Reachable | 3 |
| I — False Positive (Infrastructure) | 2 |
| Sum of categories | 15 |
| Remaining inventory | 15 |
| Migrated and accepted | 9 |
| Total identified | 24 |

`SaleController.load` (PRC-112) was the single **C — selected (expansion)** row in
the Phase 106T report; it leaves the remaining inventory in Phase 106U. The working
tree is re-checked by the 106U guard: exactly 13 legacy consumer files still call
`.listProducts(` and exactly 9 migrated consumer files call `.listProductCatalog(`.

## 22.5 Contract expansion (Phase 106U)

The frozen expansion is limited to two new read-model fields:

```text
ProductCatalogReadModel.defaultSalePricePiastersPerKg  — int?, nullable, piasters per kg
ProductCatalogReadModel.minimumSalePricePiastersPerKg  — int?, nullable, piasters per kg
products.defaultSalePricePiastersPerKg  (column exists)
products.minimumSalePricePiastersPerKg  (column exists)
```

- A null value is preserved as null; no default, no rounding, no derivation.
- The prior six fields (`id`, `name`, `code`, `unit`, `isActive`,
  `referenceCostPricePiastersPerKg`) are unchanged.
- `includeInactive = false` is fixed for `SaleController.load` (active products only).
- Ordering stays `createdAt ASC, id ASC` via the existing catalog adapter.
- No schema change, no migration, no `schemaVersion` bump (stays `15`).
- `ProductCatalogReadRepository` still exposes only `listProductCatalog(...)`.

## 22.6 Migration (SaleController.load)

The real pre-migration product read path was:

```text
SaleController.load
→ _productRepository.listProducts(includeInactive: false)
→ ProductRepository (legacy product read contract)
→ AppRepositories.productRepository
→ DriftProductRepository (production) / LocalProductRepository (tests)
→ Drift / SQLite products table
```

The real post-migration product read path is:

```text
SaleController.load
→ _productCatalogReadRepository.listProductCatalog(includeInactive: false)
→ ProductCatalogReadRepository (accepted catalog read contract)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository (production composition)
→ Drift
→ SQLite products table
```

The controller now stores and exposes `List<ProductCatalogReadModel>` directly; no
mapper or rebuilt `Product` is introduced. The sales screen wires the controller
with `AppRepositories.productCatalogReadRepository` and uses the read model locally.

## 22.7 Preserved behavior

| Concern | Value |
| --- | --- |
| `includeInactive` | `false` (fixed, active products only) — identical to the legacy call |
| Ordering | delegated to the catalog contract (`createdAt ASC, id ASC` via `DriftProductCatalogReadRepository`) |
| Loading state | `_isLoading = true` → load → `_isLoading = false`, `notifyListeners` before and after, unchanged |
| Sales / customers / accounts / balances | still read from their own repositories, unchanged |
| Success handling | sales, products, stock balances, customers, financial accounts assigned; error message cleared |
| Error handling | catalog repository errors propagate unchanged; `errorMessage` stays cleared; no fallback, retry, or new side effect |
| Empty catalog | `products` stays `[]`; no crash; `isLoading` settles |
| Reload | a later `load` performs a fresh uncached catalog read |
| Read-only integrity | `load` performs no writes; only read operations |
| Price fields | the two new fields are exposed only if present; a null stays null; no minimum-price enforcement is added to `load` |
| UI | no visual change; only dependency wiring and the product-list row types |
| Schema / migrations | untouched (`schemaVersion` stays `15`) |

## 22.8 Production composition

`AppRepositories.productCatalogReadRepository` is the production `DriftProductCatalogReadRepository`,
backed by the real SQLite `products` table. Phase 106U runtime proofs seed real
integer values into `default_sale_price_piasters_per_kg` and
`minimum_sale_price_piasters_per_kg` and assert the catalog read model returns them,
including null preservation. The legacy `AppRepositories.productRepository` remains
the write/`Product` path used by every unmigrated consumer.

## 22.9 Files changed

### Production (`lib/`, exactly the five permitted files)

| File | Reason |
| --- | --- |
| `lib/core/catalog/product_catalog_read_repository.dart` | `ProductCatalogReadModel` gains `defaultSalePricePiastersPerKg` and `minimumSalePricePiastersPerKg` (`final int?`, required constructor params) |
| `lib/core/catalog/drift_product_catalog_read_repository.dart` | `addColumns` selects both columns; each row maps them via `row.read(...)` with no conversion |
| `lib/app/app_repositories.dart` | `_LegacyProductCatalogReadRepository` forwards both fields from `Product` so every adapter call site keeps compiling |
| `lib/core/sales/sale_controller.dart` | Dependency is now `ProductCatalogReadRepository`; `load` calls `listProductCatalog(includeInactive: false)`; `products` is `List<ProductCatalogReadModel>` |
| `lib/features/sales/sales_screen.dart` | Wires `SaleController` with `AppRepositories.productCatalogReadRepository`; 5 `Product` type references replaced with `ProductCatalogReadModel` |

### New phase 106U tests

| File | Reason |
| --- | --- |
| `test/phase106u_product_catalog_read_contract_expansion_test.dart` | Model 8-field construction, real Drift adapter mapping of the two price columns (values + nulls), ordering, filtering, read-only, production composition |
| `test/phase106u_sale_controller_product_catalog_read_migration_test.dart` | `SaleController.load` functional migration proofs plus a load-body source guard |
| `test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart` | Lineage, scope, reconciliation, architecture freeze, and report-section guard |

### Updated prior tests

| File | Reason |
| --- | --- |
| `test/sales_test.dart`, `test/phase11_ux_test.dart`, `test/phase21b_pricing_cost_minimum_ui_acceptance_test.dart`, `test/phase32_pilot_acceptance_test.dart`, `test/phase35_customer_credit_ui_pilot_qa_test.dart`, `test/phase39_customer_bound_multi_item_sales_test.dart`, `test/phase59_sale_cancellation_customer_ledger_symmetry_test.dart`, `test/phase72_transaction_integration_test.dart`, `test/dc_u002_split_payments_test.dart`, `test/dc_u002_split_payments_ui_test.dart` | `SaleController(` call sites inject `ProductCatalogReadRepository` (via `ProductCatalogReadRepositoryTestAdapter` where a `ProductRepository` remains) |
| `test/support/product_catalog_read_repository_test_adapter.dart` | Forwards the two new fields from `Product` |
| `test/phase105b_product_catalog_read_contract_test.dart`, `test/phase105d_product_catalog_application_read_boundary_migration_test.dart`, `test/phase105f_product_catalog_read_boundary_pilot_acceptance_freeze_test.dart`, `test/phase106e_inventory_attention_product_catalog_read_migration_test.dart`, `test/phase106g_genuine_runtime_dashboard_service_product_catalog_read_integration_test.dart`, `test/phase106h_dashboard_service_product_catalog_read_migration_acceptance_freeze_test.dart`, `test/phase106j_product_catalog_read_model_reference_cost_test.dart`, `test/phase106k_local_report_repository_daily_activity_product_read_migration_test.dart`, `test/inventory_attention_service_test.dart` | `ProductCatalogReadModel(...)` construction sites gain the two required fields |
| `test/phase106m_drift_inventory_product_balance_enumeration_read_contract_migration_test.dart`, `test/phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart`, `test/phase106c_genuine_runtime_dashboard_guidance_product_catalog_read_integration_test.dart` | Sentinel string writes into the two integer columns replaced with real integer seeding (106M/106N) or a column the catalog adapter does not read (106C); assertions now verify catalog values |
| `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart`, `test/phase106p_purchase_controller_product_catalog_read_migration_test.dart`, `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart`, `test/phase106r_inventory_controller_product_catalog_read_migration_guard_test.dart`, `test/phase106s_inventory_controller_product_catalog_runtime_integration_test.dart`, `test/phase106t_next_product_read_migration_target_freeze_test.dart` | Historical guards extended for the single Phase 106U commit: lineage, commit-relative contract reads, `sale_controller.dart` added to catalog callers, 106T expects the eight-field model |

## 22.10 Tests

### New phase 106U tests

`test/phase106u_product_catalog_read_contract_expansion_test.dart` (10 tests):

- Model construction with the two new fields (values and nulls preserved).
- Real Drift adapter maps `default_sale_price_piasters_per_kg` and
  `minimum_sale_price_piasters_per_kg` from SQLite rows, preserves nulls,
  orders `createdAt ASC, id ASC`, filters `includeInactive`, returns an empty
  immutable list on an empty table, and is read-only.
- Production composition reaches `DriftProductCatalogReadRepository` and maps both
  columns.
- Adapter source guard: both columns selected, no `listProducts(`, no `catch`,
  no `retry`.

`test/phase106u_sale_controller_product_catalog_read_migration_test.dart` (8 tests):

- `load` reads products through `ProductCatalogReadRepository` only.
- `includeInactive` is fixed to `false` and filters inactive products.
- `load` exposes `id`, `name`, and both sale prices from the read model.
- Empty catalog, catalog error propagation, read-only load, and reload-without-cache.
- Load-body source guard: no `ProductRepository`, no `listProducts(`, no writes.

`test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart`
(10 tests):

- Lineage (HEAD is the 106T commit or the single 106U commit).
- Production scope limited to the five permitted files; working-tree subset;
  `git diff --check`.
- Reconciliation `24 = 9 + 15` against the report and the working tree.
- All nine migrated consumers remain on the catalog boundary.
- `SaleController.load` migrated without legacy bypass; screen and
  `app_repositories.dart` wiring.
- Model field set is exactly the eight frozen fields.
- No additional consumer migrated; `schemaVersion` stays `15`; no persistence diff.
- History preserved (106O–106T reports and guards).
- Report contains every required 22.x section.

### Prior suites

| Suite | Result |
| --- | --- |
| Phase 106C — runtime dashboard guidance catalog integration | PASS |
| Phase 106K — daily activity product read | PASS |
| Phase 106M — inventory balance enumeration read | PASS |
| Phase 106N — runtime daily activity integration | PASS |
| Phase 106O — target discovery freeze | PASS |
| Phase 106P — purchase controller migration guard | PASS |
| Phase 106Q — target discovery freeze | PASS |
| Phase 106R — inventory controller migration guard | PASS |
| Phase 106S — runtime inventory controller integration | PASS |
| Phase 106T — target freeze guard | PASS |
| Phase 106U — migration + expansion + freeze (new) | PASS |

Focused runs: the core migration/guard set and the ten historical phase 106
guards all pass independently before the full run.

### Full suite

`flutter test` → **2183 passed, 1 skipped (pre-existing historical skip), 0 failed**
(one pre-existing timing-sensitive auth test flaked in a parallel full run and
passes in isolation; it is unrelated to Phase 106U).

## 22.11 Analysis and build

| Gate | Result |
| --- | --- |
| `dart format --set-exit-if-changed .` | PASS |
| `flutter analyze` | PASS — `No issues found!` |
| `git diff --check` | PASS |
| Windows Release build | PASS — `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| EXE size | `784384` bytes |
| EXE SHA-256 | `2FBD0CDE5DC672BEA9699C1A2ED4314A35FADF39E3BFFE8936D2144EFAC0B8CA` |

## 22.12 Guard regression protection

- The 106T guard now expects the eight-field model, the 9/15 reconciliation, the
  13 legacy consumer files (with `sale_controller.dart` removed), and the 9
  migrated consumer files (with `sale_controller.dart` added); its lineage test
  recognizes the single Phase 106U commit as the child of the 106T commit.
- The 106O/106P/106Q/106R/106S guards recognize the Phase 106U commit and keep
  their historical contract-freeze reads pinned to their own baseline commits, so
  the expansion does not break them.
- The new 106U guard freezes the five-file production scope, the eight-field
  model, the fixed `includeInactive: false` call, and the 24/9/15 reconciliation.
- The 106M/106N composition tests now seed real integer prices and assert the
  Drift adapter returns them, replacing non-type-safe string sentinel writes.

## 22.13 Git evidence

| Item | Value |
| --- | --- |
| `git diff --check` | PASS |
| Working tree | Clean after commit |
| Commits after baseline | `1` |
| Push | NO |
| Tag | NO |

`git diff --name-only <phase106t-baseline> -- lib` reports exactly the five
permitted production files. No Push was performed. No Tag was created.

## 22.14 Non-goals

- No schema change, no database migration, and no `schemaVersion` bump (stays `15`).
- No legacy contract deleted; no cleanup; no renames.
- No other consumer migrated (`ProductController.loadProducts` stays legacy).
- No fallback to the legacy `listProducts` anywhere; no retry, no conversion, no
  rounding, and no derived `Product` rebuild.
- No new minimum-price enforcement in `load`; the two new fields are only exposed.
- No UI, navigation, or write-path change; only dependency wiring and the product
  row types in the sales screen.
- The user database was not opened, read, copied, or modified.

## Final outcome

**Outcome A — FULL SUCCESS**

`SaleController.load` now reads the product catalog exclusively through
`ProductCatalogReadRepository.listProductCatalog(includeInactive: false)`, backed
by the two-field `ProductCatalogReadModel` expansion frozen in Phase 106T, with
preserved behavior and no contract growth beyond the two frozen price fields. One
commit exists after the Phase 106T baseline; no Push and no Tag are performed.
