# Phase 105A — Select and Freeze the First Cloud/Mobile Repository Target

## 1. Outcome and repository state

**Outcome A — FULL SUCCESS: FIRST CLOUD/MOBILE REPOSITORY TARGET SELECTED AND FROZEN**

| Item | Value |
| --- | --- |
| Branch | `codex/phase-105a-select-freeze-first-cloud-mobile-repository-target` |
| Starting HEAD | `feec6aa24d44c05b81ee7b3195b0268b05f11dbe` |
| Final HEAD | The single Phase 105A commit; recorded in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 105A: select and freeze first cloud mobile repository target` |
| Starting worktree | Clean |
| Final worktree | Clean after the single commit; verified by post-commit status |
| Push/Tag | Not performed |
| Production code | Not changed |
| Schema or migrations | Not changed |
| Cloud or backend implementation | Not started |
| Mobile UI implementation | Not started |

Files added:

- `docs/PHASE-105A-SELECT-FREEZE-FIRST-CLOUD-MOBILE-REPOSITORY-TARGET.md`
- `docs/PHASE-105A-FIRST-CLOUD-MOBILE-REPOSITORY-TARGET-FREEZE.md`

Final diff size: `666 additions, 0 deletions`. No Dart file, generated file,
`pubspec.yaml`, schema, migration, controller, screen, adapter, or business
logic file changed. This is a documentation/architecture-only phase; no new
test was justified because a source-string test would only duplicate the
documented discovery and would be brittle.

## 2. Governing baseline and Phase 104J closure

The required repository root, branch, commit object, `HEAD`, clean worktree,
and pre-work `git diff --check` were verified before the Phase 105A branch was
created. The branch starts directly at
`feec6aa24d44c05b81ee7b3195b0268b05f11dbe`, whose message is
`PHASE 104J: accept and close audit log repository boundary pilot`.

Phase 104J accepted and closed the Audit Log read pilot with this production
chain:

`AuditLogsScreen → AuditLogController → AuditLogReadRepository → DriftAuditLogRepository → Drift/SQLite`

That pilot froze a presentation-only read model, a `Future` snapshot contract,
controlled failure/retry/cache states, composition-root ownership, a local
Drift adapter, and no presentation dependency on persistence entities. It is a
reference pattern, not permission for a bulk migration. Audit Log is therefore
not reconsidered as the Phase 105A target.

## 3. Discovery method and architectural observations

The audit covered `lib/`, `test/`, `docs/`, `main.dart`, routes, the application
composition root, controllers, screens, repository contracts, local and Drift
implementations, the Drift schema, and current tests. The executable paths were
traced rather than inferred from filenames.

Important findings:

1. `main()` awaits `AppRepositories.initializeProduction()` before `runApp`.
2. `AppRepositories.initializeProduction()` owns the shared
   `FoundationDatabase` and binds the durable Drift repositories.
3. Feature screens and controllers do not import Drift or
   `FoundationDatabase`; the direct database reads found in the reviewed paths
   are inside Drift adapters.
4. Most existing domain repositories combine reads, writes, backup/restore,
   wipe, and local transaction-snapshot responsibilities.
5. Existing controllers generally expose domain models, not dedicated read
   models. Several controllers also combine list reads with financial or stock
   writes.
6. `firebase_core` and a defensive bootstrap already exist, but
   `firebase_options.dart` deliberately throws `UnsupportedError`; there is no
   active cloud database, remote auth, sync repository, API, or backend. Phase
   105A did not add or configure any provider.
7. No pagination or repository-side catalog search exists. The product table
   has an optional `code`, not a field whose semantics are proven to be a
   barcode.

Current production call-site measurements in `lib/`:

| Read operation | Occurrences | Production files |
| --- | ---: | ---: |
| `listProducts()` | 28 | 23 |
| `listCustomers()` | 16 | 12 |
| `listSuppliers()` | 19 | 15 |
| `listSales()` | 16 | 11 |
| `listExpenses()` | 11 | 9 |
| `listHistory()` | 6 | 5 |
| `listAccounts()` | 38 | 25 |
| `listAllMovements()` | 12 | 10 |

The wide `listProducts()` footprint is not a reason to migrate all consumers.
It is the reason to introduce a new, consumer-specific read boundary and move
one consumer at a time while the existing write/data repository remains
unchanged.

## 4. Repository Read Surface Inventory

Query counts are estimates of the principal calls for one screen/controller
load; downstream local implementations can perform additional lookups.

| Domain | Screen(s) | Controller/service | Current source / UI model | Contract | Principal reads | R/W | Financial / stock impact | Sensitivity | Mobile value | Coupling / testability | First target? |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| Product master | Product, purchase/inventory/sale selectors, dashboard/report helpers | `ProductController`, plus product list fields in several controllers | `ProductRepository.listProducts` → domain `Product`; Drift maps one `Products` table | Mixed read/write | 1 | Mixed contract; selected projection is read-only | Low if pricing, valuation, and quantity are excluded / none | Low | High | Current contract high footprint; selected projection low and SQLite-testable | **Yes** |
| Inventory/availability | Inventory, stocktake, adjustment report, dashboard | `InventoryController`, attention/dashboard services | `InventoryRepository`, product repository, movements and valuation models | Mixed | 3–5+ | Mixed | Valuation can be financial / stock is high | Medium | High | High: movements, balances, activation and writes | No |
| Customers | Customers, sales, advances | `CustomerController` | customer plus customer-account and financial models | Mixed | 3+ | Mixed | Balances/collections are high | High | Medium | High: customer ledger and sales; good tests but broad | No |
| Suppliers | Suppliers, purchases, advances | `SupplierController` | supplier plus supplier-account and financial models | Mixed | 3+ | Mixed | Payables/payments are high | High | Medium | High: purchase and payable workflows | No |
| Sales | Sales | `SaleController` | sales, products, stock, customers, accounts | Mixed | 5+ | Mixed | Critical accounting, COGS, profitability / stock | High | Medium | Very high cross-repository transaction surface | No |
| Purchases | Purchases | `PurchaseController` | intakes, suppliers, products and financial accounts in the screen | Mixed | 3+ | Mixed | Critical payable, valuation and stock effects | High | Medium | Very high write workflow; only its product-selector subread is a later consumer | No |
| Expenses | Expenses | `ExpenseController` | expense records plus account lookups in the screen | Mixed | 1–3+ | Mixed | High: postings and balances | High | Medium | High financial coupling | No |
| Financial accounts/ledger | Account and report screens | `FinancialAccountController` and report services | accounts, entries, transfers, closings and balances | Mixed | Many | Mixed | Critical | Very high | Medium | Very high and security-sensitive | No |
| Dashboard | Dashboard and alerts | `DashboardController` / `DashboardService` | dedicated `DashboardData`, computed from many repositories | Read-only aggregation | 9+ | Read-only computation | High financial and stock exposure | High | High | Very high fan-in; difficult first parity surface | No |
| Users/auth | Login/setup/auth gate | `AuthController` | `AuthRepository` / `AppUser`; Drift uses credential records and raw SQL | Mixed session/auth | Several | Mixed | None directly | **Critical** passwords/session/roles | High | Security and provider-decision coupling | No |
| Settings/business identity | Settings and shell header | theme/business-identity controllers and local file repositories | device files and business identity model | Partial | 1–2 | Mixed | Low | Medium | Low–medium | Platform/file lifecycle, not the best cloud data pilot | No |
| Document history | Document history | `DocumentHistoryController` / local aggregate repository | purchase + sale + product + movement domain models | Read-only contract | 4 | Read-only | High financial/document content and stock evidence | High | Medium | High multi-repository aggregation | No |
| Reports | Reports/financial reports | report controllers and services | many repository/domain models | Partial | Many | Read-only computation | Critical | High | High | Very high aggregation and parity burden | No |

No reviewed feature screen or controller directly selects Drift tables. The
problem is not a UI-to-SQL bypass; it is that broad domain models and mixed
repositories currently cross the presentation boundary.

## 5. Candidate comparison

Scores are 1 (poor/high risk) to 5 (strong/low risk). “Financial safety” and
“data safety” score higher when risk is lower.

| Candidate | Financial safety | Clear atomic read | Mobile value | Low coupling | Verifiability | Data safety | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| **Product Master Catalog Read** | 5 | 5 | 5 | 4 | 5 | 5 | **Selected** |
| Product Availability Read | 3 | 3 | 5 | 2 | 4 | 4 | Reject now: balance derives from movements and touches stock semantics |
| Product Pricing Read | 2 | 4 | 4 | 2 | 4 | 2 | Reject now: minimum/default price and reference cost affect sale/profitability decisions |
| Customer Directory Read | 3 | 4 | 4 | 2 | 4 | 2 | Reject now: current controller/screen couples identity to balances and collections |
| Supplier Directory Read | 3 | 4 | 4 | 2 | 4 | 2 | Reject now: current controller/screen couples identity to payables and payments |
| Document History Read | 2 | 3 | 3 | 1 | 3 | 2 | Reject: four repositories and financial/cancellation detail |
| Dashboard Read | 1 | 2 | 5 | 1 | 2 | 2 | Reject: high fan-in, balances, stock and daily finance calculations |
| Settings Read | 5 | 3 | 2 | 3 | 4 | 3 | Reject: local device/file concern with weak first cloud value |
| Users/Employees Read | 4 | 3 | 5 | 2 | 3 | 1 | Reject: credentials, roles, permissions and session ownership |
| Sales/Expense/Account reads | 1 | 2 | 4 | 1 | 3 | 1 | Reject: financial and accounting critical |

## 6. Selected target

### Decision

The one selected target is **Product Master Catalog Read**, represented by the
future `ProductCatalogReadRepository` contract.

This is intentionally narrower than the current `ProductRepository` and the
current `Product` domain object. It is not inventory availability and it is not
product pricing.

### Why it won

- The local source is one `Products` table and one ordered select.
- The selected fields are reference data used by multiple product selectors.
- Reading them neither writes a financial record nor moves stock.
- The projection excludes every monetary field and every quantity/valuation
  field, so it does not expose cost, minimum price, COGS, profitability, or
  customer/supplier data.
- It has direct future mobile value for listing and selecting a product.
- A fake, local Drift adapter, controller states, widget rendering, production
  composition, mapping fidelity, and retry replacement can all be tested in
  isolation.
- The 28/23 footprint can be migrated one consumer at a time; it must not be
  treated as a bulk migration.

### Rejected alternatives

- **Product Availability:** quantity is not a `Product` column. It is computed
  by `InventoryRepository` from stock movements, with valuation/activation
  concerns in adjacent paths.
- **Product Pricing:** default sale price, minimum sale price, and reference
  cost are persisted on the product row but participate in pricing enforcement
  and profitability-related behavior. They require a separate authorization
  and disclosure decision.
- **Customers and suppliers:** identity lists look simple at the adapter, but
  their current screens/controllers load balances, advances, collections,
  payables, payments, and financial accounts.
- **Sales, purchases, expenses, accounts and reports:** these are financial or
  stock-changing/aggregating paths.
- **Dashboard and document history:** both fan into several repositories and
  expose financial or cancellation data.
- **Users:** first-cloud value does not justify credential, role, permission,
  and session risk.
- **Settings:** safe but mostly device/file-local and less valuable as the first
  functional cloud/mobile repository.

## 7. Current selected execution path and coupling

Current production product-master list path:

`screen/controller/service → AppRepositories.productRepository → ProductRepository.listProducts() → DriftProductRepository.listProducts() → FoundationDatabase.Products → Product`

The direct Drift read is confined to
`lib/core/catalog/drift_product_repository.dart`: it selects
`_database.products`, optionally filters `isActive`, orders by `createdAt ASC`
then `id ASC`, executes `get()`, and maps every row to the broad domain
`Product`.

Relevant current consumers include:

- `ProductsScreen` through `ProductController`;
- `PurchaseController`, `InventoryController`, and `SaleController`;
- dashboard and inventory-attention services;
- document history and reports;
- purchase/sale/inventory validation;
- backup, restore, wipe, transaction snapshots, and profitability services.

Current coupling points:

1. `ProductRepository` combines `listProducts` with create, update, activate,
   restore, wipe, and transaction snapshot responsibilities.
2. `Product` combines master fields with default/minimum sale prices,
   reference cost, notes, and persistence lifecycle timestamps.
3. `ProductsScreen` displays pricing/cost and performs writes, so it is not the
   first consumer of the narrow master projection.
4. `SaleController` and `SalesScreen` need pricing and availability as separate
   concerns and are expressly outside the first migration.
5. Inventory and purchase flows use product identity but retain their existing
   write repositories; only a later, separately tested selector read may use
   the new boundary.

The first intended consumer after local contract/adapter proof is the
product-selector subread in `PurchaseController`/`PurchasesScreen`, because
that surface consumes only `id`, `name`, and `isActive`. The migration must not
touch purchase creation, cancellation, payment, inventory, supplier, approval,
or financial-account behavior.

## 8. Frozen scope for Phase 105B and the local pilot

### In scope

- A persistence-independent `ProductCatalogReadModel`.
- A small `ProductCatalogReadRepository` interface.
- Listing a snapshot of product master records.
- Required filtering of active-only versus include-inactive records.
- Stable ordering, empty results, controlled initial failure, refresh failure,
  retry replacement, and lifecycle ownership.
- A fake repository in tests.
- A local Drift adapter in a later phase.
- One controller subread and one product-selector UI consumer in later,
  independent phases.
- A future cloud adapter only after the local boundary is accepted.

### Out of scope

- Create, update, activate/deactivate, delete, restore, wipe, or any write.
- Product notes or lifecycle timestamps in presentation.
- Default sale price, minimum sale price, reference cost, valuation, COGS,
  profitability, or any other monetary field.
- Quantity, availability, stock movements, opening stock, stocktake,
  adjustments, purchase, sale, return, cancellation, or document history.
- Repository pagination, generic filters, generic query language, realtime
  streams, synchronization, conflict resolution, offline writes, or cache
  persistence.
- Authentication, authorization redesign, tenant/warehouse/device scope, cloud
  provider selection, backend IDs, network DTOs, sync metadata, or tokens.
- Any responsive/mobile UI, navigation, Android/iOS setup, barcode scanner, or
  camera work.
- Treating `code` as a barcode before that business rule is proven.

## 9. Proposed read model

Documentation-only proposal for Phase 105B:

```dart
final class ProductCatalogReadModel {
  const ProductCatalogReadModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.isActive,
    this.code,
  });

  final String id;
  final String name;
  final String? code;
  final GrainUnit unit;
  final bool isActive;
}
```

| Field | Type/nullability | Meaning and unit | Identity/category | Reason included |
| --- | --- | --- | --- | --- |
| `id` | required `String`, trimmed/non-empty | Opaque application product ID | Internal stable identity; not a backend ID | Selection keys and stable mapping |
| `name` | required `String`, trimmed/non-empty | Display name, Unicode/Arabic preserved | Business reference text | Every current selector displays it |
| `code` | nullable `String`; blank maps to `null` | Optional business code; **not frozen as barcode** | Optional business identity | Current product master stores/displays it and it is useful for future selection |
| `unit` | required `GrainUnit` | `kilogram` or `ton`; no quantity attached | Domain value, independent of Drift wire string | Reference/display semantics without stock |
| `isActive` | required `bool` | Active/inactive master state | Reference status | Current permission-based list behavior |

Deliberately excluded: all three price/cost fields, notes, created/updated
timestamps, normalized database columns, quantity/balance, valuation, COGS,
profitability, stock movement IDs, tenant/sync/version metadata, backend IDs,
and every Drift row/type. No field is included merely because it exists in the
table.

## 10. Proposed repository contract

Documentation-only proposal for Phase 105B:

```dart
abstract interface class ProductCatalogReadRepository {
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  });
}
```

One operation is sufficient for the current proven selector need. It has no
backend, transport, auth-token, pagination, cache, sync, or provider type.

## 11. Frozen semantics

1. **Snapshot type:** `Future`, not `Stream`. The current UI performs explicit
   loads; realtime is not required. This minimizes lifecycle and does not force
   a cloud subscription model.
2. **Ordering:** preserve current durable behavior: `createdAt ASC`, then
   `id ASC`. Timestamps are an adapter sort key and are not exposed in the read
   model. Local fake parity must preserve insertion/creation order with ID as a
   deterministic tie-break.
3. **Inactive records:** `includeInactive: false` excludes inactive rows;
   `true` includes both states without reordering.
4. **Search/query:** the first contract has no query parameter. Empty-query,
   trimming, case-folding, Arabic normalization, and partial-match behavior are
   therefore not silently invented. A future contract extension must define
   them with tests.
5. **Code/barcode:** `code` is preserved exactly after blank-to-null mapping.
   No barcode exact-match behavior is claimed because the schema and UI do not
   prove that the code is a barcode.
6. **Unicode:** `name` and `code` preserve stored Unicode exactly. No Arabic
   normalization is applied by the read boundary.
7. **Duplicate identity:** duplicate non-empty IDs are an integrity failure;
   adapters must not merge or silently drop rows. Existing local schema also
   enforces normalized unique names and optional codes, but those write-side
   constraints are not broadened here.
8. **Empty result:** successful no-data is an empty, non-null, unmodifiable
   list and is not an error.
9. **Error behavior:** repository exceptions become one controlled Arabic UI
   error state. Initial failure settles loading and shows no false data.
10. **Retry:** explicit retry makes one new `Future` call and replaces the
    whole result. It never appends, merges, or duplicates prior rows.
11. **Refresh failure/cache:** the repository owns no cache. After a successful
    load, a refresh failure retains the controller's last-good snapshot and
    shows a controlled warning. A later success replaces it.
12. **Loading:** controller-owned; it starts before the call and always settles
    after success/failure. Existing data may remain visible during refresh.
13. **Cancellation/stale completion:** cancellation is not in the repository
    contract. The controller must ignore notifications after disposal and must
    prevent an older completion from overwriting a newer request.
14. **Result replacement:** every success replaces the current snapshot; no
    accumulation occurs.
15. **Lifecycle:** `AppRepositories` owns the shared database and production
    adapter. A screen owns only a controller it creates; an injected controller
    remains caller-owned. No database/repository is created or closed in
    `build`.

## 12. Risk Register

| Risk | Likelihood | Impact | Mitigation | Phase |
| --- | --- | --- | --- | --- |
| Persistence entity leaks to UI | Medium | High | Dedicated model; dependency/source audit | 105B/D/E/G |
| Monetary fields enter model | Medium | High | Exact five-field contract and negative mapping tests | 105B/C/G |
| Product master mixes with inventory | Medium | High | No quantity/movement/availability field or dependency | 105B–G |
| Read migration changes writes | Medium | Critical | Keep `ProductRepository` write/data paths untouched; one consumer only | 105D/E/G |
| Ordering changes | Medium | Medium | Freeze `createdAt ASC, id ASC`; parity fixtures | 105B/C |
| Local/cloud search differs | Low now | High later | No search in v1; require explicit contract extension | 105B/106+ |
| Arabic/Unicode normalization differs | Medium | Medium | Exact Unicode preservation; no hidden normalization | 105C/106+ |
| Duplicate ID/code/name data | Low local, medium remote | High | Fail closed on duplicate IDs; define remote integrity preconditions | 105C/106 |
| Nullable code lost | Medium | Medium | Blank-to-null and null fidelity tests | 105B/C |
| Controller/database lifecycle leak | Low | High | Copy accepted Audit Log ownership rules and disposal tests | 105D/E/G |
| Cached or stale data misrepresented | Medium | Medium | Controller-only last-good cache plus visible refresh failure | 105D/E |
| Offline behavior assumed | Medium | High | No offline/cache/sync promise in this contract | 105B/106 |
| Product data overexposed | Low | Medium | Exclude cost/prices/notes; authorization stays above repository | 105B/106 |
| Scope creep to all 23 files | High | Critical | One consumer per phase; explicit prohibited bulk migration | 105D–G |
| Sales/inventory regression | Medium | Critical | Do not migrate them in first sequence; focused and full regression gates | 105D–G |
| Schema/migration pressure | Low | High | Adapter maps existing table only; no schema change | 105C/G |
| Backend details contaminate contract | Medium | High | Ban network DTOs, provider IDs, tokens, sync/version fields | 105B/106 |
| Product `code` is mistaken for barcode | Medium | Medium | Label as business code; defer barcode semantics | 105B/106 |

## 13. Atomic follow-on plan

### Phase 105B — Introduce and Freeze Product Catalog Read Contract

- Add only `ProductCatalogReadModel` and `ProductCatalogReadRepository`.
- Add contract/fake tests for fields, nullability, ordering expectations,
  inactive filtering, empty result and provider independence.
- No adapter, controller, composition, or UI migration.

### Phase 105C — Implement Local Drift Adapter

- Add one local Drift read adapter over the existing `Products` table.
- Map only the five frozen fields.
- Add isolated SQLite parity, mapping, ordering, null, duplicate, and failure
  tests.
- No schema, write path, controller, UI, or cloud work.

### Phase 105D — Migrate One Controller Subread

- Migrate only the product-selector list inside `PurchaseController`.
- Add loading/data/empty/failure/refresh/retry and stale-completion tests for
  that subread.
- Keep purchase, supplier, payment, approval, stock, and write dependencies
  unchanged.

### Phase 105E — Migrate One Production Selector

- Migrate only the product dropdown in `PurchasesScreen` to the read model.
- Bind the repository in the composition root and add focused widget tests.
- Preserve visual behavior and every purchase command path.

### Phase 105F — Retire the Legacy Read for That Consumer

- Remove only `PurchaseController`/`PurchasesScreen` dependency on
  `ProductRepository.listProducts`.
- Do not remove or alter the legacy repository for any other consumer or write.

### Phase 105G — Accept and Freeze the Local Boundary

- Prove real composition, adapter identity, no presentation bypass, mapping,
  failure/retry/cache, ownership, no duplicate results, focused regressions,
  full suite, analyzer and Windows release.
- Freeze the local boundary before any remote decision.

### Phase 106A — deferred

Only after 105G: freeze cloud-adapter preconditions and the backend decision.
Authentication, organization/tenant/warehouse scope, offline policy, conflict
rules, data residency, deployment ownership, provider choice, remote IDs,
search/pagination evolution, and security rules are all deferred. No Phase 106
work was started here.

## 14. Verification gates

| Gate | Result |
| --- | --- |
| Baseline/root/branch/HEAD/status | PASS — required root and `feec6aa24d44c05b81ee7b3195b0268b05f11dbe`, clean |
| Pre-work `git diff --check` | PASS |
| Audit Log focused suite | PASS — 46 passed, 0 failed, 0 skipped; exit 0; 11.1 s |
| Phase 102J isolated | PASS — 5 passed, 0 failed, 0 skipped; exit 0; 4.7 s; revenue `250000`, COGS `187500`, gross profit `62500` |
| Phase 102 related suite | PASS — 61 passed, 0 failed, 0 skipped; exit 0; 8.0 s; fresh production state `profitabilityNotActivated` |
| Full Suite | PASS — 1948 passed, 0 failed, 1 skipped; exit 0; 158.9 s |
| Analyzer | PASS — `No issues found!`; exit 0; 53.9 s analyzer time / 56.2 s wall |
| Formatting | PASS — no Dart files changed; no formatting command required |
| Final `git diff --check` | PASS |
| Windows Release | PASS — exit 0; 22.3 s Flutter build / 24.3 s wall |
| Native smoke | NOT RUN — production database isolation is not proven |

Windows artifact:

- Path: `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes
- SHA-256: `CC44073A2D836BF244758BD0B32CBDCEC34006FFFBCCCAF81DAFEDA47E753CAA`

