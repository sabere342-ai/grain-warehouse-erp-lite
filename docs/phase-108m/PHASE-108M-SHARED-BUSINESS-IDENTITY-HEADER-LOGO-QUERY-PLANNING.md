# Phase 108M — Shared Business Identity Header Logo Query Planning

## 1. Planning status and governing baseline

```text
AUTHORIZED_SESSION = PHASE_108M_PLANNING
PLANNING_CLASSIFICATION = CASE_A_FRESH_PLANNING

PHASE_108M_GOVERNANCE_COMMIT =
30b654099a79fca426a1467a501f7ef235d1e751

PHASE_108M_GOVERNANCE_TAG =
phase-108m-governance-reconciliation-locked

PHASE_108M_GOVERNANCE_TAG_OBJECT =
a7f337f58a0c32f27ffbaec53cae04faf9856b9c

PHASE_108M_GOVERNANCE_TAG_PEELED_TARGET =
30b654099a79fca426a1467a501f7ef235d1e751

GOVERNANCE_ARTIFACT =
docs/phase-108m/PHASE-108M-SCOPE-DISCOVERY.md

GOVERNANCE_ARTIFACT_BLOB =
303eb84d42ec54715a93566165c71d10583728ad

PHASE_108M_IMPLEMENTATION = NOT_STARTED
```

The local and remote governing branch were both at the governance commit at
planning entry. The governance commit is a normal one-parent commit whose
parent is `f0e53febb3bba0f5c9aaa348702c78d3feeee96d`. The protected Phase 108K,
108L, and 108M governance/planning blobs and the locked lineage through Phase
108L implementation were verified before this artifact was created.

## 2. Canonical scope

The scope is frozen exactly as:

```text
ONE_LOCAL_READ_ONLY_SHARED_BUSINESS_IDENTITY_HEADER_LOGO_UI_QUERY_MIGRATION_THROUGH_EXISTING_APPLICATION_BOUNDARY
```

This plan answers only how to migrate the one selected shared-header read.
It does not reopen candidate selection and does not authorize implementation
in this planning session.

## 3. Problem statement

`BusinessIdentityHeader` is the remaining selected shared presentation widget
whose private `_IdentityLogo` reads managed logo bytes by resolving
`AppRepositories.businessIdentityRepository` directly. Phase 108L already
created, composed, and exposed the application query that performs the exact
same read. Phase 108M will remove only this one presentation-to-locator seam
and will leave the repository, managed file, query contract, handler,
composition, write flows, layout, and observable behavior unchanged.

## 4. Exact current architecture

The selected consumer is
`lib/shared/widgets/business_identity_header.dart`:

- `BusinessIdentityHeader` begins at line 9;
- the private `_IdentityLogo` begins at line 143;
- `_IdentityLogo.build` creates a `FutureBuilder<Uint8List?>`;
- `_IdentityLogo._loadBytes` checks the managed filename, catches failures,
  and resolves the locator at lines 175–178.

```text
BusinessIdentityHeader._IdentityLogo
  -> AppRepositories.businessIdentityRepository
  -> LocalBusinessIdentityRepository.loadLogoBytes
  -> managed local file
```

The exact current read is one literal
`AppRepositories.businessIdentityRepository` reference in the selected file.
`AppRepositories` constructs `LocalBusinessIdentityRepository` in
`lib/app/app_repositories.dart` and production initialization replaces it with
another `LocalBusinessIdentityRepository` using the active audit-log
repository. `loadLogoBytes` in
`lib/core/business_identity/business_identity_repository.dart` rejects empty
or path-like names, checks the managed logos directory, returns null for an
absent file, and otherwise returns `File.readAsBytes()`.

## 5. Exact existing application query surface

No application contract needs to be created or changed.

| Item | Exact live contract |
|---|---|
| Owning surface | `ApplicationQueries` in `lib/application/application_boundary.dart` |
| Property | `final LoadBusinessLogoQueryHandler businessLogo` |
| Request | `LoadBusinessLogoQuery` |
| Request input | required `String managedFileName`; no other input |
| Handler | `LoadBusinessLogoQueryHandler` |
| Handler interface | `ApplicationQueryHandler<LoadBusinessLogoQuery, Uint8List?>` |
| Execute result | `Future<ApplicationQueryResult<Uint8List?>>` |
| Value | the exact repository `Uint8List?` result |
| Metadata | local / managedFile / currentKnownState |
| Repository dependency | private final `BusinessIdentityRepository _repository` |
| Repository call | `_repository.loadLogoBytes(query.managedFileName)` |
| Composition | `AppCompositionRoot.initializeProduction` constructs the handler inside the one root-owned `ApplicationQueries` |
| Widget exposure | `ApplicationScope.of(context).queries.businessLogo` |

