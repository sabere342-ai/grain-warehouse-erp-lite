# Phase 108N — Settings Logo Preview Query Migration Plan

## 1. Phase and canonical scope

```text
PHASE = 108N
SESSION = PLANNING
CANONICAL_SCOPE =
ONE_LOCAL_READ_ONLY_SETTINGS_LOGO_PREVIEW_UI_QUERY_MIGRATION_THROUGH_EXISTING_APPLICATION_BOUNDARY
```

This artifact plans the minimum implementation of that exact frozen scope. It
does not implement the migration and does not reopen candidate selection.

## 2. Governing baseline

```text
GOVERNANCE_RECONCILIATION_COMMIT =
f1f7cb8abd21323f1172074d6088caa905732070

GOVERNANCE_RECONCILIATION_PARENT =
232adb4d29104f54e873a743b023d87f5a49ca29

GOVERNANCE_TAG =
phase-108n-governance-reconciliation-locked

GOVERNANCE_TAG_OBJECT =
c02f308c660b352a53b13118e96ce42dff733655

GOVERNANCE_TAG_PEELED_TARGET =
f1f7cb8abd21323f1172074d6088caa905732070
```

The governing artifact is
`docs/phase-108n/PHASE-108N-SCOPE-DISCOVERY.md`. Its historical
`PHASE_108N_GOVERNANCE_REMOTE_LOCK = NOT_STARTED` marker describes the
pre-lock document state. Local and remote annotated-tag evidence independently
proves that governance remote lock is complete.

## 3. Recovery context

This planning session was recovered after an interrupted reconnaissance and
baseline-verification attempt. Recovery checks found the governance commit
still checked out, the local and remote branch converged, no planning artifact
or planning commit, and no worktree, index, untracked, stash, production, or
test mutation.

```text
RECOVERY_CLASSIFICATION =
CASE_B1_INTERRUPTED_PLANNING_RECONNAISSANCE_ONLY

ENTRY_HEAD =
f1f7cb8abd21323f1172074d6088caa905732070

ENTRY_REMOTE_HEAD =
f1f7cb8abd21323f1172074d6088caa905732070

ENTRY_AHEAD = 0
ENTRY_BEHIND = 0
ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
```

The recovered architectural observations were reverified from live source and
tests. The previously incomplete full-suite result was not reused; a completed
continuation run supplies the baseline in Section 19.

## 4. Current architecture

### 4.1 Settings identity and logo state

`SettingsScreen` in `lib/features/settings/settings_screen.dart` obtains the
root-owned `BusinessIdentityController` from `BusinessIdentityScope`. The
controller exposes the current `BusinessIdentity`, including optional
`LogoMetadata`. The metadata stores a managed filename, MIME type, hash, byte
length, width, and height. Identity metadata is stored locally in
`business_identity.json`; logo bytes are stored separately in the repository's
managed logos directory.

`_LogoSection` reads `identityController.identity.hasLogo` and the current
`LogoMetadata`. When metadata is valid, it builds `_LogoPreview` with the exact
`managedFileName`.

### 4.2 Exact Phase 108N target read

```text
SETTINGS_UI_OWNER =
SettingsScreen / _LogoSection / _LogoPreview
FILE = lib/features/settings/settings_screen.dart

CURRENT_READ_LOCATION =
_LogoPreview._loadLogoBytes (current lines 478-486)

CURRENT_READ_PURPOSE =
render the Settings logo-section preview

CURRENT_READ_SOURCE =
global repository locator followed by managed local filesystem read

CURRENT_PATH =
_LogoPreview.build
  -> FutureBuilder(future: _loadLogoBytes())
  -> AppRepositories.businessIdentityRepository
  -> BusinessIdentityRepository.loadLogoBytes(managedFileName)
  -> LocalBusinessIdentityRepository.loadLogoBytes
  -> managed local logo file
```

