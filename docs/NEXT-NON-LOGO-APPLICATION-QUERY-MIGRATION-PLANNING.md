# Next non-logo application-query migration planning

## A. Session identity

```text
SESSION = NEXT_NON_LOGO_APPLICATION_QUERY_MIGRATION_PLANNING
EVIDENCE_DATE = 2026-09-07 (Africa/Cairo)
EXPECTED_RESULT = PASS_NEXT_NON_LOGO_APPLICATION_QUERY_MIGRATION_PLANNING_REMOTE_LOCKED

PLANNING_STATUS = COMPLETE
QUERY_SEAM_SELECTION_STATUS = RESOLVED
SELECTED_QUERY_SEAM = CONFIRMED_EXPENSE_LIST_APPLICATION_QUERY
BEHAVIOR_PRESERVING_MIGRATION = YES
IMPLEMENTATION_STARTED = NO
```

This artifact selects and plans one read-only ownership migration. It does not
implement it. The canonical seam is the confirmed local expense list consumed
by `ExpensesScreen` through `ExpenseController.loadExpenses`.

## B. Repository identity

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
ENTRY_AUTHORITY_COMMIT = c71cc970c0e2c60d74d8120f43c89d9f71a988c8
ENTRY_AUTHORITY_SUBJECT = docs: select post-internal-transfer successor scope
```

`git rev-parse --show-toplevel`, `git branch --show-current`, `git remote -v`,
and direct Git object inspection established these values. `origin` has no
separate push URL, so its fetch URL is also the effective push URL.

## C. Entry classification

```text
ENTRY_CLASSIFICATION = CASE_A_FRESH
ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = CLEAN
ENTRY_STASH = EMPTY
ENTRY_ACTIVE_GIT_OPERATION = NONE
ENTRY_INDEX_LOCK = ABSENT
RECOVERY_REQUIRED = NO
```

Before discovery, `git status --short`, `git diff --check`, and `git stash
list` were empty. No merge, rebase, cherry-pick, revert, sequencer, bisect, or
index-lock marker existed. There was no interrupted-session residue.

## D. Entry remote-lock proof

After a successful `git fetch origin`, independent local, tracking, merge-base,
divergence, and direct-remote checks established:

```text
ENTRY_LOCAL_HEAD = c71cc970c0e2c60d74d8120f43c89d9f71a988c8
ENTRY_TRACKING_REFERENCE = refs/remotes/origin/codex/phase-108h-app-shell-runtime-ownership-boundary
ENTRY_TRACKING_HEAD = c71cc970c0e2c60d74d8120f43c89d9f71a988c8
ENTRY_DIRECT_REMOTE_HEAD = c71cc970c0e2c60d74d8120f43c89d9f71a988c8
ENTRY_MERGE_BASE = c71cc970c0e2c60d74d8120f43c89d9f71a988c8
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0
ENTRY_FETCH = PASS
ENTRY_DIRECT_REMOTE_PROOF = PASS
```

Direct proof used `git ls-remote origin
refs/heads/codex/phase-108h-app-shell-runtime-ownership-boundary`; the
remote-tracking ref was not treated as a substitute.

## E. Binding authority chain

The following committed contents, not merely their subjects, govern this plan:

| Role | Commit | Governing effect |
| --- | --- | --- |
| Post-logo successor decision | `dfd3737e58338b3076f4f89ae0757b397d39e38e` | Closed Logo Query Migration, preserved six workstreams, and stopped for owner order. |
| Binding owner order | `a5f57c709e1b7e9b3f50d8ae4811951220edf2a6` | Ordered W2, W1, W5, W3, W4, W6. |
| Second-command discovery | `88ee8523c26dc8778268ab7317e38a6f998334ba` | Preserved multiple command candidates and stopped for selection. |
| Owner command selection | `a8ac2e2535943361cc2d40c2ddcd4ec7ba4552bc` | Selected Internal Transfer and deferred other command families. |
| Internal Transfer plan | `8382283385b61ab5efe849eb6a4bd494a26e56b1` | Froze the implementation contract. |
| Internal Transfer implementation | `0749a436629f737dfc6d91bd1ca8a0daa81ec13f` | Completed the second server-authoritative financial-command slot. |
| Current entry decision | `c71cc970c0e2c60d74d8120f43c89d9f71a988c8` | Selected `NEXT_NON_LOGO_APPLICATION_QUERY_MIGRATION` and authorized planning only. |

The binding order is:

```text
1. SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND
2. NEXT_NON_LOGO_APPLICATION_QUERY_MIGRATION
3. DISTRIBUTED_IDENTITY_SCOPE_TIME_CONTRACT_COMPLETION
4. DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION
5. CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE
6. RECOVERY_TRIAL_AND_LICENSING_BOUNDARY
```

`INTERNAL_TRANSFER` completed item 1. No commit after `a5f57c7...` changes the
order, and no commit after `c71cc97...` exists on the authorized branch.

The entry decision artifact is committed at the expected object identities:

```text
DECISION_COMMIT = c71cc970c0e2c60d74d8120f43c89d9f71a988c8
DECISION_PARENT = 0749a436629f737dfc6d91bd1ca8a0daa81ec13f
DECISION_TREE = 87ba11882efcca8d19623000896ee1b7fec11ad9
DECISION_ARTIFACT_BLOB = c011a063feb4d0f9566be1597ead25caaf20bf30
DECISION_SUBJECT = docs: select post-internal-transfer successor scope
SUCCESSOR_SELECTED = YES
SELECTED_SUCCESSOR = NEXT_NON_LOGO_APPLICATION_QUERY_MIGRATION
NEXT_SESSION_AUTHORIZED = NEXT_NON_LOGO_APPLICATION_QUERY_MIGRATION_PLANNING_ONLY
```

## F. Completed-scope exclusions

```text
INTERNAL_TRANSFER = COMPLETE_AND_CLOSED
LOGO_QUERY_MIGRATION_PROGRAM = COMPLETE_AND_CLOSED
AUDIT_LOG_APPLICATION_QUERY = COMPLETED
DOCUMENT_HISTORY_APPLICATION_QUERY = COMPLETED
PRODUCTS_SCREEN_PRODUCT_CATALOG_APPLICATION_QUERY = COMPLETED

