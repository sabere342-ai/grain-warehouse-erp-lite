# Phase 108R — Payment-Method Report PDF Logo Query Migration Plan

## 1. Phase and lifecycle state

```text
SESSION = PHASE_108R_PLANNING
MODE = FORENSIC_PLANNING_DOCUMENTATION_ONLY_LOCAL_CLOSURE

DECISION_OUTCOME = OUTCOME_A_CURRENT_108R_AUTHORIZED
IDENTITY_DECISION = PHASE_108R
PHASE_108R_SCOPE = PAYMENT_METHOD_REPORT_PDF_LOGO_QUERY_MIGRATION
SELECTED_SCOPE =
SINGLE_PAYMENT_METHOD_REPORT_PDF_MANAGED_LOGO_BYTE_READ_MIGRATION

PHASE_108Q_FINAL_CLOSURE = COMPLETE
PHASE_108R_SCOPE_DISCOVERY = COMPLETE
PHASE_108R_GOVERNANCE_RECONCILIATION_LOCAL_CLOSURE = COMPLETE
PHASE_108R_GOVERNANCE_RECONCILIATION_REMOTE_LOCK = COMPLETE
PHASE_108R_PLANNING_LOCAL_CLOSURE = IN_PROGRESS_AT_DOCUMENT_CREATION
PHASE_108R_PLANNING_REMOTE_LOCK = NOT_STARTED
PHASE_108R_IMPLEMENTATION = NOT_STARTED
```

This document makes the already-governed Phase 108R seam implementation-ready.
It does not authorize or perform source, test, runtime, or remote mutation.

## 2. Objective and canonical scope

Phase 108R will migrate one read-only dependency-ownership edge inside:

```text
PRIMARY_PRODUCTION_TARGET =
lib/features/financial_reports/payment_method_report_screen.dart

TARGET_SYMBOL = _PaymentMethodReportScreenState._exportPdf
READ_WRITE_CLASSIFICATION = READ_ONLY
EXPECTED_PRODUCTION_FILE_COUNT = 1
AUTHORIZED_BEHAVIORAL_CHANGE = ONE_DEPENDENCY_OWNERSHIP_EDGE_ONLY
```

The canonical scope is:

```text
MIGRATE_ONLY_THE_DIRECT_MANAGED_LOGO_BYTE_DEPENDENCY_LOOKUP_INSIDE
_PAYMENTMETHODREPORTSCREENSTATE._EXPORTPDF
THROUGH_THE_EXISTING_BUSINESS_LOGO_APPLICATION_QUERY,
WHILE_PRESERVING_THE_LOCATOR_OWNED_BUSINESS_IDENTITY_READ
AND_ALL_SURROUNDING_REPORT_EXPORT_BEHAVIOR
```

The current direct read is:

```dart
AppRepositories.businessIdentityRepository.loadLogoBytes(
  identity.logo!.managedFileName,
)
```

The governed target ownership is:

```dart
final result =
    await ApplicationScope.of(context).queries.businessLogo.execute(
      LoadBusinessLogoQuery(
        managedFileName: identity.logo!.managedFileName,
      ),
    );

logoBytes = result.value;
```

No business behavior, input, output, error contract, or persistence behavior is
authorized to change.

## 3. Governing governance baseline

Planning entry was independently verified after a fresh fetch against:

```text
GOVERNING_GOVERNANCE_COMMIT =
f244082a4939f92fbb3acdbb562c1a7bf826e35b

GOVERNING_GOVERNANCE_COMMIT_SUBJECT =
Phase 108R: reconcile governance and canonical scope

GOVERNING_GOVERNANCE_DIRECT_PARENT =
a7e0ada26680e9745b5c6dc8efe1d24cc1739a83

GOVERNING_GOVERNANCE_TAG =
phase-108r-governance-reconciliation-locked

GOVERNING_GOVERNANCE_TAG_OBJECT =
a5459e7bff140d94f0cd23d53fe5ca89b5b460ea

GOVERNING_GOVERNANCE_TAG_PEELED_COMMIT =
f244082a4939f92fbb3acdbb562c1a7bf826e35b

GOVERNING_GOVERNANCE_TAG_TYPE = tag
GOVERNING_GOVERNANCE_TAG_MESSAGE =
Phase 108R governance reconciliation locked
```

The tag object and peeled commit are identical locally and on `origin`. The
freshly fetched authorized branch also resolves to the governing governance
commit.

The governing artifact is:

```text
GOVERNANCE_ARTIFACT =
docs/phase-108r/PHASE-108R-GOVERNANCE-RECONCILIATION.md

GOVERNANCE_ARTIFACT_BLOB =
136afd838d69264163c5aae7cdecabbfbdd636c4
```

