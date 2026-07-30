# Phase 106G — Migrate DashboardService.load to ProductCatalogReadRepository

## Outcome

**Outcome A — FULL SUCCESS**

Phase 106G migrates only the direct product read owned by
`DashboardService.load` from the broad read/write `ProductRepository` to the
frozen `ProductCatalogReadRepository`. All Phase 106F behavior remains intact.

## Git baseline

| Item | Value |
| --- | --- |
| Previous branch | `codex/phase-106f-discover-freeze-next-product-read-consumer-target` |
| Phase branch | `codex/phase-106g-migrate-dashboard-service-to-product-catalog-read-contract` |
| Starting baseline / HEAD | `ad56678ff58334d46b76dfa3757650b1aa718d70` |
| Baseline subject | `PHASE 106F: discover and freeze next product read consumer target` |
| Initial worktree | Clean |
| Initial commits after baseline | `0` |
| Initial `git diff --check` | PASS |
| Required final subject | `PHASE 106G: migrate dashboard service to product catalog read contract` |
| Final commit | The single Phase 106G commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Required final commit count | Exactly `1` after baseline |

## Scope and non-goals

In scope:

- Replace the direct `DashboardService.load` product-list read with the frozen
  catalog read contract.
- Remove the unused broad product dependency from the service constructor.
- Update the one production construction and all compile-relevant test
  constructions.
- Preserve every Dashboard KPI, repository call, and control-flow semantic.
- Add structural, controlled-failure, behavioral, and genuine in-memory
  Drift/SQLite verification.

Explicit non-goals:

- No change to `ProductCatalogReadRepository`, `ProductCatalogReadModel`, or
  `DriftProductCatalogReadRepository`.
- No stock, price, cost, aggregate, lookup, or stream operation added to the
  catalog boundary.
- No schema, database version, migration, generated persistence, backup,
  profitability, authentication, role, cloud/mobile, or UI design change.
- No Dashboard KPI, label, text, layout, or access-control change.
- No migration of any fifth consumer and no legacy cleanup outside the target.
- No Push and no Tag.

## Starting checks

The required starting commands proved:

```text
git status --short                         → empty
git branch --show-current                  → codex/phase-106f-discover-freeze-next-product-read-consumer-target
git rev-parse HEAD                         → ad56678ff58334d46b76dfa3757650b1aa718d70
git log -1 --oneline                       → ad56678 PHASE 106F: discover and freeze next product read consumer target
git diff --check                           → exit 0
git rev-list --count <baseline>..HEAD      → 0
```

Only after these gates passed was the Phase 106G branch created.

## Frozen Phase 106F reference

The governing Phase 106F report and test were read completely, then checked
against the actual service, controller, screen, catalog contract, Drift
adapter, `AppRepositories`, alerts, and every `DashboardService(` construction.

The source proved both legacy and catalog adapters order by
`createdAt ASC, id ASC`. The selected method uses only `id` and `name`, requests
`includeInactive: true`, performs one-shot reads, and has no write or stream.
Inventory quantity remains an independent `InventoryRepository` concern.

## Runtime path before migration

```text
DashboardShell
→ DashboardScreen.didChangeDependencies
→ DashboardController.load
→ DashboardService.load
→ ProductRepository.listProducts(includeInactive: true)
→ AppRepositories.productRepository
→ ProductDataRepository / DriftProductRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

## Runtime path after migration

```text
DashboardShell
→ DashboardScreen.didChangeDependencies
→ DashboardController.load
→ DashboardService.load
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

The independently preserved stock path is:

```text
DashboardService.load
→ InventoryRepository.allProductBalancesKg()
→ production inventory repository
→ inventory data source
```

The already migrated nested alert path also remains unchanged:

```text
DashboardService.load
→ InventoryAttentionService.loadAttention
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ InventoryRepository.allProductBalancesKg()
```

## Production changes

### `lib/core/dashboard/dashboard_service.dart`

- Removed the `product_repository.dart` import.
- Removed required constructor parameter `ProductRepository productRepository`.
- Replaced `_productRepository` with the narrow
  `_productCatalogReadRepository` field.
- Reused the existing required
  `ProductCatalogReadRepository productCatalogReadRepository` parameter.
- Replaced exactly one direct call:

```text
_productRepository.listProducts(includeInactive: true)
```

with:

```text
_productCatalogReadRepository.listProductCatalog(includeInactive: true)
```

No other statement in `DashboardService.load` changed.

### `lib/features/dashboard/dashboard_screen.dart`

- Removed only
  `productRepository: AppRepositories.productRepository` from the production
  `DashboardService` construction.
