# Distributed identity, scope, and time contract completion plan

## A. Session Result / Planning Classification

```text
SESSION = PLAN_DISTRIBUTED_IDENTITY_SCOPE_TIME_CONTRACT_COMPLETION
SESSION_CLASS = PLANNING_ONLY
EVIDENCE_DATE = 2026-09-07 (Africa/Cairo)
PLANNING_COMPLETE = YES
IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED_THIS_SESSION = NO
SELECTED_SUCCESSOR = DISTRIBUTED_IDENTITY_SCOPE_TIME_CONTRACT_COMPLETION
```

This artifact freezes the minimum application-boundary contracts that the
later durable outbox/inbox/conflict-state owner may consume. It changes no
production source, test, SQL, schema, migration, generated file, dependency,
UI, controller, repository, service, command, or query behavior.

## B. Repository Identity

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
REQUIRED_ENTRY_HEAD = 8e675b2545d4388f8624b746f643188ce8c88598
```

No applicable repository `AGENTS.md` was present.

## C. Entry / Recovery Classification

```text
ENTRY_CLASSIFICATION = CASE_A_FRESH
TRACKED_WORKTREE = CLEAN
INDEX = CLEAN
STASH = EMPTY
ACTIVE_GIT_OPERATION = NONE
INDEX_LOCK = ABSENT
RECOVERY_REQUIRED = NO
```

`MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `rebase-merge`,
`rebase-apply`, and `index.lock` were absent. No state was repaired, reset,
stashed, discarded, rebased, or overwritten.

## D. Entry Remote-Lock Proof

A fresh `git fetch origin --prune` completed. The first direct remote query
encountered Windows Schannel `SEC_E_NO_CREDENTIALS`; it was not accepted as
proof. A read-only retry succeeded and independently advertised the exact
required head.

```text
ENTRY_LOCAL_HEAD = 8e675b2545d4388f8624b746f643188ce8c88598
ENTRY_TRACKING_HEAD = 8e675b2545d4388f8624b746f643188ce8c88598
ENTRY_DIRECT_REMOTE_HEAD = 8e675b2545d4388f8624b746f643188ce8c88598
ENTRY_MERGE_BASE = 8e675b2545d4388f8624b746f643188ce8c88598
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0
ENTRY_REMOTE_LOCK = VERIFIED
```

The tracking ref was resolved explicitly as
`refs/remotes/origin/codex/phase-108h-app-shell-runtime-ownership-boundary`.

## E. Binding Authority Chain

Git object and artifact inspection proves:

```text
PREDECESSOR_COMMIT = 8e675b2545d4388f8624b746f643188ce8c88598
PREDECESSOR_PARENT = bcb5ac2ecf724415dc45c925a613925ebe0dd300
PREDECESSOR_TREE = 28b848d33d87e350deeb5dde6aa575b4efa0cc44
PREDECESSOR_SUBJECT = docs: decide post expense-query migration successor
PREDECESSOR_ARTIFACT =
docs/POST_CONFIRMED_EXPENSE_LIST_APPLICATION_QUERY_MIGRATION_SUCCESSOR_AUTHORITY.md

SELECTED_SUCCESSOR = DISTRIBUTED_IDENTITY_SCOPE_TIME_CONTRACT_COMPLETION
NEXT_SESSION_CLASS = PLANNING_ONLY
IMPLEMENTATION_AUTHORIZED = NO
```

The binding order commit is
`a5f57c709e1b7e9b3f50d8ae4811951220edf2a6`, parent
`dfd3737e58338b3076f4f89ae0757b397d39e38e`, tree
`449fe9662b96b2677eb365fb67d7bd03a45110b3`, subject
`docs: order post-logo roadmap successor workstreams`. Its artifact
`docs/OWNER-ROADMAP-ORDER-AFTER-LOGO-QUERY-MIGRATION-PROGRAM-COMPLETION.md`
binds this order:

```text
1. SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND
2. NEXT_NON_LOGO_APPLICATION_QUERY_MIGRATION
3. DISTRIBUTED_IDENTITY_SCOPE_TIME_CONTRACT_COMPLETION
4. DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION
5. CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE
6. RECOVERY_TRIAL_AND_LICENSING_BOUNDARY
```

Items 1 and 2 are completed by `0749a436629f737dfc6d91bd1ca8a0daa81ec13f`
and `bcb5ac2ecf724415dc45c925a613925ebe0dd300`. Item 3 is therefore the
canonical current owner. No successor was reselected.

Historical Phase 108A described the semantic owner as freezing organization,
warehouse and device IDs, UUID operation IDs, versions, tombstones, and time
semantics, with no ID rewrite. Later accepted Phase 108E and Phase 108G work
implemented an application composition root and partial `BusinessContext` /
`SessionContext` seams under reused phase numbers. The later owner-discovery
artifact
`docs/OWNER-ROADMAP-SUCCESSOR-DECISION-AFTER-LOGO-QUERY-MIGRATION-PROGRAM-COMPLETION.md`
correctly says numeric completion did not complete the older semantic owner.
This plan reconciles the current code with that semantic requirement. Older
Phase 103/108A wording is evidence, not an authority to add duplicate
`organization_id`, `branch_id`, a generic outbox, or a timestamp-based merge
policy.

## F. Current-State Evidence Inventory

### Tenant and business identity

- `public.businesses.id` is a server-generated UUID, and all existing shared
  financial tables, receipts, membership checks, and RLS policies use
  `business_id` (`supabase/migrations/20260823000000_phase_108j_post_expense.sql`).
