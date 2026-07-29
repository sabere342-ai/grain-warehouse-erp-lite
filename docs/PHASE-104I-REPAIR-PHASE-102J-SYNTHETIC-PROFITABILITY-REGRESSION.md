# Phase 104I — Repair Phase 102J Synthetic Profitability Regression

## Outcome

**Outcome A — FULL SUCCESS: GLOBAL FULL SUITE ACCEPTANCE RESTORED**

The Phase 102J synthetic profitability failure was reproduced, isolated, and
repaired without changing production accounting behavior. The defect was a
test-harness time boundary: the sale used the current wall-clock timestamp,
while the report retained a fixed exclusive end of `2026-07-29 00:00:00`.
Once the calendar advanced to July 29, the report correctly excluded the sale.

## Starting point and branch

- Starting branch:
  `codex/phase-104h-controlled-audit-log-read-failure-runtime-integration`
- Starting HEAD: `44f403c0a9170661e1831e6b96da78bc17796c64`
- Phase branch:
  `codex/phase-104i-repair-phase-102j-synthetic-profitability-regression`
- Final commit: the single commit containing this report, with message
  `PHASE 104I: repair phase 102J regression and restore full suite`.
  Its exact hash is recorded in the final handoff after Git creates it.

The starting worktree was clean, the required branch and HEAD matched exactly,
and `git diff --check` passed before any change.

## Files changed

- `test/phase102j_synthetic_profitability_activation_test.dart`
- `tool/run_phase102j_synthetic_trial.dart`
- `docs/PHASE-104I-REPAIR-PHASE-102J-SYNTHETIC-PROFITABILITY-REGRESSION.md`

No production, Audit Log, schema, migration, cloud, or backend file changed.

## Failure reproduction before repair

The failing test was:

- group: `Phase 102J isolated synthetic profitability activation`
- test: `sandbox activation produces COGS and a synthetic profitability report`
- assertion: `report.salesRevenueQirsh`
- expected: `250000`
- actual: `0`
- original location: line 148

The pre-repair matrix established that this was deterministic:

| Reproduction | Result |
| --- | --- |
| Phase 102J file | FAIL — 4 passed, 1 failed, 0 skipped; 5.6 s |
| Failing test by exact plain name | FAIL — 0 passed, 1 failed; same mismatch |
| Three independent isolated reruns | FAIL each time — 4 passed, 1 failed |
| Randomized run, seed `10412026` | FAIL — 4 passed, 1 failed; same test |
| Related Phase 102 group | FAIL — 60 passed, 1 failed; only the same test |
| Full Suite, default concurrency | FAIL — 1943 passed, 1 failed, 1 skipped; 175.1 s |
| Full Suite, `-j 1` | FAIL — 1943 passed, 1 failed, 1 skipped; 322.5 s |

The serial Full Suite produced the same result, excluding concurrency, order,
and shared-state races as the cause.

## Proven root cause

The sale repository assigns `createdAt` from `DateTime.now()`. The report
service uses the correct half-open interval contract: start is inclusive and
end is exclusive. The Phase 102J scenario supplied a fixed report interval
`[2026-07-28, 2026-07-29)`.

The original Phase 102J commit was created on July 28, 2026, so its new sale
fell inside that interval. At reproduction time on July 29, 2026 at
approximately 17:33 Africa/Cairo, the same sale was after the fixed exclusive
end and was correctly omitted by the report.

The sale itself remained correct before repair:

- `sale.totalQirsh = 250000`
- `sale.totalCostOfGoodsSoldQirsh = 187500`
- only the report aggregation was empty because the sale was out of range

History comparison from original Phase 102J commit `d41e6afa` to the starting
HEAD showed no relevant production accounting change. The only test-file drift
was the intentional Audit Log API migration. This proves the regression was
calendar-sensitive test/tool orchestration, not a sale, valuation, reporting,
SQLite, singleton, path, unit-conversion, or Audit Log defect. No leaked state
was found.

## Minimal repair

Immediately after the sale is persisted, both the regression test and the
standalone synthetic trial derive:

