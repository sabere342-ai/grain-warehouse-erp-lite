# Advances / Refunds Report PDF Logo Query Migration Plan

Date: 2026-09-02

## A. Session Identity

```text
SESSION = ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION_PLANNING
SESSION_MODE = FORENSIC_PLANNING_ONLY_FAIL_CLOSED

AUTHORIZED_SUCCESSOR_SCOPE =
ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION

SUCCESSOR_IDENTITY_TYPE = DESCRIPTIVE_NONNUMERIC_GOVERNED_IDENTITY
PLANNING_OUTCOME = OUTCOME_A_MIGRATION_REQUIRED
PLANNING_RESULT = IMPLEMENTATION_READY

IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_MUTATIONS = NONE
```

This document plans only the presentation-owned PDF business-logo byte-read
migration in the Advances / Refunds financial report. It does not implement
the migration, authorize a batch, select another successor, or establish a
numbered phase.

## B. Repository Authority

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
IDENTITY_VERIFIED = YES

ENTRY_LOCAL_HEAD = 07850e22e221e4bc1309de66eb81cc07bd0aa452
ENTRY_REMOTE_TRACKING_HEAD = 07850e22e221e4bc1309de66eb81cc07bd0aa452
ENTRY_DIRECT_REMOTE_HEAD = 07850e22e221e4bc1309de66eb81cc07bd0aa452
ENTRY_MERGE_BASE = 07850e22e221e4bc1309de66eb81cc07bd0aa452
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0

ENTRY_TRACKED_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
ENTRY_SEQUENCER_STATE = NONE
RECOVERY_CLASSIFICATION = CLEAN_REMOTE_LOCKED_OWNER_DECISION_BASELINE
```

A mandatory fresh fetch and independent `git ls-remote` query proved that the
local branch, remote-tracking ref, direct remote branch, and merge-base all
resolved to the exact owner-decision commit before planning began.

## C. Owner-Decision Authority

```text
OWNER_DECISION_COMMIT = 07850e22e221e4bc1309de66eb81cc07bd0aa452
OWNER_DECISION_OBJECT_TYPE = commit
OWNER_DECISION_ARTIFACT =
docs/POST-EXPENSE-ANALYSIS-REPORT-PDF-LOGO-QUERY-MIGRATION-OWNER-SUCCESSOR-SCOPE-DECISION.md
OWNER_DECISION_CONTENT_PROVEN_FROM_COMMITTED_BLOB = YES

EXPENSE_ANALYSIS_REPORT_PDF_LOGO_QUERY_MIGRATION = COMPLETED_PREDECESSOR
EXPENSE_ANALYSIS_MIGRATION_REQUIRED = NO
OWNER_DECISION = SELECT_ADVANCES_REFUNDS
SELECTED_SUCCESSOR_SCOPE =
ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION
SELECTED_PRODUCTION_TARGET =
lib/features/financial_reports/advances_and_refunds_report_screen.dart
OWNER_SELECTION_COUNT = 1
BATCH_AUTHORIZED = NO
AUTOMATIC_SUCCESSOR_QUEUE_AUTHORIZED = NO
```

The decision made planning eligible only after the decision itself was
remote-locked. The entry proof above satisfies that gate. Menu order, source
order, search results, and the existence of other direct reads do not create
additional authorization.

## D. Completed Predecessor Authority

```text
COMPLETED_PREDECESSOR = 9fa5d10fb089910c4fbbaf3ef7c55b785efd5290
COMPLETED_PREDECESSOR_OBJECT_TYPE = commit
COMMIT_SUBJECT = fix: migrate expense analysis report pdf logo query
PREDECESSOR_AUTHORITY_PROVEN = YES
```

The committed Expense Analysis diff is the newest accepted canonical
precedent. It added only the existing query and scope imports, retained the
locator-owned identity read and valid-logo gate, replaced the presentation
repository invocation with the existing application query, assigned
`result.value` to the existing nullable byte variable, and left the builder
and failure path unchanged.

The predecessor is architectural evidence only. It does not authorize any
further Expense Analysis change.

## E. Search Classification

Required searches were performed across the selected source, `lib/`, and
relevant `test/` files. Architectural classification is:

```text
TARGET_PRESENTATION_SEAM =
lib/features/financial_reports/advances_and_refunds_report_screen.dart
  _AdvancesAndRefundsReportScreenState._exportPdf
  AppRepositories.businessIdentityRepository.loadLogoBytes(...)

CANONICAL_APPLICATION_QUERY =
lib/application/queries/load_business_logo_query.dart
  LoadBusinessLogoQuery

