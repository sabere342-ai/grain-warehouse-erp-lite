# Phase 108J — Atomic Server-Authoritative Expense Posting Plan

## A. Planning status

```text
PHASE = PHASE_108J_PLANNING
IMPLEMENTATION = NOT_STARTED
PHASE_108J_PLANNING
IMPLEMENTATION_NOT_STARTED
PLANNING_RESULT = IMPLEMENTATION_READY
PREREQUISITE_RESULT = MISSING_PREREQUISITES_INCLUDED_AS_SLICE-SPECIFIC_ENABLERS
CANONICAL_COMMAND = EXPENSE_POSTING
COMMAND_NAME = PostExpense
```

This is the canonical implementation plan for one and only one financial
command slice. It records current repository truth, the exact authority and
replay contracts to implement, and deterministic implementation gates. It does
not implement production code, schema, configuration, or tests.

## B. Governing baseline

The plan was prepared from this exact clean baseline:

```text
REPOSITORY = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
HEAD = 69eebcdac20bba12e9b75abaa99c9a2e02df5483
HEAD_SUBJECT = Phase 108J: reconcile governance and freeze canonical scope
HEAD_PARENT = 6896cbd73b271631cda9b31666ab200a6dcac76a
LOCK_TAG = phase-108j-governance-reconciliation-locked
LOCK_TAG_OBJECT = 1b18b22a45ed7f3c39fe72deff3daef34d8b3bd4
LOCK_PEELED_COMMIT = 69eebcdac20bba12e9b75abaa99c9a2e02df5483
REMOTE_BRANCH_HEAD = 69eebcdac20bba12e9b75abaa99c9a2e02df5483
```

The accepted direct chain was revalidated with no merge or hidden commit:

```text
db84293213d99a79b23bf25b81b565c380aa4655  Phase 108F
  -> 5c784d60e7879d18812893a9c9934856e680826e  Phase 108G
  -> f6ed0f8dc7fbb69c763115f4c66502b0d3dcb4c7  Phase 108H
  -> ca533e07dad7d36e2b17d0caa2c1740ee8fa9103  Phase 108I planning
  -> 6896cbd73b271631cda9b31666ab200a6dcac76a  Phase 108I implementation
  -> 69eebcdac20bba12e9b75abaa99c9a2e02df5483  Phase 108J governance
```

All local and independently queried remote annotated tag objects and peeled
commits matched the frozen Phase 108F, 108G, 108H, 108I-planning,
108I-implementation, and 108J-governance values. Rejected commits
`56921729ea927ee7ff45ca67d774847e65c5d499`,
`d61cf78ca9573d42ae4cc40219489a1c6c651bb3`, and
`3b871e4c8836b3a40026c9945bc763f521155143` are not ancestors of this
baseline. The direct parent of the last rejected commit is the required
`d61cf78ca9573d42ae4cc40219489a1c6c651bb3`.

| Lock | Annotated tag object | Peeled commit |
|---|---|---|
| `phase-108f-first-read-only-ui-query-migration-verified` | `df5b895ea266384084f0fbec4b97b510cec5dcb5` | `db84293213d99a79b23bf25b81b565c380aa4655` |
| `phase-108g-session-business-context-boundary-verified` | `54947c27c348c30b66ff2c02584eb6027cf9a325` | `5c784d60e7879d18812893a9c9934856e680826e` |
| `phase-108h-app-shell-runtime-ownership-locked` | `6bd7e338dd9fd64ddfea8845faffbe9102ec09f1` | `f6ed0f8dc7fbb69c763115f4c66502b0d3dcb4c7` |
| `phase-108i-planning-baseline-locked` | `74164b8e342f2ebc372c3429fe2862b7af254c89` | `ca533e07dad7d36e2b17d0caa2c1740ee8fa9103` |
| `phase-108i-second-read-only-ui-query-migration-locked` | `182afda332b3c427b09a04f2652fb606d826e30f` | `6896cbd73b271631cda9b31666ab200a6dcac76a` |
| `phase-108j-governance-reconciliation-locked` | `1b18b22a45ed7f3c39fe72deff3daef34d8b3bd4` | `69eebcdac20bba12e9b75abaa99c9a2e02df5483` |

## C. Frozen scope

The controlling decision is:

```text
OWNER_DECISION_ID = PHASE_108J_SCOPE_RECONCILIATION_DECISION_001
OWNER_DECISION = PHASE_108A_DEFINITION_IS_CANONICAL_FOR_PHASE_108J
PHASE_108J_CANONICAL_SCOPE =
  ONE_ATOMIC_IDEMPOTENT_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND_SLICE
PHASE_108J_DEFAULT_CANDIDATE = EXPENSE_POSTING
```

Phase 108J will implement one vertical command, `PostExpense`. It must not
implement all financial flows, a generic command bus, a generic sync engine, a
general outbox/inbox, a second command family, expense cancellation,
reclassification, negative-balance approval resolution, account creation,
financial closing, sale, purchase, payment, collection, or transfer posting.

## D. Semantic prerequisite revalidation

Numeric phase closure was not treated as semantic closure. The matrix below is
based on the current code, schema, composition, and tests at the governing
baseline.

