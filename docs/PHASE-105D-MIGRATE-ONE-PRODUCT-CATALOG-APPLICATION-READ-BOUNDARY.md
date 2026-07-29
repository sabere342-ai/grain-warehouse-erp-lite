# Phase 105D — Migrate One Product Catalog Application Read Boundary

## Outcome

**Outcome A — FULL SUCCESS: ONE APPLICATION READ BOUNDARY MIGRATED**

Phase 105D migrates only `LocalDocumentHistoryRepository` from the broad
read/write `ProductRepository` to the frozen `ProductCatalogReadRepository`.
It preserves document-history behavior and does not modify UI, the frozen
contract, the Drift adapter, schema, migrations, backup formats, cloud, sync,
or any second application consumer.

## Repository and Git state

| Item | Value |
| --- | --- |
| Branch | `codex/phase-105d-migrate-one-product-catalog-application-read-boundary` |
| Starting HEAD | `edda4ec72ee8307185801376e8955fb5bdfb1a77` |
| Starting commit | `PHASE 105C: implement local drift product catalog read adapter` |
| Final commit | The single Phase 105D commit; its hash is recorded in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 105D: migrate one product catalog application read boundary` |
| Starting worktree | Clean |
| Final worktree | Clean after the single commit; verified post-commit |
| Push/Tag | Not performed |

Final diff size: 25 files changed, 760 insertions, 37 deletions.

## Mandatory consumer discovery

The search covered `listProducts`, `ProductRepository`, direct Drift product
queries, controllers, services, application repositories, and direct UI reads.

| Candidate or group | Current use | Decision |
| --- | --- | --- |
| `core/documents/document_history.dart` | Read-only ID-to-name lookup; includes inactive products; no product writes; only `id` and `name` | **Selected** — isolated application boundary, centrally composed, no UI edit required |
| `core/catalog/product_controller.dart` | Product list plus create, update, and activation writes; public `Product` state used by product UI | Excluded: write- and UI-type-coupled |
| `core/inventory/inventory_controller.dart` | Product list exposed to inventory UI plus stock-write workflow | Excluded: UI construction/type coupling |
| `core/purchases/purchase_controller.dart` | Product list exposed to purchase UI plus purchase writes | Excluded: UI construction/type coupling |
| `core/sales/sale_controller.dart` | Active product list exposed to sales UI plus sale writes | Excluded: UI construction/type coupling |
| `core/inventory/inventory_attention_service.dart` | Read-only `id`, `name`, `isActive`, but constructed directly by dashboard UI and performs its own derived-item ordering | Excluded: migration would require UI source changes |
| `core/dashboard/dashboard_service.dart` | Reads product identity/name for dashboard and is constructed by dashboard UI | Excluded: UI composition coupling |
| `core/reports/report_repository.dart` | Uses unit and the larger product model for costing/valuation summary calculations | Excluded: depends on fields and domain behavior outside the frozen read model |
| `core/inventory_valuation/profitability_activation_service.dart` | Reads IDs but coordinates valuation and audit writes | Excluded: not the safest read-only boundary |
| `core/inventory_valuation/synthetic_profitability_activation_service.dart` | Checks catalog emptiness, then creates products and inventory in a synthetic transaction | Excluded: explicit write boundary |
| `core/inventory/inventory_repository.dart` and `drift_inventory_repository.dart` | Reads products to validate inventory writes and balances | Excluded: repository/write coupling |
| `core/purchases/purchase_repository.dart` and `drift_purchase_repository.dart` | Validates products for purchase writes | Excluded: write coupling |
| `core/sales/sale_repository.dart` | Uses activity and pricing/cost fields to validate sale writes | Excluded: write coupling and extra fields |
| `core/financial_accounts/negative_balance_approval_workflow_service.dart` | Product lookup participates in approval/write workflows and semantic revalidation | Excluded: broader transactional boundary |
| `core/backup/backup_export.dart` | Serializes the complete product domain model | Excluded: frozen model intentionally lacks backup fields |
| `core/backup/backup_restore_service.dart` | Validates emptiness and restores complete product records | Excluded: read/write and backup-format boundary |
| `core/backup/business_data_wipe_service.dart` | Counts products and performs destructive wipe coordination | Excluded: destructive write boundary |
| `features/dashboard/dashboard_screen.dart` and `features/financial_reports/profitability_report_screen.dart` | Direct UI reads of the legacy product repository | Excluded: UI source is explicitly frozen in Phase 105D |
| `core/catalog/drift_product_repository.dart` and `product_repository.dart` | Data sources/contracts rather than application consumers | Excluded: legacy APIs remain intact |

`LocalDocumentHistoryRepository` is the only examined boundary that is
read-only, uses no frozen-model-external field, is testable without the user
database, and can be runtime-wired through one existing composition root with
zero UI source changes.

## Selected boundary migration

### Before

```dart
required ProductRepository productRepository
final ProductRepository _productRepository;

