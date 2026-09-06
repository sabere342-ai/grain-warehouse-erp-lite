# Internal Transfer server-authoritative command planning

## A. Session authority

```text
SESSION = INTERNAL_TRANSFER_SERVER_AUTHORITATIVE_COMMAND_PLANNING_ONLY
EVIDENCE_DATE = 2026-09-06 (Africa/Cairo)
AUTHORIZED_BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
AUTHORIZED_REMOTE = origin
OWNER_SELECTION_AUTHORITY = a8ac2e2535943361cc2d40c2ddcd4ec7ba4552bc
OWNER_SELECTED_COMMAND = INTERNAL_TRANSFER
APPROVAL_MODEL = DIRECT_EXECUTION
OVERPAYMENT_POLICY = NOT_APPLICABLE
IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED = NO
```

This artifact is the implementation-grade plan for exactly one command: a
positive monetary transfer between two distinct eligible financial accounts in
one authorized business. It creates no implementation, migration, schema,
function, Dart, UI, sync, test, fixture, generated-code, or dependency change.

## B. Repository and entry proof

The fail-closed entry checks observed:

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
ENTRY_CLASSIFICATION = CASE_A_FRESH
RECOVERY_USED = NO

ENTRY_LOCAL_HEAD = a8ac2e2535943361cc2d40c2ddcd4ec7ba4552bc
ENTRY_TRACKING_HEAD = a8ac2e2535943361cc2d40c2ddcd4ec7ba4552bc
ENTRY_DIRECT_REMOTE_HEAD = a8ac2e2535943361cc2d40c2ddcd4ec7ba4552bc
ENTRY_MERGE_BASE = a8ac2e2535943361cc2d40c2ddcd4ec7ba4552bc
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0

WORKTREE = CLEAN
INDEX = CLEAN
STASH = EMPTY
ACTIVE_GIT_OPERATION = NONE
INDEX_LOCK = ABSENT
DIFF_CHECK = PASS
```

The first sandboxed fetch lacked Windows credentials. An approved
credential-aware `git fetch origin` then succeeded, and `git ls-remote` supplied
the direct head above. No remote, branch, worktree, stash, or history repair was
performed.

## C. Owner-selection authority

Git object inspection, not the session prompt alone, proved:

```text
AUTHORITY_COMMIT = a8ac2e2535943361cc2d40c2ddcd4ec7ba4552bc
PARENT = 88ee8523c26dc8778268ab7317e38a6f998334ba
TREE = 13c8186854be0db9a630e97a9dedabf8022b9328
SUBJECT = docs: select internal transfer as second financial command
ARTIFACT = docs/SECOND-SERVER-AUTHORITATIVE-FINANCIAL-COMMAND-OWNER-SELECTION.md
ARTIFACT_BLOB = 37e54d7c24bd3ddde4d5fc24222dd81e40dbf28d

OWNER_SELECTION_STATUS = RESOLVED
SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND = INTERNAL_TRANSFER
OWNER_SELECTED_COMMAND = INTERNAL_TRANSFER
APPROVAL_MODEL = DIRECT_EXECUTION
OVERPAYMENT_POLICY = NOT_APPLICABLE
PLANNING_STARTED_AT_AUTHORITY = NO
IMPLEMENTATION_STARTED_AT_AUTHORITY = NO
IMPLEMENTATION_AUTHORIZED_AT_AUTHORITY = NO
NEXT_AUTHORIZED_SESSION_AT_AUTHORITY =
  INTERNAL_TRANSFER_SERVER_AUTHORITATIVE_COMMAND_PLANNING_ONLY
```

The committed artifact defines one positive amount from one eligible account to
a different eligible account inside the permitted tenant/business scope. It
explicitly deferred transaction, replay, authorization, projection, and offline
mechanics to this planning session. No newer authority contradicts it.

### Relevant predecessor chain

1. Phase 108C selected Cloud authority plus an acknowledged local cache, trusted
   RPCs for critical writes, server-final financial truth, and online-only
   transfers in the first Cloud release.
2. Commit `2c09062474c3bae590763a70b6e3214457c12725` planned the first atomic
   financial command, `PostExpense`.
3. Commit `6d04a57e188be7cd0bed9a1ae828f1d0d49ad239` implemented it; commit
   `951ed1cfe4e673f376dd9e270f2d7076fc8f1750` closed its live verification
   defects.
4. Commit `a5f57c709e1b7e9b3f50d8ae4811951220edf2a6` opened selection of the second
   server-authoritative financial command.
5. Commit `88ee8523c26dc8778268ab7317e38a6f998334ba` found customer collection,
   supplier payment, and Internal Transfer credible but stopped for owner
   selection.
6. The authority commit `a8ac2e...` closed that selection in favor of Internal
   Transfer. Selection is not reopened here.

The older owner decisions DC-U013 through DC-U024 remain binding where they do
not conflict with the newer authority: no fees; sufficient source balance;
active accounts only; auditable non-future effective date; owner-only transfer;
client request ID plus unique transfer reference; stable transfer UUID plus
sequential display number; optional note; all active treasury/bank/wallet pairs,
including distinct same-type accounts; immutable posting; review then one final
confirmation. Reversal itself is deferred by this session.

## D. First server-authoritative command precedent

The implemented predecessor is `PostExpense`:

```text
ExpensesScreen
  -> ApplicationBoundary.commands.postExpense
  -> PostExpenseCommandHandler
     -> verified SessionContext + BusinessContext
     -> Drift ExpensePostingAttemptStore
     -> SupabaseExpensePostingGateway
     -> public.post_expense_v1
     -> financial command receipt + expense + ledger entry + two audits
     -> DriftConfirmedExpenseProjectionWriter
     -> refreshed hydrated financial-account reads
