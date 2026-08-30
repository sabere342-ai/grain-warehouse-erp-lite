# Post-Transfer Report PDF Logo Query Migration — Inflows Report PDF Logo Query Migration Plan

Date: 2026-08-30

## A. Planning Result

```text
SESSION =
POST_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION_INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING

SESSION_MODE = FORENSIC_PLANNING_LOCAL_CLOSURE_ONLY

CANONICAL_SUCCESSOR_SCOPE =
INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY =
INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY_TYPE = DESCRIPTIVE_NONNUMERIC_GOVERNED_IDENTITY
PLANNING_RESULT = IMPLEMENTATION_READY
IMPLEMENTATION_AUTHORIZED = NO
IMPLEMENTATION_STARTED = NO
```

This plan converts the remotely locked explicit owner decision into one
deterministic, behavior-preserving implementation scope. It plans only the
Inflows Report PDF managed-logo-byte ownership seam. It does not implement the
migration, reopen Transfer or Phase 108R, plan another candidate, assign an
ordinal, or create a general migration queue.

## B. Repository Identity

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
IDENTITY_VERIFIED = YES
```

## C. Entry / Recovery Classification

A fresh `git fetch origin --prune --tags` completed before planning.

```text
RECOVERY_CLASSIFICATION = CASE_A_FRESH_PLANNING

ENTRY_LOCAL_HEAD = da6c782c9dedcb5c05a49d5cbec99f2b82087acd
ENTRY_REMOTE_HEAD = da6c782c9dedcb5c05a49d5cbec99f2b82087acd
ENTRY_MERGE_BASE = da6c782c9dedcb5c05a49d5cbec99f2b82087acd
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0

ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
```

No interrupted planning work, unexpected local commit, divergence, tracked
mutation, staged content, untracked artifact, or stash entry existed.

## D. Governing Lock Verification

The immediate owner-decision baseline was independently verified:

```text
OWNER_SUCCESSOR_SCOPE_DECISION_COMMIT =
da6c782c9dedcb5c05a49d5cbec99f2b82087acd

OWNER_SUCCESSOR_SCOPE_DECISION_PARENT =
d2f3f52114bda2eead5291fde44779597c0d1690

OWNER_SUCCESSOR_SCOPE_DECISION_SUBJECT =
docs: select inflows report migration successor

OWNER_SUCCESSOR_SCOPE_DECISION_ARTIFACT =
docs/POST-TRANSFER-REPORT-PDF-LOGO-QUERY-MIGRATION-OWNER-SUCCESSOR-SCOPE-DECISION.md

OWNER_SUCCESSOR_SCOPE_DECISION_ARTIFACT_BLOB =
b9079166c997715d5510629be79f60446c7539fb

OWNER_SUCCESSOR_SCOPE_DECISION_REMOTE_LOCK = COMPLETE
```

The predecessor chain and historical annotated lock also remain exact:

```text
PREDECESSOR_GOVERNANCE_COMMIT =
d2f3f52114bda2eead5291fde44779597c0d1690

TRANSFER_IMPLEMENTATION_COMMIT =
68f6d49339b71b1ed6b6843ed4f3cfd945dff258

PHASE_108R_IMPLEMENTATION_COMMIT =
ded903e95e0b6f08e41409dac8200f1ed0367644

PHASE_108R_IMPLEMENTATION_TAG = phase-108r-implementation-locked
LOCAL_TAG_OBJECT = f9f1382fabb3ced2220a9f199487a7b6166d66db
REMOTE_TAG_OBJECT = f9f1382fabb3ced2220a9f199487a7b6166d66db
LOCAL_TAG_PEELED_COMMIT = ded903e95e0b6f08e41409dac8200f1ed0367644
REMOTE_TAG_PEELED_COMMIT = ded903e95e0b6f08e41409dac8200f1ed0367644
TAG_TYPE = tag
ANNOTATED = YES

GOVERNING_LOCKS_VALID = YES
```

All objects are reachable in the required order. No governing artifact,
predecessor implementation, or tag is modified by this planning session.

## E. Owner Decision / Scope Authority

The governing artifact establishes:

```text
OWNER_SUCCESSOR_SCOPE_DECISION =
INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION

DECISION_SOURCE = EXPLICIT_REPOSITORY_OWNER_INSTRUCTION
DECISION_STATUS = FINAL_FOR_THIS_SUCCESSOR_SELECTION

CANONICAL_SUCCESSOR_SCOPE =
INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY =
INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_SCOPE_RESOLVED = YES
SUCCESSOR_IDENTITY_RESOLVED = YES
OWNER_SUCCESSOR_SCOPE_DECISION_REQUIRED = NO
ADDITIONAL_TECHNICAL_SCOPE_DISCOVERY_REQUIRED = NO

PLANNING_AUTHORIZED = YES
IMPLEMENTATION_AUTHORIZED = NO
```

The selection derives exclusively from the explicit owner decision. It is not
derived from menu order, candidate order, technical similarity, reference
counts, or numeric succession.

The following candidates remain unselected and unauthorized in this lifecycle:

```text
OUTFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION
EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION
ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION
```

They are not canceled or permanently rejected, but this plan may neither plan
nor batch them.

```text
PHASE_108S_IS_AUTHORIZED = NO
PHASE_108T_IS_AUTHORIZED = NO
NUMBERED_SUCCESSOR_PHASE_ESTABLISHED = NO
ORDINAL_SUCCESSION_USED_AS_AUTHORITY = NO
```

## F. Current-State Forensics

### Selected production seam

Live source proves:

```text
PRIMARY_PRODUCTION_TARGET =
lib/features/financial_reports/inflows_report_screen.dart

TARGET_SYMBOL = _InflowsReportScreenState._exportPdf
READ_WRITE_CLASSIFICATION = READ_ONLY
DIRECT_LOGO_BYTE_READ_COUNT = 1
INFLOWS_APP_REPOSITORIES_REFERENCES = 4
INFLOWS_APPLICATION_SCOPE_USES = 0
WRITE_TOKENS_IN_TARGET = 0
```

The current `_exportPdf` ownership sequence is:

```text
if (_report == null) return
-> AppRepositories.businessIdentityRepository.loadIdentity()
-> Uint8List? logoBytes
-> identity.hasLogo && identity.logo != null
-> AppRepositories.businessIdentityRepository.loadLogoBytes(
     identity.logo!.managedFileName)
-> derive accountLabel from _accountIdFilter and _accounts
-> FinancialReportPdfBuilder.buildInflowsReport(
     report: _report!,
     accountLabel: accountLabel,
     businessIdentity: identity,
     logoBytes: logoBytes)
-> _showExportResult(file)
```

The file's four literal `AppRepositories.` references are:

1. `FinancialReportService` construction;
2. financial-account loading;
3. business-identity loading; and
4. the selected direct managed-logo-byte read.

Only item 4 belongs to the selected scope. Items 1–3 remain unchanged, so the
Inflows screen remains a locator consumer after migration.

### Neighboring behavior

The screen currently:

- loads `_report` through `_service.inflowsReport` with from/to date and
  account filters;
- derives `accountLabel` only for a selected financial account;
- enables PDF and CSV actions only when `_report != null` and export permission
  exists;
- uses `FinancialReportPdfBuilder.buildInflowsReport` for PDF;
- uses `FinancialReportCsvExporter.exportInflowsReport` in the separate
  `_exportCsv` method;
- shows `تعذر إنشاء ملف PDF.` inside the existing mounted/red-snackbar catch;
  and
- forwards the created file to `_showExportResult` unchanged.

No identity, logo, report, database, or other write token occurs in the
selected target.

### Import state

`dart:typed_data` remains required because `Uint8List? logoBytes` remains.
The current file does not import the application query declaration or
`ApplicationScope`. Those are the only expected production import additions.

## G. Precedent / Architecture Verification

### Accepted Transfer predecessor

The remotely locked Transfer implementation in
`lib/features/financial_reports/transfer_report_screen.dart` imports:

```dart
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
```

It retains the locator-owned identity read and valid-metadata gate, then uses:

```dart
// The export contract intentionally resolves this only after identity.
final result =
    // ignore: use_build_context_synchronously
    await ApplicationScope.of(context).queries.businessLogo.execute(
          LoadBusinessLogoQuery(
            managedFileName: identity.logo!.managedFileName,
          ),
        );

