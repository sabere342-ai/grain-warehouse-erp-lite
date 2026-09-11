# Cloud Hybrid Product Catalog Vertical Slice — Implementation Plan

## A. Authority and baseline

```text
PLAN = CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE
SESSION_CLASS = PLANNING_ONLY
IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED_THIS_SESSION = NO
```

This plan is governed by the following independently verified committed chain:

```text
DECISION_COMMIT = 128642e0abf028007373e3a817ed84355c6e800e
DECISION_PARENT = 3f24a66db38022e57b864de68f401e15aa1445b7
DECISION_TREE = c75c77e12f833f8402d67b6f82178789c7e00c8f
DECISION_ARTIFACT = docs/POST_DURABLE_OUTBOX_INBOX_AND_CONFLICT_STATE_FOUNDATION_SUCCESSOR_AUTHORITY_DETERMINATION.md
DECISION_ARTIFACT_BLOB = f1ae6152ce63b77d2f03873662ebaabd7daaaf01
ORDER_AUTHORITY_COMMIT = a5f57c709e1b7e9b3f50d8ae4811951220edf2a6
ORDER_AUTHORITY_ARTIFACT = docs/OWNER-ROADMAP-ORDER-AFTER-LOGO-QUERY-MIGRATION-PROGRAM-COMPLETION.md
ORDER_AUTHORITY_ARTIFACT_BLOB = fe6ce13f20557e23fefc9f83916f8fbe3ee29c64
```

The owner order places this workstream fifth, immediately after the completed
durable outbox/inbox/conflict/checkpoint foundation. Commit `128642e...`
selects this workstream alone and authorizes planning only. The implementation
session must start from the remote-locked planning commit and repeat repository
and authority forensics before changing code.

The completed predecessor is consumed, not redesigned. Its four tables,
claims, leases, replay rules, fingerprints, acknowledgements, inbox dedupe,
conflicts, checkpoints, scope isolation, causal metadata, and crash recovery
remain canonical.

## B. Repository discovery

The current repository was inspected rather than inferred from names.

### Product model and writes

- `Product` has local string `id`, name, optional code, grain unit, active
  state, three optional piaster-per-kilogram price fields, notes, and local
  creation/update times.
- `ProductDraft` supplies those editable descriptive and price fields.
- `ProductRepository` supports list, create, update, and set-active. It has no
  delete command.
- Both in-memory and Drift implementations enforce globally normalized name
  and optional-code uniqueness. Drift IDs are local `prd-...` identifiers.
- `code` is explicitly not defined as a barcode. There is no SKU or barcode
  identity contract to reuse.
- Current authorization is the local `canManageProducts` permission; current
  product UI exposes management to the owner-facing role.

### Product reads and relationships

- `ProductCatalogReadRepository` is the established read boundary used by the
  application query and downstream inventory, reporting, backup, and business
  services.
- `LoadProductCatalogQueryHandler` returns a complete local snapshot with
  `LocalQueryResultMetadata`. The metadata hierarchy was deliberately left
  extensible for later cloud consistency semantics.
- `DriftProductCatalogReadRepository` reads SQLite only, orders by creation
  time then ID, and optionally filters inactive products.
- `ProductsScreen` obtains the read query through `ApplicationScope` but still
  obtains the write repository through the legacy static bridge.
- Inventory, valuation, purchases, sales, and other records retain the local
  product ID. A synchronized identity must not rewrite those historical
  references.

### Local schema

- `Products` contains no business scope, remote ID, entity version,
  acknowledged snapshot, tombstone, pending operation, or sync disposition.
- `FoundationDatabase.schemaVersion` is `18`.
- Product normalized name and normalized code are globally unique in the
  device database. Current runtime supports one selected remote business, so
  the first slice can preserve those stronger local constraints while server
  uniqueness is scoped by business.

### Application/cloud composition

- `AppCompositionRoot` already creates one shared `FoundationDatabase`, one
  `DriftDurableSyncStore`, a persisted UUIDv4 device identity, execution
  context providers, and optional Supabase adapters.
- `SupabaseCloudSessionAdapter` constructs a verified business-wide context
  only from a live authenticated session and exactly one active membership.
  It currently clears context when membership resolution fails; it does not
  provide a durable offline membership/scope cache.
- Provider-neutral application gateways already exist for financial RPCs;
  Supabase types remain in infrastructure adapters.
- The runtime already depends on Drift, `crypto`, `uuid`, and
  `supabase_flutter`. No connectivity, sync, or database dependency is needed.

### Server and tests

- Existing Supabase migrations establish `businesses`, active memberships,
  server-authoritative financial RPCs, receipts, RLS, least-privilege grants,
  and pgTAP tests.
- The established write pattern is a public security-invoker wrapper over a
  private security-definer core with `search_path = ''`, fully qualified
  objects, explicit authentication/membership/role checks, replay receipts,
  and narrow execute grants.
- There is no server product table, product command RPC, change stream, or
  product pull API today.
- Current Supabase guidance requires explicit RLS plus grants and policy tests;
  current platform changes also mean implementation must not assume that a new
  public table is automatically exposed through the Data API.

## C. Current architecture

```text
ProductsScreen
  -> LoadProductCatalogQueryHandler
      -> ProductCatalogReadRepository
          -> Drift Products table

ProductsScreen
  -> ProductController
      -> ProductRepository
          -> Drift Products table

AppCompositionRoot
  -> ExecutionContext / DeviceIdentity / ApplicationClock
  -> one DriftDurableSyncStore
      -> durable_outbox_operations
      -> durable_inbox_operations
      -> durable_conflicts
      -> durable_sync_checkpoints
  -> optional provider-specific Supabase gateways
```

The correct extension is therefore a local-first product application service
and product-specific projector/coordinator around the existing repository and
durable store. Widgets must not select a local or remote implementation, and
the remote response must never bypass the local projection to become UI state.

## D. Problem statement

The product catalog is operationally useful offline but is device-local. It
cannot converge across devices, prove remote authority, reject stale writers,
preserve tombstones, or recover an unknown remote result. The durable generic
state machine now exists, but no product command/pull protocol or product
projection metadata consumes it.

