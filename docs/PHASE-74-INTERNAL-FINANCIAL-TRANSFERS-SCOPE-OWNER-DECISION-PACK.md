# Phase 74 — Internal Financial Transfers Scope & Owner Decision Pack

## Phase Type and Baseline

This is documentation, architecture, and owner-decision preparation only. It implements no production transfer behavior.

- Baseline: Phase 73 — Financial Reporting & Reconciliation Scope Freeze
- Baseline commit: `5a21b93`
- Baseline tag: `phase-73-financial-reporting-reconciliation-scope-freeze`
- Baseline tests: 673/673 passing
- Existing foundation: unified financial accounts, append-only financial-account ledger, account statement, opening-balance/correction handling, backup v4 financial data, and Phase 72 transaction integration.
- Phase 66 remains not executed and has no tag.

## Exact Scope: ACC-011 Internal Financial Transfers

An internal financial transfer moves value from one distinct financial account to another within the same establishment. It may be treasury-to-bank, bank-to-treasury, treasury-to-electronic-wallet, electronic-wallet-to-bank, or another permitted account-to-account movement.

It is not a sale, purchase, customer collection, supplier settlement, expense, revenue, or inventory movement.

## Current-State Findings

- The code has `FinancialAccount` types: treasury, bank, and electronic wallet; accounts can be active or inactive.
- `FinancialAccountEntry` records account, inflow/outflow direction, integer-qirsh amount, source type/document ID, effective date, creator, reference, note, reversal linkage, correction group, and optional payment method.
- Existing entry sources do not include transfer in or transfer out. There is no transfer aggregate/header, shared transfer reference, transfer workflow, transfer UI, or transfer history.
- Current balances are ledger-derived by summing signed entries. Opening balance is also represented by an opening-balance entry; it is not re-added to the computed balance.
- Positive opening balances exist and opening-balance corrections reject negative corrected values. Generic `createEntry` requires a positive amount but does not require an active account or sufficient balance; an outflow can make an account balance negative. There is no unified insufficient-balance guard.
- There is no financial-transfer idempotency/request-ID convention. Entry IDs are locally generated and source-document IDs are supplied by callers.
- The current roles are owner and employee, with no dedicated financial-transfer permission.
- Backup/export and restore already preserve financial accounts and entries, but there is no transfer entity or pair-integrity validation.
- The in-memory repository has no database transaction primitive. A future paired transfer needs an implementation-level atomicity boundary; sequential generic entry creation would be unsafe.

## Mandatory Accounting Invariants

- Source and destination accounts must be distinct.
- Transfer amount is an integer number of qirsh and greater than zero.
- Each posted transfer creates exactly two linked ledger entries: source outflow and destination inflow.
- The paired amounts are equal. The base transfer’s net effect across financial accounts is zero.
- Transfers do not alter inventory, customer balances, supplier balances, sales, purchases, expenses, or revenue.
- Both entries share a traceable transfer reference and are posted atomically; neither may survive alone.
- Posted transfer history is never silently deleted or edited.
- Source statements must identify Transfer Out; destination statements must identify Transfer In. Future reports must not classify transfers as income or expense.

## Candidate Architecture (Not Implemented)

### Option 1 — Transfer aggregate/header plus two ledger entries

A dedicated transfer record would own source/destination IDs, amount, effective date, note, actor, shared reference, optional status/reversal relationship, and links to its two ledger entries.

- Benefits: explicit lifecycle, simple transfer history and reversal linkage, strong pair-integrity checks, clear backup unit.
- Risks: new persisted model, serialization, migration/backup compatibility, and a larger implementation surface.

### Option 2 — Two ledger entries linked only by a shared reference

Two new transfer source types would use the same source document/reference value to link the outflow and inflow.

- Benefits: smaller data model and aligns with the current ledger-led design.
- Risks: transfer history, idempotency, reversal, and pair-integrity logic become inferred and easier to corrupt or duplicate.

### Architectural Recommendation

Use a dedicated transfer aggregate/header with exactly two linked ledger entries in the future implementation. The current ledger remains the balance source of truth, while the aggregate supplies lifecycle, idempotency, shared reference, audit, backup validation, and reversal context. This is a recommendation only, not an implemented schema decision.

## Atomicity, Failure, and Retry Design

Validate actor, source/destination existence and distinction, account eligibility, amount, owner-approved balance policy, and idempotency before posting. A future implementation must create the transfer record and both ledger entries in one atomic persistence transaction; any failed validation or write rolls back the entire operation.

Retries must be resolved by the owner-approved idempotency/reference policy, returning the original completed transfer rather than creating a second pair. Restore validation must reject a transfer lacking either side, unequal pair amounts, or mismatched links. If corruption is detected, it must be surfaced as an integrity failure, never repaired by silently changing a balance.

## Statement, Audit, Schema, Backup, and UI Assessment

### Statement and audit

Future statements should display Transfer Out/Transfer In, counterparty account name, amount, effective date, shared reference, note, and reversal state if adopted. Audit records must retain the actor and transfer/entry references.