The selected file contains exactly one `AppRepositories` reference, and it is
this read. The Settings UI therefore resolves a repository authority directly
instead of consuming the already-composed application query.

### 4.3 Repository behavior

`BusinessIdentityRepository` is the existing domain repository boundary.
`LocalBusinessIdentityRepository.loadLogoBytes`:

- returns null for an empty filename;
- rejects names containing `..`, `/`, or `\\` by returning null;
- resolves only beneath `managedLogosDirectory`;
- returns null when the file does not exist; and
- otherwise returns `File.readAsBytes()`.

It creates no file, performs no write, mutates no cache, touches no SQLite
state, and makes no cloud call.

## 5. Exact target read seam

```text
PHASE_108N_TARGET_LOGO_PREVIEW_READ =
SettingsScreen._LogoPreview._loadLogoBytes
  -> AppRepositories.businessIdentityRepository.loadLogoBytes

MIGRATION_UNIT =
one managed-filename-to-logo-bytes read used by the Settings logo section
```

No other Settings read is part of the migration. The identity metadata read,
theme state, authentication state, profile fields, backup permission, and all
write calls remain on their current paths.

## 6. Already-migrated adjacent shared-header seam

The same Settings screen also renders `BusinessIdentityHeader` in its
"معاينة الهوية" card. That shared widget's private `_IdentityLogo` was already
migrated by Phase 108M:

```text
SHARED_HEADER_LOGO_READ =
BusinessIdentityHeader._IdentityLogo._loadBytes
  -> ApplicationScope.of(context).queries.businessLogo
  -> LoadBusinessLogoQuery

STATUS = ALREADY_MIGRATED_BY_PHASE_108M
PHASE_108N_DISPOSITION = OUT_OF_SCOPE_AND_UNCHANGED
```

A valid-logo Settings widget test consequently observes two logo-query
executions: one from the already-migrated shared header and one from the Phase
108N target preview. Phase 108N must identify the target preview within the
`_LogoSection`/"شعار المنشأة" card and must not claim both reads as its
migration. The target preview's existing `80 x 200` maximum constraints are a
secondary rendering invariant, not the sole ownership discriminator.

## 7. Architectural problem

The target preview imports `app_repositories.dart` and reaches the managed-file
repository directly from presentation code. This bypasses the typed
application query, hides dependency ownership behind global state, and leaves
one Settings presentation-to-infrastructure seam after Phase 108L/108M already
established the exact query and composition path.

The defect is ownership only. The repository, file authority, filename,
result, failure behavior, and rendering semantics are already correct and must
not be redesigned.

## 8. Existing application boundary

```text
EXISTING_APPLICATION_BOUNDARY =
ApplicationQueries.businessLogo
  : LoadBusinessLogoQueryHandler

REQUEST =
LoadBusinessLogoQuery(managedFileName: String)

RESULT =
ApplicationQueryResult<Uint8List?>

APPLICATION_BOUNDARY_STATUS = REUSE_AS_IS
```

The live query is defined in
`lib/application/queries/load_business_logo_query.dart` and exposed by
`ApplicationQueries` in `lib/application/application_boundary.dart`.
`LoadBusinessLogoQueryHandler`:

- returns a null managed-file result without a repository call for an empty
  filename;
- forwards a non-empty filename unchanged to the injected
  `BusinessIdentityRepository` exactly once;
- returns the exact repository `Uint8List?` value;
- reports local / managed-file / current-known-state metadata; and
- propagates repository exceptions for the presentation consumer to handle.

Phase 108L tests already cover request forwarding, exact byte identity, null,
empty filename, metadata, exception identity, no writes, and production
composition. Phase 108N requires no new query, handler, result, repository,
adapter, dependency slot, or application interface.

```text
NEW_APPLICATION_CONTRACT = NONE
NEW_QUERY = NONE
NEW_HANDLER = NONE
NEW_REPOSITORY = NONE
APPLICATION_BOUNDARY_EXTENSION = NONE
```

