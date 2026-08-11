# Phase 108C — Cloud Operating Model and Data Authority Decision Freeze

Date: 2026-08-11

Run: `docs/phase-108c/evidence/20260811-141358/`

Governing baseline: `5aeb41b7cd5e8c1919d6e0a7cb6544c85d799054`

## 1. Final Outcome

**Outcome A — FULL SUCCESS.** The validation gates are complete; the isolated
commit proof is recorded in Section 30 and the final handoff. All architecture decisions required by
108C are frozen with no critical `UNDECIDED` item and no Production, schema,
dependency, test or platform change.

The decision is: **Cloud-authoritative shared business state, SQLite local
cache/offline working store, O3 limited provisional offline writes, and S4
hybrid synchronization with server-authoritative critical commands.**

## 2. Repository Provenance

- Phase 108A: `e0e4ddf4249282afc347a96370a38fa2617280e9`, Outcome A.
- Phase 108B/HEAD: `5aeb41b7cd5e8c1919d6e0a7cb6544c85d799054`, Outcome A2.
- Branch: `codex/phase-107h-governed-14-day-trial-windows-package-acceptance`.
- Baseline status and last ten commits were captured before work.
- Pre-existing 107H artifacts are preserved and excluded: four modified Phase
  106 tests plus untracked `docs/phase-107h/` and `tools/phase107h/`.
- No reset, clean, stash, push, tag, merge or rebase occurred.

Evidence: [baseline](evidence/20260811-141358/00-git-baseline.txt).

## 3. Current Architecture Summary

The current product is a stable local Windows application. Production composes
one Drift `FoundationDatabase`, SQLite schema version 15, WAL and foreign keys,
with durable repositories for authentication, catalog, parties, inventory,
valuation, documents, ledgers, financial accounts, approvals and audit.

Repository interfaces exist and product reads have a narrow catalog query
contract. Some complex adapters deliberately wrap/hydrate characterized local
aggregates. Cross-repository rollback uses `RepositoryTransaction` snapshots;
only selected operations, such as Phase 107B business wipe, inject one outer
durable database transaction. No organization, membership, device, outbox,
inbox, sync cursor, server version, remote timestamp or Cloud implementation exists.

Business identity/logo, theme and trial data live in local files outside
SQLite. Backup export is current JSON v8 with restore-to-empty validation and a
non-cryptographic checksum. The inactive Firebase bootstrap is not Cloud progress.

## 4. Business/Product Operating Assumptions

The strategic product supports Windows and Android against the same business
data and should permit more than one user/device without per-client forks.

The **first Cloud release supports C2**: multiple authorized users and devices
for one business. It also adopts tenant-safe `business_id` ownership from the
first schema so C3 multiple independent businesses can be enabled later without
mixing data. Self-service SaaS provisioning, billing and cross-business admin
are deferred. C4 multi-branch sync is deferred; scope contracts reserve
branch/warehouse evolution without claiming it now.

Accounting correctness takes priority over unconditional offline finality.

## 5. Evaluated Cloud Models

| Model | Fit | Decision |
| --- | --- | --- |
| A Cloud-first | Central truth but unacceptable online dependency for warehouse/mobile operation | Rejected |
| B Local-first/local authority | Excellent availability but unsafe final truth under concurrent financial writes | Rejected |
| C Cloud authority + local cache | Central accepted truth plus practical cached/offline operation | **Selected** |
| D Hybrid authority by data domain | Legitimate only for device preferences/provisional state; unsafe if financial domains have competing authorities | Rejected as general model |
| E Local device + cloud backup only | Does not meet multi-user/device/Android strategy | Rejected |

This decision reaffirms and sharpens Phase 103's server-authoritative direction
for Supabase rather than contradicting it.

## 6. Selected Operating Model

```text
Windows / Android UI
  -> application commands and queries
    -> local SQLite acknowledged projection + durable provisional outbox
    -> authenticated Supabase boundary
       -> RLS-scoped queries for safe data/projections
       -> trusted idempotent RPC/handlers for critical commands
          -> one Postgres transaction
             -> documents + stock + valuation/COGS + ledgers + audit + result
```

