# Phase 106N — Prove Genuine Runtime Daily Activity Product Read Integration

## Outcome

**Outcome A — FULL SUCCESS**

The production daily-activity report now runs end-to-end through genuine
runtime SQLite (Drift in-memory), the real `DriftProductCatalogReadRepository`
adapter, and the migrated `DriftInventoryRepository.allProductBalancesKg()`
enumeration. The report executes against real data seeded directly into the
`products`, `inventory_movements`, and `sales` tables with no call — direct or
indirect — to `ProductRepository.listProducts()`.

## Phase data

| Item | Value |
| --- | --- |
| Branch | `codex/phase-106n-prove-runtime-daily-activity-product-read-after-inventory-migration` |
| Starting HEAD | `b8f9025d4ad3a80bba71d7b4049c28073a42cad4` (`PHASE 106M: migrate inventory product balance enumeration read`) |
| Initial worktree | Clean |
| Final HEAD | The single Phase 106N commit; its immutable SHA is reported in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 106N: prove runtime daily activity product read integration` |
| Commits after baseline | Exactly `1` required and verified after commit |
| Final worktree | Clean required and verified after commit |
| Final phase diff | `2 files changed, 1003 insertions(+), 0 deletions(-)` |
| Push / Tag | Not performed / not created |

## Why Phase 106L was blocked

Phase 106L could not prove the runtime report path because
`DriftInventoryRepository.allProductBalancesKg()` still enumerated products
through the legacy surface:

```text
LocalReportRepository.dailyActivityReport
→ DriftInventoryRepository.allProductBalancesKg
→ DriftProductRepository.listProducts
→ currentStockKg(product.id)
→ DriftProductRepository.listProducts
```

## How Phase 106M removed the blocker

Phase 106M migrated balance enumeration to the frozen product catalog read
contract:

```text
DriftInventoryRepository.allProductBalancesKg
→ ProductCatalogReadRepository.listProductCatalog(
    includeInactive: !activeProductsOnly,
  )
→ listMovementsByProduct(product.id)
→ fold over StockMovement.signedQuantityKg
```

## Executable path proven in Phase 106N

```text
LocalReportRepository.dailyActivityReport
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ DriftProductCatalogReadRepository
→ Drift select on the real products table
→ SQLite in-memory (NativeDatabase.memory)

