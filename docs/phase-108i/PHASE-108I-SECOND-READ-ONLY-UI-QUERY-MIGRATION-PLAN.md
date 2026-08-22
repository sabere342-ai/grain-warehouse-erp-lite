# Phase 108I — Second Read-Only UI Query Migration Plan

## A. Phase identity and planning outcome

- Phase: `PHASE_108I`
- Name: **Second Read-Only UI Query Migration — Document History**
- Session type: planning only
- Governing implementation objective: remove exactly one presentation-level
  `AppRepositories` dependency by routing document-history reads through the
  established application query boundary.
- Production implementation is not authorized by this document's creation
  session.

This plan is implementation-ready. It freezes the smallest behavior-preserving
migration compatible with the accepted Phase 108E–108H architecture. It does
not authorize a document-history redesign, a broader locator cleanup, or any
write-path work.

## B. Governing baseline and provenance

The independently verified accepted chain is:

| Phase | Commit | Subject |
|---|---|---|
| Phase 108F | `db84293213d99a79b23bf25b81b565c380aa4655` | `Phase 108F: enforce audit log application boundary` |
| Phase 108G | `5c784d60e7879d18812893a9c9934856e680826e` | `Phase 108G: establish session and business context boundary` |
| Phase 108H | `f6ed0f8dc7fbb69c763115f4c66502b0d3dcb4c7` | `Phase 108H: centralize app shell runtime ownership` |

Verified parentage:

- `108G^ = db84293213d99a79b23bf25b81b565c380aa4655`
- `108H^ = 5c784d60e7879d18812893a9c9934856e680826e`
- both adjacent merge bases equal the earlier commit;
- the accepted history contains no merge commit in this chain.

Locked Phase 108H tag:

- tag: `phase-108h-app-shell-runtime-ownership-locked`
- annotated tag object: `6bd7e338dd9fd64ddfea8845faffbe9102ec09f1`
- peeled target: `f6ed0f8dc7fbb69c763115f4c66502b0d3dcb4c7`

Read-only remote verification matched the same branch head, tag object, and
peeled target. The repository root was
`C:/dev/multi-pos/grain-warehouse-erp-lite`, the branch was
`codex/phase-108h-app-shell-runtime-ownership-boundary`, and the entry
worktree, index, stash, and untracked set were empty.

Accepted authority inspected for this freeze consisted of the current Phase
108H source tree and tests; the Phase 108F/G/H commits; the Phase 108A
re-audit/roadmap; the Phase 108D command/query and composition-root contract;
the Phase 108D `queries.tsv`, `architectural-violations.tsv`, and
`composition-root-inventory.tsv` evidence; and the Phase 108E and Phase 108F
architecture reports. In particular, the accepted Phase 108D query inventory
characterizes document history as a controller/locator read derived locally
over sales, purchases, catalog, and inventory, while the current source was
used as authority for the narrower present-day behavior frozen here.

### Rejected and divergent history isolation

Phase 107H remains rejected. The accepted lineage goes directly from the
accepted Phase 107G commit to Phase 108A; the separate commit
`56921729ea927ee7ff45ca67d774847e65c5d499` (`PHASE 107H: preserve historical
QA evidence (not accepted)`) is not an ancestor of Phase 108H. The local ref
named `codex/phase-107h-governed-14-day-trial-windows-package-acceptance`
currently points at the accepted Phase 108C commit; its stale ref name is not
evidence that Phase 107H was accepted.

The divergent local Phase 108I commit
`d61cf78ca9573d42ae4cc40219489a1c6c651bb3`, parent
`5e7c144b8126363d387fd176c2089a4370b37773`, is not an ancestor of Phase 108H.
Only ref identity, commit identity/parent/subject, and changed-path names were
inventoried. Its code, tests, and planning decisions were not inspected or
used. Later local Phase 108J–108O refs are likewise non-authoritative.

Frozen governance state:

```text
PHASE_107H_ACCEPTED=NO
PHASE_107H_REINTRODUCED=NO
DIVERGENT_HISTORY_USED=NO
ALTERNATE_HISTORY_REUSED=NO
```

## C. Problem statement

`DocumentHistoryScreen` currently imports `app_repositories.dart` and creates
its default controller with
`AppRepositories.documentHistoryRepository`. This makes presentation select a
concrete process-global dependency even though Phase 108F already established
`ApplicationScope -> ApplicationBoundary.queries` as the production
presentation seam.