```

`post_expense_v1` derives the actor from `auth.uid()`, verifies active business
membership, locks the financial account, derives balance from ledger entries,
stores an immutable receipt keyed by command type and command ID, binds replay to
actor/business/payload fingerprint, and commits the receipt, expense, entry, and
audits in one PostgreSQL transaction. Exact replay returns the stored result;
conflicting replay is rejected. The client durably records the attempt before
send, treats transport uncertainty as `unknownOutcome`, and projects only after
server confirmation. Confirmed projection failure is repairable without
reposting.

### Precedent classification

| Predecessor pattern | Classification | Internal Transfer consequence |
|---|---|---|
| Typed application command/result/handler | `REUSE_WITH_NARROW_EXTENSION` | Add a transfer-specific command and closed result; do not create a generic command bus. |
| Verified Supabase session and business contexts | `REUSE_AS_IS` | Require both contexts before an attempt or transport call. |
| Existing financial-account Cloud links | `REUSE_AS_IS` | Resolve and recheck two distinct ready local-to-server account links. |
| PostgreSQL database function as atomic boundary | `REUSE_WITH_NARROW_EXTENSION` | One transfer RPC owns both accounts, both legs, header, audits, numbering, and receipt. |
| Public privileged `SECURITY DEFINER` implementation | `MUST_DIFFER` | Current Supabase guidance favors a non-exposed privileged implementation with an exposed restricted wrapper; never broaden direct table writes. |
| Receipt `(command_type, command_id)` uniqueness and canonical replay | `REUSE_WITH_NARROW_EXTENSION` | Widen only the receipt command-type constraint for `post_internal_transfer`; keep global uniqueness within command type. |
| Single account `FOR UPDATE` | `MUST_DIFFER` | Lock both account rows in ascending UUID order before balance/eligibility evaluation. |
| Owner-or-employee expense authorization | `MUST_DIFFER` | Transfer execution requires active `owner` membership only. |
| Payment-method routing and accounting classification | `NOT_APPLICABLE` | A transfer is account-to-account and carries neither payment route nor expense classification. |
| Negative-balance `approvalRequired` branch | `MUST_DIFFER` | Direct execution plus DC-U014 means insufficient source balance always rejects; no approval ID or approval workflow enters this command. |
| Slice-specific durable attempt state | `REUSE_WITH_NARROW_EXTENSION` | Add a transfer-only attempt store/table; do not generalize the expense table or build a generic outbox. |
| Confirmed idempotent local projection | `REUSE_WITH_NARROW_EXTENSION` | Atomically project one transfer, two entries, three audits, two link updates, and attempt state. |
| Serialized external projection refresh | `REUSE_AS_IS` | Use `DriftFinancialAccountRepository.applySerializedExternalProjection`; no repository rewrite is required. |
| Offline expense drafts/queue semantics | `MUST_DIFFER` | Transfers are online-only under Phase 108C; only an uncertain in-flight attempt may persist. |
| Stable error/result mapping | `REUSE_WITH_NARROW_EXTENSION` | Add only transfer-specific categories/codes. |

The function plan follows current official Supabase guidance for
[database functions](https://supabase.com/docs/guides/database/functions) and
[RLS/grants](https://supabase.com/docs/guides/database/postgres/row-level-security):
pin the privileged function search path, explicitly revoke/grant execution, and
combine RLS with least-privilege table grants. PostgreSQL row locks are acquired
in one stable order because the official
[locking guidance](https://www.postgresql.org/docs/current/explicit-locking.html)
identifies consistent multi-object lock order as the primary deadlock defense.

## E. Current Internal Transfer forensics

### Current call path and authority

```text
FinancialAccountsScreen
  -> FinancialTransfersScreen
  -> FinancialAccountController.createTransfer
  -> AppRepositories.financialAccountRepository
  -> DriftFinancialAccountRepository._write
  -> LocalFinancialAccountRepository._createTransfer
  -> SQLite financial_transfers + financial_account_entries + audit_logs
