# Recovery, Trial, and Licensing Boundary Implementation Plan

```text
PLANNING_COMPLETE = YES
IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED_THIS_SESSION = NO
SESSION = RECOVERY_TRIAL_AND_LICENSING_BOUNDARY_PLANNING
SESSION_CLASS = PLANNING_ONLY
EVIDENCE_DATE = 2026-09-15 (Africa/Cairo)
```

This is the canonical implementation plan for the sixth and final workstream in
the owner's binding post-logo order. It changes no production behavior. Every
future change below is `PROPOSED` unless explicitly marked `VERIFIED` or
`INFERRED`.

## A. Session and authority

```text
REPOSITORY = GRAIN WAREHOUSE ERP LITE
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
GIT_DIR = C:/dev/multi-pos/grain-warehouse-erp-lite/.git
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE = origin
REMOTE_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
ENTRY_HEAD = 8a779df8f5c1bd7f49c7396b69ec4fd53922c177
ENTRY_SUBJECT = governance: determine post catalog slice successor authority
AUTHORIZED_PREDECESSOR = docs/POST_CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE_SUCCESSOR_AUTHORITY_DETERMINATION.md
AUTHORIZED_WORKSTREAM = RECOVERY_TRIAL_AND_LICENSING_BOUNDARY
AUTHORIZED_SUCCESSOR_COUNT = 1
OWNER_DECISION_REQUIRED = NO
IMPLEMENTATION_AUTHORIZED_THIS_SESSION = NO
```

Entry forensics established `CASE_B_EXPECTED_RESIDUE`: local, tracking,
direct-remote, and merge-base heads all equalled the entry head; ahead and
behind were zero; tracked worktree, index, non-ignored untracked set, stash,
active Git-operation markers, and index lock were clean/empty/absent. The 5,030
ignored entries were pre-existing residue and were neither inspected as
authority nor modified.

The committed authority chain is:

| Commit | Artifact or object | Verified authority effect |
| --- | --- | --- |
| `a5f57c709e1b7e9b3f50d8ae4811951220edf2a6` | `docs/OWNER-ROADMAP-ORDER-AFTER-LOGO-QUERY-MIGRATION-PROGRAM-COMPLETION.md`, blob `fe6ce13f20557e23fefc9f83916f8fbe3ee29c64` | Binds `W2, W1, W5, W3, W4, W6`; W6 is this workstream. |
| `b505dc455c84d42fdc587cb9ccd454abdc7330cc` | Distributed identity/scope/time implementation | Completes ordered slot 3 with `BusinessId`, `DeviceId`, verified execution context, and `ApplicationClock`. |
| `3f24a66db38022e57b864de68f401e15aa1445b7` | Durable outbox/inbox/conflict/checkpoint implementation | Completes slot 4 and leaves recovery/export/retention/wipe interactions to this workstream. |
| `128642e0abf028007373e3a817ed84355c6e800e` | Post-durable successor authority, blob `f1ae6152ce63b77d2f03873662ebaabd7daaaf01` | Selects slot 5 after slot 4. |
| `4b7e1d77042f7f5244e8ec8ee6821cf571352020` | Catalog plan, blob `008b06af3309fc21f0d986a5dad846730b9e5e8c` | Defers durable pending-work export, wipe guards, and evidence retention to this workstream. |
| `0db0bc757ed11bfcf3a2f503dd3d2742d7af7578` | Cloud-hybrid product-catalog implementation | Completes ordered slot 5. |
| `8a779df8f5c1bd7f49c7396b69ec4fd53922c177` | Binding predecessor, artifact blob `6abd1b346cc64f4efdbac9edfc45f2131948afc0` | Selects exactly this planning session and prohibits implementation. |

All listed commits are ancestors of the entry head. No commit exists after the
entry head, the preferred artifact did not exist at entry, and no later
committed authority supersedes this chain.

Only the root `AGENTS.md` applies to this path. This plan follows its
application-command/query, composition-root, durable transaction, Arabic/RTL,
security, data-preservation, and evidence-before-claims rules.

## B. Current-state findings