| Prerequisite | Current evidence | Finding | Phase 108J disposition |
|---|---|---|---|
| FIN-001 transfer double-count proof | `docs/phase-108b/PHASE-108B-TRANSFER-DOUBLE-COUNT-ACCOUNTING-SCENARIO.md` closes FIN-001; full tests pass | `EXISTS_NOW / SATISFIED` | Preserve; no transfer changes |
| Application command seam | `lib/application/commands/application_command.dart` defines typed requests/handlers; `ApplicationBoundary` owns commands | `EXISTS_NOW / PARTIAL` | Extend with one typed `PostExpense` handler, not a bus |
| Central composition ownership | `AppCompositionRoot.initializeProduction` owns runtime construction; Phase 108H tests pass | `EXISTS_NOW / SATISFIED` | Compose the command gateway, projection writer, and handler there |
| Session context | `LocalSessionContextProvider` contains only a locally authenticated `userId` | `EXISTS_NOW / INSUFFICIENT_FOR_SERVER_AUTHORITY` | Cloud-mode session must come from an authenticated Supabase session; local identity is never server proof |
| Business context | production deliberately uses `NoBusinessContextProvider`; Phase 108G/H tests assert `current == null` | `MISSING` | Add a membership-derived cloud business context only when a verified active membership is loaded |
| Server authentication and revocation | `DriftAuthRepository` is local; Firebase is an intentionally unconfigured bootstrap | `MISSING` | Narrow cloud-mode Supabase Auth adapter is a required slice enabler |
| Tenant membership / RLS | no `business_id`, membership table, RLS policy, or server claims exist | `MISSING` | Minimal business/membership schema and default-deny policies are required for this slice |
| Supabase environment/runtime | no Supabase dependency, directory, configuration, RPC, or generated types exist | `MISSING` | Add the smallest environment/client boundary and one SQL migration/function |
| Original Phase 108I cloud catalog read | actual Phase 108I migrated document history through a local read-only application query | `NOT IMPLEMENTED / NOT REQUIRED BY EXPENSE_PAYLOAD` | Do not add product/catalog work; depend only on the proven application-boundary pattern |
| Financial-account server state | current accounts, entries, balances, and closings exist only in local SQLite | `MISSING` | A controlled pilot bootstrap/reconciliation for the selected account is required before enabling `PostExpense` |
| Expense idempotency precursor | `operationRequestId`, fingerprint, and a unique SQLite index exist | `EXISTS_NOW / LOCAL_ONLY` | Reuse the concept, replace authority with a durable server receipt and server-computed fingerprint |
| Atomic expense behavior | expense + account entry + audit are coordinated by `RepositoryTransaction` snapshots; rollback tests pass | `EXISTS_NOW / LOCAL COMPENSATION ONLY` | Preserve behavior in one PostgreSQL transaction; snapshots are not server authority |
| Audit boundary | expense and financial-entry audits exist and Phase 108F provides a read seam | `EXISTS_NOW / LOCAL_ONLY` | Create one authoritative server audit event in the same transaction and project it locally |
| Durable generic outbox | absent | `MISSING / NOT REQUIRED` | Do not build it; use one expense-specific attempt store and explicit/manual retry only |

The governance result is therefore option B:

```text
MISSING_PREREQUISITES_MUST_BE_INCLUDED_AS_MINIMAL_ENABLERS
```

Those enablers are restricted to an authenticated pilot session, one verified
business membership, the selected financial account and its reconciled opening
state/closed-period facts, one expense RPC, and one expense-specific local
attempt/projection path. They do not authorize broad Cloud migration.

## E. Canonical command selection

`EXPENSE_POSTING` remains selected. It is the smallest currently implemented
money-moving workflow: it has no inventory, customer, supplier, COGS, payable,
or receivable effect. Its current successful path already has a required
account, payment routing, an expense record, one outflow entry, audit records,
request identity, fingerprint comparison, balance validation, and rollback
tests. No alternative command is lower risk or more canonical.

The command name for new application and server code is `PostExpense`. Existing
names such as `ExpenseDraft`, `ExpenseRecord`, and `ExpenseRepository` remain
domain/persistence names; they must not be relabeled into a generic command
framework.

## F. Current-state architecture

### Current UI-to-storage path

```text
ExpensesScreen
  -> reads AuthScope local AppUser
  -> generates expense-ui-<microseconds>-<local-user-id>
  -> NegativeBalanceApprovalWorkflowService.submitExpense
  -> local AuthRepository permission check
  -> local FinancialAccountRepository routing/balance check
  -> ExpenseRepository.createExpense
  -> DriftExpenseRepository / RepositoryTransaction snapshots
     -> SQLite expenses row
     -> LocalFinancialAccountRepository.createEntry
        -> hydrated in-memory entry collection
        -> full-table Drift persistence of financial aggregates
        -> financial_account.entry.created audit row
     -> expense.created audit row
```

`ExpensesScreen` still resolves `AppRepositories` directly and does not use
`ApplicationScope` for writes. `ApplicationCommands` contains only the trial
evaluation handler. The current expense controller can call the repository
directly, but the production screen uses the negative-balance workflow.

### Current authoritative path