`LoadBusinessLogoQueryHandler` is in
`lib/application/queries/load_business_logo_query.dart`. It returns null with
managed-file metadata and no repository call for an empty filename. For a
non-empty filename, it forwards the input verbatim exactly once, preserves the
repository's bytes or null result, and lets the exact repository exception
propagate. Phase 108M changes none of those semantics.

```text
NEW_APPLICATION_CONTRACT = NONE
NEW_QUERY = NONE
NEW_HANDLER = NONE
NEW_REPOSITORY = NONE
NEW_COMPOSITION_ROOT = NONE
```

## 6. Repository capture and authority proof

`AppCompositionRoot.initializeProduction` captures
`AppRepositories.businessIdentityRepository` once as
`sharedBusinessIdentityRepository`. That exact instance is supplied to both
`BusinessIdentityController` and
`LegacyApplicationDependencyBridge.captureSharedInstances`. The bridge stores
it as
`ApplicationDependencies.repositories.businessIdentityRepository`, and the
root constructs `LoadBusinessLogoQueryHandler` from that dependency. The
handler constructor stores the supplied object in its final `_repository`
field.

Therefore the target route reaches the same object that the selected locator
route reaches. No repository lookup, duplicate repository, adapter, source,
or lifetime changes.

```text
same BusinessIdentityRepository authority
same LocalBusinessIdentityRepository implementation
same managed file
same loadLogoBytes semantics

SOURCE = local
READ_AUTHORITY = managedFile
CONSISTENCY = currentKnownState
DATABASE_AUTHORITY = NONE
CLOUD_AUTHORITY = NONE
SERVER_AUTHORITY = NONE
FINANCIAL_SEMANTICS = NONE
```

## 7. Exact target architecture

```text
BusinessIdentityHeader._IdentityLogo
  -> ApplicationScope.of(context).queries.businessLogo
  -> LoadBusinessLogoQuery(managedFileName: managedFileName)
  -> LoadBusinessLogoQueryHandler.execute
  -> exact captured BusinessIdentityRepository
  -> LocalBusinessIdentityRepository.loadLogoBytes
  -> same managed local file
```

The consumer takes only `result.value`. It must not inspect, transform, cache,
decode, copy, or replace the returned bytes outside the existing
`Image.memory` rendering path.

## 8. Widget lifecycle and context strategy

`_IdentityLogo` is a `StatelessWidget`. Its `build` method already creates a
new future for `FutureBuilder` on each widget rebuild. The future is not stored
in state, and the selected migration must not introduce state, caching,
post-frame work, or mounted checks.

The exact future implementation is:

1. pass the current build context to the existing private loader by changing
   `future: _loadBytes()` to `future: _loadBytes(context)`;
2. retain the empty-filename short circuit before query execution;
3. inside the existing `try` block resolve
   `ApplicationScope.of(context).queries.businessLogo`;
4. execute the existing `LoadBusinessLogoQuery` with the exact
   `managedFileName`;
5. return only `result.value`;
6. retain the current catch-all conversion of read failures to null.

The inherited lookup occurs while a descendant is building, which is a valid
context use. Production `main.dart` places `ApplicationScope` above
`TrialAppGate`, `GrainWarehouseApp`, routed `DashboardShell`, its desktop and
mobile shared headers, and the nested `SettingsScreen` preview. Both production
render sites therefore have the required ancestor. `FutureBuilder` continues
to own asynchronous snapshot relevance; no callback calls `setState`, so no
new mounted/rebuild rule is required.

The only historical direct widget harness with valid logo metadata and no
application scope is the first Phase 96 header widget test. It must receive
the existing scope and a focused handler-backed repository fixture. No-logo
Phase 96 cases do not create `_IdentityLogo` and need no scope. The Phase 13
settings harness has no valid logo metadata and need not be changed. The Phase
108L dashboard harness already supplies `ApplicationScope`.

## 9. Null, loading, error, and rendering invariants

The following behavior is frozen:

- absent identity or absent/invalid logo metadata: `_IdentityLogo` is not
  built and no logo query executes;