- `SupabaseCloudSessionAdapter.refresh()` reads exactly one active
  `business_memberships` row and creates a verified `BusinessContext` from its
  `business_id`, remote auth user, and role
  (`lib/infrastructure/supabase/supabase_cloud_session_adapter.dart:26`). Zero,
  multiple, malformed, or unauthorized rows clear both contexts.
- `BusinessContext` currently stores `businessId`, `userId`, optional
  `authUserId`, role, and a verified-membership flag
  (`lib/application/context/business_context.dart:1`).
- `BusinessIdentity` contains establishment name, logo, tax number, address,
  and phone only. `LocalBusinessIdentityRepository` stores it in
  `business_identity.json` under the app-data profile
  (`lib/core/business_identity/business_identity.dart:64` and
  `lib/core/business_identity/business_identity_repository.dart:32`). It is a
  branding/profile object, not a tenant identifier.
- No production `organization_id` or `tenant_id` exists. The local-only
  database also has no canonical business UUID. A local dataset is not thereby
  entitled to invent or claim a cloud business.

### Warehouse scope

No `warehouse_id`, `warehouseId`, warehouse entity, selected-warehouse
persistence, or warehouse membership exists in `lib/**` or the committed
Supabase migrations. Existing server financial commands are explicitly
business-scoped: they validate membership and account ownership by
`business_id` and carry no warehouse.

### Device identity

No `device_id`, `deviceId`, device registry, device store, or device lifecycle
exists in production or schema code. Current command IDs and transfer
references are UUIDv7 values generated in two UI screens; many legacy local
entity IDs instead combine `DateTime.now().microsecondsSinceEpoch` with local
counters/sequences. Neither pattern is a persisted device identity.

### BusinessContext and SessionContext

- `BusinessContext` and its mutable provider are in-memory. The cloud adapter
  is their only production source. Local production uses
  `NoBusinessContextProvider`, so local authentication never fabricates a
  tenant (`lib/composition/app_composition_root.dart:81`).
- `SessionContext` contains `userId`, optional `authUserId`, and a remote
  verification flag. Its local and cloud providers are independently mutable
  (`lib/application/context/session_context.dart:3`). It has no session ID,
  device, tenant, or warehouse.
- `AuthSessionContextSynchronizer` derives only a local user context from an
  authenticated `AppUser`. `DriftAuthRepository` persists accounts but keeps
  the signed-in user only in memory
  (`lib/core/auth/drift_auth_repository.dart:17`).
- Cloud mode currently constructs session and business providers separately.
  `PostExpenseCommandHandler` and `PostInternalTransferCommandHandler` compare
  active context, request context, command `businessId`, and remote auth user
  at execution (`lib/application/commands/post_expense_command.dart:253` and
  `lib/application/commands/post_internal_transfer_command.dart:287`). The
  checks are valuable, but the two-provider update is not atomic and the
  request carries only `BusinessContext`.

### Version semantics

- Command `schemaVersion` is a payload format version, not an entity version.
- `FinancialAccountCloudLinks.reconciliationVersion` is a local projection
  readiness counter incremented after confirmed projections, not a universal
  entity version (`lib/core/persistence/foundation_database.dart:362`).
- `NegativeBalanceApprovalRequests.recordVersion` starts at 1 and is used by
  one local optimistic transition workflow only
  (`lib/core/persistence/foundation_database.dart:545`).
- Products, customers, suppliers, inventory, purchases, sales, expenses,
  accounts, and other local records do not share a version contract. Their
  `updatedAt` fields, where present, are timestamps rather than causal
  versions. Current Supabase business entities likewise do not expose a
  general row/entity version.

### Deletion semantics

There is no generic deleted flag, deleted timestamp, tombstone, deletion
version, or deletion-device field. `isActive`, `cancelledAt`, `isVoided`, and
reversal links are domain lifecycle/accounting facts, not synchronization
tombstones. Physical deletes exist in local maintenance and repository flows;
they carry no distributed deletion meaning.

### Time semantics

- Production contains 162 `DateTime.now()` calls across 63 non-generated Dart
  files. Only seven calls explicitly use `DateTime.now().toUtc()`.
- `TrialClock` is the only general-looking injected clock seam, but it is
  deliberately trial-specific (`lib/core/trial/trial_clock.dart:1`).
- Existing local command-attempt stores and projection writers create UTC
  status timestamps directly with the system clock.
- Serializers frequently call `toUtc()`, while presentation has explicit
  `toLocal()` conversion in 14 files. This is partial convention, not one
  application time contract.
- The two Supabase command migrations use `timestamptz` and
  `clock_timestamp()` for authoritative acceptance/audit times. Their
  future-date validation uses unqualified `current_date`, whose timezone
  policy is not frozen in repository code.
- Current server accepted timestamps are authoritative evidence for those two
  commands. They are not a globally monotonic causal clock.

### Composition and persistence

`AppCompositionRoot.initializeProduction()` owns database initialization,
local/cloud session selection, the auth controller, the business profile
controller, command handlers, query handlers, and the application dependency
bundle (`lib/composition/app_composition_root.dart:43`).
`LegacyApplicationDependencyBridge` captures the same objects for incremental
compatibility. `ApplicationScope` exposes the resulting immutable boundary to
widgets. This root is the correct future owner for device provisioning,
application clock construction, and one atomic execution-context provider.

## G. Identity / Scope / Time Gap Matrix

