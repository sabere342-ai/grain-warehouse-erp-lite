# DC-U008 Durable Persistence Program — Complete Report

> **Document type:** Program Closure Report
> **Program:** DC-U008 Durable Persistence
> **Closure phase:** Phase 8N — Documentation-only closure
> **Date:** 2026-07-17
> **Baseline commit:** `4597bfb0a52618db7f80c2b25cc68959400d1689`
> **Baseline tag:** `dc-u008-durable-auth-repository-pass`
> **Closure branch:** `dc-u008-durable-persistence-complete`

---

## 1. Program Identity

| Property | Value |
|---|---|
| Program name | DC-U008 Durable Persistence |
| Original objective | Migrate all business-state repositories from in-memory storage to SQLite/Drift durable persistence with ACID transactions, foreign keys, and schema-versioned migrations |
| Governing ADR | Phase 7 — `docs/ADR-001-DURABLE-PERSISTENCE.md` |
| Implementation phases | Phase 8A through Phase 8M |
| Closure phase | Phase 8N — Documentation closure only |
| Final locked commit | `4597bfb0a52618db7f80c2b25cc68959400d1689` |
| Final locked tag | `dc-u008-durable-auth-repository-pass` |
| Branch at closure | `dc-u008-durable-persistence-complete` |

### Phase 7 ADR Summary

The Architecture Decision Record selected SQLite with Drift as the local durable persistence layer, rejecting alternatives including direct SQLite bindings, JSON files, Hive/Isar, and cloud services. The decision was driven by ACID transactions, enforced foreign keys, typed Dart access, schema-versioned migrations, and compatibility with the existing repository interface boundary.

---

## 2. Phase Inventory

### 2.1 Durable Persistence Phases (8A–8M)

| Phase | Scope | Schema Before | Schema After | Repository / Foundation | Locked Commit | Locked Tag | Status |
|-------|-------|-------------:|------------:|-------------------------|---------------|------------|--------|
| 7 (ADR) | Architecture decision | — | — | Documentation only | `a848792` | `dc-u008-durable-persistence-adr-pass` | COMPLETE |
| 8A | Durable persistence foundation | v1 | v1 | FoundationDatabase, lifecycle, migrations, generated code | `9bf4e67` | `dc-u008-durable-persistence-foundation-pass` | COMPLETE |
| 8B | Product repository | v1 | v2 | DriftProductRepository | `184c7fe` | `dc-u008-durable-product-repository-pass` | COMPLETE |
| 8C | Customer repository | v2 | v3 | DriftCustomerRepository | `573c448` | `dc-u008-durable-customer-repository-pass` | COMPLETE |
| 8D | Supplier repository | v3 | v4 | DriftSupplierRepository | `3063f6b` | `dc-u008-durable-supplier-repository-pass` | COMPLETE |
| 8E | Inventory repository | v4 | v5 | DriftInventoryRepository | `99ee81a` | `dc-u008-durable-inventory-repository-pass` | COMPLETE |
| 8F | Purchase repository | v5 | v6 | DriftPurchaseRepository | `c92076e` | `dc-u008-durable-purchase-repository-pass` | COMPLETE |
| 8G | Sale repository | v6 | v7 | DriftSaleRepository | `2025148` | `dc-u008-durable-sale-repository-pass` | COMPLETE |
| 8H | Financial account repository | v7 | v8 | DriftFinancialAccountRepository | `ed7c778` | `dc-u008-durable-financial-account-repository-pass` | COMPLETE |
| 8I | Audit log repository | v8 | v9 | DriftAuditLogRepository | `1bc6fab` | `dc-u008-durable-audit-log-repository-pass` | COMPLETE |
| 8J | Expense repository | v9 | v10 | DriftExpenseRepository | `f737484` | `dc-u008-durable-expense-repository-pass` | COMPLETE |
| 8K | Customer account repository | v10 | v11 | DriftCustomerAccountRepository | `efaecdd` | `dc-u008-durable-customer-account-repository-pass` | COMPLETE |
| 8L | Supplier account repository | v11 | v12 | DriftSupplierAccountRepository | `45d526d` | `dc-u008-durable-supplier-account-repository-pass` | COMPLETE |
| 8M | Auth repository | v12 | v13 | DriftAuthRepository | `4597bfb` | `dc-u008-durable-auth-repository-pass` | COMPLETE |
| 8N | Documentation closure | v13 | v13 | Documentation only | (this phase) | — | COMPLETE (local) |