The repository itself is already a narrow read-only interface. The defect is
ownership and resolution, not document-history behavior. Phase 108I therefore
moves only the screen/controller read path behind an injected typed handler
while retaining the exact existing repository instance and behavior.

## D. Revalidated current-state architecture

The accepted Phase 108H source establishes these facts:

- `main.dart` performs framework/provider bootstrap, calls only
  `AppCompositionRoot.initializeProduction()` for application assembly,
  evaluates the existing trial command, installs `ApplicationScope`, and
  injects root-owned app-shell controllers.
- `AppCompositionRoot.initializeProduction()` is the single production caller
  of `AppRepositories.initializeProduction()` and the canonical assembly
  authority.
- `LegacyApplicationDependencyBridge.captureSharedInstances()` is invoked once
  in production and captures shared objects instead of constructing a second
  repository graph.
- `ApplicationBoundary` contains the trial command slice and the audit-log
  query slice.
- `ApplicationScope` supplies that boundary to presentation.
- `AuditLogsScreen` is the one current feature consumer of
  `ApplicationScope.of(context)` and demonstrates the accepted lifecycle:
  resolve the handler once in `didChangeDependencies`, retain optional injected
  controller support for tests, and dispose only an owned controller.
- Phase 108G owns authenticated session state at the root.
- `NoBusinessContextProvider` intentionally leaves `BusinessContext`
  unavailable; branding is not tenant identity.
- Phase 108H centralizes auth, theme, and business-identity controller
  construction and injects the exact root-owned objects into the app shell.
- No feature/shared source constructs `FoundationDatabase` or a Drift
  repository directly.
- Substantial feature/shared `AppRepositories` usage and screen-local
  controller/service composition remain future debt, not Phase 108I scope.

Current production presentation path:

```text
PurchasesScreen or SalesScreen
  -> pushes const DocumentHistoryScreen()
  -> DocumentHistoryScreen.initState
  -> AppRepositories.documentHistoryRepository
  -> DocumentHistoryController(repository: ...)
  -> DocumentHistoryRepository.listHistory(filter: currentFilter)
```

The backup export, restore preview, and business-data-wipe services also receive
the same `DocumentHistoryRepository` and call `listHistory()`. Those consumers
are not presentation callers and must remain unchanged in Phase 108I.

## E. Document-history baseline characterization

### Repository and storage behavior

`AppRepositories.initializeProduction()` creates one
`LocalDocumentHistoryRepository` over the already-created production purchase,
sale, product-catalog-read, and inventory repositories. In production those
dependencies read SQLite through existing Drift adapters. The history
repository does not open a database, create persistence adapters, maintain a
cache, or expose a write method.

Each `listHistory` call reads, in current order:

1. the product catalog with `includeInactive: true` and builds an ID-to-name
   map;
2. all inventory movements;
3. purchase intakes;
4. sales.

It derives new `DocumentHistoryEntry` objects, sorts them by `createdAt`
descending, applies the filter, and returns an unmodifiable list. Equal-time
tie order is not specified by the contract and must not be newly specified or
changed. Purchase and sale domain records and stock-movement objects are read,
not mutated. Original movement lookup uses exact movement ID; reversal lookup
uses membership in the cancellation reversal-ID set and preserves movement
list order.

The handler migration must return the exact list object received from the
repository and must preserve entry object identity, membership, order, values,
nulls, and empty-list behavior. It must not copy, remap, re-sort, or re-filter
the result.

### Exact filter semantics

The existing `DocumentHistoryFilter` is the sole filter model:

- `from` is inclusive: entries strictly before it are rejected;
- `to` is inclusive: entries strictly after it are rejected;
- `type` is an exact enum match when present;
- `status` is an exact match where status is `cancelled` iff cancellation
  metadata is non-null;
- `productName` is trimmed, lower-cased, and substring-matched against the
  derived product name;
- `query` is trimmed, lower-cased, and substring-matched against entry ID only;
- null, empty, or whitespace-only text filters match all;
- all populated predicates are combined with logical AND;
- filtering occurs after descending-time sorting and preserves the surviving
  sequence.

No duplicate filter/envelope model is authorized. The handler forwards the
same `DocumentHistoryFilter` object unchanged.

### Derived content and Arabic fallbacks