| Dimension | Current committed source | Current semantics | Required Phase 108E semantics | Gap | Planned owner/layer | Future implementation consequence | Explicitly deferred later-owner work |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Tenant/business/organization identity | `businesses.id`; membership adapter | Server UUID `business_id`; local branding is unrelated | One canonical `BusinessId` UUID | Type and vocabulary are not frozen end to end | Application identity contract; server remains authority | Add validated `BusinessId`; retain wire name `business_id` | Tenant provisioning, import, org switching |
| Warehouse identity | No source | Absent | Server-issued `WarehouseId` subordinate to a business; explicit business-wide alternative | No warehouse model or selection | Application scope contract | Add discriminated `BusinessScope`; never default a warehouse | Warehouse schema/provisioning and catalog ownership |
| Device identity | No source | Absent | Random, persisted per installation profile, immutable until explicit reprovision | Distributed writes have no stable device provenance | Application port plus local infrastructure adapter | Provision before application boundary; fail closed on corruption | Server registration/revocation and queue recovery |
| BusinessContext | `business_context.dart`; cloud membership | Separate mutable business/user object | Own tenant, explicit scope, membership evidence only | Duplicates actor fields and cannot express scope | Application context | Replace free strings with value types; construct only through validated factory | Membership administration and warehouse grants |
| SessionContext | `session_context.dart`; auth/cloud adapters | User and optional remote user; no session identity | Own authentication-lifecycle ID and local/remote actor identities | No session ID; local and remote identities can be conflated | Application context | Add ephemeral `SessionId`; keep local and remote actor IDs distinct | Token storage, grace, revocation transport |
| User/audit identity | local `AppUser.id`; Supabase `auth.uid()` | Local IDs are time/sequence strings; remote UUID is server audit actor | Remote writes use `auth.uid()`; local-only audit retains local ID with explicit kind | No common typed distinction | Session/actor contract | Add typed actor provenance; never assert local-to-remote equivalence | Account-link migration and server user administration |
| Entity/version semantics | one `recordVersion`; link `reconciliationVersion` | Entity-specific counters only | Signed 64-bit positive server version per mutable entity stream | No shared contract | Application distributed-state contract | Add value/metadata contract; do not retrofit unrelated records in this owner | Storage columns per later syncable vertical slice; conflict engine |
| Updated-at semantics | mixed local `DateTime`; server `timestamptz` | Often wall-clock metadata | UTC instant metadata, never causal authority | Inconsistent sources and UTC enforcement | Application clock plus authoritative server adapters | Inject `ApplicationClock` into distributed metadata paths | Global ordering/cursor and skew handling |
| Delete/tombstone semantics | cancellation/active flags only | Domain status or physical deletion | Versioned deletion metadata for mutable synchronized entities | Generic deletion is absent | Application distributed-state contract | Add semantic tombstone type; no current row conversion | Tombstone storage/transport/retention/compaction |
| Clock source | `DateTime.now`; `TrialClock`; server clock | Many direct local calls; isolated trial seam | Injected app UTC clock; server commit clock for accepted shared writes | No shared seam | Application service dependency/composition root | Add `ApplicationClock`; migrate only distributed-boundary direct calls | Retry scheduling and server skew policy |
| UTC persistence | partial `toUtc`; server `timestamptz` | Mixed local and UTC values | Shared instants serialize/persist as UTC | Not enforced by types/tests | Contract serializers and adapters | Reject/normalize non-UTC shared instants | Entity-specific storage migrations |
| Causal ordering assumptions | timestamps and local sequences coexist | No general causal contract | Entity version/server cursor/ledger sequence; never wall clock | Missing | Version contract | Freeze explicit non-time ordering rule | Merge algorithms, cursor persistence |
| Composition/DI ownership | `AppCompositionRoot` | Two independently mutable providers | One atomic execution-context provider plus injected device/clock | Race/divergence possible | Composition root/application runtime dependencies | Build and replace context as one validated unit | Background sync worker lifecycle |
| Existing local-first compatibility | local repositories work without business context | Single local dataset and local IDs | Legacy local operations remain available but are not distributed scope | Risk of fabricating tenant/scope during migration | Compatibility bridge | Preserve null distributed context in local mode | Local-to-cloud mapping/reconciliation |

## H. Canonical Tenant / Organization Decision

```text
CANONICAL_TENANT_IDENTITY = business_id
CANONICAL_TENANT_TYPE = BusinessId
CANONICAL_TENANT_WIRE_FORMAT = LOWERCASE_HYPHENATED_UUID
ORGANIZATION_ID_ALIAS = NOT_INTRODUCED
BUSINESS_ID_SOURCE_OF_AUTHORITY = public.businesses.id
BUSINESS_PROFILE_BRANDING_IS_TENANT_IDENTITY = NO
```

“Organization” in historical roadmap prose means the tenant represented by
the existing `business_id`; it does not justify a second identifier. A
`BusinessId` value object validates and canonicalizes the UUID while existing
RPC/database wire names remain `business_id`/`businessId`.

`BusinessIdentity` remains a compatibility name for the local presentation
profile. Future documentation and API comments must call it a business
profile/branding object. Renaming that mature UI type is not required for this
owner. No local dataset receives a synthetic cloud `BusinessId`; mapping a
legacy dataset to a server business requires later explicit import/
reconciliation authority.

## I. BusinessContext / SessionContext Contract

The future model is one atomic `ExecutionContext`:

```text
ExecutionContext
  session  -> SessionContext
  business -> BusinessContext?          # null for local-only mode
  device   -> DeviceIdentity
```