```

There is a cohesive local implementation, but no server-authoritative transfer
implementation. The UI obtains the global local repository directly, generates
time-based request/reference strings, and calls the controller. The controller
and repository both enforce an active local owner. The repository validates a
positive amount, distinct accounts, non-future/open effective date, active
accounts, local request/reference uniqueness, and source balance.

One local `FinancialTransfer` header links exactly two entries:

- source `outflow` / `transferOut`;
- destination `inflow` / `transferIn`;
- equal `amountQirsh`, same transfer document ID/display number/reference/date;
- local creation time and local user ID.

Balances are not stored columns. `currentBalanceForAccount` and balance reports
sum signed `financial_account_entries`; the transfer therefore decreases the
source, increases the destination, and preserves the combined total. The
transfer report reads one header per transfer. All-account inflow/outflow reports
exclude transfer and transfer-reversal source types, while account-specific
statements retain the applicable leg. Profit and dashboard revenue/expense
totals read sales/expense repositories rather than transfer rows.

The durable adapter serializes in-process writes, mutates a hydrated aggregate,
then rewrites the four financial tables inside one SQLite transaction. Backup,
restore, preview, and wipe already include local transfer headers and entries.
No current transfer row, entry, audit, request receipt, or balance effect exists
in Supabase. There is no transfer RPC, gateway, server transfer table, server
number series, transfer attempt table, or transfer confirmed-projection writer.

### Current weaknesses to remove from the production posting path

- client/local user and business authority are trusted;
- IDs, reference, display sequence, and creation time are device-local;
- idempotency is one-device SQLite uniqueness, not cross-device server receipt;
- account ownership has no local business column and cannot prove tenancy;
- simultaneous devices cannot share the local transaction boundary;
- the current repository can accept a negative-balance approval ID when an
  account permits negatives, contrary to this command's final direct-execution,
  sufficient-funds plan;
- local success can be presented as final without server acceptance;
- Cloud mode still exposes local reversal, which must not mutate a
  server-authoritative transfer locally.

Legacy local transfer data remains historical acknowledged local data; this
session does not migrate, delete, edit, upload, or reinterpret it.

## F. Canonical command semantics

Planning name and boundary:

```text
APPLICATION_COMMAND = PostInternalTransferCommand
COMMAND_TYPE = post_internal_transfer
RPC = public.post_internal_transfer_v1 (restricted exposed wrapper)
PRIVILEGED_IMPLEMENTATION = private.post_internal_transfer_v1
SCHEMA_VERSION = 1
```

The command payload is:

| Field | Contract |
|---|---|
| `commandId` | Client-owned lowercase UUIDv7 (UUIDv4 fallback); immutable idempotency key. |
| `schemaVersion` | Exactly `1`. |
| `businessId` | UUID from verified `BusinessContext`; server treats it as an assertion and reauthorizes it. |
| `sourceFinancialAccountId` | Ready server account UUID resolved from the selected local source. |
| `destinationFinancialAccountId` | Ready server account UUID resolved from the selected local destination. |
| `amountQirsh` | Positive integer qirsh; EGP is the single application currency. |
| `effectiveBusinessDate` | `YYYY-MM-DD`, interpreted in the business timezone (currently `Africa/Cairo`); today or an open past date. |
| `transferReference` | Required independent client-generated UUIDv7 reference, immutable and unique per business. It is not the display number. |
| `note` | Optional trimmed user note; blank becomes null. It keeps the predecessor's PostgreSQL `text`/Dart `String` semantics and adds no arbitrary new length policy. |

The server derives the actor from `auth.uid()`, the acceptance/creation time
from `clock_timestamp()`, the internal transfer UUID and all entry/audit UUIDs
from server randomness, and the next business transfer display number from a
server-owned per-business sequence. The display format is the existing
`TR-000001` shape, monotonically increasing per business without automatic
date/fiscal reset. Client actor IDs, server timestamps, balances, display
numbers, entry IDs, and audit IDs are not accepted.

The command is direct execution: after the existing review and one final
confirmation, an authorized online call either atomically commits or returns a
deterministic failure. There is no draft, approval, owner inbox, maker/checker,
or pending-approval state.

It creates no fee, expense, income, sale, purchase, collection, supplier
payment, advance, refund, opening balance, adjustment, inventory movement, or
reversal.

## G. Account eligibility and monetary policy

Both source and destination must independently be:

1. present in `public.financial_accounts`;
2. owned by the asserted and authorized `business_id`;
3. active;
4. Cloud-ready, reconciled, and at reconciliation version greater than zero;
5. one of `treasury`, `bank`, or `electronicWallet`;
6. linked locally to two different active local accounts immediately before
   command construction.

Every ordered pair is allowed, including two distinct accounts of the same
type. Source and destination UUIDs must differ. There is no shop/branch column
or cross-shop feature in the current Cloud model; the business is the complete
server scope. Cross-business and cross-tenant movement is prohibited. Account
reassignment is not supported; deletion/deactivation/update must contend with
the row locks used by this command.

The current domain has one currency only: integer qirsh displayed as EGP. No
currency column, conversion, exchange rate, or cross-currency transfer is added.

The source's derived authoritative balance must be at least `amountQirsh`.
Insufficient funds returns `balance.insufficient` even when
`allow_negative_balance` is true. No negative-balance approval is accepted or
consumed. Destination balance cannot overflow PostgreSQL `bigint`; numeric
overflow is a transaction failure and commits nothing.

## H. Authorization and tenant boundary

Client-side owner checks and screen visibility are UX only. The privileged
server implementation must:

1. reject a null `auth.uid()`;
2. read the asserted business and caller membership with `FOR SHARE` locks so
   role, active-membership, and active-business updates cannot race acceptance;
3. require active business, active membership, matching authenticated user, and
   membership role exactly `owner`;
4. bind both account rows to that business after acquiring their locks;
5. never derive authority from local `AppUser`, caller-supplied actor, JWT
   `user_metadata`, or account IDs alone.

The public RPC wrapper is executable only by `authenticated`. All authoritative
tables remain direct-write denied to `anon` and `authenticated`. New exposed
tables enable RLS and grant only membership-scoped reads required by the app.
The privileged implementation lives in a non-exposed `private` schema, uses
`SECURITY DEFINER`, `search_path = ''`, fully schema-qualified names, explicit
function ownership/privilege review, and an internal `auth.uid()` check. The
public wrapper is `SECURITY INVOKER`, contains no business logic, and delegates
only the fixed signature. Implementation must prove the private schema is not a
Data API exposed schema and must run database security/advisor checks.

## I. Server authority and schema boundary

```text
MIGRATION_REQUIRED = YES
EDGE_FUNCTION_REQUIRED = NO
POSTGRES_RPC_REQUIRED = YES
```

A PostgreSQL function is the narrowest repository-consistent boundary: the
operation is data-intensive, all effects already live in Postgres, and one
implicit function-call transaction can lock and commit them atomically. An Edge
Function or multiple client calls would add a network boundary without improving
the database invariant.

The implementation migration must be additive and generated by the Supabase CLI
at implementation time; this plan does not reserve a timestamp. It must:

1. create `public.financial_transfers` with transfer UUID PK, business FK,
   command UUID, source/destination account FKs, positive amount, date,
   reference, per-business sequential display number, server actor/time, source
   and destination entry FKs, distinct-account and distinct-entry constraints,
   and uniqueness for `(business_id, command_id)`, `(business_id,
   transfer_reference)`, `(business_id, display_number)`, `source_entry_id`, and
   `destination_entry_id`;
2. add a private per-business transfer-number counter (or an equivalently
   transaction-safe existing-series extension) because `MAX()+1` is forbidden;
3. widen only `financial_account_entries.source_type` for `transferOut` and
   `transferIn`;
4. widen only `financial_command_receipts.command_type` for
   `post_internal_transfer` while preserving `(command_type, command_id)` global
   uniqueness and immutable completed results;
5. widen `audit_events.action_type` for `financial_transfer.created`; the
   existing `financial_account.entry.created` supports both leg audits;
6. add transfer lookup indexes for business/date and source/destination/date;
7. enable RLS on the new exposed transfer table, revoke all default direct
   privileges, and grant only authenticated membership-scoped select;
8. create/restrict the private implementation and public wrapper described in
   Section H.

Existing financial tables and local history are not backfilled or rewritten.
No server balance column is introduced. The migration must remain compatible
with existing `post_expense_v1` receipts and data. Dropping or weakening current
constraints/RLS is prohibited except for the narrow constraint replacement that
adds the new enum value.

## J. Authoritative transaction and accounting representation

One successful function invocation commits all of the following, or none:

1. one completed `financial_command_receipts` row;
2. one immutable `financial_transfers` header;
3. one source `financial_account_entries` outflow with source type
   `transferOut`;
4. one destination `financial_account_entries` inflow with source type
   `transferIn`;
5. two `financial_account.entry.created` audit events, one per entry;
6. one `financial_transfer.created` audit event;
7. the per-business display-number counter advance.

Both entries use the transfer UUID as `source_document_id`, equal positive
amounts, the same effective date, server actor/time, and their respective
account IDs. The transfer header is the canonical business document and stores
both entry IDs. It supplies identity/history/idempotency linkage; balances remain
derived exclusively from ledger entries.

The authoritative invariant is:

```text
source_delta = -amount_qirsh
destination_delta = +amount_qirsh
source_delta + destination_delta = 0
header_count = 1
transfer_entry_count = 2
receipt_count = 1
audit_count = 3
```

No journal/chart-of-accounts redesign is introduced. In this repository the
paired directional account entries are the canonical ledger representation.
The command must never write an expense or revenue row. Transfer source types
remain excluded from all-account economic inflow/outflow totals, while each
account statement intentionally shows its own leg. The transfer report reads
the header once, so the two ledger legs are not double-counted.

## K. Idempotency and replay

The canonical key is `(command_type = 'post_internal_transfer', command_id)`;
the existing schema's unique `(command_type, command_id)` makes it global across
businesses within this command type. The command ID is created once by the
client and durably retained before the first in-flight RPC.

The server SHA-256 fingerprint binds normalized schema version, command type,
actor Auth UUID, business UUID, ordered source UUID, ordered destination UUID,
amount, effective business date, transfer reference, and normalized note. The
server computes it; it never trusts a client digest.

Replay rules:

- first valid call reserves the receipt inside the transaction, executes, then
  stores the immutable canonical result;
- same key, same actor/business/fingerprint returns that result with
  `replayed=true` and performs no write or counter advance;
- same key with any changed field, actor, or business returns
  `idempotencyConflict`;
- a different key reusing the reference returns
  `transferReference.conflict` and commits no effect;
- concurrent exact submissions serialize on receipt uniqueness; one executes,
  the other returns the completed result;
- an internal exception rolls back header, legs, audits, number, and receipt;
  retry with the same key may then execute once;
- timeout or lost response leaves the local state `unknownOutcome`; explicit
  retry/reconciliation uses the same stored command and key;
- a confirmed local projection repair reads the stored local canonical result
  and never calls the monetary RPC again;
- receipts are retained permanently for financial replay safety; no cache TTL
  or routine deletion is planned.

`transferReference` is the second protection required by DC-U019. It does not
replace the command receipt and cannot be silently regenerated on a retry.

## L. Concurrency and locking

Within the server transaction, perform checks in this order:

1. validate parseable/syntactic payload and authenticated actor;
2. authorize and lock the business/membership rows sufficiently to prevent a
   concurrent deactivation from being ignored;
3. resolve/reserve the command receipt;
4. acquire both financial-account row locks in ascending account UUID order,
   independent of transfer direction;
5. re-evaluate existence, business ownership, active/Cloud-ready state, account
   type, open date, and source ledger balance while locks are held;
6. allocate the display number under its per-business counter lock;
7. insert both entries, header, audits, and completed receipt result;
8. return only after the PostgreSQL transaction commits.

The source balance sum is evaluated only after both account locks. The existing
`post_expense_v1` locks its one account, so a transfer contends correctly with
an expense on either account. Two same-source transfers serialize and the later
one sees the earlier ledger effect. A-to-B and B-to-A transfers cannot deadlock
on account rows because both lock the lower UUID first. Account deactivation or
deletion waits, or occurs first and causes deterministic rejection. Duplicate
commands serialize on receipt uniqueness.

SQLSTATE `40001` (serialization) and `40P01` (deadlock) are retryable
`transactionFailure` results and must be retried with the same command ID. Tests
must use bounded lock/statement timeouts so a locking defect fails rather than
hanging. No client-side balance check is authoritative.

## M. Offline and uncertain-outcome semantics

Phase 108C explicitly selected online-only transfer execution for the first
Cloud release. Therefore:

```text
AUTHORITATIVE_COMPLETION_OFFLINE = NO
CREATE_AND_QUEUE_WHILE_KNOWN_OFFLINE = NO
OPTIMISTIC_TRANSFER_HEADER = NO
OPTIMISTIC_LEDGER_LEGS = NO
OPTIMISTIC_BALANCE_MUTATION = NO
BACKGROUND_GENERIC_SYNC_QUEUE = NO
```

The screen requires a live verified Supabase session/business membership and
two ready account links. If known offline or context refresh cannot be proven,
it must reject before creating a new transfer attempt. After final confirmation,
the handler persists the exact attempt and immediately sends it; this small
crash-safety window is not permission for offline drafting.

Connectivity can fail after send begins, including after server commit. Such an
attempt is retained as `unknownOutcome`, shown as pending/uncertain rather than
completed, and has no local header, ledger legs, balance effect, report row, or
receipt presentation. Reconnect does not create a new command or silently post
in the background: the owner explicitly retries/reconciles the stored attempt.
The same-key RPC either executes once or returns its receipt. Permanent server
rejection moves the attempt to `rejected`, preserves sanitized evidence, and
still creates no local financial projection. Logout/business switch quarantines
the attempt; only the same authenticated owner/business may resume it.

On restart, the transfer screen loads nonterminal attempts for the active
business and shows an explicit retry action. A prior canonical server result in
`confirmedProjectionPending` triggers local projection repair only. Generic
outbox leasing, background connectivity scheduling, device registration, and
multi-command sync remain deferred.

## N. Local persistence and projection

### Classification

| Local record/write | Classification | Future rule |
|---|---|---|
| Existing legacy transfer/entries | `SYNC_MIRROR` / preserved legacy history | Readable and backed up; never reposted or silently uploaded. |
| New transfer attempt row | `CACHE` / durable recovery evidence | No monetary effect; persists exact payload/result/lifecycle. |
| Projected `FinancialTransfer` row | `POST_SUCCESS_PROJECTION` | Insert/upsert only from a verified canonical server result. |
| Projected source/destination entries | `POST_SUCCESS_PROJECTION` | Insert/upsert both in the same SQLite transaction. |
| Projected audit rows | `POST_SUCCESS_PROJECTION` | Use the three server IDs and exact actor/time/linkage. |
| Two financial-account Cloud-link updates | `CACHE` | Advance local reconciliation metadata only after both derived balances match server result. |
| Existing direct local production `createTransfer` call | `LEGACY_WRITE_TO_REMOVE` | Remove from the production transfer screen; keep test/legacy repository surface unless a narrower safe retirement is proven. |
| Local Cloud-mode reversal of a server transfer | `LEGACY_WRITE_TO_REMOVE` | Disable/hide in Cloud mode; reversal command remains deferred. |
| Stored local balance column | `NOT_REQUIRED` | Balances remain derived from projected entries. |

Add a transfer-specific Drift attempt table at schema version 17 with command
ID PK, business ID, exact canonical payload JSON, local fingerprint, lifecycle,
canonical server result JSON, creation/update UTC times, attempt count, and
sanitized last error. It is intentionally separate from
`expense_posting_attempts`; converting both into a generic outbox is out of
scope. Generated Drift code changes are mechanical.

The confirmed projection writer must run inside
`applySerializedExternalProjection` and one SQLite transaction. It resolves the
two server account UUIDs to two distinct local links, validates the server
envelope and existing rows, inserts/upserts one transfer, two linked entries,
and three audits, recomputes both local derived balances, requires exact equality
with `sourceBalanceAfterQirsh` and `destinationBalanceAfterQirsh`, updates both
links, and marks the attempt confirmed. Any mismatch or injected failure rolls
back the entire local projection and leaves `confirmedProjectionPending`.

Immediate success, exact response replay, app restart, and projection repair
therefore converge idempotently. A delivery replay with the same server IDs is a
no-op after equality checks. If unrelated server activity makes either local
account stale, the result remains financially confirmed but projection-pending;
it must not invent a balancing row. The controlled account reconciliation/sync
path must restore acknowledged ledger parity before the same projection is
retried. Implementing a generic inbox or synthesizing missing transactions is
not authorized by this slice.

Backup/export remains unchanged: confirmed transfer headers and entries already
participate in backup v7 through existing collections, while attempt rows and
Cloud-link metadata are device cache/recovery state and are not promoted to
business backup truth.

## O. Result and receipt contract

Success returns and stores as canonical receipt JSON:

```text
ok
commandId
businessId
transferId
displayNumber
transferReference
sourceFinancialAccountId
destinationFinancialAccountId
sourceFinancialEntryId
destinationFinancialEntryId
auditEventIds (exactly three distinct UUIDs)
effectiveBusinessDate
amountQirsh
sourceBalanceAfterQirsh
destinationBalanceAfterQirsh
serverAcceptedAtUtc
replayed
```

The client validates command/business/source/destination/reference/date/amount,
UUID shapes, distinct entry/audit IDs, and exactly three audits before recording
server confirmation. An invalid success envelope becomes retryable
`unexpectedServerError` with `unknownOutcome`; it never projects.

`transferId` is the durable result identity. `displayNumber` is the human-facing
server number. `commandId` is the retry identity. `transferReference` is the
independent immutable reference. No PDF, printable receipt, or new receipt UI is
required; the existing transfer history/report row is the presentation surface.

## P. Error contract

The transfer command uses a transfer-specific failure category enum while
preserving the predecessor's stable result style:

| Code | Category | Retryable | Meaning/action |
|---|---|---:|---|
| `validation.invalidField` | validation | no | Bad schema/UUID/date/note/amount or malformed payload; include safe field errors. |
| `validation.sameAccount` | validation | no | Source and destination are identical. |
| `unauthenticated.sessionRequired` | authentication | no until reauth | No valid Supabase actor/session. |
| `unauthorized.internalTransferDenied` | authorization | no | Membership absent/inactive, business inactive, or role is not owner. |
| `wrongBusinessContext` | businessContext | no | Caller/asserted business/account ownership mismatch; no mutation. |
| `sourceAccount.notFoundOrInactive` | account | no | Source missing, inactive, not Cloud-ready/reconciled, deleted, or invalid type. |
| `destinationAccount.notFoundOrInactive` | account | no | Destination equivalent failure. |
| `period.closed` | period | no | Effective date is inside a non-reopened closure. |
| `balance.insufficient` | balance | no for unchanged request | Derived source balance is less than amount; no approval branch. |
| `transferReference.conflict` | idempotency | no | Different command already owns the business reference. |
| `idempotencyConflict` | idempotency | no | Same command key with different actor/business/payload or incomplete conflicting receipt. |
| `serverUnavailable` | connectivity | yes | Network/timeout/temporary Data API failure; retain unknown outcome and same key. |
| `transactionFailure` | transaction | yes | Atomic failure/serialization/deadlock; same-key retry. |
| `projectionFailure` | projection | yes locally | Server success is final; repair local projection only. |
| `unexpectedServerError` | unexpected | conditionally | Invalid/unrecognized response; preserve safe diagnostic and reconcile same key. |

Client constructors perform syntactic validation for UX. The server repeats all
validation and owns authorization, state, balance, date, and concurrency rules.
PostgREST/Supabase exceptions must be sanitized and mapped without exposing SQL,
tokens, table contents, or user/account existence beyond the stable contract.

## Q. Time and audit semantics

`effectiveBusinessDate` is the owner's intended accounting day. It may be today
or a past day, may not be future relative to the server's Africa/Cairo business
date, and must not be closed. It is not an ordering timestamp.

`serverAcceptedAtUtc`/`created_at`/audit `occurred_at` are one server-derived UTC
instant for the committed command. Client time may be retained only in the local
attempt as diagnostic evidence and never authorizes/backdates the transfer.

The transfer header and audits preserve business, actor Auth UUID, command ID,
transfer ID, source/destination server account UUIDs, both entry IDs, amount,
effective date, display number, transfer reference, optional note, and server
time. No device ID is added because the current verified runtime has no trusted
server device identity; inventing one would be a generic identity expansion.

## R. Affected read models and reports

| Read model | Planned effect |
|---|---|
| Source/destination balances | Existing signed-entry derivation supports the pair after confirmed projection; refresh both. |
| Account statements/history | Existing `transferOut`/`transferIn` sources and projected IDs support it; no query semantics change. |
| Transfer history/report/AI summary | Existing header shape supports the new projected row; refresh after confirmed projection. |
| All-account inflows/outflows | Existing exclusion set already removes transfer source types; regression test required, no production change expected. |
| Account-filtered inflows/outflows | Existing behavior intentionally shows the selected account's leg; no change expected. |
| Payment-method report | Transfer entries have null payment method and existing transfer exclusions remain; regression test required. |
| Expense analysis/profit/dashboard | No expense/sale write exists; no production change expected. |
| Audit/history views | Existing local audit repository reads the three confirmed projected audits; refresh/convergence required. |
| Backup/export/restore | Existing transfer/entry collections support confirmed projections; no format change expected. |

No Logo Query Migration work or unrelated report/query migration is opened.

## S. File-level implementation delta forecast

This map is a forecast for a separately authorized implementation session.
Every change is required solely for Internal Transfer.

### NEW

| Group | Probable path | Exact purpose |
|---|---|---|
| Application command | `lib/application/commands/post_internal_transfer_command.dart` | Payload normalization/fingerprint, result/failure union, handler, attempt/replay/projection orchestration. |
| Application port | `lib/application/financial_transfers/internal_transfer_posting_gateway.dart` | Transfer-specific RPC request/response port. |
| Application port | `lib/application/financial_transfers/internal_transfer_posting_attempt_store.dart` | Durable online-attempt/recovery state and incomplete-attempt lookup. |
| Application port | `lib/application/financial_transfers/confirmed_internal_transfer_projection_writer.dart` | Confirmed header/two-leg/three-audit projection contract. |
| Supabase adapter | `lib/infrastructure/supabase/supabase_internal_transfer_posting_gateway.dart` | Authenticated RPC transport and stable error mapping. |
| Drift adapter | `lib/core/financial_accounts/drift_internal_transfer_posting_attempt_store.dart` | Schema-v17 attempt persistence and incomplete-attempt recovery; account links reuse the existing resolver. |
| Drift adapter | `lib/core/financial_accounts/drift_confirmed_internal_transfer_projection_writer.dart` | One-transaction, replay-safe confirmed projection. |
| Server migration | `supabase/migrations/<supabase-generated-timestamp>_post_internal_transfer.sql` | Additive transfer schema/constraints/RLS/private function/public RPC wrapper. |
| SQL tests | `supabase/tests/post_internal_transfer_test.sql` | Server validation/auth/tenancy/atomicity/replay/concurrency/accounting/security matrix. |
| Dart tests | `test/post_internal_transfer_command_test.dart` | Command, context, attempt, response, retry, error contract. |
| Dart tests | `test/internal_transfer_projection_test.dart` | v16-to-v17 migration, atomic projection, replay, restart, two-link reconciliation. |
| Dart tests | `test/internal_transfer_ui_integration_test.dart` | UI uses only application command; online/pending/confirmed/error/reversal boundaries. |

### MODIFIED

| Group | Path | Exact Internal Transfer reason |
|---|---|---|
| Application boundary | `lib/application/application_boundary.dart` | Expose exactly one `postInternalTransfer` handler. |
| Composition | `lib/composition/app_composition_root.dart` | Construct transfer store/gateway/projection/handler and unavailable adapter without changing other commands. |
| Drift schema | `lib/core/persistence/foundation_database.dart` | Add only transfer attempt table and advance schema 16 to 17. |
| Drift migration | `lib/core/persistence/migration_strategy.dart` | Additive v17 table creation only. |
| Generated Drift | `lib/core/persistence/foundation_database.g.dart` | Mechanical output from the schema change. |
| UI integration | `lib/features/financial_accounts/financial_transfers_screen.dart` | Replace direct local create with application command, two Cloud links, server lifecycle/result refresh, online-only behavior, and disable Cloud local reversal. |

`lib/application/application_dependencies.dart` already exposes the financial
repository and Cloud-link resolver; modify it only if compilation proves a
strictly transfer-specific dependency is otherwise unreachable. The preferred
delta leaves it unchanged. `lib/core/financial_accounts/financial_transfer.dart`,
`financial_account_controller.dart`, `financial_account_repository.dart`,
`drift_financial_account_repository.dart`, report services, backup services,
auth permissions, Supabase runtime/session adapters, `pubspec.yaml`, and
`pubspec.lock` already provide the necessary shape/dependencies and should remain
unchanged unless a failing acceptance test proves a narrower required edit.

### UNCHANGED

- customer collection, supplier payment, purchase, sale, advance/refund,
  inventory, closing/reopening, negative-balance approval, and reversal command
  implementations;
- generic sync/outbox/inbox/cursor architecture;
- expense command/RPC behavior except the narrow shared server constraint
  extension in the new migration;
- report/PDF/logo query migrations and presentation;
- backup version/format and existing local transfer history;
- dependency manifests and platform/generated plugin files.

### DELETED

```text
NONE
```

## T. Implementation test matrix

### Validation and eligibility

- positive integer-qirsh amount accepted; zero and negative rejected;
- malformed/overflow amount and unsupported schema rejected;
- same source/destination rejected before receipt/effect;
- missing, deleted, inactive, non-ready, unreconciled, and invalid-type source
  rejected; repeat for destination;
- every treasury/bank/wallet ordered pair and distinct same-type pair accepted;
- future date rejected, open past/today accepted, closed period rejected;
- blank/malformed reference rejected, duplicate business reference rejected,
  and blank note normalized to null without inventing a new length rule;
- insufficient source rejected regardless of `allow_negative_balance`; no
  approval row is read/consumed.

### Authorization and tenancy

- active owner membership succeeds;
- employee, viewer, inactive member, outsider, inactive business, expired/null
  session denied;
- source from another business denied; destination from another business denied;
- caller cannot spoof actor/business or use a valid account UUID outside scope;
- public/anon cannot execute; authenticated can execute only wrapper; direct
  insert/update/delete on transfer, entries, receipt, audit, and counter denied;
- membership-scoped reads cannot cross business.

### Atomicity and audit

- success commits one header, two equal/opposite entries, three distinct audits,
  one completed receipt, and one number advance;
- injected failure after receipt reserve, first entry, second entry, header,
  audits, and before receipt completion leaves none of those effects;
- source-entry/header FK and destination-entry/header linkage are exact;
- audit metadata carries actor/business/command/transfer/accounts/entries/time;
- failed command does not consume a visible number unless the chosen
  transaction-safe allocator's documented semantics require an audited gap.

### Idempotency and replay

- exact sequential and concurrent replay returns one logical result;
- duplicate submission never duplicates header, legs, audits, or number;
- same key plus changed source, destination, amount, date, reference, note,
  business, or actor returns `idempotencyConflict`;
- different key plus same reference returns `transferReference.conflict`;
- timeout-after-commit retry converges to one transfer;
- invalid success envelope stays unknown and does not project;
- confirmed-projection repair never invokes the monetary RPC.

### Concurrency and locking

- two simultaneous sufficient transfers from the same source serialize;
- when combined funds are insufficient, exactly the valid serial order succeeds
  and the other rejects without partial effect;
- A-to-B concurrent with B-to-A completes without lock-order deadlock and
  preserves combined value;
- transfer concurrent with `post_expense_v1` on source and on destination sees a
  serial balance order;
- concurrent exact duplicate executes once;
- account deactivation/deletion race either precedes and rejects or follows a
  completed transfer;
- membership/business deactivation race cannot authorize after deactivation;
- forced `40001`/`40P01` maps retryably and same-key retry remains safe;
- bounded timeout proves no hanging deadlock.

### Accounting and reports

- source decreases exactly once, destination increases exactly once;
- combined balance and signed transfer sum remain unchanged/zero;
- transfer writes no expense, revenue, sale, purchase, party, inventory, or
  approval row;
- transfer report has one row, source/destination statements each have one leg;
- all-account inflow/outflow, expense analysis, profit, dashboard, and payment
  method totals do not count the transfer;
- account-filtered flow reports intentionally show the applicable leg;
- server and local post-projection balances match.

### Offline, restart, and projection

- known-offline/invalid-context creation is denied before a new attempt;
- no local transfer/entry/balance/report effect exists before server success;
- in-flight network loss becomes durable `unknownOutcome`, not completion;
- reconnect exposes explicit same-command retry; server rejection reconciles to
  rejected with no projection;
- restart restores unknown/sending/confirmed-projection-pending attempts and
  quarantines wrong-user/business attempts;
- confirmed projection atomically inserts header, two entries, three audits,
  updates two links, and confirms attempt;
- injected failure rolls back every local projection row/update;
- exact projection replay is a no-op; conflicting row is quarantined;
- stale unrelated server activity leaves projection pending rather than
  fabricating balance, then converges after authoritative account reconciliation.

### Mandatory regression suites

At minimum run:

```text
flutter test test/phase108j_post_expense_command_test.dart
flutter test test/phase108j_expense_projection_test.dart
flutter test test/phase108j_expense_ui_integration_test.dart
supabase test db  # includes phase_108j_post_expense_test.sql and new transfer SQL tests