| Classification | Evidence | Current behavior and why it matters |
| --- | --- | --- |
| `VERIFIED` | `lib/core/trial/trial_service.dart:9`, `:16`, `:29` | `TrialService` owns a local 14-day evaluation, has zero rollback tolerance, and fails closed on errors. |
| `VERIFIED` | `lib/core/trial/trial_state_store.dart:30`, `:36`, `:45` | Trial state is stored under application support in two files with a deterministic SHA-256 marker. The marker detects casual corruption but is not keyed authenticity or strong DRM. |
| `VERIFIED` | `lib/features/trial/trial_app_gate.dart:9`, `:26`; `lib/main.dart:13` | The trial gate wraps the entire app and rechecks every minute, but evaluation occurs only after full production composition. |
| `VERIFIED` | `lib/composition/app_composition_root.dart:75-76`, `:114`, `:128`, `:158-173` | Trial evaluation is separate from the shared `ApplicationClock`; a verified cloud session can bind and start product synchronization during composition before the root trial gate is evaluated. |
| `VERIFIED` | `lib/application/context/execution_context.dart`; `lib/infrastructure/supabase/supabase_cloud_session_adapter.dart:11`, `:37` | Verified remote user, business, role, scope, session, and device identity already have one provider-neutral execution-context seam. |
| `VERIFIED` | `lib/infrastructure/local/file_device_identity_store.dart:9`, `:50` | Installation device identity is durable and supports reprovisioning, but no production caller currently invokes `reprovision()`. |
| `VERIFIED` | repository-wide search under `lib/`, `supabase/`, and tests | No license, entitlement, subscription, activation, grace, or revocation production model exists. Supabase has no entitlement table/RPC/policy. |
| `VERIFIED` | `docs/phase-107g/PHASE-107G-14-DAY-LOCAL-TRIAL-ENFORCEMENT-REPORT.md` | Existing trial enforcement explicitly admits deletion/reinstall, executable patching, VM rollback, and administrator-level tampering are outside its protection. |
| `VERIFIED` | `lib/core/backup/business_data_wipe_service.dart:44`, `:123`, `:179-238` | Owner permission, typed confirmation, backup-first behavior, and one outer `FoundationDatabase` transaction protect the current 13-domain wipe. |
| `VERIFIED` | `lib/core/auth/auth_repository.dart:18`; `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart` | A credential-verification seam already exists for privileged owner re-authentication, but wipe currently checks only the active user's local role and a typed phrase. |
| `VERIFIED` | `lib/core/backup/backup_file_writer.dart` | Backup save writes directly to the destination and returns after the write; wipe does not reread and hash the persisted file before deletion. |
| `VERIFIED` | `lib/core/backup/backup_export.dart:88`, `:201`; `lib/core/backup/backup_restore_service.dart:115`, `:234` | Ordinary backup is v8, declares `restoreSupported=false` for preview compatibility, and restore supports an empty business system. It does not include distributed operational state. |
| `VERIFIED` | `lib/core/persistence/foundation_database.dart:453`, `:536`, `:611`, `:671`, `:700`, `:727`, `:990` | Schema v19 contains durable outbox, conflict, inbox, checkpoint, product scope-binding, and product sync-state tables. |
| `VERIFIED` | `lib/application/distributed_state/durable_*_repository.dart` | Existing ports can load/claim/process selected records but cannot capture an exhaustive, all-state recovery snapshot. |
| `VERIFIED` | `lib/core/catalog/product_catalog_read_repository.dart` | A product can expose pending or attention-required cloud state, but the business-wipe preflight only counts ordinary domain records. |
| `VERIFIED` | `lib/core/persistence/foundation_database.dart:727-736`; `lib/core/catalog/drift_product_repository.dart:146-149` | Product sync-state rows reference local products with `ON DELETE RESTRICT`; current wipe deletes products without first governing the sync rows. |
| `VERIFIED` | `docs/DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION_IMPLEMENTATION_PLAN.md:732-746`, `:1008-1013` | Operational tables intentionally remain outside ordinary backup/wipe; this workstream owns pending-work export, reprovision/uninstall and wipe guards, retention, and trial/license interaction. |
| `VERIFIED` | `docs/CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE_IMPLEMENTATION_PLAN.md:188-202`, `:729-733` | Catalog recovery export and wipe guards were explicitly deferred; restored products are local-only and no sync metadata may be fabricated. |
| `INFERRED` | Combined wipe and schema evidence above | A cloud-bound wipe can silently omit durable evidence and can fail at product deletion because of restrictive sync-state references. No test currently proves the post-v19 cloud-bound wipe contract. |
| `VERIFIED_PARTIAL` | Git history: trial latest `e2b425ac272665eb9c0f59894799984e206146f3`; wipe latest `e74b3b462de0a2430d5437fc0fbaace00cfad900` | Recovery and local trial pieces exist, but the selected semantic boundary is not fully implemented under another name. Licensing is absent, so authorization is not stale. |

## C. Concrete problem statement

The repository has three independent truths that are not yet governed as one
boundary:

1. destructive local business-data wipe knows only legacy domain records and
   can neither detect nor export distributed pending/conflict/catalog evidence;
2. the local trial gate is evaluated after cloud-capable composition, is not
   tied to the repository's verified identity/scope/time model, and offers no
   licensed/server-managed access state; and
3. no contract states which recovery operations remain available after trial
   expiry/revocation, what survives wipe/reinstall, or when synchronization must
   be suspended.

The implementation must close these gaps without turning the workstream into
billing, cloud deletion, all-entity sync, deployment, or release work.

## D. Goals

1. Detect every locally represented distributed-operation/catalog state before
   any destructive business wipe and return stable, testable categories.
2. Export a deterministic, integrity-checked recovery-evidence bundle without
   changing ordinary backup v8 or inventing restore/replay semantics.
3. Refuse all cloud-bound or distributed-evidence-bearing business wipes in v1;
   evidence export is support material, not an override token.
4. Require current owner permission, fresh owner credential verification, exact
   confirmation, verified persisted backup, unchanged preflight snapshot, and
   one durable transaction for the local-only wipe path.
5. Make destructive requests idempotent and crash-recoverable through a small
   durable operation journal that survives the business wipe.
6. Preserve current local 14-day trial behavior as an explicit compatibility
   mode while introducing a provider-neutral server-managed trial/license
   decision boundary.
7. Make server time and a server decision version authoritative for provisioned
   entitlements; treat any local entitlement row only as a bounded offline lease.
8. Suspend product sync and business operations when access is expired,
   revoked, identity-mismatched, or unverified, while preserving owner-only
   backup and recovery-evidence export.
9. Preserve auth accounts, business identity, trial metadata, device identity,
   entitlement cache, and recovery receipts during a local business wipe.
10. Prove fresh/upgrade persistence, negative authorization, offline, replay,
    clock, failure, RTL/accessibility, and regression behavior.

## E. Non-goals

- Subscription billing, prices, plans, invoices, payment providers, Play/App
  Store billing, license purchase, activation UI, or customer provisioning.
- Automatic creation or backfill of historical server trials. Missing
  historical trial metadata must not be fabricated.
- Strong DRM against a local administrator, patched executable, full profile
  deletion, VM snapshot rollback, or disk cloning in local-only mode.
- Cloud business deletion, account deletion, tenant deletion, remote product
  deletion, server backup/disaster recovery, or multi-device administration.
- Automatic import, replay, or restore of a recovery-evidence bundle.
- Wiping a cloud-bound cache, detaching a business, reprovisioning a device, or
  using an owner override to discard pending/conflict evidence.
