# Expense Analysis Report PDF Logo Query Migration Plan

Date: 2026-09-01

## A. Session Identity

```text
SESSION = EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING
SESSION_MODE = FORENSIC_PLANNING_LOCAL_CLOSURE_ONLY

CANONICAL_SUCCESSOR_SCOPE =
EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY =
EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY_TYPE = DESCRIPTIVE_NONNUMERIC_GOVERNED_IDENTITY
PLANNING_RESULT = IMPLEMENTATION_READY

PLANNING = COMPLETE
IMPLEMENTATION = NOT_STARTED
IMPLEMENTATION_MUTATIONS = NONE

PUSH = NOT_OCCURRED
TAG = NOT_CREATED
DEPLOY = NOT_OCCURRED
```

This document plans only the Expense Analysis Report PDF managed-logo-byte
query-ownership migration. It does not implement the migration, plan or queue
Advances/Refunds, create a batch, or establish a numbered successor phase.

## B. Repository Identity

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
IDENTITY_VERIFIED = YES

RECOVERY_CLASSIFICATION = CASE_A_FRESH_PLANNING

ENTRY_LOCAL_HEAD = 41edbf1efdaa8834e232d65fcbc8ed35e19a2fd2
ENTRY_REMOTE_HEAD = 41edbf1efdaa8834e232d65fcbc8ed35e19a2fd2
ENTRY_MERGE_BASE = 41edbf1efdaa8834e232d65fcbc8ed35e19a2fd2
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0

ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
ENTRY_SEQUENCER_STATE = NONE

GIT_DIFF_CHECK = PASS
CACHED_DIFF_CHECK = PASS
```

A fresh `git fetch origin --prune` and direct remote query contacted only the
authorized remote before planning began.

## C. Locked Baseline

```text
LOCKED_BASELINE = 41edbf1efdaa8834e232d65fcbc8ed35e19a2fd2
OBJECT_TYPE = commit
MERGE_COMMIT = NO

DIRECT_PARENT = ab5a835772dfa6220676dbb8ca9b768c03f4acfe
COMMIT_SUBJECT = docs: select expense analysis as post-outflows successor

FILES_IN_COMMIT = 1
ARTIFACT_PATH =
docs/POST-OUTFLOWS-REPORT-PDF-LOGO-QUERY-MIGRATION-OWNER-SUCCESSOR-SCOPE-DECISION.md
ARTIFACT_BLOB = 4161897e12bbb3dc4d4d3a99fe097434e3669109

OWNER_DECISION_LOCAL_CLOSURE = COMPLETE
OWNER_DECISION_REMOTE_LOCK = COMPLETE
```

The local branch, remote-tracking ref, and direct remote branch query all
resolve to the exact baseline commit.

## D. Owner Authorization Proof

The remotely locked owner decision establishes:

```text
OWNER_SELECTED_SUCCESSOR_SCOPE =
EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION

OWNER_SELECTED_TARGET_FILE =
lib/features/financial_reports/expense_analysis_report_screen.dart

OWNER_SELECTION_COUNT = 1
OWNER_DECISION_REQUIRED = SATISFIED
OWNER_AUTHORIZATION = GRANTED_FOR_SELECTED_SCOPE_IDENTITY_ONLY
SUCCESSOR_TECHNICAL_DISCOVERY_REQUIRED = NO

SUCCESSOR_PLANNING_AUTHORIZED_AFTER_REMOTE_LOCK = YES
```

The same decision keeps the only other same-family candidate unselected:

```text
ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION =
NOT_SELECTED_NOT_CANCELLED_NOT_AUTHORIZED

BATCH_AUTHORIZED = NO
AUTOMATIC_SUCCESSOR_QUEUE_AUTHORIZED = NO
```

Only explicit owner authority selects Expense Analysis. Menu order, source
order, similarity, and remaining inventory do not create authorization.

## E. Selected Target

```text
PRODUCTION_TARGET =
lib/features/financial_reports/expense_analysis_report_screen.dart