`BusinessContext` owns `BusinessId`, one explicit `BusinessScope`, the remote
membership subject ID, membership role, and verified-membership evidence.
`SessionContext` owns an ephemeral random `SessionId`, optional local user ID,
optional remote auth user UUID, and authentication kind/assurance. Device ID is
owned by neither; it is installation identity in the aggregate.

`SessionContext` does not embed or duplicate `BusinessContext`. The aggregate
references both. A single factory/provider validates these invariants before
publishing a context:

1. a verified `BusinessContext` requires a verified remote session;
2. membership subject ID equals `SessionContext.remoteAuthUserId`;
3. a warehouse scope contains a non-empty server UUID and is asserted by the
   membership/scope adapter to belong to the same `BusinessId`;
4. business, warehouse, actor, and device values in a command/request must
   equal the captured execution context wherever duplicated for wire format;
5. the active provider is replaced or cleared atomically; consumers never read
   independently updated session and business providers;
6. sending a captured online command requires the current session ID and scope
   to remain compatible. A later durable retry reauthorizes and must not trust
   an old session ID.

Compatibility views may expose `sessionContextProvider` and
`businessContextProvider`, but they must derive read-only values from the same
atomic provider; two independently mutable authorities are forbidden.

The cloud adapter creates the aggregate from a live Supabase session and
exactly one verified membership. The local auth synchronizer creates a
local-only session with no business context. Local `AppUser.id` and remote
`auth.uid()` remain distinct; remote shared writes use the latter as canonical
audit actor.

## J. Warehouse Scope Contract

```text
BusinessScope = BusinessWide | Warehouse(WarehouseId)
WarehouseId = LOWERCASE_HYPHENATED_SERVER_UUID
DEFAULT_WAREHOUSE = FORBIDDEN
SYNTHETIC_LEGACY_WAREHOUSE = FORBIDDEN
NULL_SCOPE_FOR_DISTRIBUTED_OPERATION = FORBIDDEN
```

Every distributed operation declares its required scope kind. A
warehouse-scoped operation must receive `Warehouse(WarehouseId)`; absence,
mismatch, or a warehouse from another business is rejected before persistence
or transport. A genuinely business-wide operation must explicitly declare
`BusinessWide`; null is not shorthand for business-wide.

The current expense and internal-transfer server commands are business-wide
because their tables and invariants are business/account scoped and contain no
warehouse dimension. Their future application requests therefore capture
`BusinessWide` explicitly. No warehouse table, default, or fake UUID is added
just to label them. Server warehouse provisioning and selection become a
required part of the later first genuinely warehouse-scoped vertical slice,
using this already-frozen `WarehouseId` and scope contract.

## K. Device Identity Contract

```text
DEVICE_ID_FORMAT = UUID_V4
DEVICE_ID_SCOPE = APPLICATION_INSTALLATION_PROFILE
DEVICE_ID_TENANT_SCOPED = NO
DEVICE_ID_DATABASE_SCOPED = NO
DEVICE_ID_SESSION_SCOPED = NO
DEVICE_ID_BACKED_UP_WITH_BUSINESS_DATA = NO
DEVICE_ID_CREATED = ONCE_BEFORE_APPLICATION_BOUNDARY_IS_AVAILABLE
DEVICE_ID_REGENERATED_AUTOMATICALLY = NO
```

UUIDv4 is chosen because identity must not depend on wall-clock correctness.
The value is persisted in a small versioned file under the installation's app
support/data profile, separate from the business database, business backup,
branding file, and trial state. Creation uses an injected secure-random UUID
generator and an atomic temporary-file/rename write.

On a missing file, the provisioning service generates and durably writes one
ID before distributed commands are composed. On a valid file, it returns the
same ID across restarts, auth sessions, tenants, and warehouse selections. On
corrupt/unsupported content or failed persistence, distributed writes fail
closed; silent replacement is forbidden.

Reprovision is an explicit service operation with no implicit UI in this
owner. It generates a new ID only after caller-authorized profile reset or
device-clone recovery. The later outbox owner must add a pending-work guard
before exposing reprovision operationally. Server registration, attestation,
revocation, and treating the ID as authorization are later concerns. Until
then it is stable provenance, never a trusted grant.

## L. Version Contract

```text
ENTITY_VERSION_TYPE = SIGNED_64_BIT_POSITIVE_INTEGER
INITIAL_SERVER_VERSION = 1
MONOTONICITY_SCOPE = (business_id, entity_type, entity_id)
INCREMENT_AUTHORITY = SERVER_AUTHORITATIVE_MUTATION
INCREMENT_RULE = EXACTLY_ONCE_PER_ACCEPTED_SEMANTIC_MUTATION
DELETE_INCREMENTS_VERSION = YES
RESTORE_INCREMENTS_VERSION = YES
CLIENT_WALL_CLOCK_ORDERS_VERSIONS = NO
```

Mutable synchronized entities use `EntityVersion`. Creation returns version
1. Update, deletion, and restoration each produce the immediately following
version inside the authoritative server transaction. A client mutation carries
the last acknowledged `baseVersion`; the server accepts, rejects, or reports a
conflict. A local provisional mutation does not advance authoritative version.

Every authoritative mutable-entity result associates:

```text
businessId
entityType
entityId
entityVersion
serverModifiedAtUtc
modifiedByAuthUserId
modifiedByDeviceId
sourceOperationId
deletionMetadata?
```

`serverModifiedAtUtc` and device/user metadata are audit/provenance, not
tie-breakers. `schemaVersion`, `recordVersion`, and `reconciliationVersion`
retain their narrower meanings and must not be silently relabeled as
`EntityVersion`.