The server wins any disagreement about accepted shared state. The client keeps
rejected/conflicting commands for review; it does not overwrite accepted truth.

## 7. Data Authority Matrix

The complete matrix is [02-data-authority-matrix.md](evidence/20260811-141358/02-data-authority-matrix.md).
The complete current-domain inventory is [01-domain-inventory.md](evidence/20260811-141358/01-domain-inventory.md).

In summary:

- Cloud authority + local cache: all shared business, accounting, inventory,
  identity, membership, device, audit and numbering data.
- Device-local: secure session material, theme/window/file capabilities, drafts,
  outbox/inbox/cursors and provisional command state.
- Derived: balances, stock totals, reports, KPIs and document-history projections.
- Export artifact: local backup; never live Cloud truth.

## 8. Accounting Authority Decision

Final accounting authority is the trusted server/Postgres transaction. A
device cannot finally approve sale posting, purchase posting, expense, transfer,
opening balance, customer/supplier payment/refund, journal entry, closing,
negative-balance override or reconciliation while offline.

Each critical command includes a global operation ID and canonical fingerprint.
The server stores the key, fingerprint and stable result in the same transaction
as all business effects. Exact replay returns the original result; changed
payload under the same key is rejected. Timeout after commit is therefore safe.

Posted accounting data is append/reversal oriented. No client can directly
insert/update/delete accepted journal rows. The current integer-qirsh rules,
transaction-level COGS, close validation, reversal semantics and 108B duplicate
transfer invariant are constraints on the server implementation.

## 9. Inventory Authority Decision

The accepted inventory movement and valuation ledgers are server-authoritative.
Stock is derived, never synchronized as an editable balance. Sale/purchase and
adjustment commands validate and append stock/valuation effects in their same
server transaction. Concurrent sale acceptance uses locking/versioning or
serializable retry and cannot use LWW.

An offline stock take records an observed count/base cursor provisionally. The
server either computes an accepted adjustment against the valid base or rejects
for review; the device does not overwrite stock.

## 10. Offline Policy

Choose **O3 — Limited offline writes**, fully specified in
[04-offline-policy.md](evidence/20260811-141358/04-offline-policy.md).

Offline product lookup and acknowledged projections work. Sales, purchases,
expenses, collections/payments and stock observations may queue as provisional
commands. Transfers, opening balances, closings/reopenings, approval decisions,
imports and Cloud business deletion are online-only in the first release.
Pending/stale/accepted totals and documents must be visibly distinct.

## 11. Conflict Strategy

Financial, inventory, authorization, numbering and lifecycle conflicts are
server-rejected or serialized; none uses LWW. Version checks and controlled
merge/manual review are allowed for safe master-data fields. Accepted events are
immutable/append-oriented; corrections use compensating records. Full policy,
delete semantics and classification are in
[05-conflict-strategy.md](evidence/20260811-141358/05-conflict-strategy.md).

## 12. Identity & Business Tenancy Model

Supabase Auth is selected for future Cloud identity. Existing application user
IDs require an explicit legacy mapping; local credential verifiers are not
migrated. Cloud identity, application profile, business membership and device
identity remain distinct.

Every shared business row requires `business_id` from the first Cloud schema.
Membership role/status is authoritative. RLS defaults to deny and derives scope
from the authenticated membership, never a payload `business_id`. Owner versus
employee privileges and trusted server-only operations receive negative tests.

## 13. ID Strategy Direction

Existing clock+counter string IDs are not guaranteed multi-device safe. New
entity and operation IDs use client-generated UUIDv7; UUIDv4 is the documented
fallback. Existing IDs are preserved under a migration map/legacy field. IDs
are opaque and separate from official human document numbers.

## 14. Time / Ordering / Numbering Strategy

Server accepted/created/posted timestamps and server versions/order determine
critical truth. UTC device time is retained only as metadata. `business_date`
and effective date are explicit and validated against period closings.

Official document numbers are issued by the server after acceptance and unique
within a business/document/fiscal series scope. Offline work receives a
provisional reference. Audited gaps are acceptable; duplicates are not. Exact
format/reset/reservation policy is deferred to its contract phase.