- Preserved
  `productCatalogReadRepository: AppRepositories.productCatalogReadRepository`.
- Preserved every other repository, lifecycle call, UI branch, and text.

`lib/app/app_repositories.dart` required no change: production already exposes
and initializes `AppRepositories.productCatalogReadRepository` as the real
`DriftProductCatalogReadRepository(database)`.

## Constructor and call-site audit

`rg -n "DashboardService\s*\(" lib test` found one production construction,
six executable test/helper constructions, the constructor declaration, the
new Phase 106G fixture, and historical source assertions.

The six existing test/helper constructions were updated only by removing the
obsolete `productRepository:` argument. Their existing catalog adapters and
all behavioral fixtures remain unchanged:

- `test/competition04_dashboard_readiness_test.dart`
- `test/phase36_supplier_accounts_dashboard_test.dart`
- `test/phase36e_supplier_payment_ui_test.dart`
- `test/phase36g_ui_clarity_cancellation_safety_test.dart`
- `test/phase37c_dashboard_labels_test.dart` (two constructions)

The Phase 106F discovery test was converted into an immutable Git snapshot at
commit `ad56678ff58334d46b76dfa3757650b1aa718d70`. It continues proving the
intentional pre-migration state without incorrectly constraining later phases.

## Frozen behavior proof

### Include inactive

The selected call still passes explicit `includeInactive: true`. A controlled
repository records the argument, and a real inactive SQLite wheat row is
selected ahead of an active match.

### Ordering and first wheat match

The service still performs the same three case-sensitive `name.contains`
checks, materializes matches in input order, and uses
`wheatProduct.first.id`. It adds no `.sort`, set conversion, lookup, code/id
fallback, normalization, or deduplication.

The genuine runtime test inserts an inactive match before an active match by
creation time, gives each a different stock balance, and proves the earlier
row wins. Both adapters use `createdAt ASC, id ASC`, so no service-level sorting
was added.

### Wheat stock and inventory separation

The exact expression remains:

```text
balances[wheatProduct.first.id] ?? 0
```

`wheatStockKg` remains zero when there is no matching name or no balance for
the selected ID. A code and ID containing `wheat` with a non-wheat name do not
match. Balances of other products are not substituted. Stock is read only
from `InventoryRepository`; the catalog model was not expanded.

### `hasData` and empty state

The exact expression remains:

```text
products.isNotEmpty || allSales.isNotEmpty
```

An inactive-only or non-wheat-only catalog still makes `hasData` true. An empty
catalog with no sales makes it false. Absence of wheat and absence of stock do
not redefine the flag. All other Dashboard fields retain their previous
calculations; real empty repositories produce the same zero values.

### Re-read, cache, retry, fallback, and errors

Every call awaits a fresh catalog snapshot. A real SQLite test loads an empty
table, inserts a wheat row and movement, loads again, updates the product name,
and loads a third time; all three states are observed.

There is no cache, memoization, retained future, retry, fallback, catch, or
empty-list substitution. A controlled catalog error and a controlled inventory
error each propagate by object identity after one read attempt. The existing
`DashboardController` remains the higher layer that converts service failures
to the established UI error state.

### Write-free result

The selected method still calls only read operations and constructs immutable
`DashboardData`. Source guards prohibit product/inventory mutations,
transactions, and catches. Real before/after snapshots prove products and
inventory movements are unchanged by `load`.

## Genuine SQLite runtime proof

New test:
`test/phase106g_genuine_runtime_dashboard_service_product_catalog_read_integration_test.dart`.

It opens only `openInMemoryTestDatabase()`, initializes the real production
`AppRepositories` composition with that database, asserts the concrete catalog
adapter type, and invokes the real `DashboardService` with production
repositories. It covers:

1. Production `DriftProductCatalogReadRepository` composition.
2. Active and inactive wheat rows.
3. Real `createdAt ASC, id ASC` ordering and first-match behavior.
4. No code/id fallback or deduplication.
5. Correct stock mapping without cross-product substitution.
6. Missing balance and missing match.
7. Empty products and inventory tables.
8. Fresh reads after insert and update.
9. Product/movement before/after snapshots proving no writes.
10. Controlled catalog and inventory failure propagation without retry.
11. Structural absence of `ProductRepository`, `listProducts`, and production
    `AppRepositories.productRepository` from the selected path.

No fake is used for the success-path persistence proof. Controlled fakes are
used only to inject otherwise impractical read failures and record the exact
argument/attempt count.

## Architectural non-regression proof

The new test asserts:

- `DashboardService` imports and stores only
  `ProductCatalogReadRepository` for products.
- Its `load` method has exactly one direct `listProductCatalog` call and zero
  `listProducts` calls.
