# Phase 106V — Prove Genuine Runtime `SaleController.load` Product Catalog Read Integration

## Outcome

**Outcome A — FULL SUCCESS**

Phase 106V proves that the production `SaleController.load` path runs end-to-end
through genuine runtime SQLite (Drift in-memory), the real
`DriftProductCatalogReadRepository` adapter, and the Phase 106U migrated
`ProductCatalogReadRepository.listProductCatalog(includeInactive: false)`
boundary — wired through the genuine `AppRepositories` production composition
exactly as the production sales screen (`SalesScreen`) constructs it. `load`
executes with no call — direct or indirect — to the legacy
`ProductRepository.listProducts()` surface. The two expanded sale price fields
(`defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`) travel from
the SQLite `products` table, through Drift, and into the controller unchanged.
No production file was changed.

## Baseline and branch

| Item | Value |
| --- | --- |
| Branch | `codex/phase-106v-prove-runtime-sale-controller-product-catalog-integration` |
| Starting HEAD | `0ff8370b5cbc344973cdd968985a30c549f934d1` (`PHASE 106U: expand product catalog read and migrate sale controller`) |
| Initial worktree | Clean |
| Commits after baseline | Exactly `1` required and verified after commit |
| Push / Tag | Not performed / not created |

## Frozen goal

Prove the genuine runtime `SaleController` product catalog read integration —
`SalesScreen` wiring → `SaleController.load` →
`ProductCatalogReadRepository.listProductCatalog(includeInactive: false)` →
`AppRepositories.productCatalogReadRepository` →
`DriftProductCatalogReadRepository` → Drift → real SQLite in-memory `products`
table — with zero `lib/` changes, a new runtime integration test plus guards,
and a single commit after baseline `0ff8370`.

## Scope

Strictly bounded:

- **No `lib/` production changes at all** — the production diff against baseline
  is empty (verified, see "No-production-diff proof").
- No new consumer migration; no contract or read-model expansion; no model or
  field changes; no schema, migration, or backup changes; no UI changes.
- No `SaleController` or `SalesScreen` changes.
- Proof uses real SQLite in-memory, the real `FoundationDatabase`
  (`openInMemoryTestDatabase`), the real `DriftProductCatalogReadRepository`,
  the real production composition root (`AppRepositories.initializeProduction`),
  and the real `SaleController` — no mocks, fakes, stubs, or hard-coded catalog
  lists; no manual `ProductCatalogReadModel` injection; no legacy
  `ProductRepository.listProducts`.
- Historical freeze guards were updated only for technical necessity from the
  new test (lineage recognition); no old test was weakened.

## Files changed

Tests:

- `test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart` (new — 18 tests)

Documentation:

- `docs/PHASE-106V-PROVE-RUNTIME-SALE-CONTROLLER-PRODUCT-CATALOG-INTEGRATION.md` (new)

Production code: none. No production file, schema, migration, adapter,
contract, controller, UI, report format, financial calculation, or ordering
was modified. `git diff --stat 0ff8370` shows exactly `1 file changed,
876 insertions(+)` (the new test file only).

## No-production-diff proof

Verified with the mandated commands against baseline `0ff8370`:

- `git diff 0ff8370 -- lib` → **empty** (no output).
- `git diff --name-only 0ff8370` → only `test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart`.
- `git diff --stat 0ff8370` → `1 file changed, 876 insertions(+)`.

The freeze test `no production code changed and no consumer migrated in Phase
106V` re-asserts the same facts at runtime: the `git diff --name-only 0ff8370
HEAD -- lib` set is empty, the working-tree `git diff --name-only -- lib` set is
empty, and the production `.listProductCatalog(` callers set is exactly the nine
frozen files.

## Real runtime path proven

```text
SalesScreen wiring
→ SaleController(
    saleRepository,
    productCatalogReadRepository,
    inventoryRepository,
    customerRepository,
    customerAccountRepository,
    financialAccountRepository)
→ SaleController.load(AppUser user)
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: false)
→ AppRepositories.productCatalogReadRepository
→ DriftProductCatalogReadRepository
→ Drift select on the real products table
→ SQLite in-memory (NativeDatabase.memory)
```

## In-memory SQLite creation

Both runtime groups create the genuine in-memory database through the
production opener `openInMemoryTestDatabase()` from
`lib/core/persistence/database_opener.dart`, producing a real
`FoundationDatabase` over `NativeDatabase.memory`. No file-based or production
user database is opened anywhere in the proof.

## Data seeding

Scenario rows are written directly into the real SQLite tables through Drift
inserts:

- `_seedProduct` inserts into the `products` table with id, name,
  `normalizedName`, code, `normalizedCode`, unit (`GrainUnit` wire name), isActive,
  reference cost, and `defaultSalePricePiastersPerKg` /
  `minimumSalePricePiastersPerKg` (nullable price columns via `Value(...)`).
  Each seed takes an `order` index that maps to `createdAt =
  DateTime.utc(2026, 7, 30, 8, order)` so insert order can differ from the
  frozen read order.