The smallest production-complete proof must make the existing product
create/update/set-active path local-first and durably synchronized for one
verified business, provide an authoritative server row and ordered pull feed,
surface pending/stale/conflict truth, and recover across process crashes. It
must not become a general ERP synchronization platform.

## E. Scope

### IN_SCOPE

1. All existing synchronized product fields: name, optional code, unit,
   `isActive`, default sale price, minimum sale price, reference cost, and
   notes.
2. A distinct remote product UUID and a preserved local product ID.
3. A business-wide product scope for the one verified active business.
4. Local product mutation plus a durable outbound operation in one Drift
   transaction.
5. Supabase product schema, receipts, ordered change feed, RLS/grants, and
   version-checked create/update/set-active RPC.
6. Bounded push, acknowledgement projection/repair, bounded pull, inbox
   receipt/apply, checkpoint advancement, and restart recovery.
7. Entity-specific conflict detection and explicit owner resolution by
   accepting the server or resubmitting the local candidate against the
   observed server version.
8. Product catalog query metadata and UI state for local-only, pending,
   acknowledged/stale, attention-required, and tombstoned records.
9. An explicit, product-only adoption flow for legacy local products.
10. Focused application, Drift, Supabase, widget, integration, and regression
    tests.

### OUT_OF_SCOPE

- Synchronizing inventory, purchases, sales, parties, accounts, financial
  commands, reports, documents, settings, users, or any other entity.
- A generic dispatcher, background service, Android background execution,
  periodic scheduler, push notification, or full Realtime replication.
- Barcode/SKU introduction, product images, price history, or warehouse-level
  product overrides.
- Direct client writes to product/change/receipt tables.
- Automatic field-level or last-write-wins merge.
- Normal hard deletion of products or deletion of referenced local rows.
- Multi-business profile switching on one local database.
- Recovery export, retention/compaction, owner data-wipe redesign, trial,
  licensing, deployment, or production rollout.

### DEFERRED

- Realtime may later be an invalidation hint only; the ordered cursor remains
  authoritative.
- General worker scheduling, telemetry, attempt-history analytics, and remote
  device registration/revocation.
- Tombstone origination through governed administration. This slice accepts
  and preserves server tombstones but adds no ordinary product-delete UI.
- Multi-business local partitioning and replacement of the current globally
  unique local natural-key constraints.
- Durable pending-work export, cache reset/wipe guards, and evidence retention
  belong to the ordered recovery/trial/licensing successor.

## F. Non-goals

The implementation is not a full cloud migration, not an online-only rewrite,
not a repository-wide architecture refactor, and not a license/recovery
program. It must not move Supabase types into domain/application code, replace
the existing durable tables, turn local wall time into a version, or silently
upload all legacy data on sign-in.

## G. Cloud-hybrid semantic contract

```text
LOCAL_FIRST = SQLite is the sole UI/read authority and accepts eligible writes offline.
REMOTE_AUTHORITY = Supabase is authoritative for cross-device entity version and accepted shared state.
READ_CONVERGENCE = Remote changes become visible only after durable inbox apply to SQLite.
WRITE_CONVERGENCE = Local writes are provisional until a server acknowledgement is projected.
NO_CLIENT_CLOCK_CAUSAL_AUTHORITY = server entity_version and ordered cursor decide causality.
NO_SILENT_PAYLOAD_LOSS = every rejected concurrency case preserves both payloads.
NO_SILENT_TOMBSTONE_LOSS = deletion evidence is never inferred from absence or overwritten.
```

The local product row is current device presentation state. For an
acknowledged row it matches the last accepted server snapshot. For a pending
row it contains the provisional local candidate, while the sync-state sidecar
retains the last acknowledged payload and version. The server row is the
shared-state authority, but it cannot erase a pending local candidate without
durable conflict evidence.

## H. Product identity and scope

### Identity

- Keep `products.id` as the local relationship identity. Existing `prd-...`
  IDs and all inventory/history links remain unchanged.
- Add a canonical `remote_product_id` UUID in sync metadata. New cloud-created
  products use the same UUID text for both local and remote IDs; adopted legacy
  products keep their local ID and receive a separate remote UUID.
- The durable aggregate is `aggregate_type = 'product'` and
  `aggregate_id = remote_product_id`.
- Display name, normalized name, code, and normalized code are natural-key
  constraints, never durable identity. `code` remains an optional product
  code, not a barcode.

### Scope

- Product scope is exactly `DurableScope.businessWide(businessId)`; no
  warehouse or fabricated default warehouse is allowed.
- The server derives the actor from `auth.uid()` and rechecks the supplied
  business against an active membership. A payload business ID is routing
  input, not authority.
- Reads are allowed to active owner/employee/viewer memberships. Mutations and
  legacy adoption require an active owner membership, matching current product
  management semantics.
- A product-only durable scope binding stores the last successfully verified
  business ID, remote auth user ID, role, and verification time. Offline writes
  are allowed only when the persisted Supabase session has the same auth user
  and that binding is owner-qualified. Server rejection after offline role
  revocation becomes durable attention-required state.
- If there is no binding, a different user, multiple/ambiguous memberships, or
  a different business, reads remain available but cloud-bound writes and sync
  fail closed. A build with no Supabase configuration retains existing purely
  local behavior and creates no outbox rows.
- This slice supports one active remote business per local database. It must
  refuse a second binding instead of crossing scopes.

## I. Local-first behavior

| Event | Required behavior |
| --- | --- |
| Online create/update/set-active | Commit local candidate and outbox atomically, return success immediately, then request one bounded sync pass. |
| Offline with valid bound scope | Same local commit; show pending/offline state; retry on a later foreground trigger. |
| Network interruption/timeout | Preserve claim/retry state. Never roll back the committed local candidate or invent failure authority. |
| Remote unavailable | Apply deterministic retry classification/backoff already represented by the outbox; ordinary local reads continue. |
| App restart | Open SQLite, recover expired claims, repair acknowledged-pending-apply rows, then run a bounded push/pull only if remote context verifies. |
| Operation replay | Same identity/fingerprint returns the stored server result; changed payload is a durable idempotency conflict. |
| Two-device edit | Exact base-version match wins; the stale writer retains local and remote snapshots in `durable_conflicts`. |
| Remote tombstone | If no local pending edit, hide the product and persist tombstone metadata; with a pending edit, record delete-vs-update conflict. |
| Local delete | There is no normal delete command. Deactivate is a versioned update. Cache wipe is not a cloud delete and remains governed later. |

