# Phase 108K — Product Catalog Query Boundary Migration Plan

## A. Planning result

```text
PHASE_108K_PLANNING
IMPLEMENTATION = NOT_STARTED
PLANNING_SCOPE = ONE_LOCAL_READ_ONLY_PRODUCT_CATALOG_UI_QUERY_MIGRATION_FOR_PRODUCTS_SCREEN_THROUGH_APPLICATION_BOUNDARY
```

This artifact is an implementation-grade plan only. It authorizes no Dart,
test, database, dependency, generated-code, Supabase, tag, or remote mutation in
the planning session. Planning closure is recorded only by the planning
session's final forensic report and local document-only commit.

## B. Governing baselines

| Baseline | Exact commit | Relevant lock |
|---|---|---|
| Phase 108J implementation | `951ed1cfe4e673f376dd9e270f2d7076fc8f1750` | annotated tag `phase-108j-implementation-locked` (tag object `4e1c781a86beece985eb8ac3ae796976240c3cdd`) |
| Phase 108K governance reconciliation | `bc1d37f430ae3708fe2cd4e3c93386f8fbecf1af` | no Phase 108K tag exists or is authorized in this session |
| Phase 108K planning parent | `bc1d37f430ae3708fe2cd4e3c93386f8fbecf1af` | the planning commit must be its single direct child |
| Phase 108F implementation precedent | `db84293213d99a79b23bf25b81b565c380aa4655` | `phase-108f-first-read-only-ui-query-migration-verified` |
| Phase 108I planning precedent | `ca533e07dad7d36e2b17d0caa2c1740ee8fa9103` | `phase-108i-planning-baseline-locked` |
| Phase 108I implementation precedent | `6896cbd73b271631cda9b31666ab200a6dcac76a` | `phase-108i-second-read-only-ui-query-migration-locked` |

The locked Phase 108J ancestry remains:

```text
69eebcdac20bba12e9b75abaa99c9a2e02df5483
  -> 2c09062474c3bae590763a70b6e3214457c12725
  -> 6d04a57e188be7cd0bed9a1ae828f1d0d49ad239
  -> 951ed1cfe4e673f376dd9e270f2d7076fc8f1750
  -> bc1d37f430ae3708fe2cd4e3c93386f8fbecf1af
  -> <future Phase 108K implementation, not this planning commit>
```

Phase 108J source, tests, SQL, semantics, commits, and tags are protected.

## C. Frozen canonical scope

```text
ONE_LOCAL_READ_ONLY_PRODUCT_CATALOG_UI_QUERY_MIGRATION_FOR_PRODUCTS_SCREEN_THROUGH_APPLICATION_BOUNDARY
```

The narrow meaning is one existing `ProductsScreen` list request, one typed
request, one read-only handler, one `ApplicationBoundary.queries` exposure, and
one default-screen read-ownership change. Existing product creation, update,
activation/deactivation, their `ProductRepository`, and every other catalog
consumer remain on their present paths. The scope decision is closed and is not
reopened by implementation.

## D. Verified current architecture

### D.1 Current production path

```text
lib/features/products/products_screen.dart
  ProductsScreen / _ProductsScreenState.initState
  -> AppRepositories.productCatalogReadRepository
lib/core/catalog/product_controller.dart
  ProductController(productCatalogReadRepository:, repository:)
  -> ProductController.loadProducts(AppUser)
  -> ProductCatalogReadRepository.listProductCatalog(
       includeInactive: user.permissions.canManageProducts)
lib/core/catalog/drift_product_catalog_read_repository.dart
  DriftProductCatalogReadRepository
  -> FoundationDatabase.products (SQLite)
```

**FACT:** `ProductsScreen` currently constructs its default controller in
`initState` and passes both `AppRepositories.productCatalogReadRepository` and
`AppRepositories.productRepository` (`products_screen.dart:29-44`). Injected
controllers remain supported by `ProductsScreen(controller:)`.

**FACT:** `ProductController.loadProducts` is the only controller member that
calls the dedicated catalog read port (`product_controller.dart:25-35`). The
write methods `createProduct`, `updateProduct`, and `setProductActive` call the
separate `_repository` and then call `loadProducts(user)`.

