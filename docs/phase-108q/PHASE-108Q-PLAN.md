# Phase 108Q — Account-Statement PDF Logo Query Migration Plan

## 1. Phase and lifecycle state

```text
PHASE = 108Q
SESSION = PHASE_108Q_PLANNING
MODE = DOCUMENTATION_ONLY_LOCAL_CLOSURE

PHASE_108P_FINAL_CLOSURE = COMPLETE
PHASE_108Q_SCOPE_DISCOVERY = COMPLETE
PHASE_108Q_GOVERNANCE_RECONCILIATION_LOCAL_CLOSURE = COMPLETE
PHASE_108Q_GOVERNANCE_RECONCILIATION_REMOTE_LOCK = COMPLETE
PHASE_108Q_PLANNING_LOCAL_CLOSURE = COMPLETE_AFTER_LOCAL_COMMIT_AND_TAG
PHASE_108Q_PLANNING_REMOTE_LOCK = NOT_STARTED
PHASE_108Q_IMPLEMENTATION = NOT_STARTED
```

This artifact makes the locked Phase 108Q scope implementation-ready. It is a
planning document only: it changes no production or test code, performs no
runtime migration, and does not authorize implementation before the separate
planning remote-lock lifecycle is complete.

## 2. Phase objective and canonical scope

```text
CURRENT_PHASE_108Q_SCOPE =
SINGLE_ACCOUNT_STATEMENT_REPORT_PDF_MANAGED_LOGO_BYTE_READ_MIGRATION

CURRENT_PHASE_108Q_CANONICAL_SCOPE =
MIGRATE_ONLY_THE_DIRECT_MANAGED_LOGO_BYTE_DEPENDENCY_LOOKUP_INSIDE
_ACCOUNTSTATEMENTREPORTSCREENSTATE._EXPORTPDF
THROUGH_THE_EXISTING_BUSINESS_LOGO_APPLICATION_QUERY,
WHILE_PRESERVING_THE_LOCATOR_OWNED_BUSINESS_IDENTITY_READ
AND_ALL_SURROUNDING_REPORT_EXPORT_BEHAVIOR

READ_WRITE_CLASSIFICATION = READ_ONLY
PRODUCTION_FILE_COUNT = 1
```

The objective is to replace one presentation-to-repository ownership edge in
the account-statement PDF export with the already-composed application query.
The repository method, managed filename, returned bytes, identity, report,
PDF builder, file write, user notifications, and all surrounding screen
behavior remain unchanged.

The historical Phase 108Q design-system assignment is preserved as
non-governing future intent. It is not part of this plan.

## 3. Governing baseline

The planning entry gate was freshly fetched and verified before this document
was created:

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git

RECOVERY_CLASSIFICATION = CASE_A_FRESH_PLANNING
ENTRY_LOCAL_HEAD = f282d7628894c5391ce8a79b53218e0544420269
ENTRY_REMOTE_HEAD = f282d7628894c5391ce8a79b53218e0544420269
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0
ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
```

The governing Phase 108Q reconciliation baseline is:

```text
GOVERNING_GOVERNANCE_COMMIT =
f282d7628894c5391ce8a79b53218e0544420269

GOVERNING_GOVERNANCE_TAG =
phase-108q-governance-reconciliation-locked

GOVERNING_GOVERNANCE_TAG_TYPE = tag
GOVERNING_GOVERNANCE_TAG_OBJECT =
2201e7b891bbbb30c66b4c36e9c6522786fd5ade

GOVERNING_GOVERNANCE_TAG_PEELED_COMMIT =
f282d7628894c5391ce8a79b53218e0544420269

LOCAL_REMOTE_TAG_OBJECT = MATCH
LOCAL_REMOTE_PEELED_COMMIT = MATCH
```

The governing artifact is:

```text
docs/phase-108q/PHASE-108Q-GOVERNANCE-RECONCILIATION.md
```

The governance commit subject is
`Phase 108Q: reconcile governance and canonical scope`, and that Markdown file
is its only changed path.

## 4. Locked predecessor lineage

The relevant annotated baselines are exact locally and remotely:

```text
PHASE_108P_GOVERNANCE_TAG =
phase-108p-governance-reconciliation-locked
TAG_OBJECT = c292c8b7bf0cca72caf1846e0534e2bf4c2d5e34
PEELED_COMMIT = 4ea5837994331093048294df50f757521b6fdf94