- `_seedMovement` inserts into `inventory_movements` (id, productId,
  movementType, quantityKg, createdByUserId, createdAt) for the
  no-writes scenario.
- Distinctive values are used so accidental mapping loss is visible: names
  like `Genuine Runner P-1`, codes like `GEN-RUN-01`, units `kilogram` and
  `sack`, prices `12345`/`9876` (plus `4567`/`3456` in the tripwire fixture).

## Real Drift adapter proof

`AppRepositories.productCatalogReadRepository` is asserted to be a genuine
`DriftProductCatalogReadRepository` (not the legacy adapter and not a fake), and
the adapter's `listProductCatalog` executes a real Drift select against the real
`products` table. The architecture guard `Drift adapter reads both fields
directly from the database columns with no currency conversion` compacts the
adapter source and asserts both `defaultSalePricePiastersPerKg:` and
`minimumSalePricePiastersPerKg:` appear in a row mapping, with no `/ 100`,
`* 100`, `round(`, `floor(`, or `ceil(` anywhere near them.

## Composition root

The primary group calls `AppRepositories.initializeProduction(databaseFactory:
...)` against the in-memory database and builds `SaleController` with the exact
`AppRepositories.*` arguments `SalesScreen` uses. It asserts:

- `AppRepositories.database` is the injected in-memory database.
- `AppRepositories.productCatalogReadRepository` is a real
  `DriftProductCatalogReadRepository`.
- `AppRepositories.inventoryRepository` is a real `DriftInventoryRepository`.

The architecture guard `composition root wires the genuine Drift catalog
repository` compacts `lib/app/app_repositories.dart`, asserts the production
assignment `_productCatalogReadRepository=DriftProductCatalogReadRepository(`
exists, and — scoped to the `initializeProduction` method body — asserts the
body wires `DriftProductCatalogReadRepository(` and never wires
`_LegacyProductCatalogReadRepository(`. The legacy adapter class and its
pre-initialization static default value remain (unreachable once
`initializeProduction` runs) and are not part of the production init wiring.

A second runtime group composes the genuine Drift stack manually with a
**throwing legacy sentinel** at the `productRepository` seam — exactly where
production injects `DriftProductRepository`:

```text
DriftProductCatalogReadRepository(database)
DriftInventoryValuationRepository(database)
DriftInventoryRepository(
  database,
  productRepository: <throwing legacy sentinel>,
  productCatalogReadRepository: DriftProductCatalogReadRepository(database),
)
DriftSaleRepository(
  database,
  productRepository: <throwing legacy sentinel>,
  inventoryRepository: <DriftInventoryRepository>,
  inventoryValuationRepository: <DriftInventoryValuationRepository>,
)
SaleController(<all real repositories>)
```

The `<throwing legacy sentinel>` (`_ThrowingProductRepository implements
ProductRepository`) throws `StateError` on `listProducts()` and counts each
call. It is a test double only for the side component not under proof; every
repository under proof — the catalog contract, `DriftProductCatalogReadRepository`,
`DriftInventoryRepository`, `DriftSaleRepository`, and SQLite — is real. The
scenario asserts `legacy.listProductCalls == 0` after a successful `load`.

## `includeInactive`

`SaleController.load` always reads through `listProductCatalog(includeInactive:
false)`. The runtime proof seeds both an active and an inactive product and
asserts the controller's `products` list contains the active product only — the
inactive product never appears. The architecture guard asserts the compacted
`load` body names `_productCatalogReadRepository.listProductCatalog(` with
`includeInactive:false` exactly.

## Default sale price

A product seeded with `defaultSalePricePiastersPerKg = 12345` reaches
`SaleController.products` with `defaultSalePricePiastersPerKg == 12345` —
unchanged, not `123`, not `123.45`, not `1234500`, not rounded. The value is
distinctive enough that any scale/unit conversion would fail the test.

## Minimum sale price

A product seeded with `minimumSalePricePiastersPerKg = 9876` reaches
`SaleController.products` with `minimumSalePricePiastersPerKg == 9876` —
unchanged.

## Null preservation

Products seeded with `null` for both price columns reach the controller with
`defaultSalePricePiastersPerKg == null` and `minimumSalePricePiastersPerKg ==
null` — they are never coerced to `0`. The architecture guard asserts the
`ProductCatalogReadModel` fields remain `int?` (nullable).

## Ordering

Products are seeded in an insert order different from the frozen read order
(earlier `createdAt` values inserted after later ones), and the controller
returns them in `createdAt ASC, then id ASC` — the same ordering the real
`DriftProductCatalogReadRepository` and Drift apply to the real `products`
table. The architecture guard asserts the `ProductCatalogReadModel` contract is
exactly the eight frozen fields.

## No `ProductRepository.listProducts`

Proven three ways:

1. **Tripwire** — with a throwing legacy `ProductRepository` injected at the
   `productRepository` seam, `load` succeeds and `listProductCalls == 0`.