The governance commit adds exactly that one document and no production, test,
configuration, generated, dependency, platform, database, or Supabase path.

## 4. Locked predecessor lineage

The immutable implementation predecessor is:

```text
PHASE_108Q_IMPLEMENTATION_COMMIT =
a7e0ada26680e9745b5c6dc8efe1d24cc1739a83

PHASE_108Q_IMPLEMENTATION_TAG = phase-108q-implementation-locked
PHASE_108Q_IMPLEMENTATION_TAG_OBJECT =
71bc85d6df0bcae7e8f8c761234562b258afc270

PHASE_108Q_IMPLEMENTATION_TAG_PEELED_COMMIT =
a7e0ada26680e9745b5c6dc8efe1d24cc1739a83

TAG_TYPE = tag
ANNOTATED = YES
```

The current Phase 108R governance commit is a direct child of this locked
Phase 108Q implementation commit. Planning must remain a direct child of the
Phase 108R governance commit; implementation must later remain a direct child
of the separately remote-locked Phase 108R planning baseline.

## 5. Current payment-method export behavior

`PaymentMethodReportScreen` is a live stateful report screen. Its current
state and data flow are:

1. `initState` constructs `FinancialReportService` from
   `AppRepositories.financialAccountRepository`.
2. `_loadAccounts` loads the filter account list through the same locator.
3. `_applyFilters` starts immediately and calls
   `FinancialReportService.paymentMethodReport` with the current date,
   payment-method, source-type, account, and direction filters.
4. The service lists accounts, loads entries for included accounts, excludes
   transfer sources, applies filters, groups rows by payment method, and sorts
   rows by descending inflows.
5. `_report` is null during loading or after a report-load failure. The PDF and
   CSV buttons are disabled while it is null.
6. View permission gates the screen and export permission gates both export
   actions.
7. `_exportPdf` returns immediately for a null report, loads the current
   `BusinessIdentity`, conditionally reads logo bytes, builds the existing
   payment-method PDF, and passes its returned file to `_showExportResult`.
8. The existing catch displays the constant Arabic PDF failure snackbar and
   does not expose the caught exception.
9. `_exportCsv` is a separate neighboring method and is unchanged by this
   phase.

The screen is runtime-reachable through:

```text
ApplicationScope in main.dart
→ DashboardShell
→ FinancialReportsScreen
→ PaymentMethodReportScreen
→ _PaymentMethodReportScreenState._exportPdf
```

## 6. Existing business-logo application-query architecture

The complete reusable read path already exists:

```text
ApplicationScope.of(context)
→ ApplicationBoundary.queries
→ ApplicationQueries.businessLogo
→ LoadBusinessLogoQuery
→ LoadBusinessLogoQueryHandler.execute
→ BusinessIdentityRepository.loadLogoBytes
→ ApplicationQueryResult<Uint8List?>.value
```

`LoadBusinessLogoQuery` accepts exactly one `managedFileName`. Its handler is
constructed with `BusinessIdentityRepository`, returns a managed-file
`LocalQueryResultMetadata`, short-circuits an empty query filename to null, and
otherwise forwards the filename unchanged to `loadLogoBytes`. Present bytes,
empty bytes, null, and exceptions are not normalized by the handler.

```text
QUERY_ALREADY_EXISTS = YES
HANDLER_ALREADY_EXISTS = YES
REPOSITORY_PORT_ALREADY_EXISTS = YES
NEW_QUERY_REQUIRED = NO
NEW_HANDLER_REQUIRED = NO
NEW_REPOSITORY_REQUIRED = NO
NEW_QUERY_RESULT_MODEL_REQUIRED = NO
```

## 7. Runtime composition verification

Live composition was verified as follows:

- `ApplicationDependencies.repositories.businessIdentityRepository` exposes
  the existing repository port to the application layer.
- `LegacyApplicationDependencyBridge` supplies the shared runtime business-
  identity repository to those dependencies.
- `AppCompositionRoot` constructs exactly one
  `LoadBusinessLogoQueryHandler` and exposes it as
  `ApplicationQueries.businessLogo`.
- `main.dart` wraps `GrainWarehouseApp` in `ApplicationScope` using the
  production `ApplicationBoundary`.
- The dashboard and financial-reports navigation retain that inherited scope
  above `PaymentMethodReportScreen`.

```text
APPLICATION_SCOPE_AVAILABLE = YES
RUNTIME_COMPOSITION_AVAILABLE = YES
NEW_APPLICATION_BOUNDARY_REQUIRED = NO
NEW_COMPOSITION_REQUIRED = NO
NEW_PROVIDER_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
```