INTERNAL_TRANSFER_REOPENED = NO
LOGO_QUERY_MIGRATION_REOPENED = NO
```

The `loadLogoBytes` production inventory now routes live consumers through
`LoadBusinessLogoQueryHandler`; logo files and PDF/report branding are not
candidates. Internal Transfer code is architectural precedent only. Commands,
RPC mutations, reversals, and other financial-command families are not queries
and cannot satisfy this roadmap slot.

## G. Definition of this roadmap slot

A non-logo application-query migration moves ownership of an existing read from
a presentation/controller/provider or other higher layer to the established
typed `ApplicationQueryHandler<Q, R>` boundary. The application handler owns
invocation of an injected read repository and returns `ApplicationQueryResult`
with truthful provenance. The persistence adapter continues to own SQL/Drift
mapping.

This differs from:

- direct local persistence/repository access from presentation or a controller,
  which is the ownership gap being reduced;
- logo-byte queries, which are complete and closed;
- command handlers such as `PostExpenseCommandHandler` and
  `PostInternalTransferCommandHandler`, which mutate server-authoritative state;
- service-owned reads inside backup, restore, wipe, or reporting workflows,
  which need separate consistency/scope decisions rather than being relabeled
  as one UI-list query.

The established pattern is `LoadAuditLogsQuery`, `LoadDocumentHistoryQuery`,
and `LoadProductCatalogQuery`: immutable request, typed handler, exact injected
repository, unchanged repository mapping/order/error, local metadata, central
composition, and caller resolution through `ApplicationScope`.

## H. Remaining query-seam inventory

Repository-wide searches covered `AppRepositories`, `ApplicationScope`,
repository list/statement methods, Drift `select`, database fields, dashboard
and report loading, controllers, services, tests, and generated code. Hits were
traced rather than counted mechanically.

| Surface | Classification | Evidence and disposition |
| --- | --- | --- |
| Audit Logs | `COMPLETED` | `AuditLogsScreen -> ApplicationQueries.auditLogs`; typed handler and local metadata exist. |
| Document History | `COMPLETED` | Screen/controller consumes `documentHistory`; its aggregate repository remains the persistence/query adapter. |
| Products screen catalog list | `COMPLETED` | `ProductsScreen -> ApplicationQueries.productCatalog`; writes remain separate. |
| Business logo consumers | `LOGO_SPECIFIC_AND_CLOSED` | Header, Settings, printable, PDF/report and backup logo-byte reads use the canonical business-logo query. |
| Confirmed expense list | `ACTIVE_NON_LOGO_CANDIDATE` | `ExpensesScreen` resolves `ExpenseRepository` from `ApplicationScope.dependencies`; `ExpenseController` calls `listExpenses` directly. |
| Supplier directory | `ACTIVE_NON_LOGO_CANDIDATE` | Controller list read is direct, but visible load also uses supplier balances/opening state and the dependency is not captured. |
| Customer visible load | `ACTIVE_NON_LOGO_CANDIDATE_REQUIRES_RESCOPING` | One load combines customers, balances, and per-customer opening-state reads. |
| Financial-account list/statement | `ACTIVE_NON_LOGO_CANDIDATE_HIGH_RISK` | Repository is captured, but account, balance, statement, closing, transfer, and routing semantics share the surface. |
| Supplier statement | `ACTIVE_NON_LOGO_CANDIDATE_REQUIRES_WRITE_SEPARATION` | Screen-owned repository field performs both `statementForSupplier` and supplier-payment work. |
| Dashboard guidance | `ACTIVE_NON_LOGO_CANDIDATE_AGGREGATE` | Presentation static loader crosses catalog, inventory, and sales repositories without an atomic snapshot contract. |
| Owner alerts and daily/financial reports | `ACTIVE_NON_LOGO_CANDIDATE_REQUIRES_RESCOPING` | Three-to-seven authorities, derived ordering/totals, exports, and accounting consistency make these families non-atomic as currently named. |
| Sales/purchases/inventory controller loads | `ACTIVE_NON_LOGO_CANDIDATE_MIXED_WORKFLOW` | Reads are repository-owned, but each controller composes several reads and refreshes after writes; no committed artifact selects one as the next atomic seam. |
| Other product-catalog repository consumers | `ALREADY_APPLICATION_OWNED_AT_READ_REPOSITORY_LEVEL` | They use `ProductCatalogReadRepository`, not Drift directly; migrating another caller needs a separately frozen controller/workflow seam. Cloud/hybrid authority remains later-roadmap work. |
| Backup export/restore/wipe reads | `DEFERRED_FOR_OTHER_ROADMAP_SCOPE` | Reads occur inside application services with artifact mutation/recovery semantics; recovery is ordered later. |
| Auth/session/trial/license reads | `DEFERRED_FOR_OTHER_ROADMAP_SCOPE` | Distributed identity/scope/time and recovery/trial/licensing are later ordered workstreams. |
| Core Drift adapter `select` calls | `ALREADY_APPLICATION_OWNED` | Persistence implementation is the correct SQL/Drift owner; adapter internals are not UI violations. |
| Tests | `TEST_ONLY` | Direct repositories/database construction is fixture and adapter-contract evidence. |
| `foundation_database.g.dart` | `GENERATED` | Generated persistence code is not a migration candidate. |
| Old local in-memory implementations | `LEGACY_OR_TEST_COMPATIBILITY` | They preserve repository contract tests and do not select a production caller seam. |

## I. Candidate comparison

| Candidate | Current caller / owner crossed | Existing abstraction | Read-only | Collision / breadth | Current protection | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| Confirmed expense list | `ExpensesScreen -> ExpenseController -> ExpenseRepository.listExpenses` | Repository already captured in `ApplicationDependencies`; new query only | Yes; write-adjacent | No later-scope prerequisite; one list and one controller | Phase 108J UI/projection tests; Phase 8J ordering/durability; Phase 31 controller | **SELECT** |
| Supplier directory | `SuppliersScreen -> SupplierController -> SupplierRepository` plus account reads | No captured supplier dependency/query | List-only, but mixed screen | Partial seam; new capture and balance coexistence contract | Durable supplier, supplier account, purchase/payment suites | Defer |
| Customer visible load | Controller -> customer plus account repositories | No composite query | Yes | Must decide split vs composite and partial-failure consistency | Customer/account/opening/collection suites | Defer pending rescope |
| Financial account list/statement | Screens/controllers -> captured repository | Captured repository; no typed query | Yes | High-risk derived balances, date filters, closing and transfer semantics | Phase 72/76/78/79/80, Phase 8H, report suites | Defer |
| Supplier statement | Screen field -> `statementForSupplier` and payment methods | No captured exact query dependency | Read method only | Honest locator removal is blocked by write ownership | Supplier credit/payment/statement/print tests | Defer pending write separation |
| Dashboard guidance | Static presentation loader -> catalog/inventory/sales | Individual repositories captured | Yes | Needs aggregate result and cross-repository consistency | Dashboard guidance and historical source guards | Defer |
| Alerts/reports | Screens/services -> multiple repositories | Existing domain services, no application query family | Yes | Broad financial/inventory totals and export adjacency | Report, accounting, cancellation, valuation suites | Defer pending rescope |
| Sales/purchase/inventory loads | Mixed controllers -> multiple read/write repositories | Repository contracts exist | Read portion only | Mutation refresh and command-validation reads must be separated first | Domain controller and transaction suites | Defer |

Every deferred item remains valid future work. None is rejected because it is
hard; it is deferred because the current repository does not make it one
behaviorally complete, dependency-ready application-query seam.

## J. Concrete seam-selection proof

The decision hierarchy resolves the seam without inventing owner preference:

1. The owner chose the W1 workstream but did not name a concrete seam.
2. Phase 108M and 108N repeatedly preserve the confirmed expense list as the
   first concrete non-logo, database-backed query candidate after their selected
   logo seams. They describe it as high pattern reuse and high atomicity when
   limited to the list read.
3. Current code confirms the prerequisite relation: Phase 108J established the
   confirmed expense projection, and `ApplicationDependencies` already captures
   the exact production `ExpenseRepository`. The list is therefore ready to move
   without a new repository ownership decision.
4. The second command is now complete, so preserving application-boundary
   progress selects the already prepared confirmed-expense read rather than
   beginning a new dependency family.
5. Supplier/customer alternatives lack captured dependencies or complete visible
   load boundaries; statement, dashboard, report, and financial alternatives
   require consistency or read/write separation decisions. Product consumers
   beyond the completed Products-screen slice belong to mixed workflows and have
   no stronger committed successor signal.

This is architectural and predecessor/successor evidence, not selection merely
because the change is easy. Exactly one candidate combines an explicit repeated
deferred signal, an already captured exact dependency, a completed authoritative
projection prerequisite, and an atomic current caller seam.

```text
QUERY_SEAM_SELECTION_STATUS = RESOLVED
SELECTED_QUERY_SEAM = CONFIRMED_EXPENSE_LIST_APPLICATION_QUERY
CANONICAL_QUERY = LoadExpensesQuery
```

## K. Current architecture and data flow

```text
authenticated ExpensesScreen.didChangeDependencies
  -> ApplicationScope.dependencies.repositories.expenseRepository
  -> ExpenseController(repository: ...)
  -> post-frame ExpenseController.loadExpenses(AppUser)
  -> ExpenseRepository.listExpenses()
  -> DriftExpenseRepository.listExpenses()
  -> FoundationDatabase.expenses SELECT
  -> date DESC, createdAt DESC, id DESC
  -> ExpenseRecord mapping
  -> ExpenseController._expenses
  -> loading / error / empty / expense-card rendering