### 2.2 Related Pre-Program Phases

| Phase | Scope | Commit | Tag | Status |
|-------|-------|--------|-----|--------|
| DC-U008 Core | Overpayments, advances, refunds | `59d689f` | `dc-u008-overpayments-advances-refunds-pass` | COMPLETE |
| DC-U008 UI (advance refunds) | Advance refund reversal UI | `1ef1e0b` | `dc-u008-advance-refund-reversals-ui-pass` | COMPLETE |
| DC-U008 UI (supplier advances) | Supplier advance actions UI | `5a4a815` | `dc-u008-supplier-advance-actions-ui-pass` | COMPLETE |
| DC-U008 UI (customer advances) | Customer advance actions UI | `caa05c2` | `dc-u008-customer-advance-actions-ui-pass` | COMPLETE |
| DC-U008 UI (supplier overpayment) | Supplier overpayment UI | `10ad6bb` | `dc-u008-supplier-overpayment-ui-pass` | COMPLETE |

---

## 3. Repository Inventory

### 3.1 All Production Repositories

| Repository / Store | Interface | Production Implementation | Storage | Classification | Backup | Restore | Owner Wipe | Transactional | Governance Rationale |
|--------------------|-----------|--------------------------|---------|----------------|--------|---------|------------|---------------|----------------------|
| AuditLogRepository | `AuditLogRepository` | `DriftAuditLogRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Core audit trail; foundational dependency |
| AuthRepository | `AuthRepository` | `DriftAuthRepository` | Drift/SQLite + in-memory session | `DRIFT_DURABLE` | No (intentionally excluded) | No | No (preserved across wipes) | Yes | Accounts durable; session intentionally ephemeral |
| ProductRepository | `ProductRepository` | `DriftProductRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Master data; foundational dependency |
| CustomerRepository | `CustomerRepository` | `DriftCustomerRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Master data; foundational dependency |
| SupplierRepository | `SupplierRepository` | `DriftSupplierRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Master data; foundational dependency |
| InventoryRepository | `InventoryRepository` | `DriftInventoryRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Transactional data; stock movements |
| ExpenseRepository | `ExpenseRepository` | `DriftExpenseRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Transactional data; expense records |
| FinancialAccountRepository | `FinancialAccountRepository` | `DriftFinancialAccountRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Core financial ledger |
| SaleRepository | `SaleRepository` | `DriftSaleRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Transactional data; sales records |
| PurchaseRepository | `PurchaseRepository` | `DriftPurchaseRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Transactional data; purchase records |
| CustomerAccountRepository | `CustomerAccountRepository` | `DriftCustomerAccountRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Transactional data; customer ledgers |
| SupplierAccountRepository | `SupplierAccountRepository` | `DriftSupplierAccountRepository` | Drift/SQLite | `DRIFT_DURABLE` | Yes | Yes | Yes | Yes | Transactional data; supplier ledgers |
| NegativeBalanceApprovalRepository | `NegativeBalanceApprovalRepository` | `LocalNegativeBalanceApprovalRepository` | In-memory | `KEEP_LOCAL_BY_DESIGN` | No | No | No | Yes | Ephemeral security tokens (24h expiry); financial effects recorded in Drift financial_account_entries |
| ReportRepository | `ReportRepository` | `LocalReportRepository` | No own storage | `STATELESS_COMPUTED_VIEW` | N/A | N/A | N/A | No | Read-only facade aggregating Drift-backed repositories |
| DocumentHistoryRepository | `DocumentHistoryRepository` | `LocalDocumentHistoryRepository` | No own storage | `STATELESS_COMPUTED_VIEW` | Partially (serialized in backup for validation) | No (derived from Drift sources) | N/A | No | Derived view of Drift purchases and sales |
| ThemeSettingsRepository | `ThemeSettingsRepository` | `LocalThemeSettingsRepository` | Filesystem (.txt) | `FILESYSTEM_DURABLE` | No | No | No | No | Single-string UI preference; simplest persistence |
| BusinessIdentityRepository | `BusinessIdentityRepository` | `LocalBusinessIdentityRepository` | Filesystem (.json + logo images) | `FILESYSTEM_DURABLE` | Yes | Yes | No (preserved across wipes) | No | Config + binary logo; simpler as filesystem |