If any later implementation observation contradicts these facts, the phase
must stop for governance review rather than introduce new architecture.

## 8. Current dependency path

The current valid-logo portion of `_exportPdf` is:

```text
_report null guard
→ AppRepositories.businessIdentityRepository.loadIdentity
→ identity.hasLogo && identity.logo != null
→ AppRepositories.businessIdentityRepository.loadLogoBytes(
    identity.logo!.managedFileName)
→ FinancialReportPdfBuilder.buildPaymentMethodReport(
    report: _report!,
    businessIdentity: identity,
    logoBytes: logoBytes)
→ _showExportResult
```

Only the fourth edge is governed for migration. The identity and financial-
report locator reads remain intentional Phase 108R dependencies.

## 9. Target dependency path

The future valid-logo path must be exactly:

```text
_report null guard
→ AppRepositories.businessIdentityRepository.loadIdentity
→ identity.hasLogo && identity.logo != null
→ ApplicationScope.of(context).queries.businessLogo.execute(
    LoadBusinessLogoQuery(
      managedFileName: identity.logo!.managedFileName))
→ logoBytes = result.value
→ FinancialReportPdfBuilder.buildPaymentMethodReport(
    report: _report!,
    businessIdentity: identity,
    logoBytes: logoBytes)
→ _showExportResult
```

The scope lookup must stay inside the valid-logo branch. Absent or invalid
metadata must not require `ApplicationScope` and must execute zero logo-query
reads.

## 10. Minimal implementation design

The later implementation is limited to three mechanical actions in the one
target file:

1. Import the existing `load_business_logo_query.dart` query declaration.
2. Import the existing `application_scope.dart` runtime scope.
3. Replace the direct valid-logo `loadLogoBytes` expression with one execution
   of the already-composed `businessLogo` query and assign `result.value`
   unchanged to the existing `logoBytes` variable.

No method extraction, callback, provider, wrapper, facade, controller, or
production testing seam is authorized. The identity read, gate, builder call,
catch block, and every neighboring line must remain semantically unchanged.

## 11. Exact production-file forecast

### EXPECTED_MODIFY

```text
lib/features/financial_reports/payment_method_report_screen.dart

SYMBOL = _PaymentMethodReportScreenState._exportPdf
CHANGE_TYPE = REPLACEMENT_PLUS_EXISTING_APPLICATION_QUERY_IMPORTS
AUTHORIZED_BEHAVIORAL_CHANGE = ONE_DEPENDENCY_OWNERSHIP_EDGE_ONLY
```

### EXPECTED_ADD

```text
NONE
```

### EXPECTED_DELETE

```text
NONE
```

Any requirement for a second production path is a mandatory stop-and-
governance-review condition.

## 12. Exact test-file add and modify forecast

### EXPECTED_TEST_ADD

```text
test/phase108r_payment_method_report_pdf_logo_query_migration_test.dart
```

This filename follows the accepted Phase 108P/108Q focused-seam convention.

### EXPECTED_TEST_MODIFY

```text
test/phase108i_second_read_only_ui_query_migration_test.dart
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
test/phase108n_settings_logo_preview_query_migration_test.dart
test/phase108o_printable_document_scaffold_logo_query_migration_test.dart
test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart
test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart
```

Repository-wide test inspection found these seven—and only these seven—live
files whose exact locator/scope counts, direct-logo-read set, actual invocation
count, or payment-method membership changes.

- Phase 108I/M/N update `140 → 139`, `156 → 155`, and `10 → 11`; locator
  files remain `36`.
- Phase 108L removes only the payment-method report from the exact guard-style
  logo-read set.
- Phase 108O applies the same set removal and numeric deltas.
- Phase 108P applies the numeric deltas and may add explicit payment-method
  membership assertions without weakening its account-balance or Phase 108Q
  assertions.
- Phase 108Q applies all numeric deltas, removes only the payment-method path
  from its exact guard-style set, changes actual invocation files `9 → 8`,
  and asserts the payment-method path remains a locator and becomes a scope
  consumer.

No behavioral guard may be removed, broadened, or weakened.

## 13. Existing tests that remain unchanged

The relevant unchanged regression files are:

```text
test/phase42_pdf_export_foundation_test.dart
test/phase68_business_logo_invoice_windows_icon_test.dart
test/phase79_account_based_financial_reports_test.dart
test/financial_payment_method_summary_tool_test.dart
```

- Phase 42 preserves the established PDF export foundation.
- Phase 68 preserves `LogoMetadata.hasLogo`, managed-file storage, missing-file
  nulls, rejected path-like filenames, and logo-write/delete behavior.
