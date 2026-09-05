# Second server-authoritative financial command — planning discovery

## A. Session objective and result

```text
SESSION_CLASS = PLANNING_ONLY
EVIDENCE_DATE = 2026-09-06 (Africa/Cairo)
WORKSTREAM = SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND
RESULT = BLOCKED_PENDING_OWNER_COMMAND_SELECTION
SECOND_COMMAND_SELECTED = NO
IMPLEMENTATION_AUTHORIZED = NO
IMPLEMENTATION_STARTED = NO
EXECUTABLE_COMMAND_CONTRACT_COMPLETE = NO
```

Discover exactly one legitimate successor to PostExpense, or fail closed under
the owner's Section 8 selection rule. Discovery found multiple materially
credible commands and no committed rule selecting one canonically. This is the
single canonical planning/governance artifact recording that blocker and the
evidence needed for an owner decision. It is not an implementation-ready plan,
an implicit choice, or authorization to implement any candidate.

The selected-command sections below explicitly distinguish verified precedent,
candidate-specific facts, and work that cannot be frozen before selection.
Remote-locking this evidence does not resolve the owner decision or complete
the executable planning objective.

## B. Authority chain

The committed owner artifact was read with `git show` at the exact entry commit:

```text
ENTRY_AUTHORITY = a5f57c709e1b7e9b3f50d8ae4811951220edf2a6
PARENT = dfd3737e58338b3076f4f89ae0757b397d39e38e
SUBJECT = docs: order post-logo roadmap successor workstreams
ARTIFACT = docs/OWNER-ROADMAP-ORDER-AFTER-LOGO-QUERY-MIGRATION-PROGRAM-COMPLETION.md
ARTIFACT_BLOB = fe6ce13f20557e23fefc9f83916f8fbe3ee29c64
```

Sections H, I and L bind the order: second financial command; next non-logo
application query; distributed identity/scope/time; durable outbox/inbox;
cloud/hybrid product catalog; recovery/trial/licensing. Section I explicitly
says the decision selects the workstream only and selects no particular command
family, technical design, implementation scope, or prerequisite outcome.
Section L authorizes successor planning and forbids successor implementation.

The parent decision at `dfd3737e58338b3076f4f89ae0757b397d39e38e`, in
`docs/OWNER-ROADMAP-SUCCESSOR-DECISION-AFTER-LOGO-QUERY-MIGRATION-PROGRAM-COMPLETION.md`,
preserves future financial-command scope discovery. The owner decision resolves
its missing workstream order, not its missing concrete command scope.
The preceding `0904bad1495632ed4f171832e7b0d3c2b7b5fe9a` authority and these
two decisions preserve the closed logo program.

Phase 108J governance Section 8 preserves purchase, customer payment, supplier
payment and advance work as valid future work, removes fixed future numbering,
and requires future scope discovery. Phase 108K scope reconciliation Section
I's alternatives table defers the second financial command without naming it.
Committed-document searches for second financial command, default candidate,
and next financial command found no successor-specific canonical command rule.
`a5f57c7..HEAD` was empty at entry; the fresh remote head matched entry. No newer
conflicting committed authority exists on the authorized branch at that gate.
Historical list ordering and obsolete phase numbers cannot supply the missing
owner command choice.