- Production Dashboard construction passes only
  `AppRepositories.productCatalogReadRepository` for this service.
- `DashboardGuidanceState.load`, `InventoryAttentionService.loadAttention`,
  and `LocalDocumentHistoryRepository` remain on the catalog contract.
- Exactly two production files differ from the Phase 106F baseline.
- The frozen contract, adapter, schema, generated persistence, inventory
  attention, and document-history files are byte-for-byte unchanged.

Thus `DashboardService.load` is the fourth migrated product-read consumer, and
no fifth consumer is migrated.

## Tests added or modified

Added:

- `test/phase106g_genuine_runtime_dashboard_service_product_catalog_read_integration_test.dart`

Modified for constructor compatibility or historical freezing:

- `test/competition04_dashboard_readiness_test.dart`
- `test/phase36_supplier_accounts_dashboard_test.dart`
- `test/phase36e_supplier_payment_ui_test.dart`
- `test/phase36g_ui_clarity_cancellation_safety_test.dart`
- `test/phase37c_dashboard_labels_test.dart`
- `test/phase106e_inventory_attention_product_catalog_read_migration_test.dart`
- `test/phase106f_next_product_read_consumer_target_discovery_freeze_test.dart`

No test was deleted, weakened, skipped, or disabled.

## Contract, schema, and unrelated-scope proof

Git diff guards prove no change to:

- `lib/core/catalog/product_catalog_read_repository.dart`
- `lib/core/catalog/drift_product_catalog_read_repository.dart`
- `lib/core/persistence/foundation_database.dart`
- `lib/core/persistence/foundation_database.g.dart`
- database version, Drift tables, migrations, backup format, profitability,
  authentication, roles, cloud/mobile, or unrelated screens.

`AppRepositories` and the three prior consumer implementations also remain
unchanged.

## Verification results

| Gate | Result |
| --- | --- |
| New Phase 106G focused test | PASS — 11 passed, 0 failed, 0 skipped |
| Updated Dashboard/call-site/Phase 106F focused set | PASS — 75 passed, 0 failed, 0 skipped across 7 files |
| Phase 105B–106G and related regression | PASS — 334 passed, 0 failed, 0 skipped across 39 files |
| Full `flutter test` | PASS — 2045 passed, 0 failed, 1 unchanged historical skip; 148.0 s wall time |
| Skip count | One unchanged historical skip in `test/phase9a_inflows_outflows_reports_test.dart`; no new skip |
| `dart format .` | PASS — 385 Dart files checked, 0 changed; 5.62 s |
| `flutter analyze` | PASS — no issues found; final run 9.6 s |
| `git diff --check` | PASS after tests, formatting, analysis, and release build |
| Windows release build | PASS — 123.3 s Flutter build time; exit 0 |
| Native smoke | NOT RUN — isolation from the user database is not proven |

The broad regression covers Phase 105B–106G, Product Catalog, Dashboard,
Inventory Attention, Document History, Inventory, Audit Log, and Phase 102
profitability/valuation. The Windows build emitted the existing non-fatal
Firebase CMake minimum-version deprecation and `.voltbl` linker warnings.

Release artifact:

- Path:
  `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes.
- SHA-256:
  `20DAA80276A097C41726C5DE125839A2FE9B4E9969ED9B06EE46AB138F7F0BD8`.

The complete staged diff statistics, post-commit status, immutable commit SHA,
and final commit count are recorded after all gates pass and in the final
handoff.

## Files and diff statistics

- Changed files: `11` total.
- Production files: `2` modified.
- Tests: `1` added and `7` modified.
- Documentation: `1` report added.
- Staged diff: `11 files changed, 989 insertions, 31 deletions`.
- New runtime test: `556` insertions, `0` deletions.
- Governing report: `388` insertions, `0` deletions.
- Before commit, every change is staged, `git diff --cached --check` passes,
  and the commit count after baseline remains `0`.
- Required final worktree state is clean with exactly one commit after baseline;
  the immutable SHA and verified status are recorded in the final handoff.

## User database safety

Only source inspection, Git, Flutter tests, an in-memory SQLite database, and
safe build commands are used. No AppData production path is used and the
native application is not launched.

Native smoke was not run because isolation from the user database was not proven.

لم تُفتح أو تُقرأ أو تُعدّل قاعدة بيانات المستخدم.

## No Push or Tag

No Push and no Tag are performed in Phase 106G.

## Next phase only

Because Phase 106G itself includes the genuine production-composition
Drift/SQLite proof, a duplicate runtime-proof phase is unnecessary.

**Phase 106H — Accept and Close the DashboardService Product Catalog Read Migration**