PHASE_108P_PLANNING_TAG =
phase-108p-planning-baseline-locked
TAG_OBJECT = 3cb18d3627d50e584e75f7c49e8996c7e978ecf0
PEELED_COMMIT = 8408b20c1152bbd9e73b082c8a1653b3479ba33f

PHASE_108P_IMPLEMENTATION_TAG =
phase-108p-implementation-locked
TAG_OBJECT = 72157daa31c49b33513aafeda1bf692507f78422
PEELED_COMMIT = 072dd2c27578fca6d1a94ea16f498aa48f6b90a4

PHASE_108Q_GOVERNANCE_TAG =
phase-108q-governance-reconciliation-locked
TAG_OBJECT = 2201e7b891bbbb30c66b4c36e9c6522786fd5ade
PEELED_COMMIT = f282d7628894c5391ce8a79b53218e0544420269
```

Git proves this direct-parent chain:

```text
4ea5837994331093048294df50f757521b6fdf94
  Phase 108P governance
→ 8408b20c1152bbd9e73b082c8a1653b3479ba33f
  Phase 108P planning
→ 072dd2c27578fca6d1a94ea16f498aa48f6b90a4
  Phase 108P implementation
→ f282d7628894c5391ce8a79b53218e0544420269
  Phase 108Q governance reconciliation
```

All four commits are ancestors of the planning entry `HEAD`. No intervening
commit or rewritten predecessor history exists.

## 5. Current-state architecture

### 5.1 UI, state, and report path

The selected screen is:

```text
FILE =
lib/features/financial_reports/account_statement_report_screen.dart

UI_ENTRY = AccountStatementReportScreen
STATE_OWNER = _AccountStatementReportScreenState
PDF_ENTRY = _AccountStatementReportScreenState._exportPdf
```

The current report-data path is:

```text
AccountStatementReportScreen
→ _AccountStatementReportScreenState
→ _service.accountStatementReport(...selected filters...)
→ FinancialReportService.accountStatementReport
→ AppRepositories.financialAccountRepository
→ FinancialAccountRepository / production Drift repository
→ _report
```

The state owner also loads selectable accounts through
`AppRepositories.financialAccountRepository.listAccounts`, owns the selected
account and date/source/payment/reversal filters, and applies the existing
search query to report lines for display. None of this report-data or state
ownership is a Phase 108Q migration.

The PDF action is exposed by `GhalalPageHeader` only when the authenticated
user has `canExportFinancialReports`, and it is disabled when `_report` is
null. The whole screen remains gated by `canViewFinancialReports` through
`AuthScope.of(context).state.user`.

### 5.2 Current PDF identity and logo path

The current selected export path is:

```text
GhalalPageHeader PDF action
→ _AccountStatementReportScreenState._exportPdf
→ return immediately when _report == null
→ AppRepositories.businessIdentityRepository.loadIdentity()
→ identity.hasLogo && identity.logo != null
→ AppRepositories.businessIdentityRepository.loadLogoBytes(
    identity.logo!.managedFileName,
  )
→ FinancialReportPdfBuilder.buildAccountStatementReport(
    report: _report!,
    businessIdentity: identity,
    logoBytes: logoBytes,
  )
→ PdfBrandingHeader through FinancialReportPdfBuilder
→ PdfFileNaming.accountStatementReport
→ application documents / Exports directory
→ File.writeAsBytes
→ _showExportResult(file)
```

The selected architectural violation is only the direct `loadLogoBytes` call.
The locator-owned identity read is explicitly preserved.

### 5.3 Current repository semantics

`BusinessIdentityRepository.loadLogoBytes` is the existing repository port.
`LocalBusinessIdentityRepository.loadLogoBytes`:

- returns null for an empty managed filename;
- returns null for a filename containing `..`, `/`, or `\\`;
- resolves only beneath `managedLogosDirectory`;
- returns null when the managed file is absent; and
- otherwise returns the file's exact `Uint8List` bytes.

It introduces no database, Supabase, network, cache, or write behavior.
Phase 108Q does not alter this contract or implementation.

### 5.4 Current PDF and CSV ownership

`FinancialReportPdfBuilder.buildAccountStatementReport` remains the PDF
owner. It retains the current Amiri fonts, A4/RTL layout, branding header,
report contents, account name, lines, running balances, output directory,
filename, byte serialization, and file write. The returned `File` continues
to feed `_showExportResult`.

`FinancialReportCsvExporter.exportAccountStatementReport` and `_exportCsv`
are a separate unchanged path.

## 6. Existing application boundary and runtime ownership

The reusable application path already exists:

```text
ApplicationScope.of(context)
→ ApplicationBoundary.queries
→ ApplicationQueries.businessLogo
→ LoadBusinessLogoQueryHandler.execute
→ LoadBusinessLogoQuery(managedFileName: String)
→ BusinessIdentityRepository.loadLogoBytes
→ ApplicationQueryResult<Uint8List?>.value
```

Exact symbols and files are:

```text
APPLICATION_SCOPE = ApplicationScope
APPLICATION_SCOPE_FILE = lib/composition/application_scope.dart

