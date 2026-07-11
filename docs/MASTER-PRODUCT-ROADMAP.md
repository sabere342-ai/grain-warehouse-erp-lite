# Master Product Roadmap — Grain Warehouse ERP Lite

## خارطة طريق المنتج الرئيسية — نظام مخزن الحبوب ERP Lite

> **Last Updated / آخر تحديث:** Phase 69 — Final Branded Delivery Package Refresh
> **HEAD / الرأس الحالي:** `c37db59`
> **Tests / الاختبارات:** 586/586 passing
> **Flutter Analyze:** No issues
> **Windows Release Build:** Passing

---

## Table of Contents / فهرس المحتويات

1. [Project Overview](#project-overview)
2. [Technical Architecture](#technical-architecture)
3. [Current Status (Phase 69)](#current-status)
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
| Backup/Restore | JSON export/import (Version 3 with logo) |
| PDF generation | Flutter PDF rendering |
| Database | **None** — no SQLite, no cloud, no server |
| Networking | None (offline-only) |
| Auth | Local role-based (owner/employee) |

---

## Current Status

**Phase:** 69 — Final Branded Delivery Package Refresh
**HEAD:** `c37db59`
**Test Suite:** 586/586 tests passing
**Static Analysis:** Flutter analyze — no issues
**Build:** Windows release build — passing

The application is in a **production-ready local state** for a single warehouse owner pilot. All core business features are complete, tested, and branded. The system is operating in controlled owner trial.

---

## Implemented

The following features are fully implemented, tested, and passing all 586 tests:

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

### Purchases / المشتريات
- [x] Supplier-bound purchases
- [x] Purchase cancellation with stock reversal
- [x] Purchase cancellation with supplier account reversal

### Collections / التحصيل
- [x] Record customer collection
- [x] Reduce outstanding balance on collection
- [x] Collection entries in customer account ledger

### Supplier Payments / مدفوعات الموردين
- [x] Record supplier payment
- [x] Reduce outstanding debt on payment
- [x] Payment entries in supplier account ledger

### Expenses / المصروفات
- [x] Category, amount, notes
- [x] Expense tracking and listing

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
- [x] Backup export (JSON, Version 3 with logo)
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
| `SalePaymentMode.partial` | Enum exists | Split payment (multiple accounts per invoice) NOT implemented |
| Expenses | Category, amount, notes | No account/payment method association |
| Customer collections | Amount, date | No payment method or account association |
| Supplier payments | Amount, date | No payment method or account association |
| PDF stock adjustment report | — | NOT implemented |
| Invoice logo display | Logo upload exists | Invoices do NOT show logo |
| Windows app icon from business logo | — | NOT implemented at runtime |

---

## NOT Implemented

The following features do not exist in any form:

### Financial Accounts / الحسابات المالية
- [ ] Financial accounts (treasury/cashbox, bank accounts, electronic wallets)
- [ ] Financial ledger (unified financial account movement ledger)
- [ ] Account selection in sales/purchases/collections/payments/expenses
- [ ] Payment method tracking (cash vs bank transfer vs electronic)
- [ ] Transfer between financial accounts
- [ ] Daily cash closing/reconciliation

### Financial Reports / التقارير المالية
- [ ] Account balance report
- [ ] Account statement
- [ ] Inflows report
- [ ] Outflows report
- [ ] Sales by payment method report
- [ ] Collection by account report
- [ ] Supplier payment by account report
- [ ] Expense by account report
- [ ] Transfer report
- [ ] Fee tracking (bank/wallet fees)
- [ ] Reconciliation report

### Advanced Operations / العمليات المتقدمة
- [ ] Mixed source operations
- [ ] Cancellation reversal for financial accounts

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
Cloud sync
  ├── depends on: Financial accounts (must exist first)
  ├── depends on: Financial ledger (must exist first)
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

| Phase | Description | Status |
|-------|-------------|--------|
| 18–21 | Core business features, QA, release | ✅ Complete |
| 22–26 | Pilot delivery and first customer trial | ✅ Complete |
| 27–38 | Pilot continuation, credit, supplier accounts, opening balances, reports | ✅ Complete |
| 39–44 | Multi-item sales, printable docs, PDF export, WhatsApp | ✅ Complete |
| 49–52 | Stock taking, pilot lock, simulation, accounting freeze audit | ✅ Complete |
| 53 | Cloud migration readiness (planning only) | ✅ Complete |
| 54–56 | Delivery refresh, client pilot handoff, owner pilot observation | ✅ Complete |
| 57–58 | Pilot feedback review, accounting freeze audit | ✅ Complete |
| 59/59A | Sale cancellation customer ledger symmetry | ✅ Complete |
| 60 | Final production candidate packaging | ✅ Complete |
| 61 | Backup/restore safety plan + owner trial incident log | ✅ Complete |
| 62 | Data wipe sequential safety audit | ✅ Complete |
| 63 | Controlled owner trial day-1 script | ✅ Complete |
| 64 | Owner dashboard alerts | ✅ Complete |
| 65 | Pilot delivery refresh | ✅ Complete |
| **66** | **NOT EXECUTED — owner trial was not run** | ❌ **No tag exists** |
| 67 | Navigation theme and business branding | ✅ Complete |
| 68/68A | Business logo, invoice, Windows icon branding | ✅ Complete |
| 69 | Final branded delivery package refresh | ✅ Complete (current) |

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

### Next: Financial Accounts & Ledger (unlocks everything downstream)

**Phase 71: Financial Accounts Foundation (COMPLETED)**
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

**Phase 73: Financial Reporting & Reconciliation Scope Freeze — DOCUMENTATION COMPLETE**
1. ✅ Documentation, architecture, and decision-register scope freeze only
2. ✅ Reconciled the roadmap, traceability matrix, and developer handoff notes
3. ✅ Confirmed no production feature, schema, backup-version, or UI-page change
4. ✅ Confirmed internal transfers, daily close, reconciliation, and financial reports remain unimplemented
5. ✅ Kept `DC-U006` open: no hard close, period lock, posting lock, automatic carry-forward, irreversible close, or backdated-entry restriction without an explicit owner decision
6. ✅ Recorded the dependency order and accounting invariants for future implementation

**Phase 74: Internal Financial Transfers Scope & Owner Decision Pack — DOCUMENTATION COMPLETE**
1. ✅ Documentation, architecture, and owner-decision preparation only for `ACC-011`
2. ✅ No production transfer model, UI, schema, migration, or backup-format change
3. ✅ Recorded transfer accounting invariants, candidate architecture, atomicity, statement/audit, schema, backup, and UI assessments
4. ✅ Added open owner decisions required before any internal-transfer implementation
5. ✅ Confirmed the next implementation phase is not authorized or numbered

**Phase 75: Internal Financial Transfers Owner Decisions Adoption & Implementation Scope — DOCUMENTATION COMPLETE**
1. ✅ Recorded the owner's official decisions for `DC-U013` through `DC-U024`
2. ✅ Defined and approved the bounded scope and acceptance criteria for Phase 76 without starting it
3. ✅ Kept `ACC-011` unimplemented and kept `DC-U006` open
4. ✅ No production code, UI, schema, migration, or backup-format change

### Then: Financial Reporting & Reconciliation
The following are planned capabilities, not approved numbered implementation phases. Their detailed scope is frozen in Phase 73 and must be defined with acceptance criteria before implementation:

1. Internal account transfers between treasury, bank, and electronic-wallet accounts
2. Account-based financial reports: sales by payment method, collections, supplier payments, expenses, transfers, and fees
3. Cash count and reconciliation workflow
4. Daily or period close only after `DC-U006` receives an explicit owner decision

No Phase 73 production implementation exists for these capabilities. No account transfer, daily close, reconciliation, or financial report is implemented by this documentation phase.

Phase 74 does not implement internal transfers. Phase 75 records the owner decisions and formally defines the next execution scope:

**Phase 76: Internal Financial Transfers Implementation — COMPLETE**
- Implement only `ACC-011`: a dedicated transfer aggregate with exactly two linked financial-account ledger entries.
- Apply the Phase 75 owner decisions: no first-release fees; sufficient source balance required; active distinct accounts only; auditable past dates but no future date; owner-only create/reverse; documented paired reversal with mandatory reason and no repeat; client request ID plus unique reference; UUID plus display sequence; optional normal note; full review then one confirmation.
- Preserve atomicity, ledger-derived balances, backup/restore integrity, Arabic RTL functional UI, and all existing accounting/inventory/customer/supplier behavior.
- Excludes reconciliation, daily/period close, financial reports, cloud, multi-device, and mobile work.
- Implemented as the bounded `ACC-011` scope; see `PHASE-76-INTERNAL-FINANCIAL-TRANSFERS-IMPLEMENTATION.md`.

### Then: Production Hardening
1. Complete all partial implementations (split payments, invoice logos, PDF stock adjustment)
2. Extended owner trial under real conditions
3. Performance optimization
4. Edge case hardening

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

---

*This document is the single source of truth for product direction. All planning decisions should reference this file.*