Only one unresolved product mutation may exist per product. While its outbox
row is pending, claimed, retry-wait, acknowledged-pending-apply, conflict, or
permanent-failure, ordinary edit/toggle actions are disabled. This avoids
creating a second mutation with a stale base version and keeps the first slice
causally exact. Different products may synchronize independently.

Catalog read metadata is extended with:

```text
source = local
consistency = currentKnownState
cloudDisposition = localOnly | pending | acknowledged | attentionRequired
lastSuccessfulPullAtUtc = nullable
isStale = true when cloud-bound and no successful pull exists or the last pull is older than the displayed policy threshold
```

Staleness is presentation/operational metadata only. It never changes entity
version or resolves conflicts. Tombstoned rows are excluded from all ordinary
product reads, even when inactive rows are requested.

## J. Outbound synchronization

### Operation contract

Use the existing `DurableOutboxEnvelope` with:

```text
operation_kind = product.create.v1 | product.update.v1 | product.setActive.v1
idempotency_key = operation_id
scope = businessWide(business_id)
aggregate_type = product
aggregate_id = remote_product_id
payload_schema_version = 1
base_entity_version = null for create; required positive acknowledged version otherwise
deletion_metadata = null
business_date = null
causal_predecessor_operation_id = null in this single-pending-operation slice
```

The canonical payload contains exactly:

```text
schemaVersion
mutationKind
remoteProductId
legacyLocalId (nullable)
name
code (nullable)
unit = kilogram | ton
isActive
defaultSalePricePiastersPerKg (nullable positive bigint)
minimumSalePricePiastersPerKg (nullable positive bigint)
referenceCostPricePiastersPerKg (nullable positive bigint)
notes (nullable normalized text)
```

Business, scope, actor, device, operation ID, base version, and operational UTC
time remain envelope fields. Serialize with the predecessor canonical JSON and
SHA-256 fingerprint utility. Null and trimmed-string rules must be shared by
local serializer tests and server fingerprint fixtures.

### Local composition

`CloudHybridProductRepository` decorates the existing Drift repository. In
cloud-bound mode, each command calls `enqueueWithMutation` once. The mutation
validates the draft, changes/inserts `products`, creates or updates its sync
metadata with the pending operation ID while preserving the acknowledged
snapshot, and the coordinator inserts the outbox envelope. Any failure rolls
back all of those writes. Local-only mode delegates unchanged.

### Push transport and outcomes

Introduce provider-neutral application contracts such as
`ProductCatalogPushGateway.push(ProductCatalogPushRequest)` returning the
sealed outcomes `accepted`, `versionConflict`, `permanentFailure`, or
`retryableFailure`. `SupabaseProductCatalogPushGateway` is the only class that
uses `SupabaseClient` and calls `apply_product_catalog_operation_v1`.

The server acknowledgement contains the canonical complete product snapshot,
accepted `entityVersion`, source operation ID, actor/device provenance,
`serverModifiedAtUtc`, change cursor, result fingerprint, and `replayed`.

- Retryable transport/server failures call the existing retry transition with
  stable category/code and backoff.
- Validation/auth/scope failures become permanent-failure plus
  attention-required product state; the provisional candidate stays visible.
- Version/natural-key/delete-vs-update outcomes call the existing durable
  conflict transition with both canonical payloads and remote metadata.
- Accepted/replayed outcomes first persist acknowledgement result in the
  outbox, then enter the acknowledgement repair transaction described below.

## K. Inbound synchronization

### Pull contract

Introduce `ProductCatalogPullGateway.pull` with business scope, exclusive
`afterCursor`, and limit. The Supabase adapter calls
`pull_product_catalog_changes_v1`. The server returns changes ordered strictly
by monotonically increasing `change_cursor`, each with a full canonical
snapshot (including the last business fields on a tombstone), version,
fingerprint, actor/device/source-operation provenance, server UTC time, and
cursor.

Use constants:

```text
PULL_PAGE_SIZE = 100
MAX_PULL_PAGES_PER_SYNC_PASS = 5
MAX_OUTBOUND_OPERATIONS_PER_SYNC_PASS = 25
```

These are bounded foreground fairness limits, not retention rules. Another
manual/open/resume trigger continues from the committed checkpoint.

### Receive and apply

For every returned change:

1. Convert it to `DurableInboxEnvelope` with
   `source_authority = 'supabase.product_catalog.v1'`, the server source
   operation ID, exact business-wide scope, aggregate product identity,
   version/deletion metadata, payload, and fingerprint.
2. Include `changeCursor` in the versioned product change payload so it is
   recoverable after receipt; never keep an uncommitted page cursor only in
   memory.
3. Call `receive`; exact duplicate delivery is a no-op and changed content for
   the same source identity is rejected.
4. Claim and apply through `applyInbound`, which mutates/inserts the local
   product and sync metadata, marks the inbox row applied, and advances the
   product checkpoint in one `FoundationDatabase.inTransaction`.

An unknown remote live product is inserted locally with
`products.id = remote_product_id`. An adopted product is found by sync
metadata, never by name. A full-payload tombstone for an unknown product may be
stored as a hidden local row plus tombstoned sync metadata so later stale
events cannot resurrect it.

## L. Version and tombstone semantics

### Versions

- Server `entity_version` is a positive signed 64-bit integer and starts at 1.
- Create requires no existing remote product and a null base version.
- Update/set-active requires `baseEntityVersion == current entity_version`.
- Each accepted mutation increments exactly once and emits exactly one change.
- Remote version, not timestamps, decides newer/equal/stale order.
- `updatedAt` remains local presentation/audit time; server modified UTC is
  stored separately. Cairo business date does not participate in products.