- Phase 79 preserves payment-method report models, grouping, transfer
  exclusion, all screen filter inputs, ordering, totals, permission flags, and
  PDF/CSV filenames.
- The dedicated summary-tool suite preserves the canonical read-only payment-
  method report model and ordering consumed outside this screen.

The modified Phase 108P and Phase 108Q focused suites also remain mandatory
regressions for the two immediately preceding financial-report logo seams.

## 14. Focused runtime test harness

The new Phase 108R suite must use existing test and composition seams only:

1. Initialize `AppCompositionRoot.initializeProduction` against an in-memory
   `FoundationDatabase` and retain the resulting `ApplicationBoundary`.
2. Use the existing demo-owner `AuthController` so the view and export actions
   are governed by real permission logic.
3. Replace only the mutable test-time
   `AppRepositories.businessIdentityRepository` with a locator spy and restore
   it in `addTearDown`.
4. For valid-logo cases, wrap the widget in `ApplicationScope` and replace
   only `ApplicationQueries.businessLogo` in a test `ApplicationBoundary`
   clone with a spy-backed existing `LoadBusinessLogoQueryHandler`.
5. Pump `PaymentMethodReportScreen` and allow its automatic `_applyFilters`
   to complete. Unlike account statement, no account selection is required;
   even an empty successfully loaded payment-method report enables export.
6. For the no-report case, use a controlled/deferred financial-account
   repository response through the existing mutable locator, restore it at
   teardown, and inspect the disabled PDF action while `_report` remains null.
   Do not add a production hook.
7. Use an intentional query failure to stop before static PDF asset/file work
   in valid-logo routing and error-containment cases.
8. In absent/invalid metadata cases, omit `ApplicationScope`, mock asset loads
   to fail safely if PDF initialization is reached, and prove the screen catch
   absorbs that failure without a missing-scope exception.
9. Use repository spies that record read order, exact filenames, and all
   identity/logo write/delete counts.
10. Restore all locators, composition resources, binary messenger handlers,
    surface sizes, and controllers with test-owned teardown.

## 15. Required focused assertions

The focused suite must prove:

1. With no loaded report, the PDF action is disabled and identity/query counts
   remain zero; the source guard also proves the null guard precedes work.
2. A valid export loads identity exactly once through the existing locator.
3. Presentation-owned
   `businessIdentityRepository.loadLogoBytes` executes zero times.
4. Absent logo metadata executes zero application logo queries.
5. Invalid logo metadata executes zero application logo queries.
6. Both false-gate paths require no `ApplicationScope` lookup.
7. Valid metadata executes exactly one existing `businessLogo` query.
8. The query receives the exact `identity.logo!.managedFileName` without
   trimming, normalization, substitution, or decoration.
9. Event order is exactly locator identity read before query execution.
10. Direct handler tests preserve present byte identity, empty-byte identity,
    and null; source inspection proves `result.value` is not transformed.
11. Query/repository failure stays inside the existing PDF catch and displays
    exactly `تعذر إنشاء ملف PDF.`.
12. Internal exception text is absent from the UI.
13. Identity save, logo save, and logo delete counts remain zero in locator
    and query spies.
14. Source wiring preserves the exact `_report!`, exact `identity`, and
    nullable `logoBytes` builder arguments.
15. The target method contains no direct `.loadLogoBytes(` after migration.
16. The screen contains no direct `LoadBusinessLogoQueryHandler(`
    construction.
17. No write token appears in the isolated target method.

Static `FinancialReportPdfBuilder` ownership means exact builder argument
wiring is proven by the source-region guard, not by adding a production
callback or testing hook.

## 16. Source and order guard

The focused suite must read the target source and isolate the substring from:

```text
Future<void> _exportPdf()
```

up to, but not including:

```text
Future<void> _exportCsv()
```

Within only that region it must prove:

```text
_report null guard
< locator-owned loadIdentity
< identity.hasLogo && identity.logo != null
< ApplicationScope businessLogo query
< FinancialReportPdfBuilder.buildPaymentMethodReport
< _showExportResult
```

It must also assert:

- imports for the existing query and scope;
- `managedFileName: identity.logo!.managedFileName` exactly;
- `logoBytes = result.value;` exactly;
- `report: _report!`, `businessIdentity: identity`, and
  `logoBytes: logoBytes` exactly;
- the existing PDF failure text;
- absence of `.loadLogoBytes(`, direct handler construction, `saveIdentity`,
  `saveLogoBytes`, and `deleteLogoFile` in the isolated region;
- retention elsewhere in the file of export permissions,
  `_service.paymentMethodReport`, `_paymentMethodFilter`,
  `_sourceTypeFilter`, `_accountIdFilter`, `_directionFilter`,
  `_expandedRows`, and `FinancialReportCsvExporter.exportPaymentMethodReport`.

