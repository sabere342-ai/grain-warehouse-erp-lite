# Phase 108L — Dashboard App Bar Business Logo Query Planning

## 1. Phase Identity

```text
SESSION = PHASE_108L_PLANNING
AUTHORIZED_WORK = PLANNING_ONLY
IMPLEMENTATION = NOT_STARTED
CANONICAL_PHASE_108L_SCOPE = ONE_LOCAL_READ_ONLY_DASHBOARD_APP_BAR_BUSINESS_LOGO_UI_QUERY_MIGRATION_THROUGH_APPLICATION_BOUNDARY
```

This artifact freezes an implementation-ready plan for one read seam. It does
not authorize or contain production, test, persistence, database, Supabase, or
remote changes.

## 2. Governing Baseline

The fresh-planning entry was verified by Git object identity:

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
REMOTE_FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
REMOTE_PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
GOVERNANCE_COMMIT = 2172ae49119a6194ab419b0157b5e1e811ba00f9
GOVERNANCE_PARENT = 2d6abc71decd618f02540873e5e0f389f5c17408
GOVERNANCE_SUBJECT = Phase 108L: discover and freeze canonical scope
GOVERNANCE_CHANGED_FILE = docs/phase-108l/PHASE-108L-SCOPE-DISCOVERY.md
ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
ENTRY_CLASSIFICATION = FRESH_PLANNING
```

The direct-parent chain is locked and was verified exactly:

```text
951ed1cfe4e673f376dd9e270f2d7076fc8f1750
  -> bc1d37f430ae3708fe2cd4e3c93386f8fbecf1af
  -> 273640cba345a8fbfdd6a5e2f2e6b7bed74b8909
  -> 2d6abc71decd618f02540873e5e0f389f5c17408
  -> 2172ae49119a6194ab419b0157b5e1e811ba00f9
```

The local and remote annotated tag objects and peeled targets matched:

| Tag | Annotated object | Peeled target |
|---|---|---|
| `phase-108j-implementation-locked` | `4e1c781a86beece985eb8ac3ae796976240c3cdd` | `951ed1cfe4e673f376dd9e270f2d7076fc8f1750` |
| `phase-108k-planning-baseline-locked` | `4d8377fc8abd37c8f301674e2fe624dd5057511e` | `273640cba345a8fbfdd6a5e2f2e6b7bed74b8909` |
| `phase-108k-implementation-locked` | `650eef8ace456de9c69b60b7f46cac5434d09d7c` | `2d6abc71decd618f02540873e5e0f389f5c17408` |
| `phase-108l-governance-reconciliation-locked` | `18207fa2407010643f6228f100690a8f8ff04ce5` | `2172ae49119a6194ab419b0157b5e1e811ba00f9` |

The Phase 108L governance tag object type is `tag`. No tag was created,
moved, or deleted during planning.

The divergent local ref
`codex/phase-108l-fourth-read-only-ui-slice-discovery-freeze` was not checked
out, merged, rebased, cherry-picked, reset to, modified, deleted, or used as a
baseline. Its locked disposition remains non-authoritative historical evidence.

## 3. Canonical Scope

```text
CANONICAL_PHASE_108L_SCOPE =
ONE_LOCAL_READ_ONLY_DASHBOARD_APP_BAR_BUSINESS_LOGO_UI_QUERY_MIGRATION_THROUGH_APPLICATION_BOUNDARY
```

Phase 108L will migrate only the managed-file logo-byte read performed by the
private `DashboardShell._AppBarLogo` widget. The same UI, filename, repository
instance, managed local file, returned bytes, null behavior, and error hiding
remain in place; only ownership of the read moves from a presentation locator
call to a typed application query.

## 4. Explicit Non-Goals

```text
NO_DASHBOARD_BUNDLE_MIGRATION
NO_DASHBOARD_STATISTICS_MIGRATION
NO_FINANCIAL_METRICS_MIGRATION
NO_BUSINESS_PROFILE_EDITING
NO_LOGO_UPLOAD_OR_WRITE_FLOW
NO_STORAGE_SCHEMA_CHANGE
NO_DATABASE_MIGRATION
NO_SUPABASE_MUTATION
NO_NETWORK_MIGRATION
NO_GENERAL_REPOSITORY_REFACTOR
NO_GENERAL_DI_REWRITE
NO_APP_SHELL_REDESIGN
NO_SESSION_BOUNDARY_REDESIGN
NO_HISTORY_REWRITE
NO_HISTORICAL_BRANCH_MERGE
```

Also excluded are `BusinessIdentityHeader`, the Settings logo preview,
printable documents, PDF/export branding, financial-report branding, business
identity metadata reads or writes, caching, image processing, navigation,
responsive layout, any second query, and every other dashboard/report/data
read. `BusinessIdentityRepository` will not be split or redesigned.

## 5. Current Runtime/UI Read Path

Repository evidence establishes this exact path:

```text
BusinessIdentityController.identity
  -> BusinessIdentity.hasLogo
  -> DashboardShell AppBar title
  -> _AppBarLogo(managedFileName: identity.logo.managedFileName)
  -> FutureBuilder<Uint8List?>
  -> _AppBarLogo._loadBytes
  -> AppRepositories.businessIdentityRepository
  -> BusinessIdentityRepository.loadLogoBytes(managedFileName)
  -> LocalBusinessIdentityRepository
  -> managed local logo file