flutter test test/phase76_internal_financial_transfers_test.dart
flutter test test/phase78_financial_decisions_compatibility_audit_test.dart
flutter test test/phase79_account_based_financial_reports_test.dart
flutter test test/phase8h_durable_financial_account_repository_test.dart
flutter test test/phase81_transaction_financial_backup_contract_test.dart
flutter test test/phase9a_inflows_outflows_reports_test.dart
flutter test test/financial_transfer_summary_tool_test.dart
flutter test test/financial_account_balances_tool_test.dart
flutter test test/financial_account_statement_tool_test.dart
flutter test test/financial_payment_method_summary_tool_test.dart
flutter test test/financial_payment_routing_integrity_test.dart
flutter test test/dc_u007_negative_balance_controls_test.dart
flutter test test/negative_balance_approval_atomicity_test.dart
flutter test test/phase108g_session_business_context_boundary_test.dart
flutter test test/phase108h_app_shell_runtime_ownership_test.dart

flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
git diff --check
```

Implementation must discover the current Supabase CLI commands with `--help`,
generate the migration rather than inventing its timestamp, run database tests
and advisors, and verify current official Supabase function/RLS guidance before
deployment.

## U. Acceptance gates

| Gate | Objective pass condition |
|---|---|
| G1 Repository baseline | Authorized root/branch/remote are fresh and clean. |
| G2 Authority chain | `a8ac2e...` and this remote-locked plan are verified from Git objects. |
| G3 Schema/server transaction | Additive migration and one RPC boundary commit exact header/two-leg/three-audit/receipt effects. |
| G4 Server authorization | Only current active owner membership executes; client checks are UX only. |
| G5 Tenant isolation | Business and both account ownership checks defeat all cross-business/spoof cases. |
| G6 Atomic movement | Every injected failure proves zero durable half-transfer. |
| G7 Idempotent replay | Sequential/concurrent/timeout retries create one effect; payload conflict rejects. |
| G8 Concurrency | Ordered two-account locks, expense contention, deactivation races, and retryable SQLSTATE behavior pass. |
| G9 Offline policy | Known-offline create is blocked; uncertain in-flight attempts are visible, durable, and effect-free. |
| G10 Local projection | One atomic projection converges both balances or remains explicitly pending without repost. |
| G11 Reports | Transfer remains neutral to revenue/expense/profit/all-account flows and appears correctly in transfer/account views. |
| G12 Targeted tests | New Dart/SQL/UI/projection tests all pass. |
| G13 Regression tests | Mandatory suites and full Flutter suite pass. |
| G14 Static quality | Analyzer, scoped formatter check, SQL lint/advisors, and `git diff --check` pass. |
| G15 Delta | Implementation matches the forecast or documents a strictly narrower evidence-backed change. |
| G16 Deferrals | No other financial command, reversal, approval, generic sync, or Logo Query work appears. |
| G17 Clean closure | No secrets, fixtures, build output, unexplained changes, stash, lock, or active Git operation. |
| G18 Remote lock | If separately authorized, normal fast-forward push is independently fetched/directly verified. |

## V. Canonical decision table

| ID | Decision | Repository evidence | Rationale | Rejected alternatives | Implementation consequence |
|---|---|---|---|---|---|
| D1 | One immutable positive EGP transfer command; no fees/reversal/other domain. | Authority `a8ac2e...`; Phase 75 DC-U013/14/23; `financial_transfer.dart`. | Preserves selected economic event. | Expense/income/adjustment; fee; reversal. | Version-1 typed payload and result only. |
| D2 | Two distinct active, Cloud-ready accounts; all three types and same-type pairs allowed; sufficient source funds. | `financial_account.dart`; DC-U014/15/22; server account schema. | Matches established product rules and safe authority cutover. | Inactive, same account, type routing, negative funds. | Validate/lock both; no approval ID. |
| D3 | Active business owner only. | DC-U018; current transfer UI/repository owner guards. | Existing transfer-specific permission is owner role; no arbitrary new capability. | Employee expense permission; new permission enum. | Server membership role exactly `owner`. |
| D4 | Server revalidates actor, business, and both account ownerships; no shop layer exists. | Business/session contexts; business membership/account schema; Phase 108C. | Prevents caller-spoofed tenant identity. | Trusting payload/local user; cross-business transfer. | `auth.uid()` plus locked membership/business/accounts. |
| D5 | Postgres RPC with public restricted wrapper and private privileged implementation. | `post_expense_v1`; Supabase/Postgres are current authoritative stack. | One database transaction, with hardened privilege boundary. | Edge Function; multiple client writes; public privileged body. | Add one wrapper/function pair in migration. |
| D6 | Header plus two financial account entries; ledger remains balance truth. | Current `FinancialTransfer`, transfer repository, Phase 108B proof. | Preserves reports, links, and zero-net accounting. | Stored balance; header only; unlinked legs. | Add server header and entry source types. |
| D7 | Receipt, header, legs, audits, and number allocation commit together. | Expense receipt transaction; local transfer atomic snapshot/Drift transaction. | No durable half-transfer or lost idempotency result. | Multi-call workflow; post-commit audit/receipt. | Single function transaction and failure injection tests. |
| D8 | Lock both accounts in ascending UUID order; lock auth scope and number row. | Expense account lock; Phase 108C concurrent-transfer rule; Postgres lock guidance. | Serial balance checks and A/B deadlock prevention. | Direction order; client balance; `MAX()+1`. | Deterministic `FOR UPDATE`, bounded retries/timeouts. |
| D9 | Client UUID command key + separate unique transfer reference + server fingerprint/receipt. | DC-U019; local dual uniqueness; expense receipt mechanism. | Meets owner rule and cross-device retry safety. | Reference-only; key-only; expiring cache. | Permanent receipt, per-business reference unique. |
| D10 | Return transfer/header IDs, both entry IDs, three audit IDs, number/reference, both balances, date/time, replay flag. | Expense result; local transfer model; projection needs. | Sufficient to validate and project without another monetary call. | Boolean-only receipt; local IDs/time. | Canonical result stored in receipt and validated client-side. |
| D11 | Known-offline creation/queue is prohibited. | Phase 108C offline policy explicitly says Transfer: No/No. | Owner-selected first Cloud risk boundary. | Provisional offline transfer; optimistic balance. | Require live contexts/readiness; no offline draft queue. |
| D12 | In-flight uncertainty persists as `unknownOutcome`; owner retries same key after reconnect. | Expense attempt lifecycle; Phase 103 timeout rule. | Network races remain replay-safe without generic sync. | New key; automatic local success; background outbox redesign. | Transfer-specific attempt state and retry UI. |
| D13 | Local rows are atomic post-success projections; balances derive from entries. | Expense confirmed projection; current financial repository. | Keeps server authoritative and current reads usable. | Local-first write; stored balance; synthetic repair entries. | New transfer projection writer using serialized refresh. |
| D14 | Server and local additive migrations are required. | Server lacks transfer table/RPC/source constraints; Drift lacks transfer attempts. | Existing schemas cannot safely express server pair/receipt/recovery. | No migration; generic outbox/schema rewrite. | One generated Supabase migration; Drift v17. |
| D15 | Transfer is neutral to economic inflow/outflow, revenue, expense, and profit. | Phase 108B; `financial_report_service.dart` exclusion set. | Movement between internal asset accounts creates no income/cost. | Two economic flows; expense fee; revenue. | Preserve source types and regression reports. |
| D16 | Stable transfer-specific errors map through a closed Dart failure union. | PostExpense categories/gateway. | Predictable UI/retry without global hierarchy redesign. | Raw SQL/PostgREST errors; string exceptions. | New enum/codes/gateway mapping only. |
| D17 | Client supplies open non-future business date; server supplies UTC acceptance time. | DC-U016; closures; Phase 103/108C time policy. | Preserves auditable backdating without trusting device order. | Client timestamp authority; arbitrary future date; today-only. | Date-only field plus server Cairo/closure validation. |
| D18 | Three server audits include actor/business/command/transfer/accounts/entries/amount/date/reference/time. | Expense two-audit precedent; local transfer audit. | Both ledger legs and business document are traceable. | One vague audit; generic audit framework/device invention. | Two entry audits plus one transfer audit in transaction. |
| D19 | Narrow new command/store/gateway/projection/RPC/tests; modify only boundary/composition/Drift/UI. | Existing application architecture and reusable link/serialization seams. | Smallest coherent vertical slice. | Repository rewrite; generic command/outbox/inbox; dependency upgrade. | File forecast in Section S is the allowlist. |
| D20 | SQL/Dart/UI/projection/concurrency/report tests plus full regressions and gates G1-G18. | Phase 108J suites; Phase 76/79/108B coverage. | Money movement requires proof across both authority layers. | Unit-only or happy-path testing. | Implementation cannot close until every objective gate passes. |

## W. Risks and rejected alternatives

1. **Stale local account state after another device writes.** Never invent a
   balancing row or mark projection confirmed. Preserve the canonical result and
   require authoritative account reconciliation before local repair.
2. **A-to-B/B-to-A deadlock.** Lock by sorted UUID, not transfer direction, and
   prove it under bounded concurrent SQL tests.
3. **Reference/display ambiguity.** Keep command ID, independent transfer
   reference, server transfer ID, and server display number distinct because
   existing owner decisions assign different roles to them.
4. **Legacy reversal escape.** A Cloud-confirmed transfer must never be reversed
   through the local repository. Cloud UI reversal is unavailable until a
   separately planned server reversal command exists.
5. **Privilege escalation.** Do not copy a privileged implementation into an
   exposed schema. Restrict wrapper/private function execution and direct table
   writes, enable RLS, test negative paths, and run advisors.
6. **Receipt constraint regression.** Widen the existing command-type check
   without weakening expense receipt uniqueness/status invariants.
7. **Hydrated-repository stale overwrite.** Project through the existing
   serialized external projection seam and prove concurrent writes do not erase
   confirmed rows.

Explicitly rejected: local-authoritative posting, two client RPC calls, a
mutable stored balance, generic command/outbox/inbox redesign, Edge Function
orchestration, employee access, negative-balance approval, multi-currency,
fees, drafts, approval workflow, automatic offline posting, transfer-as-expense
or income, and implementation of reversals.

## X. Owner escalations

```text
BLOCKED_PENDING_OWNER_DECISION = NO
```

Existing owner authority and committed domain decisions resolve all
implementation-critical product semantics. Environment selection, pilot data
provisioning, deployment, rollout, and any future reversal remain separate
execution/owner authorizations; they do not block this code-level plan.

## Y. Implementation sequence

1. Reverify the remote-locked planning commit and clean authorized baseline.
2. Add failing command/UI/projection/SQL contract tests.
3. Use current Supabase CLI help to generate one migration and implement the
   additive schema, constraints, RLS/grants, private core, and public wrapper.
4. Prove server validation, owner authorization, cross-business denial,
   receipt replay, ordered locking, atomic rollback, and report-neutral ledger
   invariants in local/ephemeral Supabase tests.
5. Add the transfer command, ports, Supabase gateway, transfer attempt store,
   and confirmed projection writer.
6. Add Drift v17 and regenerate only Drift output.
7. Compose the handler and migrate only transfer creation UI; enforce online
   status and prevent Cloud local reversal.
8. Prove restart/unknown/replay/projection repair and two-account convergence.
9. Run the entire test matrix, advisors/security checks, analyzer, formatter,
   full suite, delta audit, secrets scan, and clean/remote-lock closure if that
   session is authorized to push.

At no point may implementation silently broaden into another financial command,
a reversal, or generic synchronization.

## Z. Implementation entry contract

This plan is executable by a fresh implementation agent without inventing
transaction, idempotency, authorization, tenant, offline, projection,
accounting, error, time, migration, or test semantics.

```text
INTERNAL_TRANSFER_PLANNING = COMPLETE
INTERNAL_TRANSFER_IMPLEMENTATION_STARTED = NO
INTERNAL_TRANSFER_IMPLEMENTATION_AUTHORIZED_BY_THIS_SESSION = NO

REVERSALS = DEFERRED
CUSTOMER_COLLECTION = DEFERRED
SUPPLIER_PAYMENT = DEFERRED
PURCHASE_INTAKE = DEFERRED
ADVANCES = DEFERRED
SALES = DEFERRED
GENERIC_COMMAND_OUTBOX_INBOX_REDESIGN = DEFERRED
UNRELATED_QUERY_OR_LOGO_WORK = DEFERRED

NEXT_SESSION_IF_PLANNING_REMOTE_LOCK_SUCCEEDS =
INTERNAL_TRANSFER_SERVER_AUTHORITATIVE_COMMAND_IMPLEMENTATION
```