await _productRepository.listProducts(includeInactive: true);
```

The consumer accepted the wide domain repository, which also exposes product
create, update, activation, restore, and wipe operations. It read a
`List<Product>` only to derive a private `Map<String, String>` from product ID
to product name.

### After

```dart
required ProductCatalogReadRepository productCatalogReadRepository
final ProductCatalogReadRepository _productCatalogReadRepository;

await _productCatalogReadRepository.listProductCatalog(
  includeInactive: true,
);
```

The consumer now knows only the frozen read interface. It has no Drift,
SQLite, table, concrete-adapter, SQL filtering, SQL ordering, cloud, or sync
dependency. Its private derived state remains the same ID-to-name map; no
public UI-facing type changed.

### `includeInactive`

The value remains `true`. Document history must resolve names for historical
purchases and sales even after a product becomes inactive. Using active-only
reads would turn valid historical references into the existing unknown-product
fallback and would change established behavior.

### Loading, success, empty, failure, and retry

- Loading remains the single existing `Future<List<DocumentHistoryEntry>>`;
  the repository has no loading flag or notification state to redesign.
- Success preserves ID/name mapping, document filtering, cancellation data,
  linked movements, and existing document-date ordering.
- An empty catalog plus empty document stores returns the same empty history.
- Catalog failures continue to propagate before purchase, sale, or inventory
  reads. The boundary previously had no error absorption or Arabic error state.
- A repeated call is a fresh load. Failure followed by success produces one
  exact history snapshot without caching or duplicates.
- The catalog lookup does not sort the frozen snapshot. The existing sort of
  derived document entries by document timestamp is unrelated and unchanged.

## Runtime composition

`lib/app/app_repositories.dart` is the only composition root modified.

- Production initialization creates
  `DriftProductCatalogReadRepository(database)` and exposes it as
  `ProductCatalogReadRepository`.
- `LocalDocumentHistoryRepository` is rebuilt after the production purchase,
  sale, inventory, and catalog repositories are ready.
- The existing local/default composition uses a private bridge over its local
  product repository to preserve non-production and widget-test behavior.
- No service locator, DI framework, singleton pattern, or database-opening path
  is added or changed.

The Phase 105C architecture guard was advanced from “unwired” to allow exactly
one production reference: `lib/app/app_repositories.dart`. The adapter itself
was not modified.

## Tests

The new Phase 105D test file contains eleven tests covering:

1. construction through `ProductCatalogReadRepository` without a concrete
   adapter;
2. successful ID/name resolution with all five frozen values preserved in the
   supplied immutable model;
3. the required `includeInactive: true` value;
4. empty catalog and empty document stores;
5. existing failure propagation with no downstream reads or side effects;
6. failure followed by a successful retry without cache or duplication;
7. no in-memory reordering inside the catalog lookup;
8. no direct database or concrete adapter dependency in the consumer;
9. zero frozen-contract/adapter dependency in UI sources;
10. the unchanged five-field model and single frozen method; and
11. production composition using the Phase 105C Drift adapter over an isolated
    in-memory database.

Nineteen existing test files that construct the selected repository use one
test-only adapter from `test/support`. This preserves their local product
fixtures without adding any production fake or changing a second consumer.

## File scope

Production files modified:

- `lib/core/documents/document_history.dart` — the single selected consumer.
- `lib/app/app_repositories.dart` — the single composition root.

Tests added:

- `test/phase105d_product_catalog_application_read_boundary_migration_test.dart`
- `test/support/product_catalog_read_repository_test_adapter.dart`

Existing tests modified:

- `test/phase105c_local_drift_product_catalog_read_adapter_test.dart`
- `test/document_history_test.dart`
- `test/phase13_backup_export_test.dart`
- `test/phase14_backup_file_save_test.dart`
- `test/phase15_restore_preview_test.dart`
- `test/phase16_restore_empty_system_test.dart`
- `test/phase17_owner_data_wipe_test.dart`
- `test/phase18_release_candidate_qa_test.dart`
- `test/phase21b_pricing_cost_minimum_ui_acceptance_test.dart`
- `test/phase21c_profit_stock_valuation_reports_test.dart`
- `test/phase21d_end_to_end_business_release_test.dart`
- `test/phase31_functional_recovery_test.dart`
- `test/phase32_pilot_acceptance_test.dart`
- `test/phase37a_opening_balances_test.dart`
- `test/phase39_customer_bound_multi_item_sales_test.dart`
- `test/phase51_real_business_day_simulation_test.dart`
- `test/phase67_navigation_theme_branding_test.dart`
- `test/phase68_business_logo_invoice_windows_icon_test.dart`
- `test/phase81_transaction_financial_backup_contract_test.dart`
- `test/phase95_business_profile_expansion_test.dart`

This report is the only documentation file added.

## Frozen boundaries proved unchanged

- Zero files under `lib/features`, `lib/screens`, or `lib/widgets` are modified.
- `product_catalog_read_repository.dart` is unchanged.
- `drift_product_catalog_read_repository.dart` is unchanged.
- Product schema, generated database code, migration strategy, schema version,
  backup format, legacy repository methods, and write APIs are unchanged.
- `String id`, `String? code`, `GrainUnit unit`, and deterministic adapter
  ordering remain frozen.
- No user database was opened, read, migrated, or modified.

## Verification gates

| Gate | Result |
| --- | --- |
| Phase 105D focused | PASS — 11 passed, 0 failed, 0 skipped; exit 0; 7.4 s wall time |
| Phase 105C adapter regression | PASS — 9 passed, 0 failed, 0 skipped; exit 0; 5.5 s wall time |
| Phase 105B contract regression | PASS — 3 passed, 0 failed, 0 skipped; exit 0; 5.7 s wall time |
| Selected consumer existing tests | PASS — 213 passed, 0 failed, 0 skipped across 19 files; exit 0; 29.3 s wall time |
| Audit Log regression | PASS — 46 passed, 0 failed, 0 skipped; exit 0; 17.1 s wall time |
| Phase 102J isolated | PASS — 5 passed, 0 failed, 0 skipped; exit 0; 10.2 s wall time |
| Phase 102 related regression | PASS — 61 passed, 0 failed, 0 skipped; exit 0; 14.6 s wall time |
| Full suite | PASS — 1971 passed, 0 failed, 1 unchanged historical skip; exit 0; 153.4 s wall time; exactly 11 new passing tests |
| Formatter | PASS — 374 files checked, 0 changed; exit 0; 4.13 s |
| Analyzer | PASS — no issues found; exit 0; 38.6 s analyzer time (42.0 s wall time) |
| Windows release | PASS — exit 0; 72.7 s Flutter build time (74.6 s wall time) |
| `git diff --check` | PASS — exit 0 |
| Native smoke | NOT RUN — production database isolation not proven |

Windows artifact:

- Path: `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes
- SHA-256: `CDFC25866AE913982515388871E9EEBDBE13F1021C0A3A192B760699BFA8A678`

The sole unchanged historical skip remains
`test/phase9a_inflows_outflows_reports_test.dart:552`, which requires negative
balance approval with actual credentials. The release build emitted the
existing Firebase CMake minimum-version deprecation and `.voltbl` linker
warnings; neither prevented artifact creation. `git diff --check` also emitted
line-ending normalization notices but returned exit 0.

Native smoke was not run because production database isolation was not proven.
No user database was opened, read, migrated, or modified.

## Proposed Phase 105E boundary

Phase 105E is not implemented here. Because genuine production composition is
now present while legacy product reads remain elsewhere, the proposed next
atomic scope is:

> **Phase 105E — Prove Genuine Runtime Product Catalog Read Integration**

It should not introduce cloud, mobile UI, synchronization, or broad legacy
retirement.