logoBytes = result.value;
```

This is accepted implementation precedent, not scope authority. Current Inflows
source has the same identity/gate/managed-filename/nullability contract, so the
same existing query path is sufficient without new architecture.

### Existing application query contract

The live path is:

```text
ApplicationScope.of(context)
-> ApplicationBoundary.queries
-> ApplicationQueries.businessLogo
-> LoadBusinessLogoQueryHandler.execute
-> BusinessIdentityRepository.loadLogoBytes
-> ApplicationQueryResult<Uint8List?>.value
```

Repository inspection proves:

```text
QUERY_ALREADY_EXISTS = YES
HANDLER_ALREADY_EXISTS = YES
REPOSITORY_PORT_ALREADY_EXISTS = YES
QUERY_REGISTRY_ALREADY_EXISTS = YES
APPLICATION_SCOPE_AVAILABLE = YES
RUNTIME_COMPOSITION_AVAILABLE = YES

NEW_QUERY_REQUIRED = NO
NEW_HANDLER_REQUIRED = NO
NEW_REPOSITORY_REQUIRED = NO
NEW_APPLICATION_BOUNDARY_REQUIRED = NO
NEW_PROVIDER_REQUIRED = NO
NEW_COMPOSITION_REQUIRED = NO
```

`LoadBusinessLogoQuery` accepts the exact `String managedFileName`.
`LoadBusinessLogoQueryHandler` returns
`ApplicationQueryResult<Uint8List?>`, preserves the repository's present,
empty, or null byte value, and identifies the read authority as `managedFile`.
`AppCompositionRoot` constructs the handler using the existing business
identity repository, and `main.dart` mounts the resulting boundary through
`ApplicationScope` above the UI.

Implementation must stop rather than add architecture if any of these facts
drifts before implementation begins.

## H. Architectural Migration Boundary

### Before

```text
Inflows presentation `_exportPdf`
-> AppRepositories.businessIdentityRepository.loadLogoBytes(...)
-> managed logo bytes
```

### After

```text
Inflows presentation `_exportPdf`
-> ApplicationScope.of(context).queries.businessLogo
-> LoadBusinessLogoQuery(exact managed filename)
-> existing LoadBusinessLogoQueryHandler
-> existing BusinessIdentityRepository.loadLogoBytes
-> ApplicationQueryResult<Uint8List?>.value
-> unchanged `logoBytes` builder input
```

### Exact future production mutation

Implementation must modify exactly:

```text
lib/features/financial_reports/inflows_report_screen.dart

SYMBOL = _InflowsReportScreenState._exportPdf
CHANGE_TYPE = ONE_OWNERSHIP_EDGE_REPLACEMENT_PLUS_TWO_EXISTING_IMPORTS
```

The implementation sequence is deterministic:

1. add the existing `LoadBusinessLogoQuery` import;
2. add the existing `ApplicationScope` import;
3. retain `AppRepositories.businessIdentityRepository.loadIdentity()`;
4. retain `Uint8List? logoBytes`;
5. retain `identity.hasLogo && identity.logo != null`;
6. replace only the direct `.loadLogoBytes(...)` call with one existing
   `queries.businessLogo.execute(LoadBusinessLogoQuery(...))` call;
7. forward `identity.logo!.managedFileName` unchanged;
8. assign only `result.value` to `logoBytes`;
9. retain account-label derivation after the logo branch;
10. retain exact builder arguments and `_showExportResult` behavior; and
11. leave `_exportCsv` untouched.

```text
PRODUCTION_ADD = NONE
PRODUCTION_DELETE = NONE
EXPECTED_PRODUCTION_FILE_COUNT = 1
AUTHORIZED_BEHAVIORAL_CHANGE = ONE_DEPENDENCY_OWNERSHIP_EDGE_ONLY
```

Any need for a second production file or application-contract change is a
mandatory governance stop.

### BuildContext/analyzer handling

The identity read is awaited before `ApplicationScope.of(context)`. The
accepted Transfer predecessor therefore carries one narrow suppression on the
scope expression:

```dart
final result =
    // ignore: use_build_context_synchronously
    await ApplicationScope.of(context).queries.businessLogo.execute(...);