## 15. Repository Boundary Findings

UI does not import Drift directly, but it frequently obtains repositories from
the global composition root; controllers and repositories can orchestrate
multi-domain writes; and some durable adapters persist whole hydrated
aggregates. These are real blockers before broad Cloud writes, not before a
read-only catalog spike. The audited inventory and priorities are in
[06-repository-boundary-audit.md](evidence/20260811-141358/06-repository-boundary-audit.md).

All production product reads use `ProductCatalogReadRepository`; remaining
legacy ProductRepository read coupling is fallback/test infrastructure and is
not a Cloud blocker. Product write semantics still need versioned commands
before Cloud writes.

## 16. Cloud Write Migration Inventory

The inventory is [07-cloud-write-inventory.md](evidence/20260811-141358/07-cloud-write-inventory.md).
P0 boundaries are sales, purchases, expenses, customer/supplier money flows,
transfers, inventory adjustments, opening/closing, approvals, auth/tenancy,
restore/import and wipe terminology. Master-data writes are P1; business files
and preferences are later.

## 17. Sync Architecture Decision

Choose **S4 hybrid**. Versioned rows/query projections serve master/reference
data; durable commands/events plus trusted RPC/handlers serve all critical
writes. S1 raw bidirectional row sync is prohibited for critical domains.
Options are compared in [08-sync-options-analysis.md](evidence/20260811-141358/08-sync-options-analysis.md).

## 18. Supabase Service Usage Direction

- Postgres: YES, authoritative store and transaction/reconciliation engine.
- Auth: YES, cloud identity/session/revocation.
- RLS: YES, default-deny business isolation.
- RPC/database functions: YES, atomic critical commands.
- Storage: YES when logos/exports/attachments migrate.
- Realtime: LATER, invalidation/freshness hints only.
- Edge Functions: LATER/selective for secret-bearing orchestration/imports, not
  to split an atomic accounting transaction.
- Managed backups/PITR: YES before production cutover.

## 19. Backup / Restore Future Contract

Current JSON v1–v8 remains legacy-compatible and becomes an export/migration
artifact (B2/B5), with optional local-only device recovery during transition
(B1). It cannot write directly over Cloud authority and is not a full Cloud
restore mechanism (reject B3). Server backup/PITR and disaster recovery are a
separate B4 capability. Organization export, device recovery, server backup and
DR restore must never be presented as one operation.

## 20. Business Data Wipe Future Contract

“Wipe business data” is retired as an ambiguous Cloud label. Future UI/contracts
distinguish local cache reset, remove/revoke this device, delete legacy local
business data, close/delete a Cloud business, and delete a user account. Only a
local cache reset can be device-local and it must protect pending commands.
Cloud deletion requires server authority, owner reauthentication, export,
confirmation/delay, audit, retention and recovery policy.

## 21. Trial / Licensing Disposition

The Phase 107G 14-day device-local trial is retained unchanged for current
local Windows transition and classified **transitional / deprecated later**.
Future Cloud trial/subscription entitlement is server-authoritative at the
business/account level, with a signed/bounded offline grace cache. Reinstalling
a device cannot create a new Cloud trial. Phase 107H artifacts remain preserved
and are not accepted or repurposed as Cloud licensing evidence.

## 22. Android Implications

The decision is Android-compatible: no startup network wait, SQLite acknowledged
cache, durable queue before send, UUID operation IDs, secure token storage,
refresh/revocation, lifecycle-safe retry, server ordering independent of mobile
clock, and platform capability abstractions for files/share/background work.
Android suspension may delay work but cannot lose or duplicate it. No Android
code or configuration is changed in 108C.

## 23. Security Boundaries

Supabase URL and anon/publishable key may be client configuration. User access
and refresh tokens go only to secure platform storage. The service-role key,
import/admin credentials, signing material and external integration secrets
never enter Windows/Android, logs, backup JSON or ordinary SQLite tables.

Trusted server execution is required for financial/inventory posting,
idempotency acceptance, membership/role/device changes, approval consumption,
closing, number allocation, staged import, organization export signing and
business deletion. RLS remains defense in depth even when RPC is used.

## 24. Migration/Reconciliation Requirements

