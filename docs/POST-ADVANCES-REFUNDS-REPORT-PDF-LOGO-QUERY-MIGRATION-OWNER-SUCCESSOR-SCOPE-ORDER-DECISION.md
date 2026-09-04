# Post-Advances/Refunds Report PDF Logo Query Migration Owner Successor-Scope Order Decision

Date: 2026-09-04

## A. Session Identity

```text
SESSION =
OWNER_SUCCESSOR_SCOPE_ORDER_DECISION_AFTER_ADVANCES_REFUNDS_REPORT_PDF_LOGO_QUERY_MIGRATION

MODE = OWNER_DECISION_RECORDING_ONLY_FAIL_CLOSED

OWNER_ORDER_AUTHORITY_PRESENT = YES
```

This governance-only artifact records the repository owner's explicit order
between the two remaining direct consumers of the legacy business-logo byte
loading path. It performs no planning or implementation.

## B. Repository Identity and Entry Git State

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git

ENTRY_LOCAL_HEAD = 9fbadd63e8e058fe79f02a32bf0527bc914e7517
ENTRY_REMOTE_TRACKING_HEAD = 9fbadd63e8e058fe79f02a32bf0527bc914e7517
ENTRY_DIRECT_REMOTE_HEAD = 9fbadd63e8e058fe79f02a32bf0527bc914e7517
ENTRY_MERGE_BASE = 9fbadd63e8e058fe79f02a32bf0527bc914e7517
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0

CONFIGURED_UPSTREAM = NONE
REMOTE_TRACKING_AND_DIRECT_REMOTE_PROOF = PASS
WORKTREE_CLEAN = YES
INDEX_CLEAN = YES
UNTRACKED = NONE
STASH_STATE = EMPTY
SEQUENCER_STATE = NONE
RECOVERY_CLASSIFICATION = CLEAN_FRESH_REMOTE_LOCKED_PREDECESSOR_BASELINE
```

A fresh fetch from `origin`, followed by remote-tracking, merge-base, and
independent direct-remote verification, proved the entry state. The absence of
a configured upstream does not weaken the exact `origin/<branch>` and direct
remote agreement.

## C. Previous Blocked Outcome

The completed Advances/Refunds planning authority identified the post-
implementation invocation set as the canonical query implementation plus
exactly Backup Export and PDF Export Service. That authority excluded both
remaining consumers from its scope and prohibited successor selection or
adjacent seam work without separate authority.

After the Advances/Refunds implementation was remotely locked, no committed
authority ordered the two remaining consumers. Consequently, successor
planning was blocked pending an explicit owner order; neither source order nor
automatic queue inference could resolve the boundary. This artifact supplies
that missing authority only.

## D. Predecessor Authority Proof

```text
PREDECESSOR_PLANNING_COMMIT =
fc43681c8bcc915b1ab0b876c72b321fcb0d756f
PREDECESSOR_PLANNING_SUBJECT =
docs: plan advances refunds report pdf logo query migration

PREDECESSOR_IMPLEMENTATION_COMMIT =
9fbadd63e8e058fe79f02a32bf0527bc914e7517
PREDECESSOR_IMPLEMENTATION_SUBJECT =
fix: migrate advances refunds report pdf logo query

PREDECESSOR_PLANNING_ANCESTOR = YES
PREDECESSOR_IMPLEMENTATION_IS_CURRENT_BASELINE = YES
PREDECESSOR_REMOTE_LOCKED = YES
```

Committed Git objects prove that the planning commit's parent is the previous
owner-decision commit and that the implementation commit's parent is the
planning commit. The implementation commit is the local, remote-tracking, and
direct-remote entry head.

## E. Previous Owner Authority Proof

The committed owner authority at
`07850e22e221e4bc1309de66eb81cc07bd0aa452` selected only the
Advances/Refunds migration. Its committed artifact and descendant planning
authority established, in substance:

```text
BATCH_AUTHORIZED = NO
AUTOMATIC_SUCCESSOR_QUEUE_AUTHORIZED = NO
BACKUP_EXPORT_LOGO_QUERY_MIGRATION_AUTHORIZED = NO
PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION_AUTHORIZED = NO
AUTOMATIC_SUCCESSOR_SCOPE_EXPANSION = FORBIDDEN
```

The two final `*_AUTHORIZED = NO` values follow from the committed single-
scope selection, explicit exclusion of both seams, and prohibition on
successor selection or adjacent work without separate authority. The old
authority did not select or order either remaining consumer. This new explicit
owner instruction supersedes only that absence of ordering authority.

## F. Current Source Inventory

Current committed source was re-read at the entry baseline.

```text
CANONICAL_QUERY_IMPLEMENTATION =
lib/application/queries/load_business_logo_query.dart

