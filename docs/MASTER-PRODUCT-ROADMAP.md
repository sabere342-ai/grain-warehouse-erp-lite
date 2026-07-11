# Master Product Roadmap — Grain Warehouse ERP Lite

## خارطة طريق المنتج الرئيسية — نظام مخزن الحبوب ERP Lite

> **Last Updated / آخر تحديث:** DC-U007 — Negative-Balance Controls (Post-Phase 81)
> **HEAD / الرأس الحالي:** DC-U007 implementation
> **Tests / الاختبارات:** 814/814 passing
> **Flutter Analyze:** No issues
> **Windows Release Build:** Passing

---

## Table of Contents / فهرس المحتويات

1. [Project Overview](#project-overview)
2. [Technical Architecture](#technical-architecture)
3. [Current Status (Phase 76)](#current-status)
4. [What IS Implemented](#implemented)
5. [What is Partially Implemented](#partially-implemented)
6. [What is NOT Implemented](#not-implemented)
7. [Deferred by Dependency](#deferred-by-dependency)
8. [Phase History](#phase-history)
9. [Critical Rules](#critical-rules)
10. [Roadmap Phases (Future)](#future-roadmap)

---

## Project Overview

**Grain Warehouse ERP Lite** is a single-user Windows desktop application built with Flutter, designed for a single grain warehouse owner. The system manages the complete grain trading lifecycle: product catalog, supplier purchasing, customer sales, inventory tracking, financial collections and payments, expense management, stock taking, document history, PDF invoicing, and business reporting — all in Arabic RTL.

**المستخدم المستهدف:** صاحب مخزن حبوب واحد
**المنصة:** Windows Desktop (Flutter)
**اللغة:** العربية (RTL)
**العملة:** قرش (أرقام صحيحة فقط — لا كسور عشرية)
**الوحدة:** جرام

---

## Technical Architecture

| Component | Technology |
|-----------|------------|
| Framework | Flutter (Windows Desktop) |
| Language | Dart |
| UI | Arabic RTL, Amiri font |
| Money type | `int` (Qirsh — no decimals) |
| Weight type | `int` (grams) |
| Persistence | In-memory repositories (`Local*Repository`) |
| Backup/Restore | JSON export/import (Version 6 with transaction financial linkage; backward-compatible with v1–v5) |
| PDF generation | Flutter PDF rendering |
| Database | **None** — no SQLite, no cloud, no server |
| Networking | None (offline-only) |
| Auth | Local role-based (owner/employee) |

---

## Current Status

**Phase:** Post-Phase 81 — DC-U007 Negative-Balance Controls
**HEAD:** DC-U007 implementation commit
**Test Suite:** 814/814 tests passing
**Static Analysis:** Flutter analyze — no issues
**Build:** Windows release build — passing

The application is in a **production-ready local state** for a single warehouse owner pilot. All core business features are complete, tested, and branded. The system is operating in controlled owner trial.

---

## Implemented

The following features are fully implemented, tested, and passing all 814 tests:

### Product Management / إدارة المنتجات
- [x] Add/edit/list products
- [x] Grain units: kg and ton
- [x] Product catalog with full CRUD

### Customer Management / إدارة العملاء
- [x] Add/edit/list customers
- [x] Active/inactive status
- [x] Customer account ledger (credit sale, cash sale, collection, opening balance, sale cancellation entries)
- [x] Opening balances for customers

### Supplier Management / إدارة الموردين
- [x] Add/edit/list suppliers
- [x] Active/inactive status
- [x] Supplier account ledger (purchase, payment, opening balance, purchase cancellation entries)
- [x] Opening balances for suppliers

### Sales / المبيعات
- [x] Cash sales
- [x] Credit sales
- [x] Partial payment sales
- [x] Multi-item sales
- [x] Customer-bound sales
- [x] Sale cancellation with stock reversal
- [x] Sale cancellation with customer account reversal (Phase 59)
- [x] Financial account association (Phase 72)
- [x] Payment method tracking (Phase 72)

### Purchases / المشتريات
- [x] Supplier-bound purchases
- [x] Purchase cancellation with stock reversal
- [x] Purchase cancellation with supplier account reversal
- [x] Financial account association (Phase 72)
- [x] Payment method tracking (Phase 72)

### Collections / التحصيل
- [x] Record customer collection
- [x] Reduce outstanding balance on collection
- [x] Collection entries in customer account ledger
- [x] Financial account association (Phase 72)
- [x] Payment method tracking (Phase 72)
- [x] Financial account ledger entry on collection (Phase 72)

### Supplier Payments / مدفوعات الموردين
- [x] Record supplier payment
- [x] Reduce outstanding debt on payment
- [x] Payment entries in supplier account ledger
- [x] Financial account association (Phase 72)
- [x] Payment method tracking (Phase 72)
- [x] Financial account ledger entry on supplier payment (Phase 72)

### Expenses / المصروفات
- [x] Category, amount, notes
- [x] Expense tracking and listing
- [x] Financial account association (Phase 72)
- [x] Payment method tracking (Phase 72)
- [x] Financial account ledger entry on expense creation (Phase 72)

### Financial Accounts / الحسابات المالية (Phases 71, 72, 76, 79)
- [x] Financial account model — treasury, bank, electronic wallet (Phase 71)
- [x] Financial ledger — append-only account entries with inflow/outflow direction (Phase 71)
- [x] Account balance derived from ledger entries (Phase 71)
- [x] Opening balance support with corrections (Phase 71)
- [x] Activate/deactivate accounts — owner-only (Phase 71)
- [x] Account statement with date filtering (Phase 71)
- [x] Backup v4 with financial accounts data (Phase 71)
- [x] Transaction integration — sales, purchases, collections, payments, expenses link to financial accounts (Phase 72)
- [x] Payment method tracking — cash, bank transfer, mobile wallet, check (Phase 72)
- [x] Financial account entry creation for all transaction types (Phase 72)
- [x] Cancellation reversal entries for financial accounts (Phase 72)
- [x] Internal financial transfers — atomic paired entries (Phase 76)
- [x] Transfer reversal with mandatory reason (Phase 76)
- [x] Transfer history and audit (Phase 76)
- [x] Backup/restore for transfers (Phase 76)
- [x] Account balance report — per-account opening/closing with inflow/outflow (Phase 79)
- [x] Account statement report — per-account entry-level with running balance (Phase 79)
- [x] Payment method report — aggregated by payment method, excluding transfers (Phase 79)
- [x] Transfer report — authoritative transfer register with reversal tracking (Phase 79)
- [x] Negative-balance controls — per-account `allowNegativeBalance` toggle, owner-only policy, balance guard on outflows and transfers (DC-U007)

### Inventory Management / إدارة المخزون
- [x] Stock movements: opening balance, purchase intake, sale, manual increase/decrease
- [x] Cancellation reversals (both sales and purchases)
- [x] Stock taking (physical count)
- [x] Variance report (expected vs. actual)

### Document History / سجل المستندات
- [x] Unified view of sales and purchases
- [x] Cancellation status display
- [x] Cancellation metadata
- [x] Reversal movement tracking

### Dashboard / لوحة التحكم
- [x] Low stock alerts
- [x] Customer balance alerts
- [x] Supplier balance alerts
- [x] Daily activity summary

### Reports / التقارير
- [x] Daily activity report (purchases, sales, expenses, collections, payments, stock balances)
- [x] PDF export: sales invoice, purchase invoice, customer statement, supplier statement, daily report
- [x] 6 printable document views
- [x] Account-based financial reports — balance, statement, payment method, transfer (Phase 79)

### PDF & Printing / الطباعة
- [x] Sales invoice PDF
- [x] Purchase invoice PDF
- [x] Customer statement PDF
- [x] Supplier statement PDF
- [x] Daily report PDF
- [x] Printable document views (6 views)

### WhatsApp Integration
- [x] WhatsApp assisted sharing (opens WhatsApp with prepared message)

### Backup & Data Safety / النسخ الاحتياطي
- [x] Backup export (JSON, Version 4 with financial accounts — backward-compatible with v1/v2/v3)
- [x] Backup restore
- [x] Data wipe with pre-wipe backup

### Authentication & Security / المصادقة
- [x] Owner/employee roles
- [x] 16 granular permission flags
- [x] Audit log

### Business Identity / الهوية التجارية
- [x] Establishment name
- [x] Logo upload
- [x] Theme settings (light/dark, preset themes)

### UI / واجهة المستخدم
- [x] Arabic RTL layout
- [x] Amiri font
- [x] Navigation theme and business branding (Phase 67)
- [x] Business logo and invoice branding (Phase 68)

---

## Partially Implemented

These features exist in some form but are incomplete or lack key integration:

| Feature | Status | Missing |
|---------|--------|---------|
| `SalePaymentMode.partial` | Enum exists | Split payment (multiple accounts per invoice) NOT implemented — DC-U002 closed (owner decisions adopted Phase 78), awaiting implementation phase |
| PDF stock adjustment report | — | NOT implemented |
| Invoice logo display | Logo upload exists | Invoices do NOT show logo |
| Windows app icon from business logo | — | NOT implemented at runtime |

---

## NOT Implemented

The following features do not exist in any form:

### Financial Reports / التقارير المالية
- [ ] Inflows report
- [ ] Outflows report
- [ ] Collection by account report
- [ ] Supplier payment by account report
- [ ] Expense by account report
- [ ] Fee tracking (bank/wallet fees)
- [x] Reconciliation history and differences (Phase 80)

### Daily Close & Reconciliation / الإغلاق اليومي والتسوية
- [x] Daily cash closing (Phase 80)
- [x] Cash count and reconciliation workflow (Phase 80)
- [x] Period close and posting lock (Phase 80)

### Advanced Operations / العمليات المتقدمة
- [ ] Mixed source operations
- [ ] Collection cancellation (CAN-005)
- [ ] Payment cancellation (CAN-006)

### Cloud & Multi-device / السحابة والأجهزة المتعددة
- [ ] Cloud sync
- [ ] Backend server/API
- [ ] Multi-device support
- [ ] Mobile application

### SaaS & Multi-tenancy / الخدمة كمنصة
- [ ] Tenant/establishment multi-tenancy
- [ ] User/device identity management
- [ ] Offline-first queue
- [ ] Conflict resolution
- [ ] Server-side validation
- [ ] Subscription/licensing

### Other
- [ ] Multi-currency support

---

## Deferred by Dependency

These features are blocked by upstream dependencies:

```
Financial Reports (RPT-003–007)
  ├── ACC-011 (internal transfers) — ✅ implemented in Phase 76
  ├── RPT-003, RPT-004, RPT-007 — ✅ implemented in Phase 79
  ├── RPT-008 (reconciliation) — blocked by ACC-012
  ├── ACC-012 (daily cash closing) — DC-U006 CLOSED (owner decisions adopted Phase 78)
  └── scope and acceptance criteria must be defined before implementation

Cloud sync
  ├── depends on: Financial accounts — ✅ implemented (Phases 71, 72, 76)
  ├── depends on: Financial ledger — ✅ implemented (Phase 71)
  └── depends on: Local stability (proven production use)

Mobile application
  ├── depends on: Cloud sync
  ├── depends on: Backend API
  └── depends on: Authentication (server-side)

Multi-device support
  ├── depends on: Cloud sync
  ├── depends on: Conflict resolution
  └── depends on: Idempotency

SaaS licensing
  ├── depends on: Cloud infrastructure
  └── depends on: Multi-tenant architecture
```

**Rule: No Cloud/Mobile before the local model is fully proven in production.**

---

## Phase History

| Phase | Description | Type | Status |
|-------|-------------|------|--------|
| 18–21 | Core business features, QA, release | Implementation | ✅ Complete |
| 22–26 | Pilot delivery and first customer trial | Implementation | ✅ Complete |
| 27–38 | Pilot continuation, credit, supplier accounts, opening balances, reports | Implementation | ✅ Complete |
| 39–44 | Multi-item sales, printable docs, PDF export, WhatsApp | Implementation | ✅ Complete |
| 49–52 | Stock taking, pilot lock, simulation, accounting freeze audit | Implementation | ✅ Complete |
| 53 | Cloud migration readiness (planning only) | Documentation | ✅ Complete |
| 54–56 | Delivery refresh, client pilot handoff, owner pilot observation | Documentation | ✅ Complete |
| 57–58 | Pilot feedback review, accounting freeze audit | Documentation | ✅ Complete |
| 59/59A | Sale cancellation customer ledger symmetry | Implementation | ✅ Complete |
| 60 | Final production candidate packaging | Documentation | ✅ Complete |
| 61 | Backup/restore safety plan + owner trial incident log | Documentation | ✅ Complete |
| 62 | Data wipe sequential safety audit | Documentation | ✅ Complete |
| 63 | Controlled owner trial day-1 script | Documentation | ✅ Complete |
| 64 | Owner dashboard alerts | Implementation | ✅ Complete |
| 65 | Pilot delivery refresh | Documentation | ✅ Complete |
| **66** | **NOT EXECUTED — owner trial was not run** | — | ❌ **No tag exists** |
| 67 | Navigation theme and business branding | Implementation | ✅ Complete |
| 68/68A | Business logo, invoice, Windows icon branding | Implementation | ✅ Complete |
| 69 | Final branded delivery package refresh | Documentation | ✅ Complete |
| 70 | Master Roadmap recovery & financial/cloud gap audit | Documentation | ✅ Complete |
| 71 | Unified financial accounts foundation | Implementation | ✅ Complete |
| 72 | Transaction integration with financial accounts | Implementation | ✅ Complete |
| 73 | Financial reporting & reconciliation scope freeze | Documentation | ✅ Complete |
| 74 | Internal financial transfers scope & owner decision pack | Documentation | ✅ Complete |
| 75 | Internal financial transfers owner decisions adoption & implementation scope | Documentation | ✅ Complete |
| 76 | Internal financial transfers implementation | Implementation | ✅ Complete |
| 77 | Financial reporting scope & governing baseline reconciliation | Documentation | ✅ Complete |
| 78 | Financial owner decisions adoption & compatibility audit | Documentation | ✅ Complete |
| 79 | Account-based financial reports implementation | Implementation | ✅ Complete |
| 80 | Period closing / daily closing / financial reconciliation | Implementation | ✅ Complete |
| 81 | Transaction-level financial Backup/Restore contract remediation | Implementation | ✅ Complete (current) |

> **⚠️ Phase 66 was never executed. No git tag exists for Phase 66. Do not reference it as completed.**

---

## Critical Rules

These rules are absolute and must never be violated:

### 1. Every Visible Page Must Be Real and Complete
No placeholder screens, no "under construction" pages, no stub components. Every page the user can navigate to must display real data and function correctly.

### 2. No Placeholders or "Under Construction"
Every UI element must serve a purpose. If a feature is not ready, it must not be visible in the navigation.

### 3. Accounting Integrity Is Top Priority
All financial calculations must be correct. Balances must always reconcile. No silent rounding errors (use integer arithmetic exclusively).

### 4. Balance Must Come from an Auditable Ledger
Account balances are always derived from ledger entries — never stored as independent values. The ledger is the single source of truth.

### 5. No Cloud/Mobile Before Local Model Is Proven
The local single-device application must be fully stable and proven in real owner use before any cloud, server, or mobile development begins.

### 6. Phase 66 Was Never Executed
No Phase 66 tag exists in the repository. The owner trial that Phase 66 was supposed to guide was not run. Phase 66 should not be referenced as a completed milestone.

---

## Future Roadmap

The recommended path forward, respecting all dependencies:

### Financial Accounts & Ledger — COMPLETE

**Phase 71: Financial Accounts Foundation — COMPLETED**
1. ✅ Define financial account model (treasury, bank, electronic wallet) — `FinancialAccount`, `FinancialAccountType` enum
2. ✅ Implement financial ledger (account movements table) — `FinancialAccountEntry` with append-only ledger
3. ✅ Account balance derived from ledger — `currentBalanceForAccount()`, `allAccountBalances()`
4. ✅ Opening balance support — set once per account, stored on account + ledger entry
5. ✅ Opening balance corrections — append-only correction entries with reason and audit trail
6. ✅ Activate/deactivate accounts — owner-only, disabled accounts excluded from active list
7. ✅ Account statement with date filtering — `statementForAccount()` with running balance
8. ✅ Backup v4 with financial accounts data — backward-compatible with v1/v2/v3
9. ✅ Backup restore, preview, and wipe support for financial accounts
10. ✅ Dashboard navigation — owner-only financial accounts destination
11. ✅ Comprehensive test coverage (44 new tests, 630 total)

**Phase 72: Transaction Integration (Track B) — COMPLETED**
1. ✅ Associate sales/purchases/collections/payments/expenses with financial accounts — `financialAccountId` on all transaction models
2. ✅ Add payment method tracking — `PaymentMethod` enum (cash, bankTransfer, mobileWallet, check)
3. ✅ FA entry creation for cash/partial sales — inflow `salePayment` entries
4. ✅ FA entry creation for paid/partial purchases — outflow `purchasePayment` entries
5. ✅ FA entry creation for customer collections — inflow `customerCollection` entries
6. ✅ FA entry creation for supplier payments — outflow `supplierSettlement` entries
7. ✅ FA entry creation for expenses — outflow `expense` entries
8. ✅ Cancellation reversal entries — outflow/inflow `cancellationReversal` entries
9. ✅ `PurchasePaymentMode` enum (credit, paid, partial) mirroring `SalePaymentMode`
10. ✅ Bug fix: `SaleRepository.createSale` now forwards `financialAccountId` and `paymentMethod` from draft
11. ✅ Comprehensive test coverage (43 new tests, 673 total)

**Phase 73: Financial Reporting & Reconciliation Scope Freeze — COMPLETED**
1. ✅ Documentation, architecture, and decision-register scope freeze only
2. ✅ Reconciled the roadmap, traceability matrix, and developer handoff notes
3. ✅ Confirmed no production feature, schema, backup-version, or UI-page change
4. ✅ Confirmed internal transfers, daily close, reconciliation, and financial reports remain unimplemented
5. ✅ Kept `DC-U006` open: no hard close, period lock, posting lock, automatic carry-forward, irreversible close, or backdated-entry restriction without an explicit owner decision
6. ✅ Recorded the dependency order and accounting invariants for future implementation

**Phase 74: Internal Financial Transfers Scope & Owner Decision Pack — COMPLETED**
1. ✅ Documentation, architecture, and owner-decision preparation only for `ACC-011`
2. ✅ No production transfer model, UI, schema, migration, or backup-format change
3. ✅ Recorded transfer accounting invariants, candidate architecture, atomicity, statement/audit, schema, backup, and UI assessments
4. ✅ Added open owner decisions required before any internal-transfer implementation
5. ✅ Confirmed the next implementation phase is not authorized or numbered

**Phase 75: Internal Financial Transfers Owner Decisions Adoption & Implementation Scope — COMPLETED**
1. ✅ Recorded the owner's official decisions for `DC-U013` through `DC-U024`
2. ✅ Defined and approved the bounded scope and acceptance criteria for Phase 76 without starting it
3. ✅ Kept `ACC-011` unimplemented and kept `DC-U006` open
4. ✅ No production code, UI, schema, migration, or backup-format change

**Phase 76: Internal Financial Transfers Implementation — COMPLETED**
1. ✅ Implemented `ACC-011`: a dedicated transfer aggregate with exactly two linked financial-account ledger entries
2. ✅ Applied Phase 75 owner decisions: no first-release fees; sufficient source balance required; active distinct accounts only; auditable past dates but no future date; owner-only create/reverse; documented paired reversal with mandatory reason and no repeat; client request ID plus unique reference; UUID plus display sequence; optional normal note; full review then one confirmation
3. ✅ Preserved atomicity, ledger-derived balances, backup/restore integrity, Arabic RTL functional UI, and all existing accounting/inventory/customer/supplier behavior
4. ✅ Comprehensive test coverage (110 new tests, 676 total)

### Then: Financial Reporting & Reconciliation — COMPLETE

**Phase 77: Financial Reporting Scope & Governing Baseline Reconciliation — COMPLETED**
1. ✅ Reconciled Master Roadmap, Traceability Matrix, and Developer Handoff Notes with actual code state
2. ✅ Defined financial report scope: Account Balance Report, Financial Account Statement, Payment Method Report, Internal Transfer Report
3. ✅ Documented accounting rules, date/ordering rules, permissions, filters, export, and backup impact
4. ✅ Documented acceptance criteria and test plans for future implementation
5. ✅ Documented open owner decisions (`DC-U002`, `DC-U006`, `DC-U007`, `DC-U008`)
6. ✅ No production code, UI, schema, or backup-format change

**Phase 79: Account-Based Financial Reports Implementation — COMPLETED**
1. ✅ Implemented 4 production-grade financial reports: Account Balance, Account Statement, Payment Method, Transfer
2. ✅ Permission-gated access with `canViewFinancialReports` and `canExportFinancialReports`
3. ✅ PDF and CSV export for all 4 reports
4. ✅ 65 new tests (774 total)
5. ✅ No schema changes — read-only from existing ledger data

### Then: Production Hardening
1. ✅ Preserve transaction-level financial-account and payment-method linkage in Backup/Restore (Phase 81)
2. Complete remaining partial implementations (split payments — DC-U002 closed, awaiting its own implementation phase; invoice-logo status reconciliation; PDF stock adjustment)
3. Extended owner trial under real conditions
4. Performance optimization
5. Edge case hardening

### Only After Local Model Is Proven: Cloud Readiness
1. Cloud sync architecture
2. Backend API design
3. Conflict resolution strategy
4. Idempotency framework

### Only After Cloud: Multi-device & Mobile
1. Mobile application
2. Multi-device sync
3. SaaS multi-tenancy
4. Subscription/licensing

---

## Version History

| Version | Date | Phase | Notes |
|---------|------|-------|-------|
| 1.0 | — | 69 | Initial master roadmap creation |
| 1.1 | 2026-07-10 | 71 | Phase 71 completed — financial accounts foundation |
| 1.2 | 2026-07-10 | 72 | Phase 72 completed — transaction integration with financial accounts |
| 1.3 | 2026-07-11 | 73 | Financial reporting & reconciliation scope freeze; documentation only, no production implementation |
| 1.4 | 2026-07-11 | 74 | Internal financial transfers scope and owner decision pack; documentation only, ACC-011 remains unimplemented |
| 1.5 | 2026-07-11 | 75 | Owner decisions adopted and Phase 76 execution scope defined; documentation only, ACC-011 remains unimplemented |
| 1.6 | 2026-07-11 | 76 | Internal financial transfers implemented; ACC-011 implemented |
| 1.7 | 2026-07-11 | 77 | Governing baseline reconciliation; corrected stale roadmap/traceability/handoff data; defined financial reporting scope |
| 1.8 | 2026-07-11 | 78 | Owner decisions adopted (DC-U002, DC-U006, DC-U007, DC-U008); compatibility audit completed; 33 characterization tests added |
| 1.9 | 2026-07-11 | 79 | Account-based financial reports implemented (balance, statement, payment method, transfer); 65 new tests (774 total) |
| 2.0 | 2026-07-11 | 81 | Backup v6 preserves transaction-level financial account and payment method links; v1–v5 remain compatible; 784 tests |

---

## Post-Phase 81 Governance Audit

A governance audit was completed after Phase 81. No "Phase 82" or specific next phase number exists in the repository. The audit identified multiple valid candidates (DC-U007, CAN-005/CAN-006, DC-U002, DC-U008) with no explicit ordering. DC-U007 (negative-balance controls) was recommended as highest priority based on integrity evidence — IMPLEMENTED. Remaining candidates: CAN-005/CAN-006 (cancellations), DC-U002 (split payments), DC-U008 (overpayments/refunds). DC-U014 is CLOSED (Phase 75) and implemented (Phase 76). See `docs/POST-PHASE-81-GOVERNANCE-AUDIT.md` for full analysis.

---

*This document is the single source of truth for product direction. All planning decisions should reference this file.*