- Automatic operational-table retention deletion or compaction.
- New sync worker, background scheduler, all-entity synchronization, Android or
  Windows packaging, deployment, production rollout, analytics, or telemetry.
- Changing accounting, inventory, financial-command, catalog version/tombstone,
  or ordinary backup/restore business semantics.

## F. Exact boundary and ownership model

### In scope

- Read-only recovery inventory over all local durable scopes and states.
- Recovery-evidence export and durable receipt/journal metadata.
- A fail-closed guard around the existing owner business wipe.
- Atomic verified-file and unchanged-snapshot requirements for local-only wipe.
- Unified runtime access decision with local-trial compatibility and optional
  server-managed entitlement.
- A private Supabase entitlement-fact table and authenticated read-only decision
  RPC, implemented and tested locally only.
- Restricted owner recovery actions while ordinary business access is blocked.

### Truth ownership

| Truth | Owner in the planned boundary |
| --- | --- |
| Local actor and role | Existing Drift `AuthRepository`; owner re-auth uses `verifyCredentials` and never stores the submitted secret. |
| Remote user/business/role/scope | Existing verified `ExecutionContext` from Supabase auth plus active membership. Caller-supplied IDs are never authority. |
| Installation identity | Existing `FileDeviceIdentityStore`; business wipe never reprovisions or deletes it. |
| Business time | Existing shared `ApplicationClock`; server entitlement evaluation uses server `clock_timestamp()`. |
| Legacy local trial | Existing `TrialService` and file store, adapted to the shared application clock. It remains compatibility access, not a commercial license. |
| Provisioned trial/license state | New private server row and decision version; client code cannot create or mutate it. |
| Offline access | Exact cached server decision for the same business/user/device, valid only through the server-issued absolute `offlineValidUntilUtc`. |
| Pending durable work | Existing v19 outbox/inbox/conflict/checkpoint tables and product sync/binding tables. No competing ledger is created. |
| Wipe authorization | New application command plus recovery preflight; UI state or a typed phrase alone is insufficient. |
| Recovery evidence | Immutable exported JSON bundle plus SHA-256 and a local durable receipt. It is evidence, not normal backup or replay input. |

## G. State machines and contracts

### G.1 Recovery assessment

```text
LOCAL_ONLY_SAFE
  = no product scope binding, product sync state, outbox, inbox, conflict,
    or checkpoint row exists in any local scope

PROTECTED_PENDING_WORK
  = outbox in pending/claimed/retryWait/acknowledgedPendingApply/
    permanentFailure/conflict/cancelled
    OR inbox in received/applying/conflict/rejected
    OR unresolved conflict
    OR product projection pending/attentionRequired

CLOUD_EVIDENCE_PRESENT
  = any binding, sync state, checkpoint, completed/applied operation,
    resolved conflict, acknowledged product, or tombstone exists

WIPE_DECISION
  LOCAL_ONLY_SAFE -> eligible after remaining guards
  PROTECTED_PENDING_WORK -> refused; recovery evidence export required/offered
  CLOUD_EVIDENCE_PRESENT -> refused as cloud-bound reset unsupported in v1
```

Assessment scans all local rows, not only the current caller scope. That closes
cross-business omission and prevents a stale/missing execution context from
making destructive work appear safe.

### G.2 Destructive operation journal

```text
REQUESTED
  -> REFUSED_AUTHORIZATION
  -> REFUSED_DISTRIBUTED_STATE
  -> PREFLIGHTED_LOCAL_ONLY
       -> BACKUP_VERIFIED
            -> COMPLETED
            -> FAILED_NO_MUTATION
       -> FAILED_NO_MUTATION

BACKUP_VERIFIED --crash/retry same operation id--> revalidate file + snapshot
wipe transaction failure --> rollback to BACKUP_VERIFIED or FAILED_NO_MUTATION
COMPLETED --same operation id/same fingerprint--> return stored result
same operation id/different fingerprint --> IDEMPOTENCY_CONFLICT
```

No journal state can authorize a cloud-bound wipe. The journal row and final
`COMPLETED` result commit in the same `FoundationDatabase.inTransaction` as the
13 existing clear operations.

### G.3 Runtime access decision

```text
CHECKING
  -> LOCAL_TRIAL_ACTIVE
  -> LOCAL_TRIAL_EXPIRED
  -> LOCAL_CLOCK_ROLLBACK
  -> LOCAL_STATE_INVALID
  -> SERVER_TRIAL_ACTIVE
  -> LICENSED_ONLINE
  -> LICENSED_OFFLINE_GRACE
  -> ENTITLEMENT_EXPIRED
  -> ENTITLEMENT_REVOKED
  -> ENTITLEMENT_UNVERIFIED
  -> IDENTITY_MISMATCH
```

- No configured Supabase client uses the existing local trial exactly.
- Cloud mode with a verified context asks the server first. An absent server
  entitlement explicitly selects legacy local-trial compatibility; it does not
  create a trial row.
- A returned provisioned entitlement permanently selects server-managed
  authority for that business on that installation. A later absent, older,
  malformed, or mismatched response fails closed rather than falling back.
- Offline access exists only from a valid cached server decision whose business,
  remote user, device, decision version, payload fingerprint, and absolute lease
  all match. Offline use never extends the lease.
- `expired`, `revoked`, `unverified`, and `identityMismatch` deny business
  operations and synchronization. `revoked`/`expired` remain sticky until a
  strictly newer valid server decision changes them.
- Local clock rollback below the last accepted instant invalidates offline
  grace. Server time replaces local suspicion only after a fresh verified
  online decision.

## H. Destructive-operation contract

The future `WipeBusinessDataCommand` must evaluate guards in this order:

1. reject a missing/inactive current local user;
2. verify supplied credentials through `AuthRepository.verifyCredentials` and
   require an active owner matching the current owner identity;