## 9. Target call path

```text
TARGET_PRESENTATION_PATH =
SettingsScreen
  -> BusinessIdentityScope / BusinessIdentityController supplies LogoMetadata
  -> _LogoSection supplies managedFileName
  -> _LogoPreview performs the read

TARGET_APPLICATION_ENTRYPOINT =
ApplicationScope.of(context).queries.businessLogo

TARGET_CALL_PATH =
SettingsScreen._LogoPreview.build
  -> _loadLogoBytes(context)
  -> ApplicationScope.of(context).queries.businessLogo
  -> LoadBusinessLogoQuery(managedFileName: managedFileName)
  -> LoadBusinessLogoQueryHandler.execute
  -> ApplicationDependencies.repositories.businessIdentityRepository
  -> exact captured BusinessIdentityRepository instance
  -> LocalBusinessIdentityRepository.loadLogoBytes
  -> same managed local logo file
  -> ApplicationQueryResult.value
  -> existing FutureBuilder / Image.memory rendering
```

The implementation changes `future: _loadLogoBytes()` to
`future: _loadLogoBytes(context)`, retains the empty-filename check before the
scope lookup, executes the existing query inside the existing `try`, returns
only `result.value`, and retains the catch-all-to-null behavior.

No new Settings controller is warranted. `_LogoPreview` is the established
presentation seam, matching the Phase 108L Dashboard App Bar and Phase 108M
shared-header pattern of a presentation widget resolving a root-owned typed
query through `ApplicationScope`.

## 10. Runtime ownership

`AppCompositionRoot.initializeProduction` captures
`AppRepositories.businessIdentityRepository` once as
`sharedBusinessIdentityRepository`. It supplies that exact object to both:

- the root-owned `BusinessIdentityController`; and
- `ApplicationDependencies.repositories.businessIdentityRepository` through
  `LegacyApplicationDependencyBridge.captureSharedInstances`.

The composition root constructs `LoadBusinessLogoQueryHandler` from that
captured dependency and places it in the single root-owned
`ApplicationQueries`. `main.dart` installs the resulting
`ApplicationBoundary` above the application in `ApplicationScope`.

```text
RUNTIME_OWNER = AppCompositionRoot.initializeProduction

INTENDED_WIRING =
AppCompositionRoot
  -> ApplicationBoundary.queries.businessLogo
  -> ApplicationScope
  -> SettingsScreen._LogoPreview

REPOSITORY_IDENTITY = SAME_EXISTING_INSTANCE
DUPLICATE_DEPENDENCY = FORBIDDEN
SCREEN_LOCAL_INFRASTRUCTURE = FORBIDDEN
```

Neither Settings nor a controller may instantiate or dispose a repository,
database, filesystem service, query handler, or application boundary.

## 11. Behavior-preservation contract

The implementation must preserve all current externally observable behavior:

1. `BusinessIdentity.hasLogo` remains the gate for constructing `_LogoPreview`.
   Absent or invalid metadata builds no target preview and performs no target
   read.
2. The exact `LogoMetadata.managedFileName` is forwarded without trimming,
   normalization, transformation, or business-context decoration.
3. The existing empty-filename short circuit remains before application-scope
   lookup and returns null. Although `hasLogo` normally prevents this state
   from rendering, the private loader remains defensive.
4. Missing files, rejected path-like names, and repository null remain a
   silent null preview.
5. Repository/query exceptions remain caught by `_LogoPreview` and converted
   to null. No error message, retry, log, or placeholder is introduced.
6. While the future is incomplete, the preview remains
   `SizedBox.shrink`; no loading indicator or loading state is added.
7. Successful bytes reach `Image.memory` unchanged, including the same byte
   object where observable.
8. The preview remains constrained to maximum height 80 and maximum width 200
   with `BoxFit.contain`.