QUERY_REGISTRY = ApplicationQueries
QUERY_FIELD = ApplicationQueries.businessLogo
BOUNDARY_FILE = lib/application/application_boundary.dart

QUERY_REQUEST = LoadBusinessLogoQuery
QUERY_HANDLER = LoadBusinessLogoQueryHandler
QUERY_FILE = lib/application/queries/load_business_logo_query.dart

REPOSITORY_PORT = BusinessIdentityRepository
REPOSITORY_FILE =
lib/core/business_identity/business_identity_repository.dart
```

For an empty filename, the handler returns a managed-file null result without
calling the repository. For a non-empty filename, it forwards the exact
string once, returns the exact `Uint8List?`, and propagates the exact
repository exception. It performs no writes or fallback retrieval.

`AppCompositionRoot.initializeProduction` captures the current
`AppRepositories.businessIdentityRepository` once as
`sharedBusinessIdentityRepository`. The same object is supplied to the
root-owned `BusinessIdentityController` and to
`ApplicationDependencies.repositories.businessIdentityRepository`.
`AppCompositionRoot` builds `LoadBusinessLogoQueryHandler` from that captured
dependency and places it in the root-owned `ApplicationQueries`.

`main.dart` installs the resulting `ApplicationBoundary` in
`ApplicationScope` above `TrialAppGate` and `GrainWarehouseApp`, so the current
account-statement route can resolve the query from its existing
`BuildContext`.

```text
RUNTIME_QUERY_AVAILABLE_AT_EXPORT_CALL_SITE = YES
ULTIMATE_REPOSITORY_INSTANCE = SAME_EXISTING_CAPTURED_INSTANCE
NEW_RUNTIME_WIRING_REQUIRED = NO
NEW_DEPENDENCY_REQUIRED = NO
NEW_APPLICATION_QUERY_REQUIRED = NO
NEW_HANDLER_REQUIRED = NO
NEW_REPOSITORY_CONTRACT_REQUIRED = NO
NEW_PROVIDER_REQUIRED = NO
```

Authentication permission state remains owned by `AuthScope`. Session and
business-context providers already captured in `ApplicationDependencies` are
not inputs to `LoadBusinessLogoQuery` and are not changed or newly consulted
by this phase. The managed logo remains a local, business-identity repository
read under the existing application boundary.

## 7. Target-state architecture

Phase 108Q changes one dependency-ownership edge and no other edge:

```text
CURRENT PATH
_AccountStatementReportScreenState._exportPdf
→ AppRepositories.businessIdentityRepository.loadIdentity()
→ valid-logo gate
→ AppRepositories.businessIdentityRepository.loadLogoBytes(managedFileName)
→ buildAccountStatementReport

TARGET PATH
_AccountStatementReportScreenState._exportPdf
→ AppRepositories.businessIdentityRepository.loadIdentity()
→ valid-logo gate
→ ApplicationScope.of(context).queries.businessLogo.execute(
    LoadBusinessLogoQuery(
      managedFileName: identity.logo!.managedFileName,
    ),
  )