CANONICAL_QUERY_HANDLER =
lib/application/queries/load_business_logo_query.dart
  LoadBusinessLogoQueryHandler.execute

CANONICAL_QUERY_REGISTRY =
lib/application/application_boundary.dart
  ApplicationQueries.businessLogo

CANONICAL_COMPOSITION =
lib/composition/application_scope.dart
lib/composition/app_composition_root.dart

CANONICAL_REPOSITORY_IMPLEMENTATION =
lib/core/business_identity/business_identity_repository.dart

TEST_AUTHORITY =
test/advances_and_refunds_report_screen_test.dart
test/phase9d_advances_and_refunds_report_test.dart
test/financial_advances_and_refunds_summary_tool_test.dart
the twelve cumulative PDF-logo-query ownership/inventory guards

UNRELATED_OUT_OF_SCOPE_SEAM =
lib/core/backup/backup_export.dart
lib/features/exports/pdf_export_service.dart
```

Occurrences in the application query handler, repository port/implementation,
test spies, and already-migrated presentation consumers are legitimate for
their respective layers. Text occurrence alone is not treated as a defect.

## F. Current Advances / Refunds Seam

```text
PRODUCTION_TARGET =
lib/features/financial_reports/advances_and_refunds_report_screen.dart

SCREEN = AdvancesAndRefundsReportScreen
STATE = _AdvancesAndRefundsReportScreenState
TARGET_SYMBOL = _AdvancesAndRefundsReportScreenState._exportPdf
PDF_BUILDER = FinancialReportPdfBuilder.buildAdvancesAndRefundsReport
CSV_EXPORTER = FinancialReportCsvExporter.exportAdvancesAndRefundsReport
READ_WRITE_CLASSIFICATION = READ_ONLY_OWNERSHIP_EDGE
```

The current committed `_exportPdf` sequence is:

```text
if (_report == null) return
-> AppRepositories.businessIdentityRepository.loadIdentity()
-> Uint8List? logoBytes
-> identity.hasLogo && identity.logo != null
-> AppRepositories.businessIdentityRepository.loadLogoBytes(
     identity.logo!.managedFileName)
-> FinancialReportPdfBuilder.buildAdvancesAndRefundsReport(
     report: _report!,
     businessIdentity: identity,
     logoBytes: logoBytes)
-> _showExportResult(file)
```

Current facts:

```text
RAW_SUPABASE_QUERY_PRESENT = NO
DIRECT_LOAD_LOGO_BYTES_PRESENT = YES
DIRECT_REPOSITORY_REACH_PRESENT = YES
LOAD_BUSINESS_LOGO_QUERY_PRESENT = NO
APPLICATION_SCOPE_BUSINESS_LOGO_COMPOSITION_PRESENT = NO

BUSINESS_IDENTITY_METADATA_SOURCE =
AppRepositories.businessIdentityRepository.loadIdentity()

NULL_OR_MISSING_LOGO_REPRESENTATION = Uint8List? logoBytes initialized null
VALID_LOGO_GATE = identity.hasLogo && identity.logo != null
INVALID_OR_ABSENT_METADATA_BEHAVIOR = skip byte read and pass null
REPOSITORY_NULL_BEHAVIOR = pass null to existing PDF builder
QUERY_FAILURE_EQUIVALENT = exception propagates to existing _exportPdf catch
USER_VISIBLE_PDF_FAILURE = generic Arabic "تعذر إنشاء ملف PDF." snackbar
PDF_WITHOUT_LOGO = existing builder receives null and continues its normal path

APP_REPOSITORIES_REFERENCES_IN_TARGET = 12
APPLICATION_SCOPE_USES_IN_TARGET = 0
DIRECT_LOGO_BYTE_INVOCATIONS_IN_TARGET = 1
```

The current direct call is presentation-owned, migration is required, and no
raw Supabase query is involved.

## G. Canonical Target Architecture

The implementation must mirror the completed Expense Analysis predecessor:

```text
locator-owned business identity metadata read
-> unchanged valid-logo metadata gate
-> ApplicationScope.of(context).queries.businessLogo
-> LoadBusinessLogoQuery(
     managedFileName: identity.logo!.managedFileName)
