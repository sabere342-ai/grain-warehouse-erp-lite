# Phase 108C — Repository Boundary Audit

## Findings

Production composition already centralizes one `FoundationDatabase` and uses
business-shaped repository interfaces. This is a useful seam. However, many
presentation screens reach the global `AppRepositories` locator directly;
write contracts often represent local mutation rather than remote command
acceptance; several durable adapters hydrate an in-memory aggregate and rewrite
tables; and atomicity is not uniformly expressed at an application command
boundary.

Direct Drift/SQLite imports are confined to the persistence layer, the
composition root, and these adapters: auth, product/catalog read, customer,
supplier, inventory, valuation, sale, purchase, expense, audit, customer
accounts, supplier accounts, financial accounts and approval requests. UI does
not import Drift directly, but it is coupled to globally selected local
repositories and sometimes orchestrates multi-repository writes.

## Inventory

| Consumer | Current dependency | Desired future abstraction | Difficulty | Priority |
| --- | --- | --- | --- | --- |
| `AppRepositories` | Concrete database and every Drift adapter | Injectable composition root with local/remote adapters and use cases | High | P0 |
| `SaleController` | Four repository contracts; orchestrates posting and payment entries | `PostSaleCommand` / `CancelSaleCommand` returning authoritative result | High | P0 |
| `DriftSaleRepository` | SQLite plus local domain delegate | Local sale projection/outbox adapter; server command adapter separate | High | P0 |
| `DriftPurchaseRepository` | SQLite and six domain repositories | `PostPurchaseCommand` / reversal server boundary | High | P0 |
| Expense repository/workflow | SQLite + financial/audit repositories | `PostExpenseCommand` and result projection | High | P0 |
| Customer/supplier account adapters | Raw SQL payload tables + hydrated local aggregates | Command/query contracts for collections/payments/advances | High | P0 |
| Financial account adapter | Hydrated aggregate; full-table persistence transaction | Query projection plus atomic server commands | Critical | P0 |
| Inventory controller/repository | Repository snapshots and local balance validation | Stock command use cases + acknowledged/provisional queries | Critical | P0 |
| Negative-balance approval workflow | SQLite request repo plus multiple execution repositories | Trusted online approval/consume server command | Critical | P0 |
| Backup restore/wipe | Repository orchestration across whole database | Explicit export/import/cache-reset/business-lifecycle services | High | P0 before migration |
| Auth repository/controller | Local credentials and memory session | Auth/session port + membership/device authorization | High | P0 |
| Product catalog read adapter | Narrow `ProductCatalogReadRepository` | Remote read + local cached implementation | Low/ready | P1 first vertical slice |
| Product write controller | `ProductRepository` | Versioned product commands | Medium | P1 |
| Reports/dashboard/document history | Read repositories and global locator | Query services over acknowledged projection with stale/pending metadata | Medium | P1/P2 |
| Screens using `AppRepositories.*` | Global service locator | Constructor/provider-injected use cases/view models | Medium/high breadth | P1 incremental |
| Business identity repository | Direct JSON/logo filesystem | Versioned business-settings/object-storage repository + cache | Medium | P2 |
| Theme/trial stores | Direct local files | Keep device-local ports; licensing port later | Low | P2 |
| PDF/export/file services | Local paths and business identity | Document DTO + platform file/share capability | Medium | Later |

## Product read migration status

Production product reads have a genuine `ProductCatalogReadRepository` and
Drift adapter. No production consumer outside the catalog adapter directly
selects `database.products`. The remaining `ProductRepository` references are:

- composition fallback adapter;
- product write/controller contract;
- legacy local inventory and purchase implementations used by tests/fallbacks.

Classification:

| Remaining area | Classification | Reason |
| --- | --- | --- |
| Production product read consumers | Not a blocker | All use `ProductCatalogReadRepository` |
| Local fallback inventory/purchase constructors accepting `ProductRepository` | SAFE TO MIGRATE DURING CLOUD | Non-production/fallback architecture; replace with owning adapter slice |
| Product write contract/controller | SHOULD MIGRATE BEFORE CLOUD WRITES | Needs version/idempotency/result semantics, but does not block read-only slice |
| Phase 106 source-freeze tests | NON-PRODUCTION / LOW PRIORITY | Historical guards; preserve until owning phase deliberately updates them |

## Boundary conclusion

The first work before Supabase business implementation is an application
command/query and composition-root freeze. Do not mass-rewrite all screens and
do not add a generic sync repository to conceal unresolved transaction groups.