**FACT:** `ApplicationRepositoryDependencies.productCatalogReadRepository`
already captures the exact shared instance. `LegacyApplicationDependencyBridge`
assigns it from `AppRepositories.productCatalogReadRepository`, and
`AppRepositories.initializeProduction` constructs that production instance once
as `DriftProductCatalogReadRepository(database)`.

**FACT:** `ApplicationQueries` currently owns exactly
`LoadAuditLogsQueryHandler auditLogs` and
`LoadDocumentHistoryQueryHandler documentHistory`. `ApplicationScope.of(context)`
is the established UI resolver.

### D.2 Persistence and result facts

`ProductCatalogReadRepository` returns a complete snapshot of
`ProductCatalogReadModel` with these fields, unchanged by Phase 108K:

```text
id
name
code
unit
isActive
referenceCostPricePiastersPerKg
defaultSalePricePiastersPerKg
minimumSalePricePiastersPerKg
notes
createdAt
updatedAt
```

`DriftProductCatalogReadRepository.listProductCatalog` selects those exact
columns. It applies `products.isActive.equals(true)` only when
`includeInactive == false`, and orders by:

```text
OrderingTerm.asc(products.createdAt)
OrderingTerm.asc(products.id)
```

It maps rows without trimming, merging, caching, sorting in Dart, or copying
through the legacy write repository.

## E. Frozen target architecture

### E.1 Planned state

```text
ProductsScreen.didChangeDependencies (default-controller path only)
  -> ApplicationScope.of(context).queries.productCatalog
  -> ProductController(queryHandler:, repository: existing write repository)
  -> ProductController.loadProducts(AppUser)
  -> LoadProductCatalogQueryHandler.execute(
       LoadProductCatalogQuery(
         includeInactive: user.permissions.canManageProducts))
  -> ProductCatalogReadRepository.listProductCatalog(includeInactive: ...)
  -> existing shared DriftProductCatalogReadRepository
  -> current local SQLite Products state
```

The result is wrapped as
`ApplicationQueryResult<List<ProductCatalogReadModel>>` with
`LocalQueryResultMetadata` (`local`, `sqlite`, `currentKnownState`).

### E.2 Current versus planned ownership

| Concern | Current | Planned Phase 108K |
|---|---|---|
| UI list-read dependency | direct global catalog-read locator | `ApplicationScope.of(context).queries.productCatalog` |
| Controller list implementation | calls read port directly | executes typed query handler |
| Read repository instance | `AppRepositories.productCatalogReadRepository` | the same instance captured in `ApplicationDependencies` |
| Product writes | `AppRepositories.productRepository` / `ProductRepository` | unchanged |
| Authority | local Drift SQLite | unchanged |
| Session/business context | no handler dependency | unchanged; none added |

### E.3 Deferred state

Remote catalogs, tenant/business filtering, RLS, synchronization, cache
freshness, provisional overlays, outbox/inbox, and migration of other product
consumers are future governance questions, not Phase 108K target architecture.

### E.4 Phase 108F / 108I precedent comparison

| Concern | Phase 108F — audit logs | Phase 108I — document history | Planned Phase 108K — product catalog |
|---|---|---|---|
| Typed request | `LoadAuditLogsQuery()` with no fields | `LoadDocumentHistoryQuery(filter:)` | `LoadProductCatalogQuery(includeInactive:)` |
| Handler dependency | existing `AuditLogReadRepository` | existing `DocumentHistoryRepository` | existing `ProductCatalogReadRepository` |
| Result ownership | unchanged repository list in `ApplicationQueryResult` | unchanged repository list in `ApplicationQueryResult` | unchanged repository list in `ApplicationQueryResult` |
| Metadata | local/SQLite/current-known-state | local/SQLite/current-known-state | reuse exactly |
| Context dependency | none in handler | none in handler | none; do not fabricate business/session context |
| Boundary member | `queries.auditLogs` | `queries.documentHistory` | `queries.productCatalog` |
| Production wiring | shared dependency captured by bridge, handler built in root | same | reuse same construction pattern and already captured catalog dependency |
| UI/controller parity | repository-compatible controller; default screen resolves scope | XOR repository/handler controller; default screen resolves scope | reuse XOR compatibility and scope resolution |
| Domain-specific difference | read-only screen/controller | read-only screen/controller with filter and owner-audit presentation | mixed controller: only list read migrates; write repository and three mutations remain legacy/local |