- purchase and single-item sale names use the product catalog;
- unresolved products use the existing Arabic unknown-product fallback;
- multi-item sales retain the existing Arabic item-count label;
- active/cancelled type and status Arabic labels remain unchanged;
- quantities, optional prices/totals, creator values, notes, cancellation
  metadata, original movement, and reversal movements remain unchanged.

### Controller state, permissions, notifications, and failures

`DocumentHistoryController` starts with an empty entry list, a default filter,
`isLoading == false`, and `canViewOwnerAudit == false`. On `load(user)` it:

1. sets loading true;
2. sets audit-detail visibility to
   `user.permissions.canViewAuditLogs || user.permissions.canCancelInvoice`;
3. notifies once;
4. awaits the repository using the current filter;
5. replaces entries, sets loading false, and notifies once on success.

`applyFilter` stores the exact new filter before invoking `load`. There is no
controller-side authorization denial: an authenticated employee can read
history, while cancellation audit details are rendered only when
`canViewOwnerAudit` is true. The screen does not initiate a load for a null
authenticated user and shows the existing Arabic sign-in message.

The controller currently does not catch repository exceptions. The exact
exception object propagates. On failure, the leading notification has already
occurred, entries remain the previous entries, `isLoading` remains true, audit
visibility reflects the supplied user, and an applied filter remains stored.
This imperfect but observable behavior is frozen; Phase 108I must not add error
translation, `finally`, retry, or state cleanup.

### Presentation and navigation behavior

- Purchases and Sales continue to push the same screen route.
- The shared route scaffold key, RTL direction, `GhalalPageHeader`, title,
  permission-sensitive subtitle, back `maybePop`, filters, apply/clear actions,
  inclusive day-boundary conversion, loading state, empty state, cards,
  expansion behavior, money/date text, movement lines, and audit details stay
  unchanged.
- A screen-created controller is owned and disposed by the screen; an injected
  test controller is not disposed by the screen.
- The initial authenticated-user load remains a one-time post-frame action.

## F. Frozen target architecture

After Phase 108I the sole production presentation path is:

```text
AppRepositories.documentHistoryRepository (existing singleton instance)
  -> LegacyApplicationDependencyBridge.captureSharedInstances
  -> ApplicationRepositoryDependencies.documentHistoryRepository
  -> AppCompositionRoot constructs LoadDocumentHistoryQueryHandler
  -> ApplicationBoundary.queries.documentHistory
  -> ApplicationScope
  -> DocumentHistoryScreen.didChangeDependencies
  -> DocumentHistoryController(queryHandler: ...)
  -> LoadDocumentHistoryQuery(filter: currentFilter)
  -> handler calls the injected repository.listHistory(filter: sameFilter)
  -> ApplicationQueryResult<List<DocumentHistoryEntry>>
```

There is one database, one legacy repository graph, one document-history
repository instance, and one production handler instance. The bridge contains
the one intentional centralized `AppRepositories.documentHistoryRepository`
capture that replaces the screen reference.

## G. In-scope atomic implementation operations

1. Add `LoadDocumentHistoryQuery` carrying the existing filter.
2. Add `LoadDocumentHistoryQueryHandler` using constructor-injected
   `DocumentHistoryRepository`.
3. Return the existing `ApplicationQueryResult` with the existing local
   metadata type.
4. Add the document-history repository to
   `ApplicationRepositoryDependencies`.
5. Capture the existing static repository once in the compatibility bridge.
6. Construct the handler in `AppCompositionRoot` from the captured dependency.
7. Expose it as the one new `ApplicationBoundary.queries` member.
8. Adapt `DocumentHistoryController` to execute the typed query.
9. Adapt the default screen path to resolve the handler from
   `ApplicationScope` in `didChangeDependencies`.
10. Remove the document screen's locator import and reference.
11. Update only the Phase 108F concrete-query count guard, preserving every
    original audit-log assertion.
12. Add the focused Phase 108I architecture and parity tests specified below.

## H. Explicitly out of scope

The implementation must not include:

- create/cancel sale, purchase, expense, payment, advance, closing, approval,
  or profitability command migration;
- durable outbox, inbox, provisional lifecycle, idempotent-command
  infrastructure, networking, cloud adapters, Supabase, remote auth, or RLS;
- fabricated `BusinessContext` or user-to-business mapping;
- schema, migration, generated Drift, dependency, lockfile, database-version,
  platform, Windows, Android, or build-configuration changes;
