# Phase 82 — Paid Purchase UI & Durable Negative-Balance Approval

## Status and verified baseline

Phase 82 is implemented as a closure candidate. It is closed only by the final
green test/analyzer/Windows build gates, one closure commit, a new annotated tag,
and a clean working tree. No Phase 83 was created.

- Branch: `phase9e-expense-analysis-report`.
- Starting HEAD: `1ebac3d1482df0b15f5a5c34025cf41a9c2fd31e`
  (`feat: add paid purchase payment workflow`).
- Earlier baseline: `d8b1962f66306aafbbb4957f427c6d269fe1b724`.
- `841301d`, `af56ced`, and the earlier baseline are ancestors of the starting
  HEAD.
- Previous verified tag: `financial-payment-routing-integrity-verified`.
- Starting working tree: clean, non-detached, and without a Phase 82 closure
  tag.

## Adopted owner decisions

- **OD-82-01 — Request Model:** insufficient funds create only a durable
  approval request. No completed document, stock movement, ledger entry,
  account mutation, or supplier-balance mutation exists before execution.
- **OD-82-02 — Self-Approval:** an ordinary user cannot approve their request.
  An owner may approve their own request only after explicit credential
  re-authentication. The domain enforces this independently of UI visibility.
- **OD-82-03 — Approve and Execute:** approval and execution are one atomic
  transaction. There is no stable `approved` state awaiting execution.
- **OD-82-04 — Stale Requests:** the financial payload is immutable and is
  revalidated at execution. Material drift makes the request `stale`; balance
  drift alone does not. A balance that became sufficient permits normal
  execution through the same request.
- **OD-82-05 — Rejection and Cancellation:** an owner can reject `pending`; its
  requester can cancel it. `rejected`, `cancelled`, and `stale` are terminal,
  have no financial effect, and cannot be reopened.
- **OD-82-06 — Durable Storage:** requests and transitions are durable,
  idempotent, backup/restorable, and protected against duplicate active
  financial signatures. Backup v6 was not redefined; v7 was introduced while
  v1–v6 restore compatibility remains.
- **OD-82-07 — Actor Identity:** new request, execute, reject, cancel, expense,
  and audit actions require a real actor identity. Null legacy values remain
  readable/restorable only for compatibility; no new silent `system` actor is
  generated.

These decisions are also recorded in `ROADMAP-DECISION-REGISTER.md`.

## Final durable data model

`NegativeBalanceApprovalRequest` stores: durable ID/idempotency key, operation
type (`supplierPayment`, `expense`, `paidPurchase`), status, financial account,
payment method, amount, source/draft ID, related party, canonical immutable
payload, SHA-256-style deterministic payload fingerprint, requester and request
time, balance/deficit snapshot, optional reason, resolver and resolution time,
verification reference, terminal reason, result document ID, audit metadata,
and model version. No callback, closure, credential, or other transient value is
stored.

Every status change also creates a durable
`NegativeBalanceApprovalRequestTransition` containing from/to state, actor,
timestamp, reason, and verification reference when relevant.

## State machine

```text
                         approve + execute atomically
                    ┌────────────────────────────────> executed
                    │
pending ────────────┼── owner rejects ───────────────> rejected
                    ├── requester cancels ───────────> cancelled
                    └── material revalidation drift ─> stale
```

All target states are terminal. A failed approval/execution remains `pending`
with no partial financial effects. An executed business operation is corrected
only through its existing reversal contract, never by reopening or cancelling
the approval request.

## Shared workflow and operation executors

`NegativeBalanceApprovalWorkflowService` centralizes validation, request
creation, permission checks, owner re-authentication, idempotency, duplicate
pending protection, stale detection, audit, transitions, and the outer atomic
repository boundary. It dispatches only the operation-specific financial work
to the existing supplier-payment, expense, and purchase repositories.

The pre-Phase-82 one-use `NegativeBalanceApproval` authorization is no longer a
user-facing immediate-approval workflow for these three screens. It remains an
internal, transaction-bound guard used only when an approved durable request
still needs to cross below zero, preserving DC-U007 repository protection
without storing a transient authorization in the durable request.

### Request creation

- A fully valid operation with sufficient balance executes directly and creates
  no request.
- An insufficient account that disallows negative balance is rejected and
  creates no request.
- An insufficient account that permits owner-approved negative balance creates
  one `pending` request and one request audit event only.
- Replaying the same idempotency key and payload returns the same request.
- Reusing the key with a different payload is rejected.
- A database partial unique index prevents two pending requests with the same
  operation/source/account/method/amount/fingerprint signature.

### Approval and atomic execution

