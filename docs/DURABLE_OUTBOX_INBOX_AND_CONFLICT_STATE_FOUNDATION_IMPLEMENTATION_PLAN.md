# Durable Outbox, Inbox, and Conflict-State Foundation Implementation Plan

## A. Session / Planning Result

```text
SESSION = PLANNING_OF_DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION
PLANNING_RESULT = COMPLETE
IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED_THIS_SESSION = NO
SELECTED_SUCCESSOR = DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION
OWNER_DECISION_REQUIRED = NO
```

This document is the implementation-ready plan for ordered roadmap slot 4. It
creates no runtime, schema, migration, transport, UI, Android, report,
recovery, trial, or licensing behavior. Repository facts are labelled
`VERIFIED_CURRENT_STATE`; decisions for the separately authorized
implementation session are labelled `PLANNED_CHANGE`; later-owner work is
labelled `DEFERRED`.

Workstream 4 is complete only when durable operation transport state, inbound
deduplication state, conflict evidence, their atomic transaction seams, and a
bounded integration with existing commands are implemented and tested. A set
of unused tables is not sufficient.

## B. Binding Authority

`VERIFIED_CURRENT_STATE`

```text
AUTHORITY_COMMIT = 6ac963436d9b0ef2c44e420ad12e4af3b2500cbe
AUTHORITY_PARENT = b505dc455c84d42fdc587cb9ccd454abdc7330cc
AUTHORITY_TREE = 204e5de4d67a3c9c92eb07a7a026bdf11948c896
AUTHORITY_SUBJECT = docs: resolve post identity scope time successor authority
AUTHORITY_ARTIFACT = docs/POST_DISTRIBUTED_IDENTITY_SCOPE_TIME_CONTRACT_COMPLETION_SUCCESSOR_AUTHORITY_DECISION.md
AUTHORITY_ARTIFACT_BLOB = 89e86a789dbe9a4a5664131a4a434b3bba20a23b

SUCCESSOR_SELECTION_STATUS = RESOLVED
SELECTED_SUCCESSOR = DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION
OWNER_DECISION_REQUIRED = NO
NEXT_SESSION_AUTHORIZED = PLANNING_OF_DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION
```

The binding order remains `W2 -> W1 -> W5 -> W3 -> W4 -> W6`. Slots 1-3 are
complete. This plan covers slot 4 only. Cloud Hybrid Product Catalog and
Recovery/Trial/Licensing remain slots 5 and 6.

Entry forensics established `CASE_A_FRESH`: local, explicit tracking, direct
remote, and merge-base heads all equalled the authority commit; ahead and
behind were zero; worktree, index, and stash were empty; and no merge,
cherry-pick, revert, bisect, rebase, or index lock was active.

## C. Repository Discovery

### C.1 Persistence and schema

`VERIFIED_CURRENT_STATE`

- Production opens one Drift `FoundationDatabase` over file-backed SQLite at
  `grain_warehouse_erp.sqlite3`. `database_opener.dart` enables foreign keys
  and WAL; tests use the same database class over in-memory or file executors.
- `FoundationDatabase.schemaVersion` is 17. `migration_strategy.dart` applies
  a complete, sequential map of additive migration steps and fails if a step
  is absent. `FoundationDatabase.inTransaction` delegates to Drift's real
  transaction facility.
- All production Drift adapters are composed from the same
  `AppRepositories.database`. This is the exact durable atomicity seam.
- Current shared business tables generally have local string IDs and do not
  have `business_id`, distributed entity versions, source-operation metadata,
  or tombstones. `NegativeBalanceApprovalRequests.recordVersion` is a narrow
  workflow concurrency field, not a distributed version contract.
- Sales, purchases, and expenses have some operation-request/idempotency
  fields. Those fields are domain-specific and do not form a generic durable
  transport ledger.
- Business backup/restore serializes business repositories. Device identity
  is deliberately outside that contract. Earlier architecture decisions also
  classify outbox, inbox, and cursors as device-local operational state.

### C.2 Transactions and writes

`VERIFIED_CURRENT_STATE`

- Simple Drift repositories use local transactions for create/update/sequence
  work. More complex repositories use Drift transactions for their own
  aggregate writes.
- `RepositoryTransaction` is an in-process serialized snapshot/rollback
  mechanism. It is valuable for legacy and in-memory composition, but it is
  not the durable cross-repository atomicity authority.
- Selected orchestrators already inject `database.inTransaction`, including
  governed business wipe and the negative-balance approval workflow.
- Confirmed Expense and Internal Transfer projection writers already perform
  all local projection rows and their attempt-state completion in one Drift
  transaction. They serialize financial-account projection access and verify
  exact replay rather than blindly overwriting mismatched rows.
- No existing production local-first write has all of the newly completed
  distributed prerequisites simultaneously: verified `BusinessId`, explicit
  `BusinessScope`, remote actor, stable device, captured session, operation ID,
  entity version, and transport policy. Inventing those values for a legacy
  local write is prohibited.

### C.3 Existing transport, retry, and idempotency behavior

`VERIFIED_CURRENT_STATE`

- `ExpensePostingAttempts` and `InternalTransferPostingAttempts` are durable,
  command-specific SQLite ledgers. They store command/business IDs, canonical
  payload and SHA-256 fingerprint, lifecycle state, optional canonical server
  result, timestamps, attempt count, and last error code.
- Command handlers persist an attempt before calling their Supabase gateway.
  Same command ID with changed payload fails locally. Unknown-outcome retry
  reuses the command ID and canonical payload. A confirmed result can repair a
  failed local projection without reposting money.
- The Internal Transfer store can enumerate incomplete rows by business. The
  Expense store cannot. Neither store has a durable next-attempt schedule,
  claim token/lease, actor/device/session/scope snapshot, entity-version or
  deletion contract, durable error class, generic operation classification,
  inbox, cursor, or conflict table.
- `sending` has no durable lease. A crash can leave it stale without a generic
  recovery rule. UI `_retryRequest` fields are process memory and disappear on
  restart. There is no background worker, poller, or general drain.
- The two Supabase RPCs already implement server-side command receipts keyed
  by business/type/command, fingerprint comparison, stable replayed results,
  transactions, business membership checks, and server timestamps. This plan
  consumes that behavior; it does not modify the RPCs or declare it a general
  server contract for future operations.

### C.4 Synchronization and conflict state

`VERIFIED_CURRENT_STATE`

- There is no generic outbox, inbox, durable sync cursor, conflict repository,
  pull protocol, reconciliation engine, or background synchronization runtime.
- Projection code fails closed when an acknowledged server row conflicts with
  local state, but the mismatch is currently surfaced as a projection failure.
  The divergent local and remote evidence is not captured in a queryable
  durable conflict record.
- Prior committed architecture selects cloud-authoritative shared state, a
  local SQLite acknowledged projection/offline working store, limited
  provisional offline writes, and hybrid synchronization: versioned safe
  reference data plus server-authoritative commands for critical writes.
  Global FIFO and client-clock last-write-wins are explicitly rejected.