## C. Repository entry proof

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
CURRENT_BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
ENTRY_CLASSIFICATION = CASE_A_FRESH
LOCAL_HEAD = a5f57c709e1b7e9b3f50d8ae4811951220edf2a6
TRACKING_HEAD = a5f57c709e1b7e9b3f50d8ae4811951220edf2a6
DIRECT_REMOTE_HEAD = a5f57c709e1b7e9b3f50d8ae4811951220edf2a6
MERGE_BASE = a5f57c709e1b7e9b3f50d8ae4811951220edf2a6
ENTRY_TREE = 449fe9662b96b2677eb365fb67d7bd03a45110b3
AHEAD = 0
BEHIND = 0
WORKTREE_STATE = CLEAN
INDEX_STATE = CLEAN
STASH_STATE = EMPTY
ACTIVE_GIT_OPERATION = NONE
INDEX_LOCK_STATE = ABSENT
```

Evidence: root/branch/remote reads; fresh `git fetch origin` exit 0;
independent `git ls-remote origin refs/heads/codex/phase-108h-app-shell-runtime-ownership-boundary`
exit 0; local/tracking resolution, merge-base, and left/right divergence;
empty porcelain status, staged name-status and stash list. Checks for
MERGE_HEAD, CHERRY_PICK_HEAD, REVERT_HEAD, rebase-merge, rebase-apply, sequencer,
BISECT_LOG and index.lock were all false. No applicable AGENTS.md was found in
the repository or checked parent directories.

The first sandboxed direct remote query failed with Windows
`SEC_E_NO_CREDENTIALS`. Fetch and direct query were repeated outside the sandbox
through the approved escalation path and succeeded. Entry classification uses
those successful fresh observations, never stale tracking data alone. No reset,
discard, stash, branch change, force push or recovery mutation was used.

## D. Phase 108J predecessor reconstruction

### Complete accepted chain

| Authority | Commit | Evidence |
| --- | --- | --- |
| Governance reconciliation | `69eebcdac20bba12e9b75abaa99c9a2e02df5483` | `docs/phase-108j/PHASE-108J-GOVERNANCE-RECONCILIATION-AND-CANONICAL-SCOPE-FREEZE.md`; only one financial command; expense default |
| Canonical planning | `2c09062474c3bae590763a70b6e3214457c12725` | `docs/phase-108j/PHASE-108J-ATOMIC-FINANCIAL-COMMAND-PLANNING.md`; PostExpense / EXPENSE_POSTING |
| Initial implementation | `6d04a57e188be7cd0bed9a1ae828f1d0d49ad239` | Typed command, Supabase runtime/RPC, durable attempt and projection, tests |
| Final live-verification remediation | `951ed1cfe4e673f376dd9e270f2d7076fc8f1750` | Direct child of implementation; strict date parsing catches invalid date exceptions; three source-freeze test adjustments |
| Subsequent acceptance | Phase 108K scope reconciliation Sections D/E and planning Section B | Accepts the remediation commit as the final locked 108J baseline |

Git commit objects prove the direct parent chain above. SQL/command path history
contains the implementation and SQL remediation, with no later changes to these
paths at entry. The rejected historical third-read-only-query definition of
108J is not the accepted financial command authority.

```text
FINAL_108J_TAG = phase-108j-implementation-locked
TAG_OBJECT = 4e1c781a86beece985eb8ac3ae796976240c3cdd
PEELED_COMMIT = 951ed1cfe4e673f376dd9e270f2d7076fc8f1750
```

Both tag object and peeled commit matched a fresh independent `git ls-remote`
query in this session. Historical closure is verified from Git and later
committed acceptance; historical live test execution is not claimed as a test
run performed in this session.

### Actual current path and architectural precedent

```text
lib/features/expenses/expenses_screen.dart
  ExpensesScreen -> ApplicationScope.of(context).commands.postExpense.execute
lib/application/application_boundary.dart
  ApplicationCommands.postExpense
lib/application/commands/post_expense_command.dart
  PostExpenseCommandHandler.execute
lib/infrastructure/supabase/supabase_expense_posting_gateway.dart
  SupabaseExpensePostingGateway.post -> post_expense_v1
supabase/migrations/20260823000000_phase_108j_post_expense.sql
  authoritative server transaction and durable receipt
lib/core/expenses/drift_confirmed_expense_projection_writer.dart
  DriftConfirmedExpenseProjectionWriter.project
  -> serialized external financial projection -> SQLite transaction
