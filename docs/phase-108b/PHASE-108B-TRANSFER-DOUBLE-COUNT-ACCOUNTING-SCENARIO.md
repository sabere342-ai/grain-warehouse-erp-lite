# Phase 108B — Transfer Double-Count Accounting Scenario

## 1. Final Outcome

**Outcome A2 — FULL SUCCESS: no defect; concern disproved and guarded.**

**DOUBLE-COUNT DEFECT: NO**

The internal transfer moves value without creating or destroying it. The direct
scenario produces one business transfer, one outgoing ledger entry, one incoming
ledger entry, a zero signed net movement across both accounts, and no
all-account inflow/outflow or profit effect.

## 2. Baseline & Repository State

- Baseline: `e0e4ddf4249282afc347a96370a38fa2617280e9`
- Baseline subject: `PHASE 108A: re-audit and reorder implementation priorities`
- Branch: `codex/phase-107h-governed-14-day-trial-windows-package-acceptance`
- Expected HEAD matched actual HEAD exactly.
- Unexpected starting paths: none.
- Starting production diff: none.

Preserved 107H paths:

- four modified Phase 106 product-read migration tests;
- untracked `docs/phase-107h/`;
- untracked `tools/phase107h/`.

They were not edited, formatted in write mode, staged, or committed by 108B.
See `evidence/20260811-135916/00-git-baseline.txt`.

## 3. Scenario Definition

Create two internal financial accounts, seed 10,000 EGP and 2,000 EGP, transfer
3,000 EGP from the first to the second through the real repository command, retry
the identical request, then inspect the document, ledger, balances and report
consumers. Add a genuine 100 EGP `salePayment` afterward only as a negative
control proving genuine inflow remains included.

## 4. Accounting Contract

- Source: 10,000 -> 7,000 EGP.
- Destination: 2,000 -> 5,000 EGP.
- Combined: 12,000 -> 12,000 EGP.
- Transfer rows: exactly two, equal and opposite.
- Transfer documents: exactly one, including after identical retry.
- All-account economic inflows/outflows: delta zero.
- Revenue, expense, gross profit and net profit: delta zero.

The repository uses inflow/outflow terminology rather than a general-journal
debit/credit label. For this internal asset transfer, the 3,000 EGP outgoing and
3,000 EGP incoming legs are the balanced pair; their signed sum is zero.

## 5. Production Data Flow

```text
Transfer command
  -> FinancialTransfer document
  -> transferOut + transferIn ledger entries
  -> signed account balances
  -> account-specific statement/flow views
  -> one-row transfer report
  -> transfer types excluded from all-account economic flow totals
```

Profit and dashboard revenue/expense metrics are sourced from sales and expense
repositories, not financial transfer entries. The durable Drift adapter persists
the same document and linked entries within its write boundary. Backup/restore
and business-data wipe already include the transfer collection. Full anchors and
duplicate-pattern audit are in `evidence/20260811-135916/02-transfer-data-flow.md`.

## 6. Before State

| Metric | Value |
| --- | ---: |
| Source balance | 1,000,000 qirsh |
| Destination balance | 200,000 qirsh |
| Combined balance | 1,200,000 qirsh |
| Transfer documents | 0 |
| Transfer ledger rows | 0 |

## 7. Transfer Operation

`FinancialAccountRepository.createTransfer` received one 300,000-qirsh draft
with stable client request ID and transfer reference. The exact same draft was
submitted twice to exercise idempotency.

## 8. Expected State

Source 700,000 qirsh; destination 500,000 qirsh; combined 1,200,000 qirsh; one
transfer document; two linked opposite entries; signed net zero; no all-account
flow or profit delta.

## 9. Actual State

Actual state matched every expected value. The retry returned the original ID,
left one document, and created no additional ledger rows. Account-specific views
showed 300,000 qirsh on the applicable side; the all-account inflow and outflow
views both showed zero for the transfer; the transfer report showed 300,000
qirsh once. See the before/after JSON and comparison evidence.

## 10. Double-Count Decision