Inbound comparison:

| Remote vs acknowledged local | Result |
| --- | --- |
| Higher, no pending local mutation | Apply full snapshot and version. |
| Equal and same fingerprint | Idempotent apply/advance. |
| Equal and different fingerprint | `payloadMismatchAtSameVersion` conflict. |
| Lower | Treat as already superseded only when ordered cursor/provenance proves it; mark inbox applied and advance without changing product. Otherwise conflict fail-closed. |
| Any version with pending local candidate from another operation | Preserve provisional row and record version/delete conflict; do not overwrite it. |

### Tombstones

`isActive = false` means business deactivation and is an ordinary synchronized
field. It is not deletion. Server products additionally retain
`is_deleted`, deletion version, UTC time, actor, device, and source operation.
A deletion increments entity version and emits a full-payload tombstone. No
hard delete or absence-as-delete is allowed. Restoration, if authorized in a
future workstream, must be an explicit later version; it is not part of this
slice.

This slice adds no public delete RPC. Tests may create a tombstone through a
private/test-authority fixture to prove inbound handling. Normal users stop a
product with set-active. This is the only interpretation consistent with the
current API and committed archive-first policy.

## M. Conflict handling

Use the predecessor `durable_conflicts` row and classifications; do not throw
away business divergence as a generic exception.

Required classifications are:

```text
versionMismatch
payloadMismatchAtSameVersion
deleteVsUpdate
duplicateNaturalKey
acknowledgedProjectionMismatch
reconciliationMismatch
```

V1 performs no automatic field merge, especially for default/minimum sale
price and reference cost. The product card shows attention-required state and
the owner can inspect the local candidate and remote snapshot.

Two explicit resolutions are in scope:

1. **Accept server**: one transaction applies the remote snapshot/tombstone,
   clears the pending link, disposes the old outbox conflict without reposting,
   and marks the durable conflict resolved with a fresh resolution operation
   UUID, resolver auth user, kind `acceptRemote`, and UTC time.
2. **Keep local**: enqueue a fresh operation with a fresh identity and base
   equal to the observed remote version. Leave the conflict unresolved until
   that resolution operation is acknowledged and projected; then mark it
   resolved as `resubmitLocal`. A second collision creates a new conflict and
   preserves the first evidence.

Expose the smallest CAS-backed resolution method needed to populate the
already-existing durable conflict resolution columns. This is consumption of
the predecessor seam, not a schema redesign. Resolution requires the same
business scope, current owner remote identity, unresolved state, expected
record version, and exact linked product/operation.

## N. Checkpoints

There is one business-wide stream:

```text
sourceAuthority = supabase.product_catalog.v1
streamName = product_catalog_changes_v1
cursor = decimal string of the last durably handled server change_cursor
scope = businessWide(businessId)
```

No row means cursor zero. Advance only inside the same transaction that marks
the inbox item applied or durably conflicted. A conflict advances the cursor
because both sides and the inbox link are preserved; otherwise one conflict
would permanently block later catalog changes. Never advance on fetch,
receipt-only, failed apply, or in-memory processing. Cursor order is a delivery
order, not an entity version and not a time.

## O. Crash, retry, and failure behavior

| Failure boundary | Durable result and recovery |
| --- | --- |
| Crash before local transaction commit | Neither product mutation nor outbox exists. |
| Crash after local mutation code but before outbox insert/commit | The shared transaction rolls back both. |
| Crash after local commit | Provisional product and pending outbox survive restart. |
| Network timeout before known server result | Claim expires or enters retry wait; replay same operation/fingerprint. |
| Server committed, client timed out | Receipt returns the exact acknowledgement on replay without a second version/change. |
| Crash after remote acknowledgement but before local acknowledgement persistence | Replay obtains the same receipt and persists it. |
| Crash after acknowledgement persistence but before product projection | Outbox remains `acknowledgedPendingApply`; startup repair applies stored result without transport. |
| Crash during acknowledgement projection | Product/metadata/outbox completion share one local transaction and roll back together. |
| Inbound receipt before apply | Inbox `received` survives; old checkpoint causes harmless exact refetch/dedupe. |
| Crash during inbound mutation before applied marker | Product mutation, inbox applied state, and checkpoint all roll back. |
| Conflict during inbound apply | Conflict row, inbox conflict state, product attention state, and checkpoint commit atomically. |
| Claim owner dies | Existing lease expiry recovery returns the record to eligible work. |
| Duplicate remote delivery | Inbox source identity plus fingerprint dedupes exactly. |
| Same identity, changed payload | Reject and durably classify; never call the product applier with changed content. |

Acknowledgement repair is implemented in a product-specific Drift projector
using the exact same database and durable store. It runs inside
`FoundationDatabase.inTransaction`: verify stored acknowledgement scope,
identity, version, and fingerprint; apply the acknowledged snapshot; clear the
matching pending operation; update acknowledged metadata; resolve any linked
resubmit conflict; and call `completeOutbox`. Nested Drift participation must
be proven by rollback tests. A mismatch records
`acknowledgedProjectionMismatch` and never marks completion.

Retry delays use durable `nextAttemptAtUtc` and the existing attempt counter.
The product coordinator supplies a deterministic capped exponential schedule
with test-injected clock/jitter policy; HTTP/network/5xx and transient Postgres
classes retry, while authentication waits for a newly verified context, and
validation/authorization/idempotency/version failures do not spin. No client
clock orders product versions.

## P. Security and server authority

### Server tables

Create:

1. `public.products` — remote UUID PK, business FK, optional legacy local ID,
   all synchronized fields, normalized natural keys, positive entity version,
   created/server-modified UTC, actor/device/source operation provenance,
   and nullable all-or-none tombstone metadata.
2. `private.product_catalog_operation_receipts` — operation/idempotency
   identity, business, actor, fingerprint, status, and canonical result JSON.
3. `public.product_catalog_changes` — monotonic `bigint generated always as
   identity` cursor, business, product, entity version, operation kind, full
   canonical payload/fingerprint, tombstone and provenance fields.

Constraints and indexes:

```text
products PK (id)
products UNIQUE (business_id, id)
products UNIQUE (business_id, normalized_name)
products UNIQUE (business_id, normalized_code) WHERE normalized_code IS NOT NULL
products CHECK positive prices and minimum <= default
products CHECK entity_version > 0
products CHECK tombstone fields are all null when live and all present/consistent when deleted
receipts PK (operation_id), UNIQUE (idempotency_key), CHECK known state
changes PK (change_cursor), UNIQUE (business_id, source_operation_id)
changes INDEX (business_id, change_cursor)
changes INDEX (business_id, product_id, entity_version)
```

Natural keys remain reserved by tombstoned rows in V1. This prevents an old
offline operation from ambiguously targeting a newly reused name/code.

### Server functions

- `private.apply_product_catalog_operation_v1(...)` performs auth, active
  owner membership, parsing, normalization, fingerprint/replay receipt,
  deterministic product row lock, base-version check, mutation, version
  increment, change append, and receipt completion in one Postgres transaction.
- `public.apply_product_catalog_operation_v1(...)` is the invoker wrapper
  granted only to `authenticated`.
- `public.pull_product_catalog_changes_v1(...)` is a security-invoker,
  read-only bounded function that verifies active membership and returns only
  the requested business after the exclusive cursor.

Use `search_path = ''` and fully qualified objects for every definer function.
Revoke default table/function access from `public` and `anon`; grant only
function execute and the minimum member read surface. The application uses a
publishable key and user session, never a service-role key. Direct insert,
update, and delete on product/change/receipt tables are denied to clients.
Enable RLS on both public tables: active members may read their own business;
non-members and members of another business see nothing. The private receipt
table has no client grants. `TO authenticated` alone is never treated as
authorization.

Use row locks and short transactions. For updates, lock the target product
before version evaluation. For create/natural-key races, database unique
constraints are final authority and map deterministically to
`duplicateNaturalKey`. Receipt reservation and product locking follow one
documented order to prevent deadlocks. The API returns stable sanitized codes,
never SQL text, stack traces, tokens, or unrestricted error bodies.

## Q. Atomicity

The following are non-negotiable single transactions:

```text
LOCAL_PRODUCT_MUTATION + SYNC_METADATA_PENDING + OUTBOX_INSERT
ACK_RESULT_PROJECTION + SYNC_METADATA_ACKNOWLEDGED + OUTBOX_COMPLETED
INBOUND_PRODUCT_PROJECTION + SYNC_METADATA + INBOX_APPLIED + CHECKPOINT_ADVANCE
INBOUND_CONFLICT + PRODUCT_ATTENTION_STATE + INBOX_CONFLICT + CHECKPOINT_ADVANCE
ACCEPT_REMOTE_RESOLUTION + PRODUCT_PROJECTION + CONFLICT_RESOLVED
SERVER_RECEIPT_RESERVE/REPLAY_CHECK + PRODUCT MUTATION + CHANGE APPEND + RECEIPT COMPLETE
```

Sequential futures outside a database transaction do not satisfy this
contract. All local participants must share the exact production
`FoundationDatabase`; composition fails closed otherwise.

## R. Dependency decision

```text
DEPENDENCY_CHANGE_REQUIRED = NO
```

Drift supplies local transactions and schema generation; `crypto` supplies
SHA-256 canonical fingerprints; `uuid` supplies distributed IDs; and
`supabase_flutter` supplies authenticated RPC transport. A connectivity plugin
is unnecessary because lifecycle/manual/write/auth triggers plus durable retry
state are sufficient. Skills that demonstrate extra packages do not override
this repository-specific decision.

## S. Schema and migration decision

```text
SCHEMA_CHANGE_REQUIRED = YES
CURRENT_LOCAL_SCHEMA_VERSION = 18
TARGET_LOCAL_SCHEMA_VERSION = 19
SERVER_MIGRATION_REQUIRED = YES
```

### Local Drift schema

Add two tables; do not rebuild `Products` or rewrite product IDs.

`ProductCatalogScopeBindings`:

```text
business_id TEXT PRIMARY KEY
auth_user_id TEXT NOT NULL
role TEXT NOT NULL CHECK role IN ('owner','employee','viewer')
verified_at_utc DATETIME NOT NULL
is_active INTEGER NOT NULL CHECK is_active IN (0,1)
CHECK only one active row (partial unique index on constant when is_active = 1)
```

`ProductCatalogSyncStates`:

```text
local_product_id TEXT PRIMARY KEY REFERENCES products(id) ON DELETE RESTRICT
business_id TEXT NOT NULL
remote_product_id TEXT NOT NULL UNIQUE
acknowledged_entity_version INTEGER NULL CHECK > 0
acknowledged_payload_json TEXT NULL
acknowledged_payload_fingerprint TEXT NULL CHECK length = 64
acknowledged_server_modified_at_utc DATETIME NULL
acknowledged_source_operation_id TEXT NULL
acknowledged_actor_auth_user_id TEXT NULL
acknowledged_device_id TEXT NULL
pending_operation_id TEXT NULL UNIQUE
projection_state TEXT NOT NULL CHECK IN ('pending','acknowledged','attentionRequired','tombstoned')
tombstone_version INTEGER NULL CHECK > 0
deleted_at_utc DATETIME NULL
deleted_by_auth_user_id TEXT NULL
deleted_by_device_id TEXT NULL
deletion_source_operation_id TEXT NULL
updated_at_utc DATETIME NOT NULL
UNIQUE (business_id, remote_product_id)
CHECK acknowledged snapshot/version/fingerprint metadata is coherently null or present
CHECK tombstone metadata is coherently null or present and tombstone_version = acknowledged_entity_version
```

Add indexes on `(business_id, projection_state, local_product_id)` and
`(business_id, remote_product_id)`. Operation state remains in
`durable_outbox_operations`; the sidecar stores only the product projection's
link/current disposition and acknowledged snapshot needed to preserve a
provisional candidate. It is not a competing sync ledger.