SCREEN = ExpenseAnalysisReportScreen
STATE = _ExpenseAnalysisReportScreenState
TARGET_SYMBOL = _ExpenseAnalysisReportScreenState._exportPdf
PDF_BUILDER = FinancialReportPdfBuilder.buildExpenseAnalysisReport
CSV_EXPORTER = FinancialReportCsvExporter.exportExpenseAnalysisReport
READ_WRITE_CLASSIFICATION = READ_ONLY_OWNERSHIP_EDGE
```

`FinancialReportsScreen` exposes the selected screen as a runtime-reachable
report. The screen requires `canViewFinancialReports`; PDF and CSV actions also
require `canExportFinancialReports` and a non-null loaded report.

The owning screen constructs `FinancialReportService` with the existing
financial-account and expense repositories, loads accounts including inactive
accounts, and calls `expenseAnalysisReport` with the current nullable date,
account, payment-method, and trimmed category-search filters. None of those
dependencies belongs to this migration.

## F. Current Direct-Access Seam

At the locked baseline, `_exportPdf` executes this sequence:

```text
if (_report == null) return
-> AppRepositories.businessIdentityRepository.loadIdentity()
-> Uint8List? logoBytes
-> identity.hasLogo && identity.logo != null
-> AppRepositories.businessIdentityRepository.loadLogoBytes(
     identity.logo!.managedFileName)
-> FinancialReportPdfBuilder.buildExpenseAnalysisReport(
     report: _report!,
     businessIdentity: identity,
     logoBytes: logoBytes)
-> _showExportResult(file)
```

Current source facts:

```text
APP_REPOSITORIES_REFERENCES_IN_TARGET = 5
APPLICATION_SCOPE_USES_IN_TARGET = 0
DIRECT_LOGO_BYTE_INVOCATIONS_IN_TARGET = 1
BUSINESS_IDENTITY_METADATA_READ_PRESENT = YES
VALID_LOGO_GATE_PRESENT = YES
WRITE_BEHAVIOR_IN_TARGET_SEAM = NO
```

The presentation-owned `loadLogoBytes` call is the sole ownership edge selected
for migration. The locator-owned business-identity metadata read remains
unchanged.

## G. Canonical Predecessor Architecture

The nearest completed and remotely locked predecessor is:

```text
PREDECESSOR_SCOPE = OUTFLOWS_REPORT_PDF_LOGO_QUERY_MIGRATION
PREDECESSOR_IMPLEMENTATION_COMMIT =
ab5a835772dfa6220676dbb8ca9b768c03f4acfe
PREDECESSOR_TARGET =
lib/features/financial_reports/outflows_report_screen.dart
PREDECESSOR_SYMBOL = _OutflowsReportScreenState._exportPdf
```

The accepted predecessor preserves `loadIdentity()` and the valid metadata
gate, imports the existing query and scope, executes the query after identity,
and forwards `result.value` unchanged to the existing nullable builder input:

```dart
final result =
    // ignore: use_build_context_synchronously
    await ApplicationScope.of(context).queries.businessLogo.execute(
          LoadBusinessLogoQuery(
            managedFileName: identity.logo!.managedFileName,
          ),
        );

logoBytes = result.value;
```

Transfer, Inflows, and Outflows establish the same one-consumer lifecycle,
focused-test pattern, exact inventory guards, and behavior-preserving boundary.
Expense Analysis can mirror that architecture without a new concept.

## H. Existing Architecture Reuse Determination

Repository inspection proves:

```text
QUERY_CONTRACT = LoadBusinessLogoQuery
QUERY_HANDLER = LoadBusinessLogoQueryHandler
QUERY_REGISTRY_FIELD = ApplicationQueries.businessLogo
UI_ACCESS_PATH = ApplicationScope.of(context).queries.businessLogo
PRODUCTION_HANDLER_WIRING = AppCompositionRoot.initializeProduction
REPOSITORY_PORT = BusinessIdentityRepository.loadLogoBytes
```

`LoadBusinessLogoQueryHandler` accepts the exact managed filename, returns the
same nullable byte object in `ApplicationQueryResult.value`, preserves null and
empty bytes, and owns the repository invocation. Production composition already
wires the handler to the business-identity repository.

Therefore:

```text
NEW_APPLICATION_QUERY_REQUIRED = NO
NEW_HANDLER_REQUIRED = NO
NEW_REPOSITORY_METHOD_REQUIRED = NO
APPLICATION_SCOPE_CHANGE_REQUIRED = NO
APPLICATION_BOUNDARY_CHANGE_REQUIRED = NO
COMPOSITION_CHANGE_REQUIRED = NO
DATABASE_CHANGE_REQUIRED = NO
DEPENDENCY_CHANGE_REQUIRED = NO
PDF_BUILDER_CHANGE_REQUIRED = NO
CSV_EXPORTER_CHANGE_REQUIRED = NO
```

## I. Exact Planned Production Changes

Future implementation changes exactly one production file:

```text
PRODUCTION_FILES_EXPECTED = 1