3. require the exact existing Arabic confirmation phrase;
4. reserve/load the idempotent operation journal row;
5. capture a one-transaction recovery inventory over every local scope;
6. refuse if any distributed/catalog operational row exists; never recover,
   cancel, delete, or normalize it as part of the guard;
7. create the existing ordinary business backup snapshot;
8. save by temporary file, flush, atomic rename where supported, reread, validate
   backup checksum, and verify an exact SHA-256 of persisted bytes;
9. enter the shared maintenance gate used by product sync and the destructive
   command, then start `FoundationDatabase.inTransaction`;
10. recompute the targeted-business snapshot fingerprint and distributed-state
    inventory; refuse/rollback if either differs from the verified backup
    preflight or distributed state is no longer empty;
11. run the established 13 dependency-ordered clears and repository snapshot
    rollback participation; and
12. record the completed journal result in the same transaction.

The user-facing result is one of: `notOwner`, `ownerReauthenticationFailed`,
`invalidConfirmation`, `pendingWorkExportRequired`,
`cloudBoundResetUnsupported`, `backupCreateFailed`, `backupPersistFailed`,
`stateChangedRetryRequired`, `wipeRolledBack`, `idempotencyConflict`, or
`completed`. Arabic copy must be actionable and must not claim no deletion
until rollback/commit evidence is known.

An evidence export does not unlock a v1 cloud-bound wipe. There is no owner
override that bypasses the guard. A future detach/cache-rebuild workflow needs
separate authority because only product catalog data is currently recoverable
from cloud state.

## I. Recovery-evidence format and retention

`RecoveryEvidenceBundle` version 1 is a separate UTF-8 canonical JSON document:

```text
metadata:
  app, evidenceVersion, localSchemaVersion, generatedAtUtc,
  deviceId, businessIds, sourceOperationId, restoreSupported=false
inventory:
  exact counts grouped by table/state/scope and assessment classification
data:
  durableOutboxOperations, durableInboxOperations, durableConflicts,
  durableSyncCheckpoints, productCatalogScopeBindings,
  productCatalogSyncStates
integrity:
  per-section SHA-256 values and one whole-payload SHA-256
```

Rows are ordered by their stable primary keys. Canonical payloads,
acknowledgements, two-sided conflict snapshots, error class/code, versions,
timestamps, deletion evidence, and scope/identity references are preserved.
Ephemeral claim tokens, credentials, access/refresh tokens, password material,
raw exception text, and unrestricted server bodies are excluded. The bundle is
plaintext like the current owner backup, contains sensitive business evidence,
is saved only to the local owner backup area, and must display a privacy warning
and exact path. SHA-256 provides integrity detection, not confidentiality or
proof against an attacker able to rewrite both file and digest.

The export is reread and rehashed before its `RecoveryOperation` receipt becomes
verified. It is never accepted by ordinary restore and no automatic replay is
implemented. Pending/unresolved/permanent-failure/conflict evidence is never
automatically compacted. Completed/applied/resolved evidence is also retained
in v1 because no committed server retention checkpoint proves deletion safe.
External file cleanup remains an explicit owner/support act outside the app;
the app performs no automatic evidence deletion.

## J. Trial and licensing trust contract

### Local compatibility mode

- Preserve the exact 14-day UTC boundary, sticky expiry, zero rollback
  tolerance, invalid-state failure, minute checkpoint, and business-data
  preservation currently covered by Phase 107G.
- Inject the shared `ApplicationClock` through a small `TrialClock` adapter so
  runtime access, durable operations, and trial evaluation do not construct
  competing production clocks.
- Business wipe/restore, owner setup, sign-out, cache clearing, and recovery
  export never delete or recreate trial metadata.
- Local-only reinstall/profile deletion remains bypassable by an administrator;
  UI/documentation must call this a local trial, not a resistant license.

### Server-managed mode

- Server entitlement state, decision version, and server time are authoritative.
- Trial start/expiry rows are explicitly provisioned; the migration creates no
  historical rows and invents no past start time.
- `licensed` does not imply billing. Provisioning/activation is outside scope.
- The server returns an absolute offline lease. Initial/default grace is zero;
  a provisioned policy may grant a non-negative duration capped at seven days.
  Trial access is additionally capped by trial expiry; dated licenses are
  capped by license expiry.
- A cache is usable only for the same `BusinessId`, `RemoteAuthUserId`, and
  `DeviceId`, at the same or newer decision version, with a valid fingerprint,
  non-rolled-back local time, and `now <= offlineValidUntilUtc`.
- Fresh/reprovisioned cloud installations require one verified online decision
  before offline business access. Deleting local files cannot reset a
  server-provisioned business trial.
- Server revocation/expiry wins immediately online and after the bounded lease
  offline. Revocation cannot be known before an already issued lease expires;
  that bounded exposure is explicit.

### Blocked-access recovery

The access gate must prevent construction/navigation of business screens and
must suspend product sync. It may expose only provider contact, sign-out where
available, owner re-authentication, ordinary backup export, and recovery-
evidence export. It must never expose wipe, restore/import, product mutation,
financial commands, conflict resolution, or device reprovisioning while access
is denied.

## K. Data-model impact

### Local Drift schema v19 to v20

Add two empty operational tables; do not backfill historical rows:

1. `recovery_operations`
   - `operation_id` UUID primary key; `kind` (`evidenceExport` or
     `businessDataWipe`); `request_fingerprint` SHA-256;
   - nullable local actor/remote actor/business identity plus required device;
   - status from the journal state machine; stable result code;
   - nullable snapshot fingerprint, backup/evidence file path and SHA-256;
   - requested/updated/completed UTC and positive `record_version`;
   - indexes on `(status, updated_at_utc)` and
     `(business_id, kind, requested_at_utc)`;
   - constraints require 64-character lowercase digests, internally complete
     file/digest pairs, and completion fields only for terminal results.
