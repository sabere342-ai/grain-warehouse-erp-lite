# Post-Advances/Refunds PDF Export Service Logo Query Migration Plan

Date: 2026-09-04

## A. Session Identity

```text
SESSION = PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION_PLANNING
MODE = SINGLE_SUCCESSOR_PLANNING_ONLY_FAIL_CLOSED
TARGET_SCOPE = PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION
IMPLEMENTATION_AUTHORIZED = NO
IMPLEMENTATION_STARTED = NO
```

This artifact plans one migration only. It does not change production code,
tests, application wiring, repository ownership, runtime behavior, or Backup
Export.

## B. Repository Identity and Entry Remote Lock

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git

ENTRY_LOCAL_HEAD = 965be058477edce51bdb34c66f14b0b566fd3575
ENTRY_REMOTE_TRACKING_HEAD = 965be058477edce51bdb34c66f14b0b566fd3575
ENTRY_DIRECT_REMOTE_HEAD = 965be058477edce51bdb34c66f14b0b566fd3575
ENTRY_MERGE_BASE = 965be058477edce51bdb34c66f14b0b566fd3575
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0

CONFIGURED_UPSTREAM = NONE
REMOTE_TRACKING_AND_DIRECT_REMOTE_PROOF = PASS
WORKTREE_CLEAN = YES
INDEX_CLEAN = YES
UNTRACKED = NONE
STASH_STATE = EMPTY
SEQUENCER_STATE = NONE
RECOVERY_CLASSIFICATION = CLEAN_FRESH_REMOTE_LOCKED_OWNER_ORDER_BASELINE
```

A fresh `git fetch origin`, explicit `origin/<branch>` resolution, direct
`git ls-remote`, and merge-base/divergence checks proved the exact entry
baseline. The missing configured upstream is acceptable because both explicit
remote views agree.

## C. Committed Authority Chain

The following committed chain is linear:

```text
PREVIOUS_OWNER_AUTHORITY =
07850e22e221e4bc1309de66eb81cc07bd0aa452

ADVANCES_REFUNDS_PLANNING =
fc43681c8bcc915b1ab0b876c72b321fcb0d756f

ADVANCES_REFUNDS_IMPLEMENTATION =
9fbadd63e8e058fe79f02a32bf0527bc914e7517

SUCCESSOR_ORDER_DECISION =
965be058477edce51bdb34c66f14b0b566fd3575
```

Git parent and ancestry proof establishes:

```text
07850e2_IS_ANCESTOR_OF_fc43681 = YES
fc43681_IS_ANCESTOR_OF_9fbadd6 = YES
9fbadd6_IS_DIRECT_PARENT_OF_965be05 = YES
965be05_IS_CURRENT_REMOTE_LOCKED_BASELINE = YES
```

## D. Owner-Order Decision Proof

The committed blob at
`docs/POST-ADVANCES-REFUNDS-REPORT-PDF-LOGO-QUERY-MIGRATION-OWNER-SUCCESSOR-SCOPE-ORDER-DECISION.md`
in commit `965be058477edce51bdb34c66f14b0b566fd3575` states:

```text
OWNER_ORDER_AUTHORITY_PRESENT = YES
SELECTED_SUCCESSOR_SCOPE = PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION
DEFERRED_SUCCESSOR_SCOPE = BACKUP_EXPORT_LOGO_QUERY_MIGRATION
PDF_EXPORT_SERVICE_IS_FIRST = YES
BACKUP_EXPORT_IS_SECOND = YES
BACKUP_EXPORT_DEFERRED_NOT_CANCELLED = YES

BATCH_AUTHORIZED = NO
AUTOMATIC_NEXT_SUCCESSOR_SELECTION = NO
AUTOMATIC_SCOPE_EXPANSION = NO

PDF_EXPORT_SERVICE_PLANNING_MAY_BE_REQUESTED_IN_A_SEPARATE_SUCCESSOR_SESSION = YES
PDF_EXPORT_SERVICE_IMPLEMENTATION_AUTHORIZED = NO
BACKUP_EXPORT_PLANNING_AUTHORIZED = NO
BACKUP_EXPORT_IMPLEMENTATION_AUTHORIZED = NO
```

The committed prose explicitly says PDF Export Service is first and Backup
Export is second. This session consumes the permitted planning handoff only;
it does not infer implementation authority.

## E. Canonical Query Contract

```text
CANONICAL_QUERY_FILE =
lib/application/queries/load_business_logo_query.dart