The guard must not ban legitimate retained `AppRepositories` uses elsewhere
in the payment-method screen.

## 17. Current architecture inventory

The planning session independently recomputed the live tree using the same
definitions encoded by the Phase 108Q guard suite:

```text
CURRENT:
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 140
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 156
APPLICATION_SCOPE_CONSUMERS = 10
GUARD_STYLE_LOGO_READ_FILES = 10
ACTUAL_LOGO_INVOCATION_FILES = 9
```

Definitions:

- feature/shared references count literal `AppRepositories.` matches in Dart
  files below `lib/features` and `lib/shared`;
- locator files are those feature/shared Dart files with at least one such
  match;
- all-lib references use the same match throughout `lib`;
- scope consumers are feature/shared Dart files containing
  `ApplicationScope.of`;
- guard-style logo-read files match `(^|[^_])loadLogoBytes\(`;
- actual invocation files contain `.loadLogoBytes(`.

The payment-method screen currently contains four literal locator references:
service construction, account loading, identity loading, and logo-byte
loading. It is one of the 36 locator files and is not one of the ten scope
consumers.

## 18. Exact post-implementation inventory target

The only valid post-implementation inventory is:

```text
TARGET:
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 139
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 155
APPLICATION_SCOPE_CONSUMERS = 11
GUARD_STYLE_LOGO_READ_FILES = 9
ACTUAL_LOGO_INVOCATION_FILES = 8

PAYMENT_METHOD_REPORT_REMAINS_LOCATOR_FILE = YES
PAYMENT_METHOD_REPORT_BECOMES_APPLICATION_SCOPE_CONSUMER = YES

DIRECT_LOGO_READ_REMOVAL =
lib/features/financial_reports/payment_method_report_screen.dart ONLY
```

After Phase 108R, the exact guard-style set must be:

```text
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
lib/core/business_identity/business_identity_repository.dart
lib/features/exports/pdf_export_service.dart
lib/features/financial_reports/advances_and_refunds_report_screen.dart
lib/features/financial_reports/expense_analysis_report_screen.dart
lib/features/financial_reports/inflows_report_screen.dart
lib/features/financial_reports/outflows_report_screen.dart
lib/features/financial_reports/transfer_report_screen.dart
```

No unrelated reference may be added or removed to manufacture these counts.

## 19. Behavioral invariants

### Export preconditions and ownership

1. `_report == null` remains the first export guard.
2. Business identity remains loaded through
   `AppRepositories.businessIdentityRepository.loadIdentity()`.
3. The identity lookup is not migrated.
4. `identity.hasLogo && identity.logo != null` remains the exact query gate.
5. Invalid or absent metadata performs zero logo queries.
6. Valid metadata executes exactly one existing query.
7. The exact managed filename is forwarded unchanged.
8. `ApplicationQueryResult.value` reaches `logoBytes` unchanged.
9. Null remains null.
10. Empty returned bytes are not normalized to null.

### Report and screen behavior

11. The exact existing `_report!` reaches the existing builder.
12. The exact existing `BusinessIdentity` reaches the builder.
13. Nullable `logoBytes` remains the logo-byte builder input.
14. Automatic report loading and `_loading` behavior remain unchanged.
15. Account-list and report-source dependencies remain unchanged.
16. Date, payment-method, source-type, account, and direction filters remain
    unchanged.
17. Transfer-source exclusion, grouping, totals, and sort order remain
    unchanged.
18. Row expansion/display state remains unchanged.
19. Authentication and view/export permissions remain unchanged.
20. Navigation and back behavior remain unchanged.
21. CSV export remains unchanged.
22. Visible UI, loading, empty, and error states remain unchanged.

### PDF, file, and error behavior

23. `FinancialReportPdfBuilder.buildPaymentMethodReport` is unchanged.
24. PDF content, A4 layout, RTL behavior, typography, branding, tables, and
    totals remain unchanged.
25. `PdfFileNaming.paymentMethodReport(report.toDate)` remains unchanged.
26. Output-directory and file-write behavior remain unchanged.
27. The returned file still reaches `_showExportResult` unchanged.
28. Existing success notification behavior remains unchanged.
29. Existing PDF failure snackbar, color, and mount guard remain unchanged.
30. Query/repository exceptions remain within that failure contract and do
    not expose internal text.
31. CSV failure handling and naming remain unchanged.

### Write and construction prohibitions

32. No identity write is introduced.
33. No logo save is introduced.
34. No logo delete is introduced.
35. No database or other write is introduced.
36. No direct `LoadBusinessLogoQueryHandler` construction is introduced in
    presentation code.

