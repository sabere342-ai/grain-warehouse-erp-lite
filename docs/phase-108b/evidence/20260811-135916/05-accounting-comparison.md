# Accounting comparison

| Metric | Before | Expected after | Actual after | Result |
| --- | ---: | ---: | ---: | --- |
| Source balance | 1,000,000 | 700,000 | 700,000 | PASS |
| Destination balance | 200,000 | 500,000 | 500,000 | PASS |
| Combined balance | 1,200,000 | 1,200,000 | 1,200,000 | PASS |
| Transfer documents | 0 | 1 | 1 | PASS |
| Source transfer rows | 0 | 1 | 1 | PASS |
| Destination transfer rows | 0 | 1 | 1 | PASS |
| Source/outgoing amount | 0 | 300,000 | 300,000 | PASS |
| Destination/incoming amount | 0 | 300,000 | 300,000 | PASS |
| Signed transfer net | 0 | 0 | 0 | PASS |
| All-account inflow total | 0 | 0 | 0 | PASS |
| All-account outflow total | 0 | 0 | 0 | PASS |
| Transfer report total | 0 | 300,000 | 300,000 | PASS |
| Revenue delta | 0 | 0 | 0 | PASS |
| Expense delta | 0 | 0 | 0 | PASS |
| Profit delta | 0 | 0 | 0 | PASS |

Negative controls:

- NC1 PASS: `salePayment` remains included in the all-account inflow report
  (10,000 qirsh in the scenario after the transfer-only assertions).
- NC2 PASS: the adjacent Phase 9A expense test remains green and includes a
  real expense in the outflow report.
- NC3 PASS: transfer writes no sale/expense record and cannot enter the
  profitability service inputs; profitability regressions pass.
- NC4 PASS: source plus destination stays 1,200,000 qirsh.
- NC5 PASS: two linked opposite ledger entries are retained and asserted, while
  only their inappropriate economic aggregation is excluded.

Decision: **DOUBLE-COUNT DEFECT: NO**.
