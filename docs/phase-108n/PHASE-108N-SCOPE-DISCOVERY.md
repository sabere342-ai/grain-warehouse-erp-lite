# Phase 108N — Scope Discovery and Governance Reconciliation

## 1. Session status

This artifact records repository-forensic scope discovery only. It does not
plan or implement Phase 108N.

```text
PASS_PHASE_108N_SCOPE_DISCOVERY_CANONICAL_SCOPE_IDENTIFIED
PHASE_108N_SCOPE_DISCOVERY = COMPLETE
PHASE_108N_GOVERNANCE_RECONCILIATION_LOCAL_CLOSURE = COMPLETE
PHASE_108N_GOVERNANCE_REMOTE_LOCK = NOT_STARTED
PHASE_108N_PLANNING = NOT_STARTED
PHASE_108N_IMPLEMENTATION = NOT_STARTED
```

## 2. Governing baseline and repository identity

The entry gate was verified before this artifact was created.

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git

ENTRY_HEAD = d31d6897053829d052199aa44da7a7e114e951fc
ENTRY_REMOTE_HEAD = d31d6897053829d052199aa44da7a7e114e951fc
AHEAD = 0
BEHIND = 0
WORKTREE = CLEAN
INDEX = EMPTY
UNTRACKED = NONE
STASH = EMPTY
ENTRY_CLASSIFICATION = CASE_A_FRESH_SCOPE_DISCOVERY
```

`git fetch origin` completed before the local and remote branch values were
compared. No reset, rebase, checkout, stash, clean, merge, cherry-pick, or
history rewrite was used.

## 3. Governing Phase 108M lock

The local annotated tag, its object, its peeled target, the remote tag, the
remote peeled target, and the implementation commit parent all match the
authorized baseline.

```text
PHASE_108M_IMPLEMENTATION_COMMIT =
d31d6897053829d052199aa44da7a7e114e951fc

PHASE_108M_IMPLEMENTATION_PARENT =
ee6cff89205bbd964ba2638c7e3953a9440275ba

PHASE_108M_IMPLEMENTATION_TAG =
phase-108m-implementation-locked

TAG_TYPE = tag
TAG_OBJECT = 528d80efa1f7e63012a853fff1e8f80c640c94fd
PEELED_TARGET = d31d6897053829d052199aa44da7a7e114e951fc
REMOTE_VERIFICATION = MATCH
```

The implementation commit is a normal one-parent commit with subject
`Phase 108M: migrate shared business identity header logo query`.

## 4. Phase 108F–108M lineage reconstruction

The accepted lineage is incremental application-boundary migration. It is not
the literal numbered sequence proposed by either Phase 108A or Phase 108D.

| Phase | Accepted commit(s) | Canonical objective and production surface | Boundary/behavior | Deferred or rejected work |
|---|---|---|---|---|
| 108F | `db84293213d99a79b23bf25b81b565c380aa4655` | Move the Audit Logs screen/controller read behind the first typed application query | Local SQLite, read-only; introduced `ApplicationScope`, the audit handler, dependency capture, and central query composition | Every other locator consumer and write path |
| 108G | `5c784d60e7879d18812893a9c9934856e680826e` | Establish session and business-context boundaries | Root-owned typed context providers; local session; `NoBusinessContextProvider` avoids inventing tenant identity | Cloud auth, fabricated business identity, and feature migrations |
| 108H | `f6ed0f8dc7fbb69c763115f4c66502b0d3dcb4c7` | Centralize app-shell runtime ownership | Composition root owns auth, theme, and business-identity controllers and injects the exact runtime objects | Feature-level repository/controller debt |
| 108I | plan `ca533e07dad7d36e2b17d0caa2c1740ee8fa9103`; implementation `6896cbd73b271631cda9b31666ab200a6dcac76a` | Move Document History behind the second typed query | Local derived SQLite read, exact repository reuse, read-only, behavior-preserving controller/screen migration | Backup/restore history consumers, writes, and other locator reads |
| 108J | governance `69eebcdac20bba12e9b75abaa99c9a2e02df5483`; plan `2c09062474c3bae590763a70b6e3214457c12725`; implementation/closure `6d04a57e188be7cd0bed9a1ae828f1d0d49ad239` / `951ed1cfe4e673f376dd9e270f2d7076fc8f1750` | Implement exactly one atomic, idempotent, server-authoritative expense-posting command | The deliberate command exception in the sequence; server transaction/gateway, local confirmed projection and attempt state | Other financial commands and any generic sync/outbox bundle |
| 108K | governance `bc1d37f430ae3708fe2cd4e3c93386f8fbecf1af`; plan `273640cba345a8fbfdd6a5e2f2e6b7bed74b8909`; implementation `2d6abc71decd618f02540873e5e0f389f5c17408` | Move only the Products screen catalog read behind a typed query | Local SQLite read, exact catalog read repository reuse; product writes remain on the existing write repository | Other catalog consumers, product writes, cloud catalog, broad locator cleanup |
| 108L | governance `2172ae49119a6194ab419b0157b5e1e811ba00f9`; plan `703180f05b0e836a9c2aa278eb01f0bbcab120e2`; implementation `f0e53febb3bba0f5c9aaa348702c78d3feeee96d` | Move only the Dashboard App Bar logo-byte read | Added `LoadBusinessLogoQuery`, managed-file authority metadata, exact repository composition, and one UI consumer migration | Shared header, settings preview, printable/export branding and all database-backed reads |
| 108M | governance `30b654099a79fca426a1467a501f7ef235d1e751`; plan `ee6cff89205bbd964ba2638c7e3953a9440275ba`; implementation `d31d6897053829d052199aa44da7a7e114e951fc` | Move only the shared `BusinessIdentityHeader` logo-byte read | Reused the existing 108L query and exact repository; local managed-file, read-only, no new contract | Settings preview, printable/export branding, other queries, and broad cleanup |

The governing architectural invariant established by this lineage is:

```text
PRESENTATION_RESOLVES_A_TYPED_APPLICATION_QUERY
  -> HANDLER_OWNS_THE_READ_PORT
  -> COMPOSITION_REUSES_THE_EXACT_PRODUCTION_DEPENDENCY
  -> EXISTING_DATA_AUTHORITY_AND_BEHAVIOR_ARE_PRESERVED
