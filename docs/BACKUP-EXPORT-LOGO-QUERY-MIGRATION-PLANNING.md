# Backup Export logo query migration planning

## A. Session Identity

```text
SESSION = BACKUP_EXPORT_LOGO_QUERY_MIGRATION_PLANNING
EVIDENCE_DATE = 2026-09-05
SELECTED_SUCCESSOR = BACKUP_EXPORT_LOGO_QUERY_MIGRATION
EXPECTED_ENTRY_AUTHORITY_COMMIT = a7a36c718c17436f46e8b7deb0e1690ee78e9816
IMPLEMENTATION_AUTHORIZED_NOW = NO
IMPLEMENTATION_STARTED = NO
BACKUP_EXPORT_PLANNING_STARTED = YES
BACKUP_EXPORT_IMPLEMENTATION_STARTED = NO
REUSE_EXISTING_CANONICAL_QUERY = YES
```

This document freezes a future implementation, not an implemented change.
Observed facts below are PLANNING_EVIDENCE. Proposed edits, runtime tests and
post-commit closure conditions are FUTURE_IMPLEMENTATION_ACCEPTANCE or explicitly
identified planning closure contracts. No future result is claimed in advance.

## B. Repository Identity

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
AUTHORIZED_REMOTE = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
```

Proven with `git rev-parse --show-toplevel`, `git branch --show-current` and
`git remote -v`; URLs also match committed owner authority. No remote changes.
No applicable repository/ancestor AGENTS.md was found by path checks and the
repository file inventory. The owner's supplied planning-only instruction governs.

## C. Entry Classification

```text
ENTRY_CLASSIFICATION = CASE_A_FRESH
ENTRY_WORKTREE_CLEAN = YES
ENTRY_INDEX_CLEAN = YES
ENTRY_STASH_EMPTY = YES
RECOVERY_REQUIRED = NO
IN_PROGRESS_GIT_OPERATION = NONE
```

`git status --short`, `git diff --cached` and `git stash list` were empty.
For each marker, `git rev-parse --git-path <marker>` resolved the actual Git
path and `Test-Path -LiteralPath` returned false: MERGE_HEAD, rebase-merge,
rebase-apply, CHERRY_PICK_HEAD, REVERT_HEAD, BISECT_LOG, BISECT_START, sequencer.
No file was written before entry and authority verification passed.

## D. Entry Remote-Lock Proof

A fresh `git fetch origin` succeeded before classification. A sandboxed direct
query initially failed with Windows SEC_E_NO_CREDENTIALS; the same read-only
query was retried outside the sandbox and succeeded. The failed attempt is
not used as remote evidence.

```text
LOCAL_HEAD = a7a36c718c17436f46e8b7deb0e1690ee78e9816
REMOTE_TRACKING_HEAD = a7a36c718c17436f46e8b7deb0e1690ee78e9816
DIRECT_REMOTE_HEAD = a7a36c718c17436f46e8b7deb0e1690ee78e9816
MERGE_BASE = a7a36c718c17436f46e8b7deb0e1690ee78e9816
AHEAD = 0
BEHIND = 0
ENTRY_REMOTE_LOCK = VERIFIED
```

Evidence commands: `git rev-parse HEAD`, `git rev-parse
origin/codex/phase-108h-app-shell-runtime-ownership-boundary`, `git ls-remote
--heads origin refs/heads/codex/phase-108h-app-shell-runtime-ownership-boundary`,
`git merge-base HEAD origin/codex/phase-108h-app-shell-runtime-ownership-boundary`
and `git rev-list --left-right --count
HEAD...origin/codex/phase-108h-app-shell-runtime-ownership-boundary`.

## E. Owner Decision Authority

```text
OWNER_DECISION_COMMIT = a7a36c718c17436f46e8b7deb0e1690ee78e9816
OWNER_DECISION_PATH = docs/POST-PDF-EXPORT-SERVICE-LOGO-QUERY-MIGRATION-OWNER-SUCCESSOR-SCOPE-DECISION.md
OWNER_DECISION_BLOB = abfc397b0d72b7e17e2a03ed3bd00484ba38608f
OWNER_DECISION_TREE = 4d1f96b3492564b51382062e5475132581403ff8
```

`git cat-file -t` returned commit for the authority object and blob for the
document object. `git ls-tree <authority> -- <path>` returned mode 100644 and
the exact expected blob. `git show <authority>:<path>` read the committed
decision; `git cat-file -p <authority>` verified its parent and tree.

Sections M through O select BACKUP_EXPORT_LOGO_QUERY_MIGRATION as
AUTHORIZED_FOR_SEPARATE_PLANNING_SESSION and explicitly withhold implementation.
Sections Q through T require exact remote lock and a separate planning session.
The current owner request authorizes that planning session only. No chat-only
claim substitutes for these committed objects.

## F. Predecessor Authority Chain

`git show -s --format='%H %P %s'` on each object proves these direct parent
edges, oldest first. An additional `git merge-base --is-ancestor 965be058...
a7a36c7...` check succeeded.

| Exact commit | Role | Exact direct parent |
| --- | --- | --- |
| `965be058477edce51bdb34c66f14b0b566fd3575` | Owner orders PDF Export first, Backup Export second | `9fbadd63e8e058fe79f02a32bf0527bc914e7517` |
| `3fa7639e7c4eaab615c3bd09a8d3b42babd227f5` | PDF Export Service planning | `965be058477edce51bdb34c66f14b0b566fd3575` |
| `6c3c722bc2e8dfc5dc181d7991fdfbe4bd746059` | PDF Export Service implementation | `3fa7639e7c4eaab615c3bd09a8d3b42babd227f5` |
| `a7a36c718c17436f46e8b7deb0e1690ee78e9816` | Fresh owner successor decision; this planning baseline | `6c3c722bc2e8dfc5dc181d7991fdfbe4bd746059` |

Committed owner-order and PDF-plan content confirms Backup was deferred, not
cancelled, and required fresh owner authority after PDF remote lock. Historical
ordering alone does not authorize implementation or automatic progression.

## G. Current Source Revalidation

All source evidence is anchored to committed baseline a7a36c7 above, using
`git show HEAD:<path>` and `git grep ... HEAD -- lib test`. Line numbers below
refer to that baseline, not to future edits.

| Source | Committed blob | Finding |
| --- | --- | --- |
| `lib/core/backup/backup_export.dart` | `926dff5964f13368e9a76504f45ac3b1c35f4126` | Service at line 41; constructor 42; createBackup 100; helper 791; direct read 800 |
| `lib/app/app_repositories.dart` | `d1d2b1f91fa758e61467167abefecefdb0cefb9b` | Sole production constructor call, getter at 266 |
| `lib/application/queries/load_business_logo_query.dart` | `7d3f497e3fd0a0ea2471662af1bba4802f79dbce` | Canonical query, handler and permitted read at 33 |
| `lib/composition/app_composition_root.dart` | `bb0f6a06692a432025c5b7b470416b267bfdcd34` | Existing businessLogo handler composition at 130 |

The constructor currently requires ProductCatalogReadRepository,
InventoryRepository, SupplierRepository, PurchaseRepository, SaleRepository
and DocumentHistoryRepository. Optional dependencies are BusinessIdentityRepository,
CustomerRepository, CustomerAccountRepository, SupplierAccountRepository,
ExpenseRepository, AuditLogStorageRepository, FinancialAccountRepository,
NegativeBalanceApprovalRequestRepository, DurableInventoryValuationRepository
and `DateTime Function()? now`. Existing defaults and all non-logo uses are frozen.

## H. Backup Export Direct Consumer Proof

`BackupExportService._identityWithLogoJson(BusinessIdentity identity)` returns
`Future<Map<String, Object?>>`. It calls the injected field's
`_businessIdentityRepository.loadLogoBytes(identity.logo!.managedFileName)`.
It contains no AppRepositories, ApplicationScope or BuildContext lookup.

There is exactly one helper call site: `createBackup`, under
`data.settings.businessIdentity`. Production callers of createBackup are:

| Caller | Affected export path |
| --- | --- |
| `lib/features/backup/backup_export_screen.dart`, `_createBackup` | Interactive creation; copy/save reuse the existing result without another logo read |
| `lib/core/backup/business_data_wipe_service.dart`, wipe workflow | Required backup before destructive business-data wipe; preview, validation and save consume that result |

`AppRepositories.backupExportService` constructs the service for the screen
and for `AppRepositories.businessDataWipeService`. Tests also instantiate it
directly in 22 existing files. There is no second export method or helper loop.
The private helper is reached once per successful snapshot-building operation;
an earlier repository failure can prevent reaching it altogether.

## I. Canonical Query Handler Proof

`LoadBusinessLogoQuery` has one required String input, `managedFileName`.
`LoadBusinessLogoQueryHandler` is final, implements the existing
`ApplicationQueryHandler<LoadBusinessLogoQuery, Uint8List?>`, and accepts one
required `BusinessIdentityRepository repository` constructor argument.
`execute` returns `Future<ApplicationQueryResult<Uint8List?>>`.

An empty filename produces null without a repository read. Otherwise the exact
filename is forwarded once; null, empty and nonempty bytes are returned without
transformation. Metadata is local/currentKnownState with managedFile authority.
No catch, retries, writes, hashing or serialization occur in the handler.
Exceptions propagate unchanged.

`ApplicationQueries.businessLogo` in `lib/application/application_boundary.dart`
exposes the concrete handler. `AppCompositionRoot` builds it from
`dependencies.repositories.businessIdentityRepository`, captured through
`lib/composition/legacy_application_dependency_bridge.dart`.
`lib/composition/application_scope.dart` exposes the boundary to widget/context
consumers. Backup can use the exact existing query and handler without changing
the input, result, metadata, repository port or registration.

PLANNING_EVIDENCE: the committed canonical tests in
`test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart` cover
byte identity, empty filename, null, exact exception propagation, metadata,
read cardinality and no writes. They were inspected, not executed here.
Canonical health here means a valid inspected contract; a fresh green runtime
result is a mandatory future implementation gate.

## J. Reference Migration Evidence

The actual diff of 6c3c722 against its planning parent changes PDF service
imports, nine handler captures and `_loadBranding` threading. Each entry point
captures `ApplicationScope.of(context).queries.businessLogo` before its first
await; the helper executes the query and consumes `result.value`. Identity
loading and catch-to-no-logo fallback stay unchanged. No composition file was
changed because those entry points already have context. Its focused test uses
separate identity and query repository spies and guards all nine source paths.
Thirteen cumulative guards were updated for that predecessor's inventory delta.

Earlier account/report consumers also resolve businessLogo through the existing
scope, invoke the same query and retain their output rules. Backup differs: it
already has constructor injection and needs no widget scope. The plan therefore
uses explicit service injection at its existing factory and preserves the
identity repository. It does not copy PDF's locator or context dependency.

## K. Remaining Consumer Inventory

Committed repository-wide searches included `loadLogoBytes`,
`.loadLogoBytes(`, `LoadBusinessLogoQuery(`, `LoadBusinessLogoQueryHandler`,
`_identityWithLogoJson`, `BackupExportService(` and `createBackup(`.

| Classification | Observed production inventory |
| --- | --- |
| Unmigrated direct business-logo consumer | Only `lib/core/backup/backup_export.dart`, `_identityWithLogoJson` |
| Canonical invocation infrastructure | Only `lib/application/queries/load_business_logo_query.dart` |
| Repository declarations/implementation | `lib/core/business_identity/business_identity_repository.dart`; valid infrastructure, not a consumer |
| Already migrated consumers | 13 feature/shared files listed below |
| Wiring | Application boundary, composition root/bridge/scope and AppRepositories getter; no additional logo read |
| Tests/fixtures | Repository spies, legacy feature/backup round trips and cumulative source inventory expectations; not production reads |
| Other image/logo work | Image rendering/PDF builders, metadata validation, managed-logo writes/deletes and restore payload decoding/saving; outside this read migration |

The 13 migrated files are:

```text
lib/features/dashboard/dashboard_shell.dart
lib/shared/widgets/business_identity_header.dart
lib/features/settings/settings_screen.dart
lib/features/prints/printable_document_scaffold.dart
lib/features/financial_reports/account_balance_report_screen.dart
lib/features/financial_reports/account_statement_report_screen.dart
lib/features/financial_reports/payment_method_report_screen.dart
lib/features/financial_reports/transfer_report_screen.dart
lib/features/financial_reports/inflows_report_screen.dart
lib/features/financial_reports/outflows_report_screen.dart
lib/features/financial_reports/expense_analysis_report_screen.dart
lib/features/financial_reports/advances_and_refunds_report_screen.dart
lib/features/exports/pdf_export_service.dart
```

The Settings `_loadLogoBytes(context)` helper is already a query consumer;
its name is not a repository invocation. Backup restore's embedded-payload
decoding and managed-file save logic is not a secondary logo-query consumer.
Exactly two production files invoke `.loadLogoBytes(` at entry: Backup and the
handler. The wider symbol set also includes repository infrastructure.
The owner decision remains valid; no extra production migration is selected.
Any newly discovered additional direct production consumer requires a fresh
scope determination; material contradiction with this inventory fails closed.

## L. Current Behavior Contract

P5 and P6 are frozen as follows:

| Condition/aspect | Required unchanged behavior |
| --- | --- |
| Identity read | `await _businessIdentityRepository?.loadIdentity() ?? BusinessIdentity.empty`; this legitimate read remains |
| Absent repository | Empty identity; no logo query or repository logo read |
| Absent logo | `identity.toJson()` omits the logo key; do not introduce an explicit null key |
| Invalid metadata | hasLogo is false; original metadata JSON remains if logo is non-null; do not normalize or delete it |
| Valid metadata | Filename, MIME and SHA are nonempty and declared length positive; dimensions are not an extra validity gate |
| Read returns null/empty, hash mismatch, or throws | Return the original identity JSON, including original managed-file metadata; do not clear the logo field |
| Valid nonempty bytes with matching SHA-256 | Replace only logo with exactly mimeType, base64Data, sha256, byteLength, width, height |
| Embedded representation | Base64 of unmodified bytes; computed SHA-256 string; actual bytes.length; MIME/dimensions from identity metadata; no managedFileName in this successful payload |
| Declared length/dimensions | Do not add length-equality checks, dimension checks, image decoding or MIME transformations |
| Identity fields | Preserve establishmentName, taxNumber, address, phone, their values and conditional key inclusion |
| Serialization | Version 8, metadata/counts/data/checksum/checksumNote, all existing collection keys, ordering and inclusion/exclusion remain unchanged |
| Checksum/encoding | Await identity/logo before BackupChecksum.computePayload; retain two-space JsonEncoder, validator, UTF-8 file-writing behavior and base64 representation |
| File/archive | Plain JSON file, no ZIP/archive layer; `grain-warehouse-backup-YYYYMMDD-HHMMSS.json` using local time; generatedAt remains UTC text |
| Security/data rules | Existing sensitive-key rejection, counts, warning strings and restoreSupported false remain unchanged |
| Restore/save/copy/wipe | Existing consumers receive the same BackupExportResult and payload; no restore, writer, screen or wipe code changes |

Cardinality is conditional, not an unconditional read on every export:
exactly one canonical execution and repository logo read when valid logo
metadata reaches the helper; zero when metadata/repository is absent or invalid,
or export fails before the helper. No retries or per-record calls. A second
createBackup call performs a fresh read; copying/saving its result does not.
The awaited logo remains at its existing point after identity acquisition and
before checksum/encoding. No Future.wait, prefetch or new cross-export cache.

P7: LocalBusinessIdentityRepository.loadLogoBytes returns null for empty,
traversal or missing paths; filesystem exists/read failures can throw. The
canonical handler forwards nonempty input and preserves those outcomes.
Its empty-input short circuit has no observable effect here because hasLogo
already requires a nonempty filename. Keep query execution and `.value`
consumption inside the helper's existing try/catch. Identity-read failures
remain outside that catch and continue to fail createBackup.

## M. Target Architecture

```text
AppRepositories.backupExportService (existing factory)
  -> explicitly injected LoadBusinessLogoQueryHandler
BackupExportService._identityWithLogoJson
  -> handler.execute(LoadBusinessLogoQuery(managedFileName: ...))
  -> ApplicationQueryResult.value
  -> unchanged backup hash/base64/JSON logic
LoadBusinessLogoQueryHandler
  -> BusinessIdentityRepository.loadLogoBytes
```

P1: retire only the direct logo method invocation. Retain the existing
BusinessIdentityRepository parameter/field/import for loadIdentity.
P2: use the existing concrete LoadBusinessLogoQueryHandler and query; no new
query class, repository abstraction, callback port or modified result contract.

P3: add exactly one optional named constructor parameter:
`LoadBusinessLogoQueryHandler? businessLogoQuery` and a corresponding final
nullable `_businessLogoQuery` field. Keep every existing constructor parameter
and createBackup/helper public contract unchanged. Prefer an explicitly supplied
handler. For existing callers that omit it, construct the same canonical handler
once in the constructor from the supplied businessIdentityRepository, if present;
if both are absent, retain a null handler and current empty-identity behavior.
This compatibility default is canonical routing over the injected repository,
not a fallback direct read. No new repository is constructed for logo loading.

This additive design preserves the 22 existing test construction sites and
external constructor usage without forcing unrelated fixture rewrites or silently
dropping logos. Production always supplies the explicit handler. Do not make
the new parameter required or silently treat omitted injection as no logo when
an identity repository exists. Keep handler selection final per service instance.

## N. Exact Production Delta Plan

Only `lib/core/backup/backup_export.dart` may change service behavior:

1. Import the existing query/handler library; add the parameter, final field and
   constructor compatibility initialization described in M.
2. Preserve identity acquisition and the existing valid-logo/repository guard.
   Use a local final handler reference with null guard for safe invocation.
3. Replace the one repository logo await with one execute call using the exact
   managed filename and assign `result.value` to logoBytes inside the same try.
4. Keep every subsequent null/empty/hash check and serialized map unchanged.

P1-P3 do not authorize removal of the identity repository, moving serialization
into the handler, changing other dependencies or adding a runtime locator.

## O. Composition/Wiring Plan

P4: the only wiring edit is `lib/app/app_repositories.dart`. Import the existing
query library and add `businessLogoQuery: LoadBusinessLogoQueryHandler(repository:
businessIdentityRepository)` to the existing backupExportService construction.
The existing unqualified repository member must supply both identity and logo
dependencies in the same synchronous factory evaluation. No global handler field,
cached singleton or static accessor is introduced.

The handler instance need not be the identical object exposed by a widget's
ApplicationBoundary: the canonical contract and underlying application-owned
repository are reused. This factory predates the scope; routing it through that
scope would add a cycle/context requirement. AppCompositionRoot's existing
registration, ApplicationBoundary, dependency bridge and ApplicationScope stay
unchanged. No UI, restore or wipe constructor changes are necessary.

## P. Testing Plan

P8: add only `test/backup_export_logo_query_migration_test.dart` for focused
behavior and structure. Follow phase13/phase106ab backup fixtures using existing
local repositories and `test/support/product_catalog_read_repository_test_adapter.dart`;
use an isolated temporary directory when filesystem behavior is needed. Reuse
the established two-repository-spy technique from the PDF migration. Because the
concrete handler is final, inject a real handler over a separate repository spy;
do not subclass it or loosen its type.

| Test | Exact future assertion |
| --- | --- |
| T1 canonical use | Inject identity repository A and real handler over spy B. With valid metadata: one A.loadIdentity, zero A.logo reads, one B.logo read with exact filename, no B identity read; result embeds B bytes |
| T2 retirement | Structural whole-lib method/reference scan rejects direct service calls or tear-offs; helper uses execute/LoadBusinessLogoQuery/result.value; only canonical handler invokes repository logo read; no service locator/import/global access |
| T3 present | Fixed time and identity; assert exact six embedded logo keys, byte-for-byte base64 round trip, SHA, actual length, MIME and dimensions; all non-logo identity values identical |
| T4 absent/fallback | Absent repository, absent logo, invalid/empty filename metadata, null bytes, empty bytes, hash mismatch and thrown sentinel all preserve the exact original JSON; assert zero or one reads according to L |
| T5 compatibility | Freeze full expected envelope/key sets, version 8, counts/data, filename, timestamp, checksum and indented JSON for a deterministic fixture; absent logo key stays absent. Exercise existing restore round trips unchanged |
| T6 backup regression | Run existing phase13, phase14, phase68, phase81, phase95, phase106ab, phase107b and phase107c suites named in Q; no legacy fixture changes |
| T7 canonical regression | Run unchanged behavioral/metadata/error tests in phase108l; only its cumulative inventory expectation may change |
| T8 compatibility injection | Omit new argument but provide repository: exactly one canonical-routed read and preserved logo. Explicit B handler wins over A. No repository plus a supplied handler still exports empty identity with zero query reads |
| T9 sequencing/cardinality | Hold B's read with Completer; createBackup must remain pending until completion, then checksum covers the embedded value. Two exports cause two reads; zero retries on failure |
| T10 wiring/no writes | Exercise AppRepositories factory with isolated identity repository, restore test global in teardown, verify export content; structural assertion proves explicit injection from the same member. Assert no identity/logo save/delete during export |
| T11 error boundary | A.loadIdentity sentinel propagates; B.logo sentinel is caught as original metadata JSON; no new catch around the entire backup |

Add a declared-byteLength mismatch case with matching hash to ensure actual
byte length still wins, and invalid dimensions/opaque bytes cases to ensure
this migration adds no image validation. Tests must protect public createBackup
behavior rather than exposing or making the private helper public.

Ten existing guards (R) require precise updates. Remove Backup only from the
logo-read symbol/invocation sets, change Q's invocation count from two to one,
and update PDF's explicit deferred-backup assertion to canonical routing.
Keep all PDF nine-entry assertions and prior migrated-consumer checks. Do not
weaken guards, delete them or update historical Git scope endpoints.

Expected final inventories:

```text
ACTUAL_LOGO_INVOCATION_FILES = lib/application/queries/load_business_logo_query.dart
LOGO_READ_SYMBOL_FILES = lib/application/queries/load_business_logo_query.dart, lib/core/business_identity/business_identity_repository.dart
UNMIGRATED_DIRECT_PRODUCTION_CONSUMERS = 0
FEATURE_SHARED_APP_REPOSITORIES_REFERENCES = 133
FEATURE_SHARED_LOCATOR_FILE_COUNT = 36
ALL_LIB_APP_REPOSITORIES_REFERENCES = 149
FEATURE_SHARED_APPLICATION_SCOPE_CONSUMER_COUNT = 17
CONCRETE_QUERY_SLICE_COUNT = 4
```

The last five counts remain unchanged: the chosen factory uses an unqualified
member, and Backup adds no locator/scope access or new query slice. Phase108M,
108N and 108P guards therefore run unchanged and are not mutation-allowlisted.

## Q. Validation Plan

These are FUTURE_IMPLEMENTATION_ACCEPTANCE commands, not results of this
planning session. Run from the repository root after only the allowed edits.

```powershell
flutter test test/backup_export_logo_query_migration_test.dart
flutter test test/phase13_backup_export_test.dart test/phase14_backup_file_save_test.dart test/phase68_business_logo_invoice_windows_icon_test.dart test/phase81_transaction_financial_backup_contract_test.dart test/phase95_business_profile_expansion_test.dart test/phase106ab_backup_export_product_catalog_migration_test.dart test/phase107b_atomic_business_data_wipe_test.dart test/phase107c_backup_restore_checksum_verification_test.dart
flutter test test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart test/phase108m_shared_business_identity_header_logo_query_migration_test.dart test/phase108n_settings_logo_preview_query_migration_test.dart test/phase108o_printable_document_scaffold_logo_query_migration_test.dart test/phase108p_account_balance_report_pdf_logo_query_migration_test.dart test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart test/phase108r_payment_method_report_pdf_logo_query_migration_test.dart
flutter test test/post_advances_refunds_report_pdf_logo_query_migration_pdf_export_service_logo_query_migration_test.dart test/post_expense_analysis_report_pdf_logo_query_migration_advances_refunds_report_pdf_logo_query_migration_test.dart test/post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_test.dart test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_test.dart test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_expense_analysis_report_pdf_logo_query_migration_test.dart
rg -n --glob '*.dart' '\.\s*loadLogoBytes\s*\(' lib
rg -n --glob '*.dart' 'loadLogoBytes' lib
rg -n 'LoadBusinessLogoQuery|businessLogoQuery|loadIdentity|AppRepositories|ApplicationScope' lib/core/backup/backup_export.dart lib/app/app_repositories.dart
flutter test --concurrency=1
flutter analyze
git diff --check
```

Inspect wider-symbol matches for method tear-offs/aliases, declarations and
unrelated helper names, rather than treating grep counts alone as architecture
proof. Expected direct invocation set is the handler only; legitimate repository
implementation remains. Verify baseline-to-implementation file names against R.
Format only actually changed allowlisted Dart files before testing. Never run
a repository-wide formatting sweep. Full serial regression and analyzer retain
the predecessor governance floor and cover the 22 compatible constructor users,
restore/wipe interactions and cumulative guards. Failed tests do not authorize
expanding the allowlist; investigate and stop for renewed authority if needed.

## R. Exact Implementation Allowlist

P9: exactly 13 possible implementation files: two production, one new focused
test and ten narrowly scoped cumulative guard updates. No directory wildcards.

| ID | Exact path | Permitted reason |
| --- | --- | --- |
| R1 | `lib/core/backup/backup_export.dart` | Constructor query injection/default and sole helper read replacement only |
| R2 | `lib/app/app_repositories.dart` | Existing backup factory's explicit canonical handler injection/import only |
| R3 | `test/backup_export_logo_query_migration_test.dart` | New T1-T11 regression coverage |
| R4 | `test/phase108l_dashboard_app_bar_business_logo_query_migration_test.dart` | Remove Backup from exact logo symbol set; preserve canonical tests |
| R5 | `test/phase108o_printable_document_scaffold_logo_query_migration_test.dart` | Remove Backup from exact logo symbol set only |
| R6 | `test/phase108q_account_statement_report_pdf_logo_query_migration_test.dart` | Symbol set and actual invocation cardinality 2 to 1 only |
| R7 | `test/phase108r_payment_method_report_pdf_logo_query_migration_test.dart` | Remove Backup from exact symbol/invocation sets only |
| R8 | `test/post_phase_108r_transfer_report_pdf_logo_query_migration_test.dart` | Same exact inventory retirement only |
| R9 | `test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_test.dart` | Same exact inventory retirement only |
| R10 | `test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_test.dart` | Same exact inventory retirement only |
| R11 | `test/post_transfer_report_pdf_logo_query_migration_inflows_report_pdf_logo_query_migration_outflows_report_pdf_logo_query_migration_expense_analysis_report_pdf_logo_query_migration_test.dart` | Same exact inventory retirement only |
| R12 | `test/post_expense_analysis_report_pdf_logo_query_migration_advances_refunds_report_pdf_logo_query_migration_test.dart` | Same exact inventory retirement only |
| R13 | `test/post_advances_refunds_report_pdf_logo_query_migration_pdf_export_service_logo_query_migration_test.dart` | Retire deferred Backup assertion and inventory entry; preserve all PDF behavior/ownership guards |

Associated test labels may be corrected only where they describe the retired
Backup expectation. Tests listed in Q but absent from R must run unchanged.
This planning artifact is not in the future implementation edit allowlist.
If any additional production/test/document file is needed, stop and obtain
renewed owner authority; do not silently enlarge this list.

## S. Explicit Denylist

P10: all paths outside R are denied for implementation mutation. Specifically
freeze query/handler/application_query, ApplicationBoundary, AppCompositionRoot,
ApplicationScope, application dependencies/bridge, business identity model and
repository, backup checksum, writer, restore/preview, business-data wipe, UI,
PDF service/builders, other reports, persistence and database schema/migrations.

No backup/schema/archive/restore redesign, version bump, JSON/identity/key change,
filename/encoding change, altered inclusion/exclusion or business rules. No
package/dependency/lockfile/platform change, generated code, formatting sweep,
new repository abstraction, locator inside Backup, global mutable access,
singleton shortcut, hidden static dependency, unrelated test/refactor/cleanup,
owner-successor decision or additional migration. Planning itself changes none
of R; only this one Markdown artifact is authorized now.

## T. Acceptance Matrix

| Gate | Measurable PASS condition | Evidence/status boundary |
| --- | --- | --- |
| A1 | Authority commit/type/path/blob exactly match E and permit separate planning only | Proven committed objects |
| A2 | Fresh local/tracking/direct/merge-base equal authority, 0/0; clean administrative state | Proven C-D |
| A3 | Committed helper still has the injected direct logo read | Proven G-H |
| A4 | Only Backup remains outside canonical infrastructure | Proven K |
| A5 | Existing input/result/error/read-only contract remains valid and reusable; fresh runtime tests required later | Inspected I; future T7/Q |
| A6 | Constructor/default, canonical execution and factory injection are specified without new locator | Frozen M-O |
| A7 | Every observable backup invariant and fallback in L has an explicit preservation/test condition | Frozen L/P |
| A8 | Exact 13-file implementation allowlist, reasons and stop-on-expansion rule | Frozen R |
| A9 | T1-T11, actual regression paths and commands specified | Frozen P-Q |
| A10 | Implementation scan finds handler as sole actual repository caller; service has no direct call/tear-off | Future T2/Q; proof condition frozen now |
| A11 | No production/test/dependency/migration/implementation edits in this session | Verify baseline delta before and after commit |
| A12 | Complete worktree/index/commit delta is this single planning document | Precommit and X |
| A13 | One normal commit, exact authority parent, recorded commit/tree/blob; no history rewrite | Postcommit X |
| A14 | Fresh pre-push parent equality, 1/0, then one normal fast-forward push succeeds | Postcommit Y |
| A15 | Fresh post-push local/tracking/direct/merge-base equality at planning commit, 0/0, clean state and matching tree/blob | Post-push Y |

A1-A10 are planning evidence or frozen future acceptance definitions. A11-A15
must be measured at closure and reported in the final execution report. This
precommit artifact does not claim its own future commit/push already exists.

## U. Risks / Edge Cases

Preserving only successful base64 output is insufficient: null, corrupt and
failed reads currently retain metadata JSON, which restore can later warn about.
Keep this exact behavior. Empty filename is already gated before execution;
do not add normalization or broaden catches. A missing newly injected handler
must not silently disable logos for existing constructor callers; the canonical
compatibility default and T8 address that risk. The default performs no I/O at
construction, and does not retry a failing explicit handler.

Identity and logo dependencies must refer to the same owned store in production.
Different stores are deliberately used only in the behavioral routing test.
Do not cache the factory's handler across repository reinitialization. No await
is introduced between choosing these constructor dependencies. Existing serial
export collection/identity/logo order remains intact.

Cumulative guards intentionally require the old Backup seam today. Retiring
that expectation is necessary within this newly authorized future slice;
rewriting prior historical scope assertions is not. A changed canonical contract,
additional consumer, incompatible source drift or insufficient allowlist blocks
implementation instead of licensing an architectural redesign.

## V. Implementation Session Entry Contract

Require a separate owner-authorized BACKUP_EXPORT_LOGO_QUERY_MIGRATION_IMPLEMENTATION
session. Resolve this document's exact first containing planning commit and blob
from the final report and committed Git objects, not a floating latest ref. Its
parent must be a7a36c718c17436f46e8b7deb0e1690ee78e9816 and its only changed file
must be this document. Verify final remote lock independently with a fresh fetch,
direct ls-remote, merge-base, 0/0 and clean worktree/index/stash/sequencer checks.

Read this committed plan and the exact owner chain; revalidate the four source
blobs in G, constructor/caller inventory, helper semantics, canonical contract
and all ten live guards. Fresh state must match the frozen plan. Recovery is
allowed only for provably this exact implementation's authorized work; unknown,
mixed or stale state fails closed. No reset, destructive restore, stash hiding,
clean, amend, rebase, force, branch switch or remote reconfiguration.

## W. Planning / Implementation Boundary

```text
IMPLEMENTATION_AUTHORIZED_NOW = NO
IMPLEMENTATION_STARTED = NO
SOURCE_CHANGES = 0
TEST_CHANGES = 0
DEPENDENCY_CHANGES = 0
MIGRATION_CHANGES = 0
IMPLEMENTATION_CHANGES = 0
PLANNING_ARTIFACTS = 1
```

Only `docs/BACKUP-EXPORT-LOGO-QUERY-MIGRATION-PLANNING.md` may be added now.
No implementation test, source edit or runtime implementation acceptance run
is performed in planning. Use Git/read-only discovery/content/diff verification
as planning evidence. Commit, normal push, independently prove remote lock,
report and STOP; no automatic implementation or next-owner decision.

## X. Local Closure Proof

Planning closure contract, measured after writing and in the final report:

1. Inspect `git status --short`, `git diff --stat`, `git diff --name-only` and
   `git diff --check`. For the new document also inspect its full content and
   stage only its exact path; inspect cached name/status/stat/diff/check output.
2. Verify identity tokens, IMPLEMENTATION_AUTHORIZED_NOW = NO,
   IMPLEMENTATION_STARTED = NO, exact R allowlist and A1-A15 matrix in the text.
3. Create one normal commit: `docs: plan backup export logo query migration`.
4. Record PLANNING_COMMIT, PLANNING_PARENT, PLANNING_TREE and ARTIFACT_BLOB
   using rev-parse/show/ls-tree/cat-file. Parent must be the exact authority
   baseline. Baseline-to-commit name/status must contain only this document.
5. Prove empty short status, cached/working diff, no unintended files and no
   production/test/dependency/migration changes; then report
   PLANNING_LOCAL_CLOSURE = COMPLETE and IMPLEMENTATION_STARTED = NO.

The containing commit hash cannot be embedded into its own blob. Its exact
commit/tree/blob and completed closure results belong to the final execution
report; no second bookkeeping commit or amend is authorized.

## Y. Remote-Lock Proof

Immediately before push, fresh-fetch origin and directly query the branch.
Required: local = planning commit; tracking = direct remote = merge-base =
authority parent; ahead 1, behind 0; clean worktree/index. If the remote has
advanced unexpectedly, stop without push/merge/rebase.

Only one normal fast-forward push is authorized:

```text
git push origin HEAD:codex/phase-108h-app-shell-runtime-ownership-boundary
PUSH_MODE = NORMAL_FAST_FORWARD
FORCE_PUSH = FORBIDDEN
```

After success, fresh-fetch and independently query direct remote again.
Require local HEAD, remote tracking HEAD, direct remote HEAD and merge-base all
equal the exact planning commit with ahead/behind 0/0. Verify clean status/index,
the committed artifact blob equals the staged/working content, local and remote
trees match, and authority-to-planning delta remains this one document.
Only then report PLANNING_REMOTE_LOCK = COMPLETE. Actual postcommit evidence
is recorded in the final execution report, never preclaimed by this contract.

## Z. Exact Next Authorized Session

Only after A1-A15 pass, local closure and independent remote lock complete,
the final report may identify the following next candidate session. This is
not permission to start it automatically; a separate implementation request
is still required.

```text
NEXT_AUTHORIZED_SESSION = BACKUP_EXPORT_LOGO_QUERY_MIGRATION_IMPLEMENTATION
BACKUP_EXPORT_PLANNING_COMPLETED = YES
BACKUP_EXPORT_IMPLEMENTATION_STARTED = NO
SUCCESS_TOKEN = PASS_BACKUP_EXPORT_LOGO_QUERY_MIGRATION_PLANNING_REMOTE_LOCKED
```

This block is conditional on measured closure. Failure of any gate requires a
precise BLOCKED report without emitting the success token as an achieved result.