`reportEnd = sale.createdAt.add(const Duration(microseconds: 1))`

They then pass `reportEnd` to the existing report service. Because the report
end is exclusive, one microsecond is the smallest direct seam that includes
the persisted sale timestamp. The activation start, expected revenue, COGS,
gross profit, inventory behavior, and all production code remain unchanged.

No expectation was weakened, no test was skipped, no delay was introduced, and
no production profitability activation was enabled. The existing end-to-end
scenario itself is the regression guard: it now remains valid on any later run
date while continuing to assert `250000` revenue, `187500` COGS, and `62500`
gross profit.

## Synthetic package and trial evidence

- package:
  `owner-input/phase_102j_synthetic_inventory_test_package.xlsx`
- SHA-256:
  `461F3EE16B2895E3AC898352384EA0D927A49688912A3B6DB4C7C62B96271DFC`
- validated/imported rows: `12`
- total quantity: `73650 kg`
- total value: `168009000 qirsh`
- duplicate replay rows: `12`
- activation: `syntheticProfitabilityActivatedForTest`
- production activation boolean: `false`
- persistence after reopen: `true`
- audit entries after reopen: `1`
- sale quantity: `100 kg`
- revenue: `250000 qirsh`
- COGS: `187500 qirsh`
- gross profit: `62500 qirsh`
- stock restored after cancellation: `true`
- value restored after cancellation: `true`
- backup/restore succeeded: `true`
- restored activation: `syntheticProfitabilityActivatedForTest`
- fresh production probe: `profitabilityNotActivated`

The tool exited successfully in 8.9 seconds. It used its own generated directory
under the operating-system temporary directory and explicitly rejected a
workspace artifact directory. It did not use the production database opener or
customer database. The synthetic evidence remained isolated from user data.

## Verification gates

| Gate | Result |
| --- | --- |
| Phase 102J after repair | PASS — 5 passed, 0 failed, 0 skipped |
| Three independent Phase 102J reruns | PASS each time — 5 passed, 0 failed |
| Related Phase 102 suite | PASS — 61 passed, 0 failed, 0 skipped; 11.9 s |
| Focused Audit Log suite (8I, 104B/C/E/F/G/H) | PASS — 42 passed, 0 failed, 0 skipped; 15.3 s |
| Full Suite run 1 | PASS — 1944 passed, 0 failed, 1 skipped; 153.2 s |
| Full Suite run 2 | PASS — 1944 passed, 0 failed, 1 skipped; 115.6 s |
| Analyzer | PASS — `No issues found!`; `--no-pub`; 8.8 s |
| Formatting | PASS — 2 Dart files, 0 changed by final check |
| `git diff --check` | PASS |
| Windows Release build | PASS — exit 0; Flutter 14.2 s, wall 15.5 s |
| Native smoke | NOT EXECUTED — production database isolation for native launch is not proven |

The standalone tool is not discovered or compiled by `flutter test`; its mirror
repair was additionally verified by executing the complete 12-row synthetic
trial, reopen, cancellation, backup/restore, and fresh-production probe.

The one Full Suite skip is pre-existing:

- `test/phase9a_inflows_outflows_reports_test.dart`, line 552
- reason: `Requires negative balance approval with actual credentials`

## Windows artifact

- Path:
  `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes
- SHA-256:
  `CC44073A2D836BF244758BD0B32CBDCEC34006FFFBCCCAF81DAFEDA47E753CAA`
- Non-blocking diagnostics: Firebase CMake minimum-version deprecation and
  linker warning `LNK4078` concerning `.voltbl` sections

## Final safety statements

- The accounting and half-open report-range contracts were preserved.
- Production profitability remains `profitabilityNotActivated`.
- No user or production database was opened, read, migrated, or modified.
- No schema, migration, Firebase, Supabase, REST, or cloud/backend work was
  added.
- No Audit Log implementation changed, and its 42 focused tests remain green.
- No push, tag, or native smoke was performed.
- Two green Full Suite runs restore global acceptance; the final Phase 104I
  commit is suitable as the governing baseline for the next phase.