```

Relevant current sources are:

- `lib/features/dashboard/dashboard_shell.dart`: owns the App Bar, derives
  `hasLogo` and the managed filename from `BusinessIdentityScope`, and performs
  the direct locator read in `_AppBarLogo`;
- `lib/core/business_identity/business_identity_repository.dart`: defines the
  broad read/write repository and implements the managed-file read;
- `lib/core/business_identity/business_identity.dart`: defines valid-logo and
  display-name semantics;
- `lib/app/grain_warehouse_app.dart`: owns `BusinessIdentityScope` around the
  routed dashboard;
- `lib/main.dart`: owns `ApplicationScope` above the complete application.

`LocalBusinessIdentityRepository.loadLogoBytes` returns null for an empty or
path-like filename, returns null when the file is missing, and otherwise
returns `File.readAsBytes()`. The private UI helper currently avoids the
repository call for an empty filename, catches every read exception and maps it
to null, shows nothing while the future has no data, and uses `Image.memory`
with `BoxFit.contain`, maximum height 32, maximum width 80, and a shrink
`errorBuilder`.

## 6. Current Architectural Violation

`DashboardShell` imports `app_repositories.dart`, selects the concrete global
repository instance, and invokes its persistence-facing managed-file API. The
UI therefore owns data-access selection and can see a repository that also
exposes `saveIdentity`, `saveLogoBytes`, and `deleteLogoFile`. This bypasses the
already established `ApplicationScope -> ApplicationQueries` boundary and
makes the presentation layer responsible for persistence wiring.

The violation is ownership/coupling, not incorrect logo behavior. The target
must preserve the existing behavior rather than redesign it.

## 7. Target Application Boundary

```text
DashboardShell._AppBarLogo
  -> ApplicationScope.of(context).queries.businessLogo
  -> LoadBusinessLogoQueryHandler.execute
  -> ApplicationDependencies.repositories.businessIdentityRepository
  -> same captured BusinessIdentityRepository instance
  -> LocalBusinessIdentityRepository
  -> same managed local logo file