-> ApplicationQueryResult<Uint8List?>
-> result.value
-> existing Uint8List? logoBytes
-> existing Advances / Refunds PDF builder input
```

Canonical production composition already exists:

```text
ApplicationScope.of(context)
-> ApplicationBoundary.queries
-> ApplicationQueries.businessLogo
-> LoadBusinessLogoQueryHandler
-> BusinessIdentityRepository.loadLogoBytes
```

`AppCompositionRoot.initializeProduction` already wires the handler to the
shared business-identity repository. The handler accepts the exact managed
filename, returns nullable bytes through `ApplicationQueryResult.value`,
returns null without a repository read for an empty filename, and otherwise
lets repository failures propagate. No architecture invention is required.

```text
NEW_QUERY_REQUIRED = NO
NEW_HANDLER_REQUIRED = NO
NEW_REPOSITORY_METHOD_REQUIRED = NO
APPLICATION_BOUNDARY_CHANGE_REQUIRED = NO
APPLICATION_SCOPE_CHANGE_REQUIRED = NO
COMPOSITION_ROOT_CHANGE_REQUIRED = NO
PDF_BUILDER_CHANGE_REQUIRED = NO
CSV_EXPORTER_CHANGE_REQUIRED = NO
CONSTRUCTOR_INJECTION_REQUIRED = NO
```

The established injection/composition seam is the inherited
`ApplicationScope` lookup inside `_exportPdf`; the widget constructor remains
unchanged.

## H. Exact Planned Production Change

Future implementation changes exactly one production file:

```text
AUTHORIZED_PRODUCTION_FILES = 1
lib/features/financial_reports/advances_and_refunds_report_screen.dart
```

Deterministic edit sequence:

1. Import the existing `load_business_logo_query.dart`.
2. Import the existing `application_scope.dart`.
3. Keep `loadIdentity()` on `AppRepositories.businessIdentityRepository`.
4. Keep `identity.hasLogo && identity.logo != null` unchanged.
5. Replace only the direct `loadLogoBytes` invocation with
   `ApplicationScope.of(context).queries.businessLogo.execute(...)`.
6. Construct `LoadBusinessLogoQuery` with the exact existing
   `identity.logo!.managedFileName` value, without normalization or fallback.
7. Assign only `result.value` to the existing `Uint8List? logoBytes` variable.
8. Use the accepted narrow `use_build_context_synchronously` suppression at
   the query expression, matching the newest completed report precedent.
9. Leave the builder call, its three arguments, result handler, catch block,
   snackbar, and CSV method unchanged.

Expected target topology:

```text
APP_REPOSITORIES_REFERENCES_IN_TARGET = 12 -> 11
APPLICATION_SCOPE_USES_IN_TARGET = 0 -> 1
DIRECT_LOGO_BYTE_INVOCATIONS_IN_TARGET = 1 -> 0
```

No other production path is authorized.

## I. Exact Planned Test Surface

Future implementation adds one focused ten-test suite:

```text
test/post_expense_analysis_report_pdf_logo_query_migration_advances_refunds_report_pdf_logo_query_migration_test.dart
```

It must mirror the completed Expense Analysis harness and prove:

1. PDF remains disabled before a report is loaded.
2. The existing query preserves present byte-object identity.
3. The existing query preserves empty byte-object identity.
4. The existing query preserves repository null.
5. Valid metadata reads locator identity first and executes exactly one query
   with the exact managed filename, with no direct locator logo read.
6. Absent metadata performs no scope lookup and no logo read.
7. Invalid metadata performs no scope lookup and no logo read.
8. Query failure retains the existing safe Arabic PDF failure snackbar and
   does not expose the internal exception.
9. A source/ordering guard proves `result.value` flows unchanged through the
   existing `logoBytes` variable into
   `buildAdvancesAndRefundsReport`, while report, filters, permissions, PDF/CSV
   actions, result handling, and no-write invariants remain frozen.
10. Live locator/scope and direct-read inventories contain only the exact
    Advances / Refunds delta.

The query byte-identity tests plus the source flow guard and existing PDF
branding regression tests prove successful bytes reach the unchanged builder
without introducing a PDF-builder seam solely for testing.

Future implementation updates exactly these twelve cumulative guards:

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
test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_expense_analysis_report_pdf_logo_query_migration_test.dart
```

Only exact count and membership deltas are authorized:

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 135 -> 134
FEATURE_SHARED_LOCATOR_FILES = 36 -> 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 151 -> 150
APPLICATION_SCOPE_CONSUMERS = 15 -> 16

GUARD_STYLE_LOGO_READ_FILES = 5 -> 4
ACTUAL_LOGO_INVOCATION_FILES = 4 -> 3
```

Expected guard-style set after implementation:

```text
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
lib/core/business_identity/business_identity_repository.dart
lib/features/exports/pdf_export_service.dart
```

Expected actual invocation set after implementation:

```text
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
lib/features/exports/pdf_export_service.dart
```

The following existing tests remain unchanged and run only as regression
evidence:

```text
test/advances_and_refunds_report_screen_test.dart
test/phase9d_advances_and_refunds_report_test.dart
test/financial_advances_and_refunds_summary_tool_test.dart
test/phase42_pdf_export_foundation_test.dart
test/phase68_business_logo_invoice_windows_icon_test.dart
```

Future implementation mutation inventory:

```text
PRODUCTION_FILES = 1
NEW_FOCUSED_TEST_FILES = 1
EXISTING_CUMULATIVE_TEST_FILES = 12
TOTAL_TEST_FILES = 13
TOTAL_CHANGED_PATHS = 14

