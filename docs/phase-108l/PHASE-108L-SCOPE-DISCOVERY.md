# Phase 108L — Scope Discovery

## 1. Purpose

This document records discovery and governance only. It does not plan or
implement Phase 108L. Its purpose is to identify one smallest legitimate next
architectural slice from the exact remotely locked Phase 108K baseline.

```text
SESSION = PHASE_108L_SCOPE_DISCOVERY
IMPLEMENTATION = NOT_STARTED
REMOTE_MUTATION = FORBIDDEN
DATABASE_MUTATION = FORBIDDEN
SUPABASE_MUTATION = FORBIDDEN
```

## 2. Governing baseline

The verified repository identity is:

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
REMOTE_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
ENTRY_HEAD = 2d6abc71decd618f02540873e5e0f389f5c17408
REMOTE_HEAD = 2d6abc71decd618f02540873e5e0f389f5c17408
AHEAD = 0
BEHIND = 0
```

The entry worktree, index, untracked set, and stash were empty. The direct
parent chain verified exactly:

```text
951ed1cfe4e673f376dd9e270f2d7076fc8f1750
  -> bc1d37f430ae3708fe2cd4e3c93386f8fbecf1af
  -> 273640cba345a8fbfdd6a5e2f2e6b7bed74b8909
  -> 2d6abc71decd618f02540873e5e0f389f5c17408
```

The local and remote annotated tag objects and peeled targets matched:

| Tag | Annotated object | Peeled target |
|---|---|---|
| `phase-108j-implementation-locked` | `4e1c781a86beece985eb8ac3ae796976240c3cdd` | `951ed1cfe4e673f376dd9e270f2d7076fc8f1750` |
| `phase-108k-planning-baseline-locked` | `4d8377fc8abd37c8f301674e2fe624dd5057511e` | `273640cba345a8fbfdd6a5e2f2e6b7bed74b8909` |
| `phase-108k-implementation-locked` | `650eef8ace456de9c69b60b7f46cac5434d09d7c` | `2d6abc71decd618f02540873e5e0f389f5c17408` |

The protected Phase 108K artifacts remain at their locked blobs:

| Artifact | Blob |
|---|---|
| `docs/phase-108k/PHASE-108K-SCOPE-DISCOVERY-AND-GOVERNANCE-RECONCILIATION.md` | `0d7df9c6f0ab547f9e45082a0851cb4ceaa36a9c` |
| `docs/phase-108k/PHASE-108K-PRODUCT-CATALOG-QUERY-PLANNING.md` | `0711297c46f33afeaaf29c48b20e3e372fd8922b` |

## 3. Phase 108K facts

Phase 108K migrated only the Products-screen product-catalog list read.

```text
OLD_PATH =
ProductsScreen
  -> AppRepositories.productCatalogReadRepository
  -> ProductController.loadProducts
  -> ProductCatalogReadRepository.listProductCatalog
  -> DriftProductCatalogReadRepository
  -> SQLite Products

NEW_PATH =
ProductsScreen
  -> ApplicationScope.of(context).queries.productCatalog
  -> ProductController.loadProducts
  -> LoadProductCatalogQueryHandler.execute
  -> ProductCatalogReadRepository.listProductCatalog
  -> DriftProductCatalogReadRepository
  -> SQLite Products
```

The implementation added `LoadProductCatalogQuery` and
`LoadProductCatalogQueryHandler`, exposed the handler through
`ApplicationQueries.productCatalog`, composed the exact captured shared read
repository in `AppCompositionRoot`, changed `ProductController.loadProducts`
to execute the query, and changed default `ProductsScreen` construction to
resolve that handler through `ApplicationScope`.

The product write path remains separate and local:

```text
ProductsScreen
  -> ProductController create/update/activation methods
  -> ProductRepository
  -> local Drift mutation
  -> refresh through LoadProductCatalogQueryHandler
