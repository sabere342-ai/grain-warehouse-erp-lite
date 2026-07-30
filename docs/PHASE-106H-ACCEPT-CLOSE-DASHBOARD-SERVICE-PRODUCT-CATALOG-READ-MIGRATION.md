# Phase 106H — Accept and Close the DashboardService Product Catalog Read Migration

## Outcome

**Outcome A — FULL SUCCESS**

The migration of the direct product read owned by `DashboardService.load`
from `ProductRepository` to `ProductCatalogReadRepository` is accepted,
closed, and architecturally frozen. The acceptance proof combines source and
Git guards with genuine isolated in-memory Drift/SQLite execution through the
production catalog adapter.

## Phase data

| Item | Value |
| --- | --- |
| Phase | `106H` |
| Branch | `codex/phase-106h-accept-close-dashboard-service-product-catalog-read-migration` |
| Governing baseline | `4e9af2034aca1694545027a50336ad15de46f2bf` |
| Baseline subject | `PHASE 106G: migrate dashboard service to product catalog read contract` |
| Initial worktree | Clean |
| Initial commits after baseline | `0` |
| Initial `git diff --check` | PASS — exit 0, no output |
| Final commit | The single Phase 106H commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Commit subject | `PHASE 106H: accept and close dashboard service product catalog read migration` |
| Required commits after baseline | Exactly `1` |
| Final worktree | Required clean; verified after the final commit and reported in the handoff |
| Phase files | `2` new files |
| Phase diff | `2 files changed, 915 insertions, 0 deletions` |
| Production diff under `lib/` | None |

## Scope

Phase 106H is evidence, acceptance, closure, and architectural freeze only.
It does not migrate another consumer and does not alter production behavior.

Added only:

- `test/phase106h_dashboard_service_product_catalog_read_migration_acceptance_freeze_test.dart`
- `docs/PHASE-106H-ACCEPT-CLOSE-DASHBOARD-SERVICE-PRODUCT-CATALOG-READ-MIGRATION.md`

There is no Phase 106H diff under `lib/`. There is no schema, migration,
database-version, generated Drift, UI, contract, adapter, inventory-contract,
sales-contract, cache, retry, fallback, or write-path change.

## Architectural evidence

### Old path frozen by Phase 106F

```text
DashboardScreen.didChangeDependencies
→ DashboardController.load
→ DashboardService.load
→ ProductRepository.listProducts(includeInactive: true)
→ AppRepositories.productRepository
→ ProductDataRepository / DriftProductRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

### Accepted production path

```text
DashboardScreen.didChangeDependencies
→ DashboardController.load
→ DashboardService.load
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

The production construction in `DashboardScreen` passes
`AppRepositories.productCatalogReadRepository` and does not pass
`AppRepositories.productRepository` to `DashboardService`. Production
initialization binds the narrow repository to
`DriftProductCatalogReadRepository(database)`.

### ProductRepository removal

`DashboardService`:

- does not import `product_repository.dart`;
- does not accept or store `ProductRepository`;
- does not call `listProducts`, `watchProducts`, or another legacy product
  read;
- stores `ProductCatalogReadRepository` and calls `listProductCatalog`
  exactly once for its direct product read;
- requests explicit `includeInactive: true`;
- has no fallback or bypass to the old repository.

The Phase 106G production diff is exactly:

- `lib/core/dashboard/dashboard_service.dart`
- `lib/features/dashboard/dashboard_screen.dart`

Phase 106H changes neither file.

### Inventory remains independent

Stock quantities remain owned by `InventoryRepository`:

```text
DashboardService.load
→ InventoryRepository.allProductBalancesKg()
→ production inventory repository
→ inventory data source
```

The catalog supplies only product identity and descriptive fields. It does not
supply or derive inventory quantities. The frozen stock expression remains:

```dart
balances[wheatProduct.first.id] ?? 0
```

### Ordering and wheat matching