```

Phase 108J proves that commands can also enter the boundary, but it does not
turn a local read-only follow-up into a financial or cloud phase. From 108K
through 108M the proven selection strategy is one narrowly bounded UI read seam
per phase.

## 5. Evidence sources inspected

### Governance, plans, and inventories

- `docs/phase-108a/PHASE-108A-COMPREHENSIVE-REAUDIT-AND-REORDERED-ROADMAP.md`;
- `docs/phase-108d/PHASE-108D-APPLICATION-COMMAND-QUERY-BOUNDARY-AND-COMPOSITION-ROOT-CONTRACT-FREEZE.md`;
- Phase 108D `queries.tsv`, `architectural-violations.tsv`, and
  `composition-root-inventory.tsv`;
- the Phase 108F report and Phase 108I plan;
- the Phase 108J governance reconciliation and planning record;
- the Phase 108K governance and planning artifacts;
- the Phase 108L scope-discovery and planning artifacts;
- the Phase 108M scope-discovery and planning artifacts;
- current repository searches for `108N`, next-phase, deferred, migration,
  application-boundary, service-locator, repository, controller, and query
  references.

### Git history

- the accepted Phase 108F–108M commits and their changed-path inventories;
- the current branch and tag topology;
- the divergent historical Phase 108N commit
  `6bb4e0a57fd1715c3216c6411a1d17d335568204`, its parent
  `bd6a0fadc3c05b9a36c00c387552fe3178d799c1`, and its document/test artifacts;
- ancestry and merge-base comparison between that divergent commit and the
  governing branch.

### Current production source

- application boundary, dependencies, scope, composition root, and legacy
  dependency bridge;
- the existing business-logo query and local business-identity repository;
- Settings logo preview and printable-document logo loader;
- Expenses, Suppliers, Customers, financial accounts/statements, dashboard
  guidance/alerts, Reports, exports, and financial-report branding paths;
- every current `AppRepositories` reference under `lib/features` and
  `lib/shared`.

### Current tests inspected

- Phase 108F, 108G, 108H, 108I, 108J, 108K, 108L, and 108M focused tests;
- Phase 68 managed-logo repository tests;
- Phase 13 Settings harness;
- Phase 91 printable-document scaffold tests;
- Phase 95 business-profile tests; and
- Phase 96 app-shell business-identity branding tests.

Tests were inspected as evidence only. No test was changed and no test run is
claimed by this documentation-only discovery session.

## 6. Current repository evidence

### 6.1 Boundary assets already available

The current production graph already contains everything required by the
selected slice:

- `ApplicationScope` wraps the production app above `GrainWarehouseApp`;
- `ApplicationQueries.businessLogo` exposes the typed handler;
- `LoadBusinessLogoQuery` carries the managed filename;
- `LoadBusinessLogoQueryHandler` returns
  `ApplicationQueryResult<Uint8List?>` with
  `LocalReadAuthority.managedFile` and current-known-state semantics;
- `ApplicationDependencies.repositories.businessIdentityRepository` stores
  the exact production repository;
- `AppCompositionRoot` constructs the handler from that exact dependency; and
- the root-owned `BusinessIdentityController` uses the same production
  `BusinessIdentityRepository` instance.

No new request, handler, result, authority enum, dependency slot, composition
wiring, controller, repository, adapter, schema, or package is required.

### 6.2 Current locator inventory

The literal current inventory beneath `lib/features` and `lib/shared` is:

```text
CONSUMER_FILES = 38
LITERAL_APP_REPOSITORIES_REFERENCES = 144
```

A whitespace-tolerant multi-line inventory is:

```text
SEMANTIC_CONSUMER_FILES = 38
SEMANTIC_APP_REPOSITORIES_REFERENCES = 148
```

The selected Settings file contains exactly one literal/semantic reference and
uses no other `AppRepositories` member. A later correct implementation would
therefore have the bounded expected delta:

```text
LITERAL = 38/144 -> 37/143
SEMANTIC = 38/148 -> 37/147
```

These are discovery facts, not authorization to implement the delta now.

### 6.3 Selected read behavior

`SettingsScreen._LogoPreview._loadLogoBytes()` currently:

- returns `null` without a repository call for an empty managed filename;
- calls only `BusinessIdentityRepository.loadLogoBytes`;
- catches any exception and returns `null`;
- renders no widget while data is absent or null;
- renders `Image.memory` within maximum `80 x 200` constraints using
  `BoxFit.contain` when bytes are present; and
- hides invalid image bytes through the existing image error builder.

`LocalBusinessIdentityRepository.loadLogoBytes` validates the filename, checks
file existence, and reads bytes. It performs no file creation, file write,
delete, audit, database operation, transaction, cache mutation, cloud call, or
business mutation.

The containing Settings screen also owns identity and logo writes, but those
methods are separate from the private preview read and are explicitly frozen
out of Phase 108N.

## 7. Historical Phase 108N reconciliation

### 7.1 Phase 108A Android proposal

Phase 108A assigned 108N to `Android Navigation and Daily-Flow Acceptance`,
dependent on its then-defined Android Phase 108M and earlier cloud/offline
sequence. The accepted 108E–108M lineage used those identifiers for different
work and did not establish the semantic prerequisites of that Android entry.

```text
HISTORICAL_108A_PHASE_108N_DISPOSITION = SUPERSEDED
PRESERVED_INTENT = DEFER_AS_UNNUMBERED_FUTURE_WORK
```

Android navigation remains potentially valid future work, but the old number
is no longer authoritative for the current lineage.

### 7.2 Phase 108D broad residual-locator direction

Phase 108D broadly assigned residual UI service-locator cleanup and report
composition work to late Phase 108. Current code confirms that debt remains,
but the bundle mixes reads, writes, financial semantics, exports, and many
screens.

```text
HISTORICAL_108D_DIRECTION_DISPOSITION = ACCEPT_WITH_RESCOPING
```

The direction is preserved through one independently reviewable read seam; the
broad bundle is not accepted as Phase 108N.

### 7.3 Divergent local-only Phase 108N freeze

Commit `6bb4e0a57fd1715c3216c6411a1d17d335568204`, subject
`PHASE 108N: freeze fifth read-only UI query slice`, is not an ancestor of the
governing HEAD. Its merge base with the governing branch is
`deac34e7db2a5f6fd01f6fa7ff04020e308dfb6e`, and it was based on a divergent
Phase 108M commit rather than the locked current Phase 108M implementation.

That artifact selected the Settings logo preview as a future Phase 108O
migration. Current-source discovery independently confirms the candidate, but
several of the old artifact's facts are no longer governing: its baseline,
inventory counts, test counts, implementation state, repository-identity
distinction, and Phase 108O assignment.

```text
DIVERGENT_108N_DISPOSITION = ACCEPT_WITH_RESCOPING
ACCEPTED_EVIDENCE = SETTINGS_LOGO_PREVIEW_IS_AN_ATOMIC_READ_ONLY_CANDIDATE
REJECTED_AUTHORITY = COMMIT_BASELINE_RESULTS_COUNTS_AND_PHASE_108O_ASSIGNMENT
```

No divergent source, test, commit, or branch is copied or revived.

## 8. Remaining migration candidate inventory

### C1 — Settings logo-preview managed-file read

```text
CANDIDATE_ID = C1_SETTINGS_LOGO_PREVIEW
PRODUCTION_FILE = lib/features/settings/settings_screen.dart
UI_SURFACE = SettingsScreen._LogoPreview
CURRENT_QUERY_PATH = _LogoPreview -> AppRepositories.businessIdentityRepository.loadLogoBytes -> managed local file
TARGET_APPLICATION_BOUNDARY = existing ApplicationQueries.businessLogo
READ_ONLY_OR_MUTATING = READ_ONLY
BUSINESS_CRITICALITY = LOW
SIMILARITY_TO_108I_108K_108L_108M = EXACT_108L_108M_QUERY_REUSE
EXPECTED_SCOPE_SIZE = ONE_PRODUCTION_FILE_PLUS_FOCUSED_TESTS
DEPENDENCIES = ALL_ALREADY_CAPTURED_AND_COMPOSED
RISK = LOW_WITH_STRICT_WRITE_ISOLATION
TESTABILITY = HIGH
SCHEMA_DATABASE_CLOUD_CHANGE = NONE
DISPOSITION = ACCEPT
```

It closes one complete presentation-to-managed-file seam and removes one
locator consumer/reference without changing business behavior.

### C2 — Printable-document scaffold logo read

```text
CANDIDATE_ID = C2_PRINTABLE_DOCUMENT_SCAFFOLD_LOGO
PRODUCTION_FILE = lib/features/prints/printable_document_scaffold.dart
UI_SURFACE = shared sale/purchase/customer/supplier/daily-report printable views
CURRENT_QUERY_PATH = _PrintableLogo -> AppRepositories.businessIdentityRepository.loadLogoBytes -> managed local file
TARGET_APPLICATION_BOUNDARY = existing ApplicationQueries.businessLogo
READ_ONLY_OR_MUTATING = READ_ONLY
BUSINESS_CRITICALITY = LOW_DATA_RISK_BUT_BROAD_DOCUMENT_VISIBILITY
SIMILARITY_TO_108L_108M = EXACT_QUERY_REUSE
EXPECTED_SCOPE_SIZE = ONE_SHARED_FILE_BUT_FIVE_RENDERING_SURFACES_AND_MANY_HARNESSES
DEPENDENCIES = ALL_ALREADY_CAPTURED_AND_COMPOSED
RISK = MODERATE_REGRESSION_RADIUS
TESTABILITY = HIGH_BUT_BROAD
SCHEMA_DATABASE_CLOUD_CHANGE = NONE
DISPOSITION = DEFER
```

It is technically valid but is wider than C1 because one private loader feeds
five printable product surfaces and export/share-adjacent behavior.

### C3 — Confirmed expense list

```text
CANDIDATE_ID = C3_EXPENSE_LIST
PRODUCTION_FILES = expenses screen/controller plus application query composition
CURRENT_QUERY_PATH = ExpensesScreen -> ApplicationScope.dependencies.expenseRepository -> ExpenseController.loadExpenses -> listExpenses
TARGET_APPLICATION_BOUNDARY = new typed expense-list query
READ_ONLY_OR_MUTATING = READ_ONLY_TARGET_IN_WRITE_ADJACENT_CONTROLLER
BUSINESS_CRITICALITY = FINANCIAL
EXPECTED_SCOPE_SIZE = MULTIPLE_APPLICATION_CONTROLLER_UI_AND_TEST_FILES
DEPENDENCIES = repository already captured; new query contract required
RISK = MODERATE_CONFIRMED_PROJECTION_AND_REFRESH_SEMANTICS
TESTABILITY = HIGH_BUT_FINANCIAL
SCHEMA_DATABASE_CLOUD_CHANGE = NONE_FOR_READ
DISPOSITION = DEFER
```

The repository is already obtained through `ApplicationScope`, reducing the
immediate ownership defect. A new query must preserve Phase 108J confirmed and
provisional projection semantics, so it is not preferable to C1.

### C4 — Supplier directory list

```text
CANDIDATE_ID = C4_SUPPLIER_DIRECTORY
PRODUCTION_FILES = suppliers screen/controller plus new dependency/query composition
CURRENT_QUERY_PATH = SuppliersScreen -> SupplierController -> SupplierRepository.listSuppliers
TARGET_APPLICATION_BOUNDARY = new typed supplier-list query
READ_ONLY_OR_MUTATING = READ_ONLY_LIST_IN_MIXED_WRITE_SCREEN
BUSINESS_CRITICALITY = MODERATE
EXPECTED_SCOPE_SIZE = MEDIUM
DEPENDENCIES = new exact supplier repository capture and contract
RISK = MODERATE
TESTABILITY = HIGH
SCHEMA_DATABASE_CLOUD_CHANGE = NONE
DISPOSITION = DEFER
```

The visible screen also loads balances/opening entries and performs payments.
A list-only migration would leave other ownership seams in the same screen.

### C5 — Customer visible load

```text
CANDIDATE_ID = C5_CUSTOMER_VISIBLE_LOAD
PRODUCTION_FILES = customers screen/controller plus multiple dependency/query surfaces
CURRENT_QUERY_PATH = listCustomers + balancesByCustomerId + per-customer hasOpeningBalanceEntry
TARGET_APPLICATION_BOUNDARY = unresolved composite or deliberately split query
READ_ONLY_OR_MUTATING = READ_ONLY_LOAD_IN_BROAD_MUTATING_CONTROLLER
BUSINESS_CRITICALITY = FINANCIAL_ACCOUNT_STATE_VISIBLE
EXPECTED_SCOPE_SIZE = MEDIUM_TO_LARGE
DEPENDENCIES = customer and customer-account ownership/consistency decision
RISK = MODERATE_TO_HIGH
TESTABILITY = HIGH_BUT_BROAD
SCHEMA_DATABASE_CLOUD_CHANGE = NONE
DISPOSITION = DEFER_PENDING_RESCOPING
```

The current load is sequential and composite, so treating it as one simple
list query would be architecturally inaccurate.

### C6 — Financial-account list or statement

```text
CANDIDATE_ID = C6_FINANCIAL_ACCOUNT_LIST_OR_STATEMENT
PRODUCTION_FILES = financial account screen/controller or statement screen
CURRENT_QUERY_PATH = screen/controller -> captured FinancialAccountRepository -> balances/account/statement derivation
TARGET_APPLICATION_BOUNDARY = new typed financial query with explicit consistency contract
READ_ONLY_OR_MUTATING = READ_ONLY_TARGET_IN_MIXED_FINANCIAL_CONTROLLER
BUSINESS_CRITICALITY = HIGH
EXPECTED_SCOPE_SIZE = MEDIUM_WITH_BROAD_FINANCIAL_REGRESSION
DEPENDENCIES = exact repository already captured; new contract required
RISK = HIGH
TESTABILITY = HIGH
SCHEMA_DATABASE_CLOUD_CHANGE = NONE_FOR_READ
DISPOSITION = DEFER
```

Opening/final balances, ordering, filters, transfers, closings, and negative
balance behavior make this a riskier next slice.

### C7 — Supplier statement read

```text
CANDIDATE_ID = C7_SUPPLIER_STATEMENT
PRODUCTION_FILE = lib/features/supplier_accounts/supplier_statement_screen.dart
CURRENT_QUERY_PATH = screen-owned supplier-account repository -> statementForSupplier
TARGET_APPLICATION_BOUNDARY = new typed supplier-statement query
READ_ONLY_OR_MUTATING = READ_METHOD_ON_A_FIELD_ALSO_USED_FOR_PAYMENT_WRITES
BUSINESS_CRITICALITY = FINANCIAL
EXPECTED_SCOPE_SIZE = MEDIUM
DEPENDENCIES = new exact supplier-account capture/query and write-ownership separation
RISK = HIGH_FOR_AN_OSTENSIBLY_READ_ONLY_PHASE
TESTABILITY = MODERATE_TO_HIGH
SCHEMA_DATABASE_CLOUD_CHANGE = NONE_FOR_READ
DISPOSITION = DEFER_PENDING_WRITE_OWNERSHIP_SEPARATION
```

The locator cannot be removed honestly by migrating only the statement read
because the same captured field participates in payment behavior.

### C8 — Dashboard guidance aggregate

```text
CANDIDATE_ID = C8_DASHBOARD_GUIDANCE
PRODUCTION_FILE = lib/features/dashboard/dashboard_screen.dart
CURRENT_QUERY_PATH = presentation static loader -> catalog + inventory + sales repositories
TARGET_APPLICATION_BOUNDARY = new typed three-repository aggregate query
READ_ONLY_OR_MUTATING = READ_ONLY_WITH_POSSIBLE_LAZY_ADAPTER_HYDRATION
BUSINESS_CRITICALITY = MODERATE
EXPECTED_SCOPE_SIZE = MEDIUM
DEPENDENCIES = exact dependencies captured; new aggregate contract required
RISK = MODERATE
TESTABILITY = HIGH
SCHEMA_DATABASE_CLOUD_CHANGE = NONE
DISPOSITION = DEFER
```

It is coherent but needs a new aggregate model and multi-repository
consistency contract; C1 needs neither.

### C9 — Owner alerts aggregate

```text
CANDIDATE_ID = C9_OWNER_ALERTS
PRODUCTION_FILE = lib/features/dashboard/dashboard_alerts_section.dart
CURRENT_QUERY_PATH = presentation static loader -> six repository/service reads -> sorted financial/inventory alerts
TARGET_APPLICATION_BOUNDARY = new typed multi-authority aggregate query
READ_ONLY_OR_MUTATING = READ_ONLY
BUSINESS_CRITICALITY = FINANCIAL_AND_INVENTORY
EXPECTED_SCOPE_SIZE = LARGE
DEPENDENCIES = several uncaptured repositories and explicit consistency policy
RISK = HIGH
TESTABILITY = HIGH_BUT_BROAD
SCHEMA_DATABASE_CLOUD_CHANGE = NONE
DISPOSITION = DEFER
```

Six authorities, derived ordering/filtering, and mixed financial/inventory
truth make it unsuitable for the next atomic phase.

### C10 — Daily and financial report queries

```text
CANDIDATE_ID = C10_DAILY_OR_FINANCIAL_REPORT_QUERY
PRODUCTION_FILES = reports screen/controller and financial-report screens/services
CURRENT_QUERY_PATH = presentation-created aggregate repository/services -> multiple local repositories -> derived report
TARGET_APPLICATION_BOUNDARY = typed report query family with consistency/provenance
READ_ONLY_OR_MUTATING = READ_ONLY_REPORTS_WITH_EXPORT_ADJACENCY
BUSINESS_CRITICALITY = HIGH
EXPECTED_SCOPE_SIZE = LARGE_MULTI_SCREEN
DEPENDENCIES = exact aggregate capture or many new dependencies/contracts
RISK = HIGH
TESTABILITY = HIGH_BUT_REPOSITORY_WIDE
SCHEMA_DATABASE_CLOUD_CHANGE = NONE_FOR_LOCAL_READ
DISPOSITION = REJECT_FOR_PHASE_108N
```

One locator can hide seven repository reads and sensitive accounting,
inventory, cancellation, and valuation calculations.

### C11 — Export/report branding identity and logo reads

```text
CANDIDATE_ID = C11_EXPORT_REPORT_BRANDING
PRODUCTION_FILES = PDF export service and financial-report export helpers
CURRENT_QUERY_PATH = export flow -> loadIdentity + loadLogoBytes -> output generation
TARGET_APPLICATION_BOUNDARY = deliberately scoped business-profile/export input
READ_ONLY_OR_MUTATING = READ_ONLY_DATA_ACCESS_INSIDE_OUTPUT_SIDE_EFFECT_FLOW
BUSINESS_CRITICALITY = MODERATE_TO_HIGH_DOCUMENT_OUTPUT
EXPECTED_SCOPE_SIZE = MULTI_SCREEN_AND_SERVICE
DEPENDENCIES = profile plus logo contract, not logo bytes alone
RISK = HIGHER_THAN_C1_C2
TESTABILITY = BROAD
SCHEMA_DATABASE_CLOUD_CHANGE = NONE
DISPOSITION = DEFER_PENDING_RESCOPING
```

A logo-byte-only edit would not close the complete identity/export seam.

### C12 — Broad locator or dependency-injection cleanup

```text
CANDIDATE_ID = C12_BROAD_LOCATOR_CLEANUP
PRODUCTION_SURFACE = repository-wide
CURRENT_QUERY_PATH = 38 feature/shared consumers and mixed read/write references
TARGET_APPLICATION_BOUNDARY = generalized locator eradication
READ_ONLY_OR_MUTATING = MIXED
BUSINESS_CRITICALITY = MIXED_HIGH
EXPECTED_SCOPE_SIZE = REPOSITORY_WIDE
DEPENDENCIES = MANY_UNRESOLVED_OWNERSHIP_DECISIONS
RISK = HIGH
TESTABILITY = FULL_REPOSITORY
SCHEMA_DATABASE_CLOUD_CHANGE = POSSIBLE_SCOPE_CREEP
DISPOSITION = REJECT
```

This violates the established one-slice strategy.

## 9. Canonical Phase 108N scope

```text
PHASE_108N_CANONICAL_SCOPE =
ONE_LOCAL_READ_ONLY_SETTINGS_LOGO_PREVIEW_UI_QUERY_MIGRATION_THROUGH_EXISTING_APPLICATION_BOUNDARY
```

Plainly: a later Phase 108N implementation may migrate only the managed logo
byte read performed by `SettingsScreen._LogoPreview` from the global
`AppRepositories` locator to the already composed `businessLogo` application
query.

This is the single preferred candidate because it:

- continues the accepted Phase 108K–108M one-read-seam sequence;
- closes one complete UI-to-managed-file bypass;
- reuses the exact existing query and exact production repository instance;
- is strictly read-only and local-only;
- changes no data, schema, database, cloud, or business rule;
- has one bounded production file; and
- leaves the printable, export, database-backed, aggregate, and write paths
  independently governable in later phases.

## 10. Architectural boundary freeze

```text
CURRENT_PATH =
SettingsScreen._LogoPreview._loadLogoBytes
  -> AppRepositories.businessIdentityRepository
  -> BusinessIdentityRepository.loadLogoBytes(managedFileName)
  -> LocalBusinessIdentityRepository
  -> same managed local logo file

