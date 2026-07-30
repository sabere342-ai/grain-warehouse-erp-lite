# Phase 106M — Migrate DriftInventoryRepository Product Balance Enumeration Read Contract

## Outcome

**Outcome A — FULL SUCCESS**

`DriftInventoryRepository.allProductBalancesKg()` now enumerates products
through the frozen `ProductCatalogReadRepository` boundary. The method no
longer invokes legacy `ProductRepository.listProducts()` either directly or
through `currentStockKg()`. All other inventory validation and write paths
retain their existing `ProductRepository` dependency and behavior.

## Phase data

| Item | Value |
| --- | --- |
| Branch | `codex/phase-106m-migrate-drift-inventory-product-balance-enumeration-read-contract` |
| Baseline | `a008729f9b9421a487065e58a6922f1726130c9e` (`PHASE 106K: migrate daily activity product read`) |
| Initial worktree | Clean; zero commits after baseline |
| Final HEAD | The single Phase 106M commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 106M: migrate inventory product balance enumeration read` |
| Commits after baseline | Exactly `1` required and verified after commit |
| Final worktree | Clean required and verified after commit |
| Push / Tag | Not performed / not created |

## Reason and Phase 106L relationship

Phase 106L proved that the genuine daily-report runtime still reached the
legacy product repository through inventory balance enumeration:

```text
LocalReportRepository.dailyActivityReport
→ DriftInventoryRepository.allProductBalancesKg
→ DriftProductRepository.listProducts
```

That prevented Phase 106L from proving removal of the legacy read path. Phase
106M removes precisely that blocker without re-running or reopening Phase
106L and without migrating another consumer.

## Migrated path

Previous enumeration:

```text
DriftInventoryRepository.allProductBalancesKg
→ ProductRepository.listProducts(includeInactive: !activeProductsOnly)
→ currentStockKg(product.id)
→ ProductRepository.listProducts(includeInactive: true)
→ Drift inventory movements
```

New enumeration:

```text
DriftInventoryRepository.allProductBalancesKg
→ ProductCatalogReadRepository.listProductCatalog(
    includeInactive: !activeProductsOnly,
  )