```

The accepted Phase 108F, 108I, and 108K pattern is reused: immutable request,
typed handler, `ApplicationQueryResult`, explicit local provenance,
`ApplicationQueries` exposure, root composition from an already captured exact
dependency, and UI resolution through `ApplicationScope`.

The existing application abstraction is extended by one member. No new
repository port, service, controller, dependency bundle, bridge, scope, or
runtime owner is required.

## 8. Exact Query Contract

The later implementation must use this frozen semantic contract:

```text
REQUEST_TYPE = LoadBusinessLogoQuery
REQUEST_FIELD = String managedFileName (required, no default)
HANDLER_TYPE = LoadBusinessLogoQueryHandler
HANDLER_INTERFACE = ApplicationQueryHandler<LoadBusinessLogoQuery, Uint8List?>
HANDLER_DEPENDENCY = BusinessIdentityRepository
APPLICATION_QUERIES_MEMBER = businessLogo
OPERATION = loadLogoBytes only
CALL_COUNT = zero for empty filename; exactly one otherwise
```

The handler must not import or reference `AppRepositories`, `File`, Drift,
SQLite, Supabase, network APIs, database APIs, or repository write methods.
It must not load the broader `BusinessIdentity`, inspect session/business
context, cache, decode, copy, map, or transform bytes.

For an empty filename the handler returns a successful result containing null
and managed-file metadata without calling the repository. For every non-empty
filename it forwards the string verbatim exactly once. Filename safety checks
remain owned by the existing repository; duplicating them in the handler would
create behavior and ownership drift.

## 9. Input / Output Semantics

### Input

The sole input is `managedFileName` from the already loaded
`BusinessIdentity.logo`. There is no business/shop ID, user ID, session
context, business context, tenant key, path, MIME type, or `LogoMetadata`
object in the request.

### Output

The value is `Uint8List?`, the smallest shape the App Bar consumes. On success
the exact byte-list instance returned by the repository is preserved. A null
value is a successful read outcome, not an error object. The UI does not
receive `BusinessIdentity`, `LogoMetadata`, a file path, a database row, or the
repository itself.

### Metadata

`LocalReadAuthority` gains exactly one value, `managedFile`. Successful query
results, including null, carry:

```text
source = QueryResultSource.local
readAuthority = LocalReadAuthority.managedFile
consistency = LocalQueryConsistency.currentKnownState
```

Existing SQLite query metadata remains unchanged.

## 10. Missing / Null Logo Semantics

- No business-identity record resolves to the existing empty identity; the
  App Bar sees `hasLogo == false`, builds no `_AppBarLogo`, and executes no
  query.
- Missing or invalid `LogoMetadata` likewise builds no `_AppBarLogo` and
  executes no query.
- An empty filename, if supplied to the private widget, yields null without a
  repository call and renders `SizedBox.shrink`.
- A path-like filename continues to be passed to the repository, which returns
  null; no new validation error is introduced.
- A missing managed file returns null and renders nothing.
- Exact non-null bytes are passed to the unchanged `Image.memory` rendering
  path.
- Invalid image bytes continue to render nothing through the existing
  `errorBuilder`.
- A repository/file read exception propagates unchanged from the handler. The
  private widget preserves its current catch-all behavior and converts the
  failure to null, so no new error UI, retry, log, snackbar, or fallback logo
  is added.
- The loading state continues to render nothing. No spinner, cache, retained
  image, or stale-result policy is introduced.

## 11. Business / Session Context Handling

```text
BUSINESS_CONTEXT_ROLE = NONE
SESSION_CONTEXT_ROLE = NONE_BEYOND_EXISTING_APP_ACCESS
AUTHORIZATION_CHANGE = NONE
```

The managed filename is already selected by the root-owned
`BusinessIdentityController`; current production is a single local business
identity and `NoBusinessContextProvider.current` may be null. The query neither
requires nor fabricates business membership. An unavailable business context
does not change the read. An unavailable authenticated user continues to be
handled by `DashboardShell` before App Bar construction.

If implementation evidence unexpectedly makes a business/shop/session input
necessary, Phase 108L stops for scope review instead of redesigning context.

## 12. Runtime Ownership / Construction

`AppCompositionRoot.initializeProduction` already captures
`AppRepositories.businessIdentityRepository` once as
`sharedBusinessIdentityRepository`, supplies it to
`BusinessIdentityController`, and passes the exact same instance through
`LegacyApplicationDependencyBridge` into
`ApplicationDependencies.repositories.businessIdentityRepository`.

The root will construct one `LoadBusinessLogoQueryHandler` from
`dependencies.repositories.businessIdentityRepository` and expose it through
the root-owned `ApplicationBoundary.queries.businessLogo`. Its lifetime is the
same as that boundary. `ApplicationScope` supplies the handler to the routed
dashboard. The controller, dependency bridge, dependency classes, and scope
remain unchanged.

Production must prove identity, not only type:

```text
application.dependencies.repositories.businessIdentityRepository
  same(AppRepositories.businessIdentityRepository)