The only authority today is the local application process plus its SQLite file.
There is no remote call. `RepositoryTransaction` serializes in-process writes
and rolls repositories back from snapshots. Drift repositories also use
individual SQLite transactions and some adapters persist hydrated aggregates by
rewriting complete tables. This is tested local compensation, not one database
transaction shared with a server and not safe multi-device authority.

### Current expense persistence

`Expenses` (schema version 15) contains:

- `id`, business date, category, positive integer qirsh amount, notes;
- local creation time and optional local actor;
- financial-account ID and payment method;
- nullable unique `operation_request_id` and fingerprint;
- accounting classification.

`FinancialAccountEntries` contains the selected account, `outflow`, positive
qirsh, source `expense`, expense ID, effective date, actor, route, approval
metadata, and annotations. `AuditLogs` stores local timestamp, action, actor,
reference, and JSON metadata.

The current expense lifecycle has no edit/delete/cancellation method. Historical
classification can be changed by an owner through a separate audited method;
that method is outside Phase 108J.

## G. Accounting model and invariants

The application uses single-entry operational account ledgers, not a general
double-entry journal. There is no journal header or debit/credit line pair for
an expense. The command must preserve this model and must not create a second
accounting truth.

| Truth | Current source | Phase 108J authoritative source |
|---|---|---|
| Expense truth | `expenses` rows | server `expenses` row accepted by `PostExpense` |
| Ledger truth | `financial_account_entries` | server expense outflow entry |
| Balance truth | sum of signed account entries; opening balance is also represented by an inflow entry | server sum of accepted entries while holding the account lock |
| Operating-expense truth | expense rows whose classification is `operating` | accepted server expense rows, projected locally |
| Audit truth | local `audit_logs` | append-only server audit event, then local acknowledged projection |

Required invariants:

1. `amountQirsh` is an integer greater than zero; floating currency is forbidden.
2. Category is trimmed and non-empty; notes normalize blank to null.
3. Classification is exactly `operating`, `capital`, or `nonOperating`.
4. Payment method is one of `cash`, `bankTransfer`, or `mobileWallet` and
   matches account type `treasury`, `bank`, or `electronicWallet` respectively.
   `check` remains rejected.
5. Account exists in the same business, is active, is Cloud-ready, and is
   locked while balance and posting rules are checked.
6. Business date is not in an accepted closed financial period and is not an
   invalid future date under the frozen server policy.
7. A successful command creates exactly one expense row and exactly one
   outflow account entry with source `expense` and source document equal to the
   expense ID.
8. Balance after posting equals balance before minus the expense amount.
9. Phase 108J does not accept a posting that would make the balance negative.
   If account policy could permit it, return `approvalRequired`; do not consume
   or implement the separate approval workflow.
10. Two authoritative audit events preserve the current distinct meanings:
    `financial_account.entry.created` references the ledger entry and
    `expense.created` references the expense. Their metadata identifies the
    shared command, expense, actor, business, account, and server timestamp.
11. Exact replay creates no additional expense, entry, audit, or balance effect.
12. No client timestamp, local counter, or UI-generated record ID becomes the
    authoritative accepted/posted time or financial record ID.

## H. Command contract

### Input

`PostExpenseCommand` is immutable and transport-safe:

```text
commandId: UUIDv7 preferred; UUIDv4 accepted fallback
schemaVersion: 1 (constant, not UI-editable)
businessId: UUID copied from verified BusinessContext; routing only
businessDate: date-only YYYY-MM-DD
category: string
amountQirsh: positive integer
notes: nullable string
financialAccountId: server UUID from a verified local account link
paymentMethod: cash | bankTransfer | mobileWallet
accountingClassification: operating | capital | nonOperating
```

The command must not contain `createdByUserId`, role, permission flags,
membership ID, server timestamps, ledger IDs, expense IDs, audit IDs,
negative-balance approval IDs, or a client-computed trusted fingerprint. Actor,
membership, and permission come from the authenticated server session.

### Application request and context

The handler accepts `ApplicationCommandRequest<PostExpenseCommand>`. Its
`idempotencyKey` must equal `command.commandId`; mismatch is an application
validation failure. `businessContext` is mandatory and must agree with the
membership-derived runtime context. The existing nullable generic fields remain
for compatibility, but this handler treats absence as failure.

### Output

The slice-specific result is a closed union, kept with the command rather than
introducing a generic result framework:

```text
PostExpenseSuccess {
  commandId,
  businessId,
  expenseId,
  financialEntryId,
  auditEventIds, // exactly the financial-entry and expense audit event IDs
  serverAcceptedAtUtc,
  businessDate,
  amountQirsh,
  balanceAfterQirsh,
  replayed
}

PostExpenseFailure {
  commandId,
  category,
  code,
  retryable,
  fieldErrors,
  diagnosticReference?
}
```

`replayed` is presentation/diagnostic information only. An exact replay is a
successful canonical result and is financially indistinguishable from the
first response.

## I. Idempotency contract

### Generation and ownership

The application generates `commandId` once when the user confirms an intent,
before network submission. It is stored durably in the expense-specific local
attempt row before the first request. Editing a materially submitted payload
creates a new command ID; retry never regenerates it.