The mixed read/write controller is the material difference. It is why Phase 108K
must not mechanically remove every `AppRepositories` reference from
`ProductsScreen`: the catalog-read locator goes away, while the unchanged
product-write locator remains.

## F. Frozen query contract

### `LoadProductCatalogQuery`

**PLANNED CHANGE:** add
`lib/application/queries/load_product_catalog_query.dart` with:

```dart
final class LoadProductCatalogQuery {
  const LoadProductCatalogQuery({required this.includeInactive});

  final bool includeInactive;
}
```

The single field is caller-controlled and must be forwarded unchanged. `true`
permits active and inactive rows; `false` returns active rows only. The query has
no default, pagination, search, category, warehouse, stock, remote, AppUser,
SessionContext, or BusinessContext field.

The result type is exactly:

```dart
ApplicationQueryResult<List<ProductCatalogReadModel>>
```

The handler must return the repository's list as `value` without sorting,
filtering, cloning, mapping, or changing object/list identity. Metadata is
`const LocalQueryResultMetadata()`.

## G. Frozen query-handler contract

### `LoadProductCatalogQueryHandler`

**PLANNED CHANGE:** in the same query file, implement:

```dart
final class LoadProductCatalogQueryHandler
    implements ApplicationQueryHandler<LoadProductCatalogQuery,
        List<ProductCatalogReadModel>>
```

Constructor dependency:

```dart
const LoadProductCatalogQueryHandler({
  required ProductCatalogReadRepository repository,
}) : _repository = repository;
```

`execute` makes exactly one awaited call:

```dart
_repository.listProductCatalog(
  includeInactive: query.includeInactive,
)
```

It propagates the exact repository exception/future failure. It performs no
permission decision: permission shaping remains with `ProductController` and
the authenticated `AppUser`. It imports no locator, Drift, database, Supabase,
write repository, product mutation, session provider, or business provider.

## H. ApplicationBoundary change

**PLANNED CHANGE:** `lib/application/application_boundary.dart` imports the new
query and adds one required constructor member to `ApplicationQueries`:

```dart
required this.productCatalog,
...
final LoadProductCatalogQueryHandler productCatalog;
```

`ApplicationBoundary`, `ApplicationCommands`, `ApplicationScope`, and the
generic `ApplicationQueryHandler`/metadata contracts are not redesigned.
`productCatalog` follows the existing domain-noun member convention
(`auditLogs`, `documentHistory`), while `LoadProductCatalogQuery[Handler]`
follows the existing `Load...` type convention.

## I. Production composition

The following ownership is frozen:

1. `AppRepositories.initializeProduction` remains the sole constructor/owner of
   the production `DriftProductCatalogReadRepository` instance.
2. `LegacyApplicationDependencyBridge.captureSharedInstances` continues to
   capture that exact instance as
   `dependencies.repositories.productCatalogReadRepository`; neither file needs
   a Phase 108K production-dependency change.
3. `AppCompositionRoot.initializeProduction` constructs
   `LoadProductCatalogQueryHandler(repository:
   dependencies.repositories.productCatalogReadRepository)` next to the audit
   and document-history handlers.
4. The root passes the handler as `ApplicationQueries.productCatalog`.
5. The default `ProductsScreen` resolves the handler through
   `ApplicationScope.of(context).queries.productCatalog`.

Production tests must use `same(...)` to prove
`application.dependencies.repositories.productCatalogReadRepository` is
`AppRepositories.productCatalogReadRepository`. A second adapter or repository
instance is a stop condition, not an acceptable convenience.

## J. ProductController migration

The smallest compatibility construction follows the Phase 108I controller
pattern while retaining the required write repository:

```dart
ProductController({
  ProductCatalogReadRepository? productCatalogReadRepository,
  LoadProductCatalogQueryHandler? queryHandler,
  required ProductRepository repository,
}) : assert(
       (productCatalogReadRepository == null) != (queryHandler == null),
       'Exactly one product catalog repository or query handler is required.',
     ),
     _queryHandler = queryHandler ??
       LoadProductCatalogQueryHandler(
         repository: productCatalogReadRepository!,
       ),
     _repository = repository;
```

