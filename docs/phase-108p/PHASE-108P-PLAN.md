# Phase 108P — Account-Balance PDF Logo Query Migration Plan

## 1. Phase and lifecycle state

```text
PHASE = 108P
SESSION = PLANNING
MODE = DOCUMENTATION_ONLY

PHASE_108P_SCOPE_DISCOVERY = COMPLETE
PHASE_108P_GOVERNANCE_RECONCILIATION_REMOTE_LOCK = COMPLETE
PHASE_108P_PLANNING_LOCAL_CLOSURE = COMPLETE_AFTER_LOCAL_COMMIT
PHASE_108P_PLANNING_REMOTE_LOCK = NOT_STARTED
PHASE_108P_IMPLEMENTATION = NOT_STARTED
```

This artifact makes the locked Phase 108P scope implementation-ready. It does
not modify production or test code and does not authorize implementation.

## 2. Governing baseline

The planning entry gate was freshly fetched and independently verified:

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git

ENTRY_LOCAL_HEAD = 4ea5837994331093048294df50f757521b6fdf94
ENTRY_REMOTE_HEAD = 4ea5837994331093048294df50f757521b6fdf94
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0
ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
RECOVERY_CLASSIFICATION = CASE_A_FRESH_PLANNING
```

No Phase 108P planning artifact, local planning commit, local planning tag, or
remote planning tag existed at entry.

The authoritative governance lock is:

```text
PHASE_108P_GOVERNANCE_COMMIT =
4ea5837994331093048294df50f757521b6fdf94

PHASE_108P_GOVERNANCE_PARENT =
f7c214186e0624bb290aa0ff55413bf4773f4767

PHASE_108P_GOVERNANCE_TAG =
phase-108p-governance-reconciliation-locked

PHASE_108P_GOVERNANCE_TAG_TYPE = tag
PHASE_108P_GOVERNANCE_TAG_OBJECT =
c292c8b7bf0cca72caf1846e0534e2bf4c2d5e34

PHASE_108P_GOVERNANCE_TAG_PEELED_COMMIT =
4ea5837994331093048294df50f757521b6fdf94

LOCAL_REMOTE_TAG_OBJECT = MATCH
LOCAL_REMOTE_PEELED_COMMIT = MATCH
```

The governance commit subject is
`Phase 108P: reconcile governance and canonical scope`, and its only changed
path is
`docs/phase-108p/PHASE-108P-GOVERNANCE-RECONCILIATION.md`.

## 3. Governing lineage

Git parent inspection proves this uninterrupted direct-parent chain:

```text
f1f7cb8abd21323f1172074d6088caa905732070  Phase 108N governance
→ cdef1249c9b50181b87bb01412e793528b6819f2  Phase 108N planning
→ e8e27d4ef4ab960e6bdb53bd19f1e27907587d6e  Phase 108N implementation
→ e248e4beb711950cb1e179a5986347d3db7d4bab  Phase 108O governance
→ bfecc1e280c7f93e104e7a4abc7109f0f27a2f4b  Phase 108O planning
→ f7c214186e0624bb290aa0ff55413bf4773f4767  Phase 108O implementation
→ 4ea5837994331093048294df50f757521b6fdf94  Phase 108P governance
```

Phase 108P governance therefore directly descends from the locked Phase 108O
implementation without history rewriting or an intervening commit.

## 4. Governance disposition and canonical scope

```text
HISTORICAL_108P_DISPOSITION = REJECT_AS_STALE
ARCHITECTURE_CLASSIFICATION = READ_ONLY
```

The canonical scope is exactly:

> Migrate only the account-balance report PDF export's direct managed-logo
> byte read through the existing business-logo application query, preserving
> the surrounding identity read and all export behavior.

The historical shared-PDF-renderer Phase 108P meaning remains preserved as
non-governing evidence. It is not reopened, renamed, or partially implemented
by this plan.

## 5. Current-state evidence

### 5.1 Export entry point and direct read

```text
ACCOUNT_BALANCE_EXPORT_FILE =
lib/features/financial_reports/account_balance_report_screen.dart