The native executable will not be launched. No user or production database is
opened or touched by this phase.

The sole Full Suite skip is the unchanged historical case at
`test/phase9a_inflows_outflows_reports_test.dart:552` (“Requires negative
balance approval with actual credentials”). No skip was added or changed.

Two diagnostics did not weaken acceptance. An initial stopwatch-wrapped Audit
command hit its orchestration timeout without test output; the isolated Phase
104J file passed, and the exact eight-file focused command then passed 46/46.
The first two sandboxed Windows build attempts could not acquire Flutter's SDK
cache lock outside the workspace and timed out before spawning a compiler.
Read-only process inspection identified that boundary; the identical build was
then run with approved SDK-cache access and returned exit 0. The release emitted
only the existing non-blocking Firebase CMake minimum-version deprecation
warning.

## 15. Governing baseline decision

With every required verification gate green, the single final Phase 105A
commit becomes the governing baseline for Phase 105B. The only next
authorized step is contract/read-model introduction. It is not authorization
for a Drift adapter, controller migration, screen migration, cloud provider,
backend, synchronization, or mobile implementation.

## 16. Explicit answers

1. **Yes.** Actual read surfaces were traced through screens, controllers,
   repositories, composition and Drift adapters.
2. **Yes.** Exactly one repository target was selected.
3. **Target name:** `Product Master Catalog Read`; contract name
   `ProductCatalogReadRepository`.