The v18→v19 migration creates empty sidecar tables/indexes only. Existing
products remain byte-for-byte local-only and are not assigned a business or
remote identity automatically. Validate foreign keys and all constraints.
Opening a pre-v18 database continues through the existing ordered migration
steps and then v19. Failure rolls back schema migration; no destructive
fallback or automatic database reset is allowed.

Generated `foundation_database.g.dart` changes only through:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

### Server migration

Add one timestamped migration containing the exact schema/RLS/functions above
and one pgTAP file. It is additive and must run cleanly from a fresh local
Supabase reset and as the next migration over the current three migrations.
No deployment occurs in the implementation session unless separately
authorized.

### Legacy adoption

The owner explicitly starts product-only adoption after a successful pull and
verified empty-or-reviewed remote catalog. For each unbound local product, a
transaction assigns a UUID remote ID in sync metadata and enqueues
`product.create.v1`, preserving the local ID as `legacyLocalId`. Adoption is
resumable per product, never name-based binding, never bulk silent on login,
and never rewrites inventory references. A server natural-key collision creates
durable `duplicateNaturalKey` evidence for manual resolution. Only one active
business may be adopted in this slice.

Backup format remains unchanged: product business data still exports/imports
through the existing product model; sync metadata, receipts, checkpoints, and
scope bindings are device-operational evidence and are not fabricated by
restore. Restored products are local-only until explicit adoption. Recovery
export of pending evidence remains deferred.

## T. Implementation slices

### S1 — Product synchronization contracts and canonical codec

- **Goal:** Define provider-neutral product IDs, operation/change/ack DTOs,
  sealed gateway outcomes, projection dispositions, retry classification, and
  canonical JSON/fingerprint rules.
- **Likely seams:** new files under `lib/application/catalog_sync/`, existing
  identity, scope, operation, deletion, and canonical JSON contracts.
- **Dependency:** completed durable foundation only.
- **Behavior:** no wiring or network; malformed scope/version/tombstone data
  fails at construction/decoding.
- **Tests:** DTO validation, canonical field order/null normalization,
  fingerprint fixtures, 64-bit versions, UUID and business-wide scope.
- **Exit:** local/server fixture JSON has one documented V1 shape and no
  Supabase/Drift type leaks into contracts.

### S2 — Drift v19 product sync metadata and migration

- **Goal:** Add scope binding and product sync-state tables while preserving
  every v18 product and reference.
- **Likely seams:** `foundation_database.dart`, `migration_strategy.dart`,
  generated Drift file, database migration tests.
- **Dependency:** S1 states/codecs.
- **Behavior:** v18 rows remain local-only; fresh v19 and upgraded v19 enforce
  identical constraints/indexes.
- **Tests:** fresh schema, v18 fixture upgrade, pre-v18 chained upgrade,
  invalid state/tombstone rejection, unique remote/pending IDs, FK restriction,
  rollback on injected migration failure.
- **Exit:** schema version 19 is reproducible and no product IDs/data change.

### S3 — Local hybrid write/read composition

- **Goal:** Compose create/update/set-active with the existing outbox and
  expose local projection metadata.
- **Likely seams:** `product_repository.dart`, `drift_product_repository.dart`,
  catalog read model/repository/query, new Drift product sync repository,
  application dependency bridge.
- **Dependency:** S1-S2.
- **Behavior:** local-only mode is unchanged; cloud-bound mutations atomically
  become provisional+outbox; a second unresolved mutation is refused; reads
  hide tombstones and report pending/acknowledged/attention/stale truth.
- **Tests:** each command's atomic rollback/success, exact envelope/payload,
  local mode parity, one-pending guard, tombstone filtering, downstream read
  model compatibility.
- **Exit:** local mutation iff outbox commit is proven with a file-backed DB.

### S4 — Supabase product authority

- **Goal:** Add authoritative server product rows, receipts, change feed,
  functions, RLS, grants, and SQL tests.
- **Likely seams:** one new `supabase/migrations/*.sql`, one
  `supabase/tests/*product_catalog*.sql`.
- **Dependency:** S1 wire fixtures.
- **Behavior:** owner mutations are versioned/idempotent and emit one ordered
  change; active members pull only their business; direct writes are denied.
- **Tests:** owner create/update/set-active, member read, anon/non-member/
  cross-business denial, employee/viewer mutation denial, exact replay,
  changed replay, stale base, natural-key race, rollback injection, grants,
  RLS, tombstone feed fixture, ordered bounded pull.
- **Exit:** fresh reset and pgTAP suite pass; no service-role client path.

### S5 — Provider adapters and outbound coordinator

- **Goal:** Implement Supabase push/pull adapters and a bounded foreground
  product sync coordinator.
- **Likely seams:** `lib/infrastructure/supabase/`,
  `lib/application/catalog_sync/`, stable provider error mapper.
- **Dependency:** S1 and S4.
- **Behavior:** claim/push/classify/retry/conflict/ack paths are deterministic;
  concurrent `synchronizeOnce` calls coalesce in-process while durable CAS and
  leases remain authoritative.
- **Tests:** adapter request/response contract, malformed response, timeout,
  5xx/transient, auth, validation, changed replay, claim expiry, bounded batch,
  no token/error leakage.
- **Exit:** all remote outcomes map to exactly one durable transition.

### S6 — Acknowledgement projection and repair

- **Goal:** Apply accepted/replayed results to SQLite and complete outbox rows
  without reposting after a crash.
- **Likely seams:** new Drift product acknowledgement projector and coordinator
  recovery path.
- **Dependency:** S2-S5.
- **Behavior:** stored acknowledgement is validated and projected atomically;
  startup repairs every eligible `acknowledgedPendingApply` product operation.
- **Tests:** crash before/after acknowledgement persistence, replayed result,
  projection rollback, nested transaction participation, mismatched scope/ID/
  fingerprint/version, permanent acknowledgement conflict.
- **Exit:** acknowledged outbound result is never reposted solely for local
  projection repair.

### S7 — Pull, inbox, checkpoint, tombstone, and conflicts

- **Goal:** Complete ordered inbound convergence and explicit resolution.
- **Likely seams:** pull coordinator, product inbox applicator, product
  conflict-resolution store/commands, existing durable repositories.