### 3.2 Local (Test/Development) Implementations

The following `Local*Repository` classes exist as in-memory test/development scaffolds. They are replaced by Drift implementations in production via `AppRepositories.initializeProduction()`:

| Local Implementation | Replaced By | Used In Production |
|----------------------|-------------|-------------------|
| `LocalAuditLogRepository` | `DriftAuditLogRepository` | No |
| `LocalAuthRepository` | `DriftAuthRepository` | No |
| `LocalProductRepository` | `DriftProductRepository` | No |
| `LocalCustomerRepository` | `DriftCustomerRepository` | No |
| `LocalSupplierRepository` | `DriftSupplierRepository` | No |
| `LocalInventoryRepository` | `DriftInventoryRepository` | No |
| `LocalExpenseRepository` | `DriftExpenseRepository` | No |
| `LocalFinancialAccountRepository` | `DriftFinancialAccountRepository` | No |
| `LocalSaleRepository` | `DriftSaleRepository` | No |
| `LocalPurchaseRepository` | `DriftPurchaseRepository` | No |
| `LocalCustomerAccountRepository` | `DriftCustomerAccountRepository` | No |
| `LocalSupplierAccountRepository` | `DriftSupplierAccountRepository` | No |

---

## 4. Schema History

### 4.1 Version Transitions

| Transition | Version | Tables Added | Notes |
|-----------|--------:|-------------|-------|
| v1 (base) | 1 | FoundationProbes | Database lifecycle, migration infrastructure |
| v1 → v2 | 2 | Products, RepositorySequences | Product catalog + custom sequence allocation |
| v2 → v3 | 3 | Customers | Customer master data |
| v3 → v4 | 4 | Suppliers | Supplier master data |
| v4 → v5 | 5 | InventoryMovements | Stock movement records |
| v5 → v6 | 6 | Purchases | Purchase intake records |
| v6 → v7 | 7 | Sales | Sale records |
| v7 → v8 | 8 | FinancialAccounts, FinancialAccountEntries, FinancialTransfers, FinancialClosings | Complete financial ledger (4 tables) |
| v8 → v9 | 9 | AuditLogs | Audit trail |
| v9 → v10 | 10 | Expenses | Expense records |
| v10 → v11 | 11 | CustomerAccountEntries, CustomerCollections, CustomerAdvances, CustomerAdvanceApplications, CustomerAdvanceRefunds | Customer account ledgers (5 tables) |
| v11 → v12 | 12 | SupplierAccountEntries, SupplierPayments, SupplierAdvances, SupplierAdvanceApplications, SupplierAdvanceRefunds | Supplier account ledgers (5 tables) |
| v12 → v13 | 13 | AuthAccounts | Authentication accounts with Argon2id; seeds auth_accounts sequence namespace |

### 4.2 Migration Mechanism

- `onUpgrade` iterates from `from + 1` to `to`, executing each step in `_migrationSteps()`
- `beforeOpen` enables `PRAGMA foreign_keys = ON`
- Version 13 includes defensive `CREATE TABLE IF NOT EXISTS repository_sequences` and `INSERT ... ON CONFLICT DO NOTHING` for the `auth_accounts` namespace, handling legacy v7/v8 fixtures

---

## 5. Database Inventory

### 5.1 Verified Counts