→ ApplicationQueryResult.value
→ buildAccountStatementReport
```

The ownership migration is from a presentation-owned repository lookup to a
root-composed application query. The identity read deliberately remains a
locator read, so the target file remains both a locator file and becomes an
`ApplicationScope` consumer.

No controller, view model, service, repository, persistence adapter, session
context, business context, or composition-root responsibility moves.

## 8. Minimal implementation design

The later implementation must make only these production edits:

1. Add imports for the existing `LoadBusinessLogoQuery` request and
   `ApplicationScope`.
2. Keep the `app_repositories.dart` import because report, account, and
   identity reads remain locator-owned.
3. Keep `dart:typed_data` because `Uint8List? logoBytes` remains explicit.
4. Keep `_report == null` as the first `_exportPdf` guard.
5. Keep the existing outer `try/catch` and identity read in their current
   order.
6. Keep `identity.hasLogo && identity.logo != null` as the exact gate.
7. Inside that gate only, resolve
   `ApplicationScope.of(context).queries.businessLogo`.
8. Execute `LoadBusinessLogoQuery` with the unchanged
   `identity.logo!.managedFileName`.
9. Assign only `result.value` to the existing `logoBytes` variable.
10. Leave the PDF builder call, success handling, catch, CSV path, state,
    filters, permissions, navigation, and rendering unchanged.

The scope lookup stays inside the valid-logo branch so absent or invalid
metadata needs no `ApplicationScope` and performs no logo read. Query
execution stays inside the existing `try` so query/repository failures remain
contained by the existing PDF failure snackbar.

No direct `LoadBusinessLogoQueryHandler` construction is permitted in the
screen.

## 9. Exact production-file forecast

### EXPECTED_MODIFY

```text
FILE = lib/features/financial_reports/account_statement_report_screen.dart
EXISTS_AT_PLANNING_BASELINE = YES
SYMBOL = _AccountStatementReportScreenState._exportPdf
CHANGE_TYPE = REPLACEMENT_PLUS_IMPORTS
WHY = replace one direct managed-logo-byte repository lookup with the
      existing business-logo application query
RESPONSIBILITY_AFTER_108Q = continue to own account-statement presentation and
      export orchestration while consuming logo bytes through the application
      boundary on the valid-logo path
```

### EXPECTED_ADD

```text
NONE
```

### EXPECTED_DELETE

```text
NONE
```

Any required production change outside the one `EXPECTED_MODIFY` path is an
implementation stop-and-governance-review condition.

## 10. Exact test-file forecast

### EXPECTED_TEST_ADD

```text
test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart
```

This focused suite must cover the selected runtime/source seam without adding
a production testing hook.

### EXPECTED_TEST_MODIFY

```text
test/phase108i_second_read_only_ui_query_migration_test.dart
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
test/phase108n_settings_logo_preview_query_migration_test.dart
test/phase108o_printable_document_scaffold_logo_query_migration_test.dart
test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart
```

The Phase 108I/M/N/O/P files assert live locator/scope inventories and require
only the exact Phase 108Q numeric and membership delta. The Phase 108L/O files
assert the complete guard-style direct-logo-read set and remove only
`account_statement_report_screen.dart`. Phase 108P remains the behavioral
precedent for an analogous financial-report export and must retain all of its
account-balance assertions.

No existing behavioral guard may be weakened to accommodate the migration.

### EXISTING TESTS THAT REMAIN UNCHANGED

```text
test/phase42_pdf_export_foundation_test.dart
test/phase68_business_logo_invoice_windows_icon_test.dart
test/phase79_account_based_financial_reports_test.dart
```

Phase 68 covers managed logo storage, missing files, and rejected path-like
filenames. Phase 79 covers account-statement models, computation, ordering,
running/opening/closing balances, filters, and PDF/CSV filenames. Phase 42
provides the existing PDF export foundation. These are regression evidence;
none directly replaces a focused private account-statement export seam test.

### INSPECT_ONLY PRODUCTION FILES

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
lib/core/financial_accounts/financial_account_repository.dart
lib/core/financial_accounts/financial_report_service.dart
lib/features/exports/financial_report_csv_exporter.dart
lib/features/exports/financial_report_pdf_builder.dart
lib/features/exports/pdf_branding_header.dart
lib/main.dart
```

## 11. Focused test design

The new Phase 108Q suite should follow the established Phase 108P harness
shape while accounting for the account-statement screen's required account
selection/report-load precondition.

### 11.1 Runtime harness

1. Initialize the existing production composition against an in-memory test
   database and retain its `ApplicationBoundary`.
2. Seed one test-owned financial account through the current
   `FinancialAccountRepository.createAccount` contract; do not add a
   production injection hook.
3. Install the existing demo owner `AuthController` so view/export permissions
   are genuine.
4. Replace only the existing mutable business-identity locator repository in
   the test, restoring it with `addTearDown`.