### Canonical fingerprint

The server computes SHA-256 over a canonical JSON object containing:

```text
commandType = post_expense
schemaVersion = 1
businessId
actorAuthUserId
businessDate
trimmed category
amountQirsh
blank-to-null trimmed notes
financialAccountId
paymentMethod
accountingClassification
```

JSON keys are fixed and sorted by the server expression. Client fingerprints
may be logged or tested but are never trusted.

### Durable receipt

The planned server receipt has a primary/unique key on
`(business_id, command_type, command_id)`. It persists the fingerprint, actor,
accepted status, canonical result JSON, and server timestamps. Expense rows
also have a unique business/command association, and ledger entries have a
unique business/source-type/source-document association as defense in depth.

### Server algorithm

1. Authenticate and resolve active membership.
2. Normalize input and compute the server fingerprint.
3. Attempt to insert the receipt key inside the same transaction.
4. On an existing key, wait for the owning transaction, load the receipt, and:
   - return its stored result when type, business, actor, and fingerprint match;
   - return `idempotencyConflict` without mutation otherwise.
5. On a new key, validate and perform all writes, store the result in the
   receipt, and commit once.

If the first transaction rolls back, its receipt insert also rolls back; a
retry can become the first accepted execution. Process-memory maps, button
disabling, local SQLite uniqueness, and client fingerprints are not authority.

## J. Transaction boundary

One PostgreSQL function/RPC, `post_expense_v1`, owns one implicit PostgreSQL
transaction containing all authoritative work:

1. membership/permission verification reads;
2. receipt reservation and later canonical result update;
3. selected financial-account row lock;
4. closed-period and payment-route validation;
5. authoritative balance calculation;
6. expense row insert;
7. one financial-account outflow entry insert;
8. the `financial_account.entry.created` and `expense.created` authoritative
   audit event inserts.

Any exception rolls back the receipt, expense, entry, and both audit events
together.
There is no partially accepted state. Validation, authentication,
authorization, insufficient balance, approval requirement, and conflicting
replay produce no authoritative mutation.

The local projection is a separate post-commit SQLite transaction. A local
projection failure cannot undo a committed server command and must not be
reported as a failed financial post. It marks the local attempt
`confirmedProjectionPending`; exact replay retrieves the stored server result
and retries the idempotent projection. Projection upserts by server IDs and
command ID, so it cannot double-post locally.

## K. Authorization and business boundary

The RPC is callable only by Supabase `authenticated`; direct table mutations by
`anon` or ordinary authenticated clients are revoked/denied. A hardened
`security definer` function must set an explicit safe `search_path`, use
`auth.uid()`, and perform these checks itself:

- authenticated user exists;
- one active membership exists for the requested business;
- membership role maps to current `canCreateExpense` semantics (owner and
  employee are allowed);
- selected account belongs to that business and is active;
- command receipt actor either matches the caller on replay or the call fails
  without exposing another actor's result.

`businessId` supplied by the client is never authority. Cross-business account
IDs, stale/revoked memberships, local roles, local `createdByUserId`, and an
unavailable `BusinessContext` fail closed. RLS is default deny and allows only
membership-scoped reads required for the acknowledged projection; raw inserts,
updates, and deletes remain unavailable.

## L. Offline and connectivity semantics

Choose a narrowly bounded form of option B:

```text
EXPENSE_OFFLINE_MODEL =
  EXPENSE_SPECIFIC_DURABLE_COMMAND_ATTEMPT_WITH_NO_LOCAL_AUTHORITATIVE_POSTING
GENERIC_SYNC_ENGINE = NOT_INCLUDED
BACKGROUND_AUTOMATIC_RETRY = NOT_INCLUDED
```

The app may durably retain a `PostExpense` intent and show it as queued or
unknown-outcome, but it must not insert an authoritative local expense, ledger
entry, audit event, or balance effect before server acceptance. Submission and
retry require connectivity. Retry is explicit/user-driven in this phase; the
same command ID is reused. A restart preserves the intent/result receipt needed
to resolve a timeout-after-commit safely. General dependency ordering,
backoff, poison queues, cursors, inboxes, and multi-command synchronization are
deferred.

The UI states for this slice are:

```text
draft -> queued -> sending -> confirmed
                         -> confirmedProjectionPending -> confirmed
                         -> rejected
                         -> unknownOutcome -> sending (same commandId)
```

Only `confirmed` may affect local financial reports/balances. Queued and unknown
attempts are visibly non-authoritative.

## M. Error contract