ACCOUNT_BALANCE_EXPORT_OWNER = AccountBalanceReportScreen
ACCOUNT_BALANCE_EXPORT_STATE = _AccountBalanceReportScreenState
ACCOUNT_BALANCE_EXPORT_SYMBOL =
_AccountBalanceReportScreenState._exportPdf

CURRENT_DIRECT_MANAGED_LOGO_READ =
AppRepositories.businessIdentityRepository.loadLogoBytes(
  identity.logo!.managedFileName,
)
```

`_exportPdf` first returns when `_report == null`. Otherwise its current order
is identity load, conditional logo-byte load, account-balance PDF build, and
success snackbar. One surrounding `try/catch` converts any identity, logo,
PDF-build, or file-write failure to the existing Arabic failure snackbar.

### 5.2 Surrounding identity read

```text
SURROUNDING_IDENTITY_READ =
AppRepositories.businessIdentityRepository.loadIdentity()

DISPOSITION = PRESERVE_EXACTLY
```

This identity read is deliberately outside Phase 108P. The continued use of
`AppRepositories` by this read, the financial report service, and account
loading is neither a contradiction nor an invitation to widen the migration.

### 5.3 Logo flow into PDF generation

```text
identity.hasLogo && identity.logo != null
  → managed filename
  → Uint8List? logoBytes
  → FinancialReportPdfBuilder.buildAccountBalanceReport(
      report: _report!,
      businessIdentity: identity,
      logoBytes: logoBytes,
    )
  → FinancialReportPdfBuilder._brandingHeader
  → PdfBrandingHeader.build
```

`FinancialReportPdfBuilder.buildAccountBalanceReport` remains the PDF owner.
It initializes the established Amiri fonts, creates the existing A4 RTL
multi-page document, uses the same branding header, report rows and totals,
writes beneath the established `Exports` directory, and returns the same
`File`. None of those steps is a Phase 108P edit.

## 6. Current behavior and fallback semantics

The live source establishes these effective semantics:

1. `_report == null` returns before identity, logo, or export work.
2. Identity is loaded first through the existing locator repository.
3. `BusinessIdentity.hasLogo` requires non-null, valid `LogoMetadata`.
4. Valid metadata requires a non-empty managed filename, MIME type and hash,
   plus a positive byte length.
5. No logo read occurs for absent or invalid metadata.
6. The exact managed filename is forwarded without normalization.
7. `LocalBusinessIdentityRepository.loadLogoBytes` returns null for an empty
   filename, path-like/traversal filename, or missing file.
8. Existing files return their exact `Uint8List` bytes, including an empty
   byte list if such a file exists.
9. `Uint8List?` is passed unchanged to the PDF branding path; null preserves
   the builder's unbranded/fallback behavior.
10. A thrown logo read is caught by `_exportPdf`'s existing catch and shows
    `تعذر إنشاء ملف PDF.` when the state remains mounted.
11. A successful build uses `_showExportResult`, preserving its path text,
    green background, and five-second duration.

## 7. Existing application-query path

The exact reusable path exists in current production source:

```text
ApplicationScope
→ ApplicationBoundary.queries
→ ApplicationQueries.businessLogo
→ LoadBusinessLogoQueryHandler.execute
→ BusinessIdentityRepository.loadLogoBytes
```

Exact symbols and paths:

```text
APPLICATION_SCOPE = ApplicationScope
APPLICATION_SCOPE_FILE = lib/composition/application_scope.dart
APPLICATION_SCOPE_ACCESS_PATH = ApplicationScope.of(context)

BUSINESS_LOGO_QUERY_FIELD = ApplicationQueries.businessLogo
APPLICATION_BOUNDARY_FILE = lib/application/application_boundary.dart

QUERY_REQUEST = LoadBusinessLogoQuery
QUERY_HANDLER = LoadBusinessLogoQueryHandler
QUERY_FILE = lib/application/queries/load_business_logo_query.dart