CANONICAL_QUERY_DIRECT_INVOCATION =
lib/application/queries/load_business_logo_query.dart:33

BACKUP_EXPORT_DIRECT_INVOCATION =
lib/core/backup/backup_export.dart:800

PDF_EXPORT_SERVICE_DIRECT_INVOCATION =
lib/features/exports/pdf_export_service.dart:222

BACKUP_EXPORT_DIRECT_INVOCATION_REMAINS = YES
PDF_EXPORT_SERVICE_DIRECT_INVOCATION_REMAINS = YES
OTHER_ACTUAL_DIRECT_INVOCATIONS = NONE
REMAINING_DIRECT_CONSUMER_COUNT_EXCLUDING_CANONICAL_QUERY = 2
```

Neither candidate has already been migrated. Both still call
`BusinessIdentityRepository.loadLogoBytes(...)` directly, and neither uses
`LoadBusinessLogoQuery`.

## G. Candidate A Classification — Backup Export

```text
CANDIDATE_SCOPE = BACKUP_EXPORT_LOGO_QUERY_MIGRATION
SOURCE_PATH = lib/core/backup/backup_export.dart

DIRECT_LOAD_PRESENT = YES
RAW_QUERY_PRESENT = NO
CANONICAL_QUERY_PRESENT = NO

CURRENT_OWNERSHIP_PATTERN =
CORE_SERVICE_WITH_INJECTED_BUSINESS_IDENTITY_REPOSITORY

APPLICATION_SCOPE_AVAILABLE = NO
ARCHITECTURAL_COMPOSITION_REQUIREMENT =
QUERY_OR_DEPENDENCY_INJECTION_THROUGH_SERVICE_COMPOSITION

APP_REPOSITORY_LOCATOR_PRESENT = NO
RUNTIME_CONTEXT_AVAILABLE = NO
IS_UI_OWNED = NO
IS_CORE_SERVICE_OWNED = YES
REQUIRES_DIFFERENT_ARCHITECTURAL_PATTERN = YES
MIGRATION_STILL_REQUIRED = YES
```

`BackupExportService` receives an optional `BusinessIdentityRepository`
through its constructor and performs the logo read in its core-service export
flow. It has no `BuildContext`, `ApplicationScope`, or `AppRepositories`
locator access.

## H. Candidate B Classification — PDF Export Service

```text
CANDIDATE_SCOPE = PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION
SOURCE_PATH = lib/features/exports/pdf_export_service.dart

DIRECT_LOAD_PRESENT = YES
RAW_QUERY_PRESENT = NO
CANONICAL_QUERY_PRESENT = NO

CURRENT_OWNERSHIP_PATTERN =
STATIC_SERVICE_USING_APP_REPOSITORIES_LOCATOR

APPLICATION_SCOPE_AVAILABLE =
PARTIAL_BUILD_CONTEXT_AT_PUBLIC_ENTRY_POINTS_BUT_NOT_IN_LOAD_BRANDING_HELPER

ARCHITECTURAL_COMPOSITION_REQUIREMENT =
THREAD_CONTEXT_QUERY_OR_DEPENDENCY_INTO_SHARED_SERVICE_HELPER

APP_REPOSITORY_LOCATOR_PRESENT = YES
RUNTIME_CONTEXT_AVAILABLE =
YES_AT_PUBLIC_METHODS_NO_INSIDE_CURRENT_HELPER
IS_UI_OWNED = NO
IS_SERVICE_OWNED = YES
REQUIRES_DIFFERENT_ARCHITECTURAL_PATTERN = YES
MIGRATION_STILL_REQUIRED = YES
```

The public PDF export entry points receive `BuildContext`, while the shared
static `_loadBranding()` helper receives no runtime context and currently
uses `AppRepositories.businessIdentityRepository` for identity and logo-byte
reads.

## I. Explicit Owner Ordering Decision

```text
OWNER_ORDER_DECISION = EXPLICIT
SELECTION_AUTHORITY = EXPLICIT_OWNER_ORDER_DECISION

FIRST_SUCCESSOR = PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION
SECOND_SUCCESSOR = BACKUP_EXPORT_LOGO_QUERY_MIGRATION

SELECTED_SUCCESSOR_SCOPE =
PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION

DEFERRED_SUCCESSOR_SCOPE =
BACKUP_EXPORT_LOGO_QUERY_MIGRATION

DEFERRED_SCOPE_STATUS = REQUIRED_LATER_BUT_NOT_AUTHORIZED_NOW

PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION_SELECTED_FIRST = YES
BACKUP_EXPORT_LOGO_QUERY_MIGRATION_SELECTED_FIRST = NO
BACKUP_EXPORT_REMAINS_REQUIRED = YES
BACKUP_EXPORT_DEFERRED_NOT_CANCELLED = YES
```

PDF Export Service is **FIRST**.

Backup Export is **SECOND**.

"Second" does not mean automatically authorized after PDF Export
implementation. A new owner/successor authority check remains mandatory after
each remotely locked predecessor unless committed authority explicitly states
otherwise.

## J. Architectural Ordering Rationale

```text
SELECTION_RATIONALE =
PDF_EXPORT_SERVICE_HAS_RUNTIME_CONTEXT_AT_PUBLIC_ENTRY_POINTS_AND_CAN_BE_MIGRATED_BY_EXPLICIT_QUERY_OR_DEPENDENCY_THREADING_WITHOUT_OPENING_THE_DEEPER_BACKUP_EXPORT_CORE_SERVICE_COMPOSITION_SCOPE
```

PDF Export Service is first because its public service entry points already
possess runtime `BuildContext`/application runtime access. A later planning
session can therefore derive an explicit query or dependency threading seam
into the shared branding helper without opening the broader core-service
composition work required by Backup Export.

Backup Export remains required, but its injected repository ownership and
core-service composition require a different architectural pattern. Deferral
is sequencing, not cancellation.

## K. Exact Authorization Boundary

```text
PDF_EXPORT_SERVICE_PLANNING_MAY_BE_REQUESTED_IN_A_SEPARATE_SUCCESSOR_SESSION = YES
PDF_EXPORT_SERVICE_PLANNING_AUTHORIZED_TO_START_IN_THIS_SESSION = NO
PDF_EXPORT_SERVICE_IMPLEMENTATION_AUTHORIZED = NO

BACKUP_EXPORT_PLANNING_AUTHORIZED = NO
BACKUP_EXPORT_IMPLEMENTATION_AUTHORIZED = NO

PDF_EXPORT_SERVICE_PLANNING_STARTED = NO
PDF_EXPORT_SERVICE_IMPLEMENTATION_STARTED = NO
BACKUP_EXPORT_PLANNING_STARTED = NO
BACKUP_EXPORT_IMPLEMENTATION_STARTED = NO

BATCH_AUTHORIZED = NO
AUTOMATIC_SUCCESSOR_QUEUE_AUTHORIZED = NO
AUTOMATIC_NEXT_SUCCESSOR_SELECTION = NO
AUTOMATIC_SCOPE_EXPANSION = NO
```

This decision authorizes PDF Export Service as the next scope in sequence. It
does not authorize planning work inside this owner-decision session and does
not authorize implementation in any scope.

No `BuildContext`, repository, query, or dependency threading is performed.
No service constructor, static API, branding helper API, application query,
repository ownership, production source, or test is changed.

## L. Allowed Mutation Boundary

```text
AUTHORIZED_TRACKED_FILES =
docs/POST-ADVANCES-REFUNDS-REPORT-PDF-LOGO-QUERY-MIGRATION-OWNER-SUCCESSOR-SCOPE-ORDER-DECISION.md

EXPECTED_TRACKED_FILE_COUNT = 1
EXPECTED_PRODUCTION_FILES_CHANGED = 0
EXPECTED_TEST_FILES_CHANGED = 0
EXPECTED_CONFIG_FILES_CHANGED = 0
EXPECTED_DATABASE_FILES_CHANGED = 0
EXPECTED_DEPENDENCY_FILES_CHANGED = 0
EXPECTED_PLATFORM_FILES_CHANGED = 0
EXPECTED_GENERATED_FILES_CHANGED = 0
```

The mutation boundary is exactly one new additive governance document. No
planning artifact, implementation edit, test edit, cleanup, refactor,
dependency change, migration, generated file, tag, or deployment is allowed.

## M. Expected Successor Planning Handoff

Only after this decision is committed, pushed by normal fast-forward, and
directly verified on the authorized remote may a separate session be
requested:

```text
NEXT_PERMISSIBLE_SESSION =
PDF_EXPORT_SERVICE_LOGO_QUERY_MIGRATION_PLANNING

NEXT_SESSION_SCOPE = PLANNING_ARTIFACT_ONLY
NEXT_SESSION_IMPLEMENTATION = FORBIDDEN
BACKUP_EXPORT_IN_NEXT_SESSION = OUT_OF_SCOPE
```

That future session must independently re-fetch; re-prove repository identity
and direct remote lock; read this committed owner decision; inspect current
source; derive the exact migration seam; define tests and invariants; create
only a planning artifact; and perform zero implementation.

There is no automatic transition from this decision session into planning and
no automatic transition from the future PDF Export lifecycle into Backup
Export.