## D. Current-State Architecture

`VERIFIED_CURRENT_STATE`

```text
Flutter UI
  -> ApplicationBoundary commands/queries
     -> command-specific attempt store -> Supabase RPC gateway
                                      -> confirmed Drift projection transaction
  -> legacy controllers/repositories -> shared FoundationDatabase

AppCompositionRoot
  -> one FoundationDatabase / AppRepositories graph
  -> one ExecutionContextProvider
  -> one restart-stable DeviceId
  -> one ApplicationClock
  -> optional Supabase session/membership adapter
```

The central composition root and one shared Drift database are sufficient to
own a generic durable-sync store without leaking Drift into application
contracts. The application layer already owns provider-neutral identity,
scope, context, time, commands, and gateway ports. The persistence adapter
must therefore remain local/Drift infrastructure, while transport adapters
remain separate and provider-specific.

## E. Predecessor Contracts Consumed

| Contract | Classification | Workstream-4 use |
| --- | --- | --- |
| `BusinessId` is the sole tenant ID | `PREDECESSOR_CONTRACT` | Required on every outbox, inbox, conflict, and checkpoint key; no branding/profile fallback. |
| `BusinessWide` / `WarehouseScope` are explicit | `PREDECESSOR_CONTRACT` | Persist `scope_kind`; `warehouse_id` is required only for warehouse scope. |
| Remote and local actor identities are distinct | `PREDECESSOR_CONTRACT` | Synchronizable operations require the verified remote actor. Legacy local-only writes are not silently enrolled. |
| `DeviceId` is UUIDv4 and restart-stable | `PREDECESSOR_CONTRACT` | Capture on outbound operations and remote mutation metadata; never regenerate to recover queue state. |
| `SessionId` identifies an authenticated lifecycle | `PREDECESSOR_CONTRACT` | Capture as provenance on outbound work; never use a historic session as current authorization. |
| `ExecutionContext` is one atomic session/business/device snapshot | `PREDECESSOR_CONTRACT` | Enqueue validates and copies one snapshot before durable write. No independent provider reads. |
| `OperationId` is a canonical UUID | `PREDECESSOR_CONTRACT` | Primary outbound identity and inbound source-operation identity. Existing command IDs remain valid. |
| `EntityVersion` starts at 1 and advances once per accepted server mutation | `PREDECESSOR_CONTRACT` | Store base/remote/acknowledged versions; never create client authority. |
| `DeletionMetadata` is explicit, versioned, UTC, actor/device/operation-linked | `PREDECESSOR_CONTRACT` | Preserve authoritative inbound tombstones and both sides of deletion conflicts. |
| `ApplicationClock` returns UTC | `PREDECESSOR_CONTRACT` | All local operational timestamps and lease decisions use the injected clock. |
| `BusinessDate` is Cairo date-only | `PREDECESSOR_CONTRACT` | Optional only when the business operation materially has a business date. It is never inferred from a stored UTC timestamp after the fact. |

`WORKSTREAM_4_NEW_RESPONSIBILITY` is durable queue/dedupe/conflict/checkpoint
state, state transitions, retry and lease evidence, crash recovery, atomic
coordination, and bounded adoption. `DOWNSTREAM_RESPONSIBILITY` is entity-
specific merge policy, server APIs for new entities, a scheduler, UX,
commercial recovery, and vertical migration.

## F. Workstream-4 Scope

`PLANNED_CHANGE`

1. Provider-neutral value/state contracts for durable outbound operations,
   inbound operations, unresolved conflicts, retry classification, claim
   leases, and sync checkpoints.
2. Four new SQLite tables: durable outbox operations, durable inbox
   operations, durable conflicts, and sync checkpoints.
3. Drift repositories with compare-and-set state transitions, scope checks,
   uniqueness enforcement, restart discovery, and expired-lease recovery.
4. A Drift-owned transaction coordinator for business mutation + enqueue and
   inbound application/conflict + inbox/checkpoint state.
5. Bounded adoption by newly created Expense and Internal Transfer attempts,
   while preserving old attempt rows and current immediate transport behavior.
6. Durable conflict capture when either existing confirmed projection detects
   incompatible local evidence.
7. Unit, database/repository integration, file-restart, concurrency,
   migration, command, and projection regression tests.

## G. Explicit Non-Scope

`DEFERRED`

- No new or changed Supabase table, RPC, RLS policy, Edge Function, HTTP API,
  or provider payload.
- No background drain, scheduler, timer, connectivity listener, app-lifecycle
  worker, Android worker, or multi-process service.
- No product/customer/supplier/cloud vertical, including product table
  versions/tombstones or product write-command migration.
- No final business-specific merge or conflict-resolution policy. Foundation
  records evidence and remains unresolved unless an already committed exact
  replay rule applies.
- No sync dashboard, badges, settings, retry/cancel UI, or error-detail UI.
- No automatic cancellation, compaction, retention deletion, queue export,
  device reprovision guard UI, uninstall recovery, restore replay, or business
  wipe policy change.
- No licensing, trial, recovery, Android, documents, reports, logo queries,
  other application-query migrations, or additional financial commands.

## H. Durable Outbox Contract

### H.1 Identity and immutable envelope

`PLANNED_CHANGE`

The outbox row is the durable operation. A second outbox-entry identifier adds
no correctness and is rejected. `operation_id` is its primary key. For v1,
existing Expense/Internal Transfer `commandId` supplies both `operation_id`
and `idempotency_key`; both concepts remain explicit because server dedupe is
scoped by business and operation kind while operation identity is global.

Enqueue is insert-once. A repeated `operation_id` is a no-op only when every
immutable identity/scope/classification/payload field and fingerprint match.
Any mismatch is a durable-idempotency conflict and no transport occurs.

### H.2 Field decisions