### Schema

Phase 74 changes no schema. A transfer aggregate and new transfer ledger sources would be additive but require a documented migration/compatibility assessment. Reusing an existing source type for a transfer would be unsafe because it changes that source type’s meaning.

### Backup and restore

Phase 74 changes neither backup format nor version. A future implementation must export the transfer aggregate and both entry links, preserve IDs/references, validate pair completeness and equality on restore, preserve old backups without transfer data, and cover round-trip integrity before any backup-version decision.

### UI and navigation

Phase 74 adds no UI. A future Arabic RTL transfer flow should have a clear back action, source/destination selectors that cannot select the same account, amount, effective date under the approved date policy, note, review/confirmation, Arabic validation, and a functional transfer-history destination. No placeholder or disabled visible control is authorized.

## Owner Decisions Required Before Implementation

All final owner decisions are **OPEN**. The decision register records detailed alternatives and recommendations for `DC-U013` through `DC-U024`:

| Topic | Decision ID |
|---|---|
| Transfer fees | DC-U013 |
| Insufficient source balance | DC-U014 |
| Inactive accounts | DC-U015 |
| Transfer date/backdating | DC-U016 |
| Cancellation/reversal | DC-U017 |
| Permissions | DC-U018 |
| Idempotency | DC-U019 |
| Reference numbering | DC-U020 |
| Notes/reasons | DC-U021 |
| Allowed account types | DC-U022 |
| Edit policy | DC-U023 |
| Owner confirmation UX | DC-U024 |

### Decision Details

| ID / topic | Why, options, and recommendation | Accounting / UX impact and risk | Final owner decision |
|---|---|---|---|
| DC-U013 Fees | A: no fees initially; B: explicit separate fee posting. Recommend A until fee accounting is approved. | Prevents an invented expense, source account, or net/gross amount. | OPEN |
| DC-U014 Insufficient balance | A: block; B: allow negative; C: vary by account type. Recommend A for first scope, while recognizing current generic entries permit negative balances. | Determines balance validation; allowing negative creates exposure without a documented policy. | OPEN |
| DC-U015 Inactive accounts | A: active accounts only; B: selected inactive cases. Recommend A. | Historical statements remain visible; new posting to an inactive account risks misleading operation. | OPEN |
| DC-U016 Date/backdating | A: today only; B: auditable past effective date. Recommend B only with explicit owner approval. | Affects statement ordering and later `DC-U006` interaction; backdating without policy is risky. | OPEN |
| DC-U017 Cancellation/reversal | A: no cancellation; B: documented paired reversal with reason. Recommend B. | Protects audit history; requires duplicate-reversal protection and clear UX. | OPEN |
| DC-U018 Permissions | A: owner only; B: owner/employee; C: future dedicated permission. Recommend A initially. | Requires matching UI/repository guard; broad access raises misuse risk. | OPEN |
| DC-U019 Idempotency | A: request ID; B: unique reference; C: both. Recommend C for durable implementation. | Prevents retry from producing a duplicate pair; requires clear retry feedback. | OPEN |
| DC-U020 Numbering | A: sequence; B: UUID plus display number; C: reuse a compatible scheme. Recommend B if a display ID is required. | Defines visible shared reference; ambiguity impairs audit lookup. | OPEN |
| DC-U021 Notes/reasons | A: optional note; B: required note; C: reason list plus note. Recommend A ordinarily and required reason for any future reversal. | More audit context versus input friction. | OPEN |
| DC-U022 Account types | A: all active types; B: selected pairs; C: prohibit same-type. Recommend A. | Determines valid source/destination choices; restrictions can block legitimate movement. | OPEN |
| DC-U023 Editing | A: immutable; B: editable drafts only; C: reversal then new transfer. Recommend A/C. | Avoids silent historical change; correction remains traceable. | OPEN |
| DC-U024 Confirmation UX | A: one confirmation; B: review screen; C: threshold-based extra confirmation. Recommend B. | Clearer review without inventing a financial threshold. | OPEN |

`DC-U006` remains open and unchanged. It controls daily closing, not the decision pack’s completion; no daily/period close, posting lock, or backdated-entry restriction is authorized here.

## Explicit Deferrals

- Production transfer model, UI, history UI, reversal, fees, schema migration, and backup-version change.
- Reconciliation, cash counting, daily close, period close, and financial reports.
- Cloud sync, multi-device support, and mobile application.
- A future internal-transfer implementation phase is not yet authorized or numbered.

## Acceptance Evidence for Phase 74

- `ACC-011` is defined precisely without claiming implementation.
- Accounting invariants, candidate architecture, atomicity/rollback/retry, statement/audit, schema, backup, and UI assessments are documented.
- Required owner decisions are recorded as OPEN in the decision register.
- Roadmap, traceability matrix, and handoff notes record Phase 74 consistently.
- No production code, UI, schema, migration, or backup format/version changes are made.