lib/features/financial_reports/expense_analysis_report_screen.dart
```

The deterministic edit is:

1. import the existing `load_business_logo_query.dart`;
2. import the existing `application_scope.dart`;
3. leave `loadIdentity()` on `AppRepositories.businessIdentityRepository`;
4. leave `identity.hasLogo && identity.logo != null` unchanged;
5. replace only the direct `loadLogoBytes` call with the accepted
   `ApplicationScope.of(context).queries.businessLogo.execute` call;
6. construct `LoadBusinessLogoQuery` with the exact existing managed filename;
7. assign only `result.value` to the existing `Uint8List? logoBytes` variable;
8. retain the accepted narrow `use_build_context_synchronously` suppression at
   the query expression, matching Outflows;
9. leave the Expense Analysis builder call and all inputs unchanged; and
10. leave PDF result handling, error handling, and CSV export unchanged.

Expected target topology after implementation:

```text
APP_REPOSITORIES_REFERENCES_IN_TARGET = 5 -> 4
APPLICATION_SCOPE_USES_IN_TARGET = 0 -> 1
DIRECT_LOGO_BYTE_INVOCATIONS_IN_TARGET = 1 -> 0
```

No constructor, method signature, async shape, report service, controller,
fixture hook, provider, or dependency-injection change is permitted.

## J. Exact Planned Tests and Guards

Future implementation adds exactly one ten-test focused suite:

```text
test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_expense_analysis_report_pdf_logo_query_migration_test.dart
```

It mirrors the accepted Outflows harness and proves:

1. PDF remains disabled without a loaded report;
2. the existing query preserves present-byte identity;
3. the existing query preserves empty-byte identity;
4. the existing query preserves repository null;
5. valid metadata reads locator-owned identity before one exact query;
6. absent metadata performs no scope lookup or logo read;
7. invalid metadata performs no scope lookup or logo read;
8. query failure retains the safe existing Expense Analysis PDF snackbar and
   exposes no internal error;
9. only the selected `_exportPdf` block moves, with report, filters, builder,
   PDF/CSV actions, and no-write invariants frozen; and
10. live locator/scope and direct-read inventories have exactly the Expense
    Analysis delta.

Future implementation updates exactly these eleven existing cumulative guards:

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
test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_test.dart
test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_test.dart
```

Only the exact mathematical delta and membership removal are allowed:

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 136 -> 135
FEATURE_SHARED_LOCATOR_FILES = 36 -> 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 152 -> 151
APPLICATION_SCOPE_CONSUMERS = 14 -> 15

GUARD_STYLE_LOGO_READ_FILES = 6 -> 5
ACTUAL_LOGO_INVOCATION_FILES = 5 -> 4
```

Expected guard-style set after implementation:

```text
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
lib/core/business_identity/business_identity_repository.dart
lib/features/exports/pdf_export_service.dart
lib/features/financial_reports/advances_and_refunds_report_screen.dart
```

Expected actual invocation set after implementation is the same set without
the repository port declaration.

No assertion weakening, wildcarding, count relaxation, or removal of historical
guards is authorized.

Future implementation mutation inventory:

```text
FUTURE_PRODUCTION_FILES = 1
FUTURE_TEST_FILES = 12
FUTURE_TOTAL_CHANGED_PATHS = 13

