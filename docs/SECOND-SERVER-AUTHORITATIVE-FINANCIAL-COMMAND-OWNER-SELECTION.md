# Second server-authoritative financial command — owner selection

## A. Session identity

```text
SESSION = SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND_OWNER_SELECTION_RESOLUTION
SESSION_CLASS = OWNER_DECISION_AUTHORITY_ONLY
EVIDENCE_DATE = 2026-09-06 (Africa/Cairo)
RESULT = PASS
OWNER_SELECTION_STATUS = RESOLVED
PLANNING_STARTED = NO
IMPLEMENTATION_STARTED = NO
```

This is the canonical owner selection for the command family that succeeds the
first server-authoritative financial command. It selects what must be planned
next; it is neither an executable plan nor implementation authority.

## B. Repository identity

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
```

## C. Entry classification

```text
ENTRY_CLASSIFICATION = CASE_A_FRESH
WORKTREE_STATE = CLEAN
INDEX_STATE = CLEAN
STASH_STATE = EMPTY
ACTIVE_GIT_OPERATION = NONE
INDEX_LOCK_STATE = ABSENT
```

No recovery, reset, discard, branch change, remote change, or history rewrite
was used.

## D. Entry remote-lock proof

A fresh fetch and an independent direct query of the authorized branch proved:

```text
LOCAL_HEAD = 88ee8523c26dc8778268ab7317e38a6f998334ba
TRACKING_HEAD = 88ee8523c26dc8778268ab7317e38a6f998334ba
DIRECT_REMOTE_HEAD = 88ee8523c26dc8778268ab7317e38a6f998334ba
MERGE_BASE = 88ee8523c26dc8778268ab7317e38a6f998334ba
AHEAD = 0
BEHIND = 0
```

The initial sandboxed network attempt lacked Windows credentials. The approved
credential-aware retry succeeded; classification relies on that fresh direct
remote observation, not on tracking refs alone.

## E. Predecessor authority

Committed Git objects establish:

```text
PREDECESSOR_COMMIT = 88ee8523c26dc8778268ab7317e38a6f998334ba
PREDECESSOR_PARENT = a5f57c709e1b7e9b3f50d8ae4811951220edf2a6
PREDECESSOR_TREE = 8018fd6f6feb2fb89ca52d4f1e12da1dbc6bd7e0
PREDECESSOR_SUBJECT = docs: record second financial command planning selection blocker
PREDECESSOR_ARTIFACT = docs/SECOND-SERVER-AUTHORITATIVE-FINANCIAL-COMMAND-PLANNING.md
PREDECESSOR_ARTIFACT_BLOB = c4b0f18dac549fc32b766ac595f80b2bbf681306
```

The artifact was read from committed content. It proves that the second
server-authoritative financial-command workstream is current, that customer
collection, supplier payment, and internal transfer are credible candidates,
and that no candidate was canonical. It records implementation as unauthorized
and requires an owner selection before resumed planning.

The committed roadmap authority at `a5f57c709e1b7e9b3f50d8ae4811951220edf2a6`
(parent `dfd3737e58338b3076f4f89ae0757b397d39e38e`) selects this workstream
first while explicitly leaving the command family unresolved. No commit exists
after the predecessor at entry, so there is no newer conflicting owner authority.

## F. Owner decision

```text
SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND = INTERNAL_TRANSFER
OWNER_SELECTED_COMMAND = INTERNAL_TRANSFER
OWNER_SELECTION_STATUS = RESOLVED
PLANNING_AUTHORIZED = NEXT_SESSION_ONLY
IMPLEMENTATION_AUTHORIZED = NO
```

This decision is binding on the next planning session.

## G. Selected command

The selected command family is an internal transfer: one positive monetary
amount moves from one eligible source financial account to one eligible,
different destination financial account within the permitted tenant/business
scope.

## H. Approval model

```text
APPROVAL_MODEL = DIRECT_EXECUTION
```

Migration to server authority must not itself introduce a new approval workflow.
If committed repository behavior already imposes a mandatory transfer approval
rule, later planning must preserve and reconcile it rather than silently delete
it. This decision does not invent an approval subsystem or authorize changes.

## I. Overpayment / excess policy

```text
OVERPAYMENT_POLICY = NOT_APPLICABLE
```

An internal transfer is not settlement of a customer or supplier obligation.
Planning must not invent overpayment, advance allocation, debt settlement,
credit-balance, or payment-remainder behavior unless repository evidence proves
that existing transfer semantics depend on it.

## J. High-level business boundary

The next planning session must evaluate, from repository evidence, source and
destination eligibility, distinct accounts, positive amount, existing currency
assumptions, actor derivation, tenant/business authorization, account-state
mutation, atomic debit/credit, durable server receipt, idempotent replay,
projection after acceptance, and offline/retry behavior.

The owner-level architecture direction is:

```text
application command
    -> server-authoritative transactional acceptance
    -> durable acceptance/receipt
    -> confirmed local projection