TARGET_REPOSITORY_METHOD = BusinessIdentityRepository.loadLogoBytes
REPOSITORY_FILE =
lib/core/business_identity/business_identity_repository.dart
```

For a non-empty filename, the handler forwards the exact string once and
returns the exact repository `Uint8List?` in an `ApplicationQueryResult` with
local managed-file metadata. For an empty filename, it returns null without a
repository call. Repository exceptions propagate unchanged. It performs no
write, fallback fetch, cache mutation, database operation, or network access.

```text
EXISTING_QUERY_CAN_REUSE = YES
NEW_QUERY_REQUIRED = NO
NEW_HANDLER_REQUIRED = NO
NEW_REPOSITORY_CONTRACT_REQUIRED = NO
APPLICATION_BOUNDARY_CHANGE_REQUIRED = NO
```

## 8. Runtime composition availability

`AppCompositionRoot.initializeProduction` captures
`AppRepositories.businessIdentityRepository` once as
`sharedBusinessIdentityRepository`. The same object is supplied to the
root-owned `BusinessIdentityController` and to
`ApplicationDependencies.repositories.businessIdentityRepository`.

The root creates `LoadBusinessLogoQueryHandler` from that captured repository,
places it in `ApplicationQueries.businessLogo`, and returns the one
`ApplicationBoundary`. `main.dart` installs that boundary in
`ApplicationScope` above `TrialAppGate` and `GrainWarehouseApp`, so the
account-balance route can resolve the existing query from its current
`BuildContext`.

```text
RUNTIME_QUERY_AVAILABLE_AT_EXPORT_CALL_SITE = YES
ULTIMATE_REPOSITORY_INSTANCE = SAME_EXISTING_CAPTURED_INSTANCE
RUNTIME_COMPOSITION_CHANGE = NONE
```

If the implementation baseline no longer provides this exact scope at the
route, implementation must stop for governance review rather than add a new
provider, locator, callback, or handler.

## 9. Architectural boundary

The current direct read bypasses application ownership because presentation
code resolves the repository locator and invokes managed storage directly.
The defect is dependency ownership only. The repository behavior, filename,
bytes, identity, PDF builder, storage authority, and visual/export behavior
are already correct.

Phase 108P changes one edge:

```text
CURRENT:
_exportPdf
→ AppRepositories.businessIdentityRepository.loadLogoBytes

TARGET:
_exportPdf
→ ApplicationScope.of(context).queries.businessLogo.execute(
    LoadBusinessLogoQuery(
      managedFileName: identity.logo!.managedFileName,
    ),
  )