Immutable append-only financial/audit events do not become editable entities
to satisfy this contract. Their UUID/idempotency identity and server-owned
ledger/receipt ordering remain authoritative. The later conflict engine may
consume `baseVersion` and acknowledged version but may not redefine the
version type, scope, or increment rule.

## M. Time Authority Contract

```text
SHARED_INSTANT_PERSISTENCE = UTC
SHARED_INSTANT_SERIALIZATION = ISO_8601_WITH_UTC_Z_OR_TIMESTAMPTZ
APPLICATION_CLOCK = INJECTED ApplicationClock.nowUtc()
APPLICATION_CLOCK_RETURN_INVARIANT = isUtc == true
SERVER_ACCEPTANCE_CLOCK = DATABASE clock_timestamp()
CURRENT_BUSINESS_TIME_ZONE_V1 = Africa/Cairo
BUSINESS_DATE_FORMAT = YYYY-MM-DD_WITH_NO_TIME_OR_OFFSET
CAUSAL_ORDER = ENTITY_VERSION_OR_SERVER_SEQUENCE_CURSOR
CLIENT_WALL_CLOCK_CAUSAL_AUTHORITY = NO
SERVER_TIMESTAMP_GLOBAL_MONOTONICITY = NO
```

Four concepts remain separate:

- Recorded shared instants are UTC and come from the injected application
  clock for local evidence/status, or the database clock for accepted shared
  truth.
- User-facing instant display conversion belongs only to presentation. Device
  local display is allowed; a date-only business value is never shifted by
  timezone conversion.
- Causal/conflict order uses entity versions, ledger sequence, or a future
  server cursor. Neither client nor server wall-clock timestamps are a total
  order.
- Server-authoritative time is the `timestamptz` returned from the committing
  database transaction. The client may record send/receive time but cannot
  replace it.

The implementation introduces a general `ApplicationClock`, constructed once
by the composition root and fakeable in tests. It replaces direct system-time
creation only in the current distributed attempt/projection boundary. The 162
legacy `DateTime.now()` calls are an inventory, not a repository-wide rewrite
authorization.

For the current product contract, business dates are interpreted in the IANA
zone `Africa/Cairo`. The two server RPCs must validate “future date” using
`timezone('Africa/Cairo', clock_timestamp())::date`, not an unqualified
session `current_date`. A future versioned business-timezone setting may
replace the fixed v1 policy, but no such setting is invented here.

## N. Tombstone / Deletion Contract

This owner stabilizes deletion semantics because transport cannot safely infer
deletion from a missing row.

```text
DeletionMetadata
  deleted = true
  deletionVersion = EntityVersion
  deletedAtUtc = authoritative server instant
  deletedByAuthUserId
  deletedByDeviceId
  sourceOperationId
```

Deletion of a mutable synchronized entity is a server-accepted semantic
mutation and increments its entity version. The tombstone preserves identity,
tenant and scope alongside the metadata above. Restoration, where the domain
permits it, is a new higher version and does not erase deletion history.
Physical removal is forbidden until later server cursor/retention/compaction
policy proves every required consumer can no longer miss the tombstone.

Current `isActive`, cancellations, voids, and financial reversals retain their
domain meanings and are not converted into tombstones. This owner defines the
value/serialization contract only. It does not create tombstone tables,
transport, retention, merge, or reconciliation behavior.

## O. Composition / DI Ownership

`AppCompositionRoot` remains the sole production construction authority. The
future initialization order is:

1. initialize the existing local database/repository graph;
2. load or first-provision the installation `DeviceIdentity`;
3. construct one `ApplicationClock` and one injected `SessionIdGenerator`;
4. construct one atomic `ExecutionContextProvider`;
5. connect local auth and the optional cloud session/membership adapter to that
   provider;
6. pass the same provider, device identity, and clock through immutable
   `ApplicationRuntimeDependencies` to handlers and compatibility views;
7. expose `ApplicationBoundary` only after valid device identity is available.

Handlers receive explicit dependencies and requests carry captured context.
They do not read environment variables, static globals, files, or Supabase
directly. UI may capture current context to create a request; it does not
construct identity or choose fallback scope.

## P. Schema / Migration Implications

```text
FUTURE_SCHEMA_MIGRATION = REQUIRED
CURRENT_SESSION_SQL_CHANGE = NO
CURRENT_SESSION_DRIFT_SCHEMA_CHANGE = NO
FUTURE_DRIFT_SCHEMA_CHANGE_FOR_THIS_OWNER = NO
FUTURE_GENERATED_DRIFT_CHANGE_FOR_THIS_OWNER = NO
```

The future implementation must create one normal Supabase migration through
the repository's migration tooling. Its bounded purpose is to replace the
existing `post_expense_v1` and `post_internal_transfer_v1` function bodies so
their future-date validation uses the frozen Cairo business-date expression.
Function signatures, receipts, tables, RLS, grants, command schema version,
and successful-result shapes remain compatible. Existing data requires no
backfill.

No table or column addition is required for the owner-3 application contract.
`DeviceIdentity` is installation-profile state, not business-database state.
Warehouse provisioning is absent because no current operation is genuinely
warehouse scoped. Entity-version and tombstone columns are added only by the
later owner of the first mutable synchronized entity/vertical slice, using the
types and rules frozen here. The actual migration timestamp/number and SQL are
left to the separately authorized implementation session.

## Q. Backward-Compatibility Strategy

- Existing server `business_id` values, membership/RLS logic, command payloads,
  fingerprints, attempt JSON, receipts, and result envelopes remain valid.