9. Empty/corrupt/undecodable bytes continue through `Image.memory`; its
   existing `errorBuilder` silently returns `SizedBox.shrink`.
10. `_LogoPreview` remains stateless. `FutureBuilder` continues to receive a
    newly created future when the widget rebuilds; no cache, memoization,
    post-frame callback, or lifecycle state is added.
11. `BusinessIdentityController` remains the editable/persisted identity state
    owner. Its notifications continue to rebuild Settings after successful
    logo selection/replacement or removal, so the preview follows the current
    metadata exactly as before.
12. The already-migrated shared header remains independently rendered and
    independently queries through the same existing boundary.
13. The source remains local managed-file authority with
    `QueryResultSource.local`, `LocalReadAuthority.managedFile`, and
    `LocalQueryConsistency.currentKnownState`.
14. No tenant, store, warehouse, business-membership, session, database, or
    cloud context participates in this lookup today; none may be invented.
15. No logo/identity write is executed by the read path.

## 12. Exact production file impact

```text
EXPECTED_MODIFY =
lib/features/settings/settings_screen.dart

EXPECTED_ADD = NONE

POSSIBLE_MODIFY_IF_VERIFIED_NECESSARY = NONE
```

The one expected production edit is limited to:

- replace the `app_repositories.dart` import with the existing
  `load_business_logo_query.dart` and `application_scope.dart` imports;
- pass `BuildContext` from `_LogoPreview.build` to its private loader; and
- replace the one locator repository call with execution of
  `ApplicationQueries.businessLogo`, returning `result.value`.

The following existing production files are specifically confirmed unchanged:

```text
lib/application/application_boundary.dart
lib/application/application_dependencies.dart
lib/application/queries/application_query.dart
lib/application/queries/load_business_logo_query.dart
lib/composition/app_composition_root.dart
lib/composition/application_scope.dart
lib/composition/legacy_application_dependency_bridge.dart
lib/core/business_identity/business_identity.dart
lib/core/business_identity/business_identity_controller.dart
lib/core/business_identity/business_identity_repository.dart
lib/shared/widgets/business_identity_header.dart
lib/features/prints/printable_document_scaffold.dart
lib/app/app_repositories.dart
lib/main.dart
```

Any required production path beyond
`lib/features/settings/settings_screen.dart` is a scope-review stop condition.

## 13. Exact test file impact

### 13.1 New focused Phase 108N suite

```text
TEST_FILE =
test/phase108n_settings_logo_preview_query_migration_test.dart

TEST_LEVEL = widget + static architecture guard

EXPECTED_CHANGE = ADD
```

The suite must prove:

- a valid Settings identity uses the injected existing application query,
  forwards the exact managed filename, and renders the target image inside the
  `_LogoSection`/"شعار المنشأة" card with unchanged bytes, 80 x 200 maximum
  constraints, and `BoxFit.contain`;
- the harness acknowledges the already-migrated `BusinessIdentityHeader` read:
  with both renderers present, exactly one read belongs to the target preview
  and one to the shared header; Phase 108N does not claim both;
- loading, repository null/missing file, thrown failure, and invalid image bytes
  remain silent without a progress indicator or visible read error;
- absent/invalid logo metadata builds neither logo renderer, performs no read,
  and preserves the existing no-`ApplicationScope` Settings harness behavior;
- every read-only preview case records zero `saveIdentity`, `saveLogoBytes`, and
  `deleteLogoFile` calls;
- the `_LogoPreview` source uses `ApplicationScope.of(context).queries.businessLogo`
  and `LoadBusinessLogoQuery`, returns `result.value`, contains the empty-name
  check before scope lookup, and contains no `AppRepositories`, direct
  `loadLogoBytes`, handler construction, concrete repository, `dart:io`,
  database, Drift, Supabase, cloud, or write call;
- the rest of Settings retains the existing `BusinessIdentityController` logo
  select/save/remove and profile write calls without moving them into an
  application query or command; and