```

**FACT:** Phase 108K established a reusable recipe for a narrow UI read:
typed request and handler, truthful local metadata, exact shared dependency
composition, controller compatibility, UI resolution through
`ApplicationScope`, focused behavior tests, and guards against a second
migration.

## 4. Discovery method

Discovery used current source and Git history rather than phase names:

1. verified repository, branch, remote, baseline ancestry, tags, divergence,
   entry cleanliness, stash, and protected artifact blobs;
2. inspected the complete Phase 108K production diff and its focused tests;
3. searched feature, shared, controller, repository, application, composition,
   test, roadmap, and governance code for direct persistence reads;
4. traced serious candidates through their actual repository implementation;
5. searched all history for `108L`, query-migration, application-boundary, and
   next-phase proposals;
6. classified the pre-existing local-only Phase 108L branch before selecting a
   scope;
7. compared candidates for atomicity, pattern reuse, testability, authority,
   side effects, and change radius.

Current presentation code contains 40 files and 148 `AppRepositories` tokens
under `lib/features/**` and `lib/shared/**`. This is an inventory signal, not an
authorization to perform broad locator cleanup.

## 5. Remaining architectural seams

### Existing seams

- `ApplicationBoundary` exposes typed commands and three typed queries.
- `ApplicationScope` provides the boundary to the widget tree.
- `ApplicationDependencies` captures exact shared repository/service/runtime
  instances.
- `LegacyApplicationDependencyBridge` isolates remaining global-locator
  capture at composition time.
- `ApplicationQueryResult` carries explicit local provenance.
- audit log, document history, and product catalog demonstrate the accepted
  handler pattern.
- Phase 108J demonstrates a distinct server-authoritative financial command
  pattern that must not be conflated with a local UI query.

### Remaining presentation bypasses

- pure managed-file logo reads in the dashboard app bar, shared business
  identity header, printable scaffold, and settings preview;
- simple controller list reads for suppliers and expenses;
- customer list loading coupled to balances and opening-balance detection;
- financial-account lists/statements and supplier statements;
- sales, purchases, and inventory controller construction over several mixed
  read/write repositories;
- dashboard, daily-report, profitability, and financial-report aggregates over
  multiple repositories;
- export paths that load identity and logo bytes directly.

### Provenance gap exposed by the selected candidate

`LocalQueryResultMetadata` currently supports only
`LocalReadAuthority.sqlite`. The selected read is a managed local file. A
future implementation must add only the precise managed-file authority value
needed to describe this query truthfully. This small contract extension is
part of the selected query, not an independent provenance redesign.

## 6. Candidate inventory

### C1 — Dashboard app-bar business-logo bytes

```text
CANDIDATE_ID = C1_DASHBOARD_APP_BAR_BUSINESS_LOGO
USER_VISIBLE_AREA = DashboardShell app bar
CURRENT_READ_PATH = DashboardShell._AppBarLogo -> AppRepositories.businessIdentityRepository.loadLogoBytes -> managed local file
TARGET_READ_PATH = DashboardShell._AppBarLogo -> ApplicationScope -> typed logo query handler -> same BusinessIdentityRepository -> same managed local file
READ_ONLY = YES
SCHEMA_CHANGE_REQUIRED = NO
WRITE_PATH_TOUCHED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
GENERATED_FILES_REQUIRED = NO
ESTIMATED_FILES = 5 production categories plus focused/current architecture tests
ESTIMATED_TEST_SURFACE = query unit tests, shared-instance composition, dashboard-shell widget behavior, Phase 108F/I/K architecture guards
ARCHITECTURAL_VALUE = closes one complete direct UI-to-managed-persistence seam and extends truthful query provenance
RISK = LOW
DEPENDENCIES = existing BusinessIdentityRepository capture and ApplicationScope
DISPOSITION = ACCEPT
```

### C2 — Shared business-identity-header logo bytes

```text
CANDIDATE_ID = C2_SHARED_BUSINESS_IDENTITY_HEADER_LOGO
USER_VISIBLE_AREA = reusable BusinessIdentityHeader in dashboard/settings layouts
CURRENT_READ_PATH = BusinessIdentityHeader._IdentityLogo -> AppRepositories.businessIdentityRepository.loadLogoBytes
TARGET_READ_PATH = BusinessIdentityHeader._IdentityLogo -> ApplicationScope -> typed logo query handler
READ_ONLY = YES
SCHEMA_CHANGE_REQUIRED = NO
WRITE_PATH_TOUCHED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
GENERATED_FILES_REQUIRED = NO
ESTIMATED_FILES = similar production count to C1
ESTIMATED_TEST_SURFACE = broader because the shared widget is rendered in several scope-free historical harnesses
ARCHITECTURAL_VALUE = closes one shared-widget persistence seam
RISK = LOW_TO_MODERATE_REGRESSION_RADIUS
DEPENDENCIES = managed-file provenance and ApplicationScope harness updates
DISPOSITION = DEFER
```

### C3 — Settings logo-preview bytes

```text
CANDIDATE_ID = C3_SETTINGS_LOGO_PREVIEW
USER_VISIBLE_AREA = Settings logo preview
CURRENT_READ_PATH = SettingsScreen._LogoPreview -> AppRepositories.businessIdentityRepository.loadLogoBytes
TARGET_READ_PATH = Settings preview -> ApplicationScope -> typed logo query handler
READ_ONLY = YES
SCHEMA_CHANGE_REQUIRED = NO
WRITE_PATH_TOUCHED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
GENERATED_FILES_REQUIRED = NO
ESTIMATED_FILES = similar production count to C1
ESTIMATED_TEST_SURFACE = settings preview plus identity write negative controls
ARCHITECTURAL_VALUE = closes one persistence read in a mixed settings screen
RISK = LOW_TO_MODERATE_MUTATION_ADJACENCY
DEPENDENCIES = managed-file provenance
DISPOSITION = DEFER
```

### C4 — Expenses-screen expense list

```text
CANDIDATE_ID = C4_EXPENSE_LIST
USER_VISIBLE_AREA = ExpensesScreen list
CURRENT_READ_PATH = ExpensesScreen -> ApplicationScope.dependencies.repositories.expenseRepository -> ExpenseController.loadExpenses -> ExpenseRepository.listExpenses -> SQLite confirmed projection
TARGET_READ_PATH = ExpensesScreen -> ApplicationScope.queries -> typed expense-list query handler -> same ExpenseRepository -> SQLite confirmed projection
READ_ONLY = YES
SCHEMA_CHANGE_REQUIRED = NO
WRITE_PATH_TOUCHED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
GENERATED_FILES_REQUIRED = NO
ESTIMATED_FILES = 5 production categories plus focused/current architecture tests
ESTIMATED_TEST_SURFACE = list parity, confirmed-projection refresh, Phase 108J command/projection regressions, query architecture guards
ARCHITECTURAL_VALUE = closes one repository exposure already partially inside ApplicationScope
RISK = MODERATE_FINANCIAL_PROJECTION_SEMANTICS
DEPENDENCIES = locked Phase 108J confirmed-projection behavior
DISPOSITION = DEFER
```

### C5 — Suppliers-screen supplier list

```text
CANDIDATE_ID = C5_SUPPLIER_LIST
USER_VISIBLE_AREA = SuppliersScreen directory list only
CURRENT_READ_PATH = SuppliersScreen -> SupplierController -> SupplierRepository.listSuppliers -> SQLite Suppliers
TARGET_READ_PATH = SuppliersScreen -> ApplicationScope.queries -> typed supplier-list handler -> same supplier repository
READ_ONLY = YES
SCHEMA_CHANGE_REQUIRED = NO
WRITE_PATH_TOUCHED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = YES
GENERATED_FILES_REQUIRED = NO
ESTIMATED_FILES = 7 production categories plus tests
ESTIMATED_TEST_SURFACE = includeInactive parity, ordering, controller CRUD refresh, supplier-screen behavior, application composition
ARCHITECTURAL_VALUE = closes the supplier-directory read but leaves separate balance reads in the same screen
RISK = LOW_DATA_RISK_WITH_MIXED_SCREEN_OWNERSHIP
DEPENDENCIES = add exact supplier repository to ApplicationDependencies/bridge or introduce a dedicated read port
DISPOSITION = DEFER
```

### C6 — Customers-screen customer list

```text
CANDIDATE_ID = C6_CUSTOMER_LIST
USER_VISIBLE_AREA = CustomersScreen
CURRENT_READ_PATH = CustomerController.loadCustomers -> customer list plus customer balances plus per-customer opening-balance checks
TARGET_READ_PATH = not atomic without choosing whether the query owns one read or the displayed composite
READ_ONLY = YES
SCHEMA_CHANGE_REQUIRED = NO
WRITE_PATH_TOUCHED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = YES
GENERATED_FILES_REQUIRED = NO
ESTIMATED_FILES = GREATER_THAN_C5
ESTIMATED_TEST_SURFACE = customer identity, balance, opening balance, collection/advance refresh, screen behavior
ARCHITECTURAL_VALUE = potentially high but the visible load is a multi-repository financial composite
RISK = MODERATE_TO_HIGH
DEPENDENCIES = customer and customer-account dependency design
DISPOSITION = DEFER_PENDING_RESCOPING
```

### C7 — Financial-account list or statement

```text
CANDIDATE_ID = C7_FINANCIAL_ACCOUNT_READ
USER_VISIBLE_AREA = Financial accounts or account statement
CURRENT_READ_PATH = screen/controller -> FinancialAccountRepository aggregate/statement -> SQLite-backed hydrated state
TARGET_READ_PATH = typed financial query handler with explicit consistency policy
READ_ONLY = YES
SCHEMA_CHANGE_REQUIRED = NO
WRITE_PATH_TOUCHED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
GENERATED_FILES_REQUIRED = NO
ESTIMATED_FILES = 5 or more production categories plus broad financial tests
ESTIMATED_TEST_SURFACE = account totals, date filters, opening/final balances, transfers/closing/negative-balance regressions
ARCHITECTURAL_VALUE = high
RISK = HIGHER_FINANCIAL_AND_CONSISTENCY_RISK
DEPENDENCIES = confirmed/provisional and official-report freshness policy
DISPOSITION = DEFER
```

### C8 — Dashboard, daily activity, or financial report query

```text
CANDIDATE_ID = C8_AGGREGATE_REPORT_QUERY
USER_VISIBLE_AREA = dashboard/reports
CURRENT_READ_PATH = screen-created aggregate service/repository -> multiple repositories -> derived SQLite state
TARGET_READ_PATH = typed aggregate query family with consistency/provenance policy
READ_ONLY = YES
SCHEMA_CHANGE_REQUIRED = NO
WRITE_PATH_TOUCHED = NO
SUPABASE_CHANGE_REQUIRED = NO_FOR_LOCAL_ONLY_BUT_FUTURE_POLICY_IS_UNRESOLVED
NEW_DEPENDENCY_REQUIRED = YES_OR_AGGREGATE_CAPTURE_REQUIRED
GENERATED_FILES_REQUIRED = NO
ESTIMATED_FILES = HIGH
ESTIMATED_TEST_SURFACE = accounting, inventory, cancellation, valuation, dashboard/report UI, consistency
ARCHITECTURAL_VALUE = high but not one smallest slice
RISK = HIGH
DEPENDENCIES = multi-repository snapshot/consistency policy
DISPOSITION = REJECT_FOR_PHASE_108L
```

### C9 — Broad boundary or repository cleanup

```text
CANDIDATE_ID = C9_NON_QUERY_BOUNDARY_REDESIGN
USER_VISIBLE_AREA = repository-wide
CURRENT_READ_PATH = many locator/controller/service patterns
TARGET_READ_PATH = generalized DI/read-port cleanup
READ_ONLY = MIXED
SCHEMA_CHANGE_REQUIRED = UNKNOWN
WRITE_PATH_TOUCHED = YES_LIKELY
SUPABASE_CHANGE_REQUIRED = NO_BUT_AUTHORITY_DESIGN_COULD_LEAK_IN
NEW_DEPENDENCY_REQUIRED = BROAD
GENERATED_FILES_REQUIRED = POSSIBLE
ESTIMATED_FILES = HIGH
ESTIMATED_TEST_SURFACE = REPOSITORY_WIDE
ARCHITECTURAL_VALUE = high in the abstract
RISK = HIGH_AND_NON_ATOMIC
DEPENDENCIES = several unresolved ownership decisions
DISPOSITION = REJECT
```

## 7. Candidate comparison

| Candidate | Pattern reuse | Atomicity | Testability | Data/financial risk | Change radius | Final disposition |
|---|---|---|---|---|---|---|
| C1 dashboard app-bar logo | high | high | high | very low | smallest | **ACCEPT** |
| C2 shared-header logo | high | high | medium | very low | broader widget harnesses | DEFER |
| C3 settings logo preview | high | high | medium | very low | mixed write-adjacent screen | DEFER |
| C4 expense list | high | high | high | moderate financial projection | small | DEFER |
| C5 supplier list | medium | high if list-only | high | low | adds dependency capture; leaves balances | DEFER |
| C6 customer visible load | medium | low without rescoping | high | moderate | multi-repository | DEFER |
| C7 financial accounts | high | medium | high | high | medium | DEFER |
| C8 aggregates/reports | medium | low | high but broad | high | large | REJECT |
| C9 broad redesign | low for one phase | none | broad | mixed | repository-wide | REJECT |

**INFERENCE:** C1 wins the governing product because it closes one complete
presentation-to-persistence seam, uses an already captured exact dependency,
requires no schema or remote behavior, and has lower behavioral and data risk
than every database-backed alternative.

## 8. Historical governance reconciliation

### Historical proposal: Phase 108A

Phase 108A assigned `108L` to a staged local-to-cloud migration and
reconciliation pilot. That semantic sequence depended on cloud/auth/catalog,
financial-command, and outbox milestones that the accepted 108E–108K lineage
did not implement under those identifiers.

```text
FINAL_DISPOSITION = SUPERSEDED_AS_PHASE_108L_IDENTIFIER; DEFER_AS_UNNUMBERED_FUTURE_WORK
```

It remains a legitimate future capability, but it is neither prerequisite to
nor safe as the next current-baseline slice.

### Historical proposal: Phase 108D

Phase 108D assigned `108L` collectively to dashboard, statement, and financial
report query boundaries. Current code confirms those seams remain, but the
assignment joins several independently reviewable query families and requires
consistency policy across financial and inventory aggregates.

```text
FINAL_DISPOSITION = ACCEPT_ARCHITECTURAL_DIRECTION_WITH_RESCOPING; REJECT_BROAD_BUNDLE_FOR_PHASE_108L
```

### Pre-existing local-only Phase 108L branch

Local ref `codex/phase-108l-fourth-read-only-ui-slice-discovery-freeze` points
to `83091e6ce87f983239339798a6a824e4abb93154`, whose parent is
`932282bd5f936df51710fb06cabeeb1a908166df`. Its merge base with the governing
HEAD is `deac34e7db2a5f6fd01f6fa7ff04020e308dfb6e`; neither head is an ancestor of
the other. No matching remote branch exists.

That commit froze `BusinessIdentityHeader` logo loading after a different
divergent Phase 108K had already introduced and migrated a business-logo query
for the dashboard app bar. It also added a governance test, whereas this
session permits exactly one document artifact.

```text
CURRENT_REPOSITORY_REALITY = no business-logo query exists on the locked current baseline; both DashboardShell and BusinessIdentityHeader still read the repository directly
FINAL_DISPOSITION = REJECT_AS_RECOVERY_BASELINE; ACCEPT_READ_ONLY_LOGO_ANALYSIS_AS_NON_AUTHORITATIVE_HISTORICAL_EVIDENCE; RESCOPE_TO_THE_SMALLER_FIRST_DASHBOARD_APP_BAR_SEAM
```

This state is not ambiguous after ancestry, content, and remote verification.
The authoritative branch therefore remains a fresh Phase 108L discovery while
the divergent local ref is preserved untouched.

### Current authority

Phase 108K expressly froze one Products-screen query and prohibited a second
query in that phase. Its completion now permits evaluating a new phase. It did
not assign Phase 108L. Current source, not stale numbering, selects C1.

## 9. Selected canonical Phase 108L scope

```text
CANONICAL_PHASE_108L_SCOPE =
ONE_LOCAL_READ_ONLY_DASHBOARD_APP_BAR_BUSINESS_LOGO_UI_QUERY_MIGRATION_THROUGH_APPLICATION_BOUNDARY
```

Human-readable scope: migrate the dashboard app-bar business-logo bytes read
through the application query boundary.

**RECOMMENDATION:** plan exactly this one managed-file read path as Phase 108L.

## 10. Explicit in-scope

- one immutable query request carrying the managed logo filename;
- one read-only handler calling only
  `BusinessIdentityRepository.loadLogoBytes`;
- truthful local/current-known-state/managed-file metadata;
- one new `ApplicationQueries` member;
- composition with the already captured exact shared
  `BusinessIdentityRepository` instance;
- migration of only `DashboardShell._AppBarLogo` from `AppRepositories` to
  `ApplicationScope` query resolution;
- preservation of empty-name, bytes, missing-file, exception, loading, null,
  image-error, dimensions, and fit behavior;
- focused unit, composition, widget, and architecture regression tests.

## 11. Explicit out-of-scope

- `BusinessIdentityHeader` logo loading;
- settings logo preview;
- printable-document logo loading;
- PDF/export/financial-report branding reads;
- business identity metadata loading, saving, editing, or deletion;
- a second logo consumer or any second query migration;
- expense, supplier, customer, account, inventory, sales, purchase, dashboard
  aggregate, statement, or report queries;
- repository-wide locator removal or dependency-injection cleanup;
- repository redesign or splitting `BusinessIdentityRepository`;
- UI redesign, navigation, branding dimensions, caching, or performance work;
- database/schema/migration/generated-file changes;
- Supabase tables, storage, RLS, RPCs, adapters, sync, or tenant/business scope;
- new dependencies;
- Phase 108J command/projection changes;
- Phase 108K product-query changes except test inventory adjustments strictly
  required to acknowledge one later query.

## 12. Architectural target

```text
CURRENT_PATH =
DashboardShell._AppBarLogo
  -> AppRepositories.businessIdentityRepository
  -> BusinessIdentityRepository.loadLogoBytes
  -> LocalBusinessIdentityRepository
  -> managed local logo file

TARGET_PATH =
DashboardShell._AppBarLogo
  -> ApplicationScope.of(context).queries.businessLogo
  -> LoadBusinessLogoQueryHandler.execute
  -> existing ApplicationDependencies.repositories.businessIdentityRepository
  -> same BusinessIdentityRepository instance
  -> LocalBusinessIdentityRepository
  -> same managed local logo file
```

```text
AUTHORITATIVE_SOURCE = CURRENT_MANAGED_LOCAL_LOGO_FILE
QUERY_SOURCE = LOCAL
READ_AUTHORITY = MANAGED_FILE
CONSISTENCY = CURRENT_KNOWN_STATE
SERVER_ROLE = NONE
BUSINESS_CONTEXT_ROLE = NONE
SESSION_CONTEXT_ROLE = NONE_BEYOND_EXISTING_APP_ACCESS
WRITE_AUTHORITY_CHANGE = NONE
```

The UI must receive only the typed query handler. The broader repository write
methods must not become reachable through the query surface.

## 13. Expected production change surface

### Required

- `lib/application/queries/load_business_logo_query.dart`: request and handler;
- `lib/application/queries/application_query.dart`: one precise managed-file
  local authority value;
- `lib/application/application_boundary.dart`: one `ApplicationQueries`
  member;
- `lib/composition/app_composition_root.dart`: compose the handler from the
  already captured exact repository;
- `lib/features/dashboard/dashboard_shell.dart`: replace only the app-bar logo
  read's locator acquisition with the typed handler.

### Possible only if focused tests prove necessary

- test harness helpers that construct `ApplicationBoundary`/`ApplicationScope`;
- existing current-tree query-inventory guards in Phase 108F, 108I, and 108K;
- a compatibility injection seam local to `_AppBarLogo` if required to keep
  widget tests deterministic without preserving production locator fallback.

### Forbidden

- production edits outside the selected query, boundary, composition, and
  app-bar consumer;
- changes to `BusinessIdentityRepository` behavior or local file layout;
- edits to identity controller ownership;
- any schema, generated, dependency, Supabase, or additional consumer change.

## 14. Expected test surface

Future planning must specify tests for:

1. empty managed filename returns null without a repository call;
2. exact filename forwarding and exact bytes identity;
3. missing-file/null parity;
4. repository exception propagation at handler level and preserved catch/hide
   behavior at widget level;
5. exactly one `loadLogoBytes` call for one executed query;
6. zero calls to `saveIdentity`, `saveLogoBytes`, and `deleteLogoFile`;
7. metadata source `local`, authority `managedFile`, consistency
   `currentKnownState`;
8. production handler uses the exact captured
   `AppRepositories.businessIdentityRepository` instance;
9. dashboard app-bar logo/no-logo/render dimensions and image-error parity;
10. `DashboardShell` no longer imports or references `AppRepositories` after
    the selected migration;
11. no second logo consumer/query migration;
12. Phase 68 managed-logo repository regressions;
13. Phase 83 dashboard-shell navigation/responsive regressions;
14. Phase 96 branding regressions;
15. Phase 108F/I/K application-query and singular-scope regressions;
16. analyzer, full Flutter suite, formatting/diff checks, and source guards.

## 15. Risk analysis

| Risk | Assessment | Control |
|---|---|---|
| Behavioral | low | preserve all existing filename/null/error/render behavior |
| Architectural | low | reuse established handler/scope/composition recipe and exact captured dependency |
| Data | very low | read-only bytes; no file creation, deletion, or modification |
| Financial | none | no amount, ledger, account, inventory, expense, sale, or purchase data |
| Schema | none | no database table/version/migration/generated code |
| Supabase | none | no network, storage bucket, RLS, RPC, session, or tenant scope |
| Regression | low to moderate | app shell has broad visibility; require focused Phase 83/96 plus full suite |
| Provenance | low | add one truthful `managedFile` authority rather than mislabel the read as SQLite |
| Scope expansion | controlled | freeze one private app-bar widget; exclude every other logo consumer |

## 16. Dependencies

Required existing dependencies:

- `ApplicationQueryHandler` and `ApplicationQueryResult`;
- `ApplicationBoundary.queries`;
- `ApplicationScope` above `DashboardShell` in production (`main.dart`);
- `ApplicationDependencies.repositories.businessIdentityRepository`;
- exact repository capture through `LegacyApplicationDependencyBridge`;
- `BusinessIdentityRepository.loadLogoBytes` and current local implementation;
- locked Phase 108K baseline and current application-query tests.

No external service, new package, schema, network, Supabase, generated file, or
unrelated refactor is a prerequisite.

## 17. Definition of Done for future planning

Discovery-time repository health verification completed without changing
production or test code:

```text
TARGETED_TESTS = 103 PASSED / 0 FAILED
FLUTTER_ANALYZE = NO ISSUES FOUND
FULL_FLUTTER_TEST = 2499 PASSED / 0 FAILED
```

The focused run covered the Phase 108F/I/K query boundaries, Phase 108H app
shell ownership, Phase 83 responsive shell, Phase 96 business branding, and
Phase 68 managed-logo behavior. The full run emitted the known Drift debug
warning about multiple in-memory database instances in a historical test; it
did not fail a test.

The later Phase 108L planning session is complete only when it freezes:

- the exact request/result/metadata contract;
- the exact handler and application-boundary member;
- exact shared dependency identity and construction order;
- the precise `_AppBarLogo` integration approach;
- all behavior, error, negative-write, and provenance assertions;
- required/possible/forbidden file lists;
- targeted and full verification commands;
- rollback and stop conditions;
- a one-phase implementation acceptance checklist;
- explicit proof that no second consumer or write behavior is included.

Planning must not implement the slice.

## 18. Forbidden scope expansion

Phase 108L must stop if implementation would require:

- migrating more than `DashboardShell._AppBarLogo`;
- adding logo caching, sync, remote storage, or business scoping;
- changing business identity metadata or managed-file layout;
- exposing a repository through the widget/application query API;
- touching any write method;
- adding a second query or feature behavior;
- changing schema, generated code, dependencies, or Supabase;
- weakening Phase 108F/I/K singular-scope or current-tree architecture guards;
- incorporating work from the divergent local Phase 108L branch by merge,
  cherry-pick, rebase, reset, or history rewrite.

If truthful managed-file provenance cannot be added atomically with this query,
or if the app-bar path cannot be migrated without a production locator
fallback, planning must block rather than broaden the phase.

## 19. Next authorized session

After valid local governance closure, the only next session is:

```text
NEXT_AUTHORIZED_SESSION = PHASE_108L_GOVERNANCE_RECONCILIATION_REMOTE_LOCK
```

That session may verify and remotely lock this governance decision only. It
must not plan or implement Phase 108L unless separately authorized after the
remote governance baseline is established.
