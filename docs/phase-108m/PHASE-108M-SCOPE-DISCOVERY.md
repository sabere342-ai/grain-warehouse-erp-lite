# Phase 108M — Scope Discovery

## 1. Purpose

This artifact records scope discovery and governance reconciliation only. It
freezes one smallest legitimate architectural product after the remotely locked
Phase 108L implementation. It does not plan or implement that product.

```text
SESSION = PHASE_108M_SCOPE_DISCOVERY_AND_GOVERNANCE_RECONCILIATION
PHASE_108M_SCOPE_DISCOVERY = COMPLETE
PHASE_108M_PLANNING = NOT_STARTED
PHASE_108M_IMPLEMENTATION = NOT_STARTED
REMOTE_MUTATION = FORBIDDEN
TAG_MUTATION = FORBIDDEN
DATABASE_MUTATION = FORBIDDEN
SUPABASE_MUTATION = FORBIDDEN
HISTORY_REWRITE = FORBIDDEN
```

## 2. Governing baseline

The repository identity and fresh-entry state were verified before discovery:

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
ENTRY_HEAD = f0e53febb3bba0f5c9aaa348702c78d3feeee96d
REMOTE_HEAD = f0e53febb3bba0f5c9aaa348702c78d3feeee96d
AHEAD = 0
BEHIND = 0
WORKTREE = CLEAN
INDEX = EMPTY
UNTRACKED = NONE
STASH = EMPTY
RECOVERY_CLASSIFICATION = CASE A — FRESH GOVERNANCE
```

The governing direct ancestry is exact:

```text
2d6abc71decd618f02540873e5e0f389f5c17408
  -> 2172ae49119a6194ab419b0157b5e1e811ba00f9
  -> 703180f05b0e836a9c2aa278eb01f0bbcab120e2
  -> f0e53febb3bba0f5c9aaa348702c78d3feeee96d
```

Each commit is a normal one-parent, non-merge commit. Their subjects are:

| Commit | Subject |
|---|---|
| `2d6abc71decd618f02540873e5e0f389f5c17408` | `Phase 108K: migrate product catalog query through application boundary` |
| `2172ae49119a6194ab419b0157b5e1e811ba00f9` | `Phase 108L: discover and freeze canonical scope` |
| `703180f05b0e836a9c2aa278eb01f0bbcab120e2` | `Phase 108L: plan dashboard app bar business logo query migration` |
| `f0e53febb3bba0f5c9aaa348702c78d3feeee96d` | `Phase 108L: migrate dashboard app bar business logo query` |

Local and remote annotated tag objects, types, and peeled targets agree:

| Tag | Tag object | Type | Peeled commit |
|---|---|---|---|
| `phase-108j-implementation-locked` | `4e1c781a86beece985eb8ac3ae796976240c3cdd` | `tag` | `951ed1cfe4e673f376dd9e270f2d7076fc8f1750` |
| `phase-108k-planning-baseline-locked` | `4d8377fc8abd37c8f301674e2fe624dd5057511e` | `tag` | `273640cba345a8fbfdd6a5e2f2e6b7bed74b8909` |
| `phase-108k-implementation-locked` | `650eef8ace456de9c69b60b7f46cac5434d09d7c` | `tag` | `2d6abc71decd618f02540873e5e0f389f5c17408` |
| `phase-108l-governance-reconciliation-locked` | `18207fa2407010643f6228f100690a8f8ff04ce5` | `tag` | `2172ae49119a6194ab419b0157b5e1e811ba00f9` |
| `phase-108l-planning-baseline-locked` | `e4b9b05ddedb78702a9c2e08179dcb4478bb8608` | `tag` | `703180f05b0e836a9c2aa278eb01f0bbcab120e2` |
| `phase-108l-implementation-locked` | `5769c878bb74657652cd77ae8f7eab0729062490` | `tag` | `f0e53febb3bba0f5c9aaa348702c78d3feeee96d` |

Protected artifact blobs were verified before writing this new artifact. Since
this session changes only this new file, their final blobs must remain equal:

| Protected artifact | Baseline blob | Required final blob |
|---|---|---|
| `docs/phase-108k/PHASE-108K-SCOPE-DISCOVERY-AND-GOVERNANCE-RECONCILIATION.md` | `0d7df9c6f0ab547f9e45082a0851cb4ceaa36a9c` | `0d7df9c6f0ab547f9e45082a0851cb4ceaa36a9c` |
| `docs/phase-108k/PHASE-108K-PRODUCT-CATALOG-QUERY-PLANNING.md` | `0711297c46f33afeaaf29c48b20e3e372fd8922b` | `0711297c46f33afeaaf29c48b20e3e372fd8922b` |
| `docs/phase-108l/PHASE-108L-SCOPE-DISCOVERY.md` | `7abf3d70649e8f08a49652186fb26aad84d41324` | `7abf3d70649e8f08a49652186fb26aad84d41324` |
| `docs/phase-108l/PHASE-108L-DASHBOARD-APP-BAR-BUSINESS-LOGO-QUERY-PLANNING.md` | `eac23dbd6931035e4ce84bbe958e4feffbae1a08` | `eac23dbd6931035e4ce84bbe958e4feffbae1a08` |

## 3. Phase 108L locked facts

Phase 108L completed exactly:

```text
ONE_LOCAL_READ_ONLY_DASHBOARD_APP_BAR_BUSINESS_LOGO_UI_QUERY_MIGRATION_THROUGH_APPLICATION_BOUNDARY
```

Its locked transition is:

```text
BEFORE
DashboardShell._AppBarLogo
  -> AppRepositories.businessIdentityRepository
  -> BusinessIdentityRepository.loadLogoBytes
  -> managed local file

