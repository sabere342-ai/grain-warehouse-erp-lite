# Post-Phase 108R Transfer Report PDF Logo Query Migration Plan

## A. Planning Result

```text
SESSION_ID =
POST_PHASE_108R_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING

SESSION_MODE = FORENSIC_PLANNING_LOCAL_CLOSURE_ONLY
DATE = 2026-08-30

CANONICAL_SUCCESSOR_SCOPE =
TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY =
POST_PHASE_108R_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY_TYPE = NONNUMERIC_SEMANTIC_IDENTITY
PLANNING_RESULT = IMPLEMENTATION_READY
IMPLEMENTATION = NOT_STARTED
```

This plan converts the remotely locked owner-governance decision into one
implementation-ready ownership migration. It does not reopen selection,
assign an ordinal, plan any deferred report, or implement the migration.

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

ENTRY_LOCAL_HEAD = ca8fc49bd0a494bf8eb355f184bacf39535101c1
ENTRY_REMOTE_HEAD = ca8fc49bd0a494bf8eb355f184bacf39535101c1
ENTRY_MERGE_BASE = ca8fc49bd0a494bf8eb355f184bacf39535101c1
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0

ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
```

No interrupted planning work or unexplained repository mutation was found.

## D. Governing Lock Verification

The immediate governance-resolution baseline was independently verified:

```text
GOVERNANCE_RESOLUTION_COMMIT =
ca8fc49bd0a494bf8eb355f184bacf39535101c1

GOVERNANCE_RESOLUTION_DIRECT_PARENT =
1a261558b7ff184172188ca73cf79fd8b7c1e64a

GOVERNANCE_RESOLUTION_SUBJECT =
docs: resolve post-108r successor scope

GOVERNANCE_RESOLUTION_PATH =
docs/POST-PHASE-108R-SUCCESSOR-SCOPE-GOVERNANCE-RESOLUTION.md

GOVERNANCE_RESOLUTION_BLOB =
c8da7c5ac694308e87d54f32be3d5f915e902d86
```

Its only committed path is the governance-resolution document. The locked
Phase 108R implementation evidence also remains exact locally and remotely:

```text
PHASE_108R_IMPLEMENTATION_COMMIT =
ded903e95e0b6f08e41409dac8200f1ed0367644

PHASE_108R_IMPLEMENTATION_TAG = phase-108r-implementation-locked
LOCAL_TAG_OBJECT = f9f1382fabb3ced2220a9f199487a7b6166d66db
REMOTE_TAG_OBJECT = f9f1382fabb3ced2220a9f199487a7b6166d66db
LOCAL_PEELED_COMMIT = ded903e95e0b6f08e41409dac8200f1ed0367644
REMOTE_PEELED_COMMIT = ded903e95e0b6f08e41409dac8200f1ed0367644
TAG_TYPE = tag
ANNOTATED = YES
GOVERNING_LOCKS_VALID = YES
```

## E. Canonical Semantic Identity

```text
SUCCESSOR_IDENTITY =
POST_PHASE_108R_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY_TYPE = NONNUMERIC_SEMANTIC_IDENTITY
PHASE_108S_IS_AUTHORIZED = NO
PHASE_108T_IS_AUTHORIZED = NO
HISTORICAL_108S_MEANING_REACTIVATED = NO
HISTORICAL_108T_MEANING_REACTIVATED = NO
ORDINAL_SUCCESSION_USED_AS_AUTHORITY = NO
```

The identity is inherited unchanged from the remote-locked owner resolution.
This plan neither renames it nor creates a general successor naming rule.

## F. Scope Freeze

```text
SCOPE_IN = ONE_TRANSFER_REPORT_PDF_MANAGED_LOGO_BYTE_OWNERSHIP_SEAM

PRIMARY_PRODUCTION_TARGET =
lib/features/financial_reports/transfer_report_screen.dart