→ ApplicationQueryResult.value
```

No parallel logo loader or new abstraction is permitted.

## 10. Proposed minimal migration

The later implementation must modify only the selected block in `_exportPdf`:

1. Retain the `_report == null` early return.
2. Retain the existing outer `try/catch`.
3. Retain the identity locator call, its position before the logo operation,
   and its returned object.
4. Retain the exact `identity.hasLogo && identity.logo != null` gate.
5. Inside that gate, resolve the existing
   `ApplicationScope.of(context).queries.businessLogo` handler.
6. Execute `LoadBusinessLogoQuery` with the unchanged
   `identity.logo!.managedFileName`.
7. Assign only `ApplicationQueryResult.value` to the existing `logoBytes`
   variable.
8. Leave the builder call, result handling, catch, CSV export, and all other
   screen behavior unchanged.

The file keeps its existing `app_repositories.dart` import because the
financial-account and identity reads remain locator-owned. It adds only the
existing query-request and application-scope imports. `dart:typed_data`
remains required by `Uint8List? logoBytes`.

The scope lookup stays within the valid-logo branch so absent/invalid metadata
continues to perform no application lookup and no logo read. It remains within
the existing `try` so a query or scope failure cannot escape the established
PDF failure behavior. No catch, fallback, or normalization is added.

## 11. Explicit in-scope items

```text
IN_SCOPE =
- one direct managed-logo byte read
- _AccountBalanceReportScreenState._exportPdf only
- reuse LoadBusinessLogoQuery
- reuse ApplicationQueries.businessLogo
- consume ApplicationQueryResult.value
- imports strictly necessary for that call
- focused tests and exact live architecture guard updates
```

## 12. Explicit out-of-scope items

```text
OUT_OF_SCOPE =
- AppRepositories.businessIdentityRepository.loadIdentity migration
- financial account repository reads or FinancialReportService ownership
- account-balance computation, rows, totals, filters, search, and sorting
- CSV export
- other financial-report screens or report logo reads
- printable views and other PDF exports
- PdfExportService and backup export logo reads
- PDF builder, branding header, layout, typography, filenames, or directories
- identity/profile persistence and all logo writes/deletes
- ApplicationBoundary, ApplicationQueries, handler, repository, or composition changes
- new service, facade, use case, provider, callback, or persistence API
- database, schema, migration, Supabase, networking, or cloud work
- dependency, platform, generated, build, CI, or runtime configuration changes
- broad architecture counters, refactors, cleanup, moves, or renames
```

```text
OUT_OF_SCOPE_OBSERVATION =
Other financial-report screens, pdf_export_service.dart, backup_export.dart,
and the repository implementation still contain direct loadLogoBytes calls.
They remain unchanged and deferred; their proximity does not expand Phase 108P.
```

## 13. Behavioral invariants

### 13.1 Identity preservation

- `loadIdentity()` remains the first asynchronous dependency read.
- It remains exactly
  `AppRepositories.businessIdentityRepository.loadIdentity()`.
- The exact returned `BusinessIdentity` reaches the existing logo gate and
  PDF builder.
- No identity write, controller migration, or identity fallback is added.

### 13.2 Report preservation

- Account selection and `FinancialReportService.accountBalanceReport` are
  unchanged.
- The exact `_report!` object reaches the PDF builder.
- Rows, opening balances, inflows, outflows, net movement, closing balances,
  totals, dates, labels, filters, search, sorting, and account status are
  unchanged.
- CSV behavior and report-screen permission behavior are unchanged.

### 13.3 Logo preservation

- Absent or invalid metadata performs no logo query or repository read.
- Present valid metadata invokes the existing query exactly once with the
  exact managed filename.
- Present bytes preserve exact byte identity through `result.value` to the
  builder argument.
- Repository null remains null and preserves the current unbranded PDF path.
- Missing or rejected managed files retain repository-null behavior.
- Empty returned bytes are not normalized to null.
- Query/repository exceptions remain handled by the existing export catch.
- No new fallback, placeholder, remote retrieval, cache, or write is added.

### 13.4 PDF and export preservation

- `FinancialReportPdfBuilder.buildAccountBalanceReport` is unchanged.
- A4 page structure, RTL direction, Amiri fonts, branding, title, table,
  totals, spacing, and profile fields are unchanged.
- Filename, `Exports` directory, file creation/write, returned `File`, and
  save behavior are unchanged.
- Success and failure snackbar text, colors, path display, mount guards, and
  five-second success duration are unchanged.
- Printing behavior is unaffected; this call site performs no print migration.

## 14. File-level implementation forecast

### EXPECTED_MODIFY

```text
lib/features/financial_reports/account_balance_report_screen.dart
  SYMBOL = _AccountBalanceReportScreenState._exportPdf
  CHANGE = replace only the conditional direct logo-byte repository call with
           the existing business-logo application query and result.value