**PLANNED CHANGE:** replace only the private read field with
`LoadProductCatalogQueryHandler _queryHandler`. `loadProducts` keeps its existing
loading/error notification sequence, constructs
`LoadProductCatalogQuery(includeInactive:
user.permissions.canManageProducts)`, awaits `_queryHandler.execute`, and assigns
`_products = result.value`.

**UNCHANGED:** `ProductRepository _repository`, `products`, `errorMessage`,
`isLoading`, `_canManageProducts`, `_messageForError`, and the bodies and return
contracts of `createProduct`, `updateProduct`, and `setProductActive`, except
that their existing calls to `loadProducts(user)` now naturally use the typed
query.

Repository injection remains available only as a test/legacy compatibility
adapter to the typed handler. Supplying neither or both read dependencies must
assert. No public mutation signature changes.

## K. ProductsScreen migration

Because `ApplicationScope.of(context)` depends on inherited widget context, the
default controller cannot be created from it in `initState`. Follow the proven
audit/document-history lifecycle:

1. `initState` records `_ownsController = widget.controller == null` and assigns
   an injected controller immediately when present.
2. Add `_initialized` and perform one-time default construction in
   `didChangeDependencies`.
3. For the owned controller, pass
   `queryHandler: ApplicationScope.of(context).queries.productCatalog` and keep
   `repository: AppRepositories.productRepository` as the unchanged write
   dependency.
4. Schedule the existing authenticated-user initial load once, preserving the
   existing user-null gate and one-load behavior; do not add new auth or refresh
   semantics as part of the ownership move.
5. Dispose only an owned controller. An injected controller remains
   scope-independent and is not disposed by the screen.

The screen may continue importing `app_repositories.dart` solely for
`productRepository`; Phase 108K must remove only direct acquisition of
`AppRepositories.productCatalogReadRepository`. Moving the write repository
into `ApplicationBoundary` would be a product-command migration and is
forbidden.

## L. Permission, identity, and context semantics

**FACT:** `ProductsScreen.build` derives
`canManage = user?.permissions.canManageProducts ?? false`; unauthenticated
users see `يجب تسجيل الدخول لعرض الأصناف.` and no load is initiated when the
post-frame `AuthScope` user is null.

**FACT:** `AppUser.permissions` is `Permissions.forRole(role)`. `owner` has
`canManageProducts == true`; `employee` has it `false`.

**FACT:** `ProductController.loadProducts` does not currently check
`AppUser.canProceed`, active status, ID validity, SessionContext, or
BusinessContext. It forwards only `user.permissions.canManageProducts`.

**PARITY FREEZE:** an owner request sends `includeInactive: true`; an employee
request sends `false`. The query handler performs no additional authorization.
Write authorization continues through `_canManageProducts` and the same Arabic
permission error. No new permission key, fake membership, tenant/shop/warehouse
filter, session provider, business provider, RLS, or remote authorization is
allowed.

## M. Ordering and result parity

The handler and controller must preserve:

- repository list membership and object identity;
- `createdAt ASC, id ASC` ordering from the Drift adapter;
- active-only filtering when `includeInactive` is false;
- all active and inactive rows when it is true;
- null versus empty/verbatim values for `code`, `notes`, and price fields;
- a successful empty list as a successful result, not an error;
- `ProductController.products` continuing to expose an unmodifiable list view
  in the same order.

Neither handler nor controller may add a sort, map, copy, cache, merge, search,
or pagination step. `ProductCatalogReadModel`, its repository, and the Drift
adapter are expected to remain byte-for-byte unchanged.

## N. Retry, error, loading, and screen-state parity

Current behavior is frozen even where it is minimal:

- `loadProducts` sets `_isLoading = true`, clears `_errorMessage`, and notifies
  before awaiting the read;
- success assigns the list, sets loading false, and notifies again;
- a read exception propagates unchanged; `loadProducts` has no catch/finally,
  so loading remains true, error remains null, retained products remain
  retained, and there is no success notification;
- `ProductsScreen` shows the loading state while `isLoading` is true;
- with no loading and no products it shows the existing Arabic empty state;
- if `errorMessage != null` and products are empty, the existing
  `GhalalErrorState` retry calls `loadProducts(user)`; if products remain, the
  message is shown above them;
