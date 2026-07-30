# Phase 106A — Discover and Freeze the Second Product Read Consumer Migration Target

## 1. Outcome

**Outcome A — FULL SUCCESS**

Discovery identified and froze one second executable consumer without
migrating it. Phase 106A changes documentation and structural acceptance tests
only.

## 2. Baseline and Branch

| Item | Value |
| --- | --- |
| Governing baseline | `a813a70d5a41e272046f320387572022797e8fd4` |
| Actual baseline subject | `PHASE 105F: accept and freeze product catalog read boundary pilot` |
| Branch | `codex/phase-106a-discover-freeze-second-product-read-consumer-target` |
| Required commit message | `PHASE 106A: discover and freeze second product read consumer target` |

The starting worktree was clean, `HEAD` equaled the governing baseline,
`git diff --check` passed, and there were zero commits after the baseline.

## 3. Scope

This phase performs discovery, selection, scope freeze, and acceptance-contract
freeze. It selects one second consumer. It does not migrate that consumer,
change production code, or begin Phase 106B.

## 4. Governing Constraints

- No file under `lib/` may change.
- The Phase 105F contract, adapter, selected consumer, and composition remain
  frozen.
- No schema or migration changes are allowed.
- No UI redesign, cloud transport, sync, write-path refactor, or legacy
  deletion is allowed.
- Phase 106B is limited to one consumer only.
- No production or user database may be opened for discovery.

## 5. Frozen Phase 105F Reference

The accepted pilot remains:

```text
LocalDocumentHistoryRepository
→ ProductCatalogReadRepository
→ DriftProductCatalogReadRepository
→ Drift / SQLite products table
```

`LocalDocumentHistoryRepository` is excluded from second-consumer selection
because it is already migrated, runtime-proved, accepted, and frozen. Its
source and the Phase 105F contract, Drift adapter, and `AppRepositories`
composition are byte-for-byte unchanged from the baseline.

## 6. Discovery Method

Discovery combined four forms of evidence:

1. Repository-wide searches for product read method names, `ProductRepository`,
   `Product`, database tables, `select`, and Drift access.
2. A complete enumeration of production files containing executable
   `.listProducts(` calls.
3. Manual tracing from screens/tools through controllers or services to
   `AppRepositories`, `DriftProductRepository`, and the `products` table.
4. Inspection of required model fields, active/inactive semantics, ordering,
   read/write coupling, transactions, financial risk, and existing tests.

Generated Drift code and test-only files were searched for evidence but were
not treated as migration candidates.

## 7. Definition of a Product Read Consumer

A production component is included when it directly invokes a product read or
receives the resulting persistence-domain `Product` values for executable
logic. Repository contracts, concrete data sources, generated code, and the
Phase 105F bridge are infrastructure rather than application-consumer targets.

Every application consumer ultimately reaches production storage through:

```text
AppRepositories.productRepository
→ ProductDataRepository
→ DriftProductRepository
→ FoundationDatabase.products
→ Drift / SQLite
```

The only direct `products` table readers are the legacy
`DriftProductRepository` and the already frozen
`DriftProductCatalogReadRepository`.

## 8. Complete Candidate Inventory

The audit found 23 production files containing `.listProducts(`. Three are
infrastructure and 20 are executable consumer files.

Infrastructure, not candidates:

- `lib/app/app_repositories.dart` — composition plus the local legacy bridge.
- `lib/core/catalog/product_repository.dart` — contract and in-memory data
  source.
- `lib/core/catalog/drift_product_repository.dart` — concrete Drift data
  source and direct table reader.

Executable consumers:

| Component | File | Entry and role | Read shape / fields | Activity / order | Write or financial coupling | Expected migration size | Fit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `DashboardGuidanceState.load` | `lib/features/dashboard/dashboard_screen.dart` | Protected owner dashboard guidance; counts master data, movements, and sales | One-shot list; uses product count only | Includes inactive; no ordering dependency | None; read-only UI guidance | 1 production file | Excellent |
| `InventoryAttentionService` | `lib/core/inventory/inventory_attention_service.dart` | Dashboard alerts and AI inventory-attention tool | One-shot list; `id`, `name`, `isActive` | Includes inactive; service sorts derived alerts | Read-only; reads inventory balances | Service plus 3 wiring sites | Excellent but larger |
| `DashboardService` | `lib/core/dashboard/dashboard_service.dart` | `DashboardController` financial/stock summary | One-shot; product `id`, `name`, emptiness | Includes inactive; wheat-name lookup | Financial dashboard aggregation and nested attention service | 2+ consumers/wiring changes | Good fields, unsafe atomicity |
| `ProductController` | `lib/core/catalog/product_controller.dart` | `ProductsScreen` catalog management | Full `Product` list, permission-dependent | Active-only or all | Same dependency creates, updates, activates | Controller/UI split required | Excluded |
| `InventoryController` | `lib/core/inventory/inventory_controller.dart` | Inventory, stocktake, adjustment screens | Full `Product` list | Active-only or all; exposed to 3 screens | Creates movements, valuation and audit effects | Broad multi-screen scope | Excluded |
| `PurchaseController` | `lib/core/purchases/purchase_controller.dart` | Purchase and supplier-purchase screens | Full `Product` list for display/selection | Permission-dependent inactive inclusion | Creates/cancels posted purchase documents | Financial/inventory workflow | Excluded |
| `SaleController` | `lib/core/sales/sale_controller.dart` | Sales screen | Active `Product` list plus stock | Active only | Creates/cancels sales and financial entries | Large transaction/UI scope | Excluded |
| `LocalInventoryRepository` | `lib/core/inventory/inventory_repository.dart` | Inventory validation and movement writes | Single-product lookup implemented as full list scan | Includes inactive for validation | Inventory-ledger writes | Repository redesign risk | Excluded |
| `DriftInventoryRepository` | `lib/core/inventory/drift_inventory_repository.dart` | Durable inventory validation and writes | List scan for product existence/activity | Active or all depending operation | Durable inventory writes | Paired repository migration | Excluded |
| `LocalPurchaseRepository` | `lib/core/purchases/purchase_repository.dart` | Purchase validation | Single-product validation via full list | Includes inactive then checks activity | Purchase, stock, accounts, audit | Atomic financial path | Excluded |
| `DriftPurchaseRepository` | `lib/core/purchases/drift_purchase_repository.dart` | Durable purchase validation | Single-product list scan | Includes inactive | Durable purchase and inventory posting | Atomic financial path | Excluded |
| `LocalSaleRepository` | `lib/core/sales/sale_repository.dart` | Sale validation | Full product map; uses pricing/cost fields | Includes inactive then validates | Sale, COGS, stock and money | Frozen model lacks required fields | Excluded |
| `LocalReportRepository` | `lib/core/reports/report_repository.dart` | Reports screen daily activity report | Full list; `id`, `name`, `unit`, reference cost | Includes inactive; report ordering/aggregation | Cost, profit, stock valuation calculations | Requires model expansion | Excluded |
| `ProfitabilityActivationService` | `lib/core/inventory_valuation/profitability_activation_service.dart` | Owner profitability activation | IDs and complete catalog cardinality | Includes inactive | Valuation and audit transaction | Financial activation path | Excluded |
| `SyntheticProfitabilityActivationService` | `lib/core/inventory_valuation/synthetic_profitability_activation_service.dart` | Isolated Phase 102J tool only | Catalog emptiness then full product creation | Includes inactive | Explicit synthetic writes | Not production-wired | Excluded/dead for production |
| `NegativeBalanceApprovalWorkflowService` | `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | Approval request execution/revalidation | Single product found by full list | Includes inactive | Financial approval and posting | High semantic risk | Excluded |
| `BackupExportService` | `lib/core/backup/backup_export.dart` | Backup export screen | Complete `Product` serialization | Includes inactive; stable snapshot | Reads all business data | Frozen model omits prices, notes, timestamps | Excluded |
| `BackupRestoreService` | `lib/core/backup/backup_restore_service.dart` | Restore preview/execute | Emptiness read plus full restore model | Includes inactive | Atomic multi-repository restore writes | Backup-format boundary | Excluded |
| `BusinessDataWipeService` | `lib/core/backup/business_data_wipe_service.dart` | Owner wipe screen | Count before backup-and-wipe | Includes inactive | Destructive transaction | Safety-critical write path | Excluded |
| `ProfitabilityReportScreen._activate` | `lib/features/financial_reports/profitability_report_screen.dart` | Activation dialog | Full `Product` values supplied to UI | Includes inactive | Feeds valuation activation | UI plus financial workflow | Excluded |

Downstream screens that receive `Product` from the listed controllers are part
of those boundaries: products, purchases, sales, inventory, stocktake, stock
adjustment, and profitability UI. They are not separate atomic candidates
because migrating them independently would leave their controller read path
unchanged.

## 9. Candidate Runtime Paths

Important current call chains are:

```text
DashboardScreen.didChangeDependencies
→ DashboardGuidanceState.load
→ AppRepositories.productRepository.listProducts(includeInactive: true)
→ DriftProductRepository
→ Drift / SQLite products table
```

```text
DashboardScreen / OwnerAlertData / InventoryAttentionTool
→ InventoryAttentionService.loadAttention
→ ProductRepository.listProducts(includeInactive: true)
→ DriftProductRepository
→ Drift / SQLite products table
```

```text
DashboardScreen
→ DashboardController
→ DashboardService.load
→ ProductRepository.listProducts(includeInactive: true)
→ DriftProductRepository
→ Drift / SQLite products table
```

Controller and repository candidates follow the same legacy repository but
continue into write, ledger, backup, valuation, or financial workflows as
recorded in the inventory.

## 10. Candidate Comparison Matrix

| Rank | Candidate | Current read path | Read shape | Contract fit | Migration size | Risk | Mobile/cloud value | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `DashboardGuidanceState.load` | Dashboard → AppRepositories legacy product read | Count of one-shot all-product list | Exact; no extra fields or ordering | 1 production file | Very low | Removes wide write-capable repository from a shared Flutter UI read | Selected |
| 2 | `InventoryAttentionService` | Dashboard/AI → service → legacy product read | `id`, `name`, `isActive` plus balances | Exact | 4 production files due wiring | Low | Strong reusable domain boundary | Closest reserve |
| 3 | `DashboardService` | Dashboard controller → service → legacy read | `id`, `name`, emptiness | Field fit, but nested second consumer | 2+ consumers | Medium; financial summary | Useful but violates one-consumer atomicity | Defer |
| 4 | `ProductController` | Products screen → controller → legacy read/write repo | Full editable products | Read fields fit; dependency also writes | Several files | Medium | High | Defer pending read/write split |
| 5 | `LocalReportRepository` | Reports screen → report repository → legacy read | Unit and cost valuation | Frozen model lacks reference cost | Contract change would be required | High financial | High | Exclude |
| 6 | Purchase/sale/inventory controllers and repositories | Screens → transactional components → legacy read | Selection and validation | Some fields fit | Multi-file | High posting/ledger risk | High | Exclude |
| 7 | Backup/restore/wipe and approval/activation | Owner workflows → wide repository | Complete model or validation | Partial or incompatible | Broad | Critical | Low for this pilot | Exclude |

## 11. Excluded Candidates

- `LocalDocumentHistoryRepository` is excluded because Phase 105F already
  accepted it.
- `InventoryAttentionService` is not chosen because changing its constructor
  requires updates in `dashboard_service.dart`, `dashboard_alerts_section.dart`,
  and dashboard composition in addition to the service. It remains the nearest
  reserve.
- `DashboardService` embeds both its own product read and construction of
  `InventoryAttentionService`; migrating it atomically would either leave a
  broad bypass or migrate two consumers.
- Product, purchase, sale, and inventory controllers combine reads with writes
  and expose full persistence-domain models to multiple screens.
- Inventory, purchase, and sale repositories use product reads for validation
  inside inventory or financial transactions.
- Reports require reference-cost fields not present in the frozen read model.
- Backup/export/restore/wipe require full product persistence data or perform
  destructive writes.
- Profitability and approval flows are financially sensitive transactions.
- The synthetic activation service is deliberately not production-wired, so
  it cannot be selected as a real second production consumer.

## 12. Selected Second Consumer

Selected second product read consumer: DashboardGuidanceState.load

The component exists in
`lib/features/dashboard/dashboard_screen.dart:254` and is reached by the
default protected-owner dashboard path at line 68. Tests can inject an
alternative loader, but production invokes this static method when no test or
caller override is supplied.

## 13. Selection Rationale

The selected read is useful, not merely syntactically easy: it controls the
first-run/daily guidance shown on the owner dashboard and currently couples a
shared Flutter UI feature to a repository that also exposes product writes.
It is the smallest safe removal of that wide dependency.

It reads once, needs only total catalog cardinality, deliberately includes
inactive records, does not inspect order, performs no product write, performs
no transaction, and does not affect posted sales, purchases, COGS, valuation,
or inventory ledger state. The existing frozen contract is strictly sufficient.

## 14. Current Runtime Read Path

Current runtime path:

```text
DashboardScreen.didChangeDependencies
→ DashboardGuidanceState.load
→ AppRepositories.productRepository
→ ProductDataRepository / DriftProductRepository
→ FoundationDatabase.products
→ Drift / SQLite products table
```

Current semantics: `listProducts(includeInactive: true)`, one `Future` read,
no ordering dependency, and only `products.length` is consumed.

## 15. Future Target Runtime Read Path

Target runtime path for the future migration:

```text
DashboardScreen.didChangeDependencies
→ DashboardGuidanceState.load
→ AppRepositories.productCatalogReadRepository
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ DriftProductCatalogReadRepository
→ Drift / SQLite products table
```

This is a future Phase 106B target only. Phase 106A leaves the current legacy
call intact as proof that migration has not started.

## 16. Frozen Contract Compatibility

The target needs no model extension. `ProductCatalogReadModel` remains:

```text
String id
String name
String? code
GrainUnit unit
bool isActive
```

The selected consumer only uses the list length. It preserves
`includeInactive: true` so product-count guidance retains its exact current
meaning. `String id`, nullable code, and `GrainUnit unit` remain unchanged even
though this consumer does not inspect them. No stream, search, aggregate,
join, schema, or new repository operation is proposed.

## 17. Risks and Mitigations

| Risk | Mitigation frozen for Phase 106B |
| --- | --- |
| Accidentally counting active products only | Behavioral test must include an inactive product and retain the total count |
| UI text or guidance transition changes | Existing Phase 12 and dashboard tests remain unchanged and green |
| Replacing one service-locator call with a concrete adapter | Only `AppRepositories.productCatalogReadRepository` may be used |
| Fake-only proof | Add an in-memory Drift runtime test through production composition |
| Expanding into dashboard financial reads | Change only the product-count subread; movements and sales remain untouched |
| Migrating the reserve candidate too | Guards forbid changes to inventory-attention and dashboard-service files |

## 18. Phase 106B In Scope

- `DashboardGuidanceState.load` only.
- Replace its legacy product list call with
  `AppRepositories.productCatalogReadRepository.listProductCatalog`.
- Preserve `includeInactive: true`, one-shot behavior, product count, guidance
  states, and existing movement/sale reads.
- Add a focused dependency-boundary test and a real in-memory Drift composition
  test.
- Run existing Phase 12/dashboard and Product Catalog boundary regressions.

## 19. Phase 106B Out of Scope

- Any third consumer or `InventoryAttentionService` migration.
- `DashboardService`, dashboard alerts, product controllers, or transactional
  repositories.
- Contract or adapter changes.
- Product model, schema, migration, generated-code, backup-format, or database
  changes.
- UI redesign, mobile redesign, cloud transport, sync, or offline work.
- Product writes, legacy-surface retirement, financial calculations, COGS,
  valuation, inventory ledger, purchase, sale, or return behavior.
- Unrelated refactors.

## 20. Phase 106B Acceptance Contract

Phase 106B must satisfy all of the following:

1. `DashboardGuidanceState.load` uses the frozen catalog read boundary for its
   product count.
2. It does not call `ProductRepository.listProducts` or
   `AppRepositories.productRepository`.
3. It does not import or construct `DriftProductCatalogReadRepository`.
4. It does not import `FoundationDatabase`, Drift, or SQLite types.
5. It performs no direct `products` query.
6. It depends on the existing `ProductCatalogReadRepository` exposure only.
7. It consumes no persistence-domain `Product` value.
8. `includeInactive: true` is preserved exactly.
9. Active plus inactive rows both contribute to `productCount`.
10. Empty catalog behavior remains `productCount == 0`.
11. The one-shot `Future` behavior remains unchanged.
12. Product ordering does not influence the count.
13. `String id`, `GrainUnit`, and null `code` remain untouched in the contract.
14. No silent unit fallback is added anywhere.
15. Movement and sale reads and counts remain unchanged.
16. Dashboard guidance text and state transitions remain unchanged.
17. Existing composition supplies the real frozen Drift adapter.
18. An isolated in-memory runtime test proves the real path, not a fake alone.
19. No product-read bypass remains in the selected method.
20. Existing Phase 12/dashboard tests and the full regression suite pass.

## 21. Files Expected to Change in Phase 106B

Production:

- `lib/features/dashboard/dashboard_screen.dart` — only the product-count read
  inside `DashboardGuidanceState.load`.

Tests/documentation expected:

- A new focused Phase 106B migration/runtime test.
- A Phase 106B report.
- Existing tests are run, not weakened; only a strictly necessary constructor
  or fixture adjustment may be considered if the real implementation requires
  it, which is not currently expected.

No `AppRepositories` production change is expected because the frozen getter
and Drift production wiring already exist.

## 22. Files Forbidden from Change in Phase 106B

- `lib/core/catalog/product_catalog_read_repository.dart`
- `lib/core/catalog/drift_product_catalog_read_repository.dart`
- `lib/core/documents/document_history.dart`
- `lib/app/app_repositories.dart`
- `lib/core/inventory/inventory_attention_service.dart`
- `lib/core/dashboard/dashboard_service.dart`
- All product write repositories and controllers.
- All persistence schema, migration, generated database, backup-format, and
  platform files.
- Every unrelated UI file.

## 23. Test Evidence

Phase 106A adds
`test/phase106a_second_product_read_consumer_target_discovery_freeze_test.dart`.
It proves the baseline snapshot, full executable `.listProducts` inventory,
single selection, live production call chain, intentional pre-migration state,
zero production diff, frozen files, and all report/scope/acceptance sections.

Relevant existing selected-consumer tests are:

- `test/phase12_help_guidance_test.dart`
- `test/competition04_dashboard_readiness_test.dart`

Phase 105B–105F and the Audit Log acceptance tests remain regression gates.

## 24. Production Code Diff Evidence

`git diff a813a70d5a41e272046f320387572022797e8fd4 --name-only -- lib`
returns no paths. No production file, generated file, schema, migration,
platform file, or existing test is changed by Phase 106A.

## 25. Database Safety

Discovery used source, tests, documentation, and Git history only. Automated
regressions use their existing isolated stores. Native smoke is not run because
production database isolation for a native launch is not proven.

Native smoke not run because production database isolation was not proven.
The user production database was not opened, read, copied, or modified.

## 26. Verification Results

| Gate | Executed result |
| --- | --- |
| Phase 106A focused | PASS — 7 passed, 0 failed, 0 skipped |
| Phase 105F | PASS — 6 passed, 0 failed, 0 skipped |
| Phase 105E | PASS — 8 passed, 0 failed, 0 skipped |
| Phase 105D | PASS — 11 passed, 0 failed, 0 skipped |
| Phase 105C | PASS — 9 passed, 0 failed, 0 skipped |
| Phase 105B | PASS — 3 passed, 0 failed, 0 skipped |
| Selected dashboard consumer | PASS — 10 passed across `phase12_help_guidance_test.dart` and `competition04_dashboard_readiness_test.dart` |
| Audit Log reference boundary | PASS — 46 passed across 8 files, 0 failed, 0 skipped |
| Full suite | PASS — 1992 passed, 0 failed, 1 unchanged historical skip; 316.4 s wall time |
| Formatter | PASS — 379 Dart files checked, 0 changed; 7.73 s |
| Analyzer | PASS — no issues found; 172.7 s |
| Windows release | PASS — 44.7 s Flutter build time; exit 0 |
| Native smoke | NOT RUN — production database isolation for native launch was not proven |
| Production diff | PASS — no path under `lib/` |
| `git diff --check` | PASS — exit 0; only existing line-ending notices were emitted |

The sole historical skip remains the baseline skip in
`test/phase9a_inflows_outflows_reports_test.dart`; Phase 106A adds no skip. The
Windows build emitted the existing non-fatal Firebase CMake minimum-version
deprecation and `.voltbl` linker warnings.

Windows release artifact:

- Path:
  `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes.
- SHA-256:
  `D6237998B8B9E059B2F2F091E2BEA6AF5A457ED0AF6A34FD17783F72F42C5FED`.

## 27. Git Evidence

| Item | Value |
| --- | --- |
| Baseline | `a813a70d5a41e272046f320387572022797e8fd4` |
| Final commit | The single Phase 106A commit; its hash is recorded in the final handoff because a commit cannot contain itself |
| Files | This report and one new structural acceptance test only |
| Diff stat | 2 files changed, 720 insertions, 0 deletions |
| Production diff | Empty |
| Commit count | Exactly one after baseline |
| Push | Not performed |
| Tag | Not created |

## 28. Final Decision

`DashboardGuidanceState.load` is frozen as the only second product-read
consumer target. `InventoryAttentionService` is the closest reserve but is not
authorized for Phase 106B. No migration is implemented in Phase 106A.

## 29. Proposed Next Phase Only

**Phase 106B — Migrate DashboardGuidanceState.load to the Frozen Product Catalog Read Contract**