- Current expense and internal-transfer commands remain explicitly
  business-wide and retain schema version 1. Device identity is captured in
  execution context now; adding it to a future transport/payload requires a
  versioned server contract and is not smuggled into v1.
- Local-only auth and workflows continue without a cloud business context,
  network, or Supabase. They gain device identity infrastructure but do not
  gain fabricated distributed authority.
- `BusinessIdentity` JSON and logo storage remain unchanged and continue to
  drive branding.
- Existing local IDs are not rewritten. Import/mapping later records their
  legacy source identity separately from server UUID identity.
- Current local timestamps are not bulk-converted. Only shared/distributed
  boundary values adopt the new clock/UTC invariant; historical business dates
  preserve their date semantics.
- Read-query migrations, repository sharing, app-shell controller ownership,
  and the two completed server-authoritative command boundaries remain intact.

## R. Future Implementation Touch-Set

This forecast is permission only for a later separately authorized
implementation session.

| Class | Path/component | Reason | Expected change category | Contract implemented | Kind | Dependency |
| --- | --- | --- | --- | --- | --- | --- |
| REQUIRED | `lib/application/identity/distributed_identity.dart` (new) | Validated `BusinessId`, `WarehouseId`, `DeviceId`, `SessionId`, actor types | New value objects/serialization | Identity formats and distinctions | Production | `uuid` already present |
| REQUIRED | `lib/application/context/business_context.dart` | Own canonical tenant, explicit scope, membership evidence | Refactor contract/provider compatibility view | Tenant and warehouse scope | Production | Identity types |
| REQUIRED | `lib/application/context/session_context.dart` | Separate local/remote actor and session lifecycle | Refactor synchronizer/context | Session/audit identity | Production | Identity types, session generator |
| REQUIRED | `lib/application/context/execution_context.dart` (new) | Publish session/business/device atomically | New aggregate, factory, provider | Cross-context invariants | Production | Both contexts and device |
| REQUIRED | `lib/application/distributed_state/distributed_record_metadata.dart` (new) | Implement `EntityVersion`, authoritative mutation metadata, and `DeletionMetadata` | New value/serialization contracts | Version and tombstone semantics | Production | Identity types and UTC invariant |
| REQUIRED | `lib/application/time/application_clock.dart` (new) | One UTC clock seam | New port/system implementation | Local recorded time | Production | None |
| REQUIRED | `lib/application/identity/device_identity_store.dart` (new) | Abstract load/provision/reprovision | New application port/service | Device lifecycle/test seam | Production | Identity types |
| REQUIRED | `lib/infrastructure/local/file_device_identity_store.dart` (new) | Versioned atomic installation-profile persistence | New file adapter | Restart stability/fail closed | Production | Device port; no new package |
| REQUIRED | `lib/infrastructure/supabase/supabase_cloud_session_adapter.dart` | Build/clear one atomic context | Adapter refactor | Verified membership/session invariant | Production | Execution provider |
| REQUIRED | `lib/composition/app_composition_root.dart` | Provision device and construct clock/context once | Composition wiring | DI ownership/init order | Production | All new ports/adapters |
| REQUIRED | `lib/application/application_dependencies.dart` | Expose atomic provider, device and clock; derive old views | Dependency bundle refactor | Explicit propagation | Production | Composition types |
| REQUIRED | `lib/composition/legacy_application_dependency_bridge.dart` | Preserve shared-instance compatibility | Bridge signature/wiring | Backward compatibility | Production | Runtime dependencies |
| REQUIRED | `lib/application/commands/application_command.dart` | Carry captured `ExecutionContext` for scoped commands | Request contract extension with compatible optionality for unscoped commands | Request invariant | Production | Execution context |
| REQUIRED | `lib/application/commands/post_expense_command.dart` | Consume one context and require `BusinessWide` | Handler validation refactor only | Tenant/session/device/scope invariant | Production | Request/provider |
| REQUIRED | `lib/application/commands/post_internal_transfer_command.dart` | Consume one context and require owner + `BusinessWide` | Handler validation refactor only | Same invariant and role | Production | Request/provider |
| REQUIRED | `lib/features/expenses/expenses_screen.dart` | Capture the root-owned execution context | Narrow call-site update | Explicit context propagation | Production/UI call-site only | Request contract |
| REQUIRED | `lib/features/financial_accounts/financial_transfers_screen.dart` | Capture context for new and restored requests | Narrow call-site/recovery update | Explicit context propagation | Production/UI call-site only | Request contract |
| REQUIRED | `lib/core/expenses/drift_expense_posting_attempt_store.dart` | Remove direct system UTC call | Inject/use `ApplicationClock` | Controllable local evidence time | Production | Clock |
| REQUIRED | `lib/core/expenses/drift_confirmed_expense_projection_writer.dart` | Remove distributed-boundary direct system UTC call | Inject/use clock | Controllable projection status time | Production | Clock |
| REQUIRED | `lib/core/financial_accounts/drift_internal_transfer_posting_attempt_store.dart` | Remove direct system UTC call | Inject/use clock | Controllable local evidence time | Production | Clock |
| REQUIRED | `lib/core/financial_accounts/drift_confirmed_internal_transfer_projection_writer.dart` | Remove distributed-boundary direct system UTC call | Inject/use clock | Controllable projection status time | Production | Clock |
| REQUIRED | `supabase/migrations/<generated>_freeze_business_date_timezone.sql` | Freeze Cairo evaluation in both current RPCs | Function-only migration | Business-date authority | SQL/migration | Create with Supabase CLI; no table backfill |
| REQUIRED | `test/distributed_identity_scope_time_contract_test.dart` (new) | Focused contract acceptance | Unit/composition/file tests | All owner-3 contracts | Test | Production touch set |
| REQUIRED | `test/phase108g_session_business_context_boundary_test.dart` | Preserve and update earlier context invariants | Focused regression update | No fabricated business identity; atomic lifecycle | Test | Context refactor |
| REQUIRED | `test/phase108e_application_boundary_composition_root_test.dart` and `test/phase108h_app_shell_runtime_ownership_test.dart` | Preserve root/shared ownership | Focused regression update | Composition compatibility | Test | Root changes |
| REQUIRED | `test/phase108j_post_expense_command_test.dart` and `test/post_internal_transfer_command_test.dart` | Preserve command behavior while changing context/clock injection | Focused regression updates | Existing command parity | Test | Handler/store changes |
| REQUIRED | `test/phase108j_expense_ui_integration_test.dart`, `test/phase108j_expense_projection_test.dart`, `test/internal_transfer_ui_integration_test.dart`, and `test/internal_transfer_projection_test.dart` | Preserve exact UI/projection adoption and idempotency | Focused regression updates | Existing command parity | Test | Call-site/store changes |
| REQUIRED | `supabase/tests/phase_108j_post_expense_test.sql` and `supabase/tests/post_internal_transfer_test.sql` | Prove Cairo boundary and unchanged RPC behavior | Focused SQL tests | Server business-date authority | Test/SQL test | Function migration |
| LIKELY | `lib/main.dart` | Only if initialization error presentation must distinguish corrupt device identity | Narrow bootstrap error mapping | Fail-closed provisioning | Production | Root behavior |
| LIKELY | `test/confirmed_expense_list_application_query_migration_test.dart` | It constructs the full runtime and may require new injected seams | Fixture-only regression update | Composition compatibility | Test | Root changes |
| OPTIONAL | `docs` API comments near `BusinessIdentity` | Clarify branding/profile terminology | Comment-only clarification | Vocabulary | Documentation | No runtime effect |
| EXCLUDED | `lib/core/persistence/foundation_database.dart`, generated `.g.dart`, `migration_strategy.dart` | No local schema is needed | No change | Scope boundary | Schema/generated | N/A |
| EXCLUDED | Other repositories/controllers/screens and all additional queries/commands | Repository-wide clock/context sweep is not atomic | No change | Scope boundary | Production/test | N/A |
| EXCLUDED | Outbox, inbox, sync, conflict, catalog, recovery, trial, licensing components | Later owners | No change | Owner boundary | All | N/A |