- the live locator inventory changes exactly from 38 files / 144 references to
  37 files / 143 references, all-lib references from 160 to 159, and
  feature/shared `ApplicationScope.of` consumers from 6 to 7, with Settings
  leaving the locator set and joining the scope-consumer set.

Source-text assertions are justified because Phase 108I/L/M already establish
this repository convention for narrowly scoped architecture ownership guards.
They must inspect the `_LogoPreview` region where appropriate rather than
forbidding legitimate Settings writes elsewhere in the file.

### 13.2 Existing live locator inventory guard

```text
TEST_FILE =
test/phase108i_second_read_only_ui_query_migration_test.dart

TEST_LEVEL = static architecture regression

CURRENT_EXPECTATION =
144 feature/shared locator references; 38 locator files;
6 ApplicationScope consumers; 160 all-lib references

EXPECTED_NEW_ASSERTION =
143 feature/shared locator references; 37 locator files;
7 ApplicationScope consumers; 159 all-lib references

WHY_REQUIRED =
the guard intentionally measures the live working-tree ownership inventory
```

No Phase 108I document-history behavior assertion is changed.

### 13.3 Existing logo-read file inventory guard

```text
TEST_FILE =
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart

TEST_LEVEL = static architecture regression

CURRENT_EXPECTATION =
_logoReadFiles includes lib/features/settings/settings_screen.dart

EXPECTED_NEW_ASSERTION =
remove only lib/features/settings/settings_screen.dart from _logoReadFiles;
retain printable, export, financial-report, repository, backup, and application
handler paths

WHY_REQUIRED =
the target UI will no longer call loadLogoBytes directly
```

No Phase 108L handler, Dashboard App Bar, metadata, composition, or query-count
assertion is changed.

### 13.4 Existing Phase 108M live inventory guard

```text
TEST_FILE =
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart

TEST_LEVEL = static architecture regression

CURRENT_EXPECTATION =
144 feature/shared locator references; 38 locator files;
6 ApplicationScope consumers; 160 all-lib references

EXPECTED_NEW_ASSERTION =
143 feature/shared locator references; 37 locator files;
7 ApplicationScope consumers; 159 all-lib references;
Settings is absent from locator files and present among scope consumers

WHY_REQUIRED =
the Phase 108M guard deliberately tracks the live monotonic migration inventory
```

No shared-header behavior or Phase 108M ownership assertion is weakened.

### 13.5 Confirmed unchanged tests

`test/phase13_backup_export_test.dart` remains unchanged: its Settings harness
has no valid logo and therefore does not construct either logo renderer or
require `ApplicationScope`. `test/phase96_in_app_business_identity_app_shell_branding_test.dart`
remains unchanged because the shared-header seam is already migrated and is not
Phase 108N's target. Phase 68/95 logo persistence/profile tests remain
unchanged.

```text
EXPECTED_TEST_ADD =
test/phase108n_settings_logo_preview_query_migration_test.dart

EXPECTED_TEST_MODIFY =
test/phase108i_second_read_only_ui_query_migration_test.dart
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart

POSSIBLE_TEST_MODIFY_IF_VERIFIED_NECESSARY = NONE
```

## 14. Minimal implementation sequence

1. Reverify the implementation session starts from the remotely locked Phase
   108N planning baseline with a clean repository.
2. Characterize the focused Settings/logo and Phase 108I/L/M guards before
   editing; do not repair unrelated failures.
3. In `settings_screen.dart`, replace only the target locator import/read with
   the existing query and `ApplicationScope` imports/call.
4. Pass the current build context into `_loadLogoBytes`, preserve the
   empty-name check before scope resolution, execute
   `LoadBusinessLogoQuery(managedFileName: managedFileName)` inside the current
   `try`, and return only `result.value`.