```

Inflows implementation must use the same explanatory comment and narrow
suppression. It must not move scope resolution before identity, add a mounted
early return, cache `context` or the scope earlier, change failure behavior, or
turn this migration into lifecycle refactoring.

## I. Behavioral Invariants

### Ownership and ordering

1. `_report == null` remains the first export guard.
2. `AppRepositories.businessIdentityRepository.loadIdentity()` remains exact.
3. The business-identity lookup is not migrated.
4. Identity loads before logo eligibility is evaluated.
5. `Uint8List? logoBytes` remains nullable.
6. `identity.hasLogo && identity.logo != null` remains the exact query gate.
7. No-logo and invalid-logo metadata perform zero logo queries and no scope
   lookup.
8. Valid metadata executes exactly one existing business-logo query.
9. `identity.logo!.managedFileName` is forwarded unchanged.
10. `result.value` reaches `logoBytes` without transformation.
11. Present, empty, and null byte object semantics remain distinct.
12. No direct handler construction or presentation-owned `.loadLogoBytes(`
    call remains in the governed method.
13. No write is introduced.

### Inflows report behavior

14. `_service.inflowsReport` ownership remains unchanged.
15. Financial-account loading remains locator-owned and unchanged.
16. From/to date selection and reset behavior remain unchanged.
17. `_accountIdFilter` and account dropdown behavior remain unchanged.
18. Inflow inclusion/exclusion, date boundaries, account filtering,
    deterministic ordering, totals, transfer handling, reversals, and
    read-only report semantics remain unchanged.
19. `accountLabel` derivation remains after the logo branch and reaches the
    builder unchanged.
20. Permissions, navigation, PDF/CSV button enablement, loading, empty, error,
    summary, breakdown, and row UI remain unchanged.
21. CSV export and CSV error behavior remain unchanged.

### PDF and user-visible contracts

22. `FinancialReportPdfBuilder.buildInflowsReport` is not modified.
23. Exact `_report!`, `accountLabel`, `identity`, and nullable `logoBytes`
    remain the builder inputs.
24. PDF content, title, rows, totals, branding, RTL, typography, layout, file
    naming, output directory, and file writes remain unchanged.
25. `_showExportResult(file)` and success UX remain unchanged.
26. The catch, mounted check, red snackbar, and exact
    `تعذر إنشاء ملف PDF.` message remain unchanged.
27. Query/repository exceptions remain behind the safe user-visible contract
    and do not expose internal text.
28. Database state and financial repository behavior remain unchanged.

## J. Implementation Allowlist

### Production allowlist — exactly one modification

```text
lib/features/financial_reports/inflows_report_screen.dart
```

### Test allowlist — exactly one addition

```text
test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_test.dart
```

This descriptive snake-case name preserves the governed predecessor and
successor identities without inventing a phase number.

### Test allowlist — exactly nine modifications

```text
test/phase108i_second_read_only_ui_query_migration_test.dart
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
test/phase108n_settings_logo_preview_query_migration_test.dart
test/phase108o_printable_document_scaffold_logo_query_migration_test.dart
test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart
test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart
test/phase108r_payment_method_report_pdf_logo_query_migration_test.dart
test/post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart
```

Eight files carry current `138/36/154/12` inventory expectations. Five carry
exact direct-read membership containing Inflows. Together, the union is exactly
the nine files above. Only deterministic `Inflows` membership removal and the
exact inventory delta may change. No assertion may be weakened, broadened,
skipped, or converted from exact-set equality to loose membership.

### Exact future implementation path budget

```text
PRODUCTION_MODIFY = 1
TEST_ADD = 1
TEST_MODIFY = 9
TOTAL_CHANGED_PATHS = 11

QUERY_FILES = 0
HANDLER_FILES = 0
REPOSITORY_FILES = 0
APPLICATION_BOUNDARY_FILES = 0
APPLICATION_SCOPE_FILES = 0
COMPOSITION_FILES = 0
PDF_BUILDER_FILES = 0
CSV_FILES = 0
DOCUMENTATION_FILES = 0
CONFIG_FILES = 0
DEPENDENCY_FILES = 0
DATABASE_OR_SUPABASE_FILES = 0
PLATFORM_FILES = 0
GENERATED_FILES = 0
```

An additional production file or twelfth changed path is not authorized.

## K. Explicit Prohibitions

```text
IDENTITY_LOOKUP_MIGRATION = FORBIDDEN
REPORT_DATA_QUERY_MIGRATION = FORBIDDEN
ACCOUNT_QUERY_MIGRATION = FORBIDDEN

OUTFLOWS_REPORT_MIGRATION = FORBIDDEN
EXPENSE_ANALYSIS_REPORT_MIGRATION = FORBIDDEN
ADVANCES_REFUNDS_REPORT_MIGRATION = FORBIDDEN
BATCHING = FORBIDDEN

QUERY_DEFINITION_CHANGE = FORBIDDEN
QUERY_HANDLER_CHANGE = FORBIDDEN
QUERY_REGISTRY_CHANGE = FORBIDDEN
REPOSITORY_CHANGE = FORBIDDEN
APPLICATION_BOUNDARY_CHANGE = FORBIDDEN
APPLICATION_SCOPE_CHANGE = FORBIDDEN
COMPOSITION_ROOT_CHANGE = FORBIDDEN

PDF_BUILDER_CHANGE = FORBIDDEN
CSV_EXPORTER_CHANGE = FORBIDDEN
FILTER_CHANGE = FORBIDDEN
FINANCIAL_CALCULATION_CHANGE = FORBIDDEN
UI_CHANGE = FORBIDDEN
NAVIGATION_CHANGE = FORBIDDEN
PERMISSION_CHANGE = FORBIDDEN
ERROR_CONTRACT_CHANGE = FORBIDDEN
FILE_NAME_CHANGE = FORBIDDEN
FILE_WRITE_CHANGE = FORBIDDEN

DATABASE_OR_SUPABASE_CHANGE = FORBIDDEN
DEPENDENCY_CHANGE = FORBIDDEN
CONFIGURATION_CHANGE = FORBIDDEN
PLATFORM_CHANGE = FORBIDDEN
GENERATED_FILE_CHANGE = FORBIDDEN
BROAD_REFACTOR = FORBIDDEN

TRANSFER_IMPLEMENTATION_REOPENING = FORBIDDEN
PHASE_108R_REOPENING = FORBIDDEN
NUMBERED_PHASE_INVENTION = FORBIDDEN
```

`PdfExportService._loadBranding` and
`BackupExportService._identityWithLogoJson` remain separate governance classes
and are excluded.

## L. Test Strategy

### Existing Inflows coverage disposition

`test/phase9a_inflows_outflows_reports_test.dart` protects permissions,
Inflows report membership, filters, date boundaries, ordering, totals,
transfer/reversal behavior, file naming, and read-only integrity.
`test/financial_inflows_summary_tool_test.dart` protects the canonical
read-only Inflows summary boundary. Neither owns the presentation logo-query
seam, so neither should be modified.

The accepted Transfer focused suite provides the appropriate runtime spies,
composition copy, widget harness, source-region guard, and inventory pattern.
A new narrow Inflows-focused suite is therefore required rather than adding
ownership assertions to unrelated report-domain tests.

### New focused suite — ten required behaviors

The new focused suite must contain ten concrete tests equivalent in strength
to the accepted Transfer suite:

1. without a loaded report, PDF remains disabled and performs zero identity,
   direct-logo, query-logo, or write operations;
2. the existing query preserves present byte object identity;
3. the existing query preserves empty byte object identity;
4. the existing query preserves repository `null`;
5. valid metadata loads locator-owned identity first, then issues exactly one
   query with the exact managed filename, with zero presentation-owned direct
   logo reads and zero writes;
6. absent metadata performs no `ApplicationScope` lookup and no logo read;
7. invalid metadata performs no `ApplicationScope` lookup and no logo read;
8. query failure preserves `تعذر إنشاء ملف PDF.` and hides internal exception
   text;
9. a source/order guard freezes the governed method, account-label/builder/CSV
   neighboring contracts, exact imports, and prohibited operations; and
10. an inventory guard freezes exact post-migration counts and membership sets.

### Harness constraints

Reuse only established production/test seams:

- in-memory production composition;
- mutable locator repository spy for the retained identity path;
- a copied `ApplicationBoundary` whose existing `businessLogo` handler uses a
  query repository spy;
- existing `AuthScope` owner credentials and export permission;
- `ApplicationScope` only where the query should be reachable;
- normal automatic empty Inflows report loading for ordinary paths; and
- source-region assertions instead of a production callback or PDF-builder
  testing hook.

The initial widget pump may assert the null-report disabled state before
automatic `_applyFilters` completes. No invented account-selection
precondition is allowed. Valid-query cases may terminate intentionally at the
query to avoid the static PDF builder while proving ownership. Absent/invalid
metadata cases may omit `ApplicationScope`, proving the false gate never
resolves it.

### Source-region contract

Isolate `Future<void> _exportPdf()` through, but not including,
`Future<void> _exportCsv()`. Prove this order:

```text
_report null guard
< locator-owned loadIdentity
< identity.hasLogo && identity.logo != null
< ApplicationScope businessLogo query
< accountLabel derivation
< FinancialReportPdfBuilder.buildInflowsReport
< _showExportResult
```

Also prove:

- both application imports are present;
- the exact managed filename is forwarded;
- `logoBytes = result.value;` remains exact;
- builder arguments include exact `_report!`, `accountLabel`, `identity`, and
  `logoBytes`;
- the safe PDF message remains exact;
- `_exportCsv` still calls `exportInflowsReport(report: _report!)`;
- `_service.inflowsReport` and all date/account filters remain present; and
- the governed region contains none of `.loadLogoBytes(`,
  `LoadBusinessLogoQueryHandler(`, `saveIdentity`, `saveLogoBytes`, or
  `deleteLogoFile`.

Do not ban all `AppRepositories` references: exactly three legitimate locator
uses intentionally remain in the Inflows screen.

### Existing guard changes

Current guard declarations total 93 tests across the nine impacted files. The
implementation may adjust only:

```text
138 / 36 / 154 / 12
->
137 / 36 / 153 / 13
```

and remove only
`lib/features/financial_reports/inflows_report_screen.dart` from exact
guard-style/invocation sets where present.

### Unchanged regression files

Run but do not modify:

```text
test/phase42_pdf_export_foundation_test.dart
test/phase68_business_logo_invoice_windows_icon_test.dart
test/phase9a_inflows_outflows_reports_test.dart
test/financial_inflows_summary_tool_test.dart
```

These files currently declare 117 tests in total. The implementation report
must record the actual runner count rather than relying only on static count.

## M. Verification Matrix

### Pre-change baseline

Before production mutation, run the exact impacted guard batch:

```powershell
flutter test `
  test\phase108i_second_read_only_ui_query_migration_test.dart `
  test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart `
  test\phase108m_shared_business_identity_header_logo_query_migration_test.dart `
  test\phase108n_settings_logo_preview_query_migration_test.dart `
  test\phase108o_printable_document_scaffold_logo_query_migration_test.dart `
  test\phase108p_account_balance_report_pdf_logo_query_migration_test.dart `
  test\phase108q_account_statement_report_pdf_logo_query_migration_test.dart `
  test\phase108r_payment_method_report_pdf_logo_query_migration_test.dart `
  test\post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart
```

Expected current declaration count is 93; record the actual pass/fail/skip
count and exit code.

Run the unchanged Inflows/PDF regression batch separately:

```powershell
flutter test `
  test\phase42_pdf_export_foundation_test.dart `
  test\phase68_business_logo_invoice_windows_icon_test.dart `
  test\phase9a_inflows_outflows_reports_test.dart `
  test\financial_inflows_summary_tool_test.dart
```

Any baseline failure must be classified before editing and must not be absorbed
into the migration.

### Post-change focused and regression gates

Run the new focused suite separately:

```powershell
flutter test `
  test\post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_test.dart
```

Then rerun the exact nine-file impacted guard batch and the exact four-file
unchanged regression batch above. Record every command, exit code, passed,
failed, and skipped count separately. No retry-only pass may conceal an
unexplained failure.

### Format, analyzer, and full suite

Format only authorized changed Dart paths as necessary, then require:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
git diff --check
git diff --cached --check
git status --porcelain=v1 --untracked-files=all
```

The repository formatter check must require zero changes. Analyzer must report
no new warning or error. The sequential full suite is mandatory and cannot be
replaced by focused suites, retries, skips, guard weakening, or warning
relaxation.

### Current live inventory

The planning session independently measured:

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 138
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 154
APPLICATION_SCOPE_CONSUMERS = 12
GUARD_STYLE_LOGO_READ_FILES = 8
ACTUAL_LOGO_INVOCATION_FILES = 7

INFLOWS_APP_REPOSITORIES_REFERENCES = 4
INFLOWS_IS_LOCATOR_FILE = YES
INFLOWS_IS_APPLICATION_SCOPE_CONSUMER = NO
```

Current guard-style set:

```text
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
lib/core/business_identity/business_identity_repository.dart
lib/features/exports/pdf_export_service.dart
lib/features/financial_reports/advances_and_refunds_report_screen.dart
lib/features/financial_reports/expense_analysis_report_screen.dart
lib/features/financial_reports/inflows_report_screen.dart
lib/features/financial_reports/outflows_report_screen.dart
```

Current invocation set is the same without the repository port declaration.

### Exact post-implementation inventory target

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 137
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 153
APPLICATION_SCOPE_CONSUMERS = 13
GUARD_STYLE_LOGO_READ_FILES = 7
ACTUAL_LOGO_INVOCATION_FILES = 6

INFLOWS_APP_REPOSITORIES_REFERENCES = 3
INFLOWS_REMAINS_LOCATOR_FILE = YES
INFLOWS_BECOMES_APPLICATION_SCOPE_CONSUMER = YES
DIRECT_LOGO_READ_REMOVAL = inflows_report_screen.dart ONLY
```

Exact post-migration guard-style set:

```text
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
lib/core/business_identity/business_identity_repository.dart
lib/features/exports/pdf_export_service.dart
lib/features/financial_reports/advances_and_refunds_report_screen.dart
lib/features/financial_reports/expense_analysis_report_screen.dart
lib/features/financial_reports/outflows_report_screen.dart
```

Exact post-migration invocation set is the same without
`lib/core/business_identity/business_identity_repository.dart`.

No inventory discrepancy may be silently rebased into tests.

### Stop conditions

Implementation stops without widening scope if it discovers:

- an entry baseline or owner-decision mismatch;
- inventory drift inconsistent with this plan;
- an unavailable `ApplicationScope`/`businessLogo` path;
- a different managed-filename or result-value contract;
- a required second production file;
- a required query, handler, repository, boundary, composition, builder, CSV,
  database, dependency, platform, or generated-file change;
- a required behavior or error-contract change;
- a required test weakening or new production testing hook;
- format, analyzer, targeted, regression, or full-suite failure caused by the
  implementation; or
- a changed path outside the exact eleven-path allowlist.

## N. Implementation Commit Contract

The future implementation session must start only from the separately
remote-locked version of this planning commit. After all gates pass it must
stage exactly the eleven authorized paths and create one atomic, non-merge
local implementation commit with subject:

```text
feat: migrate inflows report pdf logo query
```

The implementation commit must contain no planning-document edit, unrelated
formatting, other report migration, application infrastructure change,
generated artifact, dependency mutation, or configuration change. Amend,
merge, rebase, squash, cherry-pick, reset, and history rewriting are forbidden.

If a post-commit defect is discovered, the implementation commit must not be
silently amended; the session must report and stop for governed recovery.

## O. Local Closure Requirements

Implementation local closure will require all of the following:

1. exact remotely locked planning baseline and clean entry;
2. one production file and one ownership edge only;
3. one new ten-test focused suite and nine deterministic guard updates;
4. exact four unchanged regressions remain unmodified and pass;
5. exact `137/36/153/13`, guard-style `7`, invocation `6`, and membership sets;
6. exact eleven-path allowlist;
7. formatter, analyzer, targeted, regression, and sequential full-suite gates;
8. complete unstaged and staged diff review with both whitespace checks;
9. exactly one direct-child implementation commit;
10. clean worktree, empty index, no untracked file or stash; and
11. zero remote mutation during implementation local closure.

## P. Remote Lock Boundary

This planning session is local-closure-only:

```text
PUSH = FORBIDDEN
TAG_CREATION = FORBIDDEN
TAG_PUSH = FORBIDDEN
REMOTE_MUTATION = NONE
```

The planning commit must be published only by the separately authorized
planning remote-lock session. Implementation remains unauthorized until that
remote lock independently verifies the exact planning commit and artifact.

The later implementation session must likewise create only a local closure and
use its own separate remote-lock session.

## Q. Authorization State

```text
OWNER_SUCCESSOR_SCOPE_DECISION_LOCAL_CLOSURE = COMPLETE
OWNER_SUCCESSOR_SCOPE_DECISION_REMOTE_LOCK = COMPLETE

CANONICAL_SUCCESSOR_SCOPE =
INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION

PLANNING_LOCAL_CLOSURE = COMPLETE
PLANNING_REMOTE_LOCK = NOT_STARTED

IMPLEMENTATION_AUTHORIZED = NO
IMPLEMENTATION_STARTED = NO

PHASE_108S_IS_AUTHORIZED = NO
PHASE_108T_IS_AUTHORIZED = NO
NUMBERED_SUCCESSOR_PHASE_ESTABLISHED = NO
```

Planning-session mutation audit:

```text
PLANNING_DOCUMENTS_CHANGED = 1
PRODUCTION_FILES_CHANGED = 0
TEST_FILES_CHANGED = 0
CONFIG_FILES_CHANGED = 0
DEPENDENCY_FILES_CHANGED = 0
DATABASE_FILES_CHANGED = 0
PLATFORM_FILES_CHANGED = 0
GENERATED_FILES_CHANGED = 0

PLANNING_COMMITS_TO_CREATE = 1
TAGS_TO_CREATE = 0
BRANCH_PUSHES = 0
REMOTE_MUTATION = NONE

FLUTTER_TEST_RUN_THIS_SESSION = NO
FLUTTER_ANALYZE_RUN_THIS_SESSION = NO
BUILD_RUN_THIS_SESSION = NO
```

Tests and analyzer are not required for this documentation-only planning
mutation. The planning gates are exact repository identity, locked-object and
authority verification, full source/query/composition/test inspection, fresh
inventory measurement, complete diff review, and path control.

## R. Next Authorized Session

Planning local closure requires this document to be the sole committed path in
one non-merge direct child of
`da6c782c9dedcb5c05a49d5cbec99f2b82087acd` with subject:

```text
docs: plan inflows report pdf logo query migration
```

Expected local-closure topology:

```text
FINAL_LOCAL_HEAD = THIS_PLANNING_COMMIT
FINAL_LOCAL_DIRECT_PARENT = da6c782c9dedcb5c05a49d5cbec99f2b82087acd
FINAL_REMOTE_HEAD = da6c782c9dedcb5c05a49d5cbec99f2b82087acd
FINAL_MERGE_BASE = da6c782c9dedcb5c05a49d5cbec99f2b82087acd
FINAL_AHEAD = 1
FINAL_BEHIND = 0

WORKTREE = CLEAN
INDEX = EMPTY
UNTRACKED = NONE
STASH = EMPTY
LOCAL_PLANNING_TAG = NOT_CREATED
REMOTE_MUTATION = NONE
```

After verified local closure:

```text
POST_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION_INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING_LOCAL_CLOSURE =
COMPLETE

POST_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION_INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING_REMOTE_LOCK =
NOT_STARTED

IMPLEMENTATION_AUTHORIZED = NO
IMPLEMENTATION_STARTED = NO

NEXT_AUTHORIZED_SESSION =
POST_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION_INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING_REMOTE_LOCK
```

No planning remote lock, implementation, tag, or push occurs in this session.