`DriftProductCatalogReadRepository` orders the SQLite query by:

```text
createdAt ASC, id ASC
```

`DashboardService` adds no sorting, reverse, set conversion, deduplication, or
grouping. Matches retain adapter order and `wheatProduct.first.id` wins.

The historical case-sensitive name predicate remains exactly the three
existing substring checks:

```dart
p.name.contains('قمح') ||
p.name.contains(' Wheat') ||
p.name.contains('wheat')
```

There is no code, ID, enum, mapping, or normalization fallback.

### Frozen result semantics

- A matching wheat product with a balance returns that balance.
- A matching wheat product without a balance yields `wheatStockKg == 0`.
- No wheat-name match yields `wheatStockKg == 0`.
- Multiple matches use only the first adapter-ordered match.
- An inactive first match remains eligible because the direct read explicitly
  requests `includeInactive: true`.
- The exact `hasData` expression remains:

```dart
products.isNotEmpty || allSales.isNotEmpty
```

The complete truth table is proven: empty/empty is false; products-only,
sales-only, and products-plus-sales are true. Wheat presence, stock presence,
stock value, and product activity do not redefine `hasData`.

### Fresh reads, errors, and no writes

Every new `DashboardService.load` invocation performs a new catalog query.
The Phase 106H test mutates genuine in-memory SQLite rows between calls and
observes inserts and updates on the next call. There is no service cache,
memoization, retained snapshot, retry, fallback, catch, or error swallowing.

A controlled catalog failure and a controlled inventory failure each
propagate by object identity after one read attempt. Controlled repositories
are used only to inject failures and record arguments/counts; success-path
catalog behavior uses the real production Drift adapter and SQLite.

Before/after snapshots cover product rows, inventory-movement rows, and sales
rows. `DashboardService.load` changes none of them. Test-owned inserts and
updates used to prove fresh reads are not service writes.

## Historical test audit

The seven existing tests changed by Phase 106G were reviewed against Phase
106F commit `ad56678ff58334d46b76dfa3757650b1aa718d70`:

- `test/competition04_dashboard_readiness_test.dart`
- `test/phase106e_inventory_attention_product_catalog_read_migration_test.dart`
- `test/phase106f_next_product_read_consumer_target_discovery_freeze_test.dart`
- `test/phase36_supplier_accounts_dashboard_test.dart`
- `test/phase36e_supplier_payment_ui_test.dart`
- `test/phase36g_ui_clarity_cancellation_safety_test.dart`
- `test/phase37c_dashboard_labels_test.dart`

Five dashboard fixture files and `competition04` removed only the obsolete
`productRepository:` constructor argument. Phase 106E replaced one obsolete
legacy-source expectation with stronger narrow-contract expectations. Phase
106F was changed to read its governing source/report snapshot from its own
immutable commit so it continues to prove the pre-migration state.

The acceptance guard proves that every file retains the same number of test
declarations, has at least as many `expect` assertions, and contains no
`skip: true`. No scenario, test, or strong assertion was removed or converted
to a superficial smoke test.

## Acceptance matrix

| Item | Evidence | Result |
| --- | --- | --- |
| Remove `ProductRepository` | Service/screen source and targeted search | PASS |
| Genuine production path | In-memory SQLite plus production composition | PASS |
| `includeInactive: true` | Source guard and inactive runtime row | PASS |
| `createdAt ASC, id ASC` | Adapter source plus equal-time ID tie runtime case | PASS |
| First wheat match | Two distinct matching rows and balances | PASS |
| `wheatStockKg` fallbacks | Real balance, missing balance, and no-match cases | PASS |
| `hasData` semantics | Four-case truth table | PASS |
| Fresh read | SQLite insert and update between loads | PASS |
| Catalog error propagation | Same error object, exactly one call | PASS |
| Inventory error propagation | Same error object, exactly one call | PASS |
| No writes | Products/movements/sales snapshots before and after load | PASS |
| No schema changes | Git diff from Phase 106G baseline | PASS |
| Historical tests not weakened | Immutable Phase 106F/106G diff audit | PASS |
| No production diff in Phase 106H | `git diff -- lib` | PASS |

