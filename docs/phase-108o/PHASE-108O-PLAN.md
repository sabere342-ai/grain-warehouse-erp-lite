# Phase 108O — Planning

## 1. Status

```text
SESSION = PHASE_108O_PLANNING
MODE = DOCUMENTATION_ONLY

PHASE_108O_SCOPE_DISCOVERY = COMPLETE
PHASE_108O_GOVERNANCE_RECONCILIATION_LOCAL_CLOSURE = COMPLETE
PHASE_108O_GOVERNANCE_REMOTE_LOCK = COMPLETE
PHASE_108O_PLANNING_LOCAL_CLOSURE = IN_PROGRESS
PHASE_108O_PLANNING_REMOTE_LOCK = NOT_STARTED
PHASE_108O_IMPLEMENTATION = NOT_STARTED
```

This plan is repository-grounded and implementation-ready. It authorizes no
production or test mutation in the planning session. A later implementation
session must start from a separately verified and remotely locked planning
baseline.

## 2. Governing Baseline

Repository identity and the entry state were verified before this artifact was
created:

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git

ENTRY_HEAD = e248e4beb711950cb1e179a5986347d3db7d4bab
ENTRY_REMOTE_HEAD = e248e4beb711950cb1e179a5986347d3db7d4bab
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0
ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
RECOVERY_CLASSIFICATION = CASE_A_FRESH_PLANNING
```

The Phase 108O governance lock is an annotated tag. Its local and remote tag
objects and peeled commits match:

```text
PHASE_108O_GOVERNANCE_TAG = phase-108o-governance-reconciliation-locked
PHASE_108O_GOVERNANCE_TAG_OBJECT = f4e8026cf51dbdc20ac65ff80535f9c6dd684b9e
PHASE_108O_GOVERNANCE_COMMIT = e248e4beb711950cb1e179a5986347d3db7d4bab
```

The governing Phase 108N locks are also annotated local/remote matches:

| Lock | Tag | Tag object | Peeled commit |
|---|---|---|---|
| Governance | `phase-108n-governance-reconciliation-locked` | `c02f308c660b352a53b13118e96ce42dff733655` | `f1f7cb8abd21323f1172074d6088caa905732070` |
| Planning | `phase-108n-planning-baseline-locked` | `64522963ad1ac69d5da4fa1efe245eb54f180009` | `cdef1249c9b50181b87bb01412e793528b6819f2` |
| Implementation | `phase-108n-implementation-locked` | `8b5c467baa2be473cb4a7ee74396cd8eba739293` | `e8e27d4ef4ab960e6bdb53bd19f1e27907587d6e` |

All required ancestry checks passed for:

```text
232adb4d29104f54e873a743b023d87f5a49ca29
→ f1f7cb8abd21323f1172074d6088caa905732070
→ cdef1249c9b50181b87bb01412e793528b6819f2
→ e8e27d4ef4ab960e6bdb53bd19f1e27907587d6e
→ e248e4beb711950cb1e179a5986347d3db7d4bab
```

The authoritative Phase 108O governance artifact is
`docs/phase-108o/PHASE-108O-GOVERNANCE-RECONCILIATION.md`. It was read in full
before this plan was written.

## 3. Canonical Scope

```text
CANONICAL_SCOPE =
ONE_LOCAL_READ_ONLY_PRINTABLE_DOCUMENT_SCAFFOLD_LOGO_UI_QUERY_MIGRATION_THROUGH_EXISTING_APPLICATION_BOUNDARY
```

Literal implementation meaning: migrate the single logo-byte read inside the
shared printable-document UI scaffold from the legacy `AppRepositories`
locator to the already composed `ApplicationQueries.businessLogo` query. The
work is architectural migration only. It must preserve the managed local file,
returned bytes/null, asynchronous rendering, silent fallbacks, layout, and all
print/export behavior.

The canonical unit is the shared scaffold query seam. Five document previews
use that scaffold, but Phase 108O does not separately migrate five screens or
any PDF/export path.

## 4. Historical Scope Disposition

```text
HISTORICAL_108O_DISPOSITION = SUPERSEDED
SETTINGS_LOGO_SCOPE = FUNCTIONALLY_COMPLETED_UNDER_PHASE_108N
INVOICE_CONTRACT_INTENT = DEFERRED_AS_UNNUMBERED_FUTURE_WORK
OLD_108O_SCOPE_REUSE = FORBIDDEN
```

The divergent historical Settings-logo lineage and the Phase 108A invoice
roadmap assignment are forensic evidence only. No historical Phase 108O
branch, commit, plan, test, or implementation may be merged, cherry-picked,
rebased, copied as authority, or otherwise revived. The current locked branch,
governance artifact, source, and tests govern this plan.

## 5. Repository Evidence

The following current files and symbols prove the selected seam and the
available boundary:

| Evidence | Current fact |
|---|---|
| `lib/features/prints/printable_document_scaffold.dart` | `PrintableDocumentScaffold` owns the shared preview shell; `_PrintableLogo._loadBytes()` contains the one direct locator read. |
| `lib/features/prints/printable_sales_invoice_view.dart` | Uses the shared scaffold. |
| `lib/features/prints/printable_purchase_invoice_view.dart` | Uses the shared scaffold. |
| `lib/features/prints/printable_customer_statement_view.dart` | Uses the shared scaffold. |
| `lib/features/prints/printable_supplier_statement_view.dart` | Uses the shared scaffold. |
| `lib/features/prints/printable_daily_report_view.dart` | Uses the shared scaffold. |
| `lib/application/queries/load_business_logo_query.dart` | Defines the reusable `LoadBusinessLogoQuery` and `LoadBusinessLogoQueryHandler`. |
| `lib/application/application_boundary.dart` | Exposes the existing handler as `ApplicationQueries.businessLogo`. |
| `lib/composition/application_scope.dart` | Provides the existing presentation lookup `ApplicationScope.of(context)`. |
| `lib/composition/app_composition_root.dart` | Composes the handler from the captured `businessIdentityRepository`. |
| `lib/application/application_dependencies.dart` | Holds the captured `BusinessIdentityRepository` in application repository dependencies. |
| `lib/composition/legacy_application_dependency_bridge.dart` | Captures the exact shared production repository instance. |
| `lib/core/business_identity/business_identity_repository.dart` | Defines the port and its local managed-file adapter. |
| `lib/main.dart` | Places `ApplicationScope` above the production application/presentation tree. |
| `lib/features/settings/settings_screen.dart` | Phase 108N precedent: `_LogoPreview` already uses the same query and preserves catch-to-null behavior. |
| `lib/shared/widgets/business_identity_header.dart` | Phase 108M precedent: another reusable logo renderer uses the same query. |

Current live architecture inventory is:

```text
FEATURE_SHARED_APPREPOSITORIES_FILES = 37
FEATURE_SHARED_APPREPOSITORIES_REFERENCES = 143
FEATURE_SHARED_APPLICATION_SCOPE_CONSUMERS = 7
ALL_LIB_APPREPOSITORIES_REFERENCES = 159
```

The selected scaffold contains one `AppRepositories.` reference and no other
locator use. The deterministic post-migration inventory is therefore:

```text
EXPECTED_FEATURE_SHARED_APPREPOSITORIES_FILES = 36
EXPECTED_FEATURE_SHARED_APPREPOSITORIES_REFERENCES = 142
EXPECTED_FEATURE_SHARED_APPLICATION_SCOPE_CONSUMERS = 8
EXPECTED_ALL_LIB_APPREPOSITORIES_REFERENCES = 158
```

## 6. Current Printable-Document Logo Read Path

```text
PRINTABLE_DOCUMENT_SCAFFOLD =
PrintableDocumentScaffold / _PrintableLogo