FUTURE_DOCUMENTATION_FILES = 0
FUTURE_CONFIG_FILES = 0
FUTURE_DATABASE_FILES = 0
FUTURE_DEPENDENCY_FILES = 0
FUTURE_PLATFORM_FILES = 0
FUTURE_GENERATED_FILES = 0
```

Validation commands must include:

```text
flutter test <new focused Expense Analysis migration test>
flutter test <the eleven affected cumulative guards>
flutter test test/phase42_pdf_export_foundation_test.dart
             test/phase68_business_logo_invoice_windows_icon_test.dart
             test/phase9e_expense_analysis_report_test.dart
             test/financial_expense_analysis_tool_test.dart
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
git diff --check
git diff --cached --check
```

Current declaration evidence establishes:

```text
AFFECTED_EXISTING_GUARD_TESTS = 113
UNCHANGED_REGRESSION_TESTS = 119
NEW_FOCUSED_TESTS = 10
LOCKED_FULL_SUITE_BASELINE = 2597
EXPECTED_FULL_SUITE_AFTER_IMPLEMENTATION = 2607
```

The future implementation session must run the affected guards and unchanged
regressions before mutation, then rerun them after mutation along with the new
focused suite, analyzer, formatter check, and full sequential suite.

## K. Behavior-Preservation Contract

The migration changes ownership only. It must preserve:

```text
financial report loading behavior
FinancialReportService construction and repositories
from-date and to-date filters
financial-account filter
payment-method filter
trimmed category-search filter
filter reset and loading state
permissions and export availability
business identity metadata loading
valid-logo metadata gate
present, empty, null, missing, and invalid logo behavior
ExpenseAnalysisReport object identity
PDF builder and its report/businessIdentity/logoBytes inputs
PDF content, Arabic text, RTL layout, typography, totals, percentages and rows
PDF filename, destination and file handling
success snackbar and safe failure snackbar
CSV exporter, filename, content, destination and error behavior
report calculations and financial data
navigation and UI layout
mounted guards and async failure containment
all repository write behavior
```

No user-visible behavior change is authorized.

## L. Negative Scope

Future implementation must not change:

```text
any other financial-report screen
LoadBusinessLogoQuery or its handler
BusinessIdentityRepository or its implementation
ApplicationBoundary or ApplicationScope
AppCompositionRoot or dependency wiring
business identity metadata ownership
financial report calculations or models
FinancialReportPdfBuilder
FinancialReportCsvExporter
PdfExportService
BackupExportService
authentication or permissions
navigation or application startup
database, schema, migrations or Supabase
dependencies or lockfiles
configuration or build files
platform code
generated code
documentation
```

No opportunistic refactor, cleanup, formatting bundle, new abstraction, or
secondary query migration is allowed.

## M. Advances/Refunds Exclusion

```text
ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION = OUT_OF_SCOPE
ADVANCES_REFUNDS_AUTHORIZED = NO
ADVANCES_REFUNDS_QUEUED = NO
ADVANCES_REFUNDS_PLANNING_STARTED = NO
ADVANCES_REFUNDS_IMPLEMENTATION_STARTED = NO