5. Leave `_LogoSection`, `BusinessIdentityController`, all writes, the shared
   header, query/handler, repository, composition, and rendering code otherwise
   unchanged.
6. Add the focused Phase 108N suite with semantic target isolation through the
   Settings logo-section card and secondary layout assertions.
7. Update only the four intentional live expectations across the Phase 108I,
   108L, and 108M guards: locator references, locator files, scope consumers,
   all-lib references, and the Settings direct-logo-read file entry.
8. Run the focused Phase 108N suite, Phase 108I/L/M suites, and Phase 13/68/95/96
   regressions.
9. Run the non-writing formatter, analyzer, full test suite, and diff checks.
10. Inspect the implementation diff against the one-production-file/four-test-file
    allowlist; create one local implementation commit only under a separately
    authorized implementation session.

## 15. Negative scope

```text
NO Settings redesign
NO shared-header re-migration
NO second logo-query migration
NO migration of any other Settings query
NO logo picker redesign
NO logo upload/select flow change
NO logo save-path change
NO logo deletion behavior change
NO establishment-name save change
NO business-profile editing change
NO preferences write change
NO database write or cloud write
NO write-path migration
NO command architecture
NO opportunistic write separation
NO image processing
NO image compression
NO image resizing
NO image format conversion
NO filesystem or managed-file migration
NO persistence-format change
NO schema change
NO SQLite schema or migration change
NO Supabase change
NO cloud synchronization change
NO authentication change
NO session/business-context redesign
NO caching or FutureBuilder lifecycle redesign
NO repository contract or adapter change
NO new application query, handler, service, or parallel architecture
NO composition-root or broad dependency-injection rewrite
NO repository-wide Settings refactor
NO repository-wide AppRepositories cleanup
NO printable-document or export branding migration
NO unrelated read-query migration
NO visual styling or fallback change
NO route or navigation change
NO localization expansion
NO Android, Windows, or other platform-specific work
NO dependency or pubspec change
NO generated-file change
NO CI, script, or tooling change
NO unrelated cleanup or dead-code removal
NO API rename for aesthetics
NO test-suite modernization
NO history rewrite
NO implementation during planning
```

## 16. Non-goals around write paths

All writes remain untouched, even though they coexist in
`settings_screen.dart` and `BusinessIdentityController`:

```text
select/change logo = UNCHANGED
validate picked image = UNCHANGED
BusinessIdentityController.saveLogo = UNCHANGED
BusinessIdentityRepository.saveLogoBytes = UNCHANGED
BusinessIdentityRepository.saveIdentity = UNCHANGED
BusinessIdentityController.removeLogo = UNCHANGED
BusinessIdentityRepository.deleteLogoFile = UNCHANGED
save establishment name/profile = UNCHANGED
backup/export administration = UNCHANGED
database/cloud/sync writes = NONE_ADDED
```

Implementation may alter only the read-resolution code needed to compile the
one migration. It must not opportunistically separate or migrate writes.

## 17. Risks and controls