| Item | Count |
|------|------:|
| Schema version | 13 |
| Drift tables | 25 |
| Indexes | 29 |
| Sequence namespaces | 20 |
| Migration steps | 12 (v2 through v13) |
| Drift-backed repositories | 12 |

### 5.2 All Drift Tables

| # | Table Class | SQLite Table |
|---|-------------|-------------|
| 1 | FoundationProbes | foundation_probes |
| 2 | Products | products |
| 3 | RepositorySequences | repository_sequences |
| 4 | Customers | customers |
| 5 | Suppliers | suppliers |
| 6 | InventoryMovements | inventory_movements |
| 7 | Purchases | purchases |
| 8 | Sales | sales |
| 9 | FinancialAccounts | financial_accounts |
| 10 | FinancialAccountEntries | financial_account_entries |
| 11 | FinancialTransfers | financial_transfers |
| 12 | FinancialClosings | financial_closings |
| 13 | AuditLogs | audit_logs |
| 14 | Expenses | expenses |
| 15 | CustomerAccountEntries | customer_account_entries |
| 16 | CustomerCollections | customer_collections |
| 17 | CustomerAdvances | customer_advances |
| 18 | CustomerAdvanceApplications | customer_advance_applications |
| 19 | CustomerAdvanceRefunds | customer_advance_refunds |
| 20 | SupplierAccountEntries | supplier_account_entries |
| 21 | SupplierPayments | supplier_payments |
| 22 | SupplierAdvances | supplier_advances |
| 23 | SupplierAdvanceApplications | supplier_advance_applications |
| 24 | SupplierAdvanceRefunds | supplier_advance_refunds |
| 25 | AuthAccounts | auth_accounts |

### 5.3 All Indexes

| # | Index Name | Table | Columns |
|---|-----------|-------|---------|
| 1 | inventory_movements_product_idx | InventoryMovements | product_id |
| 2 | inventory_movements_created_idx | InventoryMovements | created_at, id |
| 3 | inventory_movements_document_idx | InventoryMovements | original_document_id |
| 4 | purchases_supplier_idx | Purchases | supplier_id |
| 5 | purchases_created_idx | Purchases | created_at, id |
| 6 | purchases_product_idx | Purchases | product_id |
| 7 | purchases_request_idx | Purchases | operation_request_id |
| 8 | sales_customer_idx | Sales | customer_id |
| 9 | sales_created_idx | Sales | created_at, id |
| 10 | sales_request_idx | Sales | operation_request_id |
| 11 | sales_cancelled_idx | Sales | cancelled_at |
| 12 | financial_entries_account_date_idx | FinancialAccountEntries | account_id, effective_date, id |
| 13 | financial_transfers_request_idx | FinancialTransfers | client_request_id |
| 14 | audit_logs_timestamp_idx | AuditLogs | timestamp, id |
| 15 | audit_logs_action_idx | AuditLogs | action_type |
| 16 | audit_logs_reference_idx | AuditLogs | reference_id |
| 17 | expenses_date_created_at_idx | Expenses | date, created_at, id |
| 18 | customer_account_entries_customer_timestamp_idx | CustomerAccountEntries | customer_id, occurred_at, id |
| 19 | customer_collections_customer_timestamp_idx | CustomerCollections | customer_id, occurred_at, id |
| 20 | customer_advances_customer_timestamp_idx | CustomerAdvances | customer_id, occurred_at, id |
| 21 | customer_advance_applications_advance_idx | CustomerAdvanceApplications | advance_id |
| 22 | customer_advance_refunds_advance_idx | CustomerAdvanceRefunds | advance_id |
| 23 | supplier_account_entries_supplier_timestamp_idx | SupplierAccountEntries | supplier_id, occurred_at, id |
| 24 | supplier_payments_supplier_timestamp_idx | SupplierPayments | supplier_id, occurred_at, id |
| 25 | supplier_advances_supplier_timestamp_idx | SupplierAdvances | supplier_id, occurred_at, id |
| 26 | supplier_advance_applications_advance_idx | SupplierAdvanceApplications | advance_id |
| 27 | supplier_advance_refunds_advance_idx | SupplierAdvanceRefunds | advance_id |
| 28 | auth_accounts_role_active_idx | AuthAccounts | role, is_active |
| 29 | auth_accounts_created_idx | AuthAccounts | created_at, id |