TARGET_PATH =
SettingsScreen._LogoPreview._loadLogoBytes
  -> ApplicationScope.of(context).queries.businessLogo
  -> LoadBusinessLogoQuery(managedFileName)
  -> LoadBusinessLogoQueryHandler.execute
  -> ApplicationDependencies.repositories.businessIdentityRepository
  -> exact same production BusinessIdentityRepository instance
  -> BusinessIdentityRepository.loadLogoBytes(managedFileName)
  -> same managed local logo file

OWNERSHIP_CHANGE =
PRESENTATION_STOPS_RESOLVING_THE_GLOBAL_REPOSITORY_AND_CONSUMES_THE_EXISTING_TYPED_QUERY_HANDLER
```

```text
SOURCE = QueryResultSource.local
READ_AUTHORITY = LocalReadAuthority.managedFile
CONSISTENCY = LocalQueryConsistency.currentKnownState
DATABASE_AUTHORITY = NONE
CLOUD_AUTHORITY = NONE
WRITE_AUTHORITY_CHANGE = NONE
```

## 11. Explicit in-scope for later planning and implementation

Only the following product is in scope:

- the private `_LogoPreview` read-resolution seam in
  `lib/features/settings/settings_screen.dart`;
- use of the existing `LoadBusinessLogoQuery` and registered
  `ApplicationQueries.businessLogo` handler;
- exact propagation of the current managed filename;
- exact reuse of the existing captured production repository;
- preservation of empty-name, bytes, null/missing-file, exception, loading,
  invalid-image, dimensions, and fit behavior;
- focused future tests for the selected preview and negative controls proving
  all identity/logo writes remain untouched; and
- live architecture inventory updates required solely by the expected
  one-consumer/one-reference removal.

The only allowed future production source surface is:

```text
lib/features/settings/settings_screen.dart
  -> class _LogoPreview
  -> method _loadLogoBytes and its call site only
