# ADR 108C — Cloud Operating Model and Data Authority

Status: **ACCEPTED / FROZEN**

Date: 2026-08-11

Baseline: `5aeb41b7cd5e8c1919d6e0a7cb6544c85d799054`

## Decision

Ghalal will adopt **Model C — Cloud-authoritative shared business state with a
local SQLite cache/offline working store**, implemented using **S4 hybrid sync**:
versioned master-data/projection synchronization and idempotent server commands
or RPC for every accounting-, stock-, security- or lifecycle-critical write.

The first Cloud product supports **C2: multiple authorized users/devices for one
business**. The first schema is tenant-safe for **C3** by requiring
`business_id`, but multi-business self-service provisioning/billing is deferred.
C4 multi-branch operation is deferred; the contracts must not hard-code a
single branch/warehouse forever.

Supabase is the selected platform direction: Postgres, Auth and RLS are
required; RPC/database functions are required for atomic critical commands;
Storage is used when organization files migrate; Realtime and Edge Functions
are selective/later capabilities, never authority by themselves.

## Authority

- Server/Postgres accepted records are final for products, parties, inventory,
  valuation/COGS, documents, customer/supplier ledgers, financial accounts and
  entries, transfers, expenses, openings, closings, approvals, audit,
  memberships, device state and official document numbers.
- SQLite is the acknowledged cache, offline working store, outbox/inbox and
  projection. It is not an independent final authority once Cloud mode is on.
- The client may create globally unique provisional commands offline. Server
  acceptance/rejection decides final truth.
- Device-only preferences, secure session material, drafts, file handles and
  queue mechanics remain local.
- Reports, balances, document history and KPIs are derived/recomputable from
  accepted records; local views must label staleness and provisional effects.

## Accounting and inventory authority

No device can finally post a sale, purchase, expense, payment, collection,
transfer, opening, stock adjustment, COGS event, journal entry or closing while
offline. O3 offline support means a durable provisional command only. The
server validates authorization, close state, stock/balance constraints,
versions, duplicate key/fingerprint and the entire transaction group, then
commits all effects and an idempotency result in one transaction.

Posted journal, movement, valuation and audit records are append-only. Posted
documents are immutable in their economic effect; correction uses linked
reversal/cancellation/correction records. LWW is prohibited for them.

## Identity, tenancy and RLS

```text
Supabase auth.users
  -> application user profile/mapping
    -> business_memberships (role/status)
      -> business_id
        -> scoped business data
  -> registered devices / refresh sessions
```

Existing local user IDs are preserved as legacy identifiers and mapped during
migration; Supabase Auth IDs become cloud authentication identities. Password
verifiers are not uploaded. Every shared business row is owned by `business_id`
from the first Cloud schema. RLS is default deny. Scope comes from authenticated
membership, not a client-supplied business ID. Critical mutations are
server-only functions/handlers with explicit authorization.

## IDs, time and numbering

- New entity/operation IDs are client-generated UUIDv7, with UUIDv4 permitted
  only as an evidence-backed fallback.
- Legacy local IDs remain mapped and auditable.
- Server timestamps/order are authoritative; device timestamps are metadata;
  `business_date` is explicit and checked against closing rules.
- Official document numbers are separate server-issued scoped references.
  Offline work uses provisional references; audited gaps may occur, duplicates may not.

## Offline and conflicts

O3 limited offline writes is frozen. Product lookup and acknowledged data remain
available offline. Sales, purchases, expenses, collections/payments and stock
observations may be queued provisionally. Transfers, openings, closings,
approval decisions and destructive business operations are online-only in the
first Cloud release. Financial/inventory conflicts are rejected or serialized;
safe master-data fields use expected versions and controlled merge/review.

## Backup, restore and wipe

The current v1–v8 backup becomes:

- a legacy local compatibility/export format (B5/B2);
- a migration input only through a staged, validated, idempotent import;
- an optional device-recovery artifact for local-only/transition mode (B1).

It is not a client-controlled full Cloud restore (reject B3). Managed server
backup/PITR is a distinct Cloud snapshot/recovery capability (B4). Organization
export, device recovery, server backup and disaster recovery remain separate.

Freeze these terms:

- **Reset local cache**: deletes acknowledged cache only after pending-command
  safety checks; never mutates Cloud.
- **Remove this device**: revokes device/session and clears local secure/cache data.
- **Delete local-only business data**: legacy single-device operation during transition.
- **Delete/close Cloud business**: privileged server lifecycle with export,
  reauthentication, confirmation/delay, audit and retention.
- **Delete account**: identity lifecycle, not synonymous with deleting a business.

## Trial/licensing

The 14-day 107G trial remains unchanged and supported for the current local
Windows transition. It is **transitional**, not the future Cloud authority.
When Cloud commercial access is implemented, trial/subscription entitlement is
server-authoritative at business/account level with a signed/bounded offline
grace cache. At accepted cutover the device-local trial is deprecated for Cloud
mode; 107H remains preserved and is not treated as Cloud licensing proof.

## Windows and Android consequences

- Windows remains fully functional in current local-only mode during migration.
- Cloud-mode startup does not block indefinitely on network: it opens the local
  projection, shows freshness/auth state, and enforces O3 operation rules.
- Android is compatible because IDs are client-global, the queue is durable,
  tokens use secure storage, sync tolerates suspension/restart, server time
  controls ordering, and shared code does not assume Windows file paths.
- No Android implementation is authorized by 108C.

## Security constraints

Client configuration may include Supabase URL and anon/publishable key. Access
and refresh tokens require secure platform storage. Service-role keys, signing
secrets, import privileges and administrative credentials never enter Windows
or Android binaries, logs, backups or ordinary SQLite tables. High-risk posting,
approval, closing, import/export signing, business deletion and external-secret
operations require trusted server execution.

## Consequences

Benefits: one final truth, transaction-safe accounting, controlled offline use,
multi-device support, auditable conflicts and one architecture for Windows and
Android. Costs: explicit commands/results, outbox/inbox, schema/RLS, migration,
reconciliation, server operations and user-visible pending states. Availability
is deliberately limited for high-risk offline actions to protect correctness.

## Rejected alternatives

- Model A Cloud-first/online dependency: rejects existing offline/warehouse and
  Android connectivity needs.
- Model B local-authoritative offline-first: cannot safely arbitrate concurrent
  stock/accounting truth across devices.
- Model D hybrid authority by financial domain: creates ambiguous final truth;
  only device-local preferences and provisional state may stay local.
- Model E cloud backup only: does not satisfy multi-user/device or Android direction.
- S1 raw row sync: breaks transaction groups, immutability and conflict policy.
- Universal LWW: prohibited for financial, inventory, identity and lifecycle data.

## Constraints that future phases must not break

1. No raw client write to accepted journal, inventory, valuation or audit rows.
2. One idempotency key + fingerprint + stable result for every critical command.
3. One server transaction contains every effect of a business command.
4. `business_id` and RLS exist before shared business data.
5. Pending, stale and accepted state are distinct.
6. Restore/import is never ordinary sync and never overwrites a live tenant silently.
7. No service-role secret in any client.
8. Existing accounting invariants and Phase 108B duplicate-transfer proof remain.
9. No Production/schema/dependency/platform change is part of 108C.

## Decisions deferred to named later phases

Exact SQL/table names/RLS policies/RPC signatures, UUID library, token/grace
durations, payload schemas, number formatting, branch/warehouse rollout, sync
library, Edge Function implementation, region/plan procurement, RPO/RTO, object
retention and licensing commercial terms are deferred. They must comply with
this ADR and be frozen before their implementation phase.