CURRENT_CONSUMER_FILE =
lib/features/prints/printable_document_scaffold.dart

CURRENT_SYMBOL = _PrintableLogo._loadBytes

CURRENT_DIRECT_DEPENDENCY =
AppRepositories.businessIdentityRepository

CURRENT_SOURCE =
BusinessIdentityRepository.loadLogoBytes(managedFileName)
implemented by LocalBusinessIdentityRepository as a managed local file read

CURRENT_RETURN_TYPE = Future<Uint8List?>

CURRENT_NULL/ABSENT_BEHAVIOR =
empty filename returns null before storage; missing file returns null; null
renders SizedBox.shrink

CURRENT_ERROR_BEHAVIOR =
the consumer catches every thrown read failure and returns null

CURRENT_FALLBACK_BEHAVIOR =
loading/null are silent; decode errors use Image.memory.errorBuilder to render
SizedBox.shrink; no placeholder, spinner, message, or default image is shown
```

Complete current path:

```text
PrintableDocumentScaffold.build
→ BusinessIdentityScope.maybeOf(context)?.identity.logo
→ valid LogoMetadata.managedFileName
→ _PrintableLogo._loadBytes()
→ AppRepositories.businessIdentityRepository
→ BusinessIdentityRepository.loadLogoBytes(managedFileName)
→ LocalBusinessIdentityRepository
→ File(<managedLogosDirectory>/<managedFileName>).readAsBytes()
```

This is not SharedPreferences, SQLite, Supabase, a network service, or a
per-session runtime cache. It is a direct read of the locally managed logo
file through the repository port, reached by an obsolete presentation locator.

## 7. Existing Application Boundary

The existing target boundary is complete and requires no extension:

```text
PRESENTATION_LOOKUP = ApplicationScope.of(context)
QUERY_MEMBER = ApplicationQueries.businessLogo
QUERY_REQUEST = LoadBusinessLogoQuery(managedFileName: managedFileName)
HANDLER = LoadBusinessLogoQueryHandler
RESULT = ApplicationQueryResult<Uint8List?>
RESULT_VALUE = result.value
RESULT_SOURCE = QueryResultSource.local
READ_AUTHORITY = LocalReadAuthority.managedFile
CONSISTENCY = LocalQueryConsistency.currentKnownState
REPOSITORY_PORT = BusinessIdentityRepository
PRODUCTION_ADAPTER = LocalBusinessIdentityRepository
```

`AppCompositionRoot` already constructs this handler using
`dependencies.repositories.businessIdentityRepository`. That dependency is
the exact shared production repository captured by the legacy bridge and also
used by the root-owned `BusinessIdentityController`. No new query, handler,
result model, dependency slot, repository, adapter, runtime owner, or
composition wiring is allowed or needed.

## 8. Phase 108N Reusable Logo Query/Boundary

Phase 108N changed only the Settings `_LogoPreview` consumer to:

```text
ApplicationScope.of(context)
→ queries.businessLogo
→ execute(LoadBusinessLogoQuery(managedFileName: managedFileName))
→ result.value
```

It retained the empty-name short circuit, `FutureBuilder<Uint8List?>`,
catch-all-to-null behavior, `Image.memory`, `BoxFit.contain`, and silent image
error fallback. Phase 108M uses the same shape for the shared identity header.

Phase 108O must reuse this exact query and handler. Creating another printable
logo query would duplicate identical semantics and violate the locked
governance prohibitions `NO_NEW_QUERY`, `NO_NEW_HANDLER`, and
`NO_BOUNDARY_EXTENSION`. Settings behavior is regression evidence only and is
not reopened.

## 9. Identified Architectural Violation / Direct Read

The violation is narrow:

```text
PRESENTATION_WIDGET
→ GLOBAL_APPREPOSITORIES_LOCATOR
→ REPOSITORY_READ
```

The single offending reference is the `AppRepositories.businessIdentityRepository`
call in `_PrintableLogo._loadBytes()`. The repository and local adapter are not
the violation and must remain unchanged. Other direct logo reads in backup,
PDF export, and financial report code are separate deferred seams and are not
part of Phase 108O.

## 10. Target Read Path

```text
PrintableDocumentScaffold.build
→ valid BusinessIdentity LogoMetadata.managedFileName
→ _PrintableLogo._loadBytes(context)
→ ApplicationScope.of(context).queries.businessLogo
→ LoadBusinessLogoQueryHandler.execute(LoadBusinessLogoQuery)
→ captured BusinessIdentityRepository.loadLogoBytes(managedFileName)
→ LocalBusinessIdentityRepository managed local file
→ ApplicationQueryResult<Uint8List?>.value
→ existing FutureBuilder / Image.memory rendering
```

Only the consumer-to-boundary edge changes. Storage, repository behavior,
handler behavior, metadata, identity state, and rendering stay intact.

## 11. Exact Implementation Strategy

1. In `printable_document_scaffold.dart`, replace the
   `app_repositories.dart` import with the existing business-logo query and
   application-scope imports.
2. Pass the widget `BuildContext` to `_PrintableLogo._loadBytes`, following the
   established Phase 108M/108N pattern.
3. Keep the empty managed-filename short circuit before any scope lookup.
4. Inside the existing `try`, execute
   `ApplicationScope.of(context).queries.businessLogo` with
   `LoadBusinessLogoQuery(managedFileName: managedFileName)` and return only
   `result.value`.
5. Keep the catch-all-to-null fallback and all `FutureBuilder`, constraints,
   `Image.memory`, fit, and `errorBuilder` code unchanged.
6. Add one focused Phase 108O test suite and update only the mathematically
   affected live architecture inventory assertions.

This is one consumer modification plus test/harness adaptation. Constructor
injection, callback injection, provider changes, root wiring, or a new service
locator are unnecessary because `ApplicationScope` already owns the query and
already wraps production presentation.

## 12. Expected Production Files

```text
FILE = lib/features/prints/printable_document_scaffold.dart