2. `entitlement_decision_caches`
   - `(business_id, device_id)` primary key; remote auth user ID;
   - authority mode, access status, positive server decision version;
   - canonical response JSON and SHA-256;
   - server-evaluated UTC, optional trial/license expiry, absolute offline-valid
     UTC, cached UTC, last-accepted-local UTC, and positive record version;
   - index on `(access_status, offline_valid_until_utc)`;
   - constraints enforce complete identity, fingerprint, UTC/expiry ordering,
     and no offline validity beyond the authoritative expiry.

Migration 19 to 20 creates empty tables/indexes only. Fresh creation and every
supported older ordered migration must still reach v20. Ordinary backup v8 and
restore v1-v8 remain unchanged and exclude these device-operational tables.
Restore creates no entitlement, operation receipt, binding, queue, conflict, or
checkpoint row.

### Supabase additive schema

Add `private.business_access_entitlements`:

- `business_id` primary key referencing `public.businesses` with delete
  restriction;
- `authority_kind` in `serverTrial`, `licensed`, `revoked`;
- optional trial start/expiry and license expiry with state-consistency checks;
- `offline_grace_seconds` default 0, constrained to 0 through 604800;
- positive `decision_version`, updated-at UTC, and no automatic seed/backfill.

No business, membership, product, financial, receipt, or audit table changes.

## L. Application and API impact

The future implementation is limited to the following coherent modules. Exact
names may vary only to match an existing nearby convention; ownership may not.

| File/module | Proposed symbols and responsibility |
| --- | --- |
| `lib/application/recovery/recovery_contracts.dart` (new) | `RecoverySafetyAssessment`, inventory/state counts, stable refusal/result categories, evidence-bundle DTO. |
| `lib/application/recovery/recovery_repository.dart` (new) | Exhaustive read snapshot, operation-journal CAS, and unchanged-snapshot port. |
| `lib/application/queries/inspect_recovery_safety_query.dart` (new) | Read-only all-scope assessment; no widget/database access. |
| `lib/application/commands/export_recovery_evidence_command.dart` (new) | Owner re-auth, idempotency, export, reread/hash verification, receipt. |
| `lib/application/commands/wipe_business_data_command.dart` (new) | Exact guard order and application ownership around the existing atomic service. |
| `lib/core/recovery/drift_recovery_repository.dart` (new) | One `FoundationDatabase` adapter for v19/v20 operational snapshots and journal CAS. |
| `lib/core/backup/recovery_evidence_export.dart` (new) | Canonical evidence v1 serialization and SHA-256. |
| `lib/core/backup/backup_file_writer.dart` | Atomic flushed save and persisted-byte verification result; preserve existing callers through a compatible API. |
| `lib/core/backup/backup_export.dart` | Expose deterministic business snapshot fingerprint without changing JSON v8. |
| `lib/core/backup/business_data_wipe_service.dart` | Accept verified preflight/journal dependencies, recheck inside the outer transaction, preserve the 13-domain order. |
| `lib/application/access/runtime_access_contracts.dart` (new) | Authority modes, decisions, denial reasons, and recovery-only capability set. |
| `lib/application/access/entitlement_gateway.dart` and `entitlement_cache.dart` (new) | Provider-neutral remote decision and local bounded-cache ports. |
| `lib/application/commands/evaluate_runtime_access_command.dart` (new) | Select local compatibility/server/cache path and enforce monotonic identity/time/version rules. |
| `lib/core/access/drift_entitlement_cache.dart` (new) | v20 cache adapter; no token storage. |
| `lib/infrastructure/supabase/supabase_entitlement_gateway.dart` (new) | Calls only the public authenticated decision RPC and maps stable outcomes. |
| `lib/core/trial/trial_service.dart` and `trial_clock.dart` | Preserve local state machine; use the shared application clock adapter. |
| `lib/features/trial/trial_app_gate.dart` | Evolve into the unified Arabic runtime-access gate with recovery-only blocked state; preserve existing trial labels/status behavior. |
| `lib/features/backup/data_wipe_screen.dart` | Use application query/command, add owner credential confirmation, show pending/evidence/cloud-bound categories, prevent duplicate submit. |
| `lib/features/backup/backup_export_screen.dart` | Add recovery-evidence export entry and privacy/result feedback; no restore/replay action. |
| `lib/main.dart`, `lib/application/application_boundary.dart`, `lib/application/application_dependencies.dart`, `lib/composition/app_composition_root.dart`, `lib/composition/legacy_application_dependency_bridge.dart`, `lib/app/app_repositories.dart` | Construct one shared recovery/access boundary, expose commands/queries, remove direct wipe service lookup from UI, and gate sync startup/session refresh on allowed access. |
| `lib/core/persistence/foundation_database.dart`, `.g.dart`, `migration_strategy.dart` | Schema v20 tables and ordered additive migration. |

The existing `EvaluateTrialCommand` may remain as a compatibility adapter used
by focused Phase 107G tests, but `main` and the gate must use
`EvaluateRuntimeAccessCommand`. No service locator or second database is added.

## M. Supabase impact

Add one timestamped migration and one pgTAP file. The migration must:

1. create the private entitlement table with explicit constraints;
2. enable RLS on the private table as defense in depth, create no client table
   policy, and revoke all table privileges from `PUBLIC`, `anon`, and
   `authenticated`;
3. add a private security-definer evaluator with `search_path = ''` and fully
   qualified names;
4. revoke evaluator execution from `PUBLIC` and `anon`, then grant only the
   private-schema usage and evaluator execution that `authenticated` needs for
   the existing invoker-wrapper pattern; the evaluator itself must repeat the
   authorization checks and the private schema remains outside the Data API;