- empty managed filename: returns null before the query and renders
  `SizedBox.shrink`;
- repository null or missing managed file: returns null and renders
  `SizedBox.shrink`;
- repository/read exception: the handler continues to propagate it and the
  widget's existing catch converts it to null with no visible error;
- loading snapshot: renders `SizedBox.shrink` with no progress indicator;
- non-null bytes: the exact byte-list instance reaches unchanged
  `Image.memory` with `BoxFit.contain`;
- empty or invalid image bytes, if returned: continue through the same
  `Image.memory` path and existing `errorBuilder` silent fallback; no new
  validation is added;
- standard header constraints remain `maxHeight: AppIconSizes.hero` and
  `maxWidth: 120`;
- compact header constraints remain `maxHeight: AppIconSizes.md` and
  `maxWidth: AppIconSizes.lg`;
- display name, subtitle, spacing, typography, compact behavior, and identity
  scope resolution remain unchanged.

```text
BUSINESS_BEHAVIOR_CHANGE = NONE
UI_BEHAVIOR_CHANGE = NONE
```

## 10. Write isolation

The existing application query exposes and invokes only `loadLogoBytes`.
Focused spies must keep counters for all business-identity writes and prove
they remain zero while the header loads, succeeds, returns null, or catches a
failure.

The following nearby write surfaces are inspected but frozen outside Phase
108M:

- `BusinessIdentityController.saveEstablishmentName` and
  `saveProfileDetails` call `saveIdentity`;
- `BusinessIdentityController.saveLogo` calls `saveLogoBytes`,
  `saveIdentity`, and possibly `deleteLogoFile`;
- `BusinessIdentityController.removeLogo` calls `saveIdentity` and possibly
  `deleteLogoFile`;
- `SettingsScreen` owns logo selection, replacement, deletion, and identity
  editing UI;
- `LocalBusinessIdentityRepository` owns all file writes and deletions.

None of those files or flows may change in implementation.

```text
READ_ONLY = YES
WRITE_PATH_CHANGE = NONE
SETTINGS_BEHAVIOR_CHANGE = NONE
```

## 11. Exact file-level implementation allowlist

No future implementation file outside this table is authorized by this plan.

| File | Classification | Current role | Exact planned change | Why required | Prohibited within file |
|---|---|---|---|---|---|
| `lib/shared/widgets/business_identity_header.dart` | PRODUCTION | Selected shared header and its private direct locator read | Replace only the locator import/resolution with the existing query/scope imports and the `_loadBytes(context)` execution path described in section 8 | Closes the one canonical presentation seam | Layout, public widget API, identity resolution, constraints, fallback behavior, a second consumer, write logic |
| `test/phase108m_shared_business_identity_header_logo_query_migration_test.dart` | TEST / ARCHITECTURAL_GUARD (CREATE) | Does not exist | Add focused widget, source-boundary, exact-repository, no-write, and one-seam proofs | Makes the selected migration independently testable without weakening historical tests | New production contracts, printable/export coverage, settings mutations, broad locator cleanup |
| `test/phase96_in_app_business_identity_app_shell_branding_test.dart` | HARNESS (MODIFY) | Historical direct header behavior harness | Inject the existing `ApplicationScope` only for the valid-logo header case, route it to a focused repository, and make the existing logo claim truthful by asserting the unchanged memory image behavior | It is the sole direct valid-logo historical harness missing scope | Rebaseline no-logo/name/layout cases or change Phase 96 intent |
| `test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart` | ARCHITECTURAL_GUARD (MODIFY) | Existing handler/composition/dashboard contract and live `loadLogoBytes` file inventory | Remove only `lib/shared/widgets/business_identity_header.dart` from the live direct-logo-read inventory and retain all Phase 108L handler/composition/App Bar assertions unchanged | The selected file no longer contains a direct repository call | Alter query semantics, dashboard behavior, or deferred logo consumer expectations |
| `test/phase108i_second_read_only_ui_query_migration_test.dart` | INVENTORY_ASSERTION (MODIFY) | Current-tree feature/shared and all-lib locator/scope counts | Change only live counts to 144 references, 38 locator files, 6 `ApplicationScope.of` consumer files, and 160 all-lib locator references | Records exactly the one-seam delta | Historical SHA changes, other architecture expectations, or broader rebaselining |

Expected production touch count is one. The new focused test is preferred over
placing Phase 108M behavior inside a prior phase's suite; the three existing
test modifications are required only by a known harness or current-tree guard.