handler dependency
  same(application.dependencies.repositories.businessIdentityRepository)
```

No second repository or handler may be constructed inside `DashboardShell`.

## 13. Dashboard Consumption Path

Only `_AppBarLogo._loadBytes` changes its acquisition path. It resolves
`ApplicationScope.of(context).queries.businessLogo`, executes
`LoadBusinessLogoQuery(managedFileName: managedFileName)`, and consumes only
`result.value`. The existing empty-name short circuit may remain in the widget
as an observable-behavior guard in addition to the handler contract, provided
it still produces zero repository calls.

The `FutureBuilder`, private-widget boundary, conditional `hasLogo` inclusion,
business display name, App Bar layout, dimensions, fit, loading behavior,
catch/hide behavior, and image error behavior remain unchanged.
`dashboard_shell.dart` must no longer import or reference `AppRepositories`.
Every other logo consumer remains exactly on its current path.

## 14. Expected Production File Touch Set

| Path | Current role | Planned change | Why required | Why in scope |
|---|---|---|---|---|
| `lib/application/queries/load_business_logo_query.dart` | Does not yet exist | Create the immutable request and read-only handler with the frozen contract | Provides the application-facing query seam | It is the single selected read |
| `lib/application/queries/application_query.dart` | Defines generic result metadata and SQLite-only local authority | Add only `LocalReadAuthority.managedFile` | Truthfully describes the managed-file source | Provenance is inseparable from this query |
| `lib/application/application_boundary.dart` | Defines `ApplicationQueries` with audit logs, document history, and product catalog | Import the new query and add required `businessLogo` | Makes the handler application-facing | One member for one query |
| `lib/composition/app_composition_root.dart` | Constructs the root-owned query handlers | Construct `LoadBusinessLogoQueryHandler` from `dependencies.repositories.businessIdentityRepository` | Preserves exact shared dependency identity and lifetime | Existing root is the accepted owner |
| `lib/features/dashboard/dashboard_shell.dart` | Owns the App Bar and directly reads logo bytes through `AppRepositories` | Route only `_AppBarLogo` through `ApplicationScope.queries.businessLogo`; remove the locator import/reference | Closes the selected UI-to-persistence bypass | It is the only authorized consumer |

Expected unchanged production evidence:

- `lib/application/application_dependencies.dart`;
- `lib/composition/legacy_application_dependency_bridge.dart`;
- `lib/composition/application_scope.dart`;
- `lib/app/app_repositories.dart`;
- `lib/app/grain_warehouse_app.dart` and `lib/main.dart`;
- `lib/core/business_identity/business_identity_repository.dart`;
- `lib/core/business_identity/business_identity_controller.dart`;
- `lib/core/business_identity/business_identity.dart`;
- every other file containing `loadLogoBytes`.

Any production path beyond the five-row touch set is an implementation stop
gate unless a separately reviewed scope correction proves it unavoidable.

## 15. Expected Test File Touch Set

| Path | Test purpose | Behavior protected |
|---|---|---|
| `test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart` (CREATE) | Focused handler, metadata, shared-instance composition, Dashboard App Bar widget, no-write, and one-consumer guards | Exact input/output/null/error/rendering/ownership/scope behavior |
| `test/phase108f_first_read_only_ui_query_migration_test.dart` (MODIFY) | Update the current-tree concrete query inventory from three to four | Retains the Phase 108F audit migration while acknowledging only the new query |
| `test/phase108i_second_read_only_ui_query_migration_test.dart` (MODIFY) | Update current-tree query inventory and exact locator/scope metrics for one removed Dashboard locator | Retains the Phase 108I document-history migration and proves a one-seam delta |
| `test/phase108k_product_catalog_query_migration_test.dart` (MODIFY) | Add `businessLogo` to its explicit `ApplicationQueries` reconstruction and update the current query inventory from three to four | Retains all Phase 108K product behavior and proves no second migration inside 108L |

The expected Phase 108I metric delta is exactly one selected UI locator:

```text
feature/shared locator references: 146 -> 145
feature/shared files with locator: 40 -> 39
feature/shared ApplicationScope consumers: 4 -> 5
all-lib locator references: 162 -> 161
```

`test/phase108h_app_shell_runtime_ownership_test.dart` already proves the
shared business-identity repository capture and should remain unchanged unless
a focused failure demonstrates that one additive assertion is essential.
`test/phase68_business_logo_invoice_windows_icon_test.dart`,
`test/phase83_shell_navigation_responsive_test.dart`, and
`test/phase96_in_app_business_identity_app_shell_branding_test.dart` are
regressions to run, not expected edits. Phase 49 dashboard harnesses have no
logo scope and must continue to avoid resolving the query when no valid logo is
present.

No historical SHA assertion may be updated. Any additional test modification
is `DISCOVERY_DEPENDENT` on a focused failure that directly asserts the current
intentionally changed seam; broad rebaselining is forbidden.

## 16. Test Strategy

The focused Phase 108L suite must prove at least:

1. empty filename returns null with zero repository calls;
2. a non-empty filename is forwarded verbatim exactly once;
3. exact returned `Uint8List` identity is preserved;
4. repository null/missing-file outcome is preserved;
5. exact repository exception identity propagates from the handler;
6. metadata is local/managed-file/current-known-state for byte and null results;
7. handler source has no locator, concrete infrastructure, context, network,
   cache, decode, or write token;
8. no test execution invokes `saveIdentity`, `saveLogoBytes`, or
   `deleteLogoFile`;
9. production application exposes `queries.businessLogo` using the exact
   captured shared repository instance;
10. a signed-in `DashboardShell` with valid identity metadata resolves the
    query through `ApplicationScope`, renders exact bytes within the existing
    32-by-80 constraints with `BoxFit.contain`, and makes one read;
11. no logo/empty/missing/read-failure/invalid-image paths render no image and
    expose no new error UI;
12. absent logo metadata does not require `ApplicationScope` in historical
    scope-free shell harnesses;
13. `dashboard_shell.dart` has no `app_repositories.dart`, `AppRepositories`,
    `File`, Drift, database, or Supabase access after migration;
14. every other production `loadLogoBytes` consumer remains unchanged;
15. exactly four concrete typed query slices exist after Phase 108L.

Implementation validation runs in this order:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter test test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
flutter test test\phase68_business_logo_invoice_windows_icon_test.dart test\phase83_shell_navigation_responsive_test.dart test\phase96_in_app_business_identity_app_shell_branding_test.dart
flutter test test\phase108f_first_read_only_ui_query_migration_test.dart test\phase108h_app_shell_runtime_ownership_test.dart test\phase108i_second_read_only_ui_query_migration_test.dart test\phase108k_product_catalog_query_migration_test.dart
flutter analyze
flutter test
git diff --check
```