5. add a public security-invoker wrapper
   `evaluate_business_access_v1(business_id, device_id)`;
6. require `auth.uid()`, active business, exactly one active matching
   membership, and a valid device UUID;
7. return `notProvisioned` without inserting when no row exists;
8. derive active/expired/revoked from `clock_timestamp()`, calculate the
   absolute bounded offline lease, and return the decision version;
9. revoke wrapper execution from `PUBLIC` and `anon`, and grant it only to
   `authenticated`;
10. expose no client insert/update/delete and use no service-role credential in
   Flutter, tests, logs, or artifacts.

This explicit privilege model follows the current Supabase distinction between
Data API grants and row policies, and the current rule that functions otherwise
receive `EXECUTE` from `PUBLIC` by default. The future implementation session
must recheck the [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security),
[database-function guidance](https://supabase.com/docs/guides/database/functions),
and relevant [breaking changes](https://supabase.com/changelog?types=breaking-change)
before writing the migration.

No Edge Function, Storage bucket, Auth hook, live project mutation, or
deployment belongs to the implementation session. Entitlement provisioning is
an out-of-scope administrative/commercial workflow.

## N. Security and abuse cases

| Threat | Planned decision |
| --- | --- |
| Delete local trial DB/files or reinstall | Local-only mode remains explicitly limited; provisioned server trial is business-authoritative and not reset by a new local profile/device. |
| Clock rollback | Existing local trial stays sticky; cached server grace rejects time before last accepted and never extends an absolute lease. |
| Replay stale entitlement cache | Require same B/U/D identity, canonical fingerprint, monotonic decision version, and lease; online result supersedes cache. Full-disk snapshot attacks remain outside local guarantees. |
| Extend offline grace by repeated starts | Lease end comes from server and is never recalculated locally. |
| Wipe unsent transactions | Any protected outbox/inbox/conflict/catalog state refuses wipe before backup deletion work begins. |
| Wipe only another/current scope | Inventory scans every local business/scope; any evidence refuses. |
| Unauthorized reset | Current active owner plus fresh verified owner credentials plus exact phrase; UI hiding is not the control. |
| Tamper with recovery export | Reread and SHA-256 verification detect accidental/casual alteration; file is not accepted for replay. No authenticity claim is made. |
| Sensitive evidence disclosure | No credentials/tokens/claim tokens/raw exceptions; warning and exact owner-local path; no logs of payloads. Plaintext owner-controlled storage remains an explicit limitation. |
| Access revoked while sync starts | Establish context, evaluate access, then bind/sync. Session/auth changes re-evaluate and suspend before further sync passes. |
| Cross-business entitlement | Server membership and client B/U/D checks fail closed; caller IDs never create authority. |
| Delete entitlement row to fall back | Once server-managed is cached, absent/older server results fail closed. Server table is private and client cannot delete it. |

Security classifications at planning time: current local trial anti-admin DRM is
`FAIL` by its documented limitation; server entitlement, offline lease, and
cloud-bound wipe controls are `NOT_VERIFIED` until implemented/tested; current
absence of licensing activation is `NOT_APPLICABLE` to billing because billing
is a non-goal, not a pass.

## O. Failure matrix

| Failure | Required result |
| --- | --- |
| Offline, local-only mode | Existing local trial and local business operation continue if active. |
| Offline, server-managed valid cache | Allow only until absolute lease end; label offline grace visibly. |
| Offline, no valid server cache | `entitlementUnverified`; no business screen or sync. |
| Supabase auth/session unavailable | Clear verified context; use only an already valid matching lease, otherwise fail closed. |
| Server RPC unreachable/timeout | Do not rewrite cached state; bounded matching cache or fail closed. |
| Server returns older decision version | Reject as stale replay and retain stricter current state. |
| Clock suspicious | Local trial blocks; server cache blocks until fresh online server time. |
| Missing identity/tenant mismatch | `identityMismatch`; no server request using guessed scope and no sync. |
| Pending outbox or unresolved conflict | Refuse wipe, report exact counts/categories, offer owner-authenticated evidence export. |
| Only completed/applied/binding/checkpoint evidence | Refuse as `cloudBoundResetUnsupported`; do not call it a safe empty system. |
| Evidence export write/reread/hash failure | No verified receipt and no data mutation; retry same operation ID safely. |
| Backup write fails/disk full | No wipe starts; journal records stable failure without secret/path payload logging. |
| Business state changes after backup | Final transactional fingerprint mismatch rolls back/refuses and requires a fresh backup. |
| DB transaction or repository step fails | Existing outer transaction and snapshots roll back all deletes; journal does not say completed. |
| Crash before verified backup | No delete; retry resumes/restarts preflight. |
| Crash after verified backup, before transaction | No delete; retry rereads file and revalidates current state. |
| Crash during wipe transaction | SQLite rolls back business rows and journal completion together. |
| Repeated completed request | Same fingerprint returns stored result; changed fingerprint is an idempotency conflict. |
| Trial/license blocked | Business child/routes and sync stay unavailable; owner-only exports remain reachable after re-auth. |

## P. Test plan

### New focused tests

- `test/recovery_safety_assessment_test.dart`: each outbox/inbox state, unresolved
  and resolved conflicts, checkpoints, bindings, each product disposition,
  multiple scopes, empty state, deterministic counts, and no mutation.
- `test/recovery_evidence_export_test.dart`: canonical ordering, exact fields,
  excluded secrets/claim tokens, per-section/whole SHA-256, reread validation,
  failure cleanup, idempotent receipt, privacy-safe errors, and non-restoreability.
- `test/recovery_business_wipe_guard_test.dart`: local-only success; every
  operational table blocks; evidence export does not unlock; current/different/
  inactive/non-owner/wrong-password cases; exact phrase; TOCTOU; duplicate ID;
  backup failure; F1-F4 rollback; auth/trial/device/access-cache/receipt
  preservation.
- `test/recovery_trial_licensing_migration_test.dart`: fresh v20 and authentic
  v19-to-v20 upgrade with representative business and operational rows; empty
  new tables; constraints/indexes; no backfill/data loss; old migrations reach
  v20.
- `test/runtime_access_state_machine_test.dart`: Phase 107G local parity;
  not-provisioned compatibility; online server trial/license; exact expiry;
  zero and bounded grace; offline expiry; rollback; stale version; payload,
  identity, scope, and device mismatch; sticky revocation; I/O/RPC failures.
- `test/runtime_access_gate_widget_test.dart`: Arabic active/offline/expired/
  revoked/unverified copy, business child not built when denied, recovery-only
  actions, owner re-auth, duplicate-submit prevention, keyboard focus/cancel,
  semantics/labels, long text and text scale, narrow/desktop layout, and RTL
  ordering with LTR paths/UUIDs nested explicitly.
- `test/recovery_sync_access_integration_test.dart`: composition establishes
  context then access; denied/unverified access cannot bind/start/continue sync;
  a newer allowed decision permits one bounded pass; revocation suspends later
  passes; recovery export performs no transport.
- `integration_test/recovery_trial_licensing_boundary_test.dart`: two isolated
  file databases against local Supabase prove same-business entitlement,
  cross-business denial, bounded offline restart, pending product mutation wipe
  refusal, evidence export, and unchanged remote/local business data.
- `supabase/tests/recovery_trial_licensing_boundary_test.sql`: anon,
  unauthenticated, inactive/non-member/cross-business denial; active member read;
  no direct table writes; no automatic row creation; server time; trial/licensed/
  expired/revoked; decision version; zero/max grace and cap; grants/search path.

### Existing regression files likely requiring updates

- `test/phase107g_trial_enforcement_test.dart` for exact local parity and the
  compatibility adapter.
- `test/phase107b_atomic_business_data_wipe_test.dart`,
  `test/phase17_owner_data_wipe_test.dart`,
  `test/phase18_release_candidate_qa_test.dart`, and
  `test/phase106af_migrate_business_data_wipe_current_counts_product_read_test.dart`
  for the new command/guard while preserving old atomicity/count assertions.
- `test/phase13_backup_export_test.dart`, `test/phase14_backup_file_save_test.dart`,
  `test/phase15_restore_preview_test.dart`, and
  `test/phase16_restore_empty_system_test.dart` to prove ordinary v8 JSON and
  v1-v8 restore are unchanged and operational/cache rows are not fabricated.
- `test/durable_outbox_inbox_conflict_foundation_test.dart`,
  `test/cloud_hybrid_product_catalog_vertical_slice_test.dart`, and
  `test/product_catalog_sync_widget_test.dart` for evidence preservation and
  sync suspension.
- `test/phase108e_application_boundary_composition_root_test.dart`,
  `test/phase108g_session_business_context_boundary_test.dart`, and
  `test/phase108h_app_shell_runtime_ownership_test.dart` for one shared
  composition/access/recovery owner.
- Current-schema assertions in persistence tests must move from 19 to 20 only
  where they assert the live schema. Historical source/diff guards must retain
  their original semantic claims. Before editing, enumerate them with
  `rg -n "schemaVersion.*19|schemaVersion, 19" test` and review each result;
  do not bulk-replace unrelated historical prose.

No test may mutate a live Supabase project, real profile, real backup, trial
state, license state, or customer data.

## Q. Validation gates for the future implementation session

Run from the repository root, in order, against synthetic/temp data:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
dart run build_runner build --delete-conflicting-outputs
git diff --check
flutter analyze --no-pub
flutter test test/recovery_safety_assessment_test.dart test/recovery_evidence_export_test.dart test/recovery_business_wipe_guard_test.dart test/recovery_trial_licensing_migration_test.dart test/runtime_access_state_machine_test.dart test/runtime_access_gate_widget_test.dart test/recovery_sync_access_integration_test.dart
flutter test test/phase107g_trial_enforcement_test.dart test/phase107b_atomic_business_data_wipe_test.dart test/phase17_owner_data_wipe_test.dart test/phase13_backup_export_test.dart test/phase14_backup_file_save_test.dart test/phase15_restore_preview_test.dart test/phase16_restore_empty_system_test.dart test/durable_outbox_inbox_conflict_foundation_test.dart test/cloud_hybrid_product_catalog_vertical_slice_test.dart
supabase db reset --local
supabase test db
flutter test integration_test/recovery_trial_licensing_boundary_test.dart
flutter test
flutter build windows --debug
git diff --check
```

Generation must be followed by inspection proving only the expected Drift
delta. The Supabase commands are local-only. The Windows debug build is a
compile/platform check, not release, packaging, signing, delivery, or
deployment evidence. Coverage may be collected diagnostically but no
percentage-only pass claim is allowed.

## R. Implementation order

1. **Freeze contracts and tests:** add provider-neutral recovery/access models,
   stable result enums, deterministic codecs, and state-machine unit tests.
2. **Add local schema v20:** two operational tables, ordered migration,
   generated Drift code, fresh/upgrade/constraint tests; no backfill.
3. **Implement recovery inventory/export:** all-state snapshot adapter,
   canonical evidence v1, verified atomic file save, receipt CAS, security tests.
4. **Guard the destructive seam:** application command/query, owner re-auth,
   maintenance gate, final transactional fingerprint recheck, journal
   completion, and legacy wipe regressions.
5. **Add server entitlement decision:** local Supabase migration/RPC/pgTAP only;
   no provisioning, activation, Edge Function, or deployment.
6. **Implement entitlement cache/evaluator:** identity/version/time/fingerprint
   checks, local-trial compatibility, bounded offline state, and failure tests.
7. **Reorder composition/runtime ownership:** establish context, evaluate
   access, and only then permit product binding/sync; re-evaluate on auth changes.
8. **Update focused Arabic UI:** application-owned wipe flow, recovery export,
   unified gate, restricted blocked recovery, RTL/accessibility/widget tests.
9. **Run integration/regression gates:** local Supabase and two-file-database
   scenario, full suite, analyzer, debug Windows build, scope and diff audit.
10. **Close implementation only:** commit/push only if separately authorized;
    do not deploy, activate licensing, select a successor, or start deferred work.

Each step must land its behavior and tests together. A reasonable commit series
is: contracts/tests; local persistence; recovery export/wipe guard; server
entitlement SQL; client evaluator/composition; UI/integration/closure. Do not
create a tests-only final commit that separates a risky behavior from its proof.

## S. Rollback and recovery strategy

- Before implementation testing, use only temporary/synthetic databases and
  profiles. Never test against the user's production profile.
- Local v20 is additive and has no backfill. A binary that has opened v20 must
  not be downgraded to a binary that only understands v19 without an explicit
  compatible rollback build or restored pre-upgrade database copy.
- Do not rewrite a released migration. Fix defects with a forward v21 migration
  if v20 has escaped the implementation environment.
- Recovery export and business backup are written before destructive mutation;
  failure leaves business data unchanged. A failed in-transaction wipe resumes
  from the persisted pre-completion journal state with the same operation ID.
- Supabase rollback before deployment is file removal within the uncommitted
  implementation only. After any separately authorized deployment, use a new
  forward migration; do not drop entitlement evidence casually.
- Client feature activation must remain backward-compatible with a missing RPC:
  local-only mode keeps the local trial; a known server-managed installation
  without a valid server/cache decision fails closed.

## T. Migration and deployment sequencing

1. Implement/test local v20 and client contracts without enabling
   server-managed entitlement.
2. Apply the additive Supabase migration only to the local CLI stack and pass
   pgTAP.
3. Prove the Flutter client against both unavailable/not-provisioned and
   provisioned synthetic server states.
4. Commit the implementation only under a separate implementation authority.
5. A later deployment session must deploy the server migration before enabling
   server-managed clients, verify grants/RLS/RPC, and keep provisioning empty.
6. A separately authorized commercial/admin session may define provisioning,
   support, and activation. No step here creates a real entitlement.

No production deployment, migration execution, feature activation, or data
backfill occurs in this planning session.

## U. Acceptance criteria for the future implementation

The implementation may claim PASS only when all are demonstrated with current
evidence:

1. schema v20 fresh and v19 upgrade paths preserve representative existing data
   and create empty operational tables without fabricated rows;
2. all six distributed/catalog tables are inventoried across all local scopes;
3. each protected/terminal/cloud-bound case refuses wipe before mutation;
4. recovery evidence is deterministic, verified after persistence, contains the
   required snapshots, excludes prohibited secrets, and is not restoreable;
5. local-only wipe requires owner re-auth and exact confirmation, verifies the
   persisted backup, detects state change, is idempotent, and remains atomic;
6. auth, business identity, trial state, device identity, access cache, and
   recovery receipts survive local business wipe;
7. Phase 107G local trial semantics remain byte/behavior compatible at all
   boundaries and failures;
8. provisioned server trial/license decisions use server time, membership,
   business/device identity, monotonic versions, and bounded offline leases;
9. no entitlement row is auto-created or historically backfilled, and no client
   can mutate the private table;
10. denied/unverified access builds no business route and runs no product sync,
    while owner-authenticated backup/evidence export remains available;
11. RTL, mixed LTR identifiers/paths, text scale, keyboard/focus, semantics,
    loading/disabled/error/success states pass focused widget evidence;
12. targeted tests, local Supabase tests, integration test, full Flutter suite,
    analyzer, debug Windows build, generation audit, and diff checks pass;
13. no live Supabase, user data, trial/license state, release, deployment,
    package, tag, or downstream work is touched; and
14. final implementation diff contains only the authorized boundary and its
    tests/migrations/generated code.

## V. Deferred work

- License provisioning/activation/support tooling, billing, pricing, plan UI,
  payment-provider or store integration.
- Strong administrator-resistant local DRM, hardware attestation, TPM/secure
  enclave binding, VM snapshot defense, and cross-install device registry UI.
- Cloud cache rebuild/detach, remote business deletion, account removal, device
  reprovision UI, all-device logout, or server disaster recovery.
- Recovery-evidence import/replay and automatic reconciliation.
- Evidence retention deletion/compaction after a future server checkpoint and
  audit-retention policy prove it safe.
- Multi-business local partitioning, all-entity synchronization, background
  workers, Android/iOS delivery, production rollout, telemetry, and analytics.

## W. Successor and mandatory stop boundary

```text
RECOVERY_TRIAL_AND_LICENSING_BOUNDARY_PLANNING = COMPLETE
RECOVERY_TRIAL_AND_LICENSING_BOUNDARY_IMPLEMENTATION = NOT_STARTED
POST_IMPLEMENTATION_SUCCESSOR_AUTHORITY = UNRESOLVED_UNLESS_ALREADY_COMMITTED

PLANNING_COMPLETE = YES
IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED_THIS_SESSION = NO
MIGRATION_STARTED = NO
SUPABASE_PRODUCTION_MUTATION = NONE
RECOVERY_EXECUTED = NO
WIPE_RESET_EXECUTED = NO
TRIAL_STATE_MUTATED = NO
LICENSE_STATE_MUTATED = NO
RELEASE_STARTED = NO
DEPLOYMENT_STARTED = NO
NEXT_ACTION = STOP
```

This plan does not select a roadmap successor. Implementation requires a new,
separately authorized implementation-only session that revalidates repository,
authority, remote, schema, and worktree truth before changing any code.
