# Phase 103 — Offline Sync, Idempotency & Conflict Model

Date frozen: 2026-07-28
Scope: contracts only. No outbox, API, token, network call, or production synchronization is implemented in Phase 103.

## 1. Operating principle

The application remains useful during temporary loss of internet, but offline acceptance is provisional. Shared business truth becomes final only after the server validates and atomically acknowledges the command. The UI must visibly distinguish acknowledged, pending, retrying, conflicted, rejected, and cancelled work.

## 2. Durable outbox record

Every synchronizable local command contains at least:

| Field | Contract |
| --- | --- |
| `operationId` | Globally unique immutable operation identity |
| `idempotencyKey` | Globally unique retry identity, scoped on server by organization and command type |
| `entityType`, `entityId`, `operationType` | Stable provider-neutral command classification |
| `payloadVersion` | Versioned schema; unsupported versions fail permanently with upgrade guidance |
| `payload`, `payloadFingerprint` | Canonical payload and cryptographic fingerprint; same key with different fingerprint is rejected |
| `organizationId`, `branchId`, `warehouseId` | Captured authorization context for display; server re-derives/validates scope |
| `deviceId`, `userAccountId`, `sessionId` | Actor provenance; server validates current session/device/grants |
| `createdAtLocal`, `effectiveBusinessDate` | Preserved client evidence/business intent; not server authority |
| `baseVersion` | Required for versioned mutable entities; absent for append commands where not applicable |
| `transactionGroupId`, `dependencies` | Atomic group and prerequisite operation IDs |
| `syncStatus` | State defined below |
| `retryCount`, `nextRetryAt`, `lastAttemptAt`, `lastErrorCode`, `lastError` | Retry evidence; user message is sanitized |
| `serverResultId`, `serverTimestamp`, `acknowledgedVersion` | Filled from authoritative acknowledgement |

Outbox rows are written in the same local SQLite transaction as the provisional local mutation/materialized preview. A crash must leave both present or neither present.

## 3. State machine

```text
pending -> sending -> synced
   |          |        |
   |          +-> retryableFailure -> pending
   |          +-> conflict
   |          +-> permanentFailure
   +-> cancelled (only while cancellation is safe and not server-accepted)
```

Frozen statuses:

- `pending`: durable and eligible when dependencies/grace allow.
- `sending`: leased to one sync worker; lease expiry returns it to retry evaluation.
- `synced`: server acknowledgement and authoritative result applied.
- `retryableFailure`: transport, timeout, rate limit, transient server or serialization retry.
- `permanentFailure`: invalid payload/version/authorization/business rule that retry cannot fix unchanged.
- `conflict`: human/application resolution is required.
- `cancelled`: locally abandoned before acceptance or an explicit server cancellation command has been acknowledged.

No state deletes the evidence row immediately. Retention/compaction occurs only after acknowledged server cursor and audit policy permit it.

## 4. Push/pull protocol

1. Recover expired `sending` leases.
2. Refresh session/grants if online; stop if device/account is revoked.
3. Select dependency-ready `pending` rows in deterministic order.
4. Submit a bounded transaction group with operation ID, idempotency key and fingerprint.
5. On timeout, keep the same key and query/retry; never create a new business command.
6. Server starts a transaction, locks/validates scope and invariants, checks idempotency, applies all or none, appends audit, stores the immutable result, and commits.
7. Client applies acknowledgement/result and outbox state in one local transaction.
8. Pull changes/tombstones after the last durable server cursor, apply idempotently, then advance the cursor in the same local transaction.
9. Recompute materialized views from acknowledged events plus clearly separated pending overlays.

Push and pull are independently retryable. A successful push result must be recoverable even if the acknowledgement response was lost.

## 5. Server-side idempotency

The server stores an idempotency record keyed by at least:

`organizationId + commandType + idempotencyKey`

The record contains actor/device, payload fingerprint/version, processing status, command result, created/expiry/retention timestamps, and linked audit/transaction IDs.

Rules:

- First valid request claims the key transactionally.
- Same key and same fingerprint returns the original accepted/rejected result without reapplying side effects.
- Same key with a different fingerprint returns `idempotencyPayloadMismatch` and a security/audit event.
- Concurrent claims serialize; only one command body can commit.
- Deduplication retention must cover the maximum offline/retry/restore window for financial commands. A short cache-only window is insufficient.
- Cancellation/refund/reversal commands have their own immutable keys and source links.
- Restore/import uses a separate import namespace and source-record identity; it is never ordinary outbox replay.

This prevents duplicate sale, collection, stock deduction, expense, timeout retry, cancellation, refund, and restore application.

## 6. Ordering and dependencies

| Scenario | Rule |
| --- | --- |
| New product then sale | Sale depends on acknowledged product create or includes an atomic supported reference command |
| Customer then credit sale/collection | Party command must be accepted first; entity ID remains stable |
| Supplier then purchase/payment | Same dependency rule |
| Cancellation/refund | Depends on acknowledged original and its authoritative version/status |
| Closing | Server close boundary rejects later-arriving commands with an effective date inside the close unless an explicit authorized reopen/correction workflow applies |
| Role/device revocation with queue | Server reauthorizes each command at acceptance; pending work is quarantined for review, never silently accepted/discarded |
| Two devices | Server order/locks and versions decide; device insertion order is not global order |