AFTER
DashboardShell._AppBarLogo
  -> ApplicationScope.of(context).queries.businessLogo
  -> LoadBusinessLogoQueryHandler.execute
  -> ApplicationDependencies.repositories.businessIdentityRepository
  -> same captured BusinessIdentityRepository instance
  -> managed local file
```

Phase 108L added the immutable `LoadBusinessLogoQuery`, its read-only handler,
the `ApplicationQueries.businessLogo` exposure, exact production composition,
and truthful `LocalReadAuthority.managedFile` metadata. It changed only the
dashboard app-bar logo consumer. The shared header, settings preview,
printable scaffold, exports, and financial-report branding reads were
deliberately left unchanged.

## 4. Discovery method

Discovery was performed from the exact Phase 108L implementation tree:

1. verified repository identity, clean entry state, remote head, ancestry,
   annotated tags, and protected artifact blobs;
2. inspected the Phase 108L implementation diff and its production/tests;
3. searched `lib/application`, `lib/composition`, `lib/features`, `lib/shared`,
   `lib/core`, `test`, and `docs`; the requested `lib/data` and
   `lib/repositories` directories do not exist in this repository;
4. inventoried presentation-layer `AppRepositories` access: 39 consumer files
   and 145 literal `AppRepositories.` references under `lib/features` and
   `lib/shared`;
5. traced all remaining managed-logo reads and the deferred expense, supplier,
   customer, financial-account, dashboard, and report candidates;
6. searched current documentation and all Git refs for prior `108M` meanings;
7. inspected the divergent local-only Phase 108M commit and its parent lineage
   without checking it out or modifying it;
8. compared serious candidates on exact dependency identity, provenance,
   atomicity, test surface, change radius, and financial/data risk; and
9. ran 70 focused pre-existing tests spanning Phase 108L, shared branding,
   settings/backup context, and printable-document behavior.

Search counts are inventory evidence only. They are not scope authorization.

## 5. Current architectural seams

Current accepted boundary assets are:

- `ApplicationScope` exposing one `ApplicationBoundary` to presentation;
- typed `ApplicationQueries` for audit logs, document history, product catalog,
  and business-logo bytes;
- exact shared repository capture in `ApplicationDependencies` through the
  legacy bridge;
- local result metadata with `sqlite` and `managedFile` authority; and
- Phase 108J's separate server-authoritative expense command path, whose
  confirmed/provisional semantics must not be conflated with local queries.

Remaining seams include:

- direct managed-file logo reads in `BusinessIdentityHeader`, settings, the
  printable scaffold, exports, and financial-report export helpers;
- SQLite list reads for expenses and suppliers;
- customer visible loading combining directory, balances, and opening-balance
  state;
- financial-account lists and derived statements;
- multi-repository dashboards and daily/financial reports; and
- many mixed read/write consumers whose locator references cannot be removed
  honestly by migrating one read.

Phase 108L changes the ranking: three remaining pure logo consumers can now
reuse an already composed query exactly. No new query contract, dependency
slot, composition wiring, authority enum, schema, or package is required for
those candidates.

## 6. Historical Phase 108M governance reconciliation

### H1 — Phase 108A Android platform foundation

`docs/phase-108a/PHASE-108A-COMPREHENSIVE-REAUDIT-AND-REORDERED-ROADMAP.md`
assigned Phase 108M to Android product identity, signing, secure platform
configuration, lifecycle, and capability interfaces after a cloud/offline
sequence. The accepted 108E–108L lineage did not realize that prerequisite
sequence under those identifiers.

```text
CLASSIFICATION = NOT_APPLICABLE_TO_CURRENT_LINEAGE
PRESERVED_INTENT = DEFER_AS_UNNUMBERED_FUTURE_WORK
```

The Android capability remains possible future work, but it is not a
still-governing identifier assignment for this lineage.

### H2 — Phase 108D residual UI locator cleanup

`docs/phase-108d/PHASE-108D-APPLICATION-COMMAND-QUERY-BOUNDARY-AND-COMPOSITION-ROOT-CONTRACT-FREEZE.md`
assigned Phase 108M broadly to removing residual UI service-locator coupling,
including static report capture and screen-local service construction.

```text
CLASSIFICATION = ACCEPT_WITH_RESCOPING
```

The direction remains legitimate, but the bundle violates the later locked
strategy of one smallest independently reviewable slice. The selected shared
header read advances that direction without authorizing broad cleanup.

### H3 — Divergent local-only fourth-query lineage

Local commit `bd6a0fadc3c05b9a36c00c387552fe3178d799c1`, subject
`PHASE 108M: migrate business identity header logo read query`, has parent
`83091e6ce87f983239339798a6a824e4abb93154`. Its lineage diverged from the
governing branch before the current 108J–108L chain; it is not an ancestor of
the governing HEAD, the governing HEAD is not its ancestor, and no remote
branch contains that exact local-only Phase 108M ref. Its implementation and
closure artifact were produced against a different phase sequence.

```text
CLASSIFICATION = ACCEPT_WITH_RESCOPING
ACCEPTED_EVIDENCE = the shared BusinessIdentityHeader logo read is atomic and can reuse the existing businessLogo query
REJECTED_AUTHORITY = its commit, baseline, implementation status, test counts, and Phase 108N recommendation are not governing current state
```

Fresh current-source discovery independently reaches the same narrow product,
but only as a new governance decision. No old source or commit is reused.

### Identifier conclusion

No authoritative locked artifact mandates a different next identifier. The
historical assignments are reconciled rather than erased, and there is no
`BLOCKED_PHASE_108M_GOVERNANCE_IDENTIFIER_CONFLICT` condition.

## 7. Candidate inventory

The following are the serious current candidates. `UI_CHANGE_REQUIRED` means
a later implementation would change only presentation resolution, not visual
design.

### C2 — Shared `BusinessIdentityHeader` logo bytes

```text
CANDIDATE_ID = C2_SHARED_BUSINESS_IDENTITY_HEADER_LOGO
USER_VISIBLE_AREA = shared branding header in dashboard layouts and Settings identity preview
CURRENT_READ_OR_COMMAND_PATH = BusinessIdentityHeader._IdentityLogo -> AppRepositories.businessIdentityRepository.loadLogoBytes -> managed local file
PROPOSED_BOUNDARY_PATH = BusinessIdentityHeader._IdentityLogo -> ApplicationScope.queries.businessLogo -> existing LoadBusinessLogoQueryHandler -> exact captured BusinessIdentityRepository -> same managed local file
READ_ONLY = YES
WRITE_PATH_TOUCHED = NO
DATA_AUTHORITY = local managed file
CONSISTENCY_SEMANTICS = currentKnownState
SCHEMA_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
NEW_APPLICATION_CONTRACT_REQUIRED = NO
CONTROLLER_CHANGE_REQUIRED = NO
UI_CHANGE_REQUIRED = YES_RESOLUTION_ONLY
GENERATED_FILES_REQUIRED = NO
ESTIMATED_CHANGE_RADIUS = one production consumer plus focused/current architecture test harnesses
ESTIMATED_TEST_SURFACE = existing query identity/provenance, Phase 96 header behavior, dashboard/settings render sites, no-write guards, locator inventory
ARCHITECTURAL_VALUE = HIGH; closes one complete shared presentation-to-managed-file seam and removes one locator consumer
DATA_RISK = VERY_LOW
FINANCIAL_RISK = NONE
REGRESSION_RISK = LOW_TO_MODERATE because logo-rendering historical harnesses lack ApplicationScope
DEPENDENCIES = existing businessLogo query and existing exact businessIdentityRepository capture
ATOMICITY = HIGH
PATTERN_REUSE = EXACT_PHASE_108L_REUSE
DISPOSITION = ACCEPT
```

### C3 — Settings `_LogoPreview` bytes

```text
CANDIDATE_ID = C3_SETTINGS_LOGO_PREVIEW
USER_VISIBLE_AREA = Settings logo upload/remove preview
CURRENT_READ_OR_COMMAND_PATH = SettingsScreen._LogoPreview -> AppRepositories.businessIdentityRepository.loadLogoBytes -> managed local file
PROPOSED_BOUNDARY_PATH = SettingsScreen._LogoPreview -> ApplicationScope.queries.businessLogo -> existing handler -> exact captured repository -> managed local file
READ_ONLY = YES
WRITE_PATH_TOUCHED = NO_IF_STRICTLY_ISOLATED
DATA_AUTHORITY = local managed file
CONSISTENCY_SEMANTICS = currentKnownState
SCHEMA_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
NEW_APPLICATION_CONTRACT_REQUIRED = NO
CONTROLLER_CHANGE_REQUIRED = NO
UI_CHANGE_REQUIRED = YES_RESOLUTION_ONLY
GENERATED_FILES_REQUIRED = NO
ESTIMATED_CHANGE_RADIUS = one mixed read/write production screen plus focused settings tests
ESTIMATED_TEST_SURFACE = preview bytes/null/error plus upload/delete/save negative controls and Settings harness scope
ARCHITECTURAL_VALUE = MEDIUM_HIGH; closes one direct managed-file read
DATA_RISK = LOW because adjacent logo mutations must remain untouched
FINANCIAL_RISK = NONE
REGRESSION_RISK = LOW_TO_MODERATE_MUTATION_ADJACENCY
DEPENDENCIES = existing businessLogo query and Settings ApplicationScope at production runtime
ATOMICITY = HIGH only if upload/delete/identity paths remain frozen
PATTERN_REUSE = EXACT_PHASE_108L_REUSE
DISPOSITION = DEFER
```

### C4 — Expenses-screen expense list

```text
CANDIDATE_ID = C4_EXPENSE_LIST
USER_VISIBLE_AREA = ExpensesScreen confirmed expense list
CURRENT_READ_OR_COMMAND_PATH = ExpensesScreen -> ApplicationScope.dependencies.repositories.expenseRepository -> ExpenseController.loadExpenses -> ExpenseRepository.listExpenses -> SQLite confirmed projection
PROPOSED_BOUNDARY_PATH = ExpensesScreen -> ApplicationScope.queries -> new typed expense-list handler -> same captured ExpenseRepository -> SQLite confirmed projection
READ_ONLY = YES
WRITE_PATH_TOUCHED = NO_IN_TARGET; adjacent Phase 108J command refresh must remain unchanged
DATA_AUTHORITY = local SQLite confirmed expense projection
CONSISTENCY_SEMANTICS = currentKnownState after successful confirmed projection; provisional attempts are not list rows
SCHEMA_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
NEW_APPLICATION_CONTRACT_REQUIRED = YES
CONTROLLER_CHANGE_REQUIRED = YES_LIKELY
UI_CHANGE_REQUIRED = YES_RESOLUTION_ONLY
GENERATED_FILES_REQUIRED = NO
ESTIMATED_CHANGE_RADIUS = application query/boundary/composition, controller/presentation, and financial regression tests
ESTIMATED_TEST_SURFACE = list parity, ordering, permission include behavior, command success refresh, confirmedProjectionPending, retry/idempotency, no-write query guard
ARCHITECTURAL_VALUE = HIGH
DATA_RISK = MODERATE because list truth is coupled to confirmed projection timing
FINANCIAL_RISK = MODERATE
REGRESSION_RISK = MODERATE
DEPENDENCIES = locked Phase 108J confirmed/provisional semantics
ATOMICITY = HIGH if limited to list read, but semantically more sensitive than managed-file candidates
PATTERN_REUSE = HIGH_BUT_REQUIRES_NEW_QUERY
DISPOSITION = DEFER
```

### C5 — Suppliers-screen supplier directory

```text
CANDIDATE_ID = C5_SUPPLIER_LIST
USER_VISIBLE_AREA = SuppliersScreen directory rows
CURRENT_READ_OR_COMMAND_PATH = SuppliersScreen -> SupplierController.loadSuppliers -> SupplierRepository.listSuppliers plus separate SupplierAccountRepository balances/opening entries
PROPOSED_BOUNDARY_PATH = list-only path through a typed query -> exact supplier repository -> SQLite suppliers; balances remain separate
READ_ONLY = YES
WRITE_PATH_TOUCHED = NO_IF_LIST_ONLY
DATA_AUTHORITY = local SQLite suppliers for directory; separate local SQLite account state for visible balances
CONSISTENCY_SEMANTICS = currentKnownState across independently loaded directory and account reads
SCHEMA_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = YES; supplier repository is not captured in ApplicationDependencies
NEW_APPLICATION_CONTRACT_REQUIRED = YES
CONTROLLER_CHANGE_REQUIRED = YES_LIKELY
UI_CHANGE_REQUIRED = YES_RESOLUTION_ONLY
GENERATED_FILES_REQUIRED = NO
ESTIMATED_CHANGE_RADIUS = dependency/bridge/composition, query, controller/presentation, and supplier/account tests
ESTIMATED_TEST_SURFACE = includeInactive parity, ordering, CRUD refresh, balance/opening-state coexistence, dependency identity
ARCHITECTURAL_VALUE = MEDIUM_HIGH
DATA_RISK = LOW_TO_MODERATE
FINANCIAL_RISK = MODERATE because the visible screen combines supplier account state and payment actions
REGRESSION_RISK = MODERATE
DEPENDENCIES = new exact supplier dependency capture and an explicit list-only ownership decision
ATOMICITY = MEDIUM; repository read is atomic but visible loading is composite
PATTERN_REUSE = MEDIUM_HIGH
DISPOSITION = DEFER
```

### C6 — Customers-screen visible load

```text
CANDIDATE_ID = C6_CUSTOMER_VISIBLE_LOAD
USER_VISIBLE_AREA = CustomersScreen directory with balances and opening-balance affordances
CURRENT_READ_OR_COMMAND_PATH = CustomerController.loadCustomers -> CustomerRepository.listCustomers + CustomerAccountRepository.balancesByCustomerId + per-customer hasOpeningBalanceEntry
PROPOSED_BOUNDARY_PATH = unresolved composite query or deliberately separated list query
READ_ONLY = YES
WRITE_PATH_TOUCHED = NO_IN_LOAD, but the same controller refreshes after collections, advances, CRUD, and opening-balance writes
DATA_AUTHORITY = local SQLite customer and customer-account state
CONSISTENCY_SEMANTICS = multi-read currentKnownState with no frozen snapshot guarantee
SCHEMA_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = YES
NEW_APPLICATION_CONTRACT_REQUIRED = YES
CONTROLLER_CHANGE_REQUIRED = YES
UI_CHANGE_REQUIRED = YES_RESOLUTION_ONLY
GENERATED_FILES_REQUIRED = NO
ESTIMATED_CHANGE_RADIUS = multiple dependencies/contracts plus controller and broad customer financial tests
ESTIMATED_TEST_SURFACE = customers, balances, opening balances, collections, advances, CRUD refresh, partial-failure semantics
ARCHITECTURAL_VALUE = HIGH_IF_CORRECTLY_RESCOPED
DATA_RISK = MODERATE
FINANCIAL_RISK = MODERATE_TO_HIGH
REGRESSION_RISK = HIGHER_THAN_C2_C5
DEPENDENCIES = customer and customer-account ownership plus consistency decision
ATOMICITY = LOW_UNTIL_RESCOPED
PATTERN_REUSE = MEDIUM
DISPOSITION = DEFER_PENDING_RESCOPING
```

### C7 — Financial-account list or statement

```text
CANDIDATE_ID = C7_FINANCIAL_ACCOUNT_LIST_OR_STATEMENT
USER_VISIBLE_AREA = FinancialAccountsScreen or FinancialAccountStatementScreen
CURRENT_READ_OR_COMMAND_PATH = screen/controller -> FinancialAccountRepository.listAccounts/accountById/statementForAccount -> SQLite-backed hydrated financial state -> derived balances/date filtering
PROPOSED_BOUNDARY_PATH = typed financial query with explicit result/consistency contract -> exact captured FinancialAccountRepository
READ_ONLY = YES
WRITE_PATH_TOUCHED = NO_IN_TARGET
DATA_AUTHORITY = local SQLite-backed financial ledger state
CONSISTENCY_SEMANTICS = derived currentKnownState; statement opening/final balances depend on date filters and ordered entries
SCHEMA_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO for repository capture, but a new query contract is required
NEW_APPLICATION_CONTRACT_REQUIRED = YES
CONTROLLER_CHANGE_REQUIRED = YES_LIKELY
UI_CHANGE_REQUIRED = YES_RESOLUTION_ONLY
GENERATED_FILES_REQUIRED = NO
ESTIMATED_CHANGE_RADIUS = query/boundary/composition, controller/screen, broad financial tests
ESTIMATED_TEST_SURFACE = account identity, active filtering, statement ordering, opening/final balances, transfers, closings, negative-balance regression
ARCHITECTURAL_VALUE = HIGH
DATA_RISK = HIGHER
FINANCIAL_RISK = HIGH
REGRESSION_RISK = HIGH
DEPENDENCIES = explicit financial consistency and derivation policy
ATOMICITY = MEDIUM
PATTERN_REUSE = HIGH_STRUCTURALLY, LOW_SEMANTIC_SIMPLICITY
DISPOSITION = DEFER
```

### C8 — Dashboard or report aggregate

```text
CANDIDATE_ID = C8_DASHBOARD_OR_REPORT_AGGREGATE
USER_VISIBLE_AREA = dashboard guidance/alerts or daily/financial reports
CURRENT_READ_OR_COMMAND_PATH = presentation-created service/controller -> three to seven repositories -> SQLite/local delegates -> derived inventory/accounting result
PROPOSED_BOUNDARY_PATH = typed aggregate query with captured aggregate/exact dependencies and explicit consistency contract
READ_ONLY = YES_WITH_POSSIBLE_LAZY_IN_MEMORY_HYDRATION
WRITE_PATH_TOUCHED = NO_PERSISTENT_WRITE_IN_OBSERVED_LOADS
DATA_AUTHORITY = derived local SQLite current state across multiple authorities
CONSISTENCY_SEMANTICS = no atomic multi-repository snapshot currently proven
SCHEMA_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = YES_OR_EXACT_AGGREGATE_CAPTURE_REQUIRED
NEW_APPLICATION_CONTRACT_REQUIRED = YES
CONTROLLER_CHANGE_REQUIRED = POSSIBLE
UI_CHANGE_REQUIRED = YES_RESOLUTION_ONLY
GENERATED_FILES_REQUIRED = NO
ESTIMATED_CHANGE_RADIUS = LARGE_MULTI_FEATURE
ESTIMATED_TEST_SURFACE = inventory, sales, purchases, expenses, customer/supplier accounts, cancellations, valuation, dashboard/report UI
ARCHITECTURAL_VALUE = HIGH_IN_ABSTRACT
DATA_RISK = HIGHER
FINANCIAL_RISK = HIGH
REGRESSION_RISK = HIGH
DEPENDENCIES = multi-repository consistency and result ownership
ATOMICITY = LOW
PATTERN_REUSE = MEDIUM
DISPOSITION = REJECT_FOR_PHASE_108M
```

### C9 — Broad boundary/repository cleanup

```text
CANDIDATE_ID = C9_BROAD_LOCATOR_OR_DI_CLEANUP
USER_VISIBLE_AREA = repository-wide
CURRENT_READ_OR_COMMAND_PATH = 39 presentation consumers and 145 locator references with mixed read/write ownership
PROPOSED_BOUNDARY_PATH = generalized repository DI/service-locator eradication
READ_ONLY = MIXED
WRITE_PATH_TOUCHED = YES_LIKELY
DATA_AUTHORITY = MIXED
CONSISTENCY_SEMANTICS = MIXED_AND_UNRESOLVED
SCHEMA_CHANGE_REQUIRED = UNKNOWN
DATABASE_CHANGE_REQUIRED = POSSIBLE
SUPABASE_CHANGE_REQUIRED = NOT_REQUIRED_BUT_EASILY_CONFLATED
NEW_DEPENDENCY_REQUIRED = BROAD
NEW_APPLICATION_CONTRACT_REQUIRED = BROAD
CONTROLLER_CHANGE_REQUIRED = BROAD
UI_CHANGE_REQUIRED = BROAD
GENERATED_FILES_REQUIRED = POSSIBLE
ESTIMATED_CHANGE_RADIUS = REPOSITORY_WIDE
ESTIMATED_TEST_SURFACE = FULL_REPOSITORY
ARCHITECTURAL_VALUE = HIGH_IN_ABSTRACT
DATA_RISK = HIGH
FINANCIAL_RISK = HIGH
REGRESSION_RISK = HIGH
DEPENDENCIES = unresolved ownership across many features
ATOMICITY = NONE
PATTERN_REUSE = LOW_FOR_ONE_PHASE
DISPOSITION = REJECT
```

### C10 — Printable-document scaffold logo bytes (newly re-ranked)

```text
CANDIDATE_ID = C10_PRINTABLE_DOCUMENT_SCAFFOLD_LOGO
USER_VISIBLE_AREA = shared printable sale/purchase invoices, customer/supplier statements, and daily report
CURRENT_READ_OR_COMMAND_PATH = PrintableDocumentScaffold._PrintableLogo -> AppRepositories.businessIdentityRepository.loadLogoBytes -> managed local file
PROPOSED_BOUNDARY_PATH = _PrintableLogo -> ApplicationScope.queries.businessLogo -> existing handler -> exact captured repository -> managed local file
READ_ONLY = YES
WRITE_PATH_TOUCHED = NO
DATA_AUTHORITY = local managed file
CONSISTENCY_SEMANTICS = currentKnownState
SCHEMA_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
SUPABASE_CHANGE_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
NEW_APPLICATION_CONTRACT_REQUIRED = NO
CONTROLLER_CHANGE_REQUIRED = NO
UI_CHANGE_REQUIRED = YES_RESOLUTION_ONLY
GENERATED_FILES_REQUIRED = NO
ESTIMATED_CHANGE_RADIUS = one production scaffold but five printable views and at least 17 direct historical test constructions
ESTIMATED_TEST_SURFACE = all five print views, image bytes/null/error, PDF/WhatsApp callbacks, small viewport/navigation, scope harnesses
ARCHITECTURAL_VALUE = HIGH; closes one shared print-branding read
DATA_RISK = VERY_LOW
FINANCIAL_RISK = LOW_DATA_MUTATION_RISK but statements/reports broaden regression consequences
REGRESSION_RISK = MODERATE due wide rendering and scope-free harness surface
DEPENDENCIES = existing businessLogo query
ATOMICITY = HIGH_AT_READ_LEVEL
PATTERN_REUSE = EXACT_PHASE_108L_REUSE
DISPOSITION = DEFER
```

Export services and financial-report export helpers were also inspected. They
load both identity metadata and logo bytes inside broader PDF/export flows, so
moving only the byte call would not close the full presentation/export
persistence seam. They are deferred as part of future deliberately rescoped
branding/export work, not promoted over C2.

## 8. Candidate comparison

| Candidate | Exact established reuse | Atomicity | New production contract | Data/financial risk | Regression radius | Disposition |
|---|---|---|---|---|---|---|
| C2 shared header logo | exact | high | none | very low / none | smaller shared-widget surface | **ACCEPT** |
| C3 settings preview | exact | high if isolated | none | low / none | mixed write-adjacent screen | DEFER |
| C4 expense list | high | high | required | moderate / moderate | financial command refresh | DEFER |
| C5 supplier list | medium-high | medium | required | moderate / moderate | composite visible load | DEFER |
| C6 customer load | medium | low | required | moderate / high | broad composite/controller | DEFER_PENDING_RESCOPING |
| C7 financial list/statement | structural only | medium | required | high / high | broad financial | DEFER |
| C8 aggregates/reports | medium | low | required | high / high | large | REJECT_FOR_PHASE_108M |
| C9 broad cleanup | low | none | broad | high / high | repository-wide | REJECT |
| C10 printable logo | exact | high | none | very low / low | five views and many harnesses | DEFER |

## 9. Rejected/deferred candidates

- C3 is smaller than database-backed work but sits directly beside logo
  upload/delete and identity-save behavior; C2 is cleaner.
- C4 remains semantically subordinate to Phase 108J confirmed/provisional
  posting and projection refresh behavior.
- C5 cannot be described as the whole visible supplier load because balances
  and opening-balance state come from a separate repository.
- C6 is explicitly not a simple list query.
- C7 is vetoed by financial derivation and consistency risk.
- C8 hides high-fan-out multi-repository behavior behind syntactically small
  locator sites.
- C9 violates the one-slice governing strategy.
- C10 is technically feasible with exact reuse, but its five printable views
  and larger scope-free test surface make it a wider regression product than
  C2.
- export/report branding loaders combine identity metadata, logo bytes, and
  output generation; a byte-only move would be incomplete seam closure.

No newly exposed candidate is smaller, safer, and more coherent than C2.

## 10. Canonical scope decision

```text
CANONICAL_PHASE_108M_SCOPE =
ONE_LOCAL_READ_ONLY_SHARED_BUSINESS_IDENTITY_HEADER_LOGO_UI_QUERY_MIGRATION_THROUGH_EXISTING_APPLICATION_BOUNDARY
```

Human-readable decision: a later Phase 108M implementation may migrate only
the managed logo-byte read performed by
`BusinessIdentityHeader._IdentityLogo` through the already existing
`businessLogo` application query.

This decision does not authorize implementation in this session.

## 11. Why this candidate wins

**DECISION:** C2 is the smallest truthful product that advances the accepted
lineage.

- It closes one complete presentation-to-persistence seam in one consumer
  file.
- Phase 108L already provides the exact request, handler, result metadata,
  boundary exposure, dependency capture, and production composition.
- The handler's repository is the same captured
  `AppRepositories.businessIdentityRepository` instance.
- The read is a filename-validated `File.exists`/`File.readAsBytes` operation;
  it has no database, accounting, inventory, auth, or command semantics.
- The header preserves explicit empty-name, missing-file, exception, null,
  invalid-image, dimensions, and `BoxFit.contain` fallbacks.
- Production dashboard and settings render sites already live below the
  application scope. Historical direct widget harnesses are a known focused
  test cost, not an architecture expansion.
- It is narrower than printable branding and cleaner than the settings
  write-adjacent preview.

## 12. Exact current architectural path

```text
BusinessIdentityHeader
  -> _IdentityLogo._loadBytes
  -> AppRepositories.businessIdentityRepository
  -> same LocalBusinessIdentityRepository used by production composition
  -> loadLogoBytes(managedFileName)
  -> filename validation
  -> managed local logo file
