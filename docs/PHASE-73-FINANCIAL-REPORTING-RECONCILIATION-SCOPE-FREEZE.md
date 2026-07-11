# Phase 73 — Financial Reporting & Reconciliation Scope Freeze

## Phase Type and Verified Baseline

This is a documentation, architecture, and decision-register phase only. It does not implement production features.

- Baseline phase: Phase 72 — Transaction Integration
- Baseline commit: `bc2769a`
- Baseline tag: `phase-72-transaction-integration`
- Baseline verification: analyze passed, 673/673 tests passed, Windows release build passed, and `git diff --check` passed.
- Phase 66 remains not executed and has no tag.

## Why a Scope Freeze Was Required

The master roadmap grouped the next work under “Financial Reporting & Reconciliation,” while the traceability matrix listed internal transfers (`ACC-011`), daily cash closing (`ACC-012`), and financial reports (`ACC-013`) as deferred. Developer handoff notes also referred to transfers, daily close, reports, and transaction-selection UI as “Phase 73” work. None of those documents had previously defined an official Phase 73 title, bounded scope, decision gate, or acceptance criteria.

Beginning production work from those conflicting descriptions would require inventing accounting behavior, especially for daily closing. This phase resolves that documentation conflict without claiming that a financial feature exists.

## Current Source-of-Truth Requirements

### ACC-011: Internal transfers

| Field | Current text / state |
|---|---|
| Source evidence | Future requirement — transferring between treasury/bank/wallet. |
| Implementation evidence | None. |
| Missing behavior | Transfer model, between-account balance adjustments. |
| Dependency | ACC-007. |
| Phase 73 result | Planned — scope frozen; not implemented. |

### ACC-012: Daily cash closing

| Field | Current text / state |
|---|---|
| Source evidence | Future requirement — end-of-day cash reconciliation. |
| Implementation evidence | None. The daily activity report (`RPT-001`) provides cash in/out calculations but not a formal closing process. |
| Missing behavior | Cash closing process, expected vs. actual cash, discrepancy recording. |
| Dependencies | ACC-007 and ACC-010. |
| Phase 73 result | Planned — scope frozen; not implemented and blocked by `DC-U006`. |

### ACC-013: Financial reports

| Field | Current text / state |
|---|---|
| Source evidence | Future requirement — P&L, balance sheet, cash flow. |
| Implementation evidence | None. Current reports are operational, not financial accounting reports. |
| Missing behavior | Financial report generation from financial account data. |
| Dependencies | ACC-007 and ACC-008. |
| Phase 73 result | Planned — scope frozen; not implemented. |

## DC-U006: Daily Closing Level

`DC-U006 remains OPEN. No hard daily close, accounting-period lock, posting lock, automatic carry-forward, irreversible close, or backdated-entry restriction shall be implemented until an explicit owner decision is recorded.`

The available alternatives remain: full closing with physical count, summary only, or not required. Deferring implementation now is not a final decision to remove daily closing from the product roadmap.

## Dependency Map

```text
Phase 71: unified financial accounts
  └─ account types, append-only ledger, opening balances/corrections, statements, backup v4
      └─ Phase 72: transaction integration
          └─ sales, purchases, collections, supplier payments, expenses, cancellations post ledger entries
              ├─ future internal account transfers
              ├─ future cash count and reconciliation
              │   └─ future daily/period close only after DC-U006
              └─ future ledger-derived financial reporting
```

## Current Code Reality

The current model contains `FinancialAccount` types for treasury, bank, and electronic wallet. `FinancialAccountEntry` is append-only and records account ID, direction, integer-qirsh amount, source type, source document ID, effective date, creator, optional reversal linkage, and payment method. Current entry sources are opening balance, manual correction, restore import, sale payment, purchase payment, customer collection, supplier settlement, expense, and cancellation reversal.

There is no transfer model, no transfer source type, no reconciliation model, no daily-close or period-lock model, and no financial-account reporting workflow. The existing account statement is a ledger statement, not the planned reporting/reconciliation capability.

## Future Capability Boundaries

### Internal transfers

Future transfers may move value only between distinct financial accounts (treasury, bank, and/or electronic wallet). They are not revenue or expense and do not affect inventory, customer balances, or supplier balances.

### Cash counting, reconciliation, and close

Cash count and reconciliation remain separate planned capabilities. Their detailed workflow, discrepancy treatment, and whether any close locks posting remain owner-decision dependent. No automatic shortage expense, surplus income, balance carry-forward, or close is authorized by this phase.

### Statements and financial reporting

The existing ledger statement remains available. Future financial reports must have an approved report definition and derive values from source financial-account entries; they must not store independent balances or invented values.

### Auditability and reversals

Future financial movements must remain traceable by source, reference, timestamp, and actor. Posted history must not be silently changed. Cancellation must be documented reversal, not deletion.

## Accounting Invariants for Future Implementation

- Monetary values use integer qirsh only; no `double` money values.
- A transfer debit from the source account equals the credit to the destination account.
- Net transfer effect across all financial assets is zero, except for explicit, documented transfer fees.
- There are no silent balance mutations or duplicate sources of truth.
- Inventory, customer balances, and supplier balances do not change because of an internal financial transfer.
- Reports derive from auditable ledger entries.
- Any cancellation/reversal preserves historical entries and creates an auditable opposite movement.

## Impact Assessment

### Production code and schema

Phase 73 changes no production code and introduces no schema/model migration. A later implementation may require new models and ledger sources; its migration and compatibility requirements must be assessed then, before changing stored data.

### Backup and restore

Phase 73 does not change backup format or version. Future persisted transfer, reconciliation, or close records must be included in export, validation, preview, restore, old-version compatibility, and round-trip tests before a version change is approved.

### UI and navigation

Phase 73 adds no UI page, route, button, or permission. Any future transfer, reconciliation, close, or report UI requires a functional Arabic RTL flow, clear back path, validation, permissions at UI and repository layers, and no disabled/placeholder visible controls.

## Explicit Deferrals

- Internal transfers, treasury/bank/e-wallet movements, reconciliation, daily/period closing, transfer fees, and financial reports.
- Transaction-screen account and payment-method selection UI, which remains separate from the Phase 72 domain integration.
- Cloud sync, backend/API, multi-device support, and mobile application remain in the master roadmap but are not part of this phase.
- No Phase 74 or later implementation is started or approved here.

## Recommended Sequence After Phase 73

1. Obtain and record the owner decision for `DC-U006`; separately approve the transfer and fee policy.
2. Define one bounded internal-transfer implementation scope, including source/destination entries, reversal, permissions, validation, backup/restore, and atomicity tests.
3. Define the cash-count/reconciliation scope only after the owner policy is known.
4. Define ledger-derived financial reports with filters and report-specific acceptance criteria.
5. Perform production hardening and real owner trial before cloud, multi-device, or mobile work.

These are recommendations, not approved phase numbers or final phase names.

## Acceptance Criteria for This Documentation Phase

- Phase 73 is officially named in the master roadmap as a documentation-only scope freeze.
- Roadmap, traceability matrix, decision register, and handoff notes use a consistent status for `ACC-011`, `ACC-012`, `ACC-013`, and `DC-U006`.
- No production code, schema, backup version, or UI page is changed.
- Current code reality and the absence of transfer/reconciliation/close/report features are documented without false claims.
- Future accounting invariants, explicit deferrals, and dependency order are recorded.
- Full analyze, tests, Windows release build, and diff checks pass before commit and tag.