Expected unchanged implementation evidence:

- `lib/application/queries/load_business_logo_query.dart`;
- `lib/application/application_boundary.dart`;
- `lib/application/queries/application_query.dart`;
- `lib/application/application_dependencies.dart`;
- `lib/composition/application_scope.dart`;
- `lib/composition/app_composition_root.dart`;
- `lib/composition/legacy_application_dependency_bridge.dart`;
- `lib/app/app_repositories.dart`;
- `lib/main.dart`;
- `lib/core/business_identity/business_identity_repository.dart`;
- `lib/core/business_identity/business_identity_controller.dart`;
- `lib/features/dashboard/dashboard_shell.dart`;
- `lib/features/settings/settings_screen.dart`.

If a focused failure appears to require editing any unchanged production file,
implementation must stop for scope review. “Related files,” cleanup, and
opportunistic refactors are not authorized.

## 12. Test impact and exact proof obligations

### TESTS_TO_ADD

`test/phase108m_shared_business_identity_header_logo_query_migration_test.dart`
must prove:

1. standard and compact valid-logo paths execute
   `ApplicationScope.of(context).queries.businessLogo` once with the exact
   managed filename;
2. the exact returned byte-list instance reaches the existing `MemoryImage`;
3. standard/compact constraints and `BoxFit.contain` are unchanged;
4. loading, null/missing, thrown-read, empty-name, empty/invalid bytes, and
   absent-logo paths retain silent fallback behavior;
5. query execution performs zero `saveIdentity`, `saveLogoBytes`, and
   `deleteLogoFile` calls;
6. the header source has no `app_repositories.dart`, `AppRepositories`, direct
   `loadLogoBytes`, concrete local repository construction, `File`, Drift,
   database, Supabase, cloud, or write token;
7. the header source contains the existing `businessLogo` query execution and
   does not construct `LoadBusinessLogoQueryHandler`;
8. only the selected header locator reference disappears.

### TESTS_TO_MODIFY

- `test/phase96_in_app_business_identity_app_shell_branding_test.dart`: only
  the valid-logo harness/assertion described in section 11;
- `test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart`:
  only the live direct-logo-read file set;
- `test/phase108i_second_read_only_ui_query_migration_test.dart`: only the four
  current-tree inventory totals.

### HISTORICAL_HARNESSES_REQUIRING_SCOPE_INJECTION

```text
test/phase96_in_app_business_identity_app_shell_branding_test.dart
  -> valid-logo BusinessIdentityHeader case only
```

The Phase 13 settings harness has no valid logo and does not resolve the query.
The Phase 108L dashboard logo harness is already scoped. Printable Phase 40 and
91 harnesses exercise a deferred consumer and must remain scope-independent.

### TESTS_TO_RUN_UNCHANGED

- `test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart`
  retains handler bytes/null/error/metadata and exact composition identity;
- `test/phase108h_app_shell_runtime_ownership_test.dart` retains exact shared
  business-identity repository capture;
- `test/phase108f_first_read_only_ui_query_migration_test.dart` and
  `test/phase108k_product_catalog_query_migration_test.dart` retain the exact
  four-query inventory and application-boundary composition;
- `test/phase68_business_logo_invoice_windows_icon_test.dart` retains local
  managed-file save/load/missing/path-safety behavior;
- `test/phase83_shell_navigation_responsive_test.dart` retains shell layout;
- `test/phase13_backup_export_test.dart` retains the Settings render site and
  backup/write isolation;
- `test/phase40_printable_business_documents_test.dart` and
  `test/phase91_printable_document_scaffold_design_system_test.dart` prove
  printable branding remains deferred and unchanged;
- the full test suite is the final broader regression gate.

## 13. Locator inventory proof

The locked governance methodology counts literal `AppRepositories.`
references and files containing them under `lib/features` and `lib/shared`.
Planning reproduced the exact baseline:

```text
BEFORE =
39 AppRepositories consumer files
145 literal AppRepositories. references

AFTER =
38 AppRepositories consumer files
144 literal AppRepositories. references

EXPECTED_DELTA =
-1 consumer file
-1 literal reference
```

For the existing all-lib live assertion, the corresponding count is
`161 -> 160`. Files under `lib/features` and `lib/shared` containing
`ApplicationScope.of` become `5 -> 6`. These additional values are guard
mechanics, not a broader scope metric.

The future implementation must use:

```powershell
rg -l "AppRepositories\." lib\features lib\shared --glob '*.dart'
rg -o "AppRepositories\." lib\features lib\shared --glob '*.dart'
rg -n "AppRepositories\.businessIdentityRepository" lib --glob '*.dart'
rg -n "loadLogoBytes\(" lib --glob '*.dart'
rg -n "ApplicationScope\.of" lib\features lib\shared --glob '*.dart'
```

PowerShell `Measure-Object -Line` may be applied to the first two outputs to
prove the exact file and reference totals. Documents, tests, and generated
outputs are excluded from the meaningful 39/145 architectural baseline.

## 14. Behavioral invariants

```text
same logo bytes
same managed file
same local repository authority
same empty/missing-logo behavior
same loading behavior
same failure/fallback behavior
same business identity writes
same settings behavior
same visual intent
no additional side effects

BUSINESS_BEHAVIOR_CHANGE = NONE
UI_BEHAVIOR_CHANGE = NONE
WRITE_PATH_CHANGE = NONE
```

## 15. Future implementation sequence

This sequence is authorized only in a separately authorized Phase 108M
implementation session:

1. verify the locked planning baseline, clean repository, protected blobs,
   tags, branch, and remote parity;
2. rerun the focused baseline before editing;
3. modify only `business_identity_header.dart` using section 8's exact query
   execution shape;
4. add the one Phase 108M focused test;
5. inject scope only into the Phase 96 valid-logo harness;
6. adjust only the Phase 108L logo-read set and Phase 108I live counts;
7. run the focused tests, architecture guards, unchanged regressions, locator
   inventory, formatter, analyzer, full test suite, and Git diff checks;
8. inspect the complete diff and fail closed if it exceeds the five-file
   allowlist or changes a protected/deferred surface;
9. create only the implementation commit explicitly authorized by that later
   session; do not push or tag without separate authority.

## 16. Exact validation plan

### FOCUSED_TESTS

```powershell
flutter test test\phase108m_shared_business_identity_header_logo_query_migration_test.dart
flutter test test\phase96_in_app_business_identity_app_shell_branding_test.dart test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
```

### ARCHITECTURAL_GUARDS

```powershell
flutter test test\phase108h_app_shell_runtime_ownership_test.dart test\phase108i_second_read_only_ui_query_migration_test.dart
flutter test test\phase108f_first_read_only_ui_query_migration_test.dart test\phase108k_product_catalog_query_migration_test.dart
```

### BROADER_REGRESSION

```powershell
flutter test test\phase68_business_logo_invoice_windows_icon_test.dart test\phase83_shell_navigation_responsive_test.dart
flutter test test\phase13_backup_export_test.dart test\phase40_printable_business_documents_test.dart test\phase91_printable_document_scaffold_design_system_test.dart
flutter test
```

### DART_FORMAT

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test
```

The direct executable is the same Flutter-bundled Dart SDK used by the
repository's established validation workaround; it does not install, upgrade,
or reconfigure the toolchain. If the normal `dart` batch wrapper is used and
reproduces its known lock, classify only the wrapper issue as environmental.

### FLUTTER_ANALYZE

```powershell
flutter analyze
```

### GIT_DIFF_CHECK

```powershell
git diff --check
git diff --cached --check
git status --porcelain=v1 --untracked-files=all
git diff --name-only
git diff --stat
```

### LOCATOR_INVENTORY

Run the five `rg` commands in section 13 and the focused architecture guards.
The feature/shared totals must be exactly `38 / 144`; all-lib references must
be 160; and no logo consumer besides the selected shared header may move.

## 17. Planning-session validation record

The live baseline was validated without source or test mutation:

```text
FOCUSED_TESTS = PASS
PASS_COUNT = 70
FAIL_COUNT = 0

TEST_COMMAND =
flutter test test\phase96_in_app_business_identity_app_shell_branding_test.dart test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart test\phase13_backup_export_test.dart test\phase40_printable_business_documents_test.dart test\phase91_printable_document_scaffold_design_system_test.dart

DART_FORMAT = PASS
DART_FORMAT_RESULT = 459 files / 0 changed
DART_EXECUTABLE = C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe

FLUTTER_ANALYZE = PASS
FLUTTER_ANALYZE_RESULT = No issues found