```

The logo metadata arrives through `BusinessIdentityScope`; only the byte read
bypasses the application boundary. Empty names return `null`; exceptions are
caught and hidden; missing/invalid bytes render no image.

## 13. Exact target architectural path

```text
BusinessIdentityHeader._IdentityLogo
  -> ApplicationScope.of(context).queries.businessLogo
  -> LoadBusinessLogoQuery(managedFileName)
  -> LoadBusinessLogoQueryHandler.execute
  -> ApplicationDependencies.repositories.businessIdentityRepository
  -> exact same captured BusinessIdentityRepository instance
  -> LocalBusinessIdentityRepository.loadLogoBytes
  -> same managed local logo file
```

No new handler, query, result type, dependency, composition object, controller,
repository, file authority, or persistence adapter is justified.

## 14. Data authority and consistency semantics

```text
SOURCE = QueryResultSource.local
READ_AUTHORITY = LocalReadAuthority.managedFile
CONSISTENCY = LocalQueryConsistency.currentKnownState
TENANT_SCOPE = NONE_IN_CURRENT_LOCAL_FILE_MODEL
CLOUD_AUTHORITY = NONE
SERVER_AUTHORITY = NONE
DATABASE_AUTHORITY = NONE_FOR_THIS_READ
```

The target must pass the managed filename verbatim to the existing handler.
The existing repository validation, bytes/null/exception behavior, and object
identity must remain unchanged. `currentKnownState` promises only the current
local managed-file state; it does not invent synchronization or freshness.

## 15. Allowed implementation surface

A later planning session may consider only these categories:

- the selected `BusinessIdentityHeader` presentation read resolution;
- reuse of the existing `LoadBusinessLogoQuery` and registered handler;
- focused query/widget/composition identity tests and no-write negative
  controls;
- updates to current live architecture inventory assertions strictly required
  by the one-consumer/one-reference migration; and
- focused historical widget harness changes needed to provide the existing
  application scope when a valid logo is rendered.

The expected locator inventory delta is exactly:

```text
39 consumers / 145 literal references
  -> 38 consumers / 144 literal references