- repository implementation or document-history model redesign;
- filter, ordering, permission, Arabic text, navigation, audit visibility,
  loading, notification, or exception-behavior changes;
- backup/export/restore/wipe document-history consumer migration;
- any other `AppRepositories` consumer or broad service-locator cleanup;
- Phase 107H artifacts/code or divergent Phase 108I+ code/tests/decisions;
- opportunistic fixes, formatting rewrites, or unrelated refactors.

## I. Frozen implementation file contract

### Expected modified files — exact

```text
lib/application/application_boundary.dart
lib/application/application_dependencies.dart
lib/composition/app_composition_root.dart
lib/composition/legacy_application_dependency_bridge.dart
lib/core/documents/document_history_controller.dart
lib/features/documents/document_history_screen.dart
test/phase108f_first_read_only_ui_query_migration_test.dart
```

### Expected added files — exact

```text
lib/application/queries/load_document_history_query.dart
test/phase108i_second_read_only_ui_query_migration_test.dart
```

### Confirmation-only; no modification expected

```text
test/document_history_test.dart
```

The existing document-history tests inject repositories through the controller
constructor. The compatibility contract below keeps those calls valid, so no
change to this file is justified.

No separate Phase 108I implementation report is required. Phase 108G and 108H
establish the current convention of commit/test evidence without a per-phase
execution report, and this plan already holds the frozen contract. The
implementation session must not edit this plan merely to append execution
results. If governance later explicitly authorizes an execution report, that
must be a separate scope decision before implementation mutation.

### Protected and out-of-scope paths

```text
lib/core/documents/document_history.dart
lib/core/persistence/**
lib/core/sales/**
lib/core/purchases/**
lib/core/backup/**
pubspec.yaml
pubspec.lock
windows/**
android/**
```

Any need to change a protected path is a scope-contract conflict and blocks
implementation closure.

## J. Frozen type and API contract

### `LoadDocumentHistoryQuery`

- is an immutable typed query in
  `lib/application/queries/load_document_history_query.dart`;
- follows the established Phase 108F query naming and const-value style;
- has one required named field, `DocumentHistoryFilter filter`;
- does not duplicate, normalize, serialize, or default the filter.

Equivalent intended shape:

```dart
final class LoadDocumentHistoryQuery {
  const LoadDocumentHistoryQuery({required this.filter});
  final DocumentHistoryFilter filter;
}
```

### `LoadDocumentHistoryQueryHandler`

- implements
  `ApplicationQueryHandler<LoadDocumentHistoryQuery, List<DocumentHistoryEntry>>`;
- receives one `DocumentHistoryRepository` through its constructor and stores
  it privately;
- calls exactly
  `repository.listHistory(filter: query.filter)` once per execution;
- returns
  `ApplicationQueryResult<List<DocumentHistoryEntry>>` containing that exact
  repository list and `const LocalQueryResultMetadata()`;
- performs no catch, map, copy, sort, filter, cache, write, locator lookup,
  database opening, or repository construction;
- imports neither `app_repositories.dart` nor persistence/Drift adapters.

### `ApplicationRepositoryDependencies`

- gains one required `DocumentHistoryRepository documentHistoryRepository`;
- retains every Phase 108E–108H dependency unchanged;
- receives the exact shared object from the legacy bridge.

### `ApplicationBoundary.queries`

- retains `LoadAuditLogsQueryHandler auditLogs` unchanged;
- gains exactly one member,
  `LoadDocumentHistoryQueryHandler documentHistory`;
- contains exactly two concrete production query slices after the phase.

### `DocumentHistoryController`

The smallest compatible constructor migration is frozen:

- accept optional named `DocumentHistoryRepository repository` for existing
  focused tests;
- accept optional named `LoadDocumentHistoryQueryHandler queryHandler` for the
  production path;
- require exactly one of the two inputs in debug assertions;
- when a repository is supplied, wrap it immediately in a
  `LoadDocumentHistoryQueryHandler`; this is test-friendly constructor
  injection, not locator access or a second production composition path;
- store only the handler and remove the repository field;
- on load, execute `LoadDocumentHistoryQuery(filter: _filter)` and assign
  `result.value` to `_entries`;
- do not add locator fallback, public production factory, metadata UI state,
  error translation, catch/finally, or any state/notification change.

This preserves every current `DocumentHistoryController(repository: ...)` test
construction. Existing document-history tests therefore remain unchanged.

### `DocumentHistoryScreen`

