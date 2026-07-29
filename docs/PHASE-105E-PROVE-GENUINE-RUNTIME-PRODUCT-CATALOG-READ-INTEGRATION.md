# Phase 105E — Prove Genuine Runtime Product Catalog Read Integration

## Outcome

**Outcome A — FULL SUCCESS**

Phase 105E proves that the migrated document-history product lookup runs
through the real application composition and the real Drift adapter against
an isolated SQLite database. The evidence does not use a fake catalog
repository or a test-only composition as its primary runtime proof.

## Repository and Git state

| Item | Value |
| --- | --- |
| Branch | `codex/phase-105e-prove-genuine-runtime-product-catalog-read-integration` |
| Baseline commit | `ea804cb19f0271f8df94cc83b97d73236fe098c7` |
| Baseline subject | `PHASE 105D: migrate one product catalog application read boundary` |
| Final commit | The single Phase 105E commit; its hash is recorded in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 105E: prove genuine runtime product catalog read integration` |
| Starting worktree | Clean |
| Final worktree | Clean after the single commit; verified post-commit |
| Push/Tag | Not performed |

## Exact scope and files

The phase adds runtime integration evidence and documentation. No production
file under `lib/` is modified.

- `test/phase105e_genuine_runtime_product_catalog_read_integration_test.dart`
  adds eight deterministic integration/architecture tests.
- `tool/run_phase102j_synthetic_trial.dart` repairs one stale constructor call
  left by Phase 105D. The isolated 102J trial now supplies
  `DriftProductCatalogReadRepository(database)` through the frozen interface
  instead of using the removed `productRepository` named parameter.
- This report is the only documentation file added.

The tool repair was required because the first Phase 105E analyzer run exposed
two compile errors at the stale call. It is not a second application-consumer
migration, a production branch, or a contract change; it composes the already
migrated `LocalDocumentHistoryRepository` over the trial's existing isolated
Drift database.

## Proven runtime path

```text
openInMemoryTestDatabase()
  -> NativeDatabase.memory (SQLite, foreign keys enabled)
  -> AppRepositories.initializeProduction(databaseFactory: ...)
  -> LocalDocumentHistoryRepository
  -> ProductCatalogReadRepository
  -> DriftProductCatalogReadRepository
  -> FoundationDatabase.products
```

The same production initialization also supplies the Drift purchase, sale,
and inventory repositories used by `LocalDocumentHistoryRepository`. Test
documents are stored in the isolated `purchases` table and read back through
the composed document-history repository.

## Genuine Drift/SQLite evidence

The focused test seeds realistic textual IDs such as `prd-105e-active` and
`prd-105e-inactive` directly into the isolated Drift `products` table, then
seeds historical purchase rows that reference those IDs. Reads are performed
only through `AppRepositories.documentHistoryRepository`.

The proof would fail if the runtime catalog were replaced by a static fake:

- Composition is asserted to expose `DriftProductCatalogReadRepository`.
- An initial document read resolves the stored product name.
- The product name is then changed directly in the SQLite row.
- A second read through the same repository instance returns the new name.
- An unsupported stored unit produces a real `ArgumentError` through the
  adapter. Updating that row to `GrainUnit.kilogram.name` makes retry succeed.

This proves fresh database-backed reads, explicit failure propagation, and a
successful retry without cached or duplicated history.

## Inactive products, identity, unit, empty state, and ordering

- An inactive row is excluded by an explicit catalog read with
  `includeInactive: false`, yet its historical purchase still resolves to the
  stored name through document history. This behaviorally proves the
  consumer's required `includeInactive: true` call.
- IDs remain exact `String` values; no numeric parsing is introduced.
- The active product scenario maps `GrainUnit.ton` and the optional code
  losslessly through the frozen model.
- An empty product and document store returns empty history without a crash.
- Two historical purchases remain ordered by document timestamp, newest
  first, independently of catalog ordering.

## Interface isolation and legacy bypass

Source guards supplement, rather than replace, the behavioral evidence. They
prove that `LocalDocumentHistoryRepository`:

- depends on `ProductCatalogReadRepository`;
- calls `listProductCatalog(includeInactive: true)`;
- does not reference `ProductRepository` or `listProducts`;
- does not import or reference the concrete Drift adapter, Drift, SQLite, or
  `FoundationDatabase`.

`AppRepositories` remains the production composition root that creates
`DriftProductCatalogReadRepository(database)` and passes the frozen interface
to the selected consumer. No UI, controller, schema, migration, backup format,
cloud, synchronization, mobile, or second-consumer change is made.

## Test database isolation and user-data protection

The focused runtime group creates its database exclusively with
`openInMemoryTestDatabase()`, whose implementation uses
`NativeDatabase.memory`. The database has no filesystem path and cannot be the
production database. It is passed through the existing `databaseFactory`
override, scenario rows are cleared in `setUp`, and `AppRepositories.close`
closes the connection in `tearDownAll`.

No production database opener was invoked, no application executable was
opened, no backup was imported/restored, and no user or customer data was
read, migrated, or modified.

## Verification gates

| Gate | Result |
| --- | --- |
| Phase 105E focused | PASS — 8 passed, 0 failed, 0 skipped |
| Phase 105D regression | PASS — 11 passed, 0 failed, 0 skipped |
| Phase 105C regression | PASS — 9 passed, 0 failed, 0 skipped |
| Phase 105B regression | PASS — 3 passed, 0 failed, 0 skipped |
| Existing selected-consumer tests | PASS — 213 passed, 0 failed, 0 skipped across 19 files |
| Audit Log boundary regression | PASS — 46 passed, 0 failed, 0 skipped |
| Phase 102J isolated | PASS — 5 passed, 0 failed, 0 skipped |
| Phase 102 related regression | PASS — 61 passed, 0 failed, 0 skipped |
| Final full suite | PASS — 1979 passed, 0 failed, 1 unchanged historical skip; exit 0; 158.9 s wall time |
| Formatter | PASS — 377 Dart files checked, 0 changed |
| Analyzer | PASS — no issues found; exit 0 |
| Windows release | PASS — Flutter build 49.1 s; exit 0 |
| `git diff --check` | PASS — exit 0 |
| Native smoke | NOT RUN — production database isolation for native launch was not proven |

The sole historical skip remains
`test/phase9a_inflows_outflows_reports_test.dart:552`; it requires negative
balance approval credentials. The Windows build emitted the existing Firebase
CMake minimum-version deprecation warning and `.voltbl` linker warning; both
were non-fatal.

## Windows release artifact

- Path:
  `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes
- SHA-256:
  `CDE2AAE32BAB8D6B065D82C88E69C61753038F9CB2C3AE30684E750607C74B57`

Native smoke was intentionally not run. Although the automated integration
database is conclusively isolated in memory, no equally conclusive override
was established for a native application launch. Data safety takes priority
over optional smoke evidence.

## Frozen boundaries and remaining risk

- `ProductCatalogReadModel`, `ProductCatalogReadRepository`,
  `listProductCatalog`, and all five frozen field types are unchanged.
- `DriftProductCatalogReadRepository`, product schema, generated database
  code, schema version, migrations, and backup versions/formats are unchanged.
- No UI source is changed.
- No push or tag is performed.
- The proof covers the first migrated document-history boundary only. It does
  not authorize migration of another consumer or introduction of cloud,
  synchronization, or mobile UI.

The remaining limitation is native-launch evidence, which was deliberately
omitted because production database isolation was not proven for that mode.

## Proposed next atomic phase

Phase 105F is not started here. The proposed next scope is only:

> **Phase 105F — Accept and Freeze the First Product Catalog Read Boundary Pilot**