TARGET_SYMBOL = _TransferReportScreenState._exportPdf
READ_WRITE_CLASSIFICATION = READ_ONLY
EXPECTED_PRODUCTION_FILE_COUNT = 1
AUTHORIZED_BEHAVIORAL_CHANGE = ONE_DEPENDENCY_OWNERSHIP_EDGE_ONLY
```

Only the direct managed-logo-byte read within `_exportPdf` moves from the
presentation-owned repository locator edge to the existing application query.
The business-identity read remains locator-owned. No other Transfer behavior
or report consumer is included.

## G. Current Runtime Seam

Current source inspection establishes this order:

```text
if (_report == null) return
→ AppRepositories.businessIdentityRepository.loadIdentity()
→ Uint8List? logoBytes
→ identity.hasLogo && identity.logo != null
→ AppRepositories.businessIdentityRepository.loadLogoBytes(
    identity.logo!.managedFileName)
→ FinancialReportPdfBuilder.buildTransferReport(
    report: _report!,
    businessIdentity: identity,
    logoBytes: logoBytes)
→ _showExportResult(file)
```

The target file currently contains four literal `AppRepositories.` references:

1. `FinancialReportService` construction;
2. account loading;
3. business-identity loading; and
4. the selected managed-logo-byte loading edge.

The first three remain. The file remains a locator consumer after the
migration. Its existing PDF catch displays `تعذر إنشاء ملف PDF.` only when
mounted. `_exportCsv` is a separate neighboring method and uses
`FinancialReportCsvExporter.exportTransferReport(report: _report!)`.

## H. Locked Predecessor Pattern

The accepted Phase 108R production predecessor is
`payment_method_report_screen.dart`. It imports exactly:

```dart
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
```

Inside its valid-logo branch it retains the locator identity read, then uses:

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

The Transfer implementation must use this proven structure without copying
Phase 108R naming or changing the surrounding Transfer contract.

## I. Application Query Contract Verification

The live application path is already complete:

```text
ApplicationScope.of(context)
→ ApplicationBoundary.queries
→ ApplicationQueries.businessLogo
→ LoadBusinessLogoQueryHandler.execute
→ BusinessIdentityRepository.loadLogoBytes
→ ApplicationQueryResult<Uint8List?>.value
```

Repository evidence establishes:

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
`LoadBusinessLogoQueryHandler` returns `ApplicationQueryResult<Uint8List?>`,
preserves the repository byte object or null, and marks the read authority as
`managedFile`. `AppCompositionRoot` already constructs the handler from the
captured business-identity repository. `main.dart` mounts the resulting
`ApplicationBoundary` in `ApplicationScope` above the application UI.

If any of these facts differs at implementation entry, implementation stops
for governance review instead of adding architecture.

## J. Exact Planned Production Mutation

### EXPECTED_MODIFY

```text
lib/features/financial_reports/transfer_report_screen.dart

