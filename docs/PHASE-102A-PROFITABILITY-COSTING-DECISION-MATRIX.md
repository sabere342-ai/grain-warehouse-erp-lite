# Phase 102A — Profitability and Costing Decision Matrix

Date: 2026-07-27
Status: contracts approved by owner; Phase 102B implementation authorized. Actual profitability activation remains blocked until real opening quantities, costs, evidence and activation date are approved.

## Costing-method decision

| Method | Fit for interchangeable grain | Auditability | Runtime/storage cost | Cancellation behavior | Decision |
|---|---:|---:|---:|---:|---|
| Perpetual moving weighted average | High | High when every movement stores value before/after | Moderate | Exact sale reversal is possible from stored snapshots; old purchase cancellation needs a corrective workflow | **Selected** |
| Periodic weighted average | Medium | Medium; COGS changes until the period closes | Low–moderate | Reopening/recalculation risk conflicts with immutable closed periods | Rejected |
| FIFO | Medium | High | High because cost layers and layer reversals are required | Complex after partial consumption and cancellations | Rejected for current product scope |
| Specific identification | Low | High only with physical lot identity | High | Requires lot traceability that does not exist | Rejected |
| Standard/reference cost | Low as an accounting cost; useful only as an estimate | Low unless variances are fully posted | Low | A later product edit can rewrite an estimate of history | Rejected as COGS; retain only as clearly labelled advisory data |

The selection is consistent with the IFRS Foundation's IAS 2 summary: interchangeable inventory may use FIFO or weighted average, and the carrying amount is recognized as expense when the related revenue is recognized. This project decision is a software accounting contract, not a representation that the application by itself provides statutory IFRS compliance. Source: [IFRS Foundation — IAS 2 Inventories](https://www.ifrs.org/issued-standards/list-of-standards/ias-2-inventories/).

## Transaction decision matrix

| Transaction | Revenue | COGS / inventory expense | Operating expense | Receivable / payable | Cash movement | Inventory quantity/value |
|---|---:|---:|---:|---:|---:|---|
| Cash sale | Yes, at completed sale | Yes, original stored COGS | No | No outstanding receivable | Inflow | Quantity and carrying value decrease |
| Credit sale | Yes, at completed sale | Yes, original stored COGS | No | Receivable increases | Only paid portion, if any | Quantity and carrying value decrease |
| Collection of an old invoice | No new revenue | No | No | Receivable decreases | Inflow | No effect |
| Customer advance receipt/application | No until a sale exists | No | No | Advance liability/credit changes | Receipt is inflow; application is non-cash | No effect until sale |
| Customer advance refund | No | No | No | Advance decreases | Outflow | No effect |
| Inventory purchase, paid or credit | No | No immediate COGS | No period expense merely because purchased | Payable reflects unpaid portion | Paid portion is outflow | Quantity and carrying value increase by accepted acquisition cost |
| Supplier settlement | No | No | No | Payable decreases | Outflow | No effect |
| Supplier advance/refund | No | No | No | Supplier advance changes | Cash changes | No inventory effect until purchase allocation |
| Operating expense | No | No | Yes, once accepted under the classification contract | None in the current paid-only model | Outflow when routed to an account | No effect |
| Transfer between financial accounts | No | No | No | No | Internal in/out pair; excluded from net business cash movement | No effect |
| Sale cancellation | Reverse original revenue | Reverse the **stored original** COGS | No | Reverse sale ledger effect | Reverse only original paid allocations | Restore original quantity and carrying value snapshot |
| Purchase cancellation before consumption | No | No | No | Reverse purchase ledger effect | Reverse original paid amount | Remove original quantity/value when traceably untouched |
| Purchase already mixed, sold, or closed | No direct action allowed | No silent recalculation | No | No silent reversal | No silent reversal | Block cancellation; use dated corrective return/adjustment policy |
| Stocktake shortage/manual decrease | No | Inventory loss at current moving-average cost | Included in operating result as inventory loss, separately disclosed | No | No | Quantity/value decrease |
| Stocktake surplus/manual increase | No | No immediate COGS | No | No | No | Quantity/value increase only from an approved, explicit cost source |
| Opening inventory | No | No immediate COGS | No | No | No | Establishes opening quantity and owner-approved value; never a purchase |

## Opening-inventory options

| Option | Contract | Historical accuracy | Risk | Recommendation |
|---|---|---|---|---|
| A — owner value at activation | Owner enters approved physical-count quantity and integer-qirsh cost per kg from trusted purchase evidence, with timestamp and audit identity | Accurate from the activation boundary forward | Requires accountable owner input | **Selected and approved** |
| B — zero/unknown value and accuracy starts later | Block COGS until every unknown unit leaves inventory | Accurate only after a potentially indeterminate date | Mixed pools are difficult to explain | Fallback only |
| C — deterministic trusted migration | Reconstruct from verified source records and reconciliation | Could extend accuracy backward | Current repository lacks enough cost snapshots and opening values | Not presently feasible |

## Frozen implementation invariants

1. Monetary totals remain integer qirsh; binary floating point is prohibited.
2. Quantity remains integer kilograms in the current contract; one ton is exactly 1,000 kg.
3. Maintain per-product on-hand quantity and total inventory value. Derive moving average using deterministic fixed-point/rational arithmetic with an explicitly carried residual.
4. A purchase adds accepted acquisition value to inventory; payment timing never changes COGS.
5. Every sale line stores unit-cost precision, integer-qirsh COGS, and inventory quantity/value before and after posting.
6. Sale cancellation uses the original stored snapshots; it never consults today's average or mutable reference cost.
7. Closed periods are immutable. No later purchase, cancellation, stocktake, restore, or migration may silently recalculate them.
8. Missing or ambiguous cost data yields `unavailable` or an explicitly labelled `estimated` period, never a precise profit KPI.
9. The system remains `profitabilityNotActivated` until the owner approves the real opening snapshot and activation date; tests may use clearly identified fixtures only.
10. Expense accounting classification is mandatory and independent of free text: `operating`, `capital`, or `nonOperating`. Only `operating` reduces net operating profit.