CURRENT_APPREPOSITORIES_CONSUMER_FILES = 39
CURRENT_LITERAL_APPREPOSITORIES_REFERENCES = 145
```

Git diff, staged diff, commit topology, protected artifact, worktree, stash,
and remote-divergence gates are planning-closure checks performed after this
artifact is finalized.

## 18. Failure and rollback model

Implementation fails closed without a commit if:

- the existing query cannot preserve the current bytes/null/error/UI behavior;
- a harness requires a new application contract or unrelated architecture;
- the diff requires any production file besides the selected header;
- the locator delta is not exactly one file and one reference;
- a second logo/branding consumer moves;
- a write path becomes reachable or needs modification;
- database, SQLite, Supabase, cloud, server, sync, generated, dependency, or
  financial work appears necessary;
- deferred printable/export/settings behavior changes; or
- the test/analysis/format/diff gates do not pass.

Before an implementation commit, rollback means applying explicit inverse
edits only to the five authorized files and re-running the clean-tree gates.
No `reset`, rebase, amend, force operation, tag move, remote mutation, data
rollback, or history rewrite is part of this model. If a failure is discovered
after a later authorized commit, remediation requires a separately authorized
normal follow-up; this plan does not authorize rewriting history.

## 19. Explicit non-goals and deferred surfaces

The following are all outside Phase 108M and forbidden by this plan:

```text
second logo consumer migration
settings/logo mutation migration
printable branding
PDF branding
export branding
expenses
suppliers
customers
financial accounts
financial statements
dashboard/report aggregate cleanup
broad AppRepositories cleanup
repository redesign
new application contracts
new query handlers
new repositories
new composition root
database work
SQLite schema work
Supabase work
cloud authority
server authority
sync work
generated files
dependency upgrades
UI redesign
business behavior change
branding redesign
performance redesign
unrelated test cleanup
unrelated analyzer cleanup
unrelated formatting changes
```

Specifically deferred, even where they call `loadLogoBytes`, are
`SettingsScreen`'s private logo preview/read and every settings write; the
printable document scaffold; PDF export; backup export; financial-report
branding helpers; and all report/export identity metadata reads. Dashboard App
Bar Phase 108L behavior is regression evidence, not a second Phase 108M
consumer.

```text
DATABASE_MUTATION = NONE
SUPABASE_MUTATION = NONE
REMOTE_MUTATION = NONE
GENERATED_FILE_CHANGE = NONE
DEPENDENCY_CHANGE = NONE
```

## 20. Implementation acceptance criteria

Phase 108M implementation may be accepted only when all are true:

```text
1. Only canonical shared-header logo seam migrated.
2. Existing Phase 108L businessLogo query reused.
3. No new application contract.
4. No new repository.
5. No write-path change.
6. No database/Supabase change.
7. No printable/export branding migration.
8. User-visible behavior preserved.
9. Focused tests pass.
10. Analyzer passes.
11. Formatting passes.
12. Git diff checks pass.
13. Locator inventory becomes exactly 38 / 144.
14. Worktree contains only authorized implementation surface.
```

Additional closure gates are: the exact handler/repository identity remains
proven; the full test suite passes; all protected governance/planning blobs and
historical tags remain exact; production files changed equals one; no remote
branch or tag mutation occurs; and implementation stops before any separately
authorized remote-lock action.

## 21. Frozen future implementation surface

```text
MODIFY_PRODUCTION = lib/shared/widgets/business_identity_header.dart
CREATE_TEST = test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
MODIFY_HARNESS = test/phase96_in_app_business_identity_app_shell_branding_test.dart
MODIFY_ARCHITECTURAL_GUARD = test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
MODIFY_INVENTORY_ASSERTION = test/phase108i_second_read_only_ui_query_migration_test.dart

APPLICATION_MEMBER = ApplicationQueries.businessLogo
QUERY = LoadBusinessLogoQuery(managedFileName)
HANDLER = existing LoadBusinessLogoQueryHandler
RESULT = ApplicationQueryResult<Uint8List?>.value
REPOSITORY_CALL = existing BusinessIdentityRepository.loadLogoBytes only
UI_CONSUMER = BusinessIdentityHeader._IdentityLogo only

PRODUCTION_FILES_AUTHORIZED = 1
SECOND_CONSUMER = FORBIDDEN
WRITE_CHANGE = NONE
DATABASE_CHANGE = NONE
SUPABASE_CHANGE = NONE
REMOTE_CHANGE = NONE
IMPLEMENTATION = NOT_STARTED
```

Any deviation requires a new governance decision. It is not implicitly
authorized by this plan.