```

### EXPECTED_TEST_ADD

```text
test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart
```

### EXPECTED_TEST_MODIFY

```text
test/phase108i_second_read_only_ui_query_migration_test.dart
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
test/phase108n_settings_logo_preview_query_migration_test.dart
test/phase108o_printable_document_scaffold_logo_query_migration_test.dart
```

The Phase 108I/M/N/O files intentionally assert live locator/scope inventory;
their numeric expectations require the exact Phase 108P delta. Phase 108L and
Phase 108O intentionally assert the complete direct-logo-read file set; only
the account-balance screen entry is removed. No earlier behavioral assertion
may be weakened.

### INSPECT_ONLY

```text
lib/application/application_boundary.dart
lib/application/application_dependencies.dart
lib/application/queries/application_query.dart
lib/application/queries/load_business_logo_query.dart
lib/composition/app_composition_root.dart
lib/composition/application_scope.dart
lib/composition/legacy_application_dependency_bridge.dart
lib/core/business_identity/business_identity.dart
lib/core/business_identity/business_identity_repository.dart
lib/features/exports/financial_report_pdf_builder.dart
lib/features/exports/pdf_branding_header.dart
lib/main.dart
test/phase42_pdf_export_foundation_test.dart
test/phase68_business_logo_invoice_windows_icon_test.dart
test/phase79_account_based_financial_reports_test.dart
```

### NOT_AUTHORIZED

Every other production, test, integration, dependency, database, Supabase,
platform, generated, CI/build, and runtime-configuration path is not
authorized. Any required production file beyond the one `EXPECTED_MODIFY`
path is a stop-and-governance-review condition.

## 15. Expected architecture inventory delta

Current live inventory is:

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 142
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 158
FEATURE_SHARED_APPLICATION_SCOPE_CONSUMERS = 8
```

The target file contains four `AppRepositories.` references: financial report
service construction, account loading, identity loading, and logo-byte
loading. Only the last is removed. Therefore the exact governed result is:

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 141
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 157
FEATURE_SHARED_APPLICATION_SCOPE_CONSUMERS = 9