Before implementation closure, also inventory current logo reads and query
constructors with:

```powershell
rg -n "loadLogoBytes\(" lib --glob '*.dart'
rg -n "AppRepositories\.businessIdentityRepository" lib --glob '*.dart'
rg -n "ApplicationQueries\(" lib test
```

The prior locked evidence (`flutter analyze` pass, 2499 full tests passed, 103
targeted tests passed) is baseline evidence only. This planning session does
not claim those suites were rerun.

## 17. Regression Protection

- Freeze the exact non-empty filename and returned byte identity.
- Freeze zero reads for empty/no-logo states and one read for a rendered logo.
- Freeze handler propagation plus widget catch/hide behavior.
- Freeze current App Bar dimensions, fit, title, loading, null, and image-error
  behavior.
- Prove no repository write method is reachable from the query.
- Prove the root uses the already captured repository; forbid a duplicate
  `LocalBusinessIdentityRepository`.
- Preserve `BusinessIdentityController` identity loading and all settings
  write flows.
- Preserve Phase 108F/I/K query handlers and Phase 108H root ownership.
- Run Phase 68 managed-logo, Phase 83 shell, and Phase 96 branding regressions.
- Compare the pre/post `loadLogoBytes` inventory; only the Dashboard App Bar
  call may move, and total non-dashboard consumers remain unchanged.