### 5.4 All Sequence Namespaces

| # | Namespace | Drift Repository |
|---|-----------|-----------------|
| 1 | products | DriftProductRepository |
| 2 | customers | DriftCustomerRepository |
| 3 | suppliers | DriftSupplierRepository |
| 4 | inventory_movements | DriftInventoryRepository |
| 5 | purchases | DriftPurchaseRepository |
| 6 | expenses | DriftExpenseRepository |
| 7 | audit_logs | DriftAuditLogRepository |
| 8 | auth_accounts | DriftAuthRepository |
| 9 | customer_account_entries | DriftCustomerAccountRepository |
| 10 | customer_collections | DriftCustomerAccountRepository |
| 11 | customer_payment_cancellations | DriftCustomerAccountRepository |
| 12 | customer_advances | DriftCustomerAccountRepository |
| 13 | customer_advance_applications | DriftCustomerAccountRepository |
| 14 | customer_advance_refunds | DriftCustomerAccountRepository |
| 15 | supplier_account_entries | DriftSupplierAccountRepository |
| 16 | supplier_payments | DriftSupplierAccountRepository |
| 17 | supplier_payment_cancellations | DriftSupplierAccountRepository |
| 18 | supplier_advances | DriftSupplierAccountRepository |
| 19 | supplier_advance_applications | DriftSupplierAccountRepository |
| 20 | supplier_advance_refunds | DriftSupplierAccountRepository |

---

## 6. Backup, Restore and Owner-Wipe Matrix

### 6.1 Data Classification Matrix

| Data Category | Backup | Restore | Owner Wipe | Auth Exclusion | Notes |
|--------------|--------|---------|------------|---------------|-------|
| Products | Yes | Yes | Yes | — | Drift-backed |
| Customers | Yes | Yes | Yes | — | Drift-backed |
| Suppliers | Yes | Yes | Yes | — | Drift-backed |
| Inventory movements | Yes | Yes | Yes | — | Drift-backed |
| Purchases | Yes | Yes | Yes | — | Drift-backed |
| Sales | Yes | Yes | Yes | — | Drift-backed |
| Financial accounts & entries | Yes | Yes (transactional) | Yes | — | Drift-backed; v6 backup format |
| Audit logs | Yes | Yes | Yes | — | Drift-backed |
| Expenses | Yes | Yes | Yes | — | Drift-backed |
| Customer accounts & ledgers | Yes | Yes | Yes | — | Drift-backed |
| Supplier accounts & ledgers | Yes | Yes | Yes | — | Drift-backed |
| Auth accounts | **No** | **No** | **No** (preserved) | **Excluded** | Intentionally excluded from backup/restore/wipe |
| Auth session (`_currentUser`) | **No** | **No** | **No** | **Excluded** | Always in-memory; lost on restart |
| Negative balance approvals | **No** | **No** | **No** (not wiped, but naturally ephemeral) | — | Ephemeral tokens; 24h expiry; financial effects in Drift |
| Business identity | Yes | Yes | **No** (preserved) | — | Owner configuration, not business data |
| Theme settings | **No** | **No** | **No** | — | Local UI preference only |
| Document history | Serialized for validation | Not restored (derived) | N/A | — | View over Drift sources |
| Reports | N/A | N/A | N/A | — | Computed on demand |

### 6.2 Restore Ordering

Restore follows this sequence within a single database transaction:

1. Validate all backup data before any writes
2. Create empty database (fresh schema)
3. Restore master data: products, customers, suppliers
4. Restore transactional data: purchases, sales, inventory, expenses
5. Restore financial data: accounts, entries, transfers, closings
6. Restore customer/supplier account ledgers
7. Restore audit logs
8. Commit transaction or rollback on any failure

### 6.3 Filesystem Stores Behavior