5. Wrap the widget with `ApplicationScope` only in cases that should reach the
   valid-logo query path, replacing only `ApplicationQueries.businessLogo`
   with a spy-backed `LoadBusinessLogoQueryHandler`.
6. Pump `AccountStatementReportScreen`, select the seeded account through the
   existing dropdown, allow `_applyFilters` to complete, and verify the PDF
   action becomes enabled before triggering it.
7. Use an intentional query failure to stop before real PDF asset/file work
   where the assertion concerns routing or failure containment.
8. For absent/invalid metadata cases, omit `ApplicationScope`, force the
   existing PDF asset path to fail safely if needed, and prove no missing-scope
   exception and no logo read.

### 11.2 Required focused assertions

The new suite must establish:

1. With no loaded report, the PDF action is disabled and the source guard
   proves `_report == null` precedes identity/query work.
2. Identity is loaded exactly once through the locator repository on an
   enabled export and before the logo query.
3. The locator repository's `loadLogoBytes` is never called.
4. Absent and invalid logo metadata perform zero application-query repository
   reads and require no `ApplicationScope` lookup.
5. Valid metadata invokes the injected existing business-logo query exactly
   once with the exact `identity.logo!.managedFileName`.
6. Existing query unit coverage in the suite or Phase 108L proves exact byte
   identity, null preservation, empty-name short circuit, and exception
   propagation; the source guard proves `result.value` is assigned without
   transformation to the `logoBytes` variable passed to the builder.
7. The exact `_report!`, identity object, and nullable `logoBytes` variable
   remain the three relevant builder arguments.
8. A query/repository failure displays exactly `تعذر إنشاء ملف PDF.` and does
   not display internal exception text.
9. Identity save, logo save, and logo delete counts remain zero in both
   locator and query spies.
10. The target method contains no direct `.loadLogoBytes(` and no direct
    `LoadBusinessLogoQueryHandler(` construction.
11. The existing builder, result handler, CSV method, permissions, filters,
    and neighboring screen source remain unchanged.

### 11.3 Source and ordering guard

The focused source guard should isolate the source substring from
`Future<void> _exportPdf()` to `Future<void> _exportCsv()` and assert the order:

```text
_report null guard
< locator-owned loadIdentity
< identity.hasLogo && identity.logo != null
< ApplicationScope query lookup
< FinancialReportPdfBuilder.buildAccountStatementReport
< _showExportResult
```

It should assert the exact managed-filename expression, `result.value`,
builder arguments, failure text, absence of writes, absence of a direct logo
read, and absence of direct handler construction. It must not forbid the
legitimate locator identity read or other `AppRepositories` uses elsewhere in
the file.

## 12. Expected architecture inventory delta

Live planning-baseline inspection produced:

```text
CURRENT:
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 141
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 157
FEATURE_SHARED_APPLICATION_SCOPE_CONSUMERS = 9
GUARD_STYLE_DIRECT_LOGO_READ_FILE_COUNT = 11
ACTUAL_INVOCATION_FILE_COUNT = 10
```

The target file currently has four literal `AppRepositories.` references:
financial report service construction, account loading, identity loading, and
logo-byte loading. Only the last is removed. It currently has no
`ApplicationScope.of` call; the one governed query lookup adds it to the scope
consumer set without removing it from the locator-file set.

The exact post-implementation result is:

```text
TARGET:
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 140
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 156
FEATURE_SHARED_APPLICATION_SCOPE_CONSUMERS = 10
GUARD_STYLE_DIRECT_LOGO_READ_FILE_COUNT = 10
ACTUAL_INVOCATION_FILE_COUNT = 9

ACCOUNT_STATEMENT_SCREEN_REMAINS_LOCATOR_FILE = YES
ACCOUNT_STATEMENT_SCREEN_BECOMES_SCOPE_CONSUMER = YES
DIRECT_LOGO_READ_FILE_REMOVALS =
lib/features/financial_reports/account_statement_report_screen.dart ONLY
```

After the governed removal, the guard-style set must still contain exactly:

```text
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
lib/core/business_identity/business_identity_repository.dart
lib/features/exports/pdf_export_service.dart
lib/features/financial_reports/advances_and_refunds_report_screen.dart
lib/features/financial_reports/expense_analysis_report_screen.dart
lib/features/financial_reports/inflows_report_screen.dart
lib/features/financial_reports/outflows_report_screen.dart
lib/features/financial_reports/payment_method_report_screen.dart
lib/features/financial_reports/transfer_report_screen.dart
```

