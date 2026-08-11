# Scenario contract

All monetary values in code are integer qirsh; 100 qirsh = 1 EGP.

| Item | Value |
| --- | ---: |
| Source account before | 1,000,000 qirsh (10,000 EGP) |
| Destination account before | 200,000 qirsh (2,000 EGP) |
| Internal transfer | 300,000 qirsh (3,000 EGP) |
| Source account after | 700,000 qirsh (7,000 EGP) |
| Destination account after | 500,000 qirsh (5,000 EGP) |
| Combined before and after | 1,200,000 qirsh (12,000 EGP) |

Required invariants:

- source delta = -300,000 qirsh;
- destination delta = +300,000 qirsh;
- source delta + destination delta = 0;
- exactly one transfer document exists after an identical retry;
- exactly one `transferOut` and one `transferIn` entry reference that document;
- the two signed ledger amounts sum to zero;
- an all-account inflow/outflow report excludes both transfer legs;
- a single-account report retains the applicable leg;
- the transfer report contains the business transfer once, for 300,000 qirsh;
- revenue, expense, gross profit and net profit do not change because the
  transfer command creates no sale or expense business record.

Two opposite ledger rows are the correct representation of one transfer. A
double-count defect would require those rows to create a non-zero combined
balance or to enter an economic inflow/outflow/profit aggregate twice.