SYMBOL = _TransferReportScreenState._exportPdf
CHANGE_TYPE = REPLACEMENT_PLUS_EXISTING_APPLICATION_QUERY_IMPORTS
```

The implementation must:

1. add the existing query declaration import;
2. add the existing `ApplicationScope` import;
3. retain `loadIdentity()` exactly through `AppRepositories`;
4. retain `Uint8List? logoBytes`;
5. retain `identity.hasLogo && identity.logo != null`;
6. replace only the direct `.loadLogoBytes(...)` expression with one
   `queries.businessLogo.execute(LoadBusinessLogoQuery(...))` call;
7. forward `identity.logo!.managedFileName` unchanged;
8. assign only `result.value` to `logoBytes`; and
9. retain the existing Transfer builder and result handling unchanged.

### EXPECTED_ADD / EXPECTED_DELETE

```text
PRODUCTION_ADD = NONE
PRODUCTION_DELETE = NONE
```

Any need for a second production file is a mandatory stop.

## K. Exact Planned Test Mutation

### New focused test

```text
TEST_ADD =
test/post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart
```

No existing post-Phase-108R semantic test naming precedent exists. This path
uses repository-standard Dart snake case while directly preserving the locked
nonnumeric semantic identity and selected Transfer seam.

The test uses only established seams from the Phase 108R harness:

- in-memory production composition;
- mutable locator repository spy for the retained identity path;
- a copied `ApplicationBoundary` whose existing `businessLogo` handler uses a
  query repository spy;
- `AuthScope` with the existing owner credentials and permissions;
- `ApplicationScope` only on paths expected to reach the query; and
- source-region guards instead of a production callback or builder hook.

The focused suite must contain ten concrete tests equivalent in strength to
the accepted Phase 108R suite:

1. no loaded report disables PDF and performs zero identity/query work;
2. the existing query preserves present byte identity;
3. it preserves empty byte identity;
4. it preserves repository null;
5. valid metadata loads locator identity before exactly one exact-filename
   query, with zero presentation-owned logo reads and zero writes;
6. absent metadata performs no `ApplicationScope` lookup or logo read;
7. invalid metadata performs no `ApplicationScope` lookup or logo read;
8. query failure retains `تعذر إنشاء ملف PDF.` and hides internal text;
9. a source/order test freezes the target and neighboring contracts; and
10. an inventory test freezes the exact post-migration counts and sets.

The initial widget pump is sufficient for the null-report assertion before
the screen's automatic `_applyFilters` finishes. Normal paths wait for the
existing automatic report load; no invented account-selection precondition is
allowed. Valid-query cases intentionally fail at the query to stop before the
static PDF builder. Absent/invalid cases omit `ApplicationScope` and fail PDF
asset loading only after proving the false gate does not attempt a scope
lookup.

### Existing guard modifications

Exactly these eight current guards have deterministic inventory or membership
expectations affected by removing Transfer's direct call:

```text
test/phase108i_second_read_only_ui_query_migration_test.dart
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
test/phase108n_settings_logo_preview_query_migration_test.dart
test/phase108o_printable_document_scaffold_logo_query_migration_test.dart
test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart
test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart
test/phase108r_payment_method_report_pdf_logo_query_migration_test.dart
```

The Phase 108I/M/N/O/P/Q/R inventory values change only from
`139/36/155/11` to `138/36/154/12`. Phase 108L/O/Q/R direct-read membership
expectations remove only the Transfer path. No assertion may be weakened,
skipped, broadened, or adjusted beyond the exact mathematical delta.

### Unchanged relevant regressions

```text
test/phase42_pdf_export_foundation_test.dart
test/phase68_business_logo_invoice_windows_icon_test.dart
test/phase79_account_based_financial_reports_test.dart
test/financial_transfer_summary_tool_test.dart
```

Phase 79 protects Transfer service filters, ordering, reversal semantics,
integer arithmetic, and PDF/CSV naming. The Transfer summary tool protects the
canonical report rows and read-only semantics. Phase 42 and Phase 68 retain
the shared PDF/logo foundation coverage. They are run but not modified.

## L. Behavioral Invariants

### Export ownership and ordering

1. `_report == null` remains the first export guard.
2. `AppRepositories.businessIdentityRepository.loadIdentity()` remains exact.
3. The identity lookup is not migrated.
4. `Uint8List? logoBytes` remains nullable.
5. `identity.hasLogo && identity.logo != null` remains the exact query gate.
6. Absent or invalid metadata performs zero logo queries and no scope lookup.
7. Valid metadata executes exactly one existing business-logo query.
8. `identity.logo!.managedFileName` is forwarded without transformation.
9. `result.value` reaches `logoBytes` without transformation.
10. Present, empty, and null byte semantics remain distinct and unchanged.
11. Locator identity loading occurs before the application query.

### Transfer report behavior

12. `_service.transferReport` ownership and automatic loading remain unchanged.
13. Account loading remains locator-owned and unchanged.
14. From/to dates remain unchanged.
15. Source-account, destination-account, any-account, and reversal filters
    remain unchanged.
16. Transfer row ordering, totals, reversal status, and rendering remain
    unchanged.
17. Authentication, view/export permissions, navigation, and back behavior
    remain unchanged.
18. Visible loading, empty, error, filter, summary, and row UI remains
    unchanged.
19. CSV export and its error behavior remain unchanged.

### PDF and failure behavior

20. `FinancialReportPdfBuilder.buildTransferReport` remains unchanged.
21. Exact `_report!`, exact `identity`, and nullable `logoBytes` remain the
    builder inputs.
22. PDF content, branding, RTL, typography, layout, tables, and totals remain
    unchanged.
23. `PdfFileNaming.transferReport(report.toDate)` remains unchanged.
24. Output directory and file writes remain unchanged.
25. `_showExportResult(file)` and success notification remain unchanged.
26. The PDF catch, mounted guard, red snackbar, and exact safe message remain
    unchanged.
27. Query/repository failures remain inside the safe PDF contract and do not
    expose internal exception text.
28. No identity, logo, database, or other write is introduced.
29. No direct `LoadBusinessLogoQueryHandler` construction is introduced in
    presentation code.

## M. Analyzer / BuildContext Handling

The identity lookup is awaited before the governed scope lookup, so the
accepted predecessor carries one narrow suppression directly on the
`ApplicationScope.of(context)` expression:

```dart
final result =
    // ignore: use_build_context_synchronously
    await ApplicationScope.of(context).queries.businessLogo.execute(...);