- retains optional controller injection;
- removes `app_repositories.dart` and every `AppRepositories` token;
- mirrors the accepted audit-screen ownership lifecycle: determine ownership
  in `initState`, resolve the handler once from
  `ApplicationScope.of(context).queries.documentHistory` in guarded
  `didChangeDependencies`, and schedule the same one-time post-frame load;
- does not resolve inherited scope from `initState`;
- does not require `ApplicationScope` when a controller was explicitly
  injected by a focused widget test;
- retains all rendering, callbacks, text, route, and disposal behavior.

## K. Ownership and lifetime proof contract

Production identity is proved without exposing a public handler repository
getter:

1. the bridge source contains exactly one centralized capture of
   `AppRepositories.documentHistoryRepository`;
2. a production-root test asserts
   `same(application.dependencies.repositories.documentHistoryRepository,
   AppRepositories.documentHistoryRepository)`;
3. root source/wiring asserts the handler is constructed from
   `dependencies.repositories.documentHistoryRepository`;
4. the boundary exposes that constructed handler;
5. a working production handler call returns the empty in-memory database
   result and local metadata;
6. `AppRepositories.database` remains the exact injected test database.

Together these assertions prove the identity chain without adding production
introspection solely for a test. No second repository, database, or cache may
be constructed.

## L. Behavioral parity and metadata contract

The implementation must preserve:

- exact filter-object forwarding and one repository call;
- repository list identity, entry identity, membership, sequence, values,
  nullability, immutability characteristics, and empty results;
- exact repository exception object propagation from the handler and
  controller;
- descending-time repository ordering and unspecified equal-time tie behavior;
- current controller filter storage, permission calculation, loading
  transitions, two success notifications, one leading failure notification,
  previous-entry retention on failure, and loading-true failure state;
- authenticated owner/employee read access and existing audit-detail
  visibility;
- every existing Arabic label/message/fallback and presentation/navigation
  behavior;
- read-only operation with no audit, accounting, inventory, document, or other
  mutation.

Every successful handler result uses the already-established exact metadata:

```text
LocalQueryResultMetadata
  source = QueryResultSource.local
  readAuthority = LocalReadAuthority.sqlite
  consistency = LocalQueryConsistency.currentKnownState
```

No competing provenance abstraction, cloud claim, cache claim, or provisional
state is permitted.

## M. Re-measured architecture metrics

The following Phase 108H baseline metrics were independently reproduced:

| Metric | Current | Required post-108I |
|---|---:|---:|
| Feature/shared files with `AppRepositories.*` | 42 | 41 |
| Feature/shared `AppRepositories.*` references | 151 | 150 |
| Distinct feature/shared locator properties | 25 | 24 if document history has no other feature/shared caller |
| `DocumentHistoryScreen` locator files | 1 | 0 |
| `DocumentHistoryScreen` locator references | 1 | 0 |
| Feature/shared `ApplicationScope.of` consumer files | 1 | 2 |
| Concrete application query-handler files | 1 | 2 |
| Legacy bridge production invocations | 1 | 1 |
| Direct composition-root production callers | 1 | 1 |
| Direct feature/shared Drift/database constructor references | 0 | 0 |
| Screen/feature-local service constructor sites | 13 | 13 |
| Phase 108E/F/G/H guard tests | 36 | 36 or more, all green |
| All-`lib` `AppRepositories.*` references | 161 | expected 161 |

The 13 service-constructor sites are the 12 `*_screen.dart` service
constructions plus `InventoryAttentionService` in the dashboard alerts feature
section; the `AiExecutionService` class declaration is not a construction site.

The all-`lib` count is expected to remain 161 because the one removed screen
reference is replaced by one intentional bridge capture. The authoritative
monotonic metric is feature/shared presentation usage. Exact post-change source
searches must be used; if another independently authorized baseline change has
altered counts before implementation, stop rather than silently weakening the
one-file/one-reference reduction contract.

## N. Focused test and architecture-guard contract

Add
`test/phase108i_second_read_only_ui_query_migration_test.dart` with explicit
assertions grouped as follows.

### Handler parity

1. Construct a filter with all fields populated; assert the repository spy
   receives the same filter object and exactly one call.
2. Supply a deliberately ordered list with distinct entry objects; assert the
   result list is the same object, each entry is identical, membership and
   order are unchanged, and no remapping/sorting occurs.
3. Supply an empty list; assert successful empty preservation.
4. Throw a sentinel object from the repository; assert the future throws that
   same object.