The outer `RepositoryTransactionCoordinator` snapshots all participating local
repositories and the durable request store. Inside that boundary the service
reloads and locks the request logically, checks `pending`, reloads the real
actor, requires owner authorization, re-authenticates self-approval, reloads
the account and source entities, validates routing and fingerprint, recalculates
the balance, executes the original operation exactly once, writes financial and
audit effects, and finally moves the request to `executed`.

Any account, inventory, supplier, expense, purchase, ledger, audit, or status
failure restores every snapshot. Nested repository transaction calls join the
outer boundary rather than pretending that call ordering is atomic.

### Stale, rejection, and cancellation

Material payload or source changes transition `pending` to `stale` without
financial effects. Relevant material fields include operation/source, account,
method, amount, supplier/category, purchase lines, quantities, prices, date,
and policy-sensitive identity. An inactive or missing account cannot execute
safely. Balance-only changes do not stale a request.

Only a currently authenticated owner can reject a pending request. Only the
real requester can cancel it. Approve/reject/cancel races are serialized; one
terminal transition wins and later attempts cannot mutate money or state.

## Operation contracts

### Supplier payment

A pending request creates no supplier payment, supplier ledger credit, or
financial outflow. Approval creates the payment once, decreases supplier debt
once, and debits the selected compatible account once. Inactive/missing
accounts and material supplier/source drift prevent execution. Existing
post-execution reversal remains authoritative.

### Expense

Every new expense draft requires `createdByUserId` and a stable
`operationRequestId`. Pending requests are not expense rows and therefore do
not enter expense reports. Approval creates exactly the immutable category,
amount, date, method, and account payload once and records the real actor.
Legacy restored expense/audit rows may retain null actors; new writes may not.

### Paid purchase

The immediate owner dialog added in `1ebac3d` was replaced in the purchase UI by
the shared durable workflow. Pending creates no purchase, inventory movement,
supplier debt, account debit, or financial ledger entry. Approval creates the
paid purchase once, raises stock once, debits the selected account once, and
leaves supplier debt at zero. Credit and sufficient-balance paid purchases
retain their established direct paths; cheques and split payments remain out of
scope.

## Schema and migration

- Drift schema version: **14** (previously 13).
- Added `negative_balance_approval_requests`.
- Added `negative_balance_approval_request_transitions`.
- Added the partial unique pending-signature index.
- Added real actor/idempotency/fingerprint columns to expenses.
- Added `actor_id` to durable audit rows.
- Migration is additive and defensively checks existing columns so repaired or
  fixture databases with newer physical columns are also safe.
- Fresh creation, populated v13 upgrade, populated legacy expense upgrade,
  preservation of old rows, and close/reopen persistence have focused tests.

## Backup and restore

Backup version **7** includes approval requests, transitions, actor references,
payload/fingerprint, statuses, resolution metadata, and related audit actor
metadata. It excludes passwords, PINs, and raw verification credentials.

Restore keeps v1–v6 semantics unchanged; missing approval collections restore
as empty. All approval references are parsed and validated before the first
write, restore remains atomic, executed requests are restored as history and
never replayed, and pending requests remain pending for fresh revalidation.
Owner wipe clears the new durable collections.

## UI behavior

The dashboard exposes a focused Arabic RTL “طلبات الموافقة” destination. Its
screen provides search, status filtering, loading/empty/error states, list and
detail views, operation/requester/account/method/amount/balance/deficit/time,
durable transitions, terminal reason, and clear back navigation. Authorized
owners can approve-and-execute or reject; the requester can cancel. Owner
self-approval opens explicit phone/password re-authentication. Busy guards
prevent repeated taps. Messages explicitly distinguish “request created; not
executed” from “approval executes immediately”.

## Scope boundaries

No split-payment work, cheque execution/account, cloud sync, SaaS, licensing,
multi-tenancy, full user-system replacement, dashboard redesign, report
redesign, or theme redesign is part of this closure. No null-to-cash fallback,
first-account auto-selection, completed pre-approval document, Phase 83, remote
push, or moved historical tag is allowed.

## Verification and closure evidence

Focused coverage asserts balances, stock, supplier ledger, documents,
financial ledger, request count/status/history, actor IDs, timestamps,
idempotency, rollback, concurrency, persistence, backup compatibility, report
exclusion, UI authorization, RTL, back navigation, and narrow viewport layout.

The final closure report records the current-run totals for the full suite,
analyzer, Windows release build, diff checks, closure commit, annotated tag,
and clean tree. Earlier or cached runs are not closure evidence.

## Remaining risks

- The product remains local/single-process; database constraints and serialized
  repository transactions protect this supported deployment, but cloud or
  multi-process resolution would require a server-authoritative lock protocol.
- The legacy one-use approval guard remains for compatibility outside the three
  unified Phase 82 entry points and must not be reintroduced as a UI queue.
- Reversal policy remains operation-specific and outside request-state changes.