DOCUMENTATION_FILES = 0
CONFIG_FILES = 0
DATABASE_FILES = 0
DEPENDENCY_FILES = 0
PLATFORM_FILES = 0
GENERATED_FILES = 0
```

No assertion weakening, wildcarding, count relaxation, or historical guard
removal is authorized.

## J. Behavioral Invariants

This is an ownership-boundary migration only. Future implementation must
preserve unchanged:

```text
authorization and report visibility
PDF and CSV action availability
FinancialReportService construction
customer and supplier lookup adapters
financial-account repository behavior
account loading including inactive accounts
from-date and to-date filters
financial-account filter
party-type and party-id filters
entity loading and selection
report rows, customer/supplier summaries, totals, reversals and reconciliation
sorting, determinism and read-only accounting semantics
business identity metadata source and load ordering
valid, absent, invalid, empty, null and missing-logo behavior
query/repository failure containment and user-visible snackbar text
the exact managed filename
the nullable logo byte object passed to the PDF builder
PDF content, branding, logo sizing, Arabic/RTL layout and pagination
PDF filename, destination and result handling
CSV content, filename, destination and failure handling
navigation, UI layout, mounted guards and async behavior
all repository write behavior
```

No user-visible behavior change is authorized.

## K. Explicit Non-Goals and Successor Boundary

Future implementation must not change:

```text
lib/core/backup/backup_export.dart
lib/features/exports/pdf_export_service.dart
lib/features/financial_reports/expense_analysis_report_screen.dart
any other financial-report screen
LoadBusinessLogoQuery or LoadBusinessLogoQueryHandler
BusinessIdentityRepository or its implementation
ApplicationBoundary, ApplicationScope or AppCompositionRoot
FinancialReportPdfBuilder or FinancialReportCsvExporter
report models, calculations or services
authentication, permissions, navigation or application startup
database, schema, migrations or Supabase
dependencies, lockfiles, configuration or build files
platform or generated files
documentation
```

```text
BACKUP_EXPORT_LOGO_QUERY_MIGRATION_AUTHORIZED = NO
PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION_AUTHORIZED = NO
EXPENSE_ANALYSIS_CHANGES_AUTHORIZED = NO
AUTOMATIC_SUCCESSOR_SCOPE_EXPANSION = FORBIDDEN
NUMBERED_SUCCESSOR_PHASE_ESTABLISHED = NO
```

No opportunistic refactor, cleanup, generalized dependency injection, new
abstraction, new feature, report redesign, or adjacent query migration is
allowed.

## L. Implementation Sequence

The future implementation session must:

1. Independently prove the exact remotely locked planning commit, identity,
   clean state, empty stash, no sequencer, and zero divergence.
2. Capture pre-mutation focused, cumulative, regression, count, and membership
   evidence.
3. Edit only the one authorized production file with the deterministic seam
   replacement in Section H.
4. Add only the focused suite and update only the twelve cumulative guards in
   Section I.
5. Format only changed Dart files.
6. Run all focused, cumulative, unchanged regression, analyzer, formatter,
   full-suite, whitespace, and path-control gates.
7. Prove the final implementation diff contains exactly the fourteen
   allowlisted paths and no behavior or architecture expansion.
8. Create one narrow non-merge implementation commit only if every gate passes.
9. Stop without selecting, planning, or implementing another seam.

## M. Validation Matrix

Required future commands include:

```text
flutter test <new focused Advances / Refunds migration test>
flutter test <the twelve affected cumulative guards>
flutter test test/advances_and_refunds_report_screen_test.dart
             test/phase9d_advances_and_refunds_report_test.dart
             test/financial_advances_and_refunds_summary_tool_test.dart
             test/phase42_pdf_export_foundation_test.dart
             test/phase68_business_logo_invoice_windows_icon_test.dart
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
git diff --check
git diff --cached --check
```

Validation responsibilities:

| Gate | Required proof |
| --- | --- |
| Ownership | Target uses `ApplicationScope...businessLogo.execute` and has no direct `.loadLogoBytes(` |
| Input | Exact existing managed filename reaches `LoadBusinessLogoQuery` |
| Result | `ApplicationQueryResult.value` reaches the existing nullable builder input unchanged |
| Absence | Missing/invalid metadata skips query lookup and PDF proceeds with null logo |
| Failure | Query exception reaches the existing catch and safe Arabic snackbar |
| Architecture | No handler construction or new query/wiring in presentation |
| Inventory | Exact `134/36/150/16`, guard-style `4`, invocation `3`, and exact sets |
| Behavior | Report, filters, calculations, PDF, CSV, permissions, RTL and writes unchanged |
| Scope | Exactly one production and thirteen test paths change |
| Quality | Focused, cumulative, regression, analyzer, format and full suite pass |

## N. Fail-Closed Conditions

Implementation must stop without widening scope if any of the following occurs:

```text
planning commit is not independently remote-locked
repository identity or authority chain differs
dirty baseline, stash, sequencer or unexpected divergence exists
current target is already migrated
the exact existing query cannot preserve behavior
a second production file appears necessary
canonical query, handler, boundary, scope or composition changes appear necessary
PDF builder or CSV exporter changes appear necessary
database, Supabase, dependency, platform or generated changes appear necessary
test expectations require weakening instead of exact delta updates
any non-allowlisted path changes
any report, filter, calculation, formatting, error or write behavior changes
```

Any such condition requires a new explicit governance decision; it is not
permission to improvise.

## O. Implementation Acceptance Criteria

Implementation is acceptable only if:

1. it begins from the exact separately verified remote-locked planning commit;
2. exactly one presentation-owned logo byte read is migrated;
3. locator-owned identity metadata loading and the valid-logo gate remain
   unchanged;
4. one exact existing query executes only for valid metadata;
5. the exact managed filename and nullable byte result are preserved;
6. the existing builder, PDF/CSV flows, report object, error UI and all business
   semantics remain unchanged;
7. the target has eleven `AppRepositories.` references, one
   `ApplicationScope.of` use, and no direct `.loadLogoBytes(` invocation;
8. exact cumulative counts and membership sets are proven;
9. the one focused suite, twelve cumulative guards, and unchanged regressions
   pass with no weakened assertion;
10. formatter, analyzer, full sequential suite and Git integrity gates pass;
11. the implementation commit changes exactly the fourteen allowlisted paths;
12. no push, tag, deployment, successor selection, or adjacent seam work occurs
    unless separately authorized.

## P. Planning Artifact Contract

```text
ARTIFACT_PATH =
docs/POST-EXPENSE-ANALYSIS-REPORT-PDF-LOGO-QUERY-MIGRATION-ADVANCES-REFUNDS-REPORT-PDF-LOGO-QUERY-MIGRATION-PLAN.md

DIRECT_PARENT = 07850e22e221e4bc1309de66eb81cc07bd0aa452
COMMIT_SUBJECT = docs: plan advances refunds report pdf logo query migration
EXPECTED_FILES_IN_PLANNING_COMMIT = 1
MERGE_COMMIT = NO
AMEND = NO

PLANNING_DOCUMENTATION_FILES_CHANGED = 1
PLANNING_PRODUCTION_FILES_CHANGED = 0
PLANNING_TEST_FILES_CHANGED = 0
PLANNING_CONFIG_FILES_CHANGED = 0
PLANNING_DATABASE_FILES_CHANGED = 0
PLANNING_DEPENDENCY_FILES_CHANGED = 0
PLANNING_PLATFORM_FILES_CHANGED = 0
PLANNING_GENERATED_FILES_CHANGED = 0

IMPLEMENTATION_STARTED = NO
```

The artifact name follows the established `POST-<completed predecessor>-<new
selected report>-PLAN.md` convention while avoiding an unbounded historical
filename chain. It remains under `docs/`, and the scope identity is explicit.

## Q. Success Criteria and Stop Boundary

Planning succeeds only after this one artifact is committed, pushed without
force to the authorized branch, independently verified as the direct remote
head, and the final worktree/index are clean with zero divergence.

```text
PLANNING_SUCCESS_MEANS =
ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION_PLAN_REMOTE_LOCKED

IMPLEMENTATION_AUTHORIZED_BY_THIS_DOCUMENT = NO
IMPLEMENTATION_STARTED = NO
BACKUP_EXPORT_LOGO_QUERY_MIGRATION_AUTHORIZED = NO
PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION_AUTHORIZED = NO
AUTOMATIC_SUCCESSOR_SCOPE_EXPANSION = FORBIDDEN
```

After the planning remote lock is proven, stop. A separate implementation
session must independently establish implementation authority and baseline.