| Concern | Decision | Stored representation and rationale |
| --- | --- | --- |
| Outbox entry identity | `REJECTED` as separate field | `operation_id` already uniquely identifies the row. |
| Operation identity | `REQUIRED` | Canonical `OperationId`; SQLite primary key. |
| Idempotency key | `REQUIRED` | Canonical string; v1 existing commands use the same UUID as operation ID; unique with business and operation kind. |
| Aggregate/entity identity | `REQUIRED` classification, nullable ID | `aggregate_type` required; `aggregate_id` nullable only for a server-assigned create/result. |
| Tenant/scope identity | `REQUIRED` | `business_id`, `scope_kind`, nullable `warehouse_id` with a scope consistency check. |
| Actor identity | `REQUIRED` | `actor_auth_user_id` from verified remote membership. A local actor is not coerced into this field. |
| Device identity | `REQUIRED` | Captured predecessor `DeviceId`. |
| Execution-context identity | `REQUIRED` | `session_id` and `captured_role`; evidence only, not continuing authorization. |
| Operation kind | `REQUIRED` | Stable provider-neutral name such as `financial.internalTransfer.post.v1`. |
| Payload | `REQUIRED` | Canonical JSON. Secrets and raw exception details are prohibited. |
| Payload/schema version | `REQUIRED` | Positive integer independent from the database schema version. |
| Payload fingerprint | `REQUIRED` | Lowercase SHA-256 hex of exact canonical UTF-8 payload. |
| Entity/version revision | `REQUIRED_WHEN_APPLICABLE` | Nullable `base_entity_version`; required for versioned update/delete, null for append or create. Server acknowledgement version is separate. |
| Authoritative deletion metadata | `REJECTED` outbound | A client sends deletion intent plus base version in the versioned payload. It cannot invent server deletion time/version. `is_deletion_intent` is stored for query/recovery. |
| Occurred-at | `REQUIRED` | `occurred_at_utc`, the captured client evidence instant from `ApplicationClock`. |
| Created-at | `REQUIRED` | `created_at_utc`, the local durable insert time. It may equal occurred-at but has a different meaning. |
| Cairo business date | `REQUIRED_WHEN_APPLICABLE` | Nullable `business_date`; validated with `BusinessDate`, present for current financial commands. |
| Causal dependency | `REQUIRED_WHEN_APPLICABLE` | Nullable `causal_predecessor_operation_id`; no implicit FIFO. |
| Attempt count | `REQUIRED` | Non-negative and incremented atomically at successful claim. |
| Next-attempt time | `REQUIRED_WHEN_RETRYING` | Nullable UTC; set for retry wait, null for terminal/non-scheduled states. |
| Last-attempt time | `REQUIRED_AFTER_FIRST_CLAIM` | Nullable UTC. |
| Last error | `REQUIRED_ON_FAILURE` | Stable `last_error_class` and sanitized `last_error_code`; raw messages/stacks are rejected. |
| Delivery/ack status | `REQUIRED` | State machine below; mere socket delivery is never represented as success. |
| Claim/lease | `REQUIRED_WHEN_CLAIMED` | Random `claim_token` and UTC `lease_expires_at_utc`. |
| Acknowledgement | `REQUIRED_AFTER_ACK` | Canonical result JSON, schema version, fingerprint, optional stable server result ID, server accepted UTC, and optional acknowledged entity version. |
| Updated timestamp | `REQUIRED` | UTC on every state transition. |
| Record revision | `REQUIRED` | Monotonic local `record_version` for compare-and-set; not an entity/server version. |
| Full attempt history rows | `DEFERRED` | Counter, last attempt, last stable error, and transition state are enough for foundation correctness. Telemetry/history can be added later. |

### H.3 State machine

Exact persisted states:

```text
PENDING
  -> CLAIMED
      -> RETRY_WAIT -> CLAIMED
      -> ACKNOWLEDGED_PENDING_APPLY -> COMPLETED
      -> PERMANENT_FAILURE
      -> CONFLICT
  -> CANCELLED (only through a later policy that proves cancellation is safe)

CLAIMED --lease expiry/restart recovery--> RETRY_WAIT
ACKNOWLEDGED_PENDING_APPLY --restart--> local apply only; never resend
```

- `PENDING`: durable and immediately eligible, subject to an acknowledged
  causal predecessor.
- `CLAIMED`: exactly one current claim token owns transition authority until
  lease expiry. Attempt count and last-attempt UTC are already durable.
- `RETRY_WAIT`: transient or unknown outcome. The same operation ID,
  idempotency key, and fingerprint must be retried at/after `next_attempt_at`.
- `ACKNOWLEDGED_PENDING_APPLY`: a validated canonical server result is durable;
  only local idempotent application/reconciliation remains.
- `COMPLETED`: acknowledgement and required local projection are durably
  applied. This replaces the ambiguous conventional word `DELIVERED`.
- `PERMANENT_FAILURE`: retrying the unchanged operation cannot succeed.
- `CONFLICT`: divergence evidence is durably linked to a conflict row; no
  overwrite occurs.
- `CANCELLED`: reserved terminal evidence. Workstream 4 does not introduce a
  cancel action.

All state-changing methods require the expected current state plus
`record_version`; claim-owned transitions also require the exact claim token.
An update affecting zero rows is a lost-race result, never assumed success.

## I. Durable Inbox / Dedupe Contract

### I.1 Identity and receive semantics

`PLANNED_CHANGE`

An inbound operation is uniquely keyed by
`(source_authority, source_operation_id)`. `source_authority` is a stable,
provider-neutral authority/stream identity; the future Supabase adapter must
choose its configured server authority identifier. The row also stores and
validates business/scope. Reuse of one source key with a different scope,
kind, version, payload, or fingerprint is `inboundIdentityMismatch`, not a
duplicate.

Exact states:

```text
RECEIVED -> APPLYING -> APPLIED
                     -> CONFLICT
                     -> REJECTED
          -> RECEIVED (retryable apply failure or expired lease)
```

- Receipt is a short committed transaction that inserts the immutable
  envelope as `RECEIVED`. Exact duplicate receipt returns the existing row.
- Claim uses a token, lease expiry, attempt counter, timestamp, and conditional
  update identical in principle to the outbox.
- `APPLIED` means the corresponding business mutation and applied marker
  committed in one `FoundationDatabase.inTransaction` transaction.
- `CONFLICT` means the conflict row and inbox disposition committed together;
  no incompatible business overwrite occurred.
- `REJECTED` is only a stable unsupported-version, invalid-envelope, scope, or
  permanent policy result. Retryable technical failure returns to `RECEIVED`.

Required fields are source authority/operation ID, business and explicit
scope, operation kind, aggregate type/ID, canonical payload/version/fingerprint,
source actor/device where supplied by authoritative metadata, remote entity
version, optional authoritative deletion metadata, server occurrence UTC,
local received UTC, state, apply attempts, claim/lease, applied/rejected UTC,
stable error class/code, linked conflict ID, created/updated UTC, and local
record version. Session identity is not required inbound because an
authoritative server change is not authorized by replaying a client session.

### I.2 Atomic invariants

```text
A successfully applied inbound operation cannot be applied twice after
crash, restart, duplicate delivery, or concurrent processing.

The system cannot durably mark an inbound operation APPLIED unless the
corresponding business mutation is durably committed.
```

The implementation seam is a transaction-owned `applyInbound` method on the
Drift durable-sync coordinator. It reloads and validates the `APPLYING` row and
claim token inside the transaction, invokes the transaction-scoped business
applier, marks `APPLIED`, and optionally advances the matching checkpoint.
Existing Drift adapter calls nested under the same `FoundationDatabase`
participate in that transaction. Adapters backed by another database or only
by `RepositoryTransaction` must fail composition and cannot claim this
guarantee.

## J. Conflict-State Contract

`PLANNED_CHANGE`

Every non-equivalent version/payload/tombstone divergence that is not governed
by an already committed deterministic rule produces a `DurableConflict`.
There is no silent whole-row last-write-wins.

Required conflict evidence:

- UUID `conflict_id` and unique deterministic SHA-256 `conflict_key`;
- business ID plus explicit scope kind/warehouse ID;
- entity type and entity ID;
- nullable local and remote entity versions (null means genuinely absent/not
  versioned, not unknown text);
- canonical local and remote payload snapshots and fingerprints; JSON `null`
  is the explicit snapshot for an absent side;
- nullable local and remote operation IDs and remote source authority;
- local/remote deleted flags and nullable full serialized
  `DeletionMetadata` on the side where it exists;
- stable conflict classification such as `versionMismatch`,
  `payloadMismatchAtSameVersion`, `deleteVsUpdate`, `duplicateNaturalKey`,
  `acknowledgedProjectionMismatch`, or `reconciliationMismatch`;
- detection UTC, `UNRESOLVED` resolution state, optional linked inbox key or
  outbox operation, and local record version;
- nullable future resolution kind, resolution operation ID, resolver remote
  actor, and resolution UTC. Workstream 4 creates no resolution policy/API.

`conflict_key` is computed from canonical business/scope/entity identity,
both operation identities, versions, fingerprints, deletion flags, and
classification. Re-receiving the same conflict finds the existing row and
does not create unbounded duplicates. A genuinely changed evidence tuple gets
a new conflict.

For inbound detection, conflict insert/update plus inbox `CONFLICT` and
checkpoint advancement commit together. For an outbound acknowledgement or
existing confirmed projection mismatch, conflict insert plus outbox
`CONFLICT` commit together after the failed projection transaction rolls back.
The exception carrying conflict evidence must be typed; generic disk/SQLite
errors remain retryable projection failures and must not be mislabeled.

Required guarantees:

```text
NO_SILENT_DATA_LOSS = YES
NO_SILENT_LAST_WRITE_WINS = YES
CONFLICT_EVIDENCE_IS_DURABLE = YES
CONFLICT_STATE_IS_QUERYABLE = YES
```

## K. Transaction / Atomicity Model

### K.1 Local mutation

`PLANNED_CHANGE`

```text
BUSINESS_MUTATION + OUTBOX_INSERT = ONE FOUNDATION_DATABASE TRANSACTION
```

The owner is a Drift `DurableSyncTransactionCoordinator` constructed with the
same `FoundationDatabase` as all participating production repositories. Its
`enqueueWithMutation` operation validates the immutable operation/context,
starts `FoundationDatabase.inTransaction`, runs the business mutation, inserts
the exact outbox row, and returns only after commit. Either order inside the
transaction is safe; implementation should insert after the mutation so no
outbox is emitted when validation fails, while rollback still guarantees
neither survives a later enqueue failure.

No current local-first business write is enrolled in this workstream because
none has a committed distributed tenant/context/version transport contract.
Database integration tests use an existing `FoundationProbes` business-write
fixture to prove the generic transaction primitive. Real production usability
is separately proved by adoption of the two existing server-authoritative
command attempts described in Section R.

### K.2 Inbound application

```text
INBOUND_BUSINESS_MUTATION + INBOX_APPLIED_MARKER
+ OPTIONAL_CHECKPOINT_ADVANCE = ONE FOUNDATION_DATABASE TRANSACTION
```

The coordinator rejects wrong source/business/scope, wrong claim token,
already terminal state, and changed payload before calling an applier. The
checkpoint never advances past a retryable/rolled-back operation.

### K.3 Conflict detection

If the mutation is incompatible, the business mutation transaction rolls
back. A bounded conflict-disposition transaction then validates the same inbox
or outbox record version, inserts/deduplicates complete conflict evidence,
marks the operation `CONFLICT`, and advances an inbound checkpoint only when
the conflict record is durable. The operation is then safely handled, but not
resolved.

## L. Identity / Scope / Device / Context Integration

`PLANNED_CHANGE`

- Enqueue accepts one captured `ExecutionContext`, not separate providers.
  It requires a verified remote session and matching `BusinessContext`.
- `business_id`, scope, remote actor, captured role, device, and session are
  copied from that one context. Caller-supplied duplicates must match or the
  enqueue fails before mutation/transport.
- Current Expense/Internal Transfer remain `BusinessWide`. Warehouse-scoped
  records require a real predecessor `WarehouseId`; `businessWide` requires
  `warehouse_id IS NULL` and `warehouse` requires it non-null.
- Every load/claim/list/update repository method takes business/scope and puts
  it in its SQL predicate. A bare operation ID lookup is permitted only for
  internal exact-key validation and must still return/verify scope before use.
- A stored session is provenance only. Every send rechecks the current active
  execution context and server authorization. Device/account revocation and
  offline grace policy remain server/later-session concerns.
- Device reprovision never rewrites pending rows. The already assigned device
  remains historical evidence. Pending-work guards and recovery UX are later
  recovery work.

## M. Version / Tombstone / Time Integration

`PLANNED_CHANGE`

- `base_entity_version` is required for versioned mutable update/delete and
  prohibited for append operations unless the operation schema explicitly
  uses a base. No local timestamp substitutes for it.
- `acknowledged_entity_version` and inbound `remote_entity_version` use
  predecessor `EntityVersion`. Only validated server results advance shared
  entity versions.
- An outbound delete is an intent with a base version. The server returns the
  authoritative `DeletionMetadata`. Inbound tombstones preserve the complete
  metadata, and delete/update conflicts preserve both sides.
- Cancellation, void, reversal, disable, and archive remain their current
  domain concepts; none is silently converted to a tombstone.
- All queue, claim, retry, receipt, detection, application, acknowledgement,
  and update timestamps are UTC instants from injected `ApplicationClock` or
  validated server values.
- `business_date` is a date-only Cairo value only for operations whose schema
  includes business intent. It does not schedule retries and is not derived
  from local wall-clock strings.
- The future product vertical owns actual product version/tombstone columns.
  This foundation only stores transport and conflict evidence.

## N. Ordering / Idempotency / Retry Model

### N.1 Idempotency layers

| Layer | Foundation guarantee |
| --- | --- |
| `LOCAL_OPERATION_IDEMPOTENCY` | One operation ID + immutable envelope/fingerprint; exact enqueue replay is a no-op, mismatch fails. |
| `OUTBOUND_NETWORK_RETRY` | Same durable row, operation ID, idempotency key, payload, and fingerprint are reused; attempt metadata changes, business intent does not. |
| `REMOTE_DUPLICATE_ACCEPTANCE` | Current two RPCs already return their stored exact result. Future server operations must implement the same semantic contract; local evidence is ready but cannot guarantee a foreign server. |
| `INBOUND_DEDUPLICATION` | Unique source authority/operation key plus atomic apply marker prevents reapplication. |
| `BUSINESS_COMMAND_IDEMPOTENCY` | Remains command/entity-specific. Current Expense/Internal Transfer already implement it; the generic outbox does not pretend to make every legacy command idempotent. |

### N.2 Ordering