| Category/code | Server/local meaning | Retry | UI behavior |
|---|---|---|---|
| `validation.invalidField` | malformed date/category/amount/notes/enum/UUID | No until edited with a new command ID | field-specific Arabic errors |
| `unauthenticated.sessionRequired` | no valid remote session | After sign-in | retain attempt; request sign-in |
| `unauthorized.expensePostingDenied` | inactive membership/role denied | No automatic retry | access-denied message |
| `wrongBusinessContext` | context, membership, account, or receipt business mismatch | No | block and require safe context refresh |
| `account.notFoundOrInactive` | selected server account unavailable | After explicit account refresh/change | do not fall back to local posting |
| `paymentRoute.invalid` | method incompatible; cheque rejected | No until edited | route-specific validation |
| `period.closed` | date belongs to accepted closed period | No until corrected/reopened elsewhere | closed-period message |
| `balance.insufficient` | projected balance below zero and policy disallows it | No until state/input changes | show current authoritative insufficiency |
| `approvalRequired` | negative result would require the separate owner approval workflow | No in this phase | explain that this slice cannot post it |
| `idempotencyConflict` | same key, materially different fingerprint/type/business/actor | Never retry as-is | permanent safe error; require new intent/key |
| `serverUnavailable` | connectivity/timeout/5xx with unknown commit state | Yes, same key only | `unknownOutcome`, retain retry action |
| `transactionFailure` | server aborted before commit | Yes only when server marks retryable | no local financial mutation |
| `projectionFailure` | server confirmed but SQLite projection failed | Yes, replay/projection only | show confirmed + refresh needed, never “post failed” |
| `unexpectedServerError` | sanitized unexpected failure with diagnostic reference | Per server flag | safe generic message |

Infrastructure exceptions are mapped at the gateway. The screen must receive
only the closed result union and must not parse PostgREST strings or construct
financial mutations.

## N. Replay semantics

### Exact replay

Same command ID, command type, normalized payload, business, and actor returns
the previously stored canonical result with `replayed = true`. It creates zero
new authoritative rows and zero new balance effect. It may safely repair a
missing local projection.

### Conflicting replay

Same command ID with any materially different normalized field, command type,
business, or actor returns `idempotencyConflict`. The server neither treats it
as success nor reveals the stored result to a different actor. The client marks
the attempt permanently conflicted; only an explicitly new user intent may use
a new command ID.

## O. Schema and migration plan

### Server migration (planned new)

Create
`supabase/migrations/20260823000000_phase_108j_post_expense.sql`. Because the
repository has no Supabase schema convention today, this is the first and only
Phase 108J server migration. It must be additive and include only:

- `businesses` and `business_memberships` minimal rows/constraints needed for
  authenticated pilot tenancy;
- `financial_accounts` fields needed to identify the business, legacy mapping,
  account type/active/negative policy, and concurrency lock target;
- `financial_period_closures` minimal accepted closed-date facts used by this
  command;
- `expenses` fields matching the command and existing reporting semantics;
- `financial_account_entries` fields needed for the existing operational
  ledger model;
- `financial_command_receipts` for durable idempotency/result replay;
- `audit_events` for the two authoritative events that preserve existing
  action semantics;
- required foreign keys, positive-amount checks, enum/check constraints,
  uniqueness, indexes, RLS, grants/revokes, and `post_expense_v1`.

Do not add sale, purchase, party, inventory, valuation, general journal,
approval-request, generic outbox, sync cursor, Realtime, Storage, or Edge
Function schema.

The SQL must be forward-additive. Its rollback for development is deletion of
the isolated test project/database or an explicit reverse migration before any
accepted production data; destructive rollback of accepted financial rows is
not allowed.

### Local Drift migration (planned schema version 16)

Add exactly two Phase-specific tables in `foundation_database.dart`:

1. `FinancialAccountCloudLinks`: local account ID, business ID, server account
   UUID, reconciled server balance/date/version, and readiness timestamp; unique
   by local account and by `(business, server account)`.
2. `ExpensePostingAttempts`: command ID primary key, business ID, canonical
   payload JSON, local fingerprint, lifecycle state, canonical server result
   JSON if known, timestamps, attempt count, and sanitized last error.

No generic command/outbox table is introduced. The migration creates empty
tables only and does not reinterpret historical expenses or account entries.
Generated Drift code changes are mechanical and must be regenerated from the
schema.

### Controlled pilot bootstrap prerequisite

Cloud-mode expense posting stays disabled until an operator-controlled pilot
bootstrap has:

- provisioned a Supabase Auth user and active business membership;
- created the business and selected remote financial account;
- reconciled the local account's current derived balance into one auditable
  server opening entry at a declared cutover time;
- copied any active closed-period facts required to prevent back-posting;
- written the verified local-to-server account link;
- proven local balance, server opening balance, account type, negative policy,
  and closed-period state match.

This is not a generic migration/import feature and is not exposed as another
application command. Existing local history remains preserved. A mismatch
blocks the slice; it is never silently corrected or uploaded by `PostExpense`.

## P. Application integration plan

The intended production chain is:

```text
ExpensesScreen
  -> ApplicationScope.of(context).commands.postExpense
  -> PostExpenseCommandHandler
     -> verified SessionContext + BusinessContext
     -> ExpensePostingAttemptStore (durable commandId before send)
     -> ExpensePostingGateway
        -> Supabase RPC post_expense_v1
     -> ConfirmedExpenseProjectionWriter
        -> one local SQLite projection transaction
     -> PostExpenseResult
  -> refresh ExpenseController/read models after confirmed projection
```

Responsibilities:

- UI performs only syntactic form validation, creates a draft intent, displays
  lifecycle/errors, and invokes retry with the same stored command.
- Handler requires context, enforces attempt lifecycle, invokes the gateway,
  maps the result, and requests projection.