QUERY_VALUE_TYPE = LoadBusinessLogoQuery
QUERY_CONSTRUCTOR =
const LoadBusinessLogoQuery({required String managedFileName})

HANDLER_TYPE = LoadBusinessLogoQueryHandler
HANDLER_CONSTRUCTOR_DEPENDENCY = BusinessIdentityRepository repository
HANDLER_METHOD = execute(LoadBusinessLogoQuery query)
HANDLER_RETURN_TYPE =
Future<ApplicationQueryResult<Uint8List?>>

BUILD_CONTEXT_REQUIRED_BY_QUERY_OR_HANDLER = NO
IDENTITY_REQUIRED_BY_QUERY_OR_HANDLER = NO
REPOSITORY_REQUIRED_BY_HANDLER = YES
LOGO_REPRESENTATION = Uint8List?
```

The handler contract is:

1. an empty managed filename returns `ApplicationQueryResult.value == null`
   without invoking the repository;
2. a non-empty filename delegates exactly once to the injected repository's
   `loadLogoBytes(managedFileName)`;
3. repository `Uint8List`, empty `Uint8List`, or `null` is preserved as the
   result value;
4. repository exceptions are not caught by the handler and propagate to the
   caller;
5. successful and empty-name results carry `LocalReadAuthority.managedFile`;
6. no raw SQL, database access, file access, global locator, identity lookup,
   or fallback rendering is owned by the query.

The production composition root constructs the handler with the application-
owned `BusinessIdentityRepository`. `ApplicationBoundary.queries.businessLogo`
exposes the handler, and `ApplicationScope.of(context)` is the established
application-aware lookup from UI/runtime context.

## F. Current PDF Export Service Architecture

```text
PDF_EXPORT_SERVICE_FILE = lib/features/exports/pdf_export_service.dart
SERVICE_SYMBOL = PdfExportService
OWNERSHIP = STATIC_SERVICE
CURRENT_LOCATOR = AppRepositories.businessIdentityRepository
CURRENT_BRANDING_HELPER = PdfExportService._loadBranding
CURRENT_HELPER_PARAMETERS = NONE
CURRENT_DIRECT_DEPENDENCY =
AppRepositories.businessIdentityRepository.loadLogoBytes

