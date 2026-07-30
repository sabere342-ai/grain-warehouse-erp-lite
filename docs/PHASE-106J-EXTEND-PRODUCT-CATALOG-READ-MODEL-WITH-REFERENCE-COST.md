# Phase 106J — Extend ProductCatalogReadModel with Reference Cost

## Outcome

**Outcome A — FULL SUCCESS**

`ProductCatalogReadModel` now exposes the single frozen nullable reference-cost
field, and `DriftProductCatalogReadRepository` reads it directly from the
existing nullable integer product column. No consumer was migrated in this
phase.

## Phase data

| Item | Value |
| --- | --- |
| Phase | `106J` |
| Branch | `codex/phase-106j-extend-product-catalog-read-model-reference-cost` |
| Starting HEAD | `2b3f5fb93427efa68e66a383bed5873027081514` |
| Starting subject | `PHASE 106I: discover and freeze next product read contract expansion` |
| Initial worktree | Clean |
| Initial commits after baseline | `0` |
| Initial `git diff --check` | PASS — exit 0, no output |
| Final commit | The single Phase 106J commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Commit subject | `PHASE 106J: extend product catalog read model with reference cost` |
| Required commits after baseline | Exactly `1` |
| Final worktree | Required clean; verified after the final commit and reported in the handoff |
| Final phase diff | `14 files changed, 420 insertions(+), 8 deletions(-)` |

## Implemented expansion

The read model adds exactly:

```dart
final int? referenceCostPricePiastersPerKg;
```

The named constructor parameter is nullable but required. Every production,
test-adapter, fake, and fixture construction passes it explicitly. The legacy
composition adapter forwards `Product.referenceCostPricePiastersPerKg`; test
fixtures use an explicit `null` where the cost is irrelevant.

The Phase 106I report illustrated an optional nullable constructor parameter,
while the governing Phase 106J instruction explicitly requires every
construction to pass the nullable field. Phase 106J follows the later,
phase-specific rule and makes the parameter `required`; nullability itself is
unchanged.

The production Drift adapter retains `selectOnly(products)` and explicitly
adds:

```dart
products.referenceCostPricePiastersPerKg
```

to the selected columns. It maps the row directly with:

```dart
row.read(products.referenceCostPricePiastersPerKg)
```

The actual schema declaration remains the existing
`IntColumn get referenceCostPricePiastersPerKg => integer().nullable()();`,
whose SQLite column name is `reference_cost_price_piasters_per_kg`. No schema,
generated-code, database-version, or migration change was made.

## Mapping and behavioral evidence

- `null` is preserved as `null`; no zero fallback exists.
- A stored value of `2375` is returned as the same Dart `int` value `2375`.
- There is no division, multiplication, rounding, `double`, kg/ton conversion,
  or piaster/EGP conversion.
- `includeInactive: false` still filters out inactive rows.
- `includeInactive: true` still returns active and inactive rows.
- Ordering remains `createdAt ASC, id ASC`.
- A second invocation observes a direct isolated SQLite test update from
  `2375` to `4123`, proving a fresh read and no cache.
- An invalid stored unit still raises the original `ArgumentError`; there is
  no error translation, swallowing, retry, or fallback.
- Before/after table snapshots prove `listProductCatalog` performs no writes.
- Results remain non-growable snapshots produced by each invocation.

## Scope boundaries

- `LocalReportRepository.dailyActivityReport` was not migrated and still uses
  `_productRepository.listProducts(includeInactive: true)`.
- `LocalReportRepository`, `ReportController`, and `ReportsScreen` were not
  modified.
- `ProductController.loadProducts`, `SaleController.load`, and
  `BackupExportService.createBackup` were not modified.
- No new consumer, method, lookup, stream, cache, retry, fallback, write,
  transaction, UI, navigation, schema, migration, database-version, backup
  format, or backup-version change was introduced.
- Historical Phase 106G–106I Git-scope guards were made commit-relative so
  they continue to prove their own immutable phase ranges after this legitimate
  later production change; their behavioral assertions were not weakened.

## Verification evidence

| Gate | Result |
| --- | --- |
| Phase 106J focused test | PASS — 5 passed, 0 failed, 0 skipped |
| Related product-read regression | PASS — 130 passed, 0 failed, 0 skipped across 17 files |
| Full `flutter test` | PASS — 2067 passed, 0 failed, 1 historical skip; 153.9 s wall time |
| Historical skip audit | Unchanged `test/phase9a_inflows_outflows_reports_test.dart` credential-dependent skip |
| Formatter | PASS — 13 changed Dart files checked, 0 required changes on final run; 0.69 s |
| `flutter analyze` | PASS — No issues found; 28.8 s analyzer time, 30.9 s wall time |
| Windows release | PASS — `flutter build windows --release`; 64.3 s build time, 66.1 s wall time |
| Native smoke | NOT RUN — isolation from user database not proven |

The first sandboxed Windows build remained blocked without output and was
terminated. The identical command then completed successfully outside that
sandbox restriction. The build emitted only the previously known non-fatal
Firebase CMake minimum-version deprecation warning and `.voltbl` linker
warning.

## Windows release artifact

- Path:
  `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes.
- SHA-256:
  `74E94AE6A6D08EDCC9DF54C62A59A9533589D0A81427EDBA78BAEF5D54373D3F`.

## User database protection

All Phase 106J repository integration coverage used `NativeDatabase.memory`
through `openInMemoryTestDatabase()`. The production application was not launched.
The user database was not opened, read, copied, modified, backed up, or
migrated.

## Changed files

Production:

- `lib/core/catalog/product_catalog_read_repository.dart`
- `lib/core/catalog/drift_product_catalog_read_repository.dart`
- `lib/app/app_repositories.dart`

Tests and test support:

- `test/phase106j_product_catalog_read_model_reference_cost_test.dart`
- `test/phase105b_product_catalog_read_contract_test.dart`
- `test/phase105d_product_catalog_application_read_boundary_migration_test.dart`
- `test/phase105f_product_catalog_read_boundary_pilot_acceptance_freeze_test.dart`
- `test/phase106e_inventory_attention_product_catalog_read_migration_test.dart`
- `test/phase106g_genuine_runtime_dashboard_service_product_catalog_read_integration_test.dart`
- `test/phase106h_dashboard_service_product_catalog_read_migration_acceptance_freeze_test.dart`
- `test/phase106i_next_product_read_contract_expansion_discovery_freeze_test.dart`
- `test/inventory_attention_service_test.dart`
- `test/support/product_catalog_read_repository_test_adapter.dart`

Documentation:

- `docs/PHASE-106J-EXTEND-PRODUCT-CATALOG-READ-MODEL-WITH-REFERENCE-COST.md`

No Push and no Tag are performed.

## Next phase proposed only

**Phase 106K — Migrate LocalReportRepository Daily Activity Product Read**

Phase 106K is not implemented here.