ACCOUNT_BALANCE_SCREEN_REMAINS_LOCATOR_FILE = YES
ACCOUNT_BALANCE_SCREEN_BECOMES_SCOPE_CONSUMER = YES
DIRECT_LOGO_READ_FILE_REMOVALS =
lib/features/financial_reports/account_balance_report_screen.dart ONLY
```

Changing any unrelated reference to manufacture these counts is forbidden.

## 16. Test strategy

```text
EXISTING_TEST_MODIFICATION_REQUIRED = YES
NEW_TEST_REQUIRED = YES
NO_TEST_FILE_CHANGE_REQUIRED = NO
```

### 16.1 New focused Phase 108P suite

`test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart`
must combine the narrowest runtime seam checks with a source ownership guard:

1. A widget harness supplies a valid identity through the unchanged locator
   identity repository and a distinct spy-backed
   `LoadBusinessLogoQueryHandler` through `ApplicationScope`.
2. Triggering the enabled account-balance PDF action proves identity is loaded
   through the locator, the locator repository's direct logo method is not
   used, and the query repository receives the exact managed filename once.
3. Present bytes are returned unchanged by the query. The source guard proves
   `result.value` is assigned to `logoBytes` and that the same variable reaches
   `buildAccountBalanceReport` with the unchanged report and identity.
4. Absent/invalid logo metadata proves zero application-query/repository logo
   reads while the identity read remains unchanged.
5. A query/repository failure proves the existing
   `تعذر إنشاء ملف PDF.` failure snackbar remains the consumer behavior and no
   business-identity write occurs.
6. Source-region assertions isolate `_exportPdf` and prove the exact query
   request, valid-logo gate, call ordering, result consumption, unchanged
   builder arguments, unchanged catch/success handling, and absence of direct
   `.loadLogoBytes(` only in the target method.
7. The suite must not forbid legitimate `AppRepositories` uses elsewhere in
   the screen or migrate the surrounding identity read.
8. Architecture assertions prove the exact `141 / 36 / 157 / 9` inventory and
   remove only this screen from the direct-logo-read set.

The harness may let PDF generation stop at an intentionally injected logo
failure when testing failure behavior; it must not introduce production
dependency injection solely for test convenience. Any temporary filesystem
used by a successful export test must be test-owned and cleaned by the test.

### 16.2 Existing guard updates

- Phase 108I, 108M, 108N, and 108O live inventory assertions change only from
  `142 / 36 / 158 / 8` to `141 / 36 / 157 / 9` and add the precise membership
  expectation that the account-balance screen belongs to both locator and
  scope-consumer sets.
- Phase 108L and Phase 108O direct-logo-read sets remove only
  `lib/features/financial_reports/account_balance_report_screen.dart`.
- No handler, Dashboard, shared-header, Settings, printable-scaffold, or
  prior-phase behavior assertion is weakened.

### 16.3 Existing regression evidence

- `test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart`
  already proves empty-name short circuit, exact filename forwarding, byte
  identity, null preservation, exception identity, zero writes, and production
  composition of `LoadBusinessLogoQueryHandler`.
- `test/phase68_business_logo_invoice_windows_icon_test.dart` covers managed
  logo storage success, missing files, and rejected path-like filenames.
- `test/phase79_account_based_financial_reports_test.dart` covers account
  balance models, report computation, edge cases, and financial report naming.
- `test/phase42_pdf_export_foundation_test.dart` covers established PDF
  generation and export foundations. It does not directly exercise this
  private account-balance export seam and remains unchanged.

There is no current dedicated account-balance report screen export test. That
gap is why one focused Phase 108P test file is required rather than relying
only on earlier query and report tests.

## 17. Later implementation validation strategy

Run validation in diagnostic order:

```powershell
flutter test test\phase108p_account_balance_report_pdf_logo_query_migration_test.dart

flutter test `
  test\phase108i_second_read_only_ui_query_migration_test.dart `
  test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart `
  test\phase108m_shared_business_identity_header_logo_query_migration_test.dart `
  test\phase108n_settings_logo_preview_query_migration_test.dart `
  test\phase108o_printable_document_scaffold_logo_query_migration_test.dart

flutter test `
  test\phase42_pdf_export_foundation_test.dart `
  test\phase68_business_logo_invoice_windows_icon_test.dart `
  test\phase79_account_based_financial_reports_test.dart

dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
git diff --check
git diff --cached --check
git status --porcelain=v1 --untracked-files=all
```

The implementation session must also inspect the exact diff, direct-read set,
locator/scope counts, and changed-path allowlist. A failure must be explained
and corrected within scope; it may not be masked by weakening an earlier guard.

## 18. Planning-session validation

This session changed Markdown documentation only. It verified repository and
remote identity after a fresh fetch, annotated governance tag identity,
direct-parent lineage, current source, composition, query/repository semantics,
relevant tests, planning convention, diff, changed paths, and Git state.

```text
flutter analyze = NOT_RUN_DOCUMENTATION_ONLY
flutter test = NOT_RUN_DOCUMENTATION_ONLY
```

No production or test result is claimed from this planning session.

## 19. Risks and mitigations

| Risk | Mitigation |
|---|---|
| The nearby identity read is migrated opportunistically | Assert its exact locator expression and order in the focused source guard. |
| `ApplicationScope` is resolved outside the logo gate | Keep lookup inside the existing valid-logo branch and test absent/invalid metadata for zero query calls. |
| Query bytes/null are reinterpreted | Assign only `ApplicationQueryResult.value`; reuse Phase 108L byte-identity/null tests. |
| Query failure escapes or gets a new fallback | Keep execution inside the existing export `try/catch`; assert the existing snackbar. |
| PDF content or save behavior changes | Do not edit the builder/export helpers; assert unchanged builder arguments and run Phase 42/79 regressions. |
| The locator import is removed despite retained reads | Keep `app_repositories.dart`; assert the file remains in the locator set. |
| Live guard counts are broadly rebased | Apply only `142/36/158/8 → 141/36/157/9` and inspect membership. |
| Another direct logo consumer is migrated | Exact changed-path and direct-read-set assertions; stop if any second consumer changes. |
| A testability refactor expands production scope | Use the existing widget boundary, global identity seam, and injected application query in tests; add no production hook. |
| Context/scope availability differs from verified root composition | Stop for governance review instead of adding a provider, callback, service, or alternate path. |

## 20. Rollback and recovery considerations

The later implementation is one presentation call-site migration plus focused
tests and intentional live-guard updates. Before its local commit, recovery is
the preservation or explicit review of those uncommitted paths; no destructive
reset or clean is authorized. After a valid local implementation commit and
before remote lock, recovery is a normal forward commit or a separately
authorized revert, never amend, rebase, force-push, or tag deletion.

The application query, repository, composition, and PDF builder remain
unchanged, so there is no database, schema, storage-format, dependency, or
runtime migration to roll back.

## 21. Implementation sequence

1. Verify the separately remotely locked Phase 108P planning baseline, branch,
   annotated tag, clean worktree/index, empty untracked/stash state, and exact
   planning document blob.
2. Run the focused pre-change query/guard/report baseline without changing it.
3. Reconfirm the target direct read and existing query/composition path remain
   exactly as planned.
4. Modify only `_AccountBalanceReportScreenState._exportPdf` and its necessary
   imports in the one expected production file.
5. Add the focused Phase 108P suite.
6. Update only the exact live inventory and direct-read membership assertions
   in the five expected prior-phase guard files.
7. Run focused seam tests, guard tests, unchanged report/PDF regressions,
   formatter check, analyzer, sequential full suite, and Git/diff gates.
8. Confirm the production diff is one file, no second logo consumer changed,
   and all non-document implementation paths match the forecast.
9. Create one local implementation commit only after every gate passes.
10. Stop before implementation push/tag for a distinct remote-lock session.

## 22. Stop conditions

Stop for governance review if implementation requires any of the following:

```text
- changing loadIdentity or any financial-account/report-data read
- changing ApplicationBoundary, ApplicationQueries, query handler, repository,
  application dependencies, composition root, main.dart, or PDF builder
- adding a service, facade, use case, provider, callback, or repository API
- resolving logo bytes outside the existing application query
- moving ApplicationScope lookup outside the valid-logo branch
- changing null, empty-byte, missing-file, exception, snackbar, or save behavior
- touching a second logo consumer or a second production file
- changing database, Supabase, dependency, platform, generated, CI, or runtime files
- weakening prior behavioral guards or changing unrelated architecture counts
- discovering that ApplicationScope or businessLogo is unavailable at runtime
```

## 23. Completion criteria

Future Phase 108P implementation is complete only when:

```text
1. Only the selected direct logo-byte read uses ApplicationQueries.businessLogo.
2. The surrounding identity read remains exact and first.
3. The existing valid-logo gate and filename remain exact.
4. Query result.value reaches the unchanged PDF builder logoBytes argument.
5. Present, absent, null, empty-byte, missing-file, and error behavior is preserved.
6. Report data, PDF structure/formatting, filename, save, and snackbar behavior is unchanged.
7. No query, handler, repository, composition, persistence, or dependency asset changes.
8. Inventory is exactly 141 references / 36 files / 157 all-lib / 9 scope consumers.
9. Only the account-balance screen leaves the direct-logo-read set.
10. The focused, guard, regression, analyze, format, full-suite, and diff gates pass.
11. Production changes equal one forecasted file and tests equal the forecasted set.
12. No database, Supabase, platform, generated, remote, or history mutation occurs.
```

Any unmet item is not partial completion.

## 24. Next lifecycle step

This planning session may create only the local documentation commit containing
this file. Repository precedent from Phase 108N and Phase 108O creates no local
planning tag during local planning closure; the separate remote-lock session
creates and verifies the annotated planning baseline tag.

```text
CURRENT_SESSION_END_STATE = PHASE_108P_PLANNING_LOCAL_CLOSURE

PHASE_108O_FINAL_CLOSURE = COMPLETE
PHASE_108P_SCOPE_DISCOVERY = COMPLETE
PHASE_108P_GOVERNANCE_RECONCILIATION_REMOTE_LOCK = COMPLETE
PHASE_108P_PLANNING_LOCAL_CLOSURE = COMPLETE_AFTER_LOCAL_COMMIT
PHASE_108P_PLANNING_REMOTE_LOCK = NOT_STARTED
PHASE_108P_IMPLEMENTATION = NOT_STARTED

NEXT_AUTHORIZED_SESSION = PHASE_108P_PLANNING_REMOTE_LOCK
```

Implementation remains unauthorized until the planning commit is independently
verified and remotely locked in that separate session.