High-level cutover sequence:

1. Create/verify Cloud identity, business, membership and default scope.
2. Freeze migration tool/version and create a verified local v8 backup.
3. Validate local schema, checksum, referential links, invariants and close state.
4. Assign/map global IDs without losing legacy IDs.
5. Stage reference data: business identity, users mapping, products, parties,
   accounts; then documents and dependent movements/valuation/ledgers/audit.
6. Import into an isolated staging business; no live tenant merge.
7. Reconcile exact counts, relationship hashes and money/quantity totals.
8. Freeze a cutover cursor/time, capture delta or require controlled downtime.
9. Owner reviews and accepts a signed migration report.
10. Atomically enable Cloud mode; retain rollback/export evidence.

Zero-tolerance checks include product/customer/supplier/document counts;
quantity per product; inventory valuation state and value; purchase/sale totals;
customer/supplier balances; financial account balances; directional ledger
inflow/outflow totals (and debit=credit if/when double-entry semantics exist);
expense/revenue/COGS/profit totals; transfer pairs; opening balances; closings;
valuation/audit event counts; and all referenced IDs. No silent transformation
or unexplained variance is accepted.

## 25. Failure Mode Analysis

| Failure | Expected behavior | Final authority | Recovery |
| --- | --- | --- | --- |
| Device offline | Read acknowledged cache; only allowed commands queue provisional | Last server acknowledgement | Reconnect/replay |
| Server unavailable | No critical final posting; queued state remains durable | Server | Retry with status/backoff |
| Timeout after server commit | Same key replay returns same result | Server idempotency record | Fetch result/reconcile |
| Duplicate command | Same fingerprint returns existing; mismatch rejects | Server | User-safe duplicate/conflict status |
| Partial sync | Never mix pending with final totals silently | Server cursor/version | Resume inbox/cursor; rebuild projection |
| Clock rollback/skew | Does not order/authorize critical command | Server time | Preserve device time as evidence; refresh |
| Stale product price | Command applies explicit policy/version; reject or authorized server price | Server | Refresh/review |
| Concurrent stock sale | Serialize/version; one may reject insufficient stock | Server inventory ledger | Review/retry new command |
| Concurrent transfer | Lock/version both accounts atomically | Server financial ledger | Same-key result or conflict |
| Logout during queued write | Queue is quarantined/bound to user/business/device | Server session/membership | Reauth and authorized recovery; never silent replay |
| Device revoked | New sync rejected; local data remains protected | Server device registry | Owner review/remove cache |
| App crash/suspension | Durable queue survives; no claim of send until recorded | Server + local queue state | Restart and resume safely |
| Import interruption | Staging business/job remains non-live | Server import job | Abort/retry idempotently |
| Cache corruption | Cloud acknowledged projection can be rebuilt; pending queue recovered separately | Server | Secure recovery/export of pending then rebuild |

## 26. Risk Register

The full register is [09-cloud-risk-register.md](evidence/20260811-141358/09-cloud-risk-register.md).
R0 risks are duplicate accounting, concurrent stock/valuation, partial posting,
tenant isolation and unsafe restore. Each is an implementation stop condition.

## 27. Rework Avoidance Decisions

### Work before Supabase business implementation

- Freeze application command/query boundaries and composition ownership.
- Freeze distributed ID/time/version/tombstone/number contracts.
- Freeze recovery/import/trial/licensing boundary details.
- Define Cloud schema, tenancy, RLS requirements and server command transaction groups.
- Select one low-risk catalog read vertical slice and one small governed financial write.

### Work that should not happen yet

- Full UI redesign or screen-by-screen responsive polish.
- Settings 2.0 implementation.
- Invoice visual redesign before document/number/DTO contract.
- Generic bidirectional sync engine or one-for-one SQLite schema mirror.
- Broad schema rewrites, Android implementation or real customer migration.
- Mass migration of historical Product Read test infrastructure.
- Licensing implementation or reuse of 107H as acceptance.

## 28. Work Explicitly Deferred

