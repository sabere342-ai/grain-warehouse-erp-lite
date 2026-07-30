# Phase 106C — Prove Genuine Runtime Dashboard Guidance Product Catalog Read Integration

## 1. Outcome

**Outcome A — FULL SUCCESS**

The dashboard guidance product count is proven to execute through the real
Product Catalog read adapter against an isolated SQLite database. The proof
starts at the real `DashboardGuidanceState.load` consumer, includes active and
inactive rows, detects fresh database changes, rejects a legacy-read bypass,
preserves read-only behavior, and propagates catalog conversion failures.

## 2. Git Evidence

| Item | Value |
| --- | --- |
| Branch | `codex/phase-106c-prove-genuine-runtime-dashboard-guidance-product-catalog-read-integration` |
| Baseline | `f7b926119ccf9cf220ff8a3e0c46b9ad5ac52650` |
| Baseline subject | `PHASE 106B: migrate dashboard guidance product catalog read` |
| Final commit | The single Phase 106C commit; its immutable hash is recorded in the post-commit handoff because a commit cannot contain its own hash |
| Required commit subject | `PHASE 106C: prove dashboard guidance runtime product catalog integration` |
| Initial worktree | Clean; no tracked, staged, or untracked paths |
| Initial commits after baseline | `0` |
| Final worktree | Required to be clean by the post-commit gate |
| Final commits after baseline | Required to be exactly `1` by the post-commit gate |
| Push | Not performed |
| Tag | Not created |

The starting branch was
`codex/phase-106b-migrate-dashboard-guidance-state-load-product-catalog-read-contract`.
The initial `git diff --check` passed, and no tag pointed at the baseline.

## 3. Goal

Phase 106B migrated the second product-read consumer. Phase 106C proves that
the migrated consumer genuinely reaches the frozen Drift adapter and SQLite
table at runtime, instead of relying on a mock, fake list, direct adapter call,
or source inspection alone.

## 4. Proven Runtime Path

```text
DashboardScreen
→ DashboardGuidanceState.load
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository
→ Drift/SQLite products table
```

`DashboardScreen.didChangeDependencies` retains
`DashboardGuidanceState.load` as its production guidance loader. The runtime
tests invoke that exact static consumer, and production composition supplies
the adapter and repositories below it.

## 5. Test Design

The new test opens `FoundationDatabase` with the existing
`openInMemoryTestDatabase()` helper. This creates a real in-memory SQLite
database, enables foreign keys, runs the real Drift schema lifecycle, and has
no filesystem path that could resolve to the production database.

`AppRepositories.initializeProduction(databaseFactory: ...)` receives only
that in-memory database. It composes the real
`DriftProductCatalogReadRepository`, the real Drift inventory repository, and
the real Drift sale repository. The non-catalog tables are kept empty for the
guidance scenarios, so `stockMovementCount` and `saleCount` remain isolated at
zero. No catalog fake, mock, or stub is used, and no test double is needed for
the other two reads.

Products are inserted into the real Drift `products` table with
`ProductsCompanion.insert`. Scenario rows are cleared transactionally before
each test. `AppRepositories.close` closes the in-memory database after the
group; closing it releases the only SQLite connection and its memory store.

The test never calls `openProductionDatabase`, never resolves
`productionDatabaseFileName`, and never starts the native application.

## 6. Runtime Scenarios

### A — Genuine SQLite Read

Three real product rows are inserted. `DashboardGuidanceState.load` returns
`productCount == 3`, exactly matching the SQLite row snapshot.

### B — Inactive Products Included

The three-row scenario contains two active products and one inactive product.
All three contribute to the count, proving the frozen
`includeInactive: true` behavior.

### C — Empty Catalog

An empty `products` table returns `productCount == 0` without a crash or
invented default row. The unrelated movement and sale counts also remain zero.

### D — Legacy Product Repository Is Not Used

The test creates a deliberate legacy-read sentinel inside the isolated SQLite
row. SQLite is instructed to store text in the nullable
`default_sale_price_piasters_per_kg` column. That column is outside the frozen
five-column catalog projection but is read by the legacy full-product mapper.

The test first proves that
`AppRepositories.productRepository.listProducts(includeInactive: true)` throws
on this sentinel. It then calls `DashboardGuidanceState.load`, which succeeds
with `productCount == 1`. A legacy read call count is therefore effectively
zero on the successful consumer path: any such call would throw and fail the
test.

### E — No Fallback

The same sentinel proves that a successful catalog read is not replaced by or
followed with a legacy read. Separately, an unsupported persisted `unit` causes
the real catalog mapping to throw `ArgumentError` through
`DashboardGuidanceState.load`. The error is not swallowed, translated to a
default, or recovered through the legacy repository.

### F — Read Only

For the mixed active/inactive scenario, every persisted product field is
snapshotted before and after `load`: identity, normalized fields, code, unit,
activity, all three price fields, notes, and timestamps. The complete ordered
snapshot and row count remain identical. No insert, update, or delete occurs.

### G — Conversion Error Propagation

SQLite accepts a row whose `unit` is `unsupported-unit`. The production
`GrainUnit.fromWireName` conversion fails, and `DashboardGuidanceState.load`
propagates `ArgumentError` as frozen in Phase 106B.