CURRENT_ROLE =
shared UI preview scaffold and private business-logo renderer for five
printable document views

WHY_CHANGE_IS_REQUIRED =
_PrintableLogo._loadBytes directly resolves AppRepositories and bypasses the
existing application query boundary

EXPECTED_CHANGE =
replace the locator import/read with existing LoadBusinessLogoQuery and
ApplicationScope execution; pass BuildContext into the private loader; retain
all short-circuit, catch, async, and rendering behavior

WHY_THIS_IS_MINIMAL =
it removes exactly one direct presentation read; every application,
repository, composition, identity, print-view, export, and storage asset
already exists and stays unchanged
```

```text
EXPECTED_PRODUCTION_MODIFY =
lib/features/prints/printable_document_scaffold.dart

EXPECTED_PRODUCTION_ADD = NONE
EXPECTED_PRODUCTION_DELETE = NONE
PRODUCTION_FILES_EXPECTED = 1
```

Any required production change outside this file is an implementation
stop-and-governance-review condition.

## 13. Expected Test Files

### New focused suite

```text
TEST_FILE =
test/phase108o_printable_document_scaffold_logo_query_migration_test.dart

CURRENT_COVERAGE = NEW FILE

EXPECTED_NEW/UPDATED_ASSERTIONS =
focused widget behavior for present/loading/missing/failure/invalid bytes and
absent/invalid metadata; exact query invocation and zero writes; source guard
for application-boundary ownership; exact Phase 108O live inventory result
```

### Existing architecture guards

```text
TEST_FILE = test/phase108i_second_read_only_ui_query_migration_test.dart
CURRENT_COVERAGE = live locator/scope/all-lib inventory
EXPECTED_NEW/UPDATED_ASSERTIONS = 143/37/7/159 becomes 142/36/8/158 only
```

```text
TEST_FILE =
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
CURRENT_COVERAGE = query contract plus exact files containing direct loadLogoBytes calls
EXPECTED_NEW/UPDATED_ASSERTIONS = remove only printable_document_scaffold.dart
from the direct logo-read set; retain handler, Dashboard, and other deferred reads
```

```text
TEST_FILE =
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
CURRENT_COVERAGE = shared-header behavior plus live locator/scope inventory
EXPECTED_NEW/UPDATED_ASSERTIONS = 143/37/7/159 becomes 142/36/8/158;
assert printable scaffold leaves locator files and joins scope consumers while
retaining existing header and Settings assertions
```

```text
TEST_FILE =
test/phase108n_settings_logo_preview_query_migration_test.dart
CURRENT_COVERAGE = Settings preview behavior plus live locator/scope inventory
EXPECTED_NEW/UPDATED_ASSERTIONS = 143/37/7/159 becomes 142/36/8/158;
assert printable scaffold leaves locator files and joins scope consumers while
retaining every Settings behavior/ownership assertion
```

No behavioral assertion in an earlier phase may be weakened. Only live
inventory values and membership affected by the one current migration may
change.

### Unchanged regression files

- `test/phase40_printable_business_documents_test.dart`: all five shared
  printable views and their content remain intact.
- `test/phase91_printable_document_scaffold_design_system_test.dart`: scaffold
  layout, branding text, tokens, actions, scrolling, and back behavior remain
  intact.
- `test/competition05_document_preview_pdf_readiness_test.dart`: invoice
  preview readiness and the scaffold's read-only nature remain intact.
- `test/phase68_business_logo_invoice_windows_icon_test.dart`: managed-logo
  persistence and invoice branding remain intact.

These files are regression gates, not expected edits. A test harness with no
valid logo must continue to work without an `ApplicationScope` because the
scaffold does not construct `_PrintableLogo` in that state.

## 14. Dependency / Wiring Changes

```text
NEW_CONSTRUCTOR_PARAMETER = NO
NEW_CALLBACK = NO
NEW_PROVIDER = NO
NEW_GLOBAL_SINGLETON = NO
NEW_SERVICE_LOCATOR = NO
APPLICATION_BOUNDARY_CHANGE = NO
APPLICATION_DEPENDENCY_CHANGE = NO
COMPOSITION_ROOT_CHANGE = NO
RUNTIME_OWNER_CHANGE = NO
MAIN_APP_WIRING_CHANGE = NO
```

The only dependency adaptation is local to the private widget: it uses its
existing build context to resolve the existing root `ApplicationScope`.
Production already has that scope above all routes. The new focused widget
test will explicitly inject an `ApplicationBoundary` with a spy-backed
`LoadBusinessLogoQueryHandler`, using the established 108M/108N helper pattern.

## 15. Behavioral Invariants

| Case | Invariant |
|---|---|
| Logo metadata absent | `hasLogo` is false; `_PrintableLogo` is not built; no application lookup or repository call; business name and document render normally. |
| Logo metadata invalid | Same as absent; no query and no new scope requirement. |
| Managed filename blank | Private loader returns null before `ApplicationScope.of`; no query/repository call. This remains defensive even though valid metadata requires a non-empty name. |
| Logo present | The exact managed filename is queried once per renderer build and the exact returned byte object reaches `Image.memory`. |
| Loading | `FutureBuilder` renders `SizedBox.shrink`; no progress indicator or message. |
| Missing file/repository null | Query result value is null and the logo remains silently hidden. |
| Repository/query exception | Handler may propagate; `_PrintableLogo` continues catching every failure and returns null; no visible error. |
| Empty or invalid image bytes | `Image.memory` remains the renderer and its existing `errorBuilder` silently shrinks on decode failure. |
| Valid image | Constraints remain maximum 60 high by 200 wide with `BoxFit.contain`. |
| Async lifecycle | Remains `Future<Uint8List?>` plus a stateless private renderer and build-created `FutureBuilder`; no cache, memoization, cancellation, state, or prefetch is added. |
| Scaffold layout | Logo position, spacing, identity name/address/phone, title, metadata, body, footer, actions, scrolling, and back behavior do not change. |
| Shared consumers | All five previews obtain the same behavior by using the unchanged shared scaffold; their individual files do not change. |
| PDF/export | Preview callbacks and PDF builders/export services are untouched. |

## 16. Read-Only / Local-Only Invariants

The query remains a pure local read. Its handler has one repository read for a
non-empty filename and none for an empty filename. The selected path must not
call `saveIdentity`, `saveLogoBytes`, `deleteLogoFile`, file writes, database
writes, preference writes, remote fetches, queues, or caches.

```text
QUERY_SOURCE = LOCAL
READ_AUTHORITY = MANAGED_FILE
CONSISTENCY = CURRENT_KNOWN_STATE
WRITE_SIDE_EFFECTS = NONE
NETWORK_SIDE_EFFECTS = NONE
SUPABASE_ACCESS = NONE
CLOUD_FALLBACK = NONE
SYNC/HYDRATION = NONE
```

The UI consumes only `ApplicationQueryResult.value`; it must not reinterpret
or replace the existing local metadata contract.

## 17. Session / Business Context Semantics

Current repository evidence establishes a single local business-identity
profile. `LocalBusinessIdentityRepository` resolves one identity JSON file and
one managed-logo directory; `LoadBusinessLogoQuery` accepts only a managed
filename. There is no business ID, warehouse ID, session ID, user ID, or tenant
key in this read.

```text
LOGO_SCOPE = GLOBAL_LOCAL_BUSINESS_IDENTITY_PROFILE
PER_BUSINESS = NO CURRENT KEY
PER_WAREHOUSE = NO
PER_SESSION = NO
PER_USER = NO
BUSINESS_CONTEXT_REQUIRED = NO
SESSION_CONTEXT_REQUIRED = NO
NEW_CONTEXT_MODEL = FORBIDDEN
```

The root-owned identity controller and logo query handler share the exact
captured `BusinessIdentityRepository`. Phase 108O preserves that current
semantics and must not invent tenant or session scoping.

## 18. Mandatory Tests

The future focused Phase 108O suite must prove all of the following:

1. A valid logo makes `_PrintableLogo` invoke the injected
   `ApplicationQueries.businessLogo` handler with the exact managed filename,
   exactly once for the observed renderer build, and forward the exact bytes.
2. The image remains constrained to 60 by 200 maximum and uses
   `BoxFit.contain` with a non-null silent `errorBuilder`.
3. A pending query renders no image, spinner, placeholder, or error text; a
   successful completion renders the image without writes.
4. Repository null/missing file renders no image and raises no framework
   exception.
5. A thrown query/repository failure is swallowed by the consumer and remains
   visually silent.
6. Invalid/empty returned bytes preserve the `Image.memory` silent decode
   fallback and do not trigger a write.
7. Absent and invalid `LogoMetadata` build the document without an
   `ApplicationScope`, perform zero reads, and retain the normal document/name
   content.
8. Spy counters prove zero identity writes, logo writes, and logo deletes in
   every scenario.
9. A source-region guard proves `_PrintableLogo` uses
   `ApplicationScope.of(context).queries.businessLogo` and
   `LoadBusinessLogoQuery`, returns `result.value`, and retains the empty-name
   short circuit before scope lookup.
10. The same source region contains no `AppRepositories`, direct
    `loadLogoBytes`, handler construction, concrete local repository, `dart:io`,
    `File`, database/Drift/SQLite, Supabase/cloud, context invention, or write
    token.
11. The exact direct-logo-read inventory no longer includes the printable
    scaffold and leaves every deferred backup/export/financial-report read
    unchanged.
12. Live inventory is exactly 36 feature/shared locator files, 142
    feature/shared locator references, 8 feature/shared scope consumers, and
    158 all-lib locator references.
13. Phase 108N Settings and Phase 108M shared-header behavior tests remain
    unchanged and green.
14. Phase 40, Phase 91, COMPETITION-05, and Phase 68 regressions remain green.

Source assertions are appropriate here because phases 108I, 108L, 108M, and
108N already use narrowly scoped architecture ownership guards. They must
inspect the `_PrintableLogo` region and may not forbid legitimate deferred
reads elsewhere in the repository.

## 19. Quality Gates

Run future implementation validation in diagnostic order:

```powershell
flutter test test\phase108o_printable_document_scaffold_logo_query_migration_test.dart