## 20. Explicit non-goals and negative scope

```text
IDENTITY_LOOKUP_MIGRATION = FORBIDDEN
REPORT_DATA_QUERY_MIGRATION = FORBIDDEN
ACCOUNT_QUERY_MIGRATION = FORBIDDEN
OTHER_REPORT_LOGO_MIGRATIONS = FORBIDDEN
PDF_EXPORT_SERVICE_MIGRATION = FORBIDDEN
BACKUP_EXPORT_MIGRATION = FORBIDDEN

QUERY_CHANGE = FORBIDDEN
HANDLER_CHANGE = FORBIDDEN
QUERY_RESULT_MODEL_CHANGE = FORBIDDEN
REPOSITORY_PORT_CHANGE = FORBIDDEN
REPOSITORY_IMPLEMENTATION_CHANGE = FORBIDDEN

APPLICATION_BOUNDARY_CHANGE = FORBIDDEN
APPLICATION_SCOPE_CHANGE = FORBIDDEN
APPLICATION_DEPENDENCIES_CHANGE = FORBIDDEN
COMPOSITION_ROOT_CHANGE = FORBIDDEN
MAIN_DART_CHANGE = FORBIDDEN

PDF_BUILDER_CHANGE = FORBIDDEN
PDF_RENDERER_CHANGE = FORBIDDEN
PDF_BRANDING_CHANGE = FORBIDDEN
CSV_CHANGE = FORBIDDEN
UI_CHANGE = FORBIDDEN
PERMISSION_CHANGE = FORBIDDEN
NAVIGATION_CHANGE = FORBIDDEN
FILTER_CHANGE = FORBIDDEN
REPORT_CONTENT_CHANGE = FORBIDDEN
FILENAME_CHANGE = FORBIDDEN
DIRECTORY_CHANGE = FORBIDDEN
FILE_WRITE_CHANGE = FORBIDDEN
NOTIFICATION_CHANGE = FORBIDDEN

DATABASE_CHANGE = FORBIDDEN
SCHEMA_CHANGE = FORBIDDEN
SUPABASE_CHANGE = FORBIDDEN
CLOUD_CHANGE = FORBIDDEN
NETWORK_CHANGE = FORBIDDEN
DEPENDENCY_CHANGE = FORBIDDEN
LOCKFILE_CHANGE = FORBIDDEN
PLATFORM_CHANGE = FORBIDDEN
GENERATED_FILE_CHANGE = FORBIDDEN
BUILD_CHANGE = FORBIDDEN
CI_CHANGE = FORBIDDEN
RUNTIME_CONFIGURATION_CHANGE = FORBIDDEN

GLOBAL_APP_REPOSITORIES_CLEANUP = FORBIDDEN
BROAD_REFACTOR = FORBIDDEN
PERFORMANCE_REFACTOR = FORBIDDEN
UNRELATED_FORMATTING = FORBIDDEN
NEW_BUSINESS_FEATURE = FORBIDDEN
SECOND_PRODUCTION_FILE = FORBIDDEN
```

Deferred and untouched candidates are:

```text
lib/features/financial_reports/transfer_report_screen.dart
lib/features/financial_reports/inflows_report_screen.dart
lib/features/financial_reports/outflows_report_screen.dart
lib/features/financial_reports/expense_analysis_report_screen.dart
lib/features/financial_reports/advances_and_refunds_report_screen.dart
lib/features/exports/pdf_export_service.dart
lib/core/backup/backup_export.dart
```

This plan assigns none of them a phase number.

## 21. Implementation sequence

1. Verify the separately remote-locked Phase 108R planning commit/tag, exact
   branch, ancestry, plan blob, clean worktree/index, untracked set, and stash.
2. Recompute `140/36/156/10`, guard-style `10`, and invocation `9`, including
   exact memberships, before any source mutation.
3. Run the focused query and preceding Phase 108P/108Q seam tests plus the
   relevant payment/PDF regressions as a pre-change diagnostic baseline.
4. Add only the two existing query/scope imports to the payment-method screen.
5. Replace only the valid-logo direct read inside `_exportPdf` with the
   existing query execution and `result.value` assignment.
6. Add the one focused Phase 108R suite through existing test seams.
7. Update only the seven exact prior guard files and only their legitimate
   count/membership expectations.
8. Run the focused suite, all impacted guards, unchanged regressions,
   formatter, analyzer, sequential full suite, diff checks, allowlist, and
   recount.
9. Inspect the complete source/test diff and prove one production path, eight
   test paths, no weakened guard, and exact target inventories.