- **Dependency:** S1-S6.
- **Behavior:** receive-before-apply, atomic apply/checkpoint, exact dedupe,
  version matrix, tombstone handling, conflict checkpointing, accept-server and
  resubmit-local resolutions.
- **Tests:** new/update/deactivate/tombstone apply, unknown product, duplicate
  delivery, changed delivery, cursor restart, lower/equal/higher versions,
  delete-vs-update, same-version mismatch, two-device stale writer, both
  resolution choices and repeated collision.
- **Exit:** no inbound payload/tombstone is silently lost and checkpoint never
  outruns durable handling.

### S8 — Bounded runtime and product UI wiring

- **Goal:** Wire one coordinator and truthful catalog UX through the
  composition root.
- **Likely seams:** `AppCompositionRoot`, `ApplicationDependencies`, product
  commands/query/controller/screen, lifecycle/auth hooks.
- **Dependency:** S1-S7.
- **Behavior:** sync on verified startup/auth refresh, foreground resume,
  product-screen manual refresh/open, and after a local product write; never in
  a background worker or periodic loop. UI shows offline/stale/pending/
  attention states, disables duplicate edits, and offers the two resolutions.
- **Tests:** widget tests for all states/actions, lifecycle coalescing, no-cloud
  parity, missing/changed binding fail-closed, manual retry, controller reload
  after local projection.
- **Exit:** UI remains SQLite-backed and no widget imports Supabase.

### S9 — Legacy adoption and end-to-end vertical proof

- **Goal:** Bind reviewed legacy products and prove two-device convergence.
- **Likely seams:** product adoption command/service and owner-facing product
  screen entry point; test harnesses only outside production network.
- **Dependency:** S1-S8.
- **Behavior:** explicit resumable per-product adoption, safe natural-key
  collision, preserved local references, no silent upload.
- **Tests:** empty/local/server combinations, interrupted adoption restart,
  mapping preservation, local-create→push→second-device-pull, second-device
  update→first-device-pull, stale concurrent edit→resolve, remote tombstone.
- **Exit:** the complete product-only path works across two isolated local DBs
  and one test Supabase without synchronizing any other entity.

### S10 — Regression and implementation closure

- **Goal:** Run all gates, inspect scope, document evidence, and stop.
- **Dependency:** S1-S9.
- **Behavior:** no deployment, release, next-successor selection, recovery, or
  unrelated cleanup.
- **Tests/gates:** Section V in order.
- **Exit:** exact authorized file set, green gates, clean remote lock, and no
  deferred work claimed complete.

## U. Test contract

### Domain/application unit tests

- Product remote UUID/local-ID separation and business-wide scope.
- Payload validation, normalization, canonical JSON, fingerprints, and stable
  wire enums.
- Base-version rules and version/tombstone consistency.
- Retry/permanent/conflict error classification.
- One unresolved mutation per product and role/binding rules.

### Repository and Drift integration tests

- All three product mutations compose with outbox in one real transaction.
- Existing local-only repository behavior remains unchanged.
- Read joins expose disposition/staleness and always hide tombstones.
- Acknowledgement apply, inbound apply, conflict/checkpoint, and resolution
  transaction boundaries roll back under injected failure.
- File-backed restart covers pending, retry-wait, expired claim,
  acknowledged-pending-apply, received inbox, conflict, and checkpoint state.
- Same DB instance/nested transaction participation is proven.

### Migration tests

- Fresh v19 schema and v18→v19 data preservation.
- Old chained upgrade to v19.
- Constraint/index/FK inspection and invalid-row rejection.
- No sidecar row fabricated for legacy products.

### Supabase/transport tests

- RLS and grants for anon, owner, employee, viewer, inactive member,
  non-member, and second business.
- Direct writes denied; only the public functions are executable.
- Create/update/set-active success, exact replay, changed-payload replay,
  stale base, wrong scope, invalid UUID/price/unit/version, natural-key race,
  and transaction rollback.
- One accepted operation produces one version increment, receipt, and change.
- Pull is scoped, exclusive-cursor, ordered, limited, and returns full
  tombstone/provenance data.
- Supabase adapter maps stable RPC JSON and sanitizes provider failures.

### Conflict/checkpoint/crash tests

- Two devices update the same version: one accepted, one durable conflict.
- Pending update versus remote tombstone preserves both.
- Equal version/different payload conflicts; equal/same dedupes.
- Checkpoint advances atomically for applied and durably conflicted inbox
  items, never on receipt/failure.
- Unknown remote result replays receipt; acknowledgement repair does not call
  transport; claim expiry recovers.
- Accept-server and resubmit-local resolution are scope/actor/CAS checked.

### Widget/integration/end-to-end tests

- Widget tests render local-only, offline, stale, pending, acknowledged,
  attention, and inactive states; buttons are enabled/disabled correctly.
- Manual refresh and resolution interactions call application handlers, not
  infrastructure.
- Integration test uses two file-backed app databases against the local
  Supabase test project for create, pull, edit, conflict, restart, and
  tombstone convergence.
- Existing inventory, sales, purchases, backup/restore, reports, product
  controller, application-query boundary, auth, and Windows behaviors regress.

Principal invariants:

```text
LOCAL_PRODUCT_MUTATION_IFF_OUTBOX_COMMIT
APPLIED_INBOX_IFF_PRODUCT_PROJECTION_AND_CHECKPOINT_COMMIT
EXACT_REMOTE_OPERATION_MUTATES_SERVER_AT_MOST_ONCE
EXACT_INBOUND_OPERATION_APPLIES_AT_MOST_ONCE
ACKNOWLEDGED_OUTBOUND_RESULT_IS_NEVER_REPOSTED_FOR_LOCAL_REPAIR
ONE_PRODUCT_HAS_AT_MOST_ONE_UNRESOLVED_LOCAL_MUTATION
REMOTE_VERSION_IS_THE_ONLY_ENTITY_CAUSAL_AUTHORITY
NO_SCOPE_CROSSING
NO_SILENT_PAYLOAD_LOSS
NO_SILENT_TOMBSTONE_LOSS
NO_HARD_DELETE_FROM_ORDINARY_PRODUCT_WORKFLOW
UI_READS_SQLITE_ONLY
```

