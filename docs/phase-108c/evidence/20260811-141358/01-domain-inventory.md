# Phase 108C — Data Domain Inventory

Evidence basis: `FoundationDatabase` schema version 15, production composition
in `AppRepositories`, repository contracts/adapters, backup v8, local settings,
business identity, authentication, and trial sources at baseline `5aeb41b`.

| Domain | Current storage | Writes from | Reads from | Transaction critical? | Cloud candidate? | Frozen authority candidate |
| --- | --- | --- | --- | --- | --- | --- |
| Application users / roles | SQLite `auth_accounts`; active session in memory | owner setup/auth repository | auth controller, permission gates, approval flows | Yes | Yes | Cloud authority + local cached identity/session |
| Authentication credentials | Argon2id material in local SQLite; no durable cloud session | local auth repository | sign-in and credential re-check | Yes/security | Yes | Supabase Auth; do not replicate password verifiers |
| Business memberships | Not represented separately | none | none | Yes/security | Required | Cloud authority |
| Device identity | Not represented | none | none | Yes/sync | Required | Cloud authority; secure device-local credential |
| Products / catalog | SQLite `products` | product repository/controller | `ProductCatalogReadRepository` consumers | Master-data critical | Yes | Cloud authority + local cache |
| Inventory movement ledger | SQLite `inventory_movements` | purchase, sale, cancellation, opening/stock adjustment | inventory, reports, documents | Yes | Yes | Cloud authority + local projection |
| Inventory balances | Derived from signed movements | no direct writer | inventory/report/dashboard | Yes | Yes | Derived from accepted cloud ledger; cached locally |
| Inventory valuation state | SQLite `inventory_valuation_states` | valuation repository | profitability/reporting | Yes | Yes | Cloud-authoritative projection |
| Inventory valuation events / COGS | SQLite `inventory_valuation_events`; COGS snapshots also in sale line JSON | purchase/sale/adjustment/reversal | profitability and sale records | Yes | Yes | Cloud authority, append/reversal |
| Purchases | SQLite `purchases`; current schema models one product per intake | purchase repository/controller | purchase UI, reports, document history | Yes | Yes | Cloud authority + local cache |
| Purchase lines | Embedded in current purchase record (no separate table) | purchase posting | documents/reports | Yes | Yes | Cloud authority; exact future shape deferred |
| Sales | SQLite `sales` | sale repository/controller | sales, reports, documents | Yes | Yes | Cloud authority + local cache |
| Sale lines | JSON `sales.items_json` plus legacy top-level product fields | sale posting | invoices, reports, valuation | Yes | Yes | Cloud authority; normalized/JSON schema choice deferred |
| Returns | No generic return table; cancellation/reversal and advance refund records only | governed reversal flows | statements/history | Yes | Yes | Cloud authority, compensating records only |
| Customers | SQLite `customers` | customer repository/controller | sales, customer accounts/reports | Master-data critical | Yes | Cloud authority + local cache |
| Customer ledger | SQLite `customer_account_entries` | sale, collection, advance/opening/reversal workflows | balances/statements/reports | Yes | Yes | Cloud authority, append/reversal |
| Customer collections | SQLite `customer_collections` | collection workflow | statements/reports | Yes | Yes | Cloud authority, immutable after acceptance |
| Customer advances/applications/refunds | Four SQLite tables | customer advance workflows | balance/reports | Yes | Yes | Cloud authority, append/reversal |
| Suppliers | SQLite `suppliers` | supplier repository/controller | purchases, supplier accounts/reports | Master-data critical | Yes | Cloud authority + local cache |
| Supplier ledger | SQLite `supplier_account_entries` | purchase/payment/advance/opening/reversal workflows | balances/statements/reports | Yes | Yes | Cloud authority, append/reversal |
| Supplier payments | SQLite `supplier_payments` | payment workflow | statements/reports | Yes | Yes | Cloud authority, immutable after acceptance |
| Supplier advances/applications/refunds | Four SQLite tables | supplier advance workflows | balance/reports | Yes | Yes | Cloud authority, append/reversal |
| Expenses | SQLite `expenses` | expense repository/controller/workflow | expenses and financial reports | Yes | Yes | Cloud authority, append/correction |
| Financial accounts | SQLite `financial_accounts`; hydrated in-memory aggregate | financial repository | postings/statements/reports | Yes | Yes | Cloud authority + local cache |
| Financial account entries / journal | SQLite `financial_account_entries`; hydrated in-memory aggregate | sales, purchases, expenses, payments, transfers, corrections | balances/statements/reports | Yes | Yes | Cloud authority, append/reversal |
| Transfers | SQLite `financial_transfers` plus two linked entries | financial account repository/controller | transfer/financial reports | Yes | Yes | Cloud authority, atomic command |
| Closings/reopenings | SQLite `financial_closings` | owner closing workflow | closing/report validation | Yes | Yes | Cloud authority |
| Negative-balance approvals | Requests/transitions in SQLite; legacy consumed approvals in memory | approval workflow/owner | critical posting workflows | Yes/security | Yes | Cloud authority; server-only consume |
| Opening balances | Financial account field plus customer/supplier entries and inventory movements | owner workflows | ledgers/reports | Yes | Yes | Cloud authority, one-time idempotent commands |
| Stock adjustments / stock take | Inventory movements and valuation events | owner inventory controller | inventory/reporting | Yes | Yes | Cloud authority; offline request may remain provisional |
| Audit logs | SQLite `audit_logs` | repositories/services | audit UI/export | Yes | Yes | Cloud authority, append-only |
| Document history | Derived from sales, purchases, products, movements | no independent writer | history UI/backup | No independent truth | Projection | Derived/recomputable |
| Reports/dashboard/KPIs | Calculated from repositories | no writer | UI/PDF/CSV/AI read tools | No | Projection | Derived/recomputable; accepted and pending views separated |
| Business/shop identity | Local JSON plus managed logo files | settings/business identity repository | app shell, invoices, PDF | Organization master data | Yes | Cloud authority + local cache; logo in private object storage |
| Theme/UI preferences | Local `theme.txt` JSON | theme settings repository | app theme | No | Optional | Device-local only initially |
| Other settings | Distributed/local UI and files; no versioned unified settings store | owning settings UI/services | UI/runtime | Varies | Later | Classify by device/user/business before implementation |
| Backup payload / metadata | UTF-8 JSON v8 file with Adler-32 checksum | backup export/file writer | preview/restore/import | Yes/recovery | Export/import | Export artifact, not live authority |
| Business-data wipe | Service operation, not stored domain | owner-only wipe service | settings/admin UI | Destructive | Must split | Local cache reset vs cloud business deletion are different commands |
| Trial state | Device-local application-support files | trial service | root app gate | Commercial/security | Transitional | Device-local during transition; future cloud licensing authority |
| Repository sequences | SQLite `repository_sequences` | Drift adapters | ID/document generators | Yes under concurrency | No as shared truth | Replace shared IDs with global client IDs and server numbering |
| Foundation probes | SQLite technical table | tests/technical lifecycle | tests | No | No | Device-local/technical only |

## Current storage summary

- Business data is durable in one local Drift/SQLite database, schema version
  15, with WAL and foreign keys enabled.
- Business identity and logo files are outside SQLite.
- Theme and trial state are separate device files.
- Documents and balances are mostly projections over accepted local records;
  they must not become independently synchronized truth.
- No organization, membership, device, outbox, inbox, remote version, sync
  cursor, server timestamp, or tenant ownership field exists today.