Transaction groups for a sale/purchase/payment include all stock, valuation, financial and audit effects. Partial acknowledgement is prohibited.

## 7. Conflict policy by data type

| Data | Strategy | Automatic merge? | Resolution |
| --- | --- | --- | --- |
| Sale, purchase, collection, payment, expense | Append command with idempotency and server validation | No | Accept atomically or reject/quarantine |
| Inventory movement/valuation/COGS | Server-ordered append ledger and deterministic calculation | No | Reject insufficient/closed/conflicting command; authorized corrective event |
| Financial entry/transfer/closing | Append/reversal with locking/serializable retry | No | Reject or explicit reopen/correction; never overwrite balance |
| Cancellation/refund | Linked command against authoritative source status | No | Duplicate returns original result; conflicting state is explicit |
| Product/customer/supplier profile | Expected version/optimistic concurrency | Sometimes | Non-overlapping allowed fields may merge; otherwise review |
| User role/grant/device/session | Server security authority | No client merge | Latest authorized server state; revocation wins |
| Organization/branch/warehouse settings | Version check and privileged review | Limited | Explicit owner/admin choice and audit |
| Device theme/UI preferences | Device-local or user preference version | Yes where harmless | Local or last-user-choice policy |
| Audit log | Append-only | No | Server assigns ordering/time; duplicates deduped by source operation |

Last-write-wins is prohibited for quantity, COGS, balance, account, close, approval, posting, and audit truth.

## 8. Time handling

- Transport/server timestamps use UTC.
- The organization timezone for business-day interpretation is `Africa/Cairo` until explicitly changed by an authorized organization setting.
- `effectiveBusinessDate` retains the user's intended date; server validates allowed range and close state in organization time.
- `createdAtLocal` is evidence only. `receivedAtServer` and `committedAtServer` are authoritative ordering/audit times.
- Clock skew is measured from server responses and displayed/telemetried; it never silently rewrites historical business dates.
- Old local dates retain their original semantics during migration. UTC conversion must not shift their declared business day.

The 156 current `DateTime.now()` calls are migration inventory, not a license to trust device time. Phase 104 introduces a `Clock` boundary; later server commands add server time.

## 9. Device and session identity

Each installation receives a new `deviceId` after registration. Secure storage keeps refresh-session material; ordinary SQLite may keep only non-secret device/session references. Reinstalling does not clone identity. A stolen/revoked device cannot submit new commands, but its encrypted pending queue remains recoverable through an owner-authorized process.

If an access session expires offline:

- cached reads within prior scope may continue for the configured grace period;
- pending drafts may be saved;
- high-risk commands can be queued only if policy explicitly permits it;
- server acceptance always performs current authorization;
- permanent account/device revocation overrides grace.

## 10. Retry policy

Use exponential backoff with jitter and server `Retry-After` when provided. Suggested initial schedule is seconds/minutes rather than a frozen exact value; Phase 107 load/reliability tests set limits. Retryable classes include network loss, timeout, 429, transient 5xx, and serialization conflict. Validation, forbidden scope, closed period, disabled account, bad payload version, and fingerprint mismatch are not blindly retried.

The owner can request retry after reviewing the error, but cannot force the server to bypass accounting, authorization, close, or organization invariants.

## 11. Failure modes and required behavior

| Failure | Behavior |
| --- | --- |
| App crash during enqueue | One local transaction preserves both provisional state and outbox or neither |
| Crash during send | Lease expires; same idempotency key is retried |
| Server committed, response lost | Retry/query returns stored original result |
| Ack received, local apply fails | Reapply acknowledgement idempotently on restart |
| Pull page partly applies | Local transaction rolls back; cursor does not advance |
| Queue dependency permanent failure | Dependents remain blocked with visible reason |
| Device deleted with pending work | Warn/block ordinary uninstall cannot be guaranteed; owner-visible sync status and recovery/export policy required |
| Payload version obsolete | Permanent failure with upgrade/migration path; never reinterpret silently |
| Authorization changed | Server rejects/quarantines; local data remains visible for review |
| Old restore introduces known IDs | Import dedupe and reconciliation; never post again through outbox |
| Two workers send same operation | Server idempotency and local lease make the second harmless |

## 12. Accounting reconciliation gates

Before marking a financial transaction group `synced`, the client validates the server result envelope and reconciliation totals. The server transaction must prove:

- document line totals and payment allocations reconcile;
- stock movement and valuation event/state reconcile;
- transaction-level COGS and reversal references reconcile;
- debit/credit/direction effects and account balances satisfy current rules;
- closing and negative-balance authorization are valid;
- audit entry links the operation, user, device, organization and server time.

A mismatch is `reconciliationFailed`, quarantines the result locally, and requires support/owner review. The client never “fixes” the difference silently.

## 13. Owner-visible sync UX contract

Future UI exposes last acknowledged sync, pending/retrying/conflict/permanent-failure counts, operation details, sanitized errors, dependencies, retry/cancel eligibility, stale-cache indication, and device/session state. Destructive cancellation requires confirmation and cannot cancel a server-accepted transaction; it creates a governed reversal/cancellation command instead.

No connectivity icon alone may imply that all business data is synchronized.