## Verification evidence

| Gate | Result |
| --- | --- |
| Phase 106G focused test | PASS — 11 passed, 0 failed, 0 skipped |
| Phase 106H focused test | PASS — 9 passed, 0 failed, 0 skipped |
| Dashboard and all executable `DashboardService` call sites | PASS — 93 passed, 0 failed, 0 skipped across 9 files |
| Product catalog / adapter / composition / inventory / sales regression | PASS — 184 passed, 0 failed, 0 skipped across 20 files |
| Full `flutter test` | PASS — 2054 passed, 0 failed, 1 unchanged historical skip; 132.3 s wall time |
| Skip audit | One unchanged historical skip in `test/phase9a_inflows_outflows_reports_test.dart`; no new skip |
| `dart format .` | PASS — 386 files checked, 0 changed; 4.57 s |
| `flutter analyze` | PASS — no issues found; 88.0 s |
| `git diff --check` | PASS — exit 0, no output |
| `git diff -- lib` | PASS — empty |
| Windows release | PASS — exit 0; Flutter build time 24.0 s |
| Native smoke | NOT RUN — isolation from the user database not proven |

The focused regression covers the frozen read contract, the Drift catalog
adapter, application composition, the Phase 105B–106H sequence, Dashboard
guidance, inventory attention, inventory repositories, sales repositories,
and the Phase 106G historical test call sites.

## Windows release artifact

- Path:
  `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes.
- SHA-256:
  `871F67CB35CD730EE9B3C1370B4154480DEB025B54A4E1CE48482CF8BFC8DD7D`.
- Flutter result: exit `0`, `Built ...grain_warehouse_erp_lite.exe`.

The successful build emitted only the already known non-fatal Firebase CMake
minimum-version deprecation warning and `.voltbl` linker warning. Initial
sandboxed wrapper attempts could not access the Flutter SDK lockfile and
timed out before Dart/CMake/MSBuild started. Re-running the same build outside
that SDK-lock restriction completed successfully in 24.0 seconds. No build
gate was waived.

## User database safety

All database verification uses `openInMemoryTestDatabase()` and a production
composition explicitly injected with that isolated database. The native
application was not launched.

The user database was not opened, read, copied, or modified.

لم تُفتح أو تُقرأ أو تُنسخ أو تُعدّل قاعدة بيانات المستخدم.

Native smoke: NOT RUN — isolation from user database not proven.

## Closure decision

The migration:

```text
DashboardService → ProductCatalogReadRepository
```

is accepted, proven through genuine execution, closed, and architecturally
frozen. It is a valid reference pattern for later consumers whose needs fit
the current frozen catalog-read contract.

## Boundaries not included

Closure does not mean:

- migrating every remaining `ProductRepository` consumer;
- removing `ProductRepository` from the project;
- moving inventory quantities into the catalog contract;
- changing product write paths or transactional safety reads;
- adding a cloud backend or mobile UI;
- changing schema or migrations;
- extending `ProductCatalogReadRepository` or `ProductCatalogReadModel`.

## No Push or Tag

No Push and no Tag are performed in Phase 106H.

## Next phase only

Phase 106F classified the now-completed `DashboardService.load` migration as
the only remaining consumer eligible for the current frozen contract. Its
other read-only candidates were class D because they require fields outside
that contract, while transactional/write-coupled candidates were class E.
Therefore no new consumer is selected here.

Suggested discovery-only next phase:

**Phase 106I — Discover and Freeze the Next Product Read Contract Expansion**

That phase must select and freeze any required expansion before a later
consumer migration. Phase 106H does not implement it and does not nominate a
consumer on its behalf.