```

The Transfer implementation must reuse this exact analyzer-safe structure and
the explanatory predecessor comment. It must not move the scope lookup before
identity, add a mounted early return, cache context/scope earlier, or introduce
a lifecycle refactor. The repository-wide analyzer must still report no issue.

## N. Mandatory Test Gates

### Pre-change guard and regression baseline

Before source mutation, run:

```powershell
flutter test `
  test\phase108i_second_read_only_ui_query_migration_test.dart `
  test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart `
  test\phase108m_shared_business_identity_header_logo_query_migration_test.dart `
  test\phase108n_settings_logo_preview_query_migration_test.dart `
  test\phase108o_printable_document_scaffold_logo_query_migration_test.dart `
  test\phase108p_account_balance_report_pdf_logo_query_migration_test.dart `
  test\phase108q_account_statement_report_pdf_logo_query_migration_test.dart `
  test\phase108r_payment_method_report_pdf_logo_query_migration_test.dart

flutter test `
  test\phase42_pdf_export_foundation_test.dart `
  test\phase68_business_logo_invoice_windows_icon_test.dart `
  test\phase79_account_based_financial_reports_test.dart `
  test\financial_transfer_summary_tool_test.dart
```

Any pre-existing failure must be classified before editing and must not be
absorbed into this migration.

### Post-change focused and affected gates

```powershell
flutter test test\post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart

flutter test `
  test\phase108i_second_read_only_ui_query_migration_test.dart `
  test\phase108l_dashboard_app_bar_business_logo_query_migration_test.dart `
  test\phase108m_shared_business_identity_header_logo_query_migration_test.dart `
  test\phase108n_settings_logo_preview_query_migration_test.dart `
  test\phase108o_printable_document_scaffold_logo_query_migration_test.dart `
  test\phase108p_account_balance_report_pdf_logo_query_migration_test.dart `
  test\phase108q_account_statement_report_pdf_logo_query_migration_test.dart `
  test\phase108r_payment_method_report_pdf_logo_query_migration_test.dart

flutter test `
  test\phase42_pdf_export_foundation_test.dart `
  test\phase68_business_logo_invoice_windows_icon_test.dart `
  test\phase79_account_based_financial_reports_test.dart `
  test\financial_transfer_summary_tool_test.dart
