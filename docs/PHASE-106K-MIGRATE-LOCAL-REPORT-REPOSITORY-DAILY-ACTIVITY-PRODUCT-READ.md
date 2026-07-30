# Phase 106K — Migrate LocalReportRepository Daily Activity Product Read

## Outcome

**Outcome A — FULL SUCCESS**

`LocalReportRepository.dailyActivityReport` now obtains its complete product
snapshot exclusively through `ProductCatalogReadRepository`. The daily report
keeps the historical inactive-product, nullable-cost, integer-piaster,
ordering, aggregation, date-range, and error-propagation behavior. No other
report method or product-read consumer was migrated.

## Phase data

| Item | Value |
| --- | --- |
| Branch | `codex/phase-106k-migrate-local-report-repository-daily-activity-product-read` |
| Starting HEAD | `c6e96119a473333565ae610ae6fb9a443cf74cb0` |
| Starting subject | `PHASE 106J: extend product catalog read model with reference cost` |
| Initial worktree | Clean |
| Final HEAD | The single Phase 106K commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 106K: migrate daily activity product read` |
| Commits after baseline | Exactly `1` required and verified after commit |
| Final worktree | Clean required and verified after commit |
| Final phase diff | `17 files changed, 627 insertions(+), 25 deletions(-)` |
| Push / Tag | Not performed / not created |

## Implemented migration

### Previous path

```text
LocalReportRepository.dailyActivityReport
→ ProductRepository.listProducts(includeInactive: true)
→ List<Product>
```

### New path

```text
LocalReportRepository.dailyActivityReport
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ List<ProductCatalogReadModel>
```

`ProductCatalogReadRepository` is constructor-injected. Production composition
passes `AppRepositories.productCatalogReadRepository`; the report repository
does not instantiate Drift, access `FoundationDatabase`, or select the
`products` table directly.

The migrated read uses `includeInactive: true`, matching the previous complete
snapshot and preserving historical reporting when a product has since become
inactive. The catalog adapter retains its frozen `createdAt ASC, id ASC`
ordering, so product-derived report ordering is unchanged.

`ProductCatalogReadModel.referenceCostPricePiastersPerKg` is forwarded directly
to the existing `BusinessSummaryCalculator` compatibility projection as the
same nullable Dart integer. There is no division, multiplication, rounding,
EGP conversion, or zero substitution in the read path. A missing cost stays
`null`, so incomplete sales-cost and stock-valuation results remain incomplete
instead of becoming zero-valued estimates.

The migrated method performs exactly one catalog call per report invocation.
It contains no legacy product read, dual read, fallback, cache, retry, error
swallowing, transaction, or write. Catalog errors propagate unchanged before
the remaining report sources are read.

## Accounting and output preservation

The migration leaves the following logic unchanged:

- selected-date local day boundaries (`start` inclusive, next day exclusive);
- cancelled purchase and sale filtering;
- purchase, sale, expense, collection, receivable, supplier-payment, and
  payable totals;
- quantity and money units;
- reference-cost multiplication and gross-profit arithmetic;
- missing-product and missing-cost labels/flags;
- product stock-balance order and reversed recent-movement order;
- immutable output lists and the public `DailyActivityReport` contract.

The focused test uses an inactive product with an exact reference cost of
`12347` piasters/kg. A 3 kg sale produces an exact estimated cost of `37041`
and a 2 kg balance produces an exact stock value of `24694`, proving that the
boundary does not round or convert the value.

## Verification evidence

| Gate | Result |
| --- | --- |
| Phase 106K focused test | PASS — 5 passed, 0 failed, 0 skipped |
| Related report/catalog regression | PASS — 97 passed, 0 failed, 0 skipped across 15 files |
| Full `flutter test` | PASS — 2072 passed, 0 failed, 1 historical skip; 165.8 s wall time |
| Historical skip | Unchanged credential-dependent skip in `test/phase9a_inflows_outflows_reports_test.dart` |
| Formatter | PASS — 387 Dart files checked, 0 changed; 4.61 s |
| Analyzer | PASS — `No issues found`; 21.7 s analyzer time |
| `git diff --check` | PASS — exit 0, no whitespace errors |
| Windows release | PASS — exit 0; 65.3 s Flutter build time, 67.0 s wall time |
| EXE path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| EXE size | `784384` bytes |
| SHA-256 | `81A8A84F718E4679C78DFECF1D09BCE66858FCC1EBA0D3122A4033F5789E7A4C` |
| Native smoke | NOT RUN — user database isolation is not proven |

The first sandboxed Windows build stalled without output and was terminated.
The identical build completed outside that sandbox restriction. It emitted
only the existing non-fatal Firebase CMake minimum-version deprecation warning
and `.voltbl` linker warning.

## Tests and directly related updates

The phase test is:

- `test/phase106k_local_report_repository_daily_activity_product_read_migration_test.dart`

It executes the real `LocalReportRepository.dailyActivityReport` production
implementation with isolated fakes and proves:

- exclusive use of the new catalog boundary;
- `includeInactive: true` and preservation of an inactive product;
- exact non-zero `12347`-piaster cost arithmetic;
- `null` cost remains incomplete rather than becoming zero;
- no repository writes;
- unchanged catalog error propagation with no fallback or retry;
- fresh results across repeated calls with no cache;
- totals, date boundaries, stock balances, and movement ordering.

Existing tests that construct `LocalReportRepository` now supply the catalog
test adapter. The Phase 106I historical assertions that describe the
pre-migration state read the immutable Phase 106I commit, preserving their
original freeze proof instead of asserting that the current source remains
legacy.

## Changed files

Production (exactly two files):

- `lib/core/reports/report_repository.dart`
- `lib/app/app_repositories.dart`

Tests:

- `test/phase106k_local_report_repository_daily_activity_product_read_migration_test.dart`
- `test/phase106i_next_product_read_contract_expansion_discovery_freeze_test.dart`
- `test/reports_test.dart`
- `test/phase11_ux_test.dart`
- `test/phase21c_profit_stock_valuation_reports_test.dart`
- `test/phase21d_end_to_end_business_release_test.dart`
- `test/phase31_functional_recovery_test.dart`
- `test/phase32_pilot_acceptance_test.dart`
- `test/phase35_customer_credit_ui_pilot_qa_test.dart`
- `test/phase36g_ui_clarity_cancellation_safety_test.dart`
- `test/phase37c_dashboard_labels_test.dart`
- `test/phase51_real_business_day_simulation_test.dart`
- `test/phase52_accounting_freeze_audit_test.dart`
- `test/phase53_cloud_migration_readiness_test.dart`

Documentation:

- `docs/PHASE-106K-MIGRATE-LOCAL-REPORT-REPOSITORY-DAILY-ACTIVITY-PRODUCT-READ.md`

## Scope and prohibitions preserved

No schema, database version, migration, product-table, frozen catalog contract,
Drift catalog adapter, UI, controller, route, navigation, dashboard, sales,
inventory, COGS, profitability activation, write repository, dependency,
platform file, user data, push, tag, merge, or additional consumer migration
was performed. The production application and release EXE were not launched.
The user database was not opened, read, copied, modified, deleted, moved,
renamed, backed up, or migrated.

## Next phase proposed only

**Phase 106L — Prove Genuine Runtime Local Report Daily Activity Product Read
Integration**

Phase 106L was not implemented.