## S. Future Test / Acceptance Gates

Focused tests must prove:

1. `BusinessId`, `WarehouseId`, `DeviceId`, and `SessionId` accept only their
   frozen formats and serialize canonically.
2. `business_id` is the only tenant identifier; `BusinessIdentity` never
   supplies it.
3. atomic context construction rejects membership/session actor mismatch,
   tenant/warehouse mismatch, missing distributed scope, and an unverified
   remote membership.
4. current financial commands accept only explicit `BusinessWide` context,
   reject stale/different active session or business context, and preserve all
   existing success/failure/idempotency behavior.
5. local authentication creates local-only session context and never a tenant
   or warehouse.
6. device ID is generated once with an injected generator, persists across
   ordinary store/root restart, does not regenerate on read, is independent of
   session/tenant/database, is excluded from business backup, and fails closed
   on corrupt or unwritable state.
7. explicit reprovision creates a different ID; no automatic path calls it.
8. `EntityVersion` initializes at 1, advances exactly one step for authoritative
   update/delete/restore examples, rejects zero/negative/overflow, and never
   derives order from timestamps or device IDs.
9. deletion metadata requires deletion version, UTC server time, actor, device,
   and operation ID; cancellation/void examples remain non-tombstones.
10. fake `ApplicationClock` controls attempt/projection timestamps and all
    persisted shared instants are UTC.
11. UI conversion does not mutate stored instants or date-only business values.
12. SQL tests straddle Cairo midnight and prove both RPCs use Cairo business
    date while still returning database-clock UTC acceptance timestamps.
13. existing local-first workflows, settings/profile, auth, database reopen,
    completed application queries, expense command, internal-transfer command,
    and projection idempotency regressions pass without network/Supabase.

Validation for the later implementation:

```text
focused Dart unit/widget/integration suites = REQUIRED
focused Supabase SQL command suites = REQUIRED
dart format on touched Dart files = REQUIRED
flutter analyze = REQUIRED
relevant completed-query and financial-command regressions = REQUIRED
full flutter test = REQUIRED because runtime dependencies and two commands change
git diff --check = REQUIRED
schema diff confirms one CLI-created Supabase migration and no Drift schema = REQUIRED
```

This planning session runs none of those implementation gates; its mandatory
validation is documentation delta validation only.

## T. Durable-Sync Handoff Gates

Workstream 4 may start only after the owner-3 implementation proves:

```text
1. BusinessId/business_id is the sole canonical tenant identity.
2. BusinessScope is always explicit for distributed work.
3. DeviceId is valid, persisted, restart-stable, and available before writes.
4. Session/business/device context is constructed and replaced atomically.
5. Local and remote actor identities are not conflated.
6. EntityVersion type, scope, authority, and increment rule are implemented.
7. Shared instant and business-date semantics are implemented and tested.
8. Semantic deletion metadata is implemented as a stable contract.
9. Clock, device generator/store, and context provider have deterministic tests.
10. Existing local-first and server-command behavior remains compatible.
```