```

Composition belongs to `lib/composition/app_composition_root.dart`; UI obtains
the application boundary through `lib/composition/application_scope.dart`.
`ApplicationCommands` currently has only trialEvaluation and postExpense.
`supabase_runtime_config.dart` and `supabase_cloud_session_adapter.dart` under
`lib/infrastructure/supabase/` supply the configured remote boundary. The
adapter requires an unexpired Supabase session and exactly one active membership
with owner/employee role; absent/ambiguous membership clears both contexts.
The RPC independently derives `auth.uid()` and checks active membership, allowed
role and active business. A local AppUser is not server identity proof.

The RPC validates positive integer qirsh, strict nonfuture date, normalized
category/notes, classification, account existence/business/activity/cloud
readiness, account/payment route, closed periods and available balance. It locks
the account row before balance-dependent mutation. It accepts no negative-balance
approval workflow; insufficient state produces balance.insufficient or
approvalRequired as applicable.

Atomic authoritative success comprises one expense, one expense outflow, two
audits (`financial_account.entry.created`, `expense.created`) and completion of
the reserved receipt. The function's exception block rolls back inner financial
writes and removes the receipt reservation; validation return branches after
reservation also delete it. Rejected work leaves no accepted economic event.
Read RLS is membership scoped, receipts are actor scoped, table writes are
revoked from public/anon/authenticated, and RPC execution is explicitly granted
to authenticated. The existing SECURITY DEFINER RPC has a fixed search_path and
explicit server checks; its existence does not authorize copying privileges
without a selected-command review.

The server computes SHA-256 over normalized JSON including command type/version,
business, authenticated actor, date, account, amount and all material expense
fields. Receipt primary key is `(business_id, command_type, command_id)` with
an additional global `unique(command_type, command_id)`. Actual replay lookup
uses type/id and checks business, actor, fingerprint and completed receipt.
Matching replay returns the stored result with replayed=true; mismatched replay
returns idempotencyConflict. The additional uniqueness is material and must not
be lost by copying only the initial planning description.

`lib/application/expenses/expense_posting_attempt_store.dart` defines the
expense-specific attempt contract. `DriftExpensePostingAttemptStore` in
`lib/core/expenses/drift_expense_posting_attempt_store.dart` persists the exact
payload/fingerprint before transport. States are draft, queued, sending,
confirmed, confirmedProjectionPending, rejected and unknownOutcome.
The handler validates verified session/context and key equality, prepares the
attempt, calls the gateway, validates response identity/date/amount/UUIDs/two
distinct audits, durably retains canonical acceptance, and only then projects.
Malformed accepted responses become unknownOutcome in the handler; unavailable
transport does not justify another command ID.

Known confirmed results bypass the gateway. Pending projection repairs reuse
the saved result, then mark confirmed. SQLite writes validate existing rows,
project expense/entry/audits atomically, and reconcile the projected balance
under financial-repository serialization. Failure returns financially successful
PostExpenseSuccess with projectionPending, not rejection or a local fallback.
The UI retains an in-memory retry request, blocks concurrent submission, offers
manual retry for unavailable transport/pending projection, and refreshes after
confirmed projection. Durable attempt close/reopen is tested, but the inspected
UI does not expose generic startup attempt enumeration: durable storage must
not be described as a complete automatic crash-recovery UI.

Existing tests: `test/phase108j_post_expense_command_test.dart`,
`test/phase108j_expense_projection_test.dart`,
`test/phase108j_expense_ui_integration_test.dart`, and
`supabase/tests/phase_108j_post_expense_test.sql`. The UI suite uses source
assertions; it is not proof of interactive behavior. SQL uses pgTAP, seeded
auth/business fixtures, role/claim changes and rollback; it covers replay,
authorization/isolation, validation and injected failures. No independent
multi-session concurrency runner was found under inspected scripts/supabase.

## E. Candidate inventory

Counts below describe economic records/effects, not physical SQL statement
counts: local Drift adapters can rewrite aggregate tables and sequence state.
All unselected candidates currently have LOCAL authority; none has a candidate
RPC, durable server receipt or confirmed cloud projection in the inspected
Supabase tree. Shared 108J auth, account links, ledger and receipt concepts are
available only as potential enablers. Existing local permission checks are not
cloud authorization.

| Candidate / business operation | Current entry and authority | Writes and accounting effects | Inventory / cash / counterparty effects | Cloud and authorization evidence | Tests / boundedness / dependencies and risks |
| --- | --- | --- | --- | --- | --- |
| Customer collection: receive a customer's payment | CustomersScreen._showCollectionForm -> CustomerController.recordCollection -> DriftCustomerAccountRepository.createCollection -> LocalCustomerAccountRepository.createCollection | One collection; optional customer credit entry; optional advance; financial inflow when account present; audit(s), request fingerprint and approval consumption where applicable | No inventory; cash +full amount; receivable -settled amount; excess retained separately as customer advance | No customer server tables/RPC; controller checks canCreateCustomerPayment or settings; overpayment requires local owner approval | phase34_customer_credit_collections, phase35_customer_credit_ui_pilot_qa, phase8k durable customer, dc_u008 advances; bounded payment intent, but server customer identity/open balance and overpayment semantics are missing |
| Supplier payment: pay a supplier | SuppliersScreen and SupplierStatementScreen -> SupplierPaymentDialog -> direct createPayment or NegativeBalanceApprovalWorkflowService.submitSupplierPayment -> DriftSupplierAccountRepository -> LocalSupplierAccountRepository.createPayment | One payment; optional supplier credit entry; optional supplier advance; one financial outflow when routed; audits, fingerprints and possible approval consumption | No inventory; cash -full amount; payable -settled amount; excess becomes separate supplier advance | No supplier server tables/RPC; statement uses canCreateSupplierPayment; supplier/controller paths also use manage-supplier permissions; approval and route checks remain local | phase36e_supplier_payment_ui, supplier_purchase_atomicity, phase8l durable supplier, dc_u008 advances; bounded payment intent, but supplier opening truth, balance locks and approval compatibility need explicit scope |
| Internal financial transfer: move money between accounts | FinancialTransfersScreen -> FinancialAccountController.createTransfer -> DriftFinancialAccountRepository / LocalFinancialAccountRepository.createTransfer | One transfer plus exactly two opposite ledger entries; transfer audit; optional negative-balance override audit/approval | No inventory or counterparties; source -amount, destination +amount; combined balance unchanged | Reuses account-state concept; no transfer server table/RPC; local owner-only check and actor equality; optional approval | phase76_internal_financial_transfers and FIN-001 phase108b proof; strong bounded candidate with two-account lock/reconciliation, unique reference and paired projection requirements |
| Purchase intake: accept stock, with paid/partial/credit mode | PurchasesScreen / SupplierPurchasesScreen -> PurchaseController or approval workflow -> DriftPurchaseRepository.createPurchaseIntake | Purchase and sequence; stock movement; valuation; outstanding supplier entry; effective paid financial outflow; audits | Quantity/value rise; payable rises only for outstanding amount; cash decreases by effective paid amount | No purchase/product/inventory/supplier server authority; canCreatePurchaseIntake locally | supplier_purchase_test, supplier_purchase_atomicity, phase8f durable purchase, paid_purchase_ui_completion; broad coupling risks starting catalog/inventory foundations; no canonical priority |
| Customer advance application: consume prepaid credit against receivable | CustomerAdvanceActionsScreen -> CustomerController -> DriftCustomerAccountRepository.applyAdvance -> local repository | Application + customer credit entry + audit + fingerprint; consumes available advance logically | No inventory/cash movement; receivable and available advance decrease equally | No server advance/customer ledger; local controller management/payment permissions | phase4_customer_advance_actions_ui, dc_u008_advances, phase8k; narrow action but requires authoritative original advance and receivable snapshot |
| Supplier advance application: consume prepayment against payable | SupplierAdvanceActionsScreen -> SupplierController -> DriftSupplierAccountRepository.applyAdvance -> local repository | Application + supplier credit entry + audit + fingerprint | No inventory/cash movement; payable and available advance decrease equally | No server advance/supplier ledger; local supplier management checks | phase5_supplier_advance_actions_ui, dc_u008_advances, phase8l; same dependency class as customer application; neither canonically ordered |
| Customer advance refund: return unused prepaid money | CustomerAdvanceActionsScreen -> CustomerController -> customer refundAdvance path | Refund + financial outflow + audits/fingerprint; possible approval consumption | No inventory; cash decreases; available advance decreases; settlement ledger is not another collection | No server original advance/approval; original financial account/route and remaining advance validated locally | phase4a_customer_refund_approval_contract, phase4 UI, dc_u008; requires original-link/remaining-balance and outgoing-balance authority |
| Supplier advance refund: receive unused supplier prepayment | SupplierAdvanceActionsScreen -> SupplierController -> supplier refundAdvance path | Refund + financial inflow + audits/fingerprint | No inventory; cash increases; available supplier advance decreases | No server original advance; original financial account and route validated locally | phase5 UI, dc_u008, phase8l; bounded refund action but original advance and future reversal compatibility unresolved |

Additional screened mutation families are sale posting, financial reversals,
opening balances, account administration and financial closing. They do not
make the shortlist canonical. SalesScreen/SaleController and
`lib/core/sales/drift_sale_repository.dart` delegate to local sale authority,
with the broader sale/inventory/customer/payment domain; tests include
sales_test, phase8g_durable_sale_repository and phase39 customer-bound sales.
Cancellation/reversal methods exist alongside payment, purchase, advance and
transfer posting; each is a separate economic command, not permission to migrate
an entire lifecycle. Expense posting is already implemented and is ineligible.

## F. Selection decision and owner evidence

```text
RESULT = BLOCKED_PENDING_OWNER_COMMAND_SELECTION
SECOND_COMMAND_SELECTED = NO
CANONICAL_SECOND_COMMAND = UNSELECTED
IMPLEMENTATION_AUTHORIZED = NO
```

Customer collection, supplier payment and internal transfer are real user-facing
financial events, have bounded business transactions and testable invariants,
benefit from centralized authority, and can potentially use command-specific
attempt/receipt/projection patterns without a generic sync engine. Their
prerequisite sufficiency has not been proved; being credible does not mean
implementation-ready.

Transfer has the strongest existing account-only server overlap. Customer
collection exercises incoming money and receivable settlement; supplier payment
exercises outgoing money and payable settlement, with a durable local replay
precursor. These are different business priorities, not a canonical ordering.
Purchase adds materially broader product/inventory/value dependencies. Advance
actions require authoritative source advances and counterparty balances.
None of these comparisons makes exactly one command mandatory under an existing
architectural rule. Fewer tables or easier reuse cannot override the owner's
explicit requirement to stop when multiple valid candidates lack canonical
authority.

Required owner decision: identify one existing command, including whether its
existing approval/overpayment or negative-balance variants belong to the slice.
An explicitly bounded restriction needs owner confirmation if it changes
existing business behavior; silently excluding variants would fake boundedness.
After that decision, resume only this workstream's planning and revalidate its
prerequisites. No second or third command is selected by this document.

## G. Selected command

Not selected. There is no frozen application method, new RPC name, payload,
transaction allowlist, schema delta or implementation authorization. The
selected-command requirements in Sections H-V are blocked by Section F. They
are recorded below as evidence and completion gates, not speculative executable
designs for several commands.

## H. Current-state paths and authority classification

Customer collection concrete trace:

```text
lib/features/customers/customers_screen.dart: _showCollectionForm
 -> lib/core/customers/customer_controller.dart: recordCollection
 -> lib/core/customer_accounts/drift_customer_account_repository.dart: createCollection / _write
 -> lib/core/customer_accounts/customer_account_repository.dart: createCollection (line 277)
 -> collection, settlement entry, optional advance, financial entry, approval, audit