LocalReportRepository.dailyActivityReport
→ DriftInventoryRepository.allProductBalancesKg
→ ProductCatalogReadRepository.listProductCatalog
→ DriftProductCatalogReadRepository
→ Drift listMovementsByProduct(product.id)
→ StockMovement.signedQuantityKg fold
→ SQLite in-memory
```

The report also reads purchases, sales, and expenses through the real
`DriftPurchaseRepository.listPurchaseIntakes()`,
`DriftSaleRepository.listSales()`, and
`DriftExpenseRepository.totalExpensesQirsh()` adapters. All three read
methods are pure SQLite reads; none touches the legacy product surface.

## Production composition used

### Manual fixture (runtime tripwire proof)

The test fixture composes the genuine Drift stack over one in-memory
`FoundationDatabase`:

```text
DriftProductCatalogReadRepository(database)
DriftInventoryRepository(
  database,
  productRepository: <throwing legacy sentinel>,
  productCatalogReadRepository: DriftProductCatalogReadRepository(database),
)
DriftPurchaseRepository(
  database,
  supplierRepository: DriftSupplierRepository(database),
  productRepository: <throwing legacy sentinel>,
  inventoryRepository: <DriftInventoryRepository>,
)
DriftSaleRepository(
  database,
  productRepository: <throwing legacy sentinel>,
  inventoryRepository: <DriftInventoryRepository>,
)
DriftExpenseRepository(database)
LocalReportRepository(
  purchaseRepository: <DriftPurchaseRepository>,
  saleRepository: <DriftSaleRepository>,
  inventoryRepository: <DriftInventoryRepository>,
  productCatalogReadRepository: <DriftProductCatalogReadRepository>,
  expenseRepository: <DriftExpenseRepository>,
)
```

The `<throwing legacy sentinel>` is a real `ProductRepository` implementation
whose `listProducts()` throws `StateError('Phase 106N legacy listProducts
sentinel')` and increments a counter. It is injected only at the
`productRepository` seams, exactly where production injects the legacy
repository. Customer and supplier account repositories are left at the
`LocalReportRepository` optional-null default because they are not part of the
product-read path; this limitation is documented below.

### Genuine production composition root

A separate test calls `AppRepositories.initializeProduction()` against an
in-memory database and runs the report through the lazily-initialized
`AppRepositories.reportRepository`, which composes every real Drift adapter
including customer and supplier account repositories.

## SQLite data used in the primary test

Target day: `2026-07-30` (selectedDate `2026-07-30 16:00`, start
`2026-07-30 00:00`, end `2026-07-31 00:00`).

Products (seeded into the real `products` table):

| id | name | active | reference cost | createdAt |
| --- | --- | --- | --- | --- |
| `prd-106n-active` | Active wheat | true | `12345` | 07-30 08:00 |
| `prd-106n-inactive` | Archived barley | false | `6789` | 07-30 09:00 |
| `prd-106n-no-movements` | No movements | true | `null` | 07-30 10:00 |
| `prd-106n-null-cost` | Uncosted corn | true | `null` | 07-30 10:00 |

Movements (seeded into the real `inventory_movements` table):

| id | product | type | kg | createdAt | voided |
| --- | --- | --- | --- | --- | --- |
| `mov-106n-active-prev` | active | openingBalance | +100 | 07-29 08:00 | no |
| `mov-106n-active-open` | active | openingBalance | +10 | 07-30 09:00 | no |
| `mov-106n-active-sale` | active | sale | -3 | 07-30 10:00 | no |
| `mov-106n-active-voided` | active | sale | -99 | 07-30 10:30 | yes |
| `mov-106n-inactive-inc` | inactive | manualIncrease | +4 | 07-30 11:00 | no |
| `mov-106n-inactive-dec` | inactive | manualDecrease | -1 | 07-30 11:30 | no |
| `mov-106n-null-open` | null-cost | openingBalance | +5 | 07-30 12:00 | no |
| `mov-106n-null-next` | null-cost | manualDecrease | -5 | 07-31 08:00 | no |

Sale (seeded into the real `sales` table): `sal-106n-active`, product
`prd-106n-active`, 2 kg at 20000 qirsh/kg, total 40000 qirsh, cash, created
07-30 10:15.

## Assertions proven

### 1-3. Report reads products from the real catalog adapter

The fixture asserts `fixture.catalog is DriftProductCatalogReadRepository` and
`fixture.inventory is DriftInventoryRepository`, and the report
`stockBalances` reflects rows physically stored in the `products` table. The
production-composition test asserts the same instance types on
`AppRepositories.productCatalogReadRepository` and
`AppRepositories.inventoryRepository`.

### 4. Inactive products are used via `includeInactive: true`

`prd-106n-inactive` (isActive `false`) appears in the report with its exact
balance and name, matching the Phase 106K frozen behavior.

### 5. `referenceCostPricePiastersPerKg` is preserved exactly

- `12345` arrives as the integer `12345`: `estimatedSalesCostQirsh` equals
  `2 * 12345 = 24690` exactly and `estimatedStockValueQirsh` equals
  `107 * 12345 + 3 * 6789 = 1341282` exactly. No rounding, no division, no
  unit conversion.
- `null` stays `null`: an uncosted product with a positive balance produces
  `estimatedStockValueQirsh == null`, `hasCompleteStockValuation == false`,
  and `missingStockCostProductNames == ['Uncosted corn']`. The value never
  becomes zero and never affects the integer-kilogram balance.

### 6. Balances are computed from real movements via `signedQuantityKg`

Expected balances: active `107` (100 + 10 - 3 + 0 voided), inactive `3`
(4 - 1), null-cost `0` (5 - 5, the second movement falls outside the target
day), no-movements `0`. Positive, negative, voided, before-day, and after-day
movements all fold exactly as the frozen production semantics define.

### 7. A product with no movements returns zero

`prd-106n-no-movements` appears in `stockBalances` with `quantityKg == 0`.

### 8. No direct or indirect call to `ProductRepository.listProducts()`

The throwing sentinel is injected at every `productRepository` seam. Every
scenario asserts `listProductCalls == 0` after the report. Any legacy read
would have thrown and failed the test.

### 9. No writes to the products table during the report

`_productSnapshot` (13 columns) taken before and after the report is
identical. Movement and sales snapshots are also unchanged.

### 10. Re-read reflects new SQLite rows without cache

After the first report (balance 8, name "Fresh grain"), a new sale movement
and a direct SQL rename of the product row are applied. The second report
returns balance 5, name "Renamed grain", and exact stock value `5 * 321 =
1605`.

### 11. Empty database does not crash

A fresh fixture reports `stockBalances` empty, zero totals, complete-cost and
complete-valuation flags true, and exact start/end boundaries.

### 12. Ordering matches the frozen contract

`stockBalances` follow `createdAt ASC, id ASC`: active (08:00), inactive
(09:00), then the two 10:00 products in id order (`prd-106n-no-movements`
before `prd-106n-null-cost`).

### 13. Breaking the legacy surface does not break the report

The report succeeds while the injected `listProducts()` throws on any attempt,
which is executable evidence the surface is no longer used.

## How absence of the legacy read is proven (layers)

1. Static guard test: scans `report_repository.dart`, `drift_inventory_repository.dart`,
   `drift_product_catalog_read_repository.dart`, and `app_repositories.dart`
   and asserts the daily-activity body, the `allProductBalancesKg` body, and
   the composition wiring never name the legacy surface and always use the
   catalog boundary.
2. Runtime tripwire: a throwing `ProductRepository` is injected at the
   `productRepository` seams; `listProductCalls == 0` is asserted after every
   report run.
3. Production sentinel: the genuine `AppRepositories` composition test stores a
   text value in the legacy-only `default_sale_price_piasters_per_kg` integer
   column. Any legacy full-row `listProducts()` read would raise a
   `FormatException`; the report succeeds, proving the runtime never takes the
   legacy read path.

## Nullable reference-cost result

`null` is preserved as `null` end-to-end. It is not converted to zero, not
rounded, and does not participate in arithmetic. Verified by the dedicated
"null reference cost stays null" test and by the primary test where the two
null-cost products with zero balance keep stock valuation complete.

## Inactive-product result

Inactive products remain visible in the report (frozen Phase 106K behavior).
The inactive product contributes its exact movement-derived balance and its
non-null reference cost to `estimatedStockValueQirsh`.

## Balance-from-movements result

`allProductBalancesKg` returns `{prd-106n-active: 107, prd-106n-inactive: 3,
prd-106n-no-movements: 0, prd-106n-null-cost: 0}` through the real
`DriftInventoryRepository`, and the report's `stockBalances` mirror it.

## Empty-database result

No crash; correct empty report with zero totals and complete flags.

## Re-read result

A later SQLite row is visible on the next uncached report call; no hidden
cache exists.

## Verification results

| Gate | Result |
| --- | --- |
| Phase 106N focused test | PASS — 6 passed, 0 failed, 0 skipped |
| Phase 106K related regression | PASS — 5 passed, 0 failed, 0 skipped |
| Phase 106M related regression | PASS — 6 passed, 0 failed, 0 skipped |
| Full `flutter test` | PASS — 2084 passed, 0 failed, 1 historical skip; 5 min 5 s wall time |
| Historical skip | Unchanged credential-dependent skip in `test/phase9a_inflows_outflows_reports_test.dart` |
| Formatter | PASS — 391 Dart files checked, 0 changed; 19.12 s |
| Analyzer | PASS — `No issues found`; 146.3 s analyzer time |
| Windows release | PASS — 58.5 s Flutter build time; only the existing non-fatal Firebase CMake deprecation and `.voltbl` linker warnings |
| EXE path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| EXE size | `784384` bytes |
| SHA-256 | `464C7F62CE62F4F8165F65B5B5DC46390A448A514A0DE4FB5010BCFDE19DE868` |
| Native smoke | NOT RUN — user database isolation is not proven |
| `git diff --check` | PASS — exit 0, no whitespace errors |

## Changed files

Tests:

- `test/phase106n_genuine_runtime_daily_activity_product_read_integration_test.dart` (new)

Documentation:

- `docs/PHASE-106N-PROVE-RUNTIME-DAILY-ACTIVITY-PRODUCT-READ-AFTER-INVENTORY-MIGRATION.md` (new)

Production code: none. No production file, schema, migration, adapter,
contract, controller, UI, report format, financial calculation, valuation
rule, or product ordering was modified.

## Diff statistics

`2 files changed, 1003 insertions(+), 0 deletions(-)`

## Scope exclusions and user-data safety

No consumer was migrated. No contract or read model was expanded. No schema or
migration was added. No UI, controller, report format, financial calculation,
or valuation rule changed. No caching or fallback was added. No test was
disabled, skipped, hidden, or weakened. The customer/supplier account
repositories are the `LocalReportRepository` optional-null default in the
manual fixture; the genuine `AppRepositories` composition test covers the full
production wiring including those repositories.

All runtime verification used SQLite in-memory databases. The production
application and release EXE were not launched. The user database was not
opened, read, copied, modified, deleted, moved, renamed, backed up, or
migrated.

## Confirmation

No Push was performed. No Tag was created. Exactly one commit exists after the
baseline, and the final worktree is clean.