- Treat any database, Supabase, generated, dependency, platform, or second
  consumer diff as a scope failure.

## 18. Protected Artifacts

The following blobs were verified at planning entry and must remain unchanged:

| Artifact | Required blob |
|---|---|
| `docs/phase-108k/PHASE-108K-SCOPE-DISCOVERY-AND-GOVERNANCE-RECONCILIATION.md` | `0d7df9c6f0ab547f9e45082a0851cb4ceaa36a9c` |
| `docs/phase-108k/PHASE-108K-PRODUCT-CATALOG-QUERY-PLANNING.md` | `0711297c46f33afeaaf29c48b20e3e372fd8922b` |
| `docs/phase-108l/PHASE-108L-SCOPE-DISCOVERY.md` | `7abf3d70649e8f08a49652186fb26aad84d41324` |

All prior annotated tags and the governance tag remain immutable at the object
IDs recorded in section 2.

## 19. No Database / Supabase Mutation Declaration

```text
DATABASE_MUTATION = NONE
SUPABASE_MUTATION = NONE
SQL_MIGRATION = NONE
SCHEMA_CHANGE = NONE
RLS_CHANGE = NONE
EDGE_FUNCTION_DEPLOYMENT = NONE
REMOTE_DATABASE_COMMAND = NONE
DATA_WRITE = NONE
```

The future implementation is also local managed-file read-only and requires no
database or Supabase work.

## 20. No Remote Mutation Declaration

```text
REMOTE_MUTATION = NONE
PUSH = NOT_PERFORMED
TAG_MUTATION = NONE
REMOTE_BRANCH_MUTATION = NONE
```

Remote access in planning was limited to read-only tag identity verification.
The planning lock tag is intentionally deferred to the separately authorized
`PHASE_108L_PLANNING_REMOTE_LOCK` session.

## 21. Implementation Sequence

This sequence is authorized only for a later implementation session:

1. Re-verify the locked planning commit, repository identity, clean state,
   ancestry, tags, and protected artifacts.
2. Run the existing focused logo/shell/query tests to freeze behavior before
   editing.
3. Add `LocalReadAuthority.managedFile` without changing SQLite defaults or
   existing query results.
4. Add `LoadBusinessLogoQuery` and its read-only handler with the exact frozen
   empty/forward/result/error/metadata semantics.
5. Add only `ApplicationQueries.businessLogo`.
6. Construct the handler in `AppCompositionRoot` from
   `dependencies.repositories.businessIdentityRepository`.
7. Replace only `DashboardShell._AppBarLogo` locator acquisition with query
   consumption through `ApplicationScope`.
8. Add the focused Phase 108L suite and update only the three proven
   current-tree query inventory/constructor guards.
9. Run targeted logo, shell, ownership, and Phase 108F/I/K regressions.
10. Run format verification, full `flutter analyze`, and full `flutter test`.
11. Inspect the complete diff, enforce the production/test touch budgets,
    verify protected blobs and no second logo consumer, and run
    `git diff --check`.