Exact SQL/tables, RLS SQL, RPC signatures, Edge Function code, package/library
versions, UUID library, token/grace durations, number format, branch/warehouse
features, SaaS provisioning/billing, sync scheduler, Storage policy, region/plan,
RPO/RTO, encryption/signing, commercial licensing terms, Android UI, Settings
2.0, invoice redesign and real data cutover.

## 29. Validation Results

Final results are captured in
`evidence/20260811-141358/11-validation.txt` after running the required gates.

- Formatter: PASS — 428 files, 0 changed (direct Dart SDK 3.5.4;
  `dart.bat` wrapper timeout documented in evidence).
- Analyzer: PASS — no issues found.
- Full Flutter tests: PASS — 2,418 passed, 0 skipped, 0 failed.
- Windows release build: PASS — artifact built in 22.1 seconds; existing
  non-fatal Firebase CMake/LNK4078 warnings only.
- Production/dependency/schema/platform diff guard: PASS — empty for
  `lib`, `windows`, `android`, `pubspec.yaml` and `pubspec.lock`; `test` contains
  only pre-existing 107H changes.

## 30. Git / Commit Provenance

The intended single commit subject is:

`PHASE 108C: freeze cloud operating model and data authority`

Only `docs/phase-108c/**` is authorized for staging. Final HEAD, parent, commit
count, cached diff and final worktree separation are recorded in
`evidence/20260811-141358/12-final-git-state.txt` and the handoff because a
commit cannot contain its own final hash.

## 31. Frozen Next Phase

```text
Phase 108D — Application Command/Query Boundary and Composition-Root Contract Freeze

Why now:
The Cloud authority decision is fixed, but current UI/controllers and durable
adapters do not express every transaction as one provider-neutral application
command/result. Supabase schema/RPC work before this boundary would duplicate
local orchestration and increase rework.

Exact goal:
Inventory and freeze the provider-neutral commands, queries, result/error
states, transaction participants, idempotency inputs and composition ownership
for one read slice and every P0 write family; choose the first implementation
vertical slice. Architecture/evidence only unless a separately authorized
no-behavior-change pilot is explicitly scoped.

Inputs frozen by 108C:
Model C, S4, O3, server accounting/inventory authority, business_id tenancy,
Supabase Auth/RLS direction, UUID/time/numbering direction, conflict classes,
backup/import/wipe/trial meanings and security constraints.

Scope:
Application use-case map; command/query DTO responsibilities; accepted/pending/
conflict result vocabulary; transaction-group map; composition-root injection
plan; local/remote/cache responsibilities; first catalog-read and governed-write
candidate; migration order and acceptance tests.

Non-goals:
Supabase project/package/table/RLS implementation, SQLite schema/migration,
sync engine/outbox implementation, Production repository rewrite, Android, UI
redesign, Settings 2.0, licensing or real data.

Acceptance gates:
Every P0 write has one application command boundary and participant list; no UI
or provider type leaks into contracts; one read and one write slice are selected;
error/result vocabulary covers replay/conflict/offline; no Production diff;
format/analyze/tests/build pass; one isolated documentation commit.
```

## Final Owner Decision Summary

- Operating model: Model C, Cloud authority with local cache/offline store.
- Primary source of truth: server-accepted Postgres business state.
- SQLite role after Cloud: acknowledged cache, offline working store and durable
  outbox/inbox; not final shared authority.
- Accounting/inventory authority: trusted server transaction.
- Offline sales: allowed only as provisional queued commands, never final.
- Duplicate posting prevention: global idempotency key + canonical fingerprint +
  stable result stored atomically with all effects.
- Authentication: Supabase Auth direction, with mapped local application IDs.
- Tenancy: `business_id` required from the first shared schema.
- Trusted functions: required for every critical command.
- Backup/restore: export, staged import, device recovery and server DR are
  separate; local restore cannot overwrite Cloud.
- Trial: 107G remains transitional; Cloud entitlement becomes server authority.
- Android: compatible by design; implementation remains deferred.
- Next phase: Phase 108D boundary and composition-root contract freeze.

The governing answer is unambiguous: when a device and the server disagree,
the last valid **server-accepted command result and its authoritative ledger
version** are the truth; the device's conflicting state remains provisional or
rejected evidence, not a competing balance.
