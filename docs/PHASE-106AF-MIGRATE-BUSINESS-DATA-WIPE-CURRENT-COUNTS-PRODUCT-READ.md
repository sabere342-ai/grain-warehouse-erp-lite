# Phase 106AF — Migrate Business Data Wipe Current Counts Product Read

## Identification

| Evidence | Value |
| --- | --- |
| Phase | Phase 106AF — Migrate Business Data Wipe Current Counts Product Read |
| Branch | `codex/phase-106af-migrate-business-data-wipe-current-counts-product-read` |
| Starting HEAD | `1d1b24afac39fe3e83704aa73747568c2c9b525c` |
| Starting worktree | clean |
| Final commit message | `PHASE 106AF: migrate business data wipe current counts product read` |
| Final HEAD | Created after this report is staged; the exact immutable hash is recorded in the final handoff because a commit cannot contain its own hash |
| Outcome | Outcome A — FULL SUCCESS |
| Push / Tag | none |

## Scope

The sole migrated consumer is PRC-103,
`BusinessDataWipeService._currentCounts`, in
`lib/core/backup/business_data_wipe_service.dart`.

Production files changed:

- `lib/core/backup/business_data_wipe_service.dart`: inject the existing
  product-catalog read boundary and migrate only the product-count read.
- `lib/app/app_repositories.dart`: pass the existing
  `productCatalogReadRepository` into the service at the genuine application
  composition site.

Explicitly excluded and unchanged: the product-catalog contract and read
model, Drift adapter, SQL, queries, schema, migrations, generated files,
persistence behavior, every product write, every wipe delete, wipe ordering,
transaction behavior, backup/restore formats, UI, permissions, confirmation,
and every other product-read consumer.

## Before

| Item | Value |
| --- | --- |
| Read dependency | `ProductDataRepository _productRepository` |
| Call | `_productRepository.listProducts(includeInactive: true)` |
| Visibility | active and inactive products |
| Result use | `products.length` |
| Product fields consumed | none |

## After

| Item | Value |
| --- | --- |
| Read dependency | `ProductCatalogReadRepository _productCatalogReadRepository` |
| Call | `_productCatalogReadRepository.listProductCatalog(includeInactive: true)` |
| Visibility | active and inactive products, unchanged |
| Result use | `products.length`, unchanged |
| Product fields consumed | none |
| Contract expansion | none |

The method has exactly one `products.` use, `products.length`; it does not
filter, sort, project, or inspect any `ProductCatalogReadModel` field.

## Wiring

The genuine construction location is the
`AppRepositories.businessDataWipeService` getter in
`lib/app/app_repositories.dart`. It now passes the already-composed
`AppRepositories.productCatalogReadRepository`, which resolves to
`DriftProductCatalogReadRepository` after production initialization and to the
existing local compatibility adapter before initialization.

`ProductDataRepository` remains required and injected. It is deliberately
retained because the unchanged wipe sequence still invokes
`_productRepository.clearForOwnerDataWipe()`. Only the read slice moved; the
write/delete dependency and behavior did not.

The two existing direct test constructions in Phase 17 and Phase 18 now pass
their existing `ProductCatalogReadRepositoryTestAdapter`. No new locator,
singleton, cache, fallback, dual read, or parallel initialization path was
introduced.

## Behavioral parity

- Product count semantics remain the returned list length.
- `includeInactive: true` remains literal, so active and inactive rows count.
- Inventory movement, supplier, purchase, sale, document history, customer,
  expense, and audit-log counts are fetched in the same order and counted in
  the same way.
- Catalog-read failure enters the existing catch and returns
  `technicalReason: backup-required-failed`.
- A catalog-read failure occurs before the first clear, preserving the current
  no-delete failure behavior.
- The product clear still uses `ProductDataRepository`; all other write/delete
  repositories and the wipe sequence are unchanged.
- No transaction behavior was added, removed, or reordered.
- Backup creation, validation, preview, and file save still precede current
  counts exactly as before.
- No UI, database, schema, adapter, contract, or generated file changed.

## Inventory reconciliation

The live `lib/**/*.dart` inventory after PRC-103 migration reconciles as:

| Metric | Count |
| --- | ---: |
| Total consumers | 24 |
| Migrated | 14 |
| Remaining | 10 |
| Legacy `.listProducts(` calls | 12 |
| Product Catalog `.listProductCatalog(` calls | 14 |
| Remaining classification F | 5 |
| Remaining classification I | 5 |

Therefore `24 = 14 + 10`, and `10 = 5 + 5`. PRC-103 is migrated with
`includeInactive = true`, fields consumed `none`, and list operation `length`.
No other PRC moved.

## Tests and historical guards

The dedicated guard is
`test/phase106af_migrate_business_data_wipe_current_counts_product_read_test.dart`.
It proves active-plus-inactive length counting, explicit visibility, no legacy
list call, unchanged other counts, retained product clear, failure-before-clear
behavior, genuine app wiring, exact production scope, no contract/adapter/
persistence diff, and live call-count reconciliation.

The Phase 17 and Phase 18 fixtures were updated only to supply the new read
dependency. Historical guards updated to reconcile the current forward
lineage are:

- `test/phase106aa_reaudit_freeze_next_product_read_migration_target_test.dart`
- `test/phase106ab_backup_export_product_catalog_migration_test.dart`
- `test/phase106ac_reaudit_freeze_next_product_read_migration_target_test.dart`
- `test/phase106ad_migrate_backup_restore_empty_system_product_read_test.dart`
- `test/phase106ae_reaudit_freeze_next_product_read_migration_target_test.dart`
- `test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart`
- `test/phase106p_purchase_controller_product_catalog_read_migration_test.dart`
- `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart`
- `test/phase106r_inventory_controller_product_catalog_read_migration_guard_test.dart`
- `test/phase106s_inventory_controller_product_catalog_runtime_integration_test.dart`
- `test/phase106t_next_product_read_migration_target_freeze_test.dart`
- `test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart`
- `test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart`
- `test/phase106w_next_product_read_migration_target_freeze_test.dart`
- `test/phase106x_product_controller_product_catalog_migration_freeze_test.dart`
- `test/phase106y_next_product_read_migration_target_freeze_test.dart`
- `test/phase106z_profitability_report_activation_product_read_migration_test.dart`

Their historical reports and historical revision assertions remain intact;
only current forward-lineage allowlists, caller inventories, and the latest
live 24-consumer reconciliation were advanced for PRC-103.

## Verification

| Command / group | Actual result |
| --- | --- |
| `flutter test test/phase106af_migrate_business_data_wipe_current_counts_product_read_test.dart` | 5 passed, 0 failed |
| Phase 106AE/AD/AC/AB closest guards | 27 passed, 0 failed |
| All Phase 105/106 guards, executed in stable smaller groups after two aggregate Windows timeouts | all passed, 0 failed |
| Backup/restore/wipe affected group (Phases 13–18 plus owner wipe snapshot) | 73 passed, 0 failed |
| Base `product_catalog_test.dart` | 15 passed, 0 failed |
| Full Product Catalog Read guard set | all passed, 0 failed |
| `flutter analyze` | `No issues found!` |
| Stable formatter rerun on all 22 modified Dart files | `Formatted 22 files (0 changed)` |
| `git diff --check` | exit 0; no whitespace errors |
| `flutter test --concurrency=1` | 2,295 passed; 1 historical skip; 0 failed |
| `flutter test` | 2,295 passed; 1 historical skip; 0 failed |

The two early aggregate Phase 105/106 invocations timed out because the Windows
runner produced no result for very large multi-file invocations. The same
files were then run in smaller stable groups, all passed, and both complete
test-suite invocations subsequently passed. No test failure is hidden by those
runner timeouts.

## Git proof

- Baseline was verified exactly before editing and the worktree was clean.
- The production diff contains only the two allowed production files.
- Contract, adapter, persistence, schema, migration, and generated paths have
  no diff.
- Explicit file staging and cached-diff checks are required before commit.
- Exactly one commit after the baseline is required and is verified in the
  final handoff.
- Final clean worktree, exact final HEAD, and the one-commit proof are recorded
  in the final handoff after the self-referential commit hash is created.
- No push and no tag are performed.

No tool was created in this phase.