12. Create one local implementation commit only if that later session permits
    it; do not push or tag without separate authorization.

## 22. Acceptance Gates

Phase 108L implementation may pass only if all are true:

```text
[PASS] Canonical scope unchanged.
[PASS] Exactly one immutable logo query and one read-only handler added.
[PASS] Input is only the managed filename; output is only Uint8List?.
[PASS] Metadata is local/managedFile/currentKnownState.
[PASS] Empty filename makes zero repository calls.
[PASS] Non-empty filename is forwarded exactly once.
[PASS] Bytes/null/error semantics are preserved.
[PASS] Exact shared repository identity is proven.
[PASS] Only DashboardShell._AppBarLogo migrates.
[PASS] Dashboard App Bar has no production locator fallback.
[PASS] All other logo consumers remain unchanged.
[PASS] Business/session context behavior remains unchanged.
[PASS] No write method is invoked or exposed.
[PASS] Expected production touch set is respected.
[PASS] Test changes are focused and historically safe.
[PASS] Targeted tests pass.
[PASS] Full flutter analyze passes.
[PASS] Full flutter test passes.
[PASS] Format and git diff checks pass.
[PASS] Protected artifacts and tags remain exact.
[PASS] No database, Supabase, remote, tag, or history mutation occurs.
```

## 23. Rollback / Failure Boundaries

The implementation must stop and report a scoped blocking status if any of the
following becomes necessary or cannot be proven:

- a second logo consumer, dashboard read, or query migration;
- a production locator fallback in `_AppBarLogo`;
- a change to the repository contract, file layout, controller, identity
  metadata, session context, or business context;
- caching, decoding, image processing, UI redesign, or new dependency;
- a database, schema, generated, Supabase, network, write, or deployment change;
- a production file outside the five-path budget;
- weakening historical evidence or broad current-test rebaselining;
- duplicate repository construction or inability to prove exact shared
  identity;
- an observed behavior contradiction that cannot be preserved atomically.

Because the slice is additive and one-seam, rollback is the reversal of the
single later implementation commit: restore the Dashboard locator call, remove
the one query/member/composition entry and managed-file authority, and restore
only the intentional current-tree test inventories. No data rollback, database
rollback, remote force operation, history rewrite, or tag move is part of the
rollback contract.

## 24. Final Frozen Implementation Scope

```text
CREATE_PRODUCTION = lib/application/queries/load_business_logo_query.dart
MODIFY_PRODUCTION = lib/application/queries/application_query.dart
MODIFY_PRODUCTION = lib/application/application_boundary.dart
MODIFY_PRODUCTION = lib/composition/app_composition_root.dart
MODIFY_PRODUCTION = lib/features/dashboard/dashboard_shell.dart
CREATE_TEST = test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
MODIFY_TEST = test/phase108f_first_read_only_ui_query_migration_test.dart
MODIFY_TEST = test/phase108i_second_read_only_ui_query_migration_test.dart
MODIFY_TEST = test/phase108k_product_catalog_query_migration_test.dart
QUERY = LoadBusinessLogoQuery(managedFileName)
RESULT = ApplicationQueryResult<Uint8List?>
APPLICATION_MEMBER = ApplicationQueries.businessLogo
READ_AUTHORITY = LocalReadAuthority.managedFile
REPOSITORY_CALL = BusinessIdentityRepository.loadLogoBytes only
UI_CONSUMER = DashboardShell._AppBarLogo only
BUSINESS_CONTEXT_CHANGE = NONE
SESSION_CONTEXT_CHANGE = NONE
WRITE_CHANGE = NONE
DATABASE_CHANGE = NONE
SUPABASE_CHANGE = NONE
REMOTE_CHANGE = NONE
IMPLEMENTATION = NOT_STARTED
```

Any deviation that broadens this frozen set requires a new governance decision;
it is not implicitly authorized by this plan.