```

Exact future test-file changes are a planning question and are not authorized
or selected by this scope-discovery artifact.

## 12. Explicit out-of-scope

Phase 108N excludes:

- Settings logo upload, logo deletion, identity/profile loading or saving,
  controller ownership, validation, and UI redesign;
- the printable-document logo loader;
- PDF/export and financial-report branding;
- any second logo consumer or second query migration;
- expense, supplier, customer, supplier-statement, financial-account,
  dashboard, alert, report, inventory, sale, or purchase query migration;
- product catalog work already completed by Phase 108K;
- Dashboard App Bar work already completed by Phase 108L;
- shared `BusinessIdentityHeader` work already completed by Phase 108M;
- any write or command path;
- repository interfaces, persistence adapters, composition redesign, or a new
  application query/handler/result/dependency;
- broad `AppRepositories` or dependency-injection cleanup;
- schema, SQLite, database, generated-file, migration, or data changes;
- Supabase, cloud, RLS, RPC, auth, storage, sync, or deployment work;
- new features, navigation work, Android work, responsive/UX redesign, or
  performance/caching changes;
- dependencies or Flutter/Dart upgrades;
- unrelated tests, cleanup, formatting, or documentation rewrites;
- Phase 108N implementation in this session; and
- Phase 108O work.

## 13. Forbidden mutations in this governance session

```text
PRODUCTION_CODE_CHANGE = FORBIDDEN
TEST_CHANGE = FORBIDDEN
DATABASE_OR_SCHEMA_CHANGE = FORBIDDEN
DEPENDENCY_CHANGE = FORBIDDEN
CLOUD_OR_SUPABASE_CHANGE = FORBIDDEN
TAG_CREATION_OR_REPLACEMENT = FORBIDDEN
PUSH_OR_REMOTE_REF_MUTATION = FORBIDDEN
HISTORY_REWRITE = FORBIDDEN
PHASE_108N_PLANNING = FORBIDDEN
PHASE_108N_IMPLEMENTATION = FORBIDDEN
```

## 14. Expected inputs for a later planning session

A separately authorized planning session must determine only implementation
mechanics inside the frozen product, including:

1. the exact context-passing shape that preserves the empty-name short circuit
   before application-scope lookup;
2. the minimal focused Settings harness that supplies the existing
   `ApplicationScope` for valid-logo preview behavior;
3. bytes, null, exception, empty-name, invalid-image, dimensions, and fit proof;
4. exact repository identity and managed-file provenance proof;
5. zero calls to `saveIdentity`, `saveLogoBytes`, and `deleteLogoFile`;
6. exact live inventory delta and retained printable/export logo reads;
7. the exact future test-file allowlist and proportionate verification commands.

Those questions may refine mechanics only. They may not add another production
surface or change the canonical scope.

## 15. Governance closure gates

Local closure requires:

- this artifact is the only changed/staged file;
- no production, test, database, schema, dependency, generated, or platform
  file changes;
- `git diff --check` and staged diff checks pass;
- `git fsck --full --no-dangling` passes;
- one normal, one-parent, non-merge commit is created directly on
  `d31d6897053829d052199aa44da7a7e114e951fc`;
- the commit subject follows current convention:
  `Phase 108N: discover and freeze canonical scope`;
- no tag and no remote mutation occur; and
- the final worktree, index, untracked set, and stash are empty.

## 16. Mutation declaration

This session is authorized to create only this governance artifact and its
local commit. It does not modify any production source, test, schema, database,
dependency, generated file, platform file, completed phase artifact, tag, or
remote ref.

## 17. Next authorized session

After valid local governance closure, the only next session is:

```text
NEXT_AUTHORIZED_SESSION = PHASE_108N_GOVERNANCE_REMOTE_LOCK
```

That session may verify and remotely lock the local governance decision only.
It must not plan or implement Phase 108N without separate authorization after
the governance baseline is remotely established.
