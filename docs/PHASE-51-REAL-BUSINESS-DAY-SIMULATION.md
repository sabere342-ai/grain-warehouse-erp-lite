# Phase 51 - Real Business Day Simulation

## Phase purpose
Phase 51 simulates a realistic local business day on the current Windows pilot. It verifies that the existing local purchase, sale, customer account, supplier account, inventory, report, stock-taking, stock adjustment report, and document history behavior remains internally consistent before cloud migration planning resumes.

No cloud sync was implemented in Phase 51.
No mobile app was implemented in Phase 51.
No multi-device live sync was implemented in Phase 51.

This phase does not add SaaS behavior, cloud screens, backend APIs, API keys, new visible features, or synchronization components.

## Baseline
- Starting commit: `f865667`
- Starting tag: `phase-50-local-pilot-lock`
- Production code changed in this phase: no
- Schema changed in this phase: no
- Tests added: `test/phase51_real_business_day_simulation_test.dart`
- Production fix required: none

## Simulation scope
The simulation covers:
- Product catalog
- Purchases
- Sales
- Customers
- Suppliers
- Customer balances
- Supplier balances
- Customer collections
- Supplier payments
- Expenses
- Inventory quantities
- Inventory movement history
- Stock-taking through the existing manual increase/decrease movement model
- Stock adjustment report read-only safety
- Daily report / owner reports
- Document history

Backup/restore is not repeated in this Phase 51 test because previous phases already cover backup/restore and adding it here would make the business-day simulation broader and more brittle than needed.

## Synthetic business-day scenario
This scenario uses test-only synthetic data. These numbers are simulation fixtures only, not real client balances or accounting numbers.

1. Start with a clean local repository state.
2. Add products:
   - قمح بلدي
   - ذرة صفراء
   - أرز أبيض
3. Add supplier:
   - مورد اختبار اليوم
4. Add customer:
   - عميل اختبار اليوم
5. Record purchase intake:
   - Buy 500 kg قمح بلدي at 1,500 qirsh per kg = 750,000 qirsh
   - Buy 300 kg ذرة صفراء at 1,200 qirsh per kg = 360,000 qirsh
6. Record sales:
   - Credit sale of 200 kg قمح بلدي at 2,200 qirsh per kg = 440,000 qirsh
   - Cash sale of 100 kg ذرة صفراء at 1,800 qirsh per kg = 180,000 qirsh
7. Record customer collection:
   - Collect 200,000 qirsh from عميل اختبار اليوم
8. Record supplier payment:
   - Pay 300,000 qirsh to مورد اختبار اليوم
9. Record simple expense:
   - Operating expense = 25,000 qirsh
10. Run stock-taking style adjustment using the existing supported stock movement model:
   - Add 50 kg to أرز أبيض with the stock-taking note.
11. Review the stock adjustment report as read-only.
12. Review document history for purchase and sale records.

Expected simple results:
- قمح بلدي final quantity: 500 - 200 = 300 kg
- ذرة صفراء final quantity: 300 - 100 = 200 kg
- أرز أبيض final quantity: 50 kg manual stock-taking increase
- Customer balance: 440,000 credit sale - 200,000 collection = 240,000 qirsh
- Supplier balance: 1,110,000 purchases - 300,000 payment = 810,000 qirsh
- Daily sales total: 440,000 + 180,000 = 620,000 qirsh
- Daily purchase total: 750,000 + 360,000 = 1,110,000 qirsh

## Expected accounting and stock invariants
### Inventory
- Final product quantity must equal signed stock movements recorded by purchases, sales, and supported stock-taking adjustments.
- Stock movement history must not contradict final product quantity.
- Purchase intake must create purchase stock movements.
- Sales must create sale stock movements.
- Stock-taking adjustments must use supported manual increase/decrease movement types.
- Customer collections, supplier payments, and expenses must not create stock movements.
- Stock adjustment report must remain read-only and must not invent before/after balances.

### Customers
- Customer balance must match source sale and collection documents.
- Customer collection must reduce receivable balance.
- Cash sale entries must not create receivable balance.
- Customer balance must not change because of supplier payment or inventory-only operations.

### Suppliers
- Supplier balance must match source purchase and supplier payment documents.
- Supplier payment must reduce payable balance.
- Supplier balance must not change because of customer collection or inventory-only operations.

### Reports
- Daily report totals must match recorded purchases, sales, payments, collections, expenses, and inventory movements.
- Report totals must be derived from repository model data, not mutable UI text.
- No report should claim cloud, mobile, or multi-device sync support.

### Documents
- Document history must show created purchase and sale documents where supported.
- Posted documents must not be silently deleted.
- Cancellation/reversal behavior is already covered by existing purchase, sale, and document history tests; Phase 51 does not add a new cancellation scenario because the selected business-day flow includes customer collection and supplier payment, which intentionally make some cancellation paths unsafe.

## Stop conditions
Stop the pilot if any of these happen during simulation:
- Stock quantity becomes negative unexpectedly
- Customer balance does not match source documents
- Supplier balance does not match source documents
- Daily report totals do not match source records
- Stock movement history contradicts product quantity
- Stock-taking adjustment creates a misleading or unsupported record
- Stock adjustment report changes data instead of reading data
- Cancellation does not create proper reversal behavior where expected
- Backup/restore changes stock, balances, or documents unexpectedly if tested
- Any visible page appears fake, empty, misleading, or not functional
- Any client package includes source files or developer-only files

## Result table
| Scenario area | Verified by test/manual check | Result | Notes |
|---|---|---|---|
| Purchases update stock | Automated test | Pass | Purchase intake creates stock movements and supplier payable entries |
| Sales reduce stock | Automated test | Pass | Credit and cash sales reduce inventory |
| Customer balance matches documents | Automated test | Pass | Credit sale plus collection leaves 240,000 qirsh receivable |
| Supplier balance matches documents | Automated test | Pass | Purchase entries plus payment leave 810,000 qirsh payable |
| Daily report totals | Automated test | Pass | Report matches purchase, sale, collection, payment, expense, and stock totals |
| Inventory movement history | Automated test | Pass | Signed movements match final product quantities |
| Stock-taking adjustment | Automated test | Pass | Existing manual increase movement is used with stock-taking note |
| Stock adjustment report read-only safety | Automated widget test | Pass | Refreshing the report does not mutate stock or movements |
| Document history | Automated test | Pass | Created purchase and sale documents remain visible |
| Cancellation/reversal consistency | Existing automated tests | Pass | Covered by existing purchase, sale, and document history cancellation tests |
| Backup/restore | Existing automated tests | Pass | Not repeated in this focused Phase 51 scenario |
| Cloud/mobile/sync absence | Automated documentation test | Pass | Phase 51 explicitly states no cloud, no mobile, no multi-device live sync |

## Deferred items
- Cloud/mobile migration is not part of Phase 51.
- Multi-device live sync is not part of Phase 51.
- Cloud readiness resumes later after local accounting behavior is proven.
- Rich stock adjustment PDF/export still requires reliable before/after stock balances first.