- Gateway owns transport/authenticated RPC mapping only; it contains no ledger
  construction policy.
- Server owns authorization, business binding, fingerprint, IDs, time,
  validation, balance, ledger, audit, receipt, and transaction.
- Projection writer upserts the returned confirmed expense, entry, and audit
  IDs into SQLite and refreshes the hydrated financial-account adapter before
  ordinary reads resume.

The screen must stop resolving `AppRepositories.expenseRepository`,
`financialAccountRepository`, and `negativeBalanceApprovalWorkflowService` for
the Phase 108J posting path. Existing read/reclassification behavior may remain
temporarily on characterized legacy dependencies if changing it is not needed
for this command. Direct local `createExpense` must not be a fallback when the
server is unavailable.

## Q. Test and verification plan

### Dart unit/application tests

- command normalization and UUID/schema validation;
- mandatory verified session and business context;
- attempt stored before gateway invocation;
- exact retry reuses command ID and payload;
- conflicting local attempt fails before transport;
- every gateway error maps to the stable result category;
- server success triggers projection once;
- server success plus projection failure remains confirmed and repairable;
- UI calls only the application handler and renders queued, sending,
  unknown-outcome, confirmed, approval-required, and permanent errors.

### Local Drift integration tests

- schema v15 to v16 is additive and preserves all existing rows;
- account-link uniqueness and missing-link fail closed;
- attempt survives close/reopen and retains the exact command ID/payload;
- confirmed projection inserts one expense, one outflow entry, and the two
  distinct audit events;
- exact projection replay is a no-op;
- injected projection failure rolls the local projection transaction back;
- financial repository rehydration exposes the new balance without full app
  restart;
- local reports include only confirmed, not queued, expense attempts.

### PostgreSQL/Supabase database tests

Use a local/ephemeral Supabase database and transaction-isolated SQL tests for:

1. successful first post;
2. same-key exact sequential replay;
3. concurrent exact replay;
4. same-key changed category/amount/account/business/actor conflict;
5. unauthenticated caller;
6. authenticated caller without membership;
7. inactive/wrong-role membership;
8. cross-business account attempt;
9. inactive/missing account;
10. each valid payment route and invalid/check routes;
11. zero/negative amount, blank category, invalid classification/date;
12. closed-period failure;
13. insufficient balance;
14. negative-balance approval-required path;
15. injected failure after expense, after ledger, and before receipt completion,
    each proving zero committed rows/effect;
16. one expense + one ledger entry + two distinct audits + one completed receipt;
17. derived balance decreases exactly once;
18. server timestamps and IDs are independent of client clock;
19. direct table writes denied while membership-scoped reads obey RLS.

### Existing regression tests

At minimum retain and run:

```text
flutter test test/phase8j_durable_expense_repository_test.dart
flutter test test/financial_payment_routing_integrity_test.dart
flutter test test/phase82_negative_balance_approval_workflow_test.dart
flutter test test/negative_balance_approval_atomicity_test.dart
flutter test test/phase9a_inflows_outflows_reports_test.dart
flutter test test/phase108g_session_business_context_boundary_test.dart
flutter test test/phase108h_app_shell_runtime_ownership_test.dart
flutter test test/phase108i_second_read_only_ui_query_migration_test.dart
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
```

The Phase 108G/H expectations that business context is absent must be updated
only for explicitly configured Cloud mode; local-only mode must keep the
truthful unavailable state. No test may manufacture a business ID from a local
user ID.

## R. File-level implementation map

Names below marked `PLANNED_NEW` are intentionally frozen by this plan; the
implementation session may split a test file only when a tool-enforced SQL test
layout requires it.

### Create

| File | Status/purpose |
|---|---|
| `lib/application/commands/post_expense_command.dart` | `PLANNED_NEW`: command, closed result/failure union, handler |
| `lib/application/expenses/expense_posting_gateway.dart` | `PLANNED_NEW`: use-case-specific remote port |
| `lib/application/expenses/expense_posting_attempt_store.dart` | `PLANNED_NEW`: slice-specific durable attempt port/model |
| `lib/application/expenses/confirmed_expense_projection_writer.dart` | `PLANNED_NEW`: acknowledged projection port/model |
| `lib/infrastructure/supabase/supabase_expense_posting_gateway.dart` | `PLANNED_NEW`: authenticated RPC adapter |
| `lib/infrastructure/supabase/supabase_cloud_session_adapter.dart` | `PLANNED_NEW`: Supabase session/membership-to-context adapter for configured Cloud pilot mode |
| `lib/infrastructure/supabase/supabase_runtime_config.dart` | `PLANNED_NEW`: validated non-secret URL/publishable-key configuration boundary; Cloud mode stays disabled when absent |
| `lib/core/expenses/drift_expense_posting_attempt_store.dart` | `PLANNED_NEW`: Drift attempt adapter |
| `lib/core/expenses/drift_confirmed_expense_projection_writer.dart` | `PLANNED_NEW`: one-transaction projection/upsert adapter |
| `supabase/migrations/20260823000000_phase_108j_post_expense.sql` | `PLANNED_NEW`: minimal server schema/RLS/RPC |
| `supabase/tests/phase_108j_post_expense_test.sql` | `PLANNED_NEW`: server authority/idempotency/atomicity tests |
| `test/phase108j_post_expense_command_test.dart` | `PLANNED_NEW`: command/handler/error/attempt tests |
| `test/phase108j_expense_projection_test.dart` | `PLANNED_NEW`: Drift migration/projection/recovery tests |
| `test/phase108j_expense_ui_integration_test.dart` | `PLANNED_NEW`: typed seam and lifecycle UI tests |