2. **Controller guard** — the compacted `load` body calls
   `_productCatalogReadRepository.listProductCatalog(`, contains no
   `listProducts(`, no `productRepository`, no `ProductRepository`, and no
   write call, `.transaction(`, `try{`, or `catch(`.
3. **Sales screen guard** — the compacted `sales_screen.dart` wires
   `productCatalogReadRepository: AppRepositories.productCatalogReadRepository`
   and passes no `productRepository:` argument to `SaleController`.

## New / updated tests

- `test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart` (new — 18 tests):

  - Group 1 — genuine AppRepositories production composition on SQLite:
    - composition identity resolves to the Drift adapter and load reads genuine
      SQLite rows with distinctive values
    - includeInactive is false and the read repository excludes inactive products
    - default sale price is transferred in piasters unchanged
    - minimum sale price is transferred in piasters unchanged
    - null sale prices survive SQLite, Drift, and the controller
    - products preserve createdAt ASC then id ASC ordering
    - empty products table loads without crash and stays empty
    - re-read reflects later SQLite rows without any hidden cache
    - load performs no writes to product, sale, movement, customer, or financial
      tables
  - Group 2 — legacy-read tripwire in the genuine load path:
    - load succeeds with a throwing legacy ProductRepository and never calls
      listProducts
  - Group 3 — architecture guards:
    - SaleController.load never calls the legacy product read
    - sales screen wires the genuine catalog repository with no legacy catalog load
    - ProductCatalogReadModel retains the two expanded sale price fields
    - Drift adapter reads both fields directly from the database columns with no
      currency conversion
    - composition root wires the genuine Drift catalog repository
    - no production code changed and no consumer migrated in Phase 106V
    - schemaVersion stays 15 and persistence is untouched
    - lineage: Phase 106V starts from the single Phase 106U commit

No prior freeze guard was weakened. The 106V lineage guard follows the exact
pattern of Phases 106S/106T/106U: it accepts HEAD == `0ff8370` (the baseline
itself) or exactly one 106V commit whose parent is `0ff8370` with subject
`PHASE 106V: prove runtime sale controller product catalog integration`, and
asserts the 106O/Q/T/U historical lineage tests are untouched.

## Targeted results

| Suite | Result |
| --- | --- |
| `test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart` | PASS — 18 passed, 0 failed, 0 skipped |
| Phase 106O freeze guard | PASS |
| Phase 106Q freeze guard | PASS |
| Phase 106R migration guard | PASS |
| Phase 106S runtime integration | PASS |
| Phase 106T freeze guard | PASS |
| Phase 106U migration + freeze + contract-expansion | PASS |
| Targeted 106O/Q/R/S/T/U combined | PASS — 93 passed, 0 failed |

## Full suite numbers

`flutter test` → PASS — **2205 passed, 1 historical skip, 0 failed**.

The single skip is the unchanged credential-dependent skip in
`test/phase9a_inflows_outflows_reports_test.dart` (established in earlier
phases); no test was disabled, skipped, hidden, or weakened.

## Analyze

`flutter analyze` → PASS — `No issues found!`

## Format

`dart format --output=none --set-exit-if-changed .` → PASS — `401 files checked,
0 changed` (the new test file was formatted during the gate, then the gate
re-passed).

## Diff check

`git diff --check` → PASS — exit 0, no whitespace errors (including the new
untracked file staged as intent-to-add during the check).

## Windows build

`flutter build windows --release` → PASS — built in `31.5s` with only the
existing non-fatal Firebase CMake deprecation warning and the existing MSVCRT
`.voltbl` linker warning.

## EXE size and SHA-256

| Item | Value |
| --- | --- |
| Path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| Size | `784384` bytes |
| SHA-256 | `E73EF760153E3C324FF270F3AA56BEA2A8FB1672D711A6D44130E83E3F5912E7` |

## Reconciliation

Frozen reconciliation is unchanged by Phase 106V: **24 total / 9 migrated / 15
remaining** (the 106U freeze guard asserts `24 = 9 + 15`). Phase 106V migrates
no new consumer; it only proves the Phase 106U `SaleController.load` migration
at runtime.

## No-new-consumer confirmation

The production `.listProductCatalog(` caller set is exactly the nine frozen
files (`sale_controller.dart` plus the eight established earlier callers); no
consumer was added or migrated in Phase 106V. `SalesScreen` wiring is unchanged
and already passes the genuine catalog repository.

## No push / no tag

No Push was performed. No Tag was created. No rebase, amend, or rewrite of
shared history occurred.

## Final tree state

Clean required and verified after commit: `git status --short` is empty;
`git rev-list --count 0ff8370..HEAD` equals `1`; `git diff HEAD^ HEAD -- lib`
is empty.

## Final commit

`PHASE 106V: prove runtime sale controller product catalog integration`
(the commit's immutable SHA is reported in the phase handoff because a commit
cannot contain its own hash).