```

Trusted actor identity must be server-derived or server-validated. Both transfer
legs must be one atomic financial acceptance. Retry must not duplicate movement.
Server acceptance precedes local projection, and projection repair must never
repost the command. Exact mechanics remain for planning.

## K. Explicitly deferred command families

```text
CUSTOMER_COLLECTION
SUPPLIER_PAYMENT
PURCHASE_INTAKE
CUSTOMER_ADVANCE_APPLICATION
CUSTOMER_ADVANCE_REFUND
SUPPLIER_ADVANCE_APPLICATION
SUPPLIER_ADVANCE_REFUND
SALE_COMMAND_FAMILY
REVERSAL_COMMAND_FAMILY
```

Also deferred are generic financial-command, command-bus, outbox, and inbox
redesigns; expense/PostExpense redesign; logo/report work; unrelated query
migration; new dependencies; database cleanup; unrelated modernization; and
roadmap reordering beyond this selection.

## L. Planning constraints and non-decisions

The next session is planning-only. It must inspect current transfer behavior and
determine the server acceptance, actor authority, atomicity, replay, projection,
and permitted degraded/offline contracts without creating a generic platform.

This owner session does not choose or reserve any RPC name, SQL signature,
migration number, receipt table or JSON schema, Dart handler class, repository
method, controller shape, projection storage, retry queue, account-locking
strategy, ledger schema, test-file list, file delta, permission helper, account
type enum, or currency implementation.

## M. Implementation prohibition

```text
PLANNING_STARTED = NO
IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED = NO
```

No production, test, migration, function, schema, dependency, generated, build,
CI, controller, repository, service, use-case, UI, model, Drift, or sync change
is part of this authority resolution.

## N. Next authorized session

```text
NEXT_AUTHORIZED_SESSION =
INTERNAL_TRANSFER_SERVER_AUTHORITATIVE_COMMAND_PLANNING_ONLY
```

That future session may reconstruct evidence and produce a separately validated,
committed, and remote-locked plan. It must not implement. Implementation requires
separate authority after planning closure.

## O. Delta proof

```text
ALLOWLIST = docs/SECOND-SERVER-AUTHORITATIVE-FINANCIAL-COMMAND-OWNER-SELECTION.md
DOCUMENTATION_FILES_CHANGED = 1
PRODUCTION_FILES_CHANGED = 0
TEST_FILES_CHANGED = 0
MIGRATION_FILES_CHANGED = 0
GENERATED_FILES_CHANGED = 0
DEPENDENCY_FILES_CHANGED = 0
UNRELATED_DOCUMENTATION_FILES_CHANGED = 0
```

The precommit status, diff, staged diff, and whitespace checks must confirm this
exact one-file semantic delta.

## P. Commit and final remote-lock proof

The authority must be committed as a direct child of the predecessor, pushed by
a normal fast-forward to the authorized branch, freshly fetched, and verified
through an independent direct remote query. Required closure is:

```text
OWNER_SELECTION_AUTHORITY = COMMITTED_REMOTE_LOCKED
LOCAL_HEAD = TRACKING_HEAD = DIRECT_REMOTE_HEAD = MERGE_BASE = OWNER_SELECTION_COMMIT
AHEAD = 0
BEHIND = 0
WORKTREE_STATE = CLEAN
INDEX_STATE = CLEAN
STASH_STATE = EMPTY
ACTIVE_GIT_OPERATION = NONE
INDEX_LOCK_STATE = ABSENT
```

The containing commit cannot embed its own stable commit, tree, or artifact-blob
identity. Those observed identities and final direct remote proof belong in the
session report after the normal push; no second evidence commit or amend is
authorized.

```text
SESSION = SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND_OWNER_SELECTION_RESOLUTION
RESULT = PASS
OWNER_SELECTED_COMMAND = INTERNAL_TRANSFER
OWNER_SELECTION_AUTHORITY = COMMITTED_REMOTE_LOCKED
PLANNING_STARTED = NO
IMPLEMENTATION_STARTED = NO
NEXT_AUTHORIZED_SESSION =
INTERNAL_TRANSFER_SERVER_AUTHORITATIVE_COMMAND_PLANNING_ONLY
```