→ listMovementsByProduct(product.id)
→ existing StockMovement.signedQuantityKg fold
```

There is no dual read, fallback, retry, cache, feature flag, direct products
table query, or error swallowing in the migrated method.

## Contract suitability and required fields

The balance-enumeration path requires exactly `ProductCatalogReadModel.id`.
It does not consume product names, codes, units, prices, notes, timestamps, or
write capabilities. The existing frozen contract therefore covers the path
without extension, conversion, or semantic loss.

Both the old `DriftProductRepository.listProducts()` query and the frozen
catalog adapter order products by `createdAt ASC, id ASC`. The insertion order
of the returned immutable Dart map is consequently preserved.

## Preserved inventory semantics

- The default call includes active and inactive products through
  `includeInactive: true` (`!activeProductsOnly` when the argument is false).
- `activeProductsOnly: true` retains the prior active-only behavior.
- A catalog product with no movement remains present with a `0` kg balance.
- Product ids remain exact `String` keys; there is no parsing, trimming,
  regeneration, or numeric conversion.
- Each product balance uses the existing integer
  `StockMovement.signedQuantityKg` fold. Positive, negative, zero, and voided
  movement semantics are unchanged.
- Results remain `Map<String, int>.unmodifiable`.
- An empty catalog returns an empty immutable map with no synthetic rows.
- Every invocation re-reads the catalog and movements; a later movement is
  visible immediately.
- The method performs no product, movement, sequence, ledger, or other write.

`referenceCostPricePiastersPerKg` is deliberately unused. Runtime coverage
uses both exact `12345` and `null` values and proves that neither value affects
the integer-kilogram balance. There is no division or multiplication by 100,
no `double` conversion, no rounding, and no `null`-to-zero substitution.

## Remaining ProductRepository uses

`DriftInventoryRepository` intentionally retains its required
`ProductRepository` dependency for `_findProductById()`. That helper supports:

- `currentStockKg()` missing-product validation;
- `hasOpeningBalance()` missing-product validation;
- `createMovement()` draft validation, inactive-product safety, opening
  balance uniqueness, and negative-stock protection.

These lookup and transaction-safety paths are outside Phase 106M and were not
migrated. Their behavior and legacy dependency remain unchanged.

## Production composition

`AppRepositories.initializeProduction()` creates one
`DriftProductCatalogReadRepository(database)` and passes the exposed
`AppRepositories.productCatalogReadRepository` instance into
`DriftInventoryRepository` alongside the existing product repository. Both
adapters use the same `FoundationDatabase` instance. The inventory repository
does not instantiate an adapter and does not depend on `AppRepositories`.

The governing production-composition runtime test stores a product whose
legacy-only integer column contains a text sentinel. The real catalog adapter
can project that row, and the genuine `AppRepositories.inventoryRepository`
returns its zero balance successfully. Any legacy full-row product read would
raise a `FormatException`, so success is executable evidence that production
balance enumeration no longer calls the legacy repository.

## Runtime evidence

The governing test uses genuine in-memory SQLite, Drift,
`DriftProductCatalogReadRepository`, and `DriftInventoryRepository`. A
throwing `ProductRepository` remains injected for the non-migrated methods;
its `listProducts()` call count stays zero while balance enumeration succeeds.

The six phase tests cover:

1. multiple textual product ids, active and inactive products, multiple and
   voided movements, positive and zero balances, no-movement zero balance,
   exact ordering, immutable results, and before/after database snapshots;
2. the existing optional active-only filter;
3. a second uncached read after a new ledger movement;
4. an empty SQLite catalog;
5. genuine `AppRepositories` production composition with a legacy sentinel;
6. a secondary source guard proving the new dependency is confined to
   `allProductBalancesKg()` while legacy validation remains elsewhere.

## Verification results

| Gate | Result |
| --- | --- |
| Phase 106M focused test | PASS — 6 passed, 0 failed, 0 skipped |
| Related regression | PASS — 102 passed, 0 failed, 0 skipped across 11 inventory, catalog, composition, report, and Phase 106K files |
| Phase 106I historical freeze regression | PASS — 8 passed, 0 failed, 0 skipped |
| Full `flutter test` | PASS — 2078 passed, 0 failed, 1 historical skip; 173.8 s wall time |
| Historical skip | Unchanged credential-dependent skip in `test/phase9a_inflows_outflows_reports_test.dart` |
| Formatter | PASS — 390 Dart files checked, 0 changed; 8.74 s |
| Analyzer | PASS — `No issues found`; 34.2 s analyzer time |
| Windows release | PASS — 78.5 s Flutter build time, 80.7 s wall time |
| EXE path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| EXE size | `784384` bytes |
| SHA-256 | `5247594E523FE54002749D99A13AAC7AEE869456468D2AB67463C51234BE8E23` |
| Native smoke | NOT RUN — user database isolation is not proven |
| `git diff --check` | PASS — exit 0, no whitespace errors |

The first sandboxed Windows build stalled without a live Flutter, Dart, CMake,
MSBuild, compiler, or linker process and did not refresh the EXE. It was
terminated, and the identical build completed successfully outside that
sandbox restriction. The successful build emitted only the existing
non-fatal Firebase CMake minimum-version deprecation warning and `.voltbl`
linker warning.

## Historical freeze test stabilization

The Phase 106I discovery test described an immutable Phase 106I architecture
but obtained its consumer inventory from `HEAD`. The migration would therefore
make the historical assertion depend on later repository state. The test now
runs both catalog and legacy inventories against the governing Phase 106I
commit, matching the remainder of that file's historical assertions. No
classification, report content, or production behavior was changed.

## Changed files

Production:

- `lib/core/inventory/drift_inventory_repository.dart`
- `lib/app/app_repositories.dart`

Direct constructor wiring:

- `test/phase8e_durable_inventory_repository_test.dart`
- `test/phase8f_durable_purchase_repository_test.dart`
- `test/phase8g_durable_sale_repository_test.dart`
- `tool/run_phase102j_synthetic_trial.dart`

Phase evidence and historical test stability:

- `test/phase106m_drift_inventory_product_balance_enumeration_read_contract_migration_test.dart`
- `test/phase106i_next_product_read_contract_expansion_discovery_freeze_test.dart`
- `docs/PHASE-106M-MIGRATE-DRIFT-INVENTORY-PRODUCT-BALANCE-ENUMERATION-READ-CONTRACT.md`

## Scope exclusions and user-data safety

No other `DriftInventoryRepository` method, local inventory repository,
catalog contract, catalog read model, catalog adapter, report repository,
schema, migration, generated file, UI, ledger rule, transaction rule,
dependency, or product-read consumer was migrated. No cache, retry, fallback,
dual read, unit conversion, valuation logic, or reference-cost calculation was
added.

All runtime verification used SQLite in-memory databases. The production
application and release EXE were not launched. The user database was not
opened, read, copied, modified, deleted, moved, renamed, backed up, or
migrated.

## Next phase proposed only

**Phase 106N — Prove Genuine Runtime Local Report Daily Activity Product Read
Integration**

Phase 106N was not implemented.
