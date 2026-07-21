# Phase 82 — Paid Purchase UI & Negative-Balance Approval Decision Gate

## Status

This phase is **partially implemented and intentionally not closed**.

The paid-purchase slice is implemented. A separate asynchronous
negative-balance request/approval queue is not implemented because the current
owner decisions do not define enough of its lifecycle to change financial state
safely.

## Verified baseline

- Starting branch: `phase9e-expense-analysis-report`
- Starting commit: `d8b1962f66306aafbbb4957f427c6d269fe1b724`
- Verified tag: `financial-payment-routing-integrity-verified`
- Phase 81 commit `841301d` and DC-U007 commit `af56ced` are ancestors.
- Starting working tree was clean and the branch was one commit ahead of its
  remote.
- `.build-diagnostics/` is explicitly ignored; no tracked source path is hidden
  by that rule.

## Governing owner decisions

- Phase 78 / DC-U007: negative balance is controlled per financial account;
  each operation that crosses below zero requires an owner approval; non-owner
  operations are blocked; the override is audited.
- The central `PaymentRoutingPolicy` remains authoritative for cash, bank
  transfer, wallet, and cheque rejection.
- No new split-payment, cheque-account, cloud, SaaS, or licensing behavior is
  introduced.

## Paid purchase contract implemented

The purchase-entry UI exposes only two settlement modes:

1. Fully credit: no payment method, financial account, or approval is retained;
   inventory increases and the full amount becomes supplier debt.
2. Fully paid: payment method and compatible active account are mandatory;
   inventory increases, the exact account is debited, and supplier debt remains
   zero.

Cash lists treasury accounts only, bank transfer lists bank accounts only, and
wallet lists electronic-wallet accounts only. Changing the payment method
clears an incompatible account. Cheque is not selectable. The form shows the
current account balance, payment amount, projected balance, and deficit.

The domain repeats route validation. A credit draft that carries hidden payment
data is rejected. A fully-paid draft cannot carry a partial amount. Request-id
replay returns the original purchase once; a changed payload is rejected.

Purchase cancellation reverses stock, the exact original financial account,
and only the supplier liability that actually remained. Local and Drift paths
use their existing repository transaction boundaries. A failure rolls back
purchase, stock, supplier ledger, financial ledger, audit, and approval state.

## Existing negative-balance behavior retained

For a paid purchase with insufficient account balance:

- no purchase, stock movement, supplier entry, or financial entry is created;
- an account with `allowNegativeBalance == false` is blocked with a clear
  deficit message;
- an account with `allowNegativeBalance == true` opens the existing direct owner
  credential approval dialog;
- the approval is bound to account, amount, operation type, stable request ID,
  requester, balance-before, and projected balance;
- the domain rechecks the exact binding and consumes the approval atomically;
- a changed balance or payload makes the approval stale and the purchase is
  rolled back.

This is an immediate, one-time owner authorization. It is not an asynchronous
request queue.

## Owner decision gate for the remaining workflow

The repository currently does not define a safe asynchronous lifecycle:

- `NegativeBalanceApproval` requires `approvedByOwnerUserId` at creation time.
- `requestApproval()` verifies owner credentials before it creates the record.
- `pending` currently means “approved and available for consumption”, not
  “awaiting review”.
- Statuses are `pending`, `consumed`, `expired`, and `revoked`; there is no
  requested, rejected, or requester-cancelled state.
- The production approval repository is in-memory, so a queued request would
  not survive restart and is outside the current backup contract.
- The owner decisions do not say whether self-approval is allowed.
- They do not say whether an approved request should execute automatically,
  remain consumable, or become stale when the balance becomes sufficient.
- They do not define whether a request owns an immutable operation draft or a
  separate pending business document.
- Expense financial entries currently use `system` as the posting actor, which
  cannot safely represent the requesting user in a durable approval binding.

Before implementing the remaining supplier-payment/expense approval queue, the
owner must decide:

1. request-only record versus pending business document;
2. requester and approver permissions, including self-approval;
3. approve-now versus approve-and-execute semantics;
4. stale behavior when balance, amount, route, or source document changes;
5. rejection and requester-cancellation reasons and retention;
6. durable persistence, migration, backup/restore, and owner-wipe coverage;
7. the real expense posting actor instead of the current `system` identity.

No queue schema, RBAC capability, or closure tag is created until these choices
are recorded.

## Verification evidence

- New paid-purchase contract/UI tests: 10 passing.
- Focused purchase, payment-routing, DC-U007, atomicity, durable purchase,
  Phase 79, Phase 80, and Phase 81 set: 184 passing.
- Phase 72 transaction-integration regression set: 43 passing.
- Full suite: 1,480 passing, 1 intentionally skipped, 0 failing.
- `flutter analyze --no-pub`: no issues.
- `flutter build windows --release --no-pub`: passed; produced
  `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`.
- Final diff and working-tree evidence are reviewed before the implementation
  commit. The owner-decision gate remains open after that commit.

## Closure rule

This document must not be relabeled as complete and no Phase 82 closure tag may
be created while the owner-decision gate above remains unresolved.