10. Create one local implementation commit only after every gate passes, then
    stop before implementation remote lock.

## 22. Implementation validation strategy

The later implementation must run these exact focused and impacted guards:

```powershell
flutter test test\phase108r_payment_method_report_pdf_logo_query_migration_test.dart

flutter test `
  test\phase108i_second_read_only_ui_query_migration_test.dart `
  test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart `
  test\phase108m_shared_business_identity_header_logo_query_migration_test.dart `
  test\phase108n_settings_logo_preview_query_migration_test.dart `
  test\phase108o_printable_document_scaffold_logo_query_migration_test.dart `
  test\phase108p_account_balance_report_pdf_logo_query_migration_test.dart `
  test\phase108q_account_statement_report_pdf_logo_query_migration_test.dart
```

It must run these exact unchanged relevant regressions:

```powershell
flutter test `
  test\phase42_pdf_export_foundation_test.dart `
  test\phase68_business_logo_invoice_windows_icon_test.dart `
  test\phase79_account_based_financial_reports_test.dart `
  test\financial_payment_method_summary_tool_test.dart
```

It must then run all repository gates:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
git diff --check
git diff --cached --check
git status --porcelain=v1 --untracked-files=all
```

```text
FOCUSED_TESTS = REQUIRED
IMPACTED_GUARD_TESTS = REQUIRED
RELEVANT_REGRESSION_TESTS = REQUIRED
FORMAT_GATE = REQUIRED
ANALYZER_GATE = REQUIRED
FULL_SUITE_SEQUENTIAL = REQUIRED
DIFF_CHECKS = REQUIRED
CHANGED_PATH_ALLOWLIST = REQUIRED
INVENTORY_RECOUNT = REQUIRED
```

A failing prior guard must be diagnosed within scope. Broad expectation
weakening, skip insertion, ignore expansion, or unrelated edits are forbidden.

## 23. Required focused and regression gates

The implementation closure evidence must report separately:

- the new focused suite pass/fail/test count;
- the seven-file impacted guard command pass/fail/test count;
- the four-file unchanged regression command pass/fail/test count;
- sequential full-suite pass/fail/test count;
- exact inventory recount and membership sets;
- formatter and analyzer results, including new warnings/errors;
- diff/cached-diff checks and changed-path allowlist;
- final worktree, index, untracked, and stash state.

The focused suite is not a substitute for the prior guard suites or the full
suite. The full suite is not a substitute for the seam-specific source and
runtime assertions.

## 24. Formatter, analyzer, and full-suite gates

The production/test implementation must be formatted using the repository's
existing Dart formatter only. The command
`dart format --output=none --set-exit-if-changed .` must report no files
requiring change after the final diff is ready. `flutter analyze` must
introduce no warning or error. The full
suite must run sequentially with `--concurrency=1` and pass without hiding
failures through retry-only evidence.

The implementation closure must retain the exact changed-path allowlist:

```text
PRODUCTION = 1 exact payment-method screen
TEST_ADD = 1 exact Phase 108R focused test
TEST_MODIFY = 7 exact prior guard tests
DOCUMENTATION = 0
CONFIG = 0
DEPENDENCIES = 0
DATABASE_OR_SUPABASE = 0
PLATFORM = 0
GENERATED = 0
```

## 25. Risks and controls

| Risk | Control |
| --- | --- |
| Scope lookup moves before the valid-logo gate | Source ordering guard plus absent/invalid runtime cases without `ApplicationScope`. |
| Identity read is accidentally migrated | Exact source assertion retains the locator-owned `loadIdentity`. |
| Filename or byte semantics change | Exact filename spy, handler identity/null/empty tests, and `result.value` source assertion. |
| Static builder motivates a production hook | Prove argument wiring by source guard and stop pre-builder with intentional failures. |
| Automatic payment report loading is mistaken for account-statement selection | Payment-specific harness waits for automatic `_applyFilters`; no dropdown selection is invented. |
| Null-report test races automatic loading | Use a controlled pending repository response through an existing locator seam. |
| Counts are broadly rebased | Apply only `140/36/156/10 → 139/36/155/11`, `10 → 9`, and `9 → 8`. |
| A prior direct-reader membership is accidentally removed | Assert the complete nine-file post-Phase 108R guard-style set. |
| Query errors leak internals | Intentional query failure asserts only the existing Arabic snackbar. |
| Neighboring report/CSV behavior drifts | Source guards and Phase 79 plus dedicated summary regressions. |
| Runtime scope differs from verified composition | Stop for governance review; do not add composition or provider code. |

## 26. Rollback and failure containment