No global, tenant-wide, device-wide, or arrival-time FIFO is guaranteed.
Eligible scans use deterministic `(next_attempt_at_utc, created_at_utc,
operation_id)` ordering only for repeatable work selection, not business
authority. Operations tolerate duplication, delay, and reordering.

Per-entity causality is represented only by explicit
`causal_predecessor_operation_id` and `base_entity_version`. A dependent row is
not claimable until its predecessor is `COMPLETED`; a terminal predecessor
failure leaves it blocked and queryable. The server version/locks and
business-specific command transaction remain authoritative.

### N.3 Retry classification

Retryable classes are `connectivity`, `timeout`, `rateLimited`,
`serverTransient`, `serializationConflict`, `authenticationRefreshRequired`,
and `unknownOutcome`. Permanent classes are `validation`,
`unsupportedPayloadVersion`, `authorizationDenied`, `scopeMismatch`,
`fingerprintMismatch`, and non-retryable `businessRule`. `remoteConflict` and
`reconciliationMismatch` transition to `CONFLICT` with evidence.

Backoff calculation belongs to the future dispatcher policy. The foundation
stores the resulting UTC `next_attempt_at` and supports injected deterministic
tests. Workstream 4 does not freeze numerical backoff/jitter settings or run a
scheduler. Current manual retry of Expense/Internal Transfer keeps working.

## O. Crash / Restart Recovery Model

| Crash point | Required post-restart invariant/test |
| --- | --- |
| Before local business transaction starts | Neither mutation nor outbox exists. |
| After mutation statement but before outbox insert | Transaction rollback leaves neither. |
| After outbox insert but before commit | Transaction rollback leaves neither. |
| Immediately after commit | Mutation and `PENDING` row both survive file reopen. |
| Immediately before outbound send | Row is either eligible or durably `CLAIMED`; it is never lost. |
| After remote receives/commits but before local acknowledgement | Lease expires to retry wait; same key/payload is resent and server duplicate acceptance must return the prior result. |
| After acknowledgement is stored but before local projection | `ACKNOWLEDGED_PENDING_APPLY` survives and restart performs local apply without reposting. |
| During acknowledgement projection | Projection transaction rolls back; acknowledgement remains durable and is reapplied. |
| After projection and completion commit | Restart observes `COMPLETED`; neither transport nor projection repeats. |
| During inbound receipt insert | Row is absent or exact `RECEIVED`; partial envelope cannot exist. |
| During inbound business mutation | Apply transaction rolls back; inbox is not `APPLIED`. |
| After inbound mutation statement before applied marker | Same transaction rollback removes mutation. |
| After applied marker statement before mutation commit | Same transaction rollback removes marker and mutation. |
| After inbound commit | `APPLIED` and mutation survive; duplicates are no-ops. |
| While recording conflict | Operation remains retryable/apply-pending unless complete conflict+disposition transaction commits. It is never treated safely handled without evidence. |
| Restart with retryable failures | Durable schedule/count/error remain; rows become eligible only by time/policy. |
| Restart with stale claims | Expired claim is conditionally changed to `RETRY_WAIT`, token cleared, attempt count retained, and `staleClaimRecovered` recorded. |
| Restart with permanent failures/conflicts | Terminal evidence remains queryable and is not automatically retried or deleted. |

## P. Database / Migration Plan

### P.1 Versioning rule

`VERIFIED_CURRENT_STATE`: the entry schema version is 17 and every version has
an explicit step. `PLANNED_CHANGE`: if implementation is a direct descendant
with schema still at 17, register additive migration 18 and set
`schemaVersion = 18`. If any independently authorized schema commit intervenes,
implementation must select exactly `current + 1` and add that step; it must not
reuse or skip a version.

Implementation changes `foundation_database.dart`, generated
`foundation_database.g.dart`, and `migration_strategy.dart`. Drift code
generation uses the existing dependency/tooling; no package is added.

### P.2 `durable_outbox_operations`

Purpose/owner: authoritative local outbound lifecycle, owned by the Drift
durable-sync repository.

Columns:

```text
operation_id TEXT PRIMARY KEY NOT NULL
idempotency_key TEXT NOT NULL
business_id TEXT NOT NULL
scope_kind TEXT NOT NULL
warehouse_id TEXT NULL
actor_auth_user_id TEXT NOT NULL
device_id TEXT NOT NULL
session_id TEXT NOT NULL
captured_role TEXT NOT NULL
operation_kind TEXT NOT NULL
aggregate_type TEXT NOT NULL
aggregate_id TEXT NULL
payload_schema_version INTEGER NOT NULL
payload_json TEXT NOT NULL
payload_fingerprint TEXT NOT NULL
base_entity_version INTEGER NULL
is_deletion_intent INTEGER/BOOL NOT NULL DEFAULT 0
occurred_at_utc DATETIME NOT NULL
business_date TEXT NULL
causal_predecessor_operation_id TEXT NULL
state TEXT NOT NULL
attempt_count INTEGER NOT NULL DEFAULT 0
next_attempt_at_utc DATETIME NULL
last_attempt_at_utc DATETIME NULL
last_error_class TEXT NULL
last_error_code TEXT NULL
claim_token TEXT NULL
lease_expires_at_utc DATETIME NULL
ack_schema_version INTEGER NULL
ack_payload_json TEXT NULL
ack_payload_fingerprint TEXT NULL
server_result_id TEXT NULL
server_accepted_at_utc DATETIME NULL
acknowledged_entity_version INTEGER NULL
created_at_utc DATETIME NOT NULL
updated_at_utc DATETIME NOT NULL
record_version INTEGER NOT NULL DEFAULT 1
```

Constraints/checks: UUID/value-object validation in the repository plus SQL
checks for positive schema/version values, non-negative attempts, 64-character
fingerprints, allowed state/scope values, warehouse nullability, complete
claim pairs, complete ack envelope, and state-dependent retry/error fields.
Unique `(business_id, operation_kind, idempotency_key)`. Indexes:

- `(business_id, scope_kind, warehouse_id, state, next_attempt_at_utc,
  created_at_utc, operation_id)` for eligible/recovery scans;
- `(business_id, aggregate_type, aggregate_id, created_at_utc, operation_id)`
  for per-entity evidence;
- `(causal_predecessor_operation_id, state)` for dependency checks;
- `(lease_expires_at_utc, state)` for stale-claim recovery.

No foreign key to current business tables: they have no canonical distributed
business/entity ownership and many local IDs are legacy. No automatic cascade
or retention delete.

### P.3 `durable_inbox_operations`

Purpose/owner: durable receive/dedupe/apply state, owned by the Drift inbound
repository/coordinator.

Columns mirror the relevant immutable business/scope/kind/aggregate/payload
fields and add:

```text
source_authority TEXT NOT NULL
source_operation_id TEXT NOT NULL
source_actor_auth_user_id TEXT NULL
source_device_id TEXT NULL
remote_entity_version INTEGER NULL
deletion_metadata_json TEXT NULL
server_occurred_at_utc DATETIME NOT NULL
received_at_utc DATETIME NOT NULL
state TEXT NOT NULL
apply_attempt_count INTEGER NOT NULL DEFAULT 0
last_apply_attempt_at_utc DATETIME NULL
last_error_class TEXT NULL
last_error_code TEXT NULL
claim_token TEXT NULL
lease_expires_at_utc DATETIME NULL
applied_at_utc DATETIME NULL
rejected_at_utc DATETIME NULL
conflict_id TEXT NULL
created_at_utc DATETIME NOT NULL
updated_at_utc DATETIME NOT NULL
record_version INTEGER NOT NULL DEFAULT 1
```

Composite primary key/unique identity is `(source_authority,
source_operation_id)`. Indexes cover scoped received work, stale leases,
aggregate history, and conflict ID. Checks cover state-dependent columns,
scope, fingerprint, versions, deletion metadata, and non-negative attempts.
`conflict_id` may reference the conflict table with `RESTRICT`; no business-row
foreign key or cascade is allowed.

### P.4 `durable_conflicts`

Purpose/owner: immutable divergent snapshots plus resolution status, owned by
the conflict repository.

Columns are `conflict_id` primary key, unique `conflict_key`, business/scope,
entity type/ID, local/remote versions, canonical local/remote payload JSON and
fingerprints, local/remote operation IDs, remote source authority,
local/remote deleted flags and deletion JSON, classification, detected UTC,
resolution state, optional resolution kind/operation/remote actor/time,
created/updated UTC, and local record version. Indexes:

- `(business_id, scope_kind, warehouse_id, resolution_state, detected_at_utc,
  conflict_id)`;
- `(business_id, entity_type, entity_id, detected_at_utc, conflict_id)`;
- local and remote operation IDs.

Resolution fields must be all null while unresolved and internally complete
when resolved. Workstream 4 exposes create/load/list only; it does not expose a
resolver that could bypass future policy.

### P.5 `durable_sync_checkpoints`

Purpose/owner: restart-safe inbound progress, owned by the inbound coordinator.
Composite primary key is `(business_id, scope_kind, warehouse_id,
source_authority, stream_name)`. Required values are opaque `cursor_value`,
optional `last_source_operation_id`, UTC update time, and local record version.
The cursor is never parsed or ordered locally. It advances only in the same
transaction as every operation before it becoming `APPLIED`, `CONFLICT`, or
permanently `REJECTED` with durable evidence.

### P.6 Migration/backfill/retention

- Create all four tables and indexes additively. Existing business rows need
  no backfill.
- Do not backfill `ExpensePostingAttempts` or
  `InternalTransferPostingAttempts`: they lack actor, device, session, exact
  scope, aggregate/version, and lease evidence. Fabricating those values would
  violate the predecessor.
- Retain both legacy attempt tables. Compatibility adapters continue existing
  rows to terminal state while all newly prepared rows use the generic outbox.
- No automatic row deletion. Compaction requires a later retention policy,
  server checkpoint evidence, audit requirements, and recovery decision.
- Sync tables remain outside current business backup/restore and wipe. The
  later recovery owner decides export, restore, reprovision, uninstall, and
  wipe interactions. Workstream 4 tests that ordinary business backup does not
  accidentally serialize these operational records.

## Q. Application / Repository Ownership

Candidate paths are concrete and follow the repository's current application
ports plus co-located Drift adapter convention:

| Layer | Candidate path/component | Responsibility |
| --- | --- | --- |
| `DOMAIN/APPLICATION` | `lib/application/distributed_state/durable_operation.dart` | Immutable outbound/inbound envelopes, scope snapshot, fingerprints, statuses, retry/error classifications, acknowledgement. |
| `DOMAIN/APPLICATION` | `lib/application/distributed_state/durable_conflict.dart` | Conflict snapshots, classifications, unresolved state. |
| `APPLICATION` | `lib/application/distributed_state/durable_outbox_repository.dart` | Enqueue/load/list/claim/transition port. |
| `APPLICATION` | `lib/application/distributed_state/durable_inbox_repository.dart` | Receive/load/claim/disposition port. |
| `APPLICATION` | `lib/application/distributed_state/durable_conflict_repository.dart` | Record-dedup/load/list unresolved port. |
| `APPLICATION` | `lib/application/distributed_state/durable_sync_checkpoint_repository.dart` | Scoped opaque checkpoint port. |
| `APPLICATION` | `lib/application/distributed_state/durable_sync_transaction_coordinator.dart` | Atomic local mutation and inbound apply/conflict contracts. |
| `INFRASTRUCTURE/PERSISTENCE` | `lib/core/persistence/foundation_database.dart` and `.g.dart` | Four Drift tables and generated accessors. |
| `INFRASTRUCTURE/PERSISTENCE` | `lib/core/persistence/migration_strategy.dart` | One additive sequential migration. |
| `INFRASTRUCTURE/PERSISTENCE` | `lib/core/distributed_state/drift_durable_sync_store.dart` | All SQL, compare-and-set claims, recovery, and transaction coordination; may implement the four small ports in one database-owned adapter. |
| `APPLICATION/COMPOSITION` | `lib/application/application_dependencies.dart`, `lib/composition/app_composition_root.dart`, `lib/composition/legacy_application_dependency_bridge.dart` | Construct and expose one shared durable-sync store/coordinator. |
| `EXISTING APPLICATION` | Expense/Internal Transfer attempt-store ports and handlers | Compatibility mapping to the generic outbox for new operations. |
| `EXISTING PERSISTENCE` | Both Drift attempt stores and confirmed projection writers | Legacy fallback and transactional generic completion/conflict capture. |
| `TEST SUPPORT` | `test/support/fixed_application_clock.dart` and small durable-operation builders | Deterministic UTC/claim/crash fixtures; reuse existing fixed device/context helpers. |

The implementation may split `drift_durable_sync_store.dart` if it becomes
unwieldy, but ownership and transaction boundaries may not change. No
`TransactionCoordinator` backed only by `RepositoryTransaction` may be used
for production durability.

## R. Existing Write-Seam Integration Strategy

### R.1 Classification