- Phase 108K does not invent a controller load-error mapping, retry policy,
  timeout, or stale-result policy.

Later tests must explicitly characterize the exception identity and the current
loading/error/retained-result state so the architectural migration cannot
silently improve or degrade it.

## O. Post-mutation refresh parity

Three existing in-scope refresh edges must continue:

```text
createProduct -> ProductRepository.createProduct -> loadProducts(user)
updateProduct -> ProductRepository.updateProduct -> loadProducts(user)
setProductActive -> ProductRepository.setProductActive -> loadProducts(user)
```

The mutations themselves remain outside the typed query and outside
`ApplicationBoundary.commands`. On successful writes, each refresh executes the
same handler once with the same permission-shaped `includeInactive`. Existing
write failure mapping and booleans remain unchanged. If a post-write refresh
throws, the existing surrounding mutation `try/catch` continues to map the
error and return false; Phase 108K must characterize, not redesign, that state.

The screen's add/edit dialog and activation toggle continue to call the same
controller write methods. No second explicit screen refresh is added.

## P. Test strategy for the implementation session

Create one focused suite:

```text
test/phase108k_product_catalog_query_migration_test.dart
```

It must cover at least:

1. handler calls the injected read repository exactly once;
2. `includeInactive` false and true are forwarded unchanged;
3. returned list and element identities, membership, field values, and order are
   preserved;
4. empty success is preserved and metadata is local/SQLite/current-known-state;
5. exact repository exception propagates;
6. handler source contains no locator, Drift, database, Supabase, write API, or
   mutation token;
7. controller accepts exactly one repository-or-handler read dependency while
   always retaining the separate required `ProductRepository`;
8. owner/employee permission parity and the exact loading notifications are
   preserved through the handler path;
9. controller failure identity and current loading/error/retained-list behavior
   are preserved;
10. create, update, and activation/deactivation remain on `ProductRepository`,
    never call its legacy list method, and refresh once through the handler;
11. production boundary exposes `queries.productCatalog` and the handler uses
    the same shared dependency instance;
12. a default `ProductsScreen` under `ApplicationScope` loads through the
    handler, while `ProductsScreen(controller:)` works without
    `ApplicationScope`;
13. default screen source has no
    `AppRepositories.productCatalogReadRepository`, but is allowed exactly the
    unchanged `AppRepositories.productRepository` write dependency;
14. default owner/employee UI, empty state, and unauthenticated behavior remain
    unchanged;
15. `ApplicationQueries` exposes audit logs, document history, and product
    catalog—exactly three concrete typed query slices after Phase 108K;
16. no product write method or other product consumer migrates.

Existing tests that inject `ProductCatalogReadRepository` must remain viable via
the compatibility constructor. Update current-architecture assertions only when
Phase 108K intentionally changes their observed seam; do not rewrite assertions
that inspect historical commits.

## Q. Regression strategy