### H — Fresh Re-read

The first load observes two SQLite rows. A third row is then inserted into the
same database, and a second load observes three. This proves that the consumer
does not read a cached fake or a prebuilt Dart list.

## 7. Architectural No-Bypass Proof

Method-scoped structural assertions complement, but do not replace, the
runtime proof. They verify that `DashboardGuidanceState.load`:

- references `AppRepositories.productCatalogReadRepository` exactly once;
- calls `listProductCatalog` exactly once;
- passes `includeInactive: true`;
- derives `productCount` from `products.length`;
- contains no `AppRepositories.productRepository` reference; and
- contains no `listProducts` call.

The sentinel and conversion-error scenarios independently enforce these
claims at runtime.

## 8. Production Diff

No production code changes.

There is no diff under `lib/`. UI, dashboard design, Arabic text, lifecycle,
`didChangeDependencies`, guidance rules, error handling, contracts, adapter,
schema, migrations, generated Drift code, write logic, other reads, Audit Log,
profitability, valuation, backup, restore, authentication, and cloud/mobile
wiring are unchanged.

## 9. Files

- `test/phase106c_genuine_runtime_dashboard_guidance_product_catalog_read_integration_test.dart`
  — adds the genuine isolated SQLite consumer proof and complementary
  method-scoped guards.
- `docs/PHASE-106C-PROVE-GENUINE-RUNTIME-DASHBOARD-GUIDANCE-PRODUCT-CATALOG-READ-INTEGRATION.md`
  — records scope, design, scenarios, safety, and executed evidence.

No existing test or production file was modified. No dependency, lock file,
generated file, or platform file changed.

## 10. Verification Results

| Gate | Actual result |
| --- | --- |
| Phase 106C focused test | PASS — 7 passed, 0 failed, 0 skipped; 10.6 s wall time |
| Phase 106A regression | PASS — 7 passed, 0 failed, 0 skipped; 6.2 s wall time |
| Phase 106B regression | PASS — 9 passed, 0 failed, 0 skipped; 7.0 s wall time |
| Phase 105B–105F regressions | PASS — 37 passed, 0 failed, 0 skipped; 7.2 s wall time |
| Related dashboard tests | PASS — 59 passed, 0 failed, 0 skipped; 11.3 s wall time |
| Audit Log reference regressions | PASS — 46 passed, 0 failed, 0 skipped; 11.0 s wall time |
| Phase 102 sensitive regressions | PASS — 61 passed, 0 failed, 0 skipped; 8.3 s wall time |
| Formatter | PASS — 381 Dart files checked, 0 changed; 4.85 s formatter time |
| Analyzer | PASS — `No issues found!`; 74.0 s analyzer time |
| Full suite | PASS — 2008 passed, 0 failed, 1 unchanged historical skip; 150 s wall time |
| Windows release | PASS — Flutter build 60.3 s; exit 0 |
| Production diff | PASS — no path under `lib/` |

The Product Catalog file names present in this repository are
`phase105c_local_drift_product_catalog_read_adapter_test.dart`,
`phase105d_product_catalog_application_read_boundary_migration_test.dart`, and
`phase105f_product_catalog_read_boundary_pilot_acceptance_freeze_test.dart`;
those actual names were used for verification.

The first two sandboxed build attempts timed out before Flutter could access
its SDK lockfile. Direct diagnosis returned: `Flutter failed to open a file at
"C:\src\flutter\bin\cache\lockfile"`. Re-running the same release build with
the required SDK-directory permission succeeded. This was an execution-sandbox
constraint, not a compiler, test, source, or Phase 106C failure.

The successful build emitted the existing non-fatal Firebase CMake
minimum-version deprecation warning and MSVC `LNK4078` `.voltbl` warning.

## 11. Windows Artifact

| Item | Value |
| --- | --- |
| Path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| Size | `784384` bytes |
| SHA-256 | `B33A6099D1EEA9DB1DD836B538CCBB8D4329007547A7275A671225082B0CB594` |
| Build timestamp | `2026-07-30 16:05:37` local time |

## 12. Database Safety and Native Smoke

All Phase 106C runtime data existed only in the in-memory SQLite database.
The user production database was not opened, read, copied, or modified.

Native smoke was not run because production database isolation for a native
launch was not proven. Building the executable does not launch it.

## 13. Scope Boundaries

This phase changes only proof and documentation. It does not change UI,
lifecycle, strings, guidance calculations, error semantics, read contracts,
schema, migrations, product writes, other consumers, Audit Log architecture,
financial calculations, inventory valuation, backup/restore, authentication,
or cloud/mobile behavior.

## 14. Final Decision

The genuine runtime path, inactive inclusion, empty result, fresh re-read,
legacy sentinel, no fallback, conversion failure propagation, read-only
behavior, regressions, analyzer, formatter, full suite, and Windows release all
pass. Phase 106C is accepted as **Outcome A — FULL SUCCESS**, subject only to
the mechanical post-commit Git checks whose immutable values are recorded in
the final handoff.

## 15. Proposed Next Phase Only

**Phase 106D — Discover and Freeze the Next Product Read Consumer Target**

This proposal is intentionally limited to one atomic discovery/freeze phase.
No third consumer migration is included in Phase 106C.