flutter test `
  test\phase108i_second_read_only_ui_query_migration_test.dart `
  test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart `
  test\phase108m_shared_business_identity_header_logo_query_migration_test.dart `
  test\phase108n_settings_logo_preview_query_migration_test.dart

flutter test `
  test\phase40_printable_business_documents_test.dart `
  test\phase91_printable_document_scaffold_design_system_test.dart `
  test\competition05_document_preview_pdf_readiness_test.dart `
  test\phase68_business_logo_invoice_windows_icon_test.dart

dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
git diff --check
git diff --cached --check
git status --porcelain=v1 --untracked-files=all
```

If the normal Dart wrapper has an environmental lock issue, the existing
Flutter-bundled Dart executable may be used for the same non-writing format
check; this does not authorize a toolchain or dependency change.

Inherited locked baseline, not rerun by this planning session:

```text
flutter analyze = PASS
dart format = PASS — 461 files, 0 changed
FULL_SUITE_SEQUENTIAL = PASS — 2531 passed, 0 failed
FULL_SUITE_CONCURRENCY_1 = PASS — 2531/2531
```

The historical parallel-only Phase 8M `ConnectionClosedException` is classified
as a resource race only for that established event. It may not excuse any new
failure. Every future regression must be investigated.

Planning-time focused validation executed before this artifact:

```text
TARGETED_LOGO_AND_PRINTABLE_TESTS = PASS
PASSED = 76
FAILED = 0
```

The full suite was intentionally not rerun for this documentation-only plan.

## 20. Negative Scope

Phase 108O explicitly excludes:

```text
NO settings logo feature expansion
NO Settings logo preview reimplementation
NO new logo upload workflow
NO logo editing
NO logo deletion UX or delete-path change
NO logo save change
NO image picker changes
NO business identity profile migration
NO invoice domain contract creation
NO invoice repository redesign
NO invoice numbering work
NO invoice persistence migration
NO new printable document types
NO print layout redesign
NO printable visual redesign
NO PDF visual redesign
NO PDF export migration
NO report redesign
NO financial report branding migration
NO cloud logo storage
NO remote logo retrieval or fallback
NO Supabase work
NO database or schema migrations
NO SQLite changes
NO sync engine work
NO hydration work
NO licensing work
NO authentication work
NO RBAC changes
NO routing changes
NO app-shell redesign
NO runtime-owner change
NO new repository
NO new query
NO new handler
NO boundary extension
NO new persistence
NO cross-feature or broad architecture refactor
NO unrelated cleanup or test rewrites
NO dependency upgrades or package additions
NO platform, generated, or CI changes
NO historical Phase 108O implementation reuse
NO historical branch merge, cherry-pick, rebase, deletion, or rewrite
NO behavior change
NO write-path change
NO second logo consumer migration
```

Explicitly deferred future work includes the unnumbered invoice contract
intent; direct logo reads in PDF export, backup export, and financial report
screens; broader report/dashboard queries; and any future tenant-aware
business-identity design.

## 21. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| A valid-logo test or legacy harness lacks `ApplicationScope` | Production root is already scoped; inject the existing boundary only in the new valid-logo focused harness. Preserve absent/invalid metadata gating so no-logo harnesses need no scope. |
| Query exception becomes visible | Keep the existing consumer `try/catch` and add thrown-query silent-fallback coverage. |
| Loading or image decode changes the UI | Keep `FutureBuilder`, `Image.memory`, constraints, fit, and `errorBuilder` unchanged; assert each behavior. |
| Shared-scaffold change has a five-preview blast radius | Change only the private shared query seam and run all Phase 40/91 printable regressions; do not edit the five consumer files. |
| PDF/export work is accidentally conflated with preview branding | Treat export services/builders as protected deferred surfaces; verify the production allowlist is one file. |
| Scope lookup occurs for absent/blank metadata | Retain valid-logo construction gating and empty-name short circuit before `ApplicationScope.of`; test zero reads. |
| New caching changes freshness or query count | Add no state/cache/memoization; preserve the build-created future and controller-driven rebuild behavior. |
| Application handler or repository is duplicated | Reuse `ApplicationQueries.businessLogo` exclusively; static guard forbids handler construction and concrete adapters in the widget. |
| Tenant/session semantics are invented | Preserve the filename-only global local profile and require no business/session context. |
| Live architecture guards are broadly rebased | Apply only the exact `143/37/7/159 → 142/36/8/158` delta and one direct-read set removal. |
| Empty bytes are reclassified as null | Preserve exact query value and existing `Image.memory` decode fallback; do not normalize. |
| A second direct-logo read is migrated opportunistically | Exact source allowlist and direct-read inventory review; stop if another consumer changes. |

If repository reality in the implementation session contradicts these facts or
requires a new application asset, production file, behavior, or context model,
stop for governance review rather than expanding scope.

## 22. Implementation Sequence

1. Verify the separately remotely locked Phase 108O planning baseline, exact
   repository identity, branch parity, annotated tag, clean worktree/index,
   empty untracked/stash state, and protected governance/planning blobs.
2. Run the focused current baseline for phases 108L, 108M, 108N and the shared
   printable regressions.
3. Reconfirm `ApplicationQueries.businessLogo`,
   `LoadBusinessLogoQueryHandler`, and the exact captured repository remain
   unchanged and reusable.
4. Modify only `lib/features/prints/printable_document_scaffold.dart` using
   section 11's consumer adaptation.
5. Add only
   `test/phase108o_printable_document_scaffold_logo_query_migration_test.dart`
   for focused behavior and ownership coverage.
6. Update only the exact inventory assertions in the four identified prior
   phase guard files.
7. Run the new focused suite, then the architecture/inventory guards.
8. Run the unchanged Settings, shared-header, printable, invoice readiness,
   and managed-logo regressions.
9. Run the non-writing formatter, analyzer, full suite with concurrency one,
   inventory searches, and Git diff checks.
10. Confirm the implementation diff contains exactly one production file, one
    new test, and four guard updates; no other files may change.
11. Create one local implementation commit only if every gate passes.
12. Stop before any push or tag for a separate Phase 108O implementation
    remote-lock session.

## 23. Definition of Done

Future implementation is complete only when:

```text
1. Exactly _PrintableLogo._loadBytes is migrated through the existing query.
2. AppRepositories is absent from printable_document_scaffold.dart.
3. LoadBusinessLogoQuery and ApplicationQueries.businessLogo are reused.
4. No application/repository/composition contract is added or changed.
5. Exact bytes/null/error semantics are preserved.
6. Loading, image fallback, 60x200 constraints, fit, and layout are preserved.
7. Absent/invalid metadata performs no query and requires no scope.
8. The read remains local-only and write-free.
9. Global local business-identity scope is preserved without new context.
10. All mandatory focused, architecture, regression, format, analyze, full-suite,
    and diff gates pass.
