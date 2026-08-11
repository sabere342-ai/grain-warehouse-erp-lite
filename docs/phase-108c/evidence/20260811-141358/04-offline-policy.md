# Phase 108C — Frozen Offline Policy

## Decision

Choose **O3 — Limited offline writes** for the first Cloud architecture.

Offline reads use the last acknowledged SQLite projection with an explicit
stale timestamp. Offline writes are allowed only as durable provisional
commands. A provisional command is not a posted sale, expense, payment, stock
movement, journal entry, or final balance until the server atomically accepts
it. This preserves useful field operation without allowing two devices to
declare conflicting financial truth.

## Operation matrix

| Operation | Allowed offline? | Queued? | Provisional or final? | Conflict possible? | Reconciliation required? |
| --- | --- | --- | --- | --- | --- |
| Login with no cached authorized session | No | No | N/A | Yes | Online authentication required |
| Resume with valid cached session/grace | Yes, read-only plus approved queue policy | No | Local access only | Revocation may exist | Revalidate before server acceptance |
| Product/party lookup | Yes | No | Last acknowledged snapshot | Staleness | Refresh on reconnect |
| Product/customer/supplier edit | Yes, low-risk fields | Yes | Provisional | Version conflict | Server version/field review |
| Sale | Yes only as command draft | Yes | Provisional | Stock, price, customer, close, auth | Mandatory server accept/reject and totals |
| Purchase | Yes only as command draft | Yes | Provisional | product/supplier/close/valuation | Mandatory |
| Expense | Yes only as command draft | Yes | Provisional | account funds, close, auth | Mandatory |
| Customer collection/payment | Yes only as command draft | Yes | Provisional | balance, duplicate, account | Mandatory |
| Supplier payment/refund | Yes only as command draft | Yes | Provisional | balance, approval, duplicate | Mandatory |
| Stock adjustment / stock take | Yes as observed-count command | Yes | Provisional | newer stock movements/base version | Mandatory/manual review on conflict |
| Transfer | No in first Cloud release | No | N/A | two-account balance/concurrency | Must be online and server-final |
| Opening balance | No | No | N/A | one-time/global invariant | Online privileged command |
| Closing/reopening | No | No | N/A | concurrent postings | Online privileged command |
| Negative-balance approval/consume | No | No | N/A | privilege and current balance | Online reauthentication/authority |
| Shared business settings | Low-risk edits may queue later | Optional | Provisional | version conflict | Version check |
| Theme/device settings | Yes | No | Final device-local | No shared conflict | No |
| Backup/export | Yes from acknowledged local snapshot, labeled with cursor | No | File artifact | May be stale | Cloud export preferred when online |
| Restore/import | No cloud write | No | N/A | catastrophic duplication | Separate staged online import |
| Local cache reset | Yes | No | Device-local | Pending queue may exist | Block/authorize recovery first |

## User-visible states

Every queued critical command must expose `draft`, `queued`, `sending`,
`accepted`, `rejected`, `conflict`, or `needsReview`. UI totals must label
whether they include provisional effects. Receipts/invoices requiring official
numbers cannot be represented as final before acceptance; an offline provisional
reference may be printed only if explicitly marked provisional.

## Queue safety contract

- Durable before the UI reports “queued”.
- Scoped to business, user and device; never replay after an unsafe logout or
  business switch without authorized recovery.
- Stable UUID operation ID and canonical payload fingerprint.
- Exponential retry only for retryable failures; payload mismatch is permanent.
- Same key/same payload returns the original result; same key/different payload
  is rejected.
- Dependency ordering and quarantine prevent one bad item blocking all sync.
- Client restart, Android suspension and timeout after server commit must not
  create a second posting.