PDF_EXPORT_SERVICE_DIRECT_INVOCATION_REMAINS = YES
RAW_QUERY_PRESENT = NO
CANONICAL_QUERY_PRESENT = NO
CURRENT_OWNERSHIP_PATTERN = STATIC_SERVICE_USING_APP_REPOSITORIES_LOCATOR
RUNTIME_CONTEXT_AVAILABLE = YES_AT_PUBLIC_METHODS_NO_INSIDE_CURRENT_HELPER
MIGRATION_STILL_REQUIRED = YES
```

`_loadBranding()` currently loads identity metadata through the locator. If
the identity has no valid logo it returns identity with `logoBytes == null`.
For valid metadata it calls the same locator directly for bytes. A direct
read exception is caught by the helper and falls back to identity with null
logo bytes. That fallback must remain unchanged when the query replaces the
direct byte read.

### Public entry points that reach branding

Every relevant entry point is static, returns `Future<bool>`, has a required
positional `BuildContext context`, has current indirect access to
`AppRepositories` through `_loadBranding()`, and calls that shared helper.

| Symbol | Additional parameters | Current logo flow |
|---|---|---|
| `exportSalesInvoice` | `SaleRecord sale`, `String customerName`, `Map<String, String> productNames` | initialize -> `_loadBranding()` -> sales invoice builder -> save/open/notify |
| `exportCustomerStatement` | `CustomerStatement statement`, `String customerName` | initialize -> `_loadBranding()` -> customer statement builder -> save/open/notify |
| `exportDailyReport` | `DailyActivityReport report`, `DateTime reportDate` | initialize -> `_loadBranding()` -> daily report builder -> save/open/notify |
| `exportPurchaseInvoice` | `PurchaseIntake purchase`, `String supplierName`, `String productName` | initialize -> `_loadBranding()` -> purchase invoice builder -> save/open/notify |
| `exportSupplierStatement` | `SupplierStatement statement`, `String supplierName` | initialize -> `_loadBranding()` -> supplier statement builder -> save/open/notify |
| `exportAccountBalanceReport` | `AccountBalanceReport report` | financial builder initialize -> `_loadBranding()` -> account balance builder -> notify |
| `exportAccountStatementReport` | `AccountStatementReport report` | financial builder initialize -> `_loadBranding()` -> account statement builder -> notify |
| `exportPaymentMethodReport` | `PaymentMethodReport report` | financial builder initialize -> `_loadBranding()` -> payment method builder -> notify |
| `exportTransferReport` | `TransferReport report` | financial builder initialize -> `_loadBranding()` -> transfer builder -> notify |

The four CSV methods do not call `_loadBranding()` and are not part of the
migration. The five printable-view callers already pass their local
`BuildContext`; no caller signature or caller file must change. The four
financial PDF methods have no current production call sites found by the
repository scan, but their live public bodies reach the helper and therefore
must be migrated consistently.

### Internal helper gap

```text
HELPER_FILE = lib/features/exports/pdf_export_service.dart
HELPER_SYMBOL = PdfExportService._loadBranding
CURRENT_PARAMETERS = NONE
CURRENT_DIRECT_DEPENDENCY =
AppRepositories.businessIdentityRepository.loadLogoBytes
WHY_CANONICAL_QUERY_IS_NOT_CURRENTLY_AVAILABLE =
NO_QUERY_OR_APPLICATION_RUNTIME_DEPENDENCY_IS_PASSED_TO_THE_HELPER
```

## G. Direct-Consumer Inventory

The current actual `.loadLogoBytes(` invocation set in production source is:

```text
CANONICAL_IMPLEMENTATION =
lib/application/queries/load_business_logo_query.dart
LoadBusinessLogoQueryHandler.execute

TARGET_ACTUAL_DIRECT_CONSUMER =
lib/features/exports/pdf_export_service.dart
PdfExportService._loadBranding

DEFERRED_ACTUAL_DIRECT_CONSUMER =
lib/core/backup/backup_export.dart
BackupExportService._identityWithLogoJson

OTHER_ACTUAL_DIRECT_CONSUMERS = NONE
```

The repository implementation/declaration is not classified as an application
consumer. Tests, spies, fixtures, and comments are also excluded. Excluding
the canonical query implementation leaves exactly the target and deferred
consumer.

## H. Exact Target and Non-Target Seams

```text
TARGET_FILE = lib/features/exports/pdf_export_service.dart
TARGET_SYMBOL = PdfExportService._loadBranding
TARGET_DIRECT_CALL =
AppRepositories.businessIdentityRepository.loadLogoBytes(
  identity.logo!.managedFileName)

TARGET_CONSUMER_LEGACY_CALL = MUST_DISAPPEAR

DEFERRED_FILE = lib/core/backup/backup_export.dart
DEFERRED_SYMBOL = BackupExportService._identityWithLogoJson
DEFERRED_CONSUMER_LEGACY_CALL = EXPECTED_TO_REMAIN
```

The target seam includes the nine public PDF entry-point bodies only because
they must supply the explicit query dependency to the one shared helper. It
does not include their external callers or any builder/header API.

Backup Export may remain visible in inventory assertions, but no Backup Export
implementation design, production edit, test behavior edit, or allowlist entry
is authorized by this plan.

## I. Chosen Migration Architecture

```text
CHOSEN_MIGRATION_PATTERN =
RESOLVE_CANONICAL_QUERY_AT_EACH_PUBLIC_APPLICATION_AWARE_ENTRY_POINT_BEFORE_FIRST_AWAIT_AND_PASS_EXPLICIT_HANDLER_DEPENDENCY_TO_SHARED_BRANDING_HELPER

PATTERN_COMBINATION = B_PLUS_C
PUBLIC_SIGNATURE_CHANGE = NO
CALLER_FILE_CHANGE = NO
BUILD_CONTEXT_PASSED_TO_HELPER = NO
NEW_GLOBAL_LOCATOR = NO
```

The future implementation must:

1. import the existing query and `ApplicationScope` types into
   `pdf_export_service.dart`;
2. at the start of each of the nine PDF entry points, before its first
   asynchronous gap, resolve
   `ApplicationScope.of(context).queries.businessLogo` into a local handler;
3. preserve the current initialization, builder, file, open, notification,
   error, and `context.mounted` ordering after that synchronous resolution;
4. change the private helper to require an explicit
   `LoadBusinessLogoQueryHandler` parameter;
5. preserve the locator-based identity metadata read and valid-logo gate;
6. inside the existing helper `try`, execute
   `LoadBusinessLogoQuery(managedFileName: identity.logo!.managedFileName)`
   through the passed handler;
7. use only `ApplicationQueryResult.value` as `_PdfBranding.logoBytes`;
8. retain the existing catch-to-null-logo fallback.

Resolving the handler before the first `await` avoids using `BuildContext`
across an asynchronous gap. Passing the handler rather than context keeps
application/UI lookup outside the low-level branding helper and makes its
read dependency explicit. All edits remain within one production file.

## J. Rejected Alternatives

### A. Pass BuildContext into `_loadBranding`

Rejected because it leaks widget-tree ownership into the low-level helper.
Calling `ApplicationScope.of(context)` after the helper's identity await would
also create a `BuildContext`-across-async-gap hazard. Resolving synchronously
at the public boundary is clearer and safer.

### B. Resolve and pass only already-loaded logo bytes

Rejected because it would duplicate the identity validity gate and fallback
flow across nine entry points or require another orchestration helper. The
shared helper already owns branding assembly and should retain it.

### C. Add a new public dependency parameter to every export API

Rejected because the current public methods already possess the application-
aware `BuildContext`. Widening public signatures would churn five printable
callers and any external consumers without architectural need.

### D. Construct `LoadBusinessLogoQueryHandler` inside the service

Rejected because that would bypass application composition, retain direct
repository ownership, and make the service create rather than consume the
canonical application query.

### E. Add another global locator or runtime singleton

Rejected because it would increase global ownership and violate the selected
application query boundary.

### F. Inject through a new PdfExportService instance/constructor

Rejected because converting the established static service is broader API and
composition churn than this single-read migration requires.

## K. Frozen Behavioral and Architectural Invariants

```text
NO_NEW_DIRECT_BUSINESS_IDENTITY_REPOSITORY_LOGO_LOAD = REQUIRED
CANONICAL_QUERY_BECOMES_SINGLE_APPLICATION_LOOKUP_PATH = REQUIRED
NO_NEW_GLOBAL_LOCATOR_ACCESS = REQUIRED
NO_BACKUP_EXPORT_CHANGE = REQUIRED
PDF_OUTPUT_BEHAVIOR_PRESERVED = REQUIRED
LOGO_NULL_FALLBACK_PRESERVED = REQUIRED
NO_REPORT_LAYOUT_REGRESSION = REQUIRED
NO_UNRELATED_SERVICE_API_CHURN = REQUIRED
NO_NEW_DATABASE_QUERY_PATH = REQUIRED
NO_RAW_SQL = REQUIRED
NO_NEW_RUNTIME_SINGLETON = REQUIRED
NO_UI_OWNERSHIP_TRANSFER = REQUIRED
```

The future implementation must additionally preserve:

- all nine public names, static ownership, parameters, and return values;
- the four CSV paths unchanged;
- identity metadata loading through the existing locator;
- the `identity.hasLogo && identity.logo != null` gate;
- exact managed filename propagation;
- present, empty, null, absent, invalid, and exception logo fallback behavior;
- all builder inputs, PDF bytes/content, branding header, fonts, Arabic/RTL
  layout, filenames, collision avoidance, file/open behavior, snackbars, and
  mounted checks;
- no business identity writes, logo writes, deletes, database reads, or
  application query creation;
- no changes to `LoadBusinessLogoQuery`, its handler, `ApplicationScope`,
  `ApplicationBoundary`, composition root, builders, headers, callers, or
  repositories.

## L. Exact Future Production Implementation Allowlist

```text
PRODUCTION_MODIFY =
lib/features/exports/pdf_export_service.dart

PRODUCTION_ADD = NONE
PRODUCTION_DELETE = NONE
```

Maximum production scope is exactly one file. No printable caller needs to
change because every public signature remains identical. No builder/header
needs to change because `_PdfBranding` continues to supply the same
`BusinessIdentity` and `Uint8List?` values.

## M. Exact Future Test Allowlist

One focused test is required:

```text
TEST_ADD =
test/post_advances_refunds_report_pdf_logo_query_migration_pdf_export_service_logo_query_migration_test.dart
```

The following thirteen cumulative inventory guards must be updated only for
the mechanically required PDF Export Service delta:

```text
TEST_MODIFY =
test/phase108i_second_read_only_ui_query_migration_test.dart
test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart
test/phase108m_shared_business_identity_header_logo_query_migration_test.dart
test/phase108n_settings_logo_preview_query_migration_test.dart
test/phase108o_printable_document_scaffold_logo_query_migration_test.dart
test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart
test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart
test/phase108r_payment_method_report_pdf_logo_query_migration_test.dart
test/post_expense_analysis_report_pdf_logo_query_migration_advances_refunds_report_pdf_logo_query_migration_test.dart
test/post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart
test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_expense_analysis_report_pdf_logo_query_migration_test.dart
test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_test.dart
test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_test.dart
```

No other test file is in the implementation mutation allowlist. In particular,
the builder and broader regression tests below are run unchanged.

The focused test must prove behavior, not only source replacement:

1. wrap a representative financial PDF export in `ApplicationScope` with a
   spy business-logo handler and replace only the existing locator identity
   repository with a spy;
2. mock the path-provider channel to an isolated temporary directory so
   `exportAccountBalanceReport` can complete without native platform state;
3. with valid identity metadata and valid PNG bytes, assert successful export,
   one locator identity read, zero locator direct logo reads, one canonical
   query repository read, exact managed filename, and a generated PDF file;
4. with absent/invalid logo metadata, assert successful null-logo export and
   zero canonical query reads;
5. with a canonical query result of null or empty bytes, assert successful
   fallback output and exact single query invocation;
6. with query/repository failure, assert the existing helper fallback still
   permits PDF generation without exposing the failure or performing writes;
7. assert no identity/logo save or delete occurs;
8. statically prove all nine public paths resolve and pass the handler, the
   helper consumes it, `.value` feeds `_PdfBranding`, and service public
   signatures/builders/error handling remain unchanged.

The cumulative guard changes must freeze the expected mechanical counts:

```text
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 133
FEATURE_SHARED_LOCATOR_FILE_COUNT = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 149
FEATURE_SHARED_APPLICATION_SCOPE_CONSUMER_COUNT = 17

LOGO_READ_FILES =
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
lib/core/business_identity/business_identity_repository.dart

ACTUAL_LOGO_INVOCATION_FILES =
lib/application/queries/load_business_logo_query.dart
lib/core/backup/backup_export.dart
```

Only assertions directly affected by these counts/sets may change. No guard
may be weakened, wildcarded, removed, or broadened.

## N. Static Source Proof Strategy

Future implementation must run and record scans equivalent to:

```text
rg -n --glob "*.dart" "\.loadLogoBytes\(" lib
rg -n "LoadBusinessLogoQuery|ApplicationScope\.of|_loadBranding" lib/features/exports/pdf_export_service.dart
rg -n "AppRepositories\.businessIdentityRepository" lib/features/exports/pdf_export_service.dart
rg -n "\.loadLogoBytes\(" lib/core/backup/backup_export.dart
git diff --name-only <planning-commit>..HEAD
```

Required post-change interpretation:

```text
PDF_EXPORT_SERVICE_DIRECT_LEGACY_LOAD_COUNT = 0
PDF_EXPORT_SERVICE_CANONICAL_QUERY_USAGE = PRESENT
PDF_EXPORT_SERVICE_IDENTITY_LOCATOR_READ = STILL_PRESENT
BACKUP_EXPORT_DIRECT_LOAD = STILL_PRESENT
OTHER_ACTUAL_DIRECT_CONSUMERS = NONE

TARGET_CONSUMER_LEGACY_CALL = MUST_DISAPPEAR
DEFERRED_CONSUMER_LEGACY_CALL = EXPECTED_TO_REMAIN
```

The Backup Export invocation is an intentional deferred boundary, not a
failure of the PDF Export Service slice.

## O. Future Implementation Regression Gates

The implementation session must run, in order:

```text
1. flutter test test/post_advances_refunds_report_pdf_logo_query_migration_pdf_export_service_logo_query_migration_test.dart

2. flutter test test/phase42_pdf_export_foundation_test.dart test/phase68_business_logo_invoice_windows_icon_test.dart

3. flutter test test/phase108i_second_read_only_ui_query_migration_test.dart test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart test/phase108m_shared_business_identity_header_logo_query_migration_test.dart test/phase108n_settings_logo_preview_query_migration_test.dart test/phase108o_printable_document_scaffold_logo_query_migration_test.dart test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart test/phase108r_payment_method_report_pdf_logo_query_migration_test.dart test/post_expense_analysis_report_pdf_logo_query_migration_advances_refunds_report_pdf_logo_query_migration_test.dart test/post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_expense_analysis_report_pdf_logo_query_migration_test.dart test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_test.dart test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_test.dart

4. the static source scans in Section N

5. flutter test --concurrency=1

6. flutter analyze

7. git diff --check
```

The implementation session must format only allowlisted Dart files and then
prove formatting introduced no out-of-scope diff. These are future required
gates; this planning session does not claim that any implementation test or
analyzer command has passed.

## P. Fail-Closed Implementation Conditions

Future implementation must stop without broadening scope if:

- the planning commit is not the current remotely locked baseline;
- a newer authority supersedes this scope or plan;
- target source, public paths, helper, query contract, or consumer inventory
  has materially drifted;
- any public path lacks a valid `ApplicationScope` runtime boundary;
- resolving the handler before the first await cannot be preserved;
- any caller, builder, repository, application composition, or Backup Export
  production edit becomes necessary;
- the exact fifteen-file implementation allowlist is insufficient;
- Backup Export disappears from the deferred direct-consumer inventory;
- any assertion must be weakened rather than updated to exact new counts;
- PDF behavior, logo fallback, layout, filenames, save/open/notification, or
  mounted semantics cannot be preserved;
- an unauthorized file changes, tests/analyzer fail, or remote fast-forward
  safety cannot be proven.

Do not solve any such blocker with a new locator, singleton, public API
redesign, query change, repository change, caller expansion, or Backup Export
work.

## Q. Planning-Session Mutation and Prohibition

```text
AUTHORIZED_TRACKED_FILE =
docs/POST-ADVANCES-REFUNDS-REPORT-PDF-LOGO-QUERY-MIGRATION-PDF-EXPORT-SERVICE-LOGO-QUERY-MIGRATION-PLAN.md

EXPECTED_TRACKED_FILES_CHANGED = 1
PRODUCTION_FILES_CHANGED_THIS_SESSION = NONE
TEST_FILES_CHANGED_THIS_SESSION = NONE
IMPLEMENTATION_STARTED = NO
BACKUP_EXPORT_PLANNING_STARTED = NO
BACKUP_EXPORT_IMPLEMENTATION_STARTED = NO
```

This planning session must create, commit, and remotely lock only this
artifact. No production implementation, test implementation, query wiring,
context threading, service API change, repository change, formatting, code
generation, cleanup, refactor, dependency change, tag, or deployment is
authorized.

## R. Successor Boundary

Only after this plan is committed, normally pushed, and directly verified on
the authorized remote may the following owner-gated session be requested:

```text
NEXT_POSSIBLE_SESSION =
PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION_IMPLEMENTATION

AUTOMATIC_IMPLEMENTATION_START = NO
BACKUP_EXPORT_REMAINS_OUT_OF_SCOPE = YES
```

That future session must independently re-fetch; prove this planning commit is
the current remote baseline; read this exact committed blob; revalidate the
target source and allowlist; and prove no newer authority supersedes it.

After a future PDF Export Service implementation is remotely locked, a fresh
owner/successor authority check remains mandatory before any Backup Export
planning. "Second" is ordering, not automatic authorization.