The implementation must fail closed before commit if any gate fails or scope
expands. Preserve the evidence and working diff for a separately authorized
recovery session; do not amend, rebase, reset destructively, or rewrite locked
history. Do not compensate for a failed query seam with a direct-repository
fallback. Do not commit a partial migration whose source changed without its
focused and inventory guards.

If the implementation commit is valid but remote lock is not yet authorized,
retain the clean local commit/tag state and stop. Remote publication is a
separate lifecycle session.

## 27. Implementation stop conditions

Stop for governance review if implementation requires any of the following:

- changing `loadIdentity`;
- changing report-data reads, account reads, or `FinancialReportService`
  ownership;
- changing `ApplicationBoundary`, `ApplicationQueries`,
  `LoadBusinessLogoQuery`, `LoadBusinessLogoQueryHandler`,
  `BusinessIdentityRepository`, `ApplicationDependencies`,
  `AppCompositionRoot`, `ApplicationScope`, or `main.dart`;
- changing the PDF builder or CSV exporter;
- adding a provider, service, facade, controller, use case, callback,
  repository, adapter, or production testing hook;
- moving query resolution outside the valid-logo branch;
- changing null or empty-byte behavior;
- changing error/snackbar, success/result, file, filename, directory, UI,
  permissions, navigation, filters, report, or row-expansion behavior;
- introducing identity/logo/database writes;
- touching another financial-report logo consumer or another production file;
- changing database, Supabase, dependencies, lockfiles, platform, generated,
  build, CI, cloud, network, or runtime-configuration files;
- weakening a prior behavioral guard;
- discovering that `ApplicationScope`/`businessLogo` is unavailable;
- discovering inventory drift inconsistent with this locked baseline.

## 28. Implementation completion criteria

Phase 108R implementation local closure is complete only when:

1. The implementation is the direct child of the remote-locked planning
   baseline.
2. Exactly one production file changed and no production file was added or
   deleted.
3. Only the selected valid-logo byte read moved to the existing query.
4. Identity, report, filters, UI, PDF, CSV, and error behavior are unchanged.
5. The new focused suite proves every required runtime/source assertion.
6. Exactly the seven forecast prior guard files changed, without weakening.
7. The exact post-implementation inventory is `139/36/155/11`, guard-style
   `9`, invocation `8`, with correct memberships.
8. The focused, impacted, unchanged regression, analyzer, formatter, and full
   sequential suite gates pass.
9. Diff checks and the changed-path allowlist pass.
10. Worktree/index/untracked/stash state satisfies local-closure policy.
11. Exactly one implementation commit and, if lifecycle precedent requires,
    one correct local annotated implementation tag exist.
12. No remote mutation occurred during implementation local closure.

## 29. Planning-session validation evidence

This planning session performed documentation-only forensic validation:

```text
FRESH_FETCH = PASS
REPOSITORY_IDENTITY = PASS
GOVERNING_REMOTE_BRANCH = PASS
GOVERNING_LOCAL_REMOTE_TAG_OBJECT_MATCH = PASS
GOVERNING_LOCAL_REMOTE_TAG_PEELED_MATCH = PASS
GOVERNANCE_ARTIFACT_BLOB = PASS
SOURCE_AND_RUNTIME_ARCHITECTURE_INSPECTION = PASS
TEST_TREE_AND_GUARD_DISCOVERY = PASS
LIVE_INVENTORY_RECOUNT = PASS

FLUTTER_TEST_RUN_THIS_SESSION = NO
FLUTTER_ANALYZE_RUN_THIS_SESSION = NO
BUILD_RUN_THIS_SESSION = NO
```

The plan was derived from the live payment-method screen, application query,
handler, repository port/implementation, application boundary/dependencies,
scope, composition root/bridge, runtime root, PDF/CSV builders, branding
header, Phase 108Q plan/implementation precedent, current guards, and relevant
payment/PDF regressions.

## 30. Local closure and next lifecycle step

Planning local closure requires this document to be the only changed path,
one commit with subject:

```text
Phase 108R: plan payment method report logo query migration
```

and one local annotated tag:

```text
TAG = phase-108r-planning-baseline-locked
MESSAGE = Phase 108R planning baseline locked
```

No branch or tag push is authorized in this planning session. After valid
local commit/tag closure:

```text
PHASE_108R_PLANNING_LOCAL_CLOSURE = COMPLETE
PHASE_108R_PLANNING_REMOTE_LOCK = NOT_STARTED
PHASE_108R_IMPLEMENTATION = NOT_STARTED

NEXT_AUTHORIZED_SESSION = PHASE_108R_PLANNING_REMOTE_LOCK
```

Implementation remains unauthorized until the planning commit and annotated
tag are independently remote-locked and verified in that separate session.
