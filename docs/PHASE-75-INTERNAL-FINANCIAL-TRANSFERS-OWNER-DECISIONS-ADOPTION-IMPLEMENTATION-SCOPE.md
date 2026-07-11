# Phase 75 — Internal Financial Transfers Owner Decisions Adoption & Implementation Scope

## Phase Type and Baseline

This is a documentation-only approval phase. It records owner decisions and defines the next execution scope; it does not implement transfers.

- Baseline commit: `a08e3f3`
- Baseline tag: `phase-74-internal-financial-transfers-scope-owner-decision-pack`
- Baseline: Phase 74 — Internal Financial Transfers Scope & Owner Decision Pack
- Requirement: `ACC-011` remains not implemented.
- `DC-U006` remains open and unchanged.

## Owner Decisions Adopted

| Decision | Official owner decision |
|---|---|
| DC-U013 | No transfer fees in the first release. |
| DC-U014 | Block a new transfer when the source account has insufficient balance. This transfer-only rule does not change legacy financial-operation rules. |
| DC-U015 | New transfers use active accounts only; inactive accounts remain visible in historical statements. |
| DC-U016 | Allow an auditable past effective date; prohibit future dates; retain actual creation time separately. Review this policy later if `DC-U006` closing policy changes. |
| DC-U017 | Support a documented paired reversal with mandatory reason; do not delete or edit the original; prevent repeated reversal. |
| DC-U018 | Owner only may create or reverse transfers in the first release. |
| DC-U019 | Require both client request ID and unique transfer reference for retry protection. |
| DC-U020 | Use stable internal UUID plus clear sequential display number. |
| DC-U021 | Normal transfer note is optional; reversal reason is mandatory. |
| DC-U022 | Allow all active financial accounts, including treasury, bank, wallet, and distinct accounts of the same type. |
| DC-U023 | Saved transfer is immutable; correction is documented reversal then a new transfer. |
| DC-U024 | Show a full review screen with source, destination, amount, date, note, and both balances, then one final confirmation; no large-amount threshold is adopted. |

## Phase 76 — Internal Financial Transfers Implementation

### Status

Execution scope is approved, but Phase 76 is **not started** by Phase 75. Production code may be changed only in a separate authorized task.

### Exact Scope

- Implement `ACC-011` only.
- Create a dedicated transfer aggregate/header and exactly two linked financial-account entries: source outflow and destination inflow.
- Post the aggregate and both entries atomically; failure creates neither side.
- Use equal positive integer-qirsh amounts, distinct active accounts, sufficient source balance, an effective date no later than today, creation timestamp, optional note, stable UUID, display sequence, client request ID, and unique transfer reference.
- Provide owner-only create and documented paired reversal with mandatory reason and duplicate-reversal protection.
- Show functional Arabic RTL transfer review/confirmation and history/statement presentation with Transfer Out/Transfer In, counterparty, reference, date, amount, note, and reversal status.
- Include backup/export, restore, preview, validation, old-version compatibility, and round-trip handling for new persisted transfer data.

### Mandatory Accounting Rules

- Transfers are not revenue, expense, sale, purchase, collection, supplier payment, or inventory movement.
- They do not alter inventory, customer balances, supplier balances, sales, purchases, expenses, or revenue.
- The source debit equals destination credit; net base effect across financial accounts is zero.
- No silent delete or historical edit. A reversal creates an auditable opposite linked pair.
- The sufficient-balance rule is limited to new transfers and does not automatically alter older transaction flows.

### Explicit Deferrals

- Transfer fees, reconciliation, cash counting, daily/period close, financial reports, cloud sync, multi-device, and mobile.
- No change to `DC-U006` or any closing/period-lock behavior.

### Phase 76 Acceptance Criteria

1. Transfer creation rejects same source/destination, missing/non-active account, zero/negative amount, future date, insufficient source balance, unauthorized actor, duplicate request/reference, and partial persistence.
2. Successful transfer creates one aggregate and exactly two equal/opposite linked entries atomically; both accounts’ statements show the correct transfer direction and counterparty.
3. Transfer affects no stock, customer/supplier balance, sale, purchase, expense, or revenue total.
4. Retry returns the original completed transfer without a second pair.
5. Reversal is owner-only, requires reason, creates exactly one linked opposite pair, and cannot repeat.
6. Saved transfers and historical entries cannot be edited or deleted.
7. Backup/restore/preview and old backup compatibility preserve transfer relationships and reject incomplete pairs.
8. Functional Arabic RTL UI provides review then one final confirmation, validation feedback, clear return navigation, and no placeholder.
9. Existing financial-account, sales, purchase, collection, supplier-payment, expense, inventory, backup, and accounting regression tests remain passing.

## Phase 75 Acceptance Evidence

- All `DC-U013`–`DC-U024` decisions are recorded as owner-decided without changing `DC-U006`.
- Master roadmap, traceability matrix, and handoff notes define Phase 76 without claiming implementation.
- No production code, UI, schema, migration, or backup-format/version change is made.