| Write seam | Classification | Decision |
| --- | --- | --- |
| New Expense and Internal Transfer command attempts | `FOUNDATION_INTEGRATION_REQUIRED_NOW` | Store new attempts in generic outbox using the validated captured context, existing command ID/payload/fingerprint/business date, and current immediate gateway invocation. |
| Existing rows in the two specialized attempt tables | `FOUNDATION_INTEGRATION_REQUIRED_NOW` compatibility | Read/update in place through fallback; do not backfill or reissue. Projection completion supports both stores. |
| Existing confirmed Expense/Internal Transfer projection mismatch | `FOUNDATION_INTEGRATION_REQUIRED_NOW` | Replace generic `StateError` mismatch with typed evidence and persist `acknowledgedProjectionMismatch`/`reconciliationMismatch`; no overwrite. |
| Generic mutation+outbox and inbound+inbox probe transaction | `REPRESENTATIVE_VERTICAL_INTEGRATION` at database-test level | Proves the reusable atomic seam with `FoundationProbes`; does not enroll an unauthorized business vertical. |
| Product writes | `DOWNSTREAM_MIGRATION` | The next Cloud Hybrid Product Catalog vertical owns command/API/entity version/tombstone integration. |
| Customer/supplier/profile writes | `DOWNSTREAM_MIGRATION` | Require future versioned server contracts and real distributed IDs. |
| Sales, purchases, inventory, collections/payments, remaining finance | `DOWNSTREAM_MIGRATION` | Require their own atomic server command groups; do not row-sync. |
| Backup restore/wipe/import | `OUT_OF_SCOPE` | Never ordinary outbox replay; later recovery/migration authority. |
| Theme/trial/licensing/documents/reports/UI settings | `OUT_OF_SCOPE` | Device-local, derived, or later owner. |

### R.2 Compatibility details

`ExpensePostingAttemptStore.prepare` and
`InternalTransferPostingAttemptStore.prepare` are extended to accept the
already validated captured execution context and business date. Their Drift
implementations first load a matching legacy row. If one exists, the legacy
state machine continues unchanged. Otherwise they create/read the generic
outbox operation. Their domain-facing attempt objects remain compatible while
mapping:

```text
queued/draft -> PENDING
sending -> CLAIMED
unknownOutcome -> RETRY_WAIT
confirmedProjectionPending -> ACKNOWLEDGED_PENDING_APPLY
confirmed -> COMPLETED
rejected -> PERMANENT_FAILURE
```

New generic claims must use a real lease token. The current handler remains the
only immediate dispatcher and passes that token through transition calls.
There is no automatic discovery/drain invocation in production. Projection
writers update generic completion inside their existing transaction; their
legacy direct-table completion remains for old rows.

Adopting both already server-authoritative commands is the bounded proof that
the foundation is usable. It avoids both a dead schema and an uncontrolled
migration of every application write.

## S. Implementation Slices

### S1 — Provider-neutral durable contracts

Files: new application distributed-state model/repository/coordinator ports;
focused unit tests.

Responsibility: immutable envelope validation, canonical scope/context
snapshot, exact state machines, error/retry classes, conflict key calculation,
and compare-and-set result vocabulary. Depends only on predecessor identity,
metadata, and clock types. Acceptance: constructor/serialization/state tests,
UUID/scope/version/time/deletion failures, canonical fingerprint stability.
No SQL, network, UI, or entity policy.

### S2 — Additive Drift schema and migration

Files: `foundation_database.dart`, generated `.g.dart`,
`migration_strategy.dart`, migration tests.

Responsibility: four tables, checks, keys, and indexes at deterministic next
schema version. Acceptance: fresh create, v17 upgrade, legacy-row preservation,
schema/index/constraint inspection, and no business-table alteration. No
Supabase migration or backfill.

### S3 — Durable outbox repository, leases, and recovery

Files: Drift durable-sync store, outbox repository tests.

Responsibility: insert-once exact replay, scoped reads, deterministic eligible
scan, atomic claim, token/version guarded transitions, durable retry/ack,
expired-claim recovery, dependencies. Acceptance: file restart, concurrent
claims, payload mismatch, stale lease, state consistency, no raw error storage.
No worker or backoff policy.

### S4 — Atomic local mutation + outbox composition

Files: coordinator adapter and database integration tests.

Responsibility: one `FoundationDatabase.inTransaction` for mutation and
enqueue. Acceptance: injected failures at before mutation, after mutation,
after enqueue, and before commit prove both-or-neither; successful commit and
pending discovery survive reopen; simultaneous writers serialize. No existing
local-first business domain is migrated.

### S5 — Inbox dedupe, atomic apply, and checkpoint foundation

Files: inbox/checkpoint portions of store/coordinator and tests.

Responsibility: exact receive dedupe, claim/lease, business apply + APPLIED +
checkpoint transaction, permanent rejection, retry recovery. Acceptance:
first application once, duplicate/concurrent/restart no reapply, both inverse
atomicity crash invariants, wrong scope fails, checkpoint cannot overtake
retryable work. No pull transport.

### S6 — Durable conflict-state foundation

Files: conflict model/repository, coordinator conflict disposition, tests.

Responsibility: canonical two-sided evidence, dedupe key, unresolved queries,
inbox/outbox conflict linking, tombstones. Acceptance: incompatible versions,
same-version payload mismatch, delete/update, repeated conflict, restart,
atomic disposition, and no overwrite. No resolver/merge UI or policy.

### S7 — Bounded adoption by existing server-authoritative commands

Files: Expense/Internal Transfer attempt ports and Drift adapters, both command
handlers, both confirmed projection writers, composition/dependency files, and
their focused tests.

Responsibility: new attempts use generic outbox; legacy rows continue; current
manual immediate send and canonical RPC payloads remain identical; validated
ack survives before projection; typed projection divergence becomes durable
conflict. Acceptance: existing success/failure/replay tests plus new context
capture, durable retry discovery, ack-without-repost repair, legacy fallback,
and conflict query tests. No gateway/RPC/UI behavior change.

### S8 — Regression and forensic closure

Responsibility: run code generation/format, focused suites, migration tests,
all Expense/Internal Transfer/projector/context/composition regressions,
`flutter analyze`, full `flutter test`, and `git diff --check`; inspect schema
delta and production touch set. Acceptance: only Workstream-4 files changed,
no later workstream began, one normal implementation commit can be remotely
locked under separately committed authorization.

## T. Test Matrix

| Area | Test level | Mandatory proof |
| --- | --- | --- |
| Contract/value objects | Unit | Canonical identity/scope/context/version/deletion/time serialization; invalid and non-UTC values fail closed. |
| Outbox enqueue | Repository/database | Exact replay one row; changed immutable field/fingerprint conflict; uniqueness and scope predicates. |
| Local atomicity | Database integration | Mutation+outbox both commit or neither at every injected failure point. |
| Restart durability | File database | Pending, retry, acknowledgement, conflict, inbox marker, checkpoint, and terminal states survive close/reopen. |
| Claim concurrency | Database integration | Concurrent claimers yield one token/owner; losing CAS cannot transition; SQLite serialization is sufficient without in-memory mutex correctness. |
| Retry | Repository/integration | Attempt count/last attempt/next attempt/error persist; expired claim recovers; same operation/key/payload reused. |
| Acknowledgement | Repository/integration | Ack envelope is durable before projection; completion requires local apply; restart repairs without transport. |
| Inbox first delivery | Database integration | One business apply and APPLIED marker. |
| Inbox duplicate delivery | Database integration | Sequential, concurrent, and post-restart duplicates do not reapply. |
| Inbox inverse atomicity | Database integration | Neither marker-without-mutation nor mutation-without-marker can survive injected crash. |
| Checkpoint | Database integration | Advances with handled batch transaction; never advances past retryable rollback; opaque value not locally ordered. |
| Conflicts | Unit + database integration | Version/payload/delete divergence creates complete queryable snapshots; no overwrite; repeated evidence dedupes; changed evidence makes a distinct conflict. |
| Conflict crash | Database integration | An operation cannot be treated handled without a committed conflict row. |
| Scope | Unit + repository | Cross-business and cross-warehouse read/claim/apply/update fail; warehouse nullability constraints hold. |
| Time | Unit + repository | UTC operational instants and Cairo `BusinessDate` stay distinct under a fixed clock. |
| Tombstones | Unit + repository | Full authoritative deletion metadata survives receipt/restart/conflict; cancellation/void not reclassified. |
| Migration | Database integration | v17-to-next upgrade preserves all existing rows and specialized attempts, creates exact tables/indexes, and does no fabricated backfill. |
| Legacy attempt compatibility | Repository/integration | Old rows continue in old tables; new rows use outbox; no duplicate operation is created. |
| Existing commands | Application integration | Same payload/gateway/result/error/replay semantics; context captured; new durable states map correctly. |
| Existing projectors | Database integration | Exact replay no-op, full transaction rollback, generic/legacy completion, and durable typed mismatch conflict. |
| Composition | Integration | One store/database/clock/context instance is shared; alternate-database participant fails closed. |
| Regression | Full suite | No change to current local workflows, Supabase RPCs, UI, reports, Android, trial, recovery, or completed predecessor tests. |