```

The later planning session must prove the exact test-file list. This artifact
does not pre-authorize particular line edits or commits.

## 16. Explicit non-goals

Phase 108M may not include:

- dashboard app-bar work already completed by Phase 108L;
- settings `_LogoPreview`, logo upload, logo delete, identity load/save, or
  profile editing;
- printable-document, PDF, export, financial-report, or invoice branding;
- a second logo consumer or any second query migration;
- modification of `LoadBusinessLogoQuery`, its metadata, or repository contract
  unless a future planning blocker proves the locked reuse assumption false;
- new dependency capture or application composition redesign;
- expense, supplier, customer, financial-account, dashboard, statement, or
  report queries;
- broad `AppRepositories` cleanup or service-locator eradication;
- controller ownership redesign, repository interface redesign, DI framework,
  query bus, command bus, event bus, or cache layer;
- database/SQLite schema or data changes;
- Supabase, cloud, auth, RLS, storage, Edge Function, or sync work;
- generated files, dependencies, Flutter/Dart upgrades, performance work, UI
  redesign, business behavior changes, or branch migration; and
- modification of any historical governance or planning artifact.

## 17. Expected validation surface

A future implementation plan must determine the minimal exact commands while
covering:

- existing `LoadBusinessLogoQueryHandler` bytes/null/exception behavior and
  managed-file metadata;
- exact production repository identity and no replacement capture;
- `BusinessIdentityHeader` valid bytes, null/missing file, exception, empty
  filename, invalid image, sizing, and fit behavior;
- zero calls to `saveIdentity`, `saveLogoBytes`, and `deleteLogoFile`;
- dashboard and settings shared-header render sites;
- Phase 108L dashboard app-bar regression and four-query singularity history;
- exact one-consumer/one-reference locator inventory delta;
- formatter, analyzer, focused tests, diff checks, and clean-tree/source-scope
  gates; and
- full-suite execution only if justified by the later planning contract and
  environment.

## 18. Governance invariants

```text
ONE_PHASE = ONE_SHARED_HEADER_LOGO_READ_SEAM
EXACT_EXISTING_QUERY_REUSE = REQUIRED
EXACT_REPOSITORY_INSTANCE_REUSE = REQUIRED
READ_ONLY = REQUIRED
MANAGED_FILENAME_BEHAVIOR = PRESERVED
BYTES_NULL_EXCEPTION_BEHAVIOR = PRESERVED
UI_LAYOUT_AND_ERROR_FALLBACK = PRESERVED
WRITE_PATHS = UNCHANGED
DATABASE_AND_SUPABASE = UNCHANGED
SECOND_CONSUMER = FORBIDDEN
BROAD_LOCATOR_CLEANUP = FORBIDDEN
```

If planning proves that the selected consumer cannot use the registered query
without architecture expansion, the phase must block and return to governance
rather than broaden silently.

## 19. Remote/database/Supabase mutation declarations

```text
REMOTE_MUTATION = NONE
TAG_MUTATION = NONE
DATABASE_MUTATION = NONE
SUPABASE_MUTATION = NONE