### Modify

| File | Exact reason |
|---|---|
| `pubspec.yaml`, `pubspec.lock` | add the official Supabase Flutter client and UUID support selected by implementation verification; no unrelated dependency upgrades |
| `lib/application/application_boundary.dart` | expose exactly one `postExpense` command handler |
| `lib/application/application_dependencies.dart` | expose only dependencies required by the new handler/session/context |
| `lib/application/context/session_context.dart` | represent verified remote session identity without treating local user ID as proof |
| `lib/application/context/business_context.dart` | provide verified replace/clear lifecycle for Cloud mode; preserve no-context local mode |
| `lib/composition/app_composition_root.dart` | own client/session/gateway/store/projection/handler lifetimes |
| `lib/composition/legacy_application_dependency_bridge.dart` | bridge only shared legacy reads/projection dependencies still required during the slice |
| `lib/core/persistence/foundation_database.dart` | schema v16 tables for account links and expense attempts |
| `lib/core/persistence/migration_strategy.dart` | additive v16 migration only |
| `lib/core/persistence/foundation_database.g.dart` | generated Drift output only |
| `lib/core/financial_accounts/drift_financial_account_repository.dart` | add serialized projection refresh so direct confirmed upserts cannot be overwritten by stale hydrated state |
| `lib/features/expenses/expenses_screen.dart` | invoke the application command, show lifecycle/errors, remove local-authoritative posting fallback |
| `lib/core/expenses/expense_controller.dart` | refresh/read handling after confirmed projection; no direct production create path |
| existing Phase 108G/H/I architecture tests | preserve local-mode invariants while proving configured Cloud context and one new command seam |

The exact Supabase package version must be resolved against the implementation
session's current official package documentation and locked in `pubspec.lock`;
the planning session does not change dependencies.

### Leave untouched

- sale, purchase, customer, supplier, inventory, valuation, transfer, closing,
  and approval command implementations;
- existing Phase 108F/108G/108H/108I governance/planning documents and tags;
- existing SQLite expense/history data and migrations 1 through 15;
- Firebase bootstrap (unrelated inactive scaffold);
- platform signing, installer, release, backup/restore, and deployment files
  except any separately authorized environment mechanism strictly required by
  Supabase configuration.

## S. Ordered implementation sequence

1. Reverify the locked planning baseline and remote planning lock in the next
   authorized implementation session; stop on mismatch.
2. Add failing Dart contract tests for command normalization, contexts, stable
   results, attempt lifecycle, and no direct repository write from the UI.
3. Add the isolated Supabase migration and failing SQL tests; first prove
   default-deny access and transaction rollback.
4. Implement minimal pilot business/membership/account/closure schema, grants,
   RLS, receipt uniqueness, and `post_expense_v1`.
5. Make SQL tests pass for success, exact/conflicting/concurrent replay,
   cross-business denial, accounting invariants, and injected rollback.
6. Add Supabase/UUID dependencies without unrelated upgrades and implement the
   configured Cloud session adapter. Keep local-only mode truthful and working.
7. Implement `PostExpenseCommand`, its slice-specific result, gateway port, and
   Supabase RPC adapter. No generic dispatcher/repository is added.
8. Add Drift schema v16, regenerate code, and implement the account-link and
   expense-attempt store with restart-safe command identity.
9. Implement the confirmed projection writer and serialized financial adapter
   refresh; prove replay-safe local projection and recovery after a server
   success/local failure split.
10. Compose exact production instances in `AppCompositionRoot` and expose the
    one handler through `ApplicationCommands`.
11. Migrate only expense submission in `ExpensesScreen` to the typed handler;
    preserve expense reads and reclassification semantics outside the command.
12. Provision and reconcile an isolated pilot membership/account. Block command
    availability unless every readiness comparison passes.
13. Run targeted SQL/Dart/UI tests, all existing regression tests, analyzer,
    formatter, and the full suite. Inspect schema/generated diffs and secrets.
14. Perform first-post, timeout/replay, conflicting replay, wrong-business,
    rollback, and projection-repair acceptance against the isolated server.
15. Record evidence and stop. Do not broaden into another financial command or
    general sync/outbox work.

## T. Acceptance criteria

Phase 108J implementation is complete only when every gate is binary PASS:

1. One UI action reaches only `PostExpenseCommandHandler`; no direct local
   authoritative expense creation remains in its production success path.
2. A valid authenticated member posts exactly one server expense, one outflow
   entry, the two distinct audit events, and one completed receipt in one
   transaction.
3. Server-derived balance decreases by the exact qirsh amount once.
4. Exact sequential and concurrent replay return the stored canonical result
   with no additional mutation.