```

Supplier payment concrete trace:

```text
lib/features/suppliers/suppliers_screen.dart: _recordPayment
lib/features/supplier_accounts/supplier_statement_screen.dart: _recordPayment
 -> lib/features/supplier_accounts/supplier_payment_dialog.dart: _submit
 -> direct createPayment OR
    lib/core/financial_accounts/negative_balance_approval_workflow_service.dart: submitSupplierPayment
 -> lib/core/supplier_accounts/drift_supplier_account_repository.dart: createPayment (line 221)
 -> lib/core/supplier_accounts/supplier_account_repository.dart: createPayment (line 214)
 -> payment, settlement entry, optional advance, financial entry, approval, audit
```

Transfer trace:

```text
lib/features/financial_accounts/financial_transfers_screen.dart
 -> lib/core/financial_accounts/financial_account_controller.dart: createTransfer
 -> lib/core/financial_accounts/drift_financial_account_repository.dart
 -> lib/core/financial_accounts/financial_account_repository.dart: createTransfer / _createTransfer (line 921)
 -> transfer, paired entries, audit and conditional approval
```

```text
CURRENT_LOCAL_AUTHORITY = local repositories, RepositoryTransaction snapshots and Drift persistence
CURRENT_SERVER_AUTHORITY = none for these candidate commands
CURRENT_PROJECTION = local records are authoritative locally, not acknowledged server results
CURRENT_FALLBACK = no candidate cloud attempt to fall back from; direct local writes are the primary path
CURRENT_RETRY = command-specific local/UI behavior, not a remote accepted-receipt recovery contract
CURRENT_IDEMPOTENCY = heterogeneous local mechanisms, not cross-device server receipts
```

Supplier Drift payment replay compares stored request fingerprint and returns the
existing payment; its local delegate rejects reused request IDs. Customer local
collection uses its request map and rejects a processed request rather than
returning a canonical server receipt. Transfer compares request ID plus source,
destination, amount and reference; it also checks duplicate transfer reference.
These equivalence rules are not interchangeable. Purchase already checks a
stored request fingerprint before and inside its snapshot transaction.

Direct createCollection/createPayment/createTransfer calls, full aggregate
Drift persistence, and approval-workflow alternate call paths would require
removal or demotion for whichever cloud slice is selected. They must not remain
financially authoritative after a cloud RPC succeeds. No such changes occur here.

## I. Target architecture gate

The required shape after a future selected-command plan is UI -> existing
ApplicationCommands boundary -> dedicated handler -> authoritative RPC ->
transaction and durable receipt -> confirmed local projection. No actual new
method or RPC is proposed/frozen here. PostExpense remains the only concrete
reference implementation, not a mandate to copy its accounting semantics.

## J. Server transaction gate

ATOMIC_REQUIRED must include every selected economic record, all account and
counterparty/advance effects, necessary approval consumption, audits and receipt
completion. PROJECTION_ONLY comprises local cached accepted records, local
acknowledgment and UI refresh; none may complete an omitted financial effect.
The inventory table exposes different boundaries: two accounts for transfer;
counterparty settlement plus possible advance for collection/payment;
stock/value/payable/paid money for purchase. Exact locks, write set and rollback
points remain unfrozen until one command is selected.

## K. Identity and authorization gate

Reuse runtime ownership and verified session/business context as precedent.
The current cloud model uses business_id, not a separate shop membership model.
Do not introduce a shop/identity framework in this workstream.

| Identifier | Existing precedent / required treatment in resumed planning |
| --- | --- |
| Authenticated actor | Derived server-side from auth.uid(); local user ID/name are not trusted actor identity |
| Business ID | Client routing input from verified context; independently validated against active server membership/business |
| Membership ID, role and permissions | Derived/checked server-side; do not trust client assertions or copy expense role policy for a different operation |
| Financial account ID | Validated server reference in same business; local ID must resolve through a verified cloud link |
| Customer/supplier/advance/original document ID, if selected | Untrusted client reference; server business ownership, existence and linkage must be established; no server links currently exist for these families |
| Request ID | Client-supplied durable intent identity, format/uniqueness/equivalence validated server-side; not identity authorization |
| Approval ID, if retained | Reference only; approval status, actor, amount, scope and single consumption need server authority |
| Financial record IDs, receipt actor and accepted time | Server-derived; cannot be replaced with local counters/timestamps |

Exact selected-command role/permission mapping is an open contract item.

## L. Idempotency and recovery gate

Retain exact durable request identity before sending, server-computed canonical
equivalence, matching-result replay, conflict rejection and atomic durable
receipt. Preserve type/id collision protection and tenant/actor isolation.
After acceptance is durably known, repair from that saved result without posting
again. After a lost response or crash before acceptance is saved, receipt lookup
or exact-key replay must recover the same economic event; it must never generate
a replacement ID blindly. Distinguish this safe authoritative replay from local
projection repair, which must bypass transport.

The selected payload, fingerprint fields, receipt lookup API, retry UI and
startup discovery of pending attempts remain to be frozen. ExpensePostingAttempts
is expense-specific, not an existing generic queue. Reuse bounded primitives
where compatible without making a generic framework or pretending a new command
can already be stored there unchanged.

## M. Offline boundary

```text
GENERIC_DURABLE_OUTBOX = OUT_OF_SCOPE
GENERIC_INBOX = OUT_OF_SCOPE
GENERIC_CONFLICT_ENGINE = OUT_OF_SCOPE
LOCAL_AUTHORITATIVE_CLOUD_FINANCIAL_FALLBACK = FORBIDDEN
```

If authoritative acceptance is unavailable, no new local financial success may
be reported. Only existing command-specific attempt/retry precedent may inform
the eventual selected plan. A network timeout may mean unknown outcome;
absence of a response is not proof of server rejection. Background generic
retry, cross-device convergence and conflict resolution belong to later owner
workstreams.

## N. Local projection gate

For the future migrated financial result, LOCAL_DB = confirmed projection/cache.
The resumed plan must specify atomic projected rows, server-to-local references,
acknowledgment, duplicate/conflict checks, durable attempt states, crash-window
recovery, projection repair and UI refresh. Existing unrelated local persistence
is not redesigned. FoundationDatabase currently has schemaVersion 16 with
FinancialAccountCloudLinks and ExpensePostingAttempts; no new version is reserved.

## O. Application boundary gate

`ApplicationCommands`, `ApplicationScope`, and `AppCompositionRoot` are the
established ownership seam. Minimum future change is one selected typed command
and dedicated handler wired there, with the necessary transport/attempt/projection
dependencies. Exact signatures/files await selection. No generic command bus,
additional query migration, or multiple financial handlers is authorized.

## P. UI boundary gate

The relevant existing actions are listed in Sections E/H. A selected plan must
cover every entry for that command (supplier payment has two screens and an
approval path), submission/double-submit state, explicit server rejection,
unknown outcome retry, accepted-but-projection-pending state, repair, and success
refresh. Keep screen design changes limited to authority migration. Existing
expense source-based UI tests are a regression floor, not a replacement for
selected-command interaction tests.

## Q. Accounting and business invariants

These are discovered semantics, not selected new behavior. The application uses
operational account entries; do not invent a general double-entry journal.

- Collection/payment: settled = min(amount, max(counterparty balance, 0));
  advance = amount - settled. Cash changes by the full amount, counterparty
  balance by settled only, and excess remains a separate advance.
- Overpayment requires request/account/owner approval in the current domain.
  Supplier outflow can also involve negative-balance approval. Omitting these
  paths without an explicit scope decision changes business behavior.
- Transfer creates equal opposite entries; total across the two accounts is
  unchanged. Neither leg is income/expense. FIN-001 report semantics remain
  protected, including preventing transfer double counting.
- Advance application cannot exceed remaining advance or receivable/payable;
  it reduces both without another cash movement. Refund cannot exceed remaining
  advance and retains the original financial account linkage.
- Purchase intake increases quantity/value; outstanding amount affects supplier
  balance and effective paid amount affects financial outflow.
- Any selected server migration must prevent duplicate economic events and
  preserve operation-specific date, route, approval and audit rules.

## R. Error contract gate

PostExpense provides evidence for authentication, authorization, business context,
validation, account/route, period, balance, approval, idempotency, connectivity,
transaction, projection and unexpected categories. The gateway maps stable codes
such as unauthenticated.sessionRequired, unauthorized.expensePostingDenied,
wrongBusinessContext, period.closed, balance.insufficient, approvalRequired,
idempotencyConflict, serverUnavailable and transactionFailure.

Do not transplant expensePostingDenied or every expense error to an unselected
command. Counterparty/reference/advance errors must follow the eventual operation.
The essential distinction is COMMAND_REJECTED_BY_SERVER versus
COMMAND_ACCEPTED_BUT_LOCAL_PROJECTION_FAILED. The latter is accepted financial
success needing local repair; it must never invite a blind repost. Exact new
codes, retryability and user messages remain unfrozen.

## S. Database and RPC dependency findings

The inspected Supabase tree contains one migration and one test SQL file for
PostExpense. There is no second financial RPC. Existing schema is deliberately
restricted: receipt command_type equals post_expense; ledger source_type is
openingBalance or expense; audit action_type allows the two expense actions.
Those checks mean a second command cannot simply reuse these tables unchanged.

A resumed selected plan must resolve a new authoritative RPC, selected document
storage, narrowly extended receipt/source/audit constraints, unique keys/indexes,
RLS and grants, and any command-specific local attempt/projection persistence.
Transfers need paired-leg/source uniqueness and two ready account links;
collections/payments require authoritative counterparty reference/opening state;
advance actions require authoritative original advances and consumption facts;
purchases add product/inventory/value truth. These are dependencies to resolve,
not authorizations to start other owner workstreams.

No claim of 'no schema change required' is supportable. No migration number,
RPC name, local schema version bump or SQL definition is reserved or created.
The deployed database schema was not queried or modified in this session.

## T. Future verification matrix — not executed

| Family | Required acceptance evidence after selection |
| --- | --- |
| Request/application | Exact selected payload, normalization, identifier/context/key checks; rejected requests never project; response identity validation; error mapping |
| Attempts/recovery | Persist before send; same key/payload after timeout and restart; conflict rejection; accepted-response persistence crash window; no blind new ID |
| Local database | Atomic confirmed projection; duplicate no-op with equivalence checks; conflicting projection failure; close/reopen; injected failure rollback; repair bypasses RPC; serialization with existing writers |
| Server | Auth/session, role, active membership/business, references and cross-business isolation; complete commit/rollback; durable receipt; matching/conflicting replay; direct-write denial |
| Concurrency | Same key concurrently gives one event; different keys contend on the same financial/domain balance; ordered multi-account locks if transfer; no partial paired entries or double consumption |
| Accounting | Chosen invariants from Section Q, exact row/audit counts, resulting balances, dates/closures/routes and approval policy |
| UI | All selected entry paths route through application; duplicate submit disabled; rejection versus unknown outcome versus accepted projection failure; retry/repair and refresh |
| Regression | All three phase108j Dart suites and phase_108j_post_expense_test.sql; selected family suites from Section E; financial_payment_routing_integrity_test, negative_balance_approval_atomicity_test, FIN-001/transfer invariants as affected; flutter analyze and full flutter test before closure |

Section E abbreviates some suite labels. Exact durable suite paths are
`test/phase8k_durable_customer_account_repository_test.dart`,
`test/phase8l_durable_supplier_account_repository_test.dart`,
`test/phase8f_durable_purchase_repository_test.dart`, and
`test/phase8g_durable_sale_repository_test.dart`. Other concrete examples are
`test/phase34_customer_credit_collections_test.dart`,
`test/phase36e_supplier_payment_ui_test.dart`,
`test/phase76_internal_financial_transfers_test.dart`,
`test/dc_u008_advances_test.dart`, and
`test/supplier_purchase_atomicity_test.dart`.
No new test file is created and no baseline tests were run
in this documentation-only discovery session. No pass count or baseline failure
is inferred from reading source.

## U. Live authoritative verification gate

Future implementation closure must run actual PostgreSQL/Supabase checks on an
authorized isolated test environment and record schema revision, roles, fixtures,
queries, result counts and cleanup. Exercise transaction/rollback, RLS/direct
write denial, membership/business isolation, exact/conflicting replay and real
concurrent sessions. Flutter mocks and source assertions cannot prove these.
The existing rollback-wrapped pgTAP file is a useful starting infrastructure;
its inspection is not a current live pass, nor a multi-session concurrency proof.
No deployment, schema change or live financial write is made during planning.

## V. Dependency order and stop gate

There is no deterministic executable implementation sequence until the command
and its variants are selected. The only immediate sequence authorized here is:

1. Lock this single blocked-discovery artifact and stop.
2. Obtain the owner's concrete command/scope decision within this workstream.
3. Resume planning; freeze the complete selected path, prerequisite bootstrap,
   transaction, authorization, payload/replay, projection and UI contracts.
4. Validate and separately lock that complete plan before implementation is
   authorized. Revalidate remote entry and owner authority on resumption.

Only that future complete plan may turn the usual dependency order into an
executable sequence: server contract/schema/RPC, server tests, transport,
command-specific durable attempts and handler, confirmed projection, composition
and all selected UI paths, focused/regression tests, live authority verification,
then normal commit/push/remote lock. None of these implementation steps runs now.

## W. Risks and unresolved decisions

The blocking risk is inventing a canonical choice from relative simplicity.
Additional candidate-dependent risks are authoritative opening-state bootstrap,
mixed local/cloud writers on shared accounts, approval behavior changes,
cross-business reference mapping, multi-account locks, aggregate persistence
overwriting accepted projections, loss of an in-memory retry request after a
crash, and inability to reconstruct original advances remotely. These belong in
the resumed selected plan. Discovering them authorizes no remediation now.

## X. Explicit non-goals

```text
NO implementation in this session
NO third server-authoritative financial command
NO migration of every financial command or whole lifecycle
NO generic command framework rewrite
NO generic sync/outbox/inbox/conflict system
NO next non-logo application-query migration
NO distributed identity/scope/time workstream
NO cloud/hybrid product-catalog vertical slice
NO recovery/trial/licensing work
NO logo-query migration reopening
NO unrelated UI cleanup, refactoring or opportunistic bug fixes
NO dependency upgrades, generated changes, production/test/SQL changes
NO Supabase deployment or database mutation
NO claim that documentation remote lock resolves command selection
```

## Y. Authorization and continuation state

```text
LOGO_QUERY_MIGRATION_PROGRAM = CLOSED
POST_LOGO_OWNER_ORDER = BINDING
SUCCESSOR_SELECTED = SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND
SUCCESSOR_PLANNING_STARTED = YES
SUCCESSOR_PLANNING_COMPLETE = NO
SECOND_COMMAND_SELECTED = NO
SUCCESSOR_IMPLEMENTATION_STARTED = NO
IMPLEMENTATION_AUTHORIZED = NO
OTHER_POST_LOGO_WORKSTREAM_STARTED = NO
NEXT_REQUIRED_ACTION = OWNER_CONCRETE_COMMAND_SELECTION_WITHIN_THIS_WORKSTREAM
NEXT_AUTHORIZED_SESSION = SECOND_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND_PLANNING
NEXT_SESSION_CLASS = PLANNING_ONLY
```

The next planning session requires the concrete owner decision before freezing
the command contract. This does not reorder or authorize any other workstream.
Do not emit the successful executable-plan completion token for this blocker.

## Z. Documentation closure and remote-lock proof contract

```text
ALLOWLIST = docs/SECOND-SERVER-AUTHORITATIVE-FINANCIAL-COMMAND-PLANNING.md
REQUIRED_DELTA = DOCUMENTATION 1; PRODUCTION 0; TESTS 0; MIGRATIONS 0; GENERATED 0; DEPENDENCY_FILES 0
COMMIT_SUBJECT = docs: record second financial command planning selection blocker
REQUIRED_PARENT = a5f57c709e1b7e9b3f50d8ae4811951220edf2a6
```

Precommit gates: inspect this artifact completely; verify cited production paths
and predecessor chain; verify no candidate is silently selected; verify all
selected-contract gaps are explicit and implementation remains forbidden;
inspect status, diff/stat/check and staged diff; require exactly the allowlisted
documentation addition and no unrelated unstaged changes. Selection gate is
BLOCKED, so executable-plan validation cannot pass; only the truthful blocked
governance record can be committed under the owner's evidence-producing branch.

Create one normal documentation commit. Prove parent, commit, tree, artifact blob,
subject and one-file delta. Push normally to origin on the authorized branch;
then fresh-fetch and independently query its exact remote ref. Require:

```text
LOCAL_HEAD = TRACKING_HEAD = DIRECT_REMOTE_HEAD = MERGE_BASE = DOCUMENTATION_COMMIT
AHEAD = 0
BEHIND = 0
LOCAL_TREE = TRACKING_TREE = DIRECT_REMOTE_COMMIT_TREE
WORKTREE = CLEAN
INDEX = CLEAN
STASH = EMPTY
ACTIVE_GIT_OPERATION = NONE
INDEX_LOCK = ABSENT
RESULT = BLOCKED_PENDING_OWNER_COMMAND_SELECTION
```

Actual post-commit hashes and observed remote-lock results belong in the final
session report: a document cannot embed its own containing commit hash without
changing it. These are closure requirements, not claims of future observations.
No second evidence commit, amend, force push, implementation, or workstream #2
activity is authorized. After remote proof, stop with selection still blocked.