```

The persistence adapter is correctly database-owning. The ownership gap is that
presentation selects the repository and the controller uses a mixed read/write
repository directly for the list instead of consuming the established
application query surface.

The list contains confirmed local expense projections only. Command attempts in
queued, sending, unknown, rejected, or confirmed-projection-pending states are
not `ExpenseRecord` list rows. A successful `PostExpenseCommand` refreshes the
list only after the confirmed projection succeeds.

## L. Target architecture and application query contract

```text
ExpensesScreen.didChangeDependencies
  -> ApplicationScope.queries.expenses
  -> ExpenseController(queryHandler: ..., repository: writeRepository)
  -> ExpenseController.loadExpenses(AppUser)
  -> LoadExpensesQueryHandler.execute(const LoadExpensesQuery())
  -> injected exact ApplicationDependencies.repositories.expenseRepository
  -> ExpenseRepository.listExpenses()
  -> unchanged DriftExpenseRepository / FoundationDatabase SELECT and mapping
  -> ApplicationQueryResult<List<ExpenseRecord>>
  -> ExpenseController._expenses
  -> unchanged rendering
```

Exact planned contract:

```dart
final class LoadExpensesQuery {
  const LoadExpensesQuery();
}

final class LoadExpensesQueryHandler
    implements ApplicationQueryHandler<LoadExpensesQuery, List<ExpenseRecord>> {
  const LoadExpensesQueryHandler({required ExpenseRepository repository});

  Future<ApplicationQueryResult<List<ExpenseRecord>>> execute(
    LoadExpensesQuery query,
  );
}
```

Contract decisions:

- input parameters: none; current list has no filter, page, date, scope, or user
  parameter;
- output: the exact `List<ExpenseRecord>` returned by the repository, wrapped in
  `ApplicationQueryResult`; the handler does not copy, sort, filter, or map it;
- empty/null: success is a non-null list, possibly empty; no nullable list or
  synthetic placeholder;
- ordering: preserve adapter order exactly; production Drift order is `date`
  descending, then `createdAt` descending, then `id` descending;
- filtering: none; all locally confirmed expense projections are returned;
- date/time: no normalization in the handler; retain stored `ExpenseRecord.date`
  and `createdAt` values;
- identity/scope: no new business/user/device identifier is invented. Current
  local repository instance and current authenticated-screen gate are preserved;
- errors: propagate the exact repository exception unchanged. The handler adds
  no retry, message mapping, catch, fallback, or state mutation;
- consistency: one-shot read of current known local SQLite state; no stream,
  transaction, refresh, cache, server call, or multi-repository snapshot;
- metadata: `LocalQueryResultMetadata(source: local, readAuthority: sqlite,
  consistency: currentKnownState)`;
- mapping: `DriftExpenseRepository` retains row-to-`ExpenseRecord` mapping;
- dependency injection: the composition root constructs one handler from the
  exact captured `expenseRepository` and exposes it as
  `ApplicationQueries.expenses`;
- lifecycle: `ApplicationBoundary` owns the handler for the application
  lifetime; the screen-owned controller retains its existing lifecycle;
- controller compatibility: add an optional injected query handler while
  retaining required `ExpenseRepository` for reclassification and historical
  test/write compatibility. When absent in non-production tests, construct the
  same handler from that supplied repository, matching the ProductController
  migration pattern;
- caller migration: production `ExpensesScreen` passes both
  `queries.expenses` for reads and the existing dependency repository for the
  unchanged reclassification write.

```text
CURRENT_OWNER = ExpenseController via ExpenseRepository
CURRENT_CALLER = ExpensesScreen
TARGET_APPLICATION_QUERY = LoadExpensesQueryHandler
TARGET_CALLER = ExpenseController, injected by ExpensesScreen from ApplicationScope.queries.expenses
TARGET_RETURN_TYPE = ApplicationQueryResult<List<ExpenseRecord>>
DEPENDENCY_BOUNDARY = ApplicationDependencies.repositories.expenseRepository
PERSISTENCE_ADAPTER = DriftExpenseRepository
```

## M. Behavior-preservation contract

Implementation must preserve all of the following observable behavior:

- unauthenticated users do not trigger a list query and see the existing login
  empty state;
- an authenticated screen schedules the initial load after the current frame;
- each load sets loading `true`, clears the existing error message, and notifies
  before invoking the read;
- success replaces the controller list, sets loading `false`, and notifies once;
- an empty list renders the existing Arabic empty state;
- expense category, amount, date, accounting classification, payment method,
  notes, and owner-only reclassification affordance render unchanged;
- owner and employee list membership remains identical because the current
  `AppUser` parameter does not filter `listExpenses`;
- deterministic production ordering remains date/createdAt/id descending;
- exact repository errors continue to escape `loadExpenses`; current failure
  behavior retains the old list and leaves loading `true` because no new catch
  or error mapping is authorized;
- retry continues to call the same controller load method;
- successful reclassification continues through `ExpenseRepository` and then
  refreshes through the query exactly once;
- the production screen continues to create expenses only through
  `ApplicationCommands.postExpense`, never the legacy controller write method;
- confirmed command success refreshes only after local projection succeeds;
- replay success, projection-pending, unknown outcome, approval-required, and
  rejection messages/lifecycle behavior remain unchanged;
- provisional/attempt rows never appear in the confirmed list;
- no totals, report, inventory, account balance, permissions, localization,
  formatting, navigation, or visual-design behavior changes.

## N. Exact future file touch-set

### Production files

| Action | Path | Planned responsibility change | Must remain unchanged |
| --- | --- | --- | --- |
| `CREATE` | `lib/application/queries/load_expenses_query.dart` | Define immutable request and handler; delegate once to `ExpenseRepository.listExpenses`; return local SQLite metadata. | Repository behavior, mapping, order, errors. |
| `MODIFY` | `lib/application/application_boundary.dart` | Import the new query and add required `ApplicationQueries.expenses`. | Existing commands and four query members. |
| `MODIFY` | `lib/composition/app_composition_root.dart` | Construct `LoadExpensesQueryHandler` from the exact captured expense repository. | Repository initialization, command composition, session/runtime ownership. |
| `MODIFY` | `lib/core/expenses/expense_controller.dart` | Read via injected handler; keep repository only for existing write/reclassification compatibility; refreshes call the handler-backed load. | State transitions, public methods, permissions, error mapping for writes. |
| `MODIFY` | `lib/features/expenses/expenses_screen.dart` | Resolve `ApplicationScope.queries.expenses` for the default controller while passing the same repository for unchanged writes. | Command UI, lifecycle messages, financial-account reads, form, cards, visuals. |

No persistence adapter change is expected: `ExpenseRepository` already exposes
the exact read, and `DriftExpenseRepository` already provides the required
deterministic ordering and mapping.

### Test files

| Action | Path(s) | Planned change |
| --- | --- | --- |
| `CREATE` | `test/confirmed_expense_list_application_query_migration_test.dart` | Handler parity, metadata, composition identity, controller state/refresh/error parity, default-screen wiring, and forbidden direct-read/write guards. |
| `MODIFY` | `test/phase108f_first_read_only_ui_query_migration_test.dart` | Update the concrete-query inventory from four to five and include the new handler path. |
| `MODIFY` | `test/phase108i_second_read_only_ui_query_migration_test.dart`; `test/phase108k_product_catalog_query_migration_test.dart`; `test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart` | Preserve exact query inventory expectations and copy the new required query member in test boundary clones. |
| `MODIFY` | `test/phase108m_shared_business_identity_header_logo_query_migration_test.dart`; `test/phase108n_settings_logo_preview_query_migration_test.dart`; `test/phase108o_printable_document_scaffold_logo_query_migration_test.dart`; `test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart`; `test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart`; `test/phase108r_payment_method_report_pdf_logo_query_migration_test.dart`; `test/phase96_in_app_business_identity_app_shell_branding_test.dart` | Copy `application.queries.expenses` into existing `ApplicationQueries` test clones only; do not alter logo assertions or behavior. |
| `MODIFY` | `test/post_advances_refunds_report_pdf_logo_query_migration_pdf_export_service_logo_query_migration_test.dart`; `test/post_expense_analysis_report_pdf_logo_query_migration_advances_refunds_report_pdf_logo_query_migration_test.dart`; `test/post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart`; `test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_test.dart`; `test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_test.dart`; `test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_expense_analysis_report_pdf_logo_query_migration_test.dart` | Copy the required query member in boundary clones; no report/logo expectation changes. |

`test/phase31_functional_recovery_test.dart` is `VERIFY_ONLY`: its existing
`ExpenseController(repository: ...)` construction must remain compatible and
must refresh through the internally adapted handler in tests.

### Explicit `DO_NOT_TOUCH`

```text
supabase/**
lib/core/persistence/foundation_database.dart
lib/core/persistence/foundation_database.g.dart
lib/core/persistence/migration_strategy.dart
lib/core/expenses/expense_repository.dart
lib/core/expenses/drift_expense_repository.dart
lib/application/commands/**
lib/application/expenses/**
lib/application/financial_transfers/**
lib/infrastructure/supabase/**
lib/application/queries/load_business_logo_query.dart
lib/core/business_identity/**
lib/features/exports/**
lib/features/prints/**
lib/features/financial_reports/**
assets/**
pubspec.yaml
pubspec.lock
windows/**
android/**
ios/**
macos/**
linux/**
web/**
```

The Internal Transfer implementation paths and tests are verify-only regression
surfaces. No database migration, schema, SQL, generated file, dependency, logo,
report, command, or platform file may change.

## O. Test and regression contract

### Focused query tests

The new focused test must prove:

1. one `LoadExpensesQuery` causes exactly one repository call;
2. list object, record identities, membership, and repository order are
   preserved exactly;
3. an exact empty list is a successful result;
4. repository exception identity propagates unchanged;
5. metadata is local/SQLite/current-known-state;
6. the handler calls no create, reclassify, total, financial, command, network,
   or logo method.

### Controller and caller regression tests

- production construction injects `ApplicationQueries.expenses` and the exact
  existing repository instance for writes;
- legacy/test construction with a repository remains behaviorally compatible;
- initial authenticated load and retry use the query;
- loading notifications, retained-list failure behavior, and unmodifiable
  controller exposure remain exact;
- owner/employee results are unfiltered as before;
- reclassification writes once then refreshes once through the query;
- command success refreshes only for confirmed, non-pending projection;
- queued/sending/unknown/rejected/approval/pending states do not fabricate a
  list row;
- the source guard proves the production list no longer traverses
  `ApplicationScope.dependencies.repositories.expenseRepository` as its read
  dependency and still contains `commands.postExpense`;
- no direct Drift/database construction is introduced in application,
  controller, or presentation code.

### Persistence adapter tests

`test/phase8j_durable_expense_repository_test.dart` remains unchanged and must
pass, especially deterministic date/createdAt/id ordering, exact field mapping,
empty/wipe behavior, corrupt-field failure, migration compatibility, and
production Drift wiring.

### Existing targeted regression suite

```text
flutter test test/confirmed_expense_list_application_query_migration_test.dart
flutter test test/phase108f_first_read_only_ui_query_migration_test.dart
flutter test test/phase108i_second_read_only_ui_query_migration_test.dart
flutter test test/phase108k_product_catalog_query_migration_test.dart
flutter test test/phase108j_expense_ui_integration_test.dart
flutter test test/phase108j_expense_projection_test.dart
flutter test test/phase108j_post_expense_command_test.dart
flutter test test/phase8j_durable_expense_repository_test.dart
flutter test test/phase31_functional_recovery_test.dart
flutter test test/phase81_transaction_financial_backup_contract_test.dart
flutter test test/phase9e_expense_analysis_report_test.dart
```

Run every modified historical query/logo harness listed in Section N. Their
changes are constructor/inventory accommodation only; all original assertions
must remain intact.

Planning baseline executed before this artifact:

```text
FOCUSED_BASELINE = PASS
TESTS_PASSED = 50
TESTS_FAILED = 0
```

The baseline combined the Phase 108F, 108I, and 108K query tests, Phase 108J
expense UI guard, and Phase 8J durable expense repository test.

### Broad gates

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

The implementation session must also prove its changed-path allowlist, no SQL
or schema delta, no generated/dependency delta, and no forbidden direct read.

## P. Scope-collision analysis

```text
NEW_DATABASE_MIGRATION_REQUIRED = NO
SCHEMA_CHANGE_REQUIRED = NO
SQL_CHANGE_REQUIRED = NO
SERVER_QUERY_REQUIRED = NO
SERVER_COMMAND_CHANGE_REQUIRED = NO
```

- Distributed identity/scope/time: the query invents no tenant, warehouse,
  device, membership, version, or time authority. It preserves the current
  local production repository and screen authentication gate.
- Durable outbox/inbox/conflict state: the query reads confirmed projections
  only and adds no queue, overlay, conflict, cursor, replay, or sync state.
- Cloud/hybrid product catalog: no catalog repository, cache, RLS, cloud adapter,
  or product model changes.
- Recovery/trial/licensing: no backup, restore, trial, license, or recovery path
  changes.
- Financial commands: `PostExpense` and `PostInternalTransfer` remain unchanged;
  no mutation RPC, idempotency, concurrency, approval, or reversal semantics are
  added.

If implementation discovery appears to require any schema, SQL, generated
Drift, Supabase, distributed-scope, outbox, cloud-catalog, recovery, or licensing
change, stop: that is evidence of scope collision, not permission to expand.

## Q. Explicit non-goals

- no new filters, search, pagination, totals, streams, refresh timers, cache, or
  server refresh;
- no conversion of `ExpenseRecord` to a new DTO/view model;
- no business-rule, permission, ordering, date, formatting, or error change;
- no fix for the current load-failure state machine;
- no migration of dashboard/report calls to `listExpenses` or
  `totalExpensesQirsh`;
- no expense reclassification redesign and no legacy write deletion;
- no Customer Collection, Supplier Payment, Purchase Intake, sales, advances,
  refunds, reversals, or another financial command;
- no supplier, customer, account, statement, dashboard, alert, report, sale,
  purchase, inventory, or second query seam;
- no logo, identity, printable, PDF, CSV, export, or backup work;
- no repository-wide locator cleanup, dependency framework, package upgrade,
  schema work, generated code, or opportunistic refactor.

## R. Deterministic implementation order

1. Verify this planning commit is the fresh direct-remote head and the repository
   is clean.
2. Add focused failing tests for request/handler parity, metadata, exact error,
   controller behavior, production identity, and forbidden writes/direct reads.
3. Create `LoadExpensesQuery` and its handler with one repository dependency.
4. Add the required `expenses` member to `ApplicationQueries` and compose it from
   the exact captured production `expenseRepository`.
5. Adapt `ExpenseController` so every list/refresh read goes through the handler
   while write/reclassification behavior retains the repository.
6. Migrate only the default `ExpensesScreen` controller wiring.
7. Update the exact historical `ApplicationQueries` clones and query-file
   inventories listed in Section N without changing their feature assertions.
8. Run focused handler/controller/UI/persistence tests and the complete targeted
   regression list.
9. Run formatter check, analyzer, full Flutter suite, `git diff --check`, and
   changed-path/forbidden-surface audits.
10. Prove the production direct read path is gone, no behavior or later roadmap
    scope changed, and perform the separately authorized implementation closure.

## S. Failure and rollback boundaries

- The implementation is atomic at source-control scope: handler, composition,
  controller, caller, and tests must land together or not at all.
- A failing parity test is not authority to change behavior; retain the old
  behavior or stop and report the mismatch.
- A discovered need for schema/cloud/distributed-state work invalidates this
  candidate for the current slot and requires a new owner decision.
- No database/data rollback is needed because implementation changes no schema or
  stored data.
- Before commit, unexpected tracked/untracked state must be preserved and
  classified. Do not reset, clean, stash, or discard it.
- After a local implementation commit but before a confirmed push, recovery is a
  normal unpublished commit investigation; do not amend or rewrite history.
- After a push, rollback requires a new authorized forward commit, never a force
  push or history rewrite.

## T. Implementation authorization boundary

This plan authorizes no implementation in this session. A future implementation
session is limited to the canonical seam and exact behavioral contract above.

```text
PLANNING_STATUS = COMPLETE
QUERY_SEAM_SELECTION_STATUS = RESOLVED
SELECTED_QUERY_SEAM = CONFIRMED_EXPENSE_LIST_APPLICATION_QUERY

IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED_BY_THIS_SESSION = NO

NEXT_SESSION_AUTHORIZED =
CONFIRMED_EXPENSE_LIST_APPLICATION_QUERY_MIGRATION_IMPLEMENTATION_ONLY
```

The implementation session must bind its entry authority to the commit that
adds this artifact, not to an uncommitted copy or this planning prompt.

## U. Final planning acceptance criteria

Planning is accepted only when all are true:

1. repository, branch, remote, entry authority, and direct remote identity pass;
2. the owner order and post-Internal-Transfer selection are verified from
   committed contents;
3. Logo Query Migration and Internal Transfer remain closed;
4. the remaining non-logo inventory is classified by actual call path;
5. the confirmed expense list is uniquely selected by committed deferral,
   prerequisite completion, captured dependency, and atomicity evidence;
6. current and target ownership, metadata, order, empty/error/refresh behavior,
   and confirmed-projection semantics are frozen;
7. the future production and test touch-set is explicit;
8. schema, SQL, command, logo, dependency, generated, and later-roadmap work are
   prohibited;
9. this artifact is the only planning-session tracked change;
10. the planning commit is normal-pushed and independently direct-remote locked;
11. final worktree, index, stash, active-operation, lock, and diff checks are
    clean.

## V. Planning-session mutation declaration

```text
ALLOWLIST = docs/NEXT-NON-LOGO-APPLICATION-QUERY-MIGRATION-PLANNING.md
PLANNING_DOCUMENTATION_FILES = 1
PRODUCTION_FILES_CHANGED = 0
TEST_FILES_CHANGED = 0
MIGRATION_FILES_CHANGED = 0
DEPENDENCY_FILES_CHANGED = 0
GENERATED_FILES_CHANGED = 0
```

The observed planning commit/tree/blob and final remote-lock identities belong
in the post-commit forensic report because this pre-commit artifact cannot
truthfully contain its own future Git object identity.

## W. Final authorization declarations

```text
INTERNAL_TRANSFER_REOPENED = NO
LOGO_QUERY_MIGRATION_REOPENED = NO

CUSTOMER_COLLECTION_STARTED = NO
SUPPLIER_PAYMENT_STARTED = NO
PURCHASE_INTAKE_STARTED = NO
REVERSAL_IMPLEMENTATION_STARTED = NO

DISTRIBUTED_IDENTITY_SCOPE_TIME_STARTED = NO
DURABLE_OUTBOX_INBOX_CONFLICT_STARTED = NO
CLOUD_HYBRID_PRODUCT_CATALOG_STARTED = NO
RECOVERY_TRIAL_LICENSING_STARTED = NO

QUERY_SEAM_SELECTION_STATUS = RESOLVED
SELECTED_QUERY_SEAM = CONFIRMED_EXPENSE_LIST_APPLICATION_QUERY
SUCCESSOR_IMPLEMENTATION_STARTED = NO

NEXT_SESSION_AUTHORIZED =
CONFIRMED_EXPENSE_LIST_APPLICATION_QUERY_MIGRATION_IMPLEMENTATION_ONLY
```

## X. Stop boundary

After this planning artifact is committed, normally pushed, independently
remote-locked, and reported, stop. Do not create the query, edit Dart/tests,
begin another candidate, or start a later roadmap workstream.