5. Assert metadata type and the exact local/SQLite/current-known-state enum
   values.

### Controller parity

6. Prove both authorized constructor forms route through the handler while the
   production form accepts the composed handler and the legacy focused-test
   form accepts an injected repository.
7. Assert `applyFilter` forwards the same filter; successful load changes
   loading true to false, preserves entry identities, calculates audit
   visibility with the existing OR expression, and notifies exactly twice in
   the current state sequence.
8. Assert an employee without either audit/cancellation permission can still
   load entries but has `canViewOwnerAudit == false`.
9. Assert a sentinel handler/repository exception remains identical and
   preserves the current failure state: previous entries unchanged, loading
   true, current filter retained, and one leading notification.

### Production wiring and scope

10. Initialize the production root with an in-memory database and stub trial
    evaluator; assert dependency repository identity and database identity with
    `same`.
11. Execute `application.queries.documentHistory` and assert a working empty
    result plus local metadata.
12. Around that production handler execution, read the public catalog,
    inventory-movement, purchase, sale, and audit-log surfaces before and
    after; assert their empty counts/state remain identical. This is the
    focused runtime no-write proof and complements the read-only interface and
    static import/construction guards.
13. Assert `ApplicationBoundary.queries` exposes both the unchanged audit
    handler and the new document-history handler.
14. Widget-test `ApplicationScope` resolution and the default
    `DocumentHistoryScreen` path under the root-owned boundary; retain injected
    controller tests without requiring a scope.

### Static ownership and no-write guards

15. Assert the screen contains
    `ApplicationScope.of(context).queries.documentHistory`, no
    `app_repositories.dart`, and no `AppRepositories`.
16. Assert the controller contains the typed handler/query and no
    `app_repositories.dart` or `AppRepositories`.
17. Assert the handler contains no locator, `FoundationDatabase`, Drift adapter,
    repository construction, or write verb and depends only on the read-only
    repository contract.
18. Count concrete `*_query.dart` handlers using the existing Phase 108F
    predicate; require exactly the set
    `load_audit_logs_query.dart` and `load_document_history_query.dart`.
19. Recount feature/shared locator metrics and require the exact 151/42 to
    150/41 reduction, two scope consumers, one bridge invocation, one root
    caller, and zero direct feature/shared database/Drift constructors.

Modify the Phase 108F `Q11` guard only: change its expected concrete-handler
count from one to two and assert the exact two-file set. Keep Phase 108F Q1–Q10,
all audit handler behavior, audit screen locator removal, and audit production
wiring untouched. Do not weaken the handler-detection predicate.

Existing `test/document_history_test.dart` remains the authoritative domain/UI
regression for active/cancelled purchases and sales, dates, statuses, Arabic
status, owner cancellation metadata, linked movement display, and employee
audit-detail hiding. It is run unchanged.

## O. Architecture invariants

1. `main.dart` remains a thin bootstrap.
2. `AppCompositionRoot` remains the sole production assembly authority.
3. `ApplicationScope` remains the presentation access seam.
4. The document screen and new handler contain no locator access.
5. The exact existing document-history repository reaches the handler.
6. No duplicate repository, database, or cache is created.
7. Filtering, ordering, membership, permissions, state, notifications,
   failures, visibility, navigation, and presentation remain unchanged.
8. Query provenance remains local SQLite/current-known-state.
9. Document history remains read-only.
10. `BusinessContext` remains unavailable without authoritative membership.
11. Phase 108F audit behavior and guards remain intact.
12. Feature/shared locator use decreases monotonically by one reference and
    one file.
13. Phase 107H and divergent Phase 108I+ histories remain isolated.
14. No schema, migration, dependency, generated-database, Supabase, platform,
    or build-config change occurs.

## P. Acceptance criteria

- **AC-01 — Screen locator removal:** zero `AppRepositories` references and no
  locator import in `DocumentHistoryScreen`.
- **AC-02 — Monotonic reduction:** feature/shared locator metrics move exactly
  from 151 references/42 files to 150 references/41 files.
- **AC-03 — Boundary exposure:** exactly one document-history handler is added
  to `ApplicationBoundary.queries`.
- **AC-04 — Two query slices:** only audit log and document history are concrete
  production query slices; audit remains unchanged.
- **AC-05 — Shared identity:** production dependency is
  `same(AppRepositories.documentHistoryRepository)` and no replacement graph
  exists.