No unrelated reference may be added or removed to manufacture these counts.

## 13. Behavioral invariants

### 13.1 Export preconditions and identity

- `_report == null` returns before identity, logo, builder, or file work.
- PDF remains visible only to users with export permission and remains disabled
  until a report exists.
- Identity remains loaded first through exactly
  `AppRepositories.businessIdentityRepository.loadIdentity()`.
- The exact returned `BusinessIdentity` reaches the existing logo gate and PDF
  builder.
- No identity controller migration, fallback, save, or normalization is added.

### 13.2 Logo behavior

- `identity.hasLogo && identity.logo != null` remains the exact lookup gate.
- Absent or invalid metadata performs no `ApplicationScope` lookup and no logo
  repository read.
- Valid metadata invokes the existing query exactly once with the exact
  `identity.logo!.managedFileName`.
- The filename is not trimmed, normalized, decorated, or replaced.
- `ApplicationQueryResult.value` reaches `logoBytes` unchanged.
- Present bytes preserve exact byte identity; query/repository null remains
  null; empty returned bytes are not normalized to null.
- Existing repository behavior for missing and rejected path-like files
  remains null.
- Query/repository exceptions remain within the existing export catch.
- No fallback image, remote lookup, cache mutation, write, or delete is added.

### 13.3 Account-statement behavior

- Account list loading and account selection remain unchanged.
- `_applyFilters` and `FinancialReportService.accountStatementReport` remain
  unchanged.
- Date, source type, payment method, reversal, and text-search behavior remain
  unchanged.
- Opening balance, entry ordering, running balance, closing balance, source
  labels, payment labels, reversal status, document data, and notes remain
  unchanged.
- The exact `_report!` object reaches the PDF builder.
- Loading, empty, error, permission, and report-result UI states remain
  unchanged.

### 13.4 PDF, file, and notification behavior

- `FinancialReportPdfBuilder.buildAccountStatementReport` is unchanged.
- PDF content, branding, A4 layout, RTL direction, Amiri typography, table,
  balances, labels, spacing, and profile fields are unchanged.
- `PdfFileNaming.accountStatementReport`, account-name sanitization, date, and
  `.pdf` extension are unchanged.
- Application-documents `Exports` directory behavior is unchanged.
- File serialization and `writeAsBytes` behavior are unchanged.
- The returned `File` still reaches `_showExportResult`.
- Success text/path, green background, mount guard, and five-second duration
  remain unchanged.
- Identity, query, builder, and file failures remain represented by exactly
  `تعذر إنشاء ملف PDF.` with the existing red snackbar and mount guard.
- Internal exception text remains hidden.

### 13.5 Neighboring behavior

- CSV export, CSV failure text, and CSV naming are unchanged.
- Navigation/back behavior is unchanged.
- Authentication and permission semantics are unchanged.
- Session and business-context ownership are unchanged.
- All other financial-report screens and logo readers are unchanged.

## 14. Explicit non-goals and negative scope

Phase 108Q does not authorize:

- migration of the locator-owned business-identity read;
- migration of financial-account reads or `FinancialReportService` ownership;
- changes to account selection, report loading, filters, search, sort, or
  displayed report state;
- changes to CSV behavior;
- migration of the six neighboring financial-report logo readers;
- changes to `PdfExportService._loadBranding`;
- changes to backup logo integrity/base64 architecture;
- global `AppRepositories` removal;
- changes to `ApplicationBoundary`, `ApplicationQueries`, query request,
  handler, result model, application dependencies, or composition root;
- a new controller, view model, service, facade, use case, callback, provider,
  repository, adapter, DI framework, or production test hook;
- direct handler construction in presentation code;
- PDF builder, renderer, branding, content, layout, RTL, typography, filename,
  directory, file-write, or notification changes;
- UI redesign, new product features, navigation changes, or unrelated screens;
- database/schema/migration, Supabase, cloud, network, or persistence-format
  changes;
- dependency, manifest, lockfile, platform, generated, build, CI, or runtime
  configuration changes;
- dependency upgrades, performance work, broad refactors, moves, renames,
  cleanup-only edits, or unrelated formatting.