4. **Yes.** The target is read-only.
5. **No.** It contains no write operation.
6. **No.** It does not affect accounting entries.
7. **No.** It does not affect COGS.
8. **No.** It does not affect profitability.
9. **No.** It does not move inventory.
10. **No.** It needs no schema change.
11. **No.** It needs no migration.
12. **No.** It needs no cloud package now.
13. **No.** It needs no backend now.
14. **No.** It needs neither Firebase nor Supabase now.
15. **No.** It needs no mobile UI change now.
16. **Yes.** `ProductCatalogReadModel` is proposed and frozen here.
17. **Yes.** Its fields and types are independent of Drift rows/columns.
18. **Yes.** Prices, cost, notes, timestamps, quantity, valuation and metadata
    are deliberately excluded.
19. **Yes.** `ProductCatalogReadRepository` is proposed and frozen here.
20. **Yes.** Its list plus active-state choice matches a proven current product
    selector need.
21. **Yes.** It contains no backend or transport detail.
22. **Yes.** `Future` is selected, not `Stream`.
23. **Yes.** The selection rationale and rejected alternatives are documented.
24. **Yes.** Sorting is frozen as creation ascending, then ID ascending.
25. **Yes.** Search is explicitly absent from v1; no implicit semantics exist.
26. **Yes.** Failure becomes controlled UI state.
27. **Yes.** Retry performs one new call and replaces results.
28. **Yes.** No repository cache; controller may retain last-good data on
    refresh failure.
29. **Yes.** Composition, database, controller and screen ownership are frozen.
30. **Yes.** Product master is separated from inventory availability and
    pricing.
31. **Yes.** The read contract is separated from every write operation.
32. **Yes.** A Risk Register is included.
33. **Yes.** Work is divided into 105B–105G and deferred 106A.
34. **Yes.** Each follow-on phase has one atomic objective.
35. **Yes.** Audit Log remains closed and its focused suite is recorded above.
36. **Yes.** Phase 102J remains green as recorded above.
37. **Yes.** Revenue remains `250000` in the Phase 102J evidence.
38. **Yes.** COGS remains `187500`.
39. **Yes.** Gross profit remains `62500`.
40. **Yes.** Production state remains `profitabilityNotActivated`.
41. **Yes.** The Full Suite has zero failures as recorded above.
42. **Yes.** Analyzer has zero issues as recorded above.
43. **Yes.** Windows Release succeeds as recorded above.
44. **No.** The user/production database was not touched.
45. **No.** No cloud implementation started.
46. **No.** No mobile implementation started.
47. **Yes.** After all gates and the single commit, that commit is the
    governing baseline for 105B.
48. **Yes.** Phase 105B is contract/read-model introduction only, with no
    adapter or UI migration.