11. Live inventory is exactly 36/142/8/158 and only the scaffold leaves the
    direct logo-read set.
12. Production changes equal one file; no second consumer or deferred surface moves.
13. Settings Phase 108N behavior remains unchanged.
14. No database, Supabase, dependency, platform, generated, CI, or remote mutation occurs.
15. The implementation is committed locally once and stops before remote lock.
```

Any unmet item is not partial success; it is a fail-closed implementation
blocker requiring correction within scope or a new governance decision.

## 24. Remote-Lock Separation

This planning session may create only the local documentation commit containing
this file. It must not push, create a tag, or implement Phase 108O.

```text
CURRENT_SESSION_END_STATE = PHASE_108O_PLANNING_LOCAL_CLOSURE

PHASE_108O_GOVERNANCE_REMOTE_LOCK = COMPLETE
PHASE_108O_PLANNING_LOCAL_CLOSURE = COMPLETE_AFTER_LOCAL_COMMIT
PHASE_108O_PLANNING_REMOTE_LOCK = NOT_STARTED
PHASE_108O_IMPLEMENTATION = NOT_STARTED

NEXT_AUTHORIZED_SESSION = PHASE_108O_PLANNING_REMOTE_LOCK
```

The later planning remote-lock session is distinct from implementation. It
must verify and lock this planning commit without modifying it. Implementation
may begin only after that separate remote lock is complete and a new session
is explicitly authorized.