Run in this order after implementation:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test\phase108k_product_catalog_query_migration_test.dart
flutter test test\phase106x_product_controller_product_catalog_migration_freeze_test.dart test\product_catalog_test.dart test\phase11_ux_test.dart
flutter test test\phase105b_product_catalog_read_contract_test.dart test\phase105c_local_drift_product_catalog_read_adapter_test.dart test\phase105d_product_catalog_application_read_boundary_migration_test.dart test\phase105e_genuine_runtime_product_catalog_read_integration_test.dart test\phase105f_product_catalog_read_boundary_pilot_acceptance_freeze_test.dart
flutter test test\phase108e_application_boundary_composition_root_test.dart test\phase108f_first_read_only_ui_query_migration_test.dart test\phase108g_session_business_context_boundary_test.dart test\phase108h_app_shell_runtime_ownership_test.dart test\phase108i_second_read_only_ui_query_migration_test.dart
flutter test test\phase108j_expense_projection_test.dart test\phase108j_post_expense_command_test.dart
flutter test
git diff --check
```

Before the full run, inventory Phase 106 current-working-tree source guards with:

```powershell
rg -n -g 'phase106*.dart' "product_controller\.dart|products_screen\.dart|listProductCatalog\(|AppRepositories\.productCatalogReadRepository" test
```

Several Phase 106 suites intentionally count current catalog call sites. Moving
one call from `ProductController` to the typed handler should keep one logical
repository read, but changes its source path. Only assertions proven to inspect
the current tree may be updated; SHA-based historical evidence must remain
unchanged. Any broader failure is investigated rather than mass-rebaselined.

If a named Phase 108J filename differs at implementation time, use
`rg --files test | rg phase108j` to select the existing focused Phase 108J suites;
no Phase 108J file is modified.

## R. File-level change budget

| Class | Likely path(s) | Authorized later implementation purpose |
|---|---|---|
| CREATE | `lib/application/queries/load_product_catalog_query.dart` | typed request and read-only handler only |
| CREATE | `test/phase108k_product_catalog_query_migration_test.dart` | focused parity, ownership, composition, and no-write guards |
| MODIFY | `lib/application/application_boundary.dart` | import handler; add `ApplicationQueries.productCatalog` |
| MODIFY | `lib/composition/app_composition_root.dart` | construct handler from `dependencies.repositories.productCatalogReadRepository` |
| MODIFY | `lib/core/catalog/product_controller.dart` | compatibility read injection and `loadProducts` typed-query execution only |
| MODIFY | `lib/features/products/products_screen.dart` | default read ownership through `ApplicationScope`; retain write locator |
| TEST MODIFY | `test/phase108f_first_read_only_ui_query_migration_test.dart` | update current concrete-query inventory from two to three without weakening 108F assertions |
| TEST MODIFY | `test/phase108i_second_read_only_ui_query_migration_test.dart` | update current query/scope/locator metrics and inventory for the intentional one-screen migration |
| TEST MODIFY | `test/phase106x_product_controller_product_catalog_migration_freeze_test.dart` | preserve Phase 106X behavior while recognizing the new typed application seam |
| TEST MODIFY — only if a focused/full run proves a current-tree guard is affected | `test/phase106p_purchase_controller_product_catalog_read_migration_test.dart`, `test/phase106r_inventory_controller_product_catalog_read_migration_guard_test.dart`, `test/phase106s_inventory_controller_product_catalog_runtime_integration_test.dart`, `test/phase106t_next_product_read_migration_target_freeze_test.dart`, `test/phase106u_sale_controller_product_catalog_read_migration_test.dart`, `test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart`, `test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart`, `test/phase106w_next_product_read_migration_target_freeze_test.dart`, `test/phase106y_next_product_read_migration_target_freeze_test.dart`, and Phase 106 re-audit inventories discovered by the command in Q | change only present-tree call-site/path expectations; never alter historical commit expectations or unrelated consumer behavior |
| CONFIRM UNCHANGED | `lib/application/application_dependencies.dart`, `lib/composition/legacy_application_dependency_bridge.dart`, `lib/composition/application_scope.dart`, `lib/core/catalog/product_catalog_read_repository.dart`, `lib/core/catalog/drift_product_catalog_read_repository.dart`, `lib/app/app_repositories.dart` | existing shared dependency and persistence contracts already suffice |
| MUST NOT TOUCH | `lib/core/persistence/**`, generated Drift files, `supabase/**`, SQL/migrations, `pubspec.yaml`, `pubspec.lock`, Phase 108J source/tests/docs, product write repository/adapter, unrelated screens/controllers | protected/out of scope |

The implementation diff should start with five production source paths (one
create and four modify), plus one focused test create and narrowly proven test
updates. Any new production path beyond those five listed source paths is a
scope-review gate.

## S. Explicit non-goals

- no product create/update/activation command migration;
- no change to `ProductRepository`, `DriftProductRepository`, validation, or
  mutation semantics;
- no other product consumer, screen, dashboard, sale, purchase, inventory,
  report, backup, supplier, or customer migration;
- no removal of `ProductRepository.listProducts` or the compatibility adapter;
- no product/read-model/repository/Drift redesign;
- no pagination, search, category, warehouse, stock balance, or new field;
- no schema/version/generated Drift/dependency/platform/navigation/app-shell
  change;
- no Supabase products table, adapter, RPC, Edge Function, RLS, or deployment;
- no BusinessContext, tenant membership, SessionContext, or server authority;
- no hybrid catalog, sync, outbox, inbox, provisional overlay, or generic retry
  infrastructure;
- no repository-wide service-locator or `AppRepositories` cleanup;
- no second financial command and no Phase 108J modification;
- no remote push or tag work in the implementation-local session unless a later
  prompt explicitly authorizes a separate lock session.

## T. Risk register

| Risk | Mitigation / implementation gate |
|---|---|
| Accidental product write migration | Keep `ProductRepository _repository` and all three write methods unchanged; static guards forbid write tokens in the handler. |
| Duplicate read repository instance | Construct only from `dependencies.repositories.productCatalogReadRepository`; production `same(...)` assertion is mandatory. |
| Permission drift | Controller remains sole shaper of `includeInactive`; test owner `true`, employee `false`, and unchanged screen actions. |
| `includeInactive` drift | Required query field, no default; spy proves exact forwarding once. |
| Ordering/result drift | Same-list/same-element assertions plus Drift regression for `createdAt ASC, id ASC`; forbid handler/controller sorting/mapping. |
| Refresh regression after mutation | Spy write and handler dependencies independently; assert one write plus one typed refresh for create/update/toggle. |
| Controller compatibility break | XOR repository-or-handler constructor; existing injected-controller/product tests must pass. |
| Inherited-scope lifecycle error | Resolve default handler once in `didChangeDependencies`; injected controller path must not resolve scope. |
| Service-locator cleanup creep | Permit the screen's existing write locator; remove only the catalog-read locator reference. |
| BusinessContext fabrication | Query contract contains only `includeInactive`; any required business/session context blocks the phase. |
| Supabase/cloud scope creep | Handler imports only application-query contract and core read port; no network or remote test fixture. |
| Repository-wide consumer migration | Static call-site inventory must show only the selected ProductsScreen/controller ownership move. |
| Historical test rebaselining | Distinguish working-tree assertions from fixed-SHA assertions; never change historical evidence merely to make tests pass. |
| Current odd error semantics accidentally changed | Explicit failure tests freeze exception identity, loading true, null load error, and retained list. |
| Phase 108J contamination | Diff path allowlist and dedicated Phase 108J regression; any required 108J edit is a stop condition. |

## U. Deterministic implementation sequence

1. Re-verify root, branch, remote, clean state, implementation entry HEAD, and
   locked Phase 108J ancestry.
2. Run/inspect the focused current product/controller tests to characterize
   permission, identity, state, errors, and mutation refreshes before editing.
3. Add `LoadProductCatalogQuery` and `LoadProductCatalogQueryHandler` with the
   frozen one-field/read-only contract.
4. Add `ApplicationQueries.productCatalog`.
5. Compose the handler in `AppCompositionRoot` from the already captured shared
   repository; do not edit the bridge or dependency bundle unless contrary
   evidence triggers a stop.
6. Adapt `ProductController` to exactly-one repository-or-handler read
   construction and route only `loadProducts` through the typed query.
7. Move only default `ProductsScreen` read ownership to `ApplicationScope` in
   `didChangeDependencies`; retain injected-controller and write-repository
   behavior.
8. Add the focused Phase 108K suite, then update the known 108F/108I/106X
   current-architecture guards.
9. Run focused regressions; update any additional Phase 106 test only after
   proving it asserts the intentionally changed current-tree path.
10. Run analyzer, formatter verification, Phase 105/106/108 regressions, and the
    full test suite.
11. Inspect name-status/stat/diff, enforce the file budget, run diff/secret
    checks, and confirm no schema, dependency, generated, cloud, unrelated
    consumer, or Phase 108J change.
12. Create one local implementation commit only under a separately authorized
    implementation prompt; do not push or tag in local closure.

## V. Implementation stop conditions

Stop fail-closed if any of these becomes necessary or cannot be proven:

- a schema, Drift generation, dependency, Supabase, RPC, RLS, or deployment
  change;
- BusinessContext, fake tenant/shop/warehouse membership, or a new session
  dependency;
- replacement/redesign of `ProductCatalogReadRepository` or inability to
  preserve its exact filtering, result, and ordering semantics;
- any Phase 108J modification;
- simultaneous migration of all product consumers or any product write path;
- permission behavior cannot be proven from `AppUser`/`Permissions` and tests;
- ordering cannot remain `createdAt ASC, id ASC`;
- production composition needs a second repository instance or boundary/root
  redesign beyond adding the one query member;
- the default screen cannot retain its existing write dependency without a
  product-command migration;
- existing tests reveal a behavioral contradiction rather than a current-path
  architecture assertion;
- the diff contains any path outside the reviewed file budget or unrelated user
  work.

The correct result is a precise
`BLOCKED_PHASE_108K_IMPLEMENTATION_<REASON>`, not scope expansion.

## W. Local closure contract for the later implementation session

`PASS_PHASE_108K_IMPLEMENTATION_LOCAL_READY` may be declared only when:

```text
CANONICAL_SCOPE = UNCHANGED
ONE_TYPED_QUERY = IMPLEMENTED
ONE_READ_ONLY_HANDLER = IMPLEMENTED
APPLICATION_QUERIES_PRODUCT_CATALOG = COMPOSED
SHARED_REPOSITORY_IDENTITY = PROVEN
PRODUCT_CONTROLLER_LIST_READ = MIGRATED
PRODUCTS_SCREEN_DEFAULT_READ_OWNERSHIP = MIGRATED
PRODUCT_WRITE_PATHS = UNCHANGED
OTHER_PRODUCT_CONSUMERS = UNCHANGED
PERMISSION_INCLUDEINACTIVE_ORDER_RESULT_STATE_REFRESH_PARITY = PROVEN
LOCAL_SQLITE_OFFLINE_AUTHORITY = UNCHANGED
SCHEMA_SUPABASE_DEPENDENCIES_GENERATED_FILES_PHASE_108J = UNCHANGED
FOCUSED_TESTS = PASS
REGRESSION_TESTS = PASS
FLUTTER_TEST = PASS
FLUTTER_ANALYZE = PASS
DART_FORMAT_VERIFICATION = PASS
DIFF_AND_SECRET_CHECKS = PASS
ONE_LOCAL_IMPLEMENTATION_COMMIT = CREATED
WORKTREE_INDEX_UNTRACKED_STASH = CLEAN_OR_EXACTLY_PRESERVED_ENTRY_STATE
REMOTE_PUSH = NOT_PERFORMED
TAG_MUTATION = NOT_PERFORMED
```

This planning artifact does not claim any of those implementation conditions.

## Evidence index

The plan's concrete decisions derive from these inspected sources and tests:

- `lib/application/application_boundary.dart` — `ApplicationBoundary`,
  `ApplicationQueries`;
- `lib/application/application_dependencies.dart` — existing catalog read
  dependency;
- `lib/application/queries/application_query.dart` — generic result/metadata;
- `lib/application/queries/load_audit_logs_query.dart` and
  `load_document_history_query.dart` — Phase 108F/I naming and delegation;
- `lib/composition/app_composition_root.dart`,
  `legacy_application_dependency_bridge.dart`, and `application_scope.dart` —
  construction, shared identity, and UI resolution;
- `lib/app/app_repositories.dart` — sole production Drift catalog instance and
  unchanged product write repository;
- `lib/core/catalog/product_controller.dart`,
  `product_catalog_read_repository.dart`, and
  `drift_product_catalog_read_repository.dart` — controller seam, port/model,
  filtering, mapping, and ordering;
- `lib/features/products/products_screen.dart` — default/injected controller,
  auth, loading/error/empty/retry, permissions, and mutation UI;
- `lib/core/auth/app_user.dart` and `permissions.dart` — current identity and
  `canManageProducts` behavior;
- `test/phase105b_product_catalog_read_contract_test.dart` through
  `test/phase105f_product_catalog_read_boundary_pilot_acceptance_freeze_test.dart`;
- `test/phase106x_product_controller_product_catalog_migration_freeze_test.dart`,
  `test/product_catalog_test.dart`, and `test/phase11_ux_test.dart`;
- `test/phase108f_first_read_only_ui_query_migration_test.dart` and
  `test/phase108i_second_read_only_ui_query_migration_test.dart`;
- `docs/phase-108f/PHASE-108F-FIRST-READ-ONLY-UI-QUERY-MIGRATION.md`,
  `docs/phase-108i/PHASE-108I-SECOND-READ-ONLY-UI-QUERY-MIGRATION-PLAN.md`, and
  the complete Phase 108K governance reconciliation artifact.