Principal invariants:

```text
LOCAL_MUTATION_IFF_OUTBOX_COMMIT
APPLIED_INBOX_IFF_BUSINESS_MUTATION_COMMIT
EXACT_INBOUND_OPERATION_APPLIES_AT_MOST_ONCE
ACKNOWLEDGED_OUTBOUND_RESULT_IS_NEVER_REPOSTED_FOR_LOCAL_REPAIR
SAME_ID_CHANGED_PAYLOAD_NEVER_REACHES_TRANSPORT_OR_APPLIER
ONE_UNEXPIRED_CLAIM_TOKEN_OWNS_A_TRANSITION
CONFLICT_DISPOSITION_REQUIRES_DURABLE_CONFLICT_EVIDENCE
NO_SCOPE_CROSSING
NO_CLIENT_CLOCK_CAUSAL_AUTHORITY
NO_SILENT_TOMBSTONE_OR_PAYLOAD_LOSS
```

## U. Acceptance Criteria

Workstream-4 implementation is acceptable only when:

1. The four durable state tables and provider-neutral contracts exist with all
   keys, checks, and indexes described here.
2. Newly issued Expense and Internal Transfer attempts genuinely use the
   generic outbox; legacy rows remain recoverable without fabricated context.
3. A real file-backed restart proves pending/retry/ack/inbox/conflict/checkpoint
   durability.
4. Local mutation+outbox and inbound mutation+APPLIED are each one real Drift
   transaction, not a snapshot or in-memory queue.
5. Concurrent claims and dedupe are enforced by conditional SQL and unique
   constraints, not by process mutexes alone.
6. Expired claims, unknown outcomes, permanent failures, acknowledgements
   pending local apply, and conflicts have deterministic restart behavior.
7. Projection divergence from the two adopted commands is durable and
   queryable with both sides preserved.
8. Identity, business/scope, actor, device, context, version, tombstone, UTC,
   and Cairo date contracts are consumed without redesign.
9. No network/scheduler/UI/cloud-product/recovery implementation is included.
10. All Section T tests and regression/forensic gates pass.

## V. Risks / Open Questions

No owner decision blocks implementation. The remaining items are technical
risks with resolved handling:

- **Legacy attempts lack predecessor metadata.** Preserve in place and route
  by existence; never backfill invented device/session/actor/scope values.
- **Projection mismatches currently throw generic errors.** Introduce a typed
  internal exception containing sanitized canonical local/remote evidence;
  separate actual persistence failures from business divergence.
- **Drift nested transaction participation must be proven.** Composition and
  database tests must verify all participating adapters share the exact
  `FoundationDatabase`; otherwise fail closed.
- **SQLite has one writer but callers may race.** Unique constraints and
  expected-state/record-version/claim-token conditional updates are the
  authority. In-memory serialization is only an optimization.
- **No dispatcher exists.** This is deliberate. Durable eligible state and
  claim/recovery APIs are implemented; automatic execution remains deferred.
- **No synchronized mutable entity has version columns yet.** Inbox/conflict
  database tests use a controlled probe applier; the product vertical later
  supplies its entity schema and policy without redesigning durability.
- **Operational tables may grow.** No evidence is deleted until a separately
  governed retention/compaction policy can prove safety.
- **Payloads can contain business-sensitive data.** Persist only canonical
  operation/result snapshots needed for replay/evidence; never stack traces,
  tokens, credentials, or unrestricted server error bodies.

## W. Downstream Handoff Boundaries

### Cloud Hybrid Product Catalog Vertical Slice

`DEFERRED`: owns product server schema/RLS/API, product distributed IDs,
product entity-version/tombstone columns, initial import/mapping, product
command/pull serializers, entity-specific merge policy, and UI/cache behavior.
It consumes outbox enqueue/claim/ack, inbox apply/dedupe/checkpoint, conflict
recording, and predecessor metadata.

### Recovery / Trial / Licensing Boundary

`DEFERRED`: owns pending-work export/recovery, device reprovision/uninstall and
business-wipe guards, backup/restore treatment, retention/compaction policy,
trial/license interaction, and user-authorized recovery workflows. It cannot
reinterpret or silently delete Workstream-4 evidence.

### Other later work

`DEFERRED`: additional commands/queries, Android background execution,
documents/reports, UI/settings/dashboard, commercial/licensing features,
Cloud realtime hints, metrics/telemetry, and automated scheduling. Foundation
observability is limited to durable IDs, states, UTC timestamps, attempts,
stable error class/code, claim/lease, acknowledgement, checkpoint, and conflict
links. Logs, tracing, dashboards, notifications, and attempt-history analytics
are later work.

## X. Implementation Authorization Boundary

This planning artifact authorizes only a separate fresh session, after this
document's containing commit is independently remote-locked, to implement the
exact bounded slices S1-S8.

```text
DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION_PLANNING = COMPLETE
DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION_IMPLEMENTATION = NOT_STARTED

NEXT_ALLOWABLE_SESSION = IMPLEMENTATION_OF_DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION
NEXT_ALLOWABLE_SESSION_CLASS = IMPLEMENTATION_OF_THIS_PLAN_ONLY

CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE_AUTHORIZED = NO
RECOVERY_TRIAL_AND_LICENSING_BOUNDARY_AUTHORIZED = NO
OTHER_WORKSTREAM_IMPLEMENTATION_AUTHORIZED = NO
```

The implementation session must re-run repository/authority/remote-lock
forensics and stop on divergence. It may not use this plan to start slot 5 or
6, add a worker/network protocol/UI, or reopen completed predecessor work.