lib/features/financial_reports/advances_and_refunds_report_screen.dart =
MUST_REMAIN_UNCHANGED
```

Its presence in the post-implementation direct-read inventory is intentional
and does not make it automatically next.

## N. Numbered-Phase Exclusion

```text
NUMBERED_SUCCESSOR_PHASE_ESTABLISHED = NO
PHASE_108S_IS_AUTHORIZED = NO
PHASE_108T_IS_AUTHORIZED = NO
PHASE_108U_IS_AUTHORIZED = NO
ORDINAL_SUCCESSION_USED_AS_AUTHORITY = NO
```

Only `EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION` names this scope.

## O. Implementation Acceptance Criteria

Implementation is acceptable only if:

1. it starts from the separately remote-locked exact planning commit;
2. exactly one production ownership edge changes in the selected `_exportPdf`;
3. identity loading and the valid-logo gate remain locator-owned and unchanged;
4. one exact existing query executes only for valid metadata;
5. the exact managed filename is forwarded without transformation;
6. `result.value` reaches the existing nullable builder input unchanged;
7. no direct `.loadLogoBytes(` remains in the selected presentation path;
8. no query handler is constructed directly in the screen;
9. all report, filter, calculation, PDF, CSV, permission, Arabic/RTL, fallback,
   error, filename, output, navigation, and UI behavior remains unchanged;
10. the target ends with exactly four legitimate `AppRepositories.` references
    and one `ApplicationScope.of` use;
11. exact `135/36/151/15`, guard-style `5`, invocation `4`, and exact membership
    sets are proven;
12. one new ten-test focused suite and eleven exact guard updates are made;
13. all targeted, regression, formatter, analyzer, full-suite, whitespace, and
    path-control gates pass;
14. the implementation commit changes exactly the thirteen allowlisted paths,
    is non-merge, and is the direct child of the locked planning commit; and
15. implementation local closure performs no push, tag, deployment, history
    rewrite, planning for another scope, or Advances/Refunds mutation.

Any required second production file, architecture change, database/dependency/
platform/generated change, behavior change, test weakening, or path outside the
allowlist is a governance blocker rather than permission to widen scope.

## P. Planning Commit Contract

Established chained planning-artifact precedent requires:

```text
ARTIFACT_PATH =
docs/POST-TRANSFER-REPORT-PDF-LOGO-QUERY-MIGRATION-INFLOWS-REPORT-PDF-LOGO-QUERY-MIGRATION-OUTFLOWS-REPORT-PDF-LOGO-QUERY-MIGRATION-EXPENSE-ANALYSIS-REPORT-PDF-LOGO-QUERY-MIGRATION-PLAN.md

DIRECT_PARENT = 41edbf1efdaa8834e232d65fcbc8ed35e19a2fd2
COMMIT_SUBJECT = docs: plan expense analysis report pdf logo query migration
EXPECTED_FILES_IN_COMMIT = 1
MERGE_COMMIT = NO
AMEND = NO

DOCUMENTATION_FILES_CHANGED = 1
PRODUCTION_FILES_CHANGED = 0
TEST_FILES_CHANGED = 0
CONFIG_FILES_CHANGED = 0
DATABASE_FILES_CHANGED = 0
DEPENDENCY_FILES_CHANGED = 0
PLATFORM_FILES_CHANGED = 0
GENERATED_FILES_CHANGED = 0

RUNTIME_TESTS_RERUN = NO
ANALYZER_RERUN = NO
REASON = DOCUMENTATION_ONLY_PLANNING_AND_LOCKED_RUNTIME_UNCHANGED

PUSH_OCCURRED = NO
TAG_CREATED = NO
DEPLOY_OCCURRED = NO
```

The filename extends the exact Transfer -> Inflows -> Outflows planning chain;
the commit subject follows the three accepted `docs: plan <report> report pdf
logo query migration` predecessors.

## Q. Closure State and Next Authorized Lifecycle

After verified local commit, the required topology is:

```text
FINAL_LOCAL_HEAD = THIS_PLANNING_COMMIT
FINAL_LOCAL_DIRECT_PARENT = 41edbf1efdaa8834e232d65fcbc8ed35e19a2fd2
FINAL_REMOTE_HEAD = 41edbf1efdaa8834e232d65fcbc8ed35e19a2fd2
FINAL_MERGE_BASE = 41edbf1efdaa8834e232d65fcbc8ed35e19a2fd2
FINAL_AHEAD = 1
FINAL_BEHIND = 0

WORKTREE = CLEAN
INDEX = EMPTY
UNTRACKED = NONE
STASH = EMPTY
SEQUENCER_STATE = NONE

PLANNING_LOCAL_CLOSURE = COMPLETE
PLANNING_REMOTE_LOCK = NOT_STARTED
IMPLEMENTATION_STARTED = NO

NEXT_AUTHORIZED_SESSION =
EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING_REMOTE_LOCK
```

The planning commit may be published only by that separately authorized
remote-lock session. Implementation remains unauthorized until it independently
verifies and locks the exact planning object.

## R. STOP Boundary

```text
STOP.

NO IMPLEMENTATION WAS STARTED.
NO PLANNING REMOTE LOCK WAS STARTED.
NO ADVANCES/REFUNDS WORK WAS AUTHORIZED OR STARTED.
NO PUSH OR TAG WAS PERFORMED.
NO NUMBERED PHASE WAS CREATED.
```