```text
IDENTITY_LOOKUP_MIGRATION = NOT_AUTHORIZED
OTHER_REPORT_LOGO_MIGRATIONS = NOT_AUTHORIZED
PDF_EXPORT_SERVICE_MIGRATION = NOT_AUTHORIZED
BACKUP_EXPORT_MIGRATION = NOT_AUTHORIZED
GLOBAL_APP_REPOSITORIES_REMOVAL = NOT_AUTHORIZED
NEW_BOUNDARY_ELEMENT = NOT_AUTHORIZED
SECOND_PRODUCTION_FILE = NOT_AUTHORIZED
```

## 15. Implementation sequence

1. Verify the separately remote-locked Phase 108Q planning commit/tag, branch,
   clean worktree/index, empty untracked/stash state, and exact planning blob.
2. Recompute the `141/36/157/9`, `11`, and `10` baseline inventories and the
   exact direct-logo-read membership.
3. Run the focused pre-change business-logo query, Phase 108P seam, and
   account-statement report regressions without weakening them.
4. Add only the two existing application query/scope imports to the selected
   account-statement screen.
5. Replace only the valid-logo direct `loadLogoBytes` block in `_exportPdf`
   with `ApplicationQueries.businessLogo` execution and `result.value`.
6. Add the focused Phase 108Q suite using existing composition, auth, repository
   seeding, and test teardown seams.
7. Update only the exact inventory and direct-read membership assertions in
   the six forecasted prior-phase test files.
8. Run focused seam tests, impacted guards, unchanged report/PDF regressions,
   formatter validation, analyzer, sequential full suite, and Git/diff gates.
9. Confirm the production diff is one file, no second logo consumer changed,
   no earlier behavior guard was weakened, and the target inventories are
   exact.
10. Create one local implementation commit only after all gates pass, then stop
    before any implementation remote lock.

## 16. Later implementation validation strategy

Run the narrowest diagnostic checks first:

```powershell
flutter test test\phase108q_account_statement_report_pdf_logo_query_migration_test.dart

flutter test `
  test\phase108i_second_read_only_ui_query_migration_test.dart `
  test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart `
  test\phase108m_shared_business_identity_header_logo_query_migration_test.dart `
  test\phase108n_settings_logo_preview_query_migration_test.dart `
  test\phase108o_printable_document_scaffold_logo_query_migration_test.dart `
  test\phase108p_account_balance_report_pdf_logo_query_migration_test.dart

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

The implementation session must also inspect the complete diff, changed-path
allowlist, source-region guard, inventory counts, and direct-read sets. A test
failure must be diagnosed within scope; it may not be hidden by weakening an
earlier assertion.

## 17. Risks and controls

| Risk | Control |
|---|---|
| The nearby identity read is migrated opportunistically | Assert its exact locator expression and its order before the query. |
| `ApplicationScope` is resolved without valid logo metadata | Keep lookup inside the existing gate; test absent/invalid metadata without a scope. |
| The account-statement report is not loaded in the widget harness | Seed/select an account and assert the PDF action is enabled before tapping. |
| Query bytes or null are transformed | Assign only `result.value`; combine query identity/null tests with the focused source guard. |
| Query failure escapes or exposes internals | Keep execution inside the current `try/catch`; assert exact existing snackbar and hidden exception text. |
| Static PDF APIs motivate production injection | Stop; use intentional pre-builder failures and source guards, adding no production test hook. |
| The locator import is removed despite retained reads | Retain `app_repositories.dart`; assert the target stays in the locator set. |
| Existing report/filter/CSV behavior is changed | Restrict the production diff to imports and the selected logo block; run Phase 79 and source guards. |
| Guard counts are broadly rebased | Apply only `141/36/157/9 → 140/36/156/10` and exact set membership changes. |
| Another logo consumer is migrated | Enforce the one-production-file allowlist and remove only the account-statement path from direct-read sets. |
| Runtime scope differs from verified root composition | Stop for governance review instead of adding a provider, callback, service, or alternate path. |

## 18. Rollback and failure containment

The later implementation is reversible because it changes one presentation
call site, adds one focused test, and updates deterministic source/inventory
guards. It changes no storage format, database, schema, network contract,
dependency, generated artifact, repository port, handler, or composition.

Before an implementation commit, preserve and inspect any uncommitted work;
do not use destructive reset or clean operations. After a valid local commit
and before remote lock, recovery is a normal forward correction or separately
authorized revert, never amend/rebase/force-push/tag deletion.

Failures remain localized as follows:

- missing/invalid logo metadata bypasses the application query;
- repository null remains a nullable builder input;
- query/repository failure remains in the existing `_exportPdf` catch;
- builder/file failure remains in the same catch;
- report loading and CSV paths do not depend on the migrated logo query; and
- no persistent data migration requires rollback.

## 19. Implementation stop conditions

Stop for governance review if implementation requires any of the following:

```text
- changing loadIdentity or any financial-account/report-data read
- changing ApplicationBoundary, ApplicationQueries, query handler, repository,
  application dependencies, composition root, main.dart, or PDF builder