MERGE = NONE
REBASE = NONE
CHERRY_PICK = NONE
RESET = NONE
FORCE_PUSH = NONE
HISTORY_REWRITE = NONE
```

Repository SQL and Supabase-related source were inspected only as static local
evidence. No database or Supabase connection, query, CLI mutation, migration,
or remote schema action occurred.

## 20. Planning questions that remain open

Planning is not started. A later authorized planning session must answer:

1. Which existing header widget harnesses render a valid logo without an
   `ApplicationScope`, and what is the smallest truthful shared test harness?
2. Which current architecture inventories are live-tree assertions rather than
   immutable historical-baseline assertions?
3. What focused negative control best proves all business-identity write
   methods remain untouched?
4. What exact focused test set proves both dashboard and settings header render
   sites without dragging printable/export behavior into scope?
5. Is full-suite validation proportionate after focused and architecture gates,
   given the locked documentation-only governance result?

These questions may refine validation mechanics only. They may not change the
canonical product without a new governance decision.

## 21. Local closure requirements

This governance session closes locally only when:

- this is the sole changed and staged file;
- `git diff --check` and `git diff --cached --check` pass;
- protected historical blobs remain exact;
- one normal non-merge commit with subject
  `Phase 108M: discover and freeze canonical scope` is created directly on
  `f0e53febb3bba0f5c9aaa348702c78d3feeee96d`;
- the commit contains exactly this file;
- worktree, index, untracked set, and stash are empty afterward;
- the remote branch remains at the Phase 108L implementation commit; and
- local divergence is ahead 1, behind 0.

No governance tag is created locally in this session.

## 22. Next authorized session

```text
NEXT_AUTHORIZED_SESSION = PHASE_108M_GOVERNANCE_RECONCILIATION_REMOTE_LOCK
EXPECTED_FUTURE_TAG = phase-108m-governance-reconciliation-locked
PHASE_108M_PLANNING = NOT_STARTED
PHASE_108M_IMPLEMENTATION = NOT_STARTED
```

The remote-lock session is separate and may only verify and lock this local
governance result under explicit authorization. It may not plan or implement
Phase 108M.

## 23. Governance-session validation record

Source assumptions were checked with existing tests before this artifact was
written:

```text
FOCUSED_TESTS = 70 passed / 0 failed
FILES = phase96 branding, phase108l business-logo query, phase13 settings/backup,
        phase40 printable documents, phase91 printable scaffold
CLASSIFICATION = PASS
```

Static gates:

```text
DART_FORMAT = PASS; same Flutter-bundled Dart SDK 3.5.4; 459 files; 0 changed
FLUTTER_ANALYZE = PASS; no issues found; 36.9 seconds
```

The `dart` batch wrapper produced no output for 60 seconds, reproducing the
pre-existing wrapper-lock condition recorded by Phase 108L. Only that wrapper
process was interrupted. The equivalent command then ran through
`C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe`, the same bundled SDK, with no
source modification, installation, or PATH reconfiguration.

```text
WRAPPER_FAILURE_CLASSIFICATION = ENVIRONMENTAL
SAME_FLUTTER_SDK = YES
SAME_BUNDLED_DART_SDK = YES
SOURCE_MODIFICATION_FOR_WORKAROUND = NO
TOOLCHAIN_INSTALLATION = NO
PATH_RECONFIGURATION = NO
```

Final diff, staged diff, protected-blob, commit-topology, worktree, stash, and
remote-state checks are performed by the local closure procedure after this
artifact is finalized.