**DOUBLE-COUNT DEFECT: NO**

The two ledger rows are correct double-entry-style representation, not duplicate
economic value. No tested aggregate converts the pair into a doubled effect.

## 11. Root Cause

There was no production accounting root cause. The verification gap came from a
stale test fixture: the Phase 9A test manually inserted transfer-shaped entries,
configured negative balances, requested an approval it never consumed, and was
then skipped for an authentication reason. It therefore never executed either
its original report assertions or the real transfer command.

Resolution: remove that unrelated approval fixture, execute the real
positive-balance transfer command, retain the original all-account assertions,
and add direct arithmetic, ledger, report and retry assertions.

## 12. Changes Made

- Production: none.
- Tests: one existing Phase 9A test activated and strengthened; skip removed.
- Docs: this report and deterministic evidence package.
- Schema/platform/dependencies: none.

## 13. Accounting Invariants

All pass:

- `sourceDelta + destinationDelta == 0`;
- `totalBefore == totalAfter == 1,200,000 qirsh`;
- outgoing amount equals incoming amount equals 300,000 qirsh;
- signed ledger sum equals zero;
- one transfer document and two linked rows after retry;
- revenue/expense/profit deltas equal zero.

## 14. Negative Controls

- NC1: real sale payment still increases all-account inflow — PASS.
- NC2: real expense still increases all-account outflow — PASS.
- NC3: transfer does not enter profit inputs; profitability tests — PASS.
- NC4: combined internal balance unchanged — PASS.
- NC5: correct opposite pair retained, not mistaken for duplication — PASS.

## 15. Validation Results

| Gate | Result |
| --- | --- |
| Focused Phase 9A | 43 passed, 0 skipped, 0 failed |
| Targeted financial matrix | 126 passed, 0 skipped, 0 failed |
| Full suite | 2,418 passed, 0 skipped, 0 failed |
| Analyzer | No issues found |
| Format | 428 files, 0 changed |
| Windows release build | PASS |

The build emitted only the existing non-blocking CMake deprecation and MSVCRT
`.voltbl` linker warnings. No build binary is committed.

## 16. Risk Closure

```text
Risk: FIN-001 (R1) — skipped transfer double-count edge
Previous state: Still open; sole skipped accounting scenario
Evidence before 108B: 42 Phase 9A tests passed and this scenario skipped
108B reproduction result: Real transfer executed; no double-count occurred
Root cause: Stale/irrelevant skipped test fixture, not production accounting
Resolution: Execute real positive-balance transfer and preserve/strengthen assertions
Regression guard: Active Phase 9A no-double-count scenario with ledger, balance,
                  report and idempotency checks
Final state: CLOSED — scenario disproved
```

## 17. Git / Commit Provenance

The Phase 108B commit is intentionally one commit with parent
`e0e4ddf4249282afc347a96370a38fa2617280e9` and subject:

`PHASE 108B: close transfer double-count accounting scenario`

Only the Phase 108B test and documentation paths are eligible for staging.

## 18. Remaining Dirty Worktree Reconciliation

After the isolated commit, the worktree is expected to remain dirty only for
the exact six preserved 107H path groups listed in section 2. A dirty worktree
with only those paths is the accepted baseline, not a Phase 108B failure.

## 19. Final Decision

- Does Transfer double value? **No.**
- Does it affect revenue? **No.**
- Does it affect expense? **No.**
- Does it affect profit? **No.**
- Are total account balances equal before/after? **Yes: 12,000 EGP.**
- Is FIN-001 closed? **Yes — CLOSED, scenario disproved and guarded.**
- Is any accounting blocker left by this scenario? **No.**

Recommended next phase: **108C — Cloud Operating Model and Data Authority Decision Freeze**

Reason: Phase 108A ranked authority, tenancy, identity, time, multi-device write,
conflict and licensing decisions ahead of Cloud implementation.

Dependency satisfied by 108B: the sole ambiguous local transfer accounting
invariant is now directly executed, green, and guarded with zero skipped tests.