- adding a service, facade, use case, provider, callback, controller, or
  production test hook
- resolving logo bytes outside the existing application query
- moving ApplicationScope lookup outside the valid-logo branch
- changing null, empty-byte, missing-file, exception, snackbar, or save behavior
- changing account selection, filters, report data, permissions, CSV, UI, or
  navigation
- touching a second logo consumer or a second production file
- changing database, Supabase, dependency, platform, generated, CI, or runtime
  files
- weakening prior behavioral guards or changing unrelated inventory counts
- discovering ApplicationScope or businessLogo is unavailable at runtime
```

## 20. Completion criteria

Future Phase 108Q implementation is complete only when:

```text
1. Only the selected account-statement logo-byte lookup moves to
   ApplicationQueries.businessLogo.
2. _report null remains the first export guard.
3. The locator-owned identity read remains exact, first, and unchanged.
4. The valid-logo gate and exact managed filename remain unchanged.
5. Exactly one query lookup occurs on the valid-logo path and none otherwise.
6. Query result.value reaches the unchanged logoBytes builder argument.
7. The exact report and identity objects reach buildAccountStatementReport.
8. Present bytes, null, empty bytes, missing files, and errors retain behavior.
9. Report selection/data/filtering, PDF/CSV, UI, permissions, navigation,
   filenames, file writes, and notifications are unchanged.
10. No identity/logo write or deletion is introduced.
11. No query, handler, repository, composition, session/business-context,
    persistence, dependency, or platform asset changes.
12. Inventory is exactly 140 references / 36 locator files / 156 all-lib /
    10 scope consumers, with direct-read counts 10 and 9.
13. Only account_statement_report_screen.dart leaves both direct-read sets.
14. Production changes equal the one forecasted file; tests equal the one new
    and six modified forecasted files.
15. Focused, guard, regression, format, analyzer, full-suite, and diff gates pass.
16. No remote or history mutation occurs during local implementation closure.
```

Any unmet criterion is not partial completion.

## 21. Planning-session validation

This planning session verified fresh repository/remote identity, the exact
annotated governing tags and parent chain, the complete Phase 108Q governance
commit, current source, runtime composition, repository semantics, PDF/report
paths, Phase 108N–108P planning conventions, focused Phase 108L–108P guards,
and independently recomputed live inventories.

Only this Markdown plan is authorized to change in the planning session.

```text
TESTS_RUN_THIS_SESSION = NO
ANALYZER_RUN_THIS_SESSION = NO
REASON = PLANNING_ONLY_DOCUMENTATION_MUTATION
```

No production or test result is claimed from this planning session.

## 22. Next lifecycle step

This planning session creates one local documentation commit and the local
annotated `phase-108q-planning-baseline-locked` tag required by its governing
session instructions. It performs no push and creates no remote tag.

```text
CURRENT_SESSION_END_STATE = PHASE_108Q_PLANNING_LOCAL_CLOSURE

PHASE_108P_FINAL_CLOSURE = COMPLETE
PHASE_108Q_SCOPE_DISCOVERY = COMPLETE
PHASE_108Q_GOVERNANCE_RECONCILIATION_LOCAL_CLOSURE = COMPLETE
PHASE_108Q_GOVERNANCE_RECONCILIATION_REMOTE_LOCK = COMPLETE
PHASE_108Q_PLANNING_LOCAL_CLOSURE = COMPLETE_AFTER_LOCAL_COMMIT_AND_TAG
PHASE_108Q_PLANNING_REMOTE_LOCK = NOT_STARTED
PHASE_108Q_IMPLEMENTATION = NOT_STARTED

NEXT_AUTHORIZED_SESSION = PHASE_108Q_PLANNING_REMOTE_LOCK
```

Implementation remains unauthorized until the planning commit and tag are
independently verified and remotely locked in that separate session.