- **AC-06 — Behavioral parity:** exact filter forwarding, order, membership,
  entry/list identity, empty behavior, and exception identity pass.
- **AC-07 — Provenance:** success reports the established
  local/SQLite/current-known-state metadata.
- **AC-08 — Controller ownership:** controller reads through the typed handler
  and has no locator access.
- **AC-09 — Permissions:** owner/employee read and audit-detail visibility are
  unchanged.
- **AC-10 — Presentation parity:** filters, loading, notifications, routes,
  back behavior, empty state, and Arabic presentation remain green.
- **AC-11 — No writes:** no document, audit, accounting, inventory, or
  repository-implementation write/change occurs.
- **AC-12 — Historical guards:** Phase 108E/F/G/H guards remain green.
- **AC-13 — Full verification:** full `flutter test` and `flutter analyze`
  pass.
- **AC-14 — Hygiene:** non-writing formatter and `git diff --check` pass.
- **AC-15 — Protected domains:** schema, migrations, generated DB,
  dependencies, Supabase, platform, and build configuration are unchanged.
- **AC-16 — Frozen scope:** implementation diff contains only the nine exact
  files in Section I.
- **AC-17 — Governance:** locked 108F → 108G → 108H ancestry is untouched and
  rejected/divergent histories remain isolated.

## Q. Future implementation verification matrix

Run in diagnostic order and record exact pass/fail/skip counts:

```powershell
flutter test test\phase108i_second_read_only_ui_query_migration_test.dart
flutter test test\document_history_test.dart
flutter test test\phase101h_route_surface_presentation_test.dart
flutter test test\phase90_push_route_screens_design_system_test.dart
flutter test test\phase108e_application_boundary_composition_root_test.dart test\phase108f_first_read_only_ui_query_migration_test.dart test\phase108g_session_business_context_boundary_test.dart test\phase108h_app_shell_runtime_ownership_test.dart
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git diff --check
flutter build windows --release
```

Then run exact source metrics, protected-path diff checks, `git diff --check`,
explicit staging checks, and final Git integrity checks. No deployment,
Supabase, network, or remote mutation test belongs to this phase.

## R. Planning-session baseline evidence

Current Phase 108H evidence generated independently in this planning session:

- Phase 108E/F/G/H architecture group: **36 passed, 0 failed, 0 skipped**.
- Document-history plus Phase 101H/90 presentation group: **20 passed, 0
  failed, 0 skipped**.
- Full default suite: **2,454 passed, 0 failed, 0 skipped** in 5:57.
- `flutter analyze`: **PASS — No issues found** in 103.6 seconds.
- Repository-wide formatter through the Flutter SDK's underlying Dart
  executable with the exact non-writing arguments and `.` target: **10,293
  files, 0 changed**, 348.31 seconds.
- The `dart.bat` wrapper attempt produced no output for more than two minutes
  and was interrupted; the underlying executable completed the same gate. This
  is tooling startup/scan behavior, not a formatting failure.
- `git diff --check`: **PASS**.
- Worktree and index remained clean after every read-only gate.
- Windows release build was not run during planning because it is optional for
  planning; it is mandatory for implementation closure.

These are current baseline results, not inherited Phase 108F counts.

## S. Rollback, failure, no-mutation, and future-work contract

If any focused assertion, historical guard, full test, analyzer, formatter,
build, source metric, protected-path check, or Git-scope check fails during
implementation, the implementation remains uncommitted. Do not weaken tests,
broaden scope, repair unrelated defects, or reuse alternate history. The
locked Phase 108H commit remains the authoritative rollback point.

The implementation must declare no changes to schema, migrations, generated
database code, dependencies, cloud/Supabase, platform/build configuration,
Phase 107H artifacts, or divergent history. It must not push, tag, deploy,
merge, rebase, cherry-pick, amend, or rewrite accepted history unless a later
session explicitly authorizes the corresponding operation.

Future work recorded but not authorized here:

- sales and other command ownership migrations;
- durable outbox, provisional lifecycle, and idempotent command processing;
- authoritative business membership and `BusinessContext`;
- remaining feature/shared service-locator migration;
- screen-local service/controller construction debt;
- backup/restore/wipe history consumer migration;
- cloud/Supabase adapters, RLS, Android, and cross-platform work.

Phase 108I succeeds only as this one read-only ownership migration—no more and
no less.