```

Each command's pass/fail and exact test count must be reported separately.

### Source-region guard

The focused test isolates source from `Future<void> _exportPdf()` up to, but
not including, `Future<void> _exportCsv()`. It proves:

```text
_report null guard
< locator-owned loadIdentity
< identity.hasLogo && identity.logo != null
< ApplicationScope businessLogo query
< FinancialReportPdfBuilder.buildTransferReport
< _showExportResult
```

It also proves both imports, exact managed filename, `logoBytes = result.value;`,
exact builder arguments, exact PDF failure text, and absence within the target
of `.loadLogoBytes(`, `LoadBusinessLogoQueryHandler(`, `saveIdentity`,
`saveLogoBytes`, and `deleteLogoFile`. Neighbor guards retain
`_service.transferReport`, all four Transfer filters, permission handling,
`FinancialReportCsvExporter.exportTransferReport`, and `_showExportResult`.
The guard must not ban the three legitimate retained `AppRepositories` uses.

## O. Mandatory Analyzer Gate

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
```

The format gate must report no required changes after formatting only the
authorized changed Dart paths. The analyzer may introduce no warning or error;
no ignore expansion beyond the one proven context suppression is allowed.

## P. Full-Suite Gate

```powershell
flutter test --concurrency=1
git diff --check
git diff --cached --check
git status --porcelain=v1 --untracked-files=all
```

The sequential full suite is mandatory and is not replaceable by focused
tests or retries. No skip, ignore, fatal-warning relaxation, or broad guard
rebasing may manufacture a pass.

## Q. Mutation Budget

### Current live inventory

The planning session independently measured:

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 139
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 155
APPLICATION_SCOPE_CONSUMERS = 11
GUARD_STYLE_LOGO_READ_FILES = 9
ACTUAL_LOGO_INVOCATION_FILES = 8

TRANSFER_APP_REPOSITORIES_REFERENCES = 4
TRANSFER_IS_LOCATOR_FILE = YES
TRANSFER_IS_APPLICATION_SCOPE_CONSUMER = NO
```

Current guard-style files are:

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

Current invocation files are the same set without the repository interface.

### Exact target inventory

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 138
FEATURE_SHARED_LOCATOR_FILES = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 154
APPLICATION_SCOPE_CONSUMERS = 12
GUARD_STYLE_LOGO_READ_FILES = 8
ACTUAL_LOGO_INVOCATION_FILES = 7

TRANSFER_APP_REPOSITORIES_REFERENCES = 3
TRANSFER_REMAINS_LOCATOR_FILE = YES
TRANSFER_BECOMES_APPLICATION_SCOPE_CONSUMER = YES
DIRECT_LOGO_READ_REMOVAL = transfer_report_screen.dart ONLY
```

The exact post-migration guard-style set is:

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

The invocation set is the same set without
`business_identity_repository.dart`.

### Implementation changed-path allowlist

```text
PRODUCTION_MODIFY = 1
TEST_ADD = 1
TEST_MODIFY = 8
TOTAL_CHANGED_PATHS = 10

QUERY_FILES = 0
HANDLER_FILES = 0
REPOSITORY_FILES = 0
COMPOSITION_FILES = 0
PDF_BUILDER_FILES = 0
CSV_FILES = 0
DOCUMENTATION_FILES = 0
CONFIG_FILES = 0
DEPENDENCY_FILES = 0
DATABASE_FILES = 0
PLATFORM_FILES = 0
GENERATED_FILES = 0
```

## R. Explicit Exclusions

```text
IDENTITY_LOOKUP_MIGRATION = FORBIDDEN
REPORT_DATA_QUERY_MIGRATION = FORBIDDEN
ACCOUNT_QUERY_MIGRATION = FORBIDDEN

INFLOWS_REPORT_MIGRATION = FORBIDDEN
OUTFLOWS_REPORT_MIGRATION = FORBIDDEN
EXPENSE_ANALYSIS_REPORT_MIGRATION = FORBIDDEN
ADVANCES_REFUNDS_REPORT_MIGRATION = FORBIDDEN

QUERY_DEFINITION_CHANGE = FORBIDDEN
QUERY_HANDLER_CHANGE = FORBIDDEN
QUERY_REGISTRY_CHANGE = FORBIDDEN
REPOSITORY_CHANGE = FORBIDDEN
APPLICATION_SCOPE_CHANGE = FORBIDDEN
COMPOSITION_ROOT_CHANGE = FORBIDDEN

PDF_BUILDER_CHANGE = FORBIDDEN
CSV_CHANGE = FORBIDDEN
FILTER_CHANGE = FORBIDDEN
UI_CHANGE = FORBIDDEN
NAVIGATION_CHANGE = FORBIDDEN
PERMISSION_CHANGE = FORBIDDEN
ERROR_CONTRACT_CHANGE = FORBIDDEN
FILE_NAME_CHANGE = FORBIDDEN
FILE_WRITE_CHANGE = FORBIDDEN

DATABASE_CHANGE = FORBIDDEN
DEPENDENCY_CHANGE = FORBIDDEN
PLATFORM_CHANGE = FORBIDDEN
GENERATED_FILE_CHANGE = FORBIDDEN
BROAD_REFACTOR = FORBIDDEN
BATCHING = FORBIDDEN
```

`PdfExportService._loadBranding` and
`BackupExportService._identityWithLogoJson` remain separate governance
problems and are not selected.

## S. Deferred Candidate Preservation

```text
INFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION
OUTFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION
EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION
ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION

DEFERRED != REJECTED
DEFERRED != AUTHORIZED
DEFERRED != AUTOMATIC_NEXT
```

No ordering among them is created by this plan.

## T. Implementation Commit Discipline

The later implementation must begin from the separately remote-locked version
of this planning commit. It must stage only the ten exact allowed paths after
all gates pass and create one atomic local implementation commit. Recommended
subject:

```text
feat: migrate transfer report pdf logo query
```

No planning-document edit, unrelated formatting, deferred migration,
infrastructure change, generated output, or dependency change may enter that
commit. No amend, merge, rebase, squash, cherry-pick, or history rewrite is
allowed.

## U. Implementation Local-Closure Requirements

Implementation local closure requires all of the following:

1. exact remote planning baseline and clean entry verification;
2. exact one-production-file implementation;
3. one new focused suite and eight exact guard updates;
4. focused, impacted-guard, and unchanged-regression commands pass;
5. `138/36/154/12`, guard-style `8`, and invocation `7` with exact sets;
6. format, analyzer, and sequential full suite pass;
7. complete diff inspection and ten-path allowlist pass;
8. `git diff --check` and cached check pass;
9. one direct-child implementation commit only;
10. clean worktree, empty index, no unexplained untracked file or stash; and
11. zero remote mutation.

Implementation must stop if it requires another production file, architecture
change, changed behavior, guard weakening, inventory drift, or unavailable
`ApplicationScope`/`businessLogo` runtime composition.

## V. Remote-Lock Separation

The implementation session is local-closure-only. Its commit must be remotely
published only by a separately authorized implementation remote-lock session.
Likewise this planning session creates no tag and performs no push. Planning
does not authorize implementation until this plan itself is remotely locked.

## W. Planning Mutation Audit

```text
PLANNING_DOCUMENTS_CHANGED = 1
PRODUCTION_FILES_CHANGED = 0
TEST_FILES_CHANGED = 0
RUNTIME_WIRING_CHANGED = 0
CONFIG_FILES_CHANGED = 0
DEPENDENCY_FILES_CHANGED = 0
DATABASE_FILES_CHANGED = 0
PLATFORM_FILES_CHANGED = 0
GENERATED_FILES_CHANGED = 0

PLANNING_COMMITS_TO_CREATE = 1
TAGS_TO_CREATE = 0
REMOTE_MUTATION = NONE

FLUTTER_TEST_RUN_THIS_SESSION = NO
FLUTTER_ANALYZE_RUN_THIS_SESSION = NO
BUILD_RUN_THIS_SESSION = NO
```

Tests and analyzer are not required for a documentation-only planning
mutation. Repository identity, locked objects, source/query/composition/test
inspection, live inventory recount, diff checks, and changed-path control are
the planning-session gates.

## X. Final Repository State

Expected after valid local closure:

```text
FINAL_LOCAL_HEAD = THIS_PLANNING_COMMIT
FINAL_LOCAL_DIRECT_PARENT = ca8fc49bd0a494bf8eb355f184bacf39535101c1
FINAL_REMOTE_HEAD = ca8fc49bd0a494bf8eb355f184bacf39535101c1
FINAL_AHEAD = 1
FINAL_BEHIND = 0

WORKTREE = CLEAN
INDEX = EMPTY
UNTRACKED = NONE
STASH = EMPTY
LOCAL_PLANNING_TAG = NOT_CREATED
REMOTE_MUTATION = NONE
```

## Y. Next Authorized Session

Planning local closure requires this document to be the only committed path
under one direct-child commit with subject:

```text
docs: plan transfer report pdf logo query migration
```

After that local commit is verified:

```text
POST_PHASE_108R_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING_LOCAL_CLOSURE =
COMPLETE

POST_PHASE_108R_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING_REMOTE_LOCK =
NOT_STARTED

IMPLEMENTATION = NOT_STARTED

NEXT_AUTHORIZED_SESSION =
POST_PHASE_108R_TRANSFER_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING_REMOTE_LOCK
```

Implementation remains unauthorized until the planning commit is independently
remote-locked and verified in that separate session.