Workstream 4 still exclusively owns:

```text
outbox storage
inbox storage
delivery and retry state
leases and scheduling
transport deduplication behavior
server cursor persistence
conflict-state persistence
merge/conflict processing
remote tombstone transport
retention/compaction execution
sync scheduling/background sync
remote transport and reconciliation
pending-work guard integration for device reprovision
```

It consumes the context snapshot, `EntityVersion`, time, and deletion
contracts; it does not rename the tenant, invent fallback warehouse scope,
regenerate device identity, or use timestamps as causal order.

## U. Explicit Exclusions

This planning session does not authorize or perform:

```text
DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION
CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE
RECOVERY_TRIAL_AND_LICENSING_BOUNDARY

additional application-query migrations
Customer Collection
Supplier Payment
Purchase Intake
financial reversals

Supabase runtime
remote synchronization
network transport
background sync
conflict-resolution engine
sync queue persistence
licensing/trial/recovery runtime
catalog vertical slice

production implementation
test implementation
SQL/schema/migration changes
dependency/generated/UI/controller/repository/service changes
```

Completed work remains closed:

```text
DO NOT REOPEN Internal Transfer
DO NOT REOPEN Logo Query Migration
DO NOT REOPEN Confirmed Expense List Application Query Migration
```

## V. Risks / Open Findings

The following are bounded implementation risks, not unresolved policy:

- The local branding type is still named `BusinessIdentity`; the canonical
  decision prevents it from being used as tenant identity without requiring a
  broad rename.
- The repository has no warehouse data. Explicit `BusinessWide` preserves
  current commands, while the first warehouse vertical slice must obtain a
  real server UUID and cannot default one.
- A copied whole installation profile can copy its device file. The contract
  requires explicit reprovision for a cloned profile; automatic clone
  detection is not claimed.
- The current cloud adapter and local auth controller represent different
  identity systems. The target keeps their IDs distinct and makes no unproven
  account-link assertion.
- Cairo is intentionally the v1 business timezone. Multi-timezone tenant
  settings require a later versioned setting and server migration, not an
  implementation-time choice.
- Entity-version/tombstone storage is absent. This is intentional: the contract
  becomes stable here; the owning mutable-entity vertical slice adds its
  columns before synchronization of that entity is allowed.
- The repository has 162 direct system-clock calls. Only the distributed
  boundary touch set is in scope; broad clock migration remains separately
  governed.

No material architectural decision is left for the implementation agent.

## W. Implementation Readiness Decision

All twelve readiness conditions are resolved: tenant semantics, context
ownership, warehouse invariant, device lifecycle, version semantics, time
authority, deletion responsibility, migration implication, bounded touch set,
test gates, durable-sync handoff, and implementation policy.

```text
IMPLEMENTATION_READY_FOR_NEXT_SESSION = YES
NEXT_SESSION_AUTHORIZED =
IMPLEMENTATION_OF_DISTRIBUTED_IDENTITY_SCOPE_TIME_CONTRACT_COMPLETION
IMPLEMENTATION_AUTHORIZED_THIS_SESSION = NO
```

## X. Commit / Push Evidence Contract

Before commit, the only allowed delta is this artifact. Required observed
classification:

```text
DOCUMENTATION_FILES_CHANGED = 1
PRODUCTION_FILES_CHANGED = 0
TEST_FILES_CHANGED = 0
SQL_FILES_CHANGED = 0
SCHEMA_FILES_CHANGED = 0
MIGRATIONS_CHANGED = 0
SUPABASE_FILES_CHANGED = 0
GENERATED_FILES_CHANGED = 0
DEPENDENCY_FILES_CHANGED = 0
UI_FILES_CHANGED = 0
```

Create exactly one normal commit with subject
`docs: plan distributed identity scope time contracts` and parent
`8e675b2545d4388f8624b746f643188ce8c88598`. Stage only this exact path and
push normally to
`origin/codex/phase-108h-app-shell-runtime-ownership-boundary`. Amend, rebase,
squash, force, and force-with-lease are forbidden.

The containing commit cannot embed its own stable commit/tree/blob evidence
after creation without producing another commit. Actual observed commit and
push identities are therefore recorded in the final forensic report, not
guessed in this pre-commit artifact.

## Y. Final Remote-Lock Proof Contract

After push, a fresh fetch and independent `ls-remote` must prove:

```text
FINAL_LOCAL_HEAD = FINAL_TRACKING_HEAD = FINAL_DIRECT_REMOTE_HEAD
FINAL_MERGE_BASE = FINAL_LOCAL_HEAD
FINAL_AHEAD = 0
FINAL_BEHIND = 0
WORKTREE = CLEAN
INDEX = CLEAN
STASH = EMPTY
ACTIVE_GIT_OPERATION = NONE
INDEX_LOCK = ABSENT
git diff --check = PASS
```

The actual hashes/counts belong in the final forensic report. A failed push,
force requirement, or unavailable direct proof fails closed.

## Z. Next-Session Authorization

```text
PLANNING_COMPLETE = YES
IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED_THIS_SESSION = NO
IMPLEMENTATION_READY_FOR_NEXT_SESSION = YES
NEXT_SESSION_AUTHORIZED =
IMPLEMENTATION_OF_DISTRIBUTED_IDENTITY_SCOPE_TIME_CONTRACT_COMPLETION
LATER_WORKSTREAM_IMPLEMENTATION_AUTHORIZED = NO
STOP_AFTER_PLANNING_REMOTE_LOCK = YES
```