- **BusinessIdentityRepository**: Fully covered by backup/restore (JSON + base64-encoded logos). Not wiped (preserved as owner config).
- **ThemeSettingsRepository**: Not backed up (local preference). Not wiped.

### 6.4 Rollback/Snapshot Behavior

The in-memory `RepositoryTransaction` system captures snapshots of Local* repositories before each transaction and rolls back on failure. In Drift-backed production, database-level ACID transactions provide the rollback guarantee, making the in-memory snapshot system redundant for production but still used for test isolation.

---

## 7. Security Boundaries

### 7.1 Authentication

- **Password hashing**: Argon2id with configurable parameters (memory cost, time cost, parallelism)
- **No plaintext credentials**: Passwords stored as salt + verifier + parameters in the `auth_accounts` Drift table
- **Session management**: `_currentUser` is an in-memory field; no persistent session, no token, no auto-login across restarts
- **Auth isolation from backup**: Auth accounts are intentionally excluded from backup/restore to prevent credential leakage

### 7.2 Ephemeral Authorization

- **NegativeBalanceApprovalRepository**: In-memory only; single-use, time-bound (24h default) authorization tokens
- **Financial effect preservation**: While approvals are ephemeral, their financial effects are recorded durably in `financial_account_entries` with the approval ID for audit trail continuity

### 7.3 Phase 8N Scope Boundary

Phase 8N introduces no new security persistence, no credential behavior changes, and no session persistence changes.

---

## 8. Completion Criteria Verification

### 8.1 Durable Production Repositories

**Achieved.** All 12 business-state repositories that store original data are backed by Drift/SQLite implementations, wired in production via `AppRepositories.initializeProduction()`.

### 8.2 Reopen Persistence

**Achieved.** On application restart, all Drift-backed repositories load their state from the SQLite database. Master data, transactional records, financial ledgers, and audit logs survive restarts.

### 8.3 Deterministic Ordering

**Achieved.** All repositories use monotonic integer IDs allocated via the `RepositorySequences` table with atomic `UPDATE ... RETURNING` operations, ensuring deterministic ordering independent of wall-clock time.

### 8.4 ID and Timestamp Preservation

**Achieved.** IDs are preserved across backup/restore. Timestamps (`created_at`, `occurred_at`, etc.) are preserved as-is. No time normalization is applied during restore.

### 8.5 Sequence Continuity

**Achieved.** Sequence namespaces are preserved across backup/restore via the `repository_sequences` table. Each restore seeds the sequences to the correct next value.

### 8.6 Backup/Restore

**Achieved.** The backup format (v6) includes all Drift-backed business data, business identity, and document history for validation. Restore operates within a single database transaction with full rollback on failure.

### 8.7 Owner Wipe

**Achieved.** Owner wipe clears all 12 Drift-backed business tables while preserving auth accounts and business identity. The wipe operates within a single database transaction.

### 8.8 Transactional Rollback

**Achieved.** All multi-repository business operations execute within a single Drift database transaction. On failure, the entire transaction rolls back with no partial state.

### 8.9 Migration Reproducibility

**Achieved.** The schema migration history (v1 through v13) is defined in `migration_strategy.dart` with 12 discrete steps. Each step is idempotent for additive operations and tested against upgrade paths.

### 8.10 Test and Analyzer Gates

**Achieved in prior phases.** Each phase (8A–8M) passed focused tests, full test suite, and flutter analyze before being locked with a tag.

### 8.11 Windows Release Verification

**Achieved in prior phases.** Windows release builds were verified at key milestones throughout the program.

---

## 9. Remaining Intentional Exclusions

### 9.1 NegativeBalanceApprovalRepository — KEEP_LOCAL_BY_DESIGN

**Classification:** Ephemeral session state
**Storage:** In-memory `List<NegativeBalanceApproval>`
**Reason for exclusion:** Negative balance approvals are owner-authorized, single-use, time-bound (24-hour default) security tokens. They exist only for the duration of a session or until consumed in a transaction. Persisting them to SQLite would add unnecessary complexity for data that is intentionally short-lived. The financial effect of each approval is recorded durably in `financial_account_entries.negativeBalanceApprovalId`.