5. Same-key changed payload/business/actor fails as an idempotency conflict.
6. Every injected server failure proves complete rollback, including receipt.
7. Unauthenticated, unauthorized, revoked, stale-context, and cross-business
   attempts fail before financial mutation.
8. Payment route, account state, closed period, amount, category,
   classification, and date validation match the frozen rules.
9. Negative-balance cases do not post; approval-required cases stay outside
   this command family.
10. Server IDs and timestamps, not client clock/counters, identify accepted
    records.
11. The command attempt survives restart; timeout retry uses the same ID.
12. No queued/unconfirmed attempt affects SQLite expenses, ledger, reports, or
    balances.
13. Confirmed projection is idempotent; projection failure cannot convert a
    server success into a second financial post.
14. Local-only mode remains supported and does not fabricate Cloud context.
15. Direct client writes to authoritative tables are denied; membership reads
    are business-scoped.
16. No service-role secret or user token is committed, logged, backed up, or
    stored in ordinary SQLite business tables.
17. Full Dart tests, focused tests, SQL tests, analyzer, and formatter pass.
18. The implementation diff contains only the file map or an explicitly
    justified narrower subset; no second command family or generic sync system
    appears.

## U. Explicit non-goals

- all financial commands or a reusable command platform;
- generic outbox/inbox, background sync, cursoring, Realtime, conflict engine,
  or multi-command retry scheduler;
- expense cancellation, deletion, editing, or reclassification migration;
- negative-balance approval request/approve/reject/consume implementation;
- financial account CRUD, opening-balance UI, transfer, closing/reopening;
- sale, purchase, customer/supplier payment, advance, inventory, valuation, or
  product Cloud migration;
- double-entry redesign, general ledger/chart of accounts, mutable balance
  columns, or a second accounting truth;
- broad local-to-Cloud data migration, backup restore, tenant self-service,
  multi-business UI, multi-warehouse rollout, billing, or licensing;
- automatic upload of existing local history;
- production deployment, customer cutover, remote lock, or tag creation in the
  implementation-planning session.

## V. Risks and blockers

### Blocking implementation preconditions

- A Supabase project/environment and safe client configuration must exist; no
  project, URL, publishable key, or secret is present in the repository now.
- The pilot Supabase user, active membership, business, account, opening
  balance, and closed-period facts must be provisioned and reconciled before a
  real post can be enabled.
- Official current Supabase Flutter/API behavior must be verified when pinning
  dependencies and RPC error mapping.
- SQL tests must demonstrate that the minimal schema/RLS/function actually
  provides the semantics in this plan. Failure blocks implementation closure.

These are deployment/readiness inputs, not reasons to substitute local
authority or widen the command.

### Non-blocking risks

- The financial account adapter hydrates and rewrites complete tables; the
  planned serialized refresh must be proven against stale overwrite races.
- Existing local and server expense IDs will coexist in one text-key cache;
  projection tests must keep legacy records immutable and server IDs exact.
- Existing reports are local and can be stale until acknowledged projection;
  only the new attempt lifecycle must distinguish this in Phase 108J.
- The existing UI command ID uses time and local user text; the new UUID path
  must not reuse that generator.
- Network timeouts after commit require disciplined same-key retry; any path
  that generates a new key is a stop condition.

### Owner-decision-required items

- Select the isolated Supabase dev/test project and authorize its external
  provisioning/deployment in the implementation session.
- Identify the pilot business, user membership, and financial account whose
  balance/closing facts will be reconciled.
- Production/customer rollout remains a separate owner decision after Phase
  108J evidence; successful implementation does not authorize rollout.

No owner decision is required to change the command candidate: expense posting
remains canonical.

## W. Baseline health recorded during planning

```text
flutter analyze
PASS — No issues found (87.1 seconds)

dart format --output=none --set-exit-if-changed lib test
PASS — 443 files, 0 changed (3.82 seconds)

flutter test
PASS — 2,469 tests (4 minutes 12 seconds)

flutter test <8 focused expense/accounting/context files>
PASS — 120 tests (19.85 seconds)
```

The literal prior-plan command
`dart format --output=none --set-exit-if-changed .` was also attempted before
any mutation. It produced no diagnostic but traversed ignored build artifacts
indefinitely and was interrupted after approximately five minutes. The scoped
`lib test` command covers all 443 tracked Dart source/test files and completed
cleanly. The planning document itself is Markdown and does not affect Dart
formatting.

## X. Planning closure

This plan freezes a coherent single vertical slice despite missing original
Phase 108A Cloud prerequisites by including only command-specific enablers. It
does not claim that the accepted numeric Phase 108H or 108I implemented
Supabase auth, tenancy, RLS, catalog Cloud reads, RPC infrastructure, or
financial server state.

```text
PHASE_108J_PLANNING = COMPLETE_WHEN_LOCALLY_COMMITTED
PHASE_108J_IMPLEMENTATION = NOT_STARTED
CANONICAL_COMMAND = PostExpense
SERVER_AUTHORITY = REQUIRED
LOCAL_SQLITE_ROLE_AFTER_ACCEPTANCE = ACKNOWLEDGED_PROJECTION_ONLY
NEXT_PHASE_CONTENT_ACTION = NONE_UNTIL_PLANNING_REMOTE_LOCK
```
