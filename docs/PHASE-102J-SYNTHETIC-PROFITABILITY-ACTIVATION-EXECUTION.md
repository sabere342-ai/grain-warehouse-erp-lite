# Phase 102J — Synthetic Profitability Activation Execution

## Outcome

**Outcome A — PASSED IN AN ISOLATED SYNTHETIC SANDBOX**

The trial ran through `tool/run_phase102j_synthetic_trial.dart` against a new
SQLite database outside the repository. The production application repository
wiring does not expose the synthetic activation service.

## Execution identity

| Item | Actual result |
| --- | --- |
| Branch | `codex/phase-102j-owner-approved-synthetic-inventory-profitability-activation-trial` |
| Resumption commit | `3e2446b10b1e984422c2871a80f5ac9915e5cd04` |
| Database identity | `PHASE-102J-TEST-SANDBOX` |
| Data classification | `SYNTHETIC_TEST_DATA` |
| Database path | `C:\Users\saber\AppData\Local\Temp\phase102j-trial-20260728-1805\phase102j_sandbox.sqlite3` |
| Evidence file | `C:\Users\saber\AppData\Local\Temp\phase102j-trial-20260728-1805\phase102j_execution_evidence.json` |
| Package SHA-256 | `461F3EE16B2895E3AC898352384EA0D927A49688912A3B6DB4C7C62B96271DFC` |
| Submitted / validated / rejected / written | `12 / 12 / 0 / 12` |
| Quantity / valuation | `73,650 kg / 1,680,090.00 EGP` |
| Activation state | `syntheticProfitabilityActivatedForTest` |
| Production activation boolean | `false` |

## Safety design

- `ProfitabilityActivation.isActivated` remains true only for genuine
  production activation.
- Synthetic valuation operations require the separate
  `syntheticProfitabilityActivatedForTest` state.
- The intake coordinator requires an active owner, the exact sandbox identity,
  a 64-character package hash, an empty database, unique rows, exact valuation,
  and a synthetic classification.
- Product creation, opening inventory, opening valuation, and audit logging
  share one rollback boundary.
- A simulated audit failure test proved that products, movements, valuation,
  events, and activation all roll back.
- The profitability screen displays an explicit synthetic-test warning if such
  a backup is ever opened there.

## Profitability scenario

The first workbook row was used for a 100 kg synthetic sale:

| Measure | Result |
| --- | ---: |
| Sale price | 25.00 EGP/kg |
| Revenue | 2,500.00 EGP |
| COGS | 1,875.00 EGP |
| Gross profit | 625.00 EGP |
| Stock restored after cancellation | Yes |
| Inventory value restored after cancellation | Yes |

No production or customer database was selected, read, or modified.