### 9.2 ReportRepository — STATELESS_COMPUTED_VIEW

**Classification:** Read-only computation facade
**Storage:** No own storage
**Reason for exclusion:** This is a pure aggregation layer that queries Drift-backed repositories on demand. It holds no state and produces `DailyActivityReport` value objects by joining data from PurchaseRepository, SaleRepository, InventoryRepository, ProductRepository, ExpenseRepository, CustomerAccountRepository, and SupplierAccountRepository.

### 9.3 DocumentHistoryRepository — STATELESS_COMPUTED_VIEW

**Classification:** Read-only computation facade
**Storage:** No own storage
**Reason for exclusion:** Derived view over Drift-backed purchases and sales. Always reconstructible from source data. The backup system serializes its output for validation but does not restore it (the underlying Drift data is the source of truth).

### 9.4 ThemeSettingsRepository — FILESYSTEM_DURABLE

**Classification:** Filesystem-backed configuration
**Storage:** Plain text file (`%APPDATA%/GrainWarehouseErpLite/theme.txt`)
**Reason for exclusion:** Stores a single theme preset ID string. A plain text file is the simplest possible persistence mechanism. There is no relational data, no query need, and no complex structure. This is not included in backup/restore as it is a local UI preference.

### 9.5 BusinessIdentityRepository — FILESYSTEM_DURABLE

**Classification:** Filesystem-backed configuration
**Storage:** JSON file + logo image files in `%APPDATA%/GrainWarehouseErpLite/`
**Reason for exclusion:** Business identity is a small configuration record (1-2 fields + optional binary logo). The logo is binary data that does not belong in SQLite. A JSON file is simpler, requires no migration, and is trivially portable. This IS included in backup/restore and is preserved across owner wipes (it is owner configuration, not business transaction data).

### 9.6 Auth Session (_currentUser)

**Classification:** In-memory session state
**Storage:** `AppUser? _currentUser` field
**Reason for exclusion:** The active session is intentionally ephemeral. Requiring re-authentication on every launch is a security measure for a financial system. No session persistence, no token refresh, no auto-login.

---

## 10. Drift Persistence Patterns

The 12 Drift repositories use four distinct persistence strategies:

### 10.1 Direct Drift

Used by: Products, Customers, Suppliers, Audit Logs, Auth, Inventory, Expenses, Purchases

Each operation directly reads/writes via Drift's generated query API. No in-memory mirror.

### 10.2 Hybrid Extend-Local

Used by: FinancialAccountRepository

`DriftFinancialAccountRepository` extends `LocalFinancialAccountRepository`, keeping in-memory state in the superclass, but adds `_hydrate()` (load from Drift on startup) and `_persist()` (write-through on mutation) for durability.

### 10.3 Load-and-Restore Delegation

Used by: CustomerAccountRepository, SupplierAccountRepository

Each call loads the full state from Drift into a temporary `Local*Repository`, executes the domain logic, then persists the resulting state back. Drift is the sole source of truth; the local instance is transient per-operation.

### 10.4 Serialize-Delegate

Used by: SaleRepository

Keeps a `LocalSaleRepository` as the domain rule engine. Serializes its state to/from Drift between operations.

---

## 11. Final Conclusion

> اكتملت جميع عمليات الهجرة إلى SQLite/Drift التي يفرضها نطاق DC-U008. لا توجد repository business-state إضافية واجبة الهجرة وفق inventory الإنتاج الحالي. وتبقى بعض الحالات على filesystem أو في الذاكرة بموجب حدود تصميم وأمن موثقة.
>
> All migrations required by the DC-U008 scope have been completed. No additional business-state repositories require migration according to the current production inventory. Some stores remain on filesystem or in-memory by documented design and security boundaries.

---

*This report is the program closure documentation for DC-U008 Durable Persistence. No code, tests, schema, or generated files were modified in Phase 8N.*