| Risk | Control / implementation gate |
|---|---|
| The shared-header read is falsely counted as Phase 108N | Isolate the target inside the Settings logo-section card; explicitly expect the existing shared-header query independently. |
| Duplicate repository or handler ownership | Resolve only `ApplicationScope.of(context).queries.businessLogo`; forbid handler/repository construction in Settings. |
| Empty-name behavior changes because scope is resolved first | Retain the empty-filename return before `ApplicationScope.of(context)` and guard source ordering. |
| Missing/path-invalid file semantics drift | Reuse the exact handler and repository unchanged; test null/missing behavior. |
| Query exception becomes visible | Retain the target widget's catch-all-to-null and silent UI regression. |
| Invalid bytes cause a visible framework error | Preserve `Image.memory` and its existing `errorBuilder`; cover invalid bytes. |
| Preview layout or fallback changes | Assert semantic logo-section descendant plus existing 80 x 200 constraints and `BoxFit.contain`. |
| Preview becomes stale after logo change | Keep the stateless `FutureBuilder` and controller-driven rebuild path; add no cache/state. |
| An old async completion is given new lifecycle semantics | Do not add state, mounted handling, cancellation, or result caching; retain current `FutureBuilder` behavior. |
| A no-logo test/harness starts requiring ApplicationScope | Retain `hasLogo` and empty-name gating; preserve Phase 13 regression without scope. |
| Settings writes are accidentally migrated | Static target-region guard plus zero-write spies; retain explicit existing controller write calls and regressions. |
| Live architecture guards are broadly rebased | Change only the mathematically required `144/38/6/160 -> 143/37/7/159` values and one logo-read file entry. |
| Another Settings or logo consumer migrates | Exact production allowlist, direct-read inventory, and diff review. |
| Tenant/cloud semantics are invented | Query input remains only `managedFileName`; no session, business context, Supabase, or database dependency. |

## 18. Acceptance criteria

```text
AC1:
Exactly one Settings logo-preview local read is migrated: the read in
SettingsScreen._LogoPreview._loadLogoBytes.

AC2:
The already-migrated BusinessIdentityHeader._IdentityLogo read remains outside
Phase 108N and unchanged.

AC3:
The target read flows through the existing
ApplicationQueries.businessLogo / LoadBusinessLogoQueryHandler boundary with
APPLICATION_BOUNDARY_STATUS = REUSE_AS_IS.

AC4:
settings_screen.dart no longer imports app_repositories.dart or performs the
targeted direct repository/loadLogoBytes call.

AC5:
No logo, identity, profile, preferences, database, cloud, or sync write path is
migrated or behaviorally changed.

AC6:
No persistence format, schema, SQLite migration, Supabase, cloud, dependency,
generated, platform, route, or navigation change occurs.

AC7:
Managed filename forwarding, byte identity, null/missing/path-invalid behavior,
silent exception/loading/invalid-image fallback, 80 x 200 constraints,
BoxFit.contain, and controller-driven refresh semantics remain unchanged.

AC8:
AppCompositionRoot remains the sole runtime owner; the exact captured
BusinessIdentityRepository and existing root-owned query are reused with no
screen-local or duplicate dependency.

AC9:
The production diff contains exactly
lib/features/settings/settings_screen.dart and no added production file.

AC10:
The focused Phase 108N suite identifies the target inside the Settings
logo-section card and separately accounts for the already-migrated shared
header instead of claiming both reads.

AC11:
Only the exact Phase 108I/L/M live architecture expectations listed in Section
13 are updated, without weakening prior behavior, handler, composition, or
historical assertions.

AC12:
Focused regressions, formatter verification, analyzer, full Flutter test suite,
and diff checks pass, or a failure is proven pre-existing and reported without
an out-of-scope repair.

AC13:
No other Settings query, printable/export logo read, shared widget, or UI
consumer is migrated.

AC14:
The Phase 108N implementation introduces no new application architecture
parallel to the existing boundary.

AC15:
The direct locator inventory changes exactly from 38 files / 144 references to
37 files / 143 references; all-lib references become 159 and feature/shared
ApplicationScope consumers become 7.

AC16:
No implementation occurs in this planning session; its commit contains only
docs/phase-108n/PHASE-108N-PLAN.md.
```

## 19. Planning quality baseline

The repository-supported commands are `flutter analyze` and `flutter test`;
governed Phase 108 plans also use a non-writing Dart formatter and focused
phase regressions.

Completed planning baseline:

```text
BASELINE_FOCUSED_COMMAND =
flutter test
  test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
  test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
  test/phase96_in_app_business_identity_app_shell_branding_test.dart
  test/phase68_business_logo_invoice_windows_icon_test.dart
  test/phase13_backup_export_test.dart

BASELINE_FOCUSED_STATUS = PASS
BASELINE_FOCUSED_TOTAL = 80
BASELINE_FOCUSED_FAILURES = 0

BASELINE_ANALYZE_COMMAND = flutter analyze
BASELINE_ANALYZE_STATUS = PASS — No issues found

BASELINE_FORMAT_COMMAND =
C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe format
  --output=none --set-exit-if-changed lib test

BASELINE_FORMAT_STATUS = PASS
BASELINE_FORMAT_FILES = 460
BASELINE_FORMAT_CHANGED = 0

BASELINE_FULL_TEST_COMMAND = flutter test
BASELINE_FULL_TEST_STATUS = PASS
BASELINE_FULL_TEST_TOTAL = 2522
BASELINE_FULL_TEST_FAILURES = 0

BASELINE_DIFF_CHECK = PASS
```

The `dart.bat` wrapper remained silent and was interrupted without changing
tracked files. The Flutter SDK's underlying Dart executable then completed the
same non-writing formatter gate successfully in 5.47 seconds. The full-suite
result above comes from the completed continuation run, not the earlier
interrupted run.

## 20. Future implementation verification matrix

Run in diagnostic order after the separately authorized implementation:

```powershell
flutter test test\phase108n_settings_logo_preview_query_migration_test.dart

flutter test `
  test\phase108i_second_read_only_ui_query_migration_test.dart `
  test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart `
  test\phase108m_shared_business_identity_header_logo_query_migration_test.dart

flutter test `
  test\phase13_backup_export_test.dart `
  test\phase68_business_logo_invoice_windows_icon_test.dart `
  test\phase95_business_profile_expansion_test.dart `
  test\phase96_in_app_business_identity_app_shell_branding_test.dart

& 'C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe' format `
  --output=none --set-exit-if-changed lib test

flutter analyze
flutter test
git diff --check
```

Then inspect exact `git diff --name-status`, the one-production-file/four-test
file allowlist, source inventories, dependency/schema/generated/platform/cloud
paths, worktree/index state, and commit ancestry. A Windows release build is
not proportionate to this local read-resolution migration unless the later
implementation governance explicitly makes it mandatory.

## 21. Implementation stop conditions

Stop rather than broaden Phase 108N if implementation requires any of:

- a production file other than `settings_screen.dart`;
- a new or changed application query, handler, repository contract, adapter,
  dependency bundle, composition root, or controller;
- migration or modification of the shared-header, printable, export, report,
  or any second logo read;
- any write-path, schema, database, Supabase, cloud, dependency, generated,
  platform, navigation, or routing change;
- a cache/state/lifecycle redesign to preserve preview behavior;
- weakening a prior architecture or behavior guard beyond the exact live
  inventory consequences listed here;
- inability to distinguish the Settings logo-section preview from the shared
  header in focused verification;
- behavior evidence contradicting this preservation contract; or
- any unrelated dirty/user work that cannot be safely isolated.

Use a precise `BLOCKED_PHASE_108N_IMPLEMENTATION_<REASON>` result instead of
architectural invention or scope expansion.

## 22. Planning closure declaration

This plan authorizes no production or test mutation. Successful local planning
closure contains this documentation file only. It creates no implementation
tag, planning lock tag, remote ref, deployment, schema change, dependency
change, generated file, or history rewrite.

```text
PHASE_108N_SCOPE_DISCOVERY = COMPLETE
PHASE_108N_GOVERNANCE_RECONCILIATION_LOCAL_CLOSURE = COMPLETE
PHASE_108N_GOVERNANCE_REMOTE_LOCK = COMPLETE
PHASE_108N_PLANNING_LOCAL_CLOSURE = COMPLETE_AFTER_DOCUMENT_ONLY_COMMIT
PHASE_108N_IMPLEMENTATION = NOT_STARTED

NEXT_AUTHORIZED_SESSION = PHASE_108N_PLANNING_REMOTE_LOCK
```