Coverage is a diagnostic for missed branches, especially the failure matrix;
it is not a correctness oracle and no percentage-only acceptance gate is
introduced.

## V. Validation gates

Run in this order in the future implementation session:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
dart run build_runner build --delete-conflicting-outputs
git diff --check
flutter analyze --no-pub
flutter test <focused catalog contract/repository/coordinator/widget tests>
supabase db reset --local
supabase test db
flutter test integration_test/<product_catalog_vertical_slice_test.dart>
flutter test
flutter test --coverage   # diagnostic artifact; no percentage-only pass claim
git diff --check
```

After generation, verify only the expected generated Drift delta. Inspect the
full diff and changed path set before commit. A full Windows release build is
required only if runtime/UI wiring changes Windows compilation, which S8 is
expected to do; use the repository's established `flutter build windows
--release` gate in that case. Do not deploy Supabase or publish a release as a
validation side effect.

## W. Compatibility and regression constraints

- Existing local-only installations work with no Supabase configuration.
- Existing `Product`, product IDs, inventory links, ordering, price units, and
  backup schema remain compatible.
- No product name/code is treated as identity; no barcode meaning is added.
- Inactive products behave as before; tombstoned products are separately
  hidden.
- Current local natural-key uniqueness remains, intentionally stricter than
  per-business server uniqueness under the one-business limitation.
- Application and domain imports remain provider-neutral.
- The exact shared `FoundationDatabase`, device identity, execution context,
  clock, and durable store are injected from the composition root.
- No old outbox/inbox/conflict/checkpoint row is rewritten or compacted.
- No client timestamp, Cairo business date, cursor, or payload arrival order is
  substituted for server entity version.
- No service-role key, token, credentials, stack trace, or raw provider body is
  persisted in product evidence.
- Existing financial command gateways and durable foundation tests remain
  unchanged except additive shared-interface compatibility where required.

## X. Risks and resolved boundaries

| Risk | Planned control |
| --- | --- |
| Current session adapter loses business context offline | Product-only last-verified binding; same persisted remote auth user required; server always reauthorizes. |
| Offline role revocation | Local candidate remains provisional; server rejects durably; no remote authority is forged. |
| Legacy ID differs across devices | Explicit remote UUID sidecar; never bind by name or rewrite historical local references. |
| Natural-key collision during adoption | Server unique constraint plus `duplicateNaturalKey` conflict; no auto-merge. |
| Price/cost concurrent edits | No automatic merge; explicit owner decision from preserved snapshots. |
| Multiple edits before first acknowledgement | One-unresolved-mutation guard in V1. |
| Crash after server commit | Server receipt replay and local acknowledgement repair. |
| Pull cursor outruns apply | Advance only with applied/conflicted inbox transaction. |
| Remote tombstone erases local pending work | `deleteVsUpdate` conflict and full retained tombstone payload. |
| Sidecar becomes a second ledger | It stores projection/link state only; durable operation lifecycle remains exclusively in predecessor tables. |
| Public schema exposure defaults change | Use explicit migration, grants, RLS, functions, and tests; do not assume automatic exposure. |
| Foreground work grows | Fixed batch/page caps and coalesced sync passes; no worker platform. |
| Conflict resolution extends predecessor API | Use the already-modeled resolution columns with narrow CAS semantics; no predecessor schema/state-machine redesign. |

No owner decision blocks this plan. The following limitations are deliberate,
not silently solved: one local remote business, no ordinary delete, no
automatic merge, no background sync, no general recovery/export, and no
multi-entity synchronization.

## Y. Implementation authorization boundary

This artifact authorizes only a separate, fresh implementation session after
its containing commit is independently remote-locked. That session may
implement S1-S10 in order and must stop on authority, remote, scope, or schema
divergence.

```text
CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE_PLANNING = COMPLETE
CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE_IMPLEMENTATION = NOT_STARTED

NEXT_ALLOWABLE_SESSION = IMPLEMENTATION_OF_CLOUD_HYBRID_PRODUCT_CATALOG_VERTICAL_SLICE
NEXT_ALLOWABLE_SESSION_CLASS = IMPLEMENTATION_OF_THIS_PLAN_ONLY

RECOVERY_TRIAL_AND_LICENSING_BOUNDARY_AUTHORIZED = NO
OTHER_ENTITY_SYNCHRONIZATION_AUTHORIZED = NO
GENERAL_SYNC_WORKER_AUTHORIZED = NO
SUPABASE_DEPLOYMENT_AUTHORIZED = NO
NEXT_SUCCESSOR_SELECTION_AUTHORIZED = NO
```

The implementation session may not interpret this plan as permission to
deploy, broaden into recovery/licensing, synchronize another entity, add a
general worker, select a successor, or discard durable conflict/tombstone
evidence.

## Z. Skills and external guidance applied during planning

Repository authority remained above all external guidance.

- `flutter-apply-architecture-best-practices`: applied UI/application/data
  separation, repository ownership of offline/cache/retry behavior, single
  source of truth, and root composition.
- `flutter-add-widget-test` and `flutter-add-integration-test`: applied to the
  widget state matrix and real end-to-end interaction contract.
- `dart-add-unit-test` and `dart-collect-coverage`: applied to focused contract
  tests, deterministic fixtures, and coverage-as-diagnostic treatment.
- `supabase` and `supabase-postgres-best-practices`: applied RLS/grants,
  definer/search-path safety, private receipts, short transactions, row-lock
  order, database constraints, indexes, idempotent upsert/replay, and pgTAP
  gates.
- `verification-before-completion`: applied evidence-before-claims and fresh
  Git-object/direct-remote closure requirements.
- Official Flutter/Dart skill repositories were used as canonical acquisition
  sources. Searches for current official offline/database skills returned
  historical names that are not present in the current official package; no
  untrusted substitute was installed.
- Current Supabase RLS, database-function, Dart RPC, and changelog guidance was
  checked on 2026-09-11. The implementation session must recheck the changelog
  and exact APIs because cloud behavior is time-sensitive.
