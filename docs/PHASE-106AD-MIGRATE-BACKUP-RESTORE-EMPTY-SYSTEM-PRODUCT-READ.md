# Phase 106AD — Migrate Backup Restore Empty-System Product Read

## Outcome

**Outcome A — FULL SUCCESS**

Phase 106AD migrated only PRC-102, the product-presence read inside
`BackupRestoreService._checkEmptySystem`, from the legacy product repository
to the existing product-catalog read boundary. No product fields are consumed;
the returned list is used only through `List.isNotEmpty`.

## Git and worktree

| Evidence | Value |
| --- | --- |
| Branch | `codex/phase-106ad-migrate-backup-restore-empty-system-product-read` |
| Starting HEAD | `1cd4033720fd765a31b5b5357760c8f55e454f92` |
| Starting worktree | clean |
| Final commit message | `PHASE 106AD: migrate backup restore empty-system product read` |
| Final HEAD / commit hash | Created after this report is staged; the exact immutable hash is in the final handoff because a commit cannot contain its own hash |
| Required commits after baseline | exactly `1` |
| Final worktree | required clean after commit |
| Push / Tag | none |

## Migration

| Item | Before | After |
| --- | --- | --- |
| Consumer | `PRC-102` / `BackupRestoreService._checkEmptySystem` | unchanged |
| Read dependency | `ProductDataRepository _productRepository` | `ProductCatalogReadRepository _productCatalogReadRepository` for the product-presence read |
| Product read call | `_productRepository.listProducts(includeInactive: true)` | `_productCatalogReadRepository.listProductCatalog(includeInactive: true)` |
| Visibility | `includeInactive: true` | `includeInactive: true` |
| Consumption | `products.isNotEmpty` | `products.isNotEmpty` |
| Fields consumed | none | none |
| Contract expansion | none | none |

`ProductDataRepository` remains injected because restore snapshots and
`restoreProductsIntoEmpty` still require the write-capable dependency. App
composition injects the existing `productCatalogReadRepository`; the synthetic
trial tool uses its existing `DriftProductCatalogReadRepository` composition.
There is no new locator, singleton, mutable global, fallback, dual read, cache,
or parallel initialization path.

## Behavior preservation

- Empty-system semantics and the order of all entity checks are unchanged.
- An active product makes the system non-empty.
- An inactive-only product also makes the system non-empty because
  `includeInactive: true` is preserved literally.
- An empty product catalog permits the unchanged remaining empty-system checks
  and restore flow to continue.
- The system-not-empty message and technical reason are unchanged.
- Backup parsing, validation, schema validation, format, version, checksum,
  archive/file handling, and export behavior are unchanged.
- Restore sequencing, snapshots, transaction, rollback, and writes are
  unchanged.
- Wipe, reset, delete, import, UI, permissions, navigation, and localization
  behavior are unchanged.

## Exact changed files

### Production

```text
lib/app/app_repositories.dart
lib/core/backup/backup_restore_service.dart
```

### Tests

```text
test/phase106ad_migrate_backup_restore_empty_system_product_read_test.dart
test/phase106aa_reaudit_freeze_next_product_read_migration_target_test.dart
test/phase106ab_backup_export_product_catalog_migration_test.dart
test/phase106ac_reaudit_freeze_next_product_read_migration_target_test.dart
test/phase106o_next_product_read_migration_target_discovery_freeze_test.dart
test/phase106p_purchase_controller_product_catalog_read_migration_test.dart
test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart
test/phase106r_inventory_controller_product_catalog_read_migration_guard_test.dart
test/phase106s_inventory_controller_product_catalog_runtime_integration_test.dart
test/phase106t_next_product_read_migration_target_freeze_test.dart
test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart
test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart
test/phase106w_next_product_read_migration_target_freeze_test.dart
test/phase106x_product_controller_product_catalog_migration_freeze_test.dart
test/phase106y_next_product_read_migration_target_freeze_test.dart
test/phase106z_profitability_report_activation_product_read_migration_test.dart
test/phase16_restore_empty_system_test.dart
test/phase17_owner_data_wipe_test.dart
test/phase18_release_candidate_qa_test.dart
test/phase21b_pricing_cost_minimum_ui_acceptance_test.dart
test/phase21c_profit_stock_valuation_reports_test.dart
test/phase21d_end_to_end_business_release_test.dart
test/phase31_functional_recovery_test.dart
test/phase32_pilot_acceptance_test.dart
test/phase39_customer_bound_multi_item_sales_test.dart
test/phase67_navigation_theme_branding_test.dart
test/phase68_business_logo_invoice_windows_icon_test.dart
test/phase81_transaction_financial_backup_contract_test.dart
test/phase95_business_profile_expansion_test.dart
```

The existing restore tests were changed only to supply the new required read
dependency. Historical product-read guards were extended only to admit the
linear 106AC/106AD lineage and the one newly accepted catalog consumer.

### Docs / tool

```text
docs/PHASE-106AD-MIGRATE-BACKUP-RESTORE-EMPTY-SYSTEM-PRODUCT-READ.md
tool/run_phase102j_synthetic_trial.dart
```

## Forbidden-scope diff proofs

`git diff --name-only 1cd4033720fd765a31b5b5357760c8f55e454f92 -- lib`
returned exactly:

```text
lib/app/app_repositories.dart
lib/core/backup/backup_restore_service.dart
```

The baseline diff is empty for all of:

```text
lib/core/catalog/product_catalog_read_repository.dart
lib/core/catalog/drift_product_catalog_read_repository.dart
lib/core/persistence
```

Therefore there is no change to `ProductCatalogReadModel`, the catalog
contract, the Drift adapter, schema, migrations, or generated persistence.
Search evidence finds the new catalog call with `includeInactive: true` and
`products.isNotEmpty`, and no targeted legacy call inside the service.

## Verification

| Gate | Result |
| --- | --- |
| Dedicated Phase 106AD | PASS — 5 passed, 0 failed |
| Phase 106AA/106AB/106AC/106AD guards | PASS — 29 passed, 0 failed |
| Phase 106O/106Q lineage plus 106AD | PASS — 26 passed, 0 failed |
| Forward product-catalog guard stage | PASS — 128 passed, 0 failed |
| Backup/restore stage | PASS — 41 passed, 0 failed |
| Product Catalog contract/adapter/runtime stage | PASS before the historical-guard extensions; all updated catalog guards pass in the stages above |
| Full suite, `--concurrency=1` | PASS — exit code `0`, 2,281 passed, 1 skipped, 0 failed; 719 seconds |
| Full suite, default concurrency | PASS — exit code `0`, 2,281 passed, 1 skipped, 0 failed; 370.5 seconds |
| `flutter analyze` | PASS — no issues found |
| Formatter | PASS — modified Dart files formatted; final check left 0 changes |
| `git diff --check` | PASS |
| Production diff | PASS — exactly the two allowed production files |

The one skipped test is the repository's pre-existing historical skip and was
not changed by this phase.

## Final integrity requirements

After the single final commit, the following must hold and are rechecked in the
handoff:

```text
git rev-list --count 1cd4033720fd765a31b5b5357760c8f55e454f92..HEAD
1

git status --short
<empty>
```

No push or tag is performed.
