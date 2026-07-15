# Master Product Roadmap — Grain Warehouse ERP Lite

## خارطة طريق المنتج الرئيسية — نظام مخزن الحبوب ERP Lite

> **Last Updated / آخر تحديث:** Owner Wipe — Post-Phase 81 Unified Baseline
> **HEAD / الرأس الحالي:** `4d8705b2cc76b757294a5ddaed44fd8adc83eaec`
> **Branch:** `transaction-safe-restore-wipe`
> **Tests / الاختبارات:** 862/862 passing
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

**Phase:** Post-Owner Wipe — Unified Accounting Baseline
**HEAD:** `4d8705b2cc76b757294a5ddaed44fd8adc83eaec`
**Branch:** `transaction-safe-restore-wipe`
**Test Suite:** 862/862 tests passing
**Static Analysis:** Flutter analyze — no issues
**Build:** Windows release build — passing

**Integrated Chain:**
DC-U007 → CAN-005/006/007 → DC-U002 Core → DC-U008 Core → Owner Wipe

The application is in a **production-ready local state** for a single warehouse owner pilot. All core business features are complete, tested, and branded. The system is operating in controlled owner trial.

---

## Implemented

The following features are fully implemented, tested, and passing all 862 tests:

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
- [x] Negative-balance controls — per-account `allowNegativeBalance` toggle, owner-only policy, balance guard on outflows and transfers (DC-U007 — Commit `af56ced`)
- [x] Atomic financial reversals — collection cancellation, payment cancellation, financial account reversal (CAN-005/006/007 — Commit `49878f7`)
- [x] Split payment allocations — multi-account per invoice, atomic allocation creation (DC-U002 Core — Commit `839ff78`)
- [x] Overpayments, advances, refunds — customer/supplier credit tracking, refund documents, owner approval (DC-U008 Core — Commit `59d689f`)

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
- [x] Backup export (JSON, Version 6 with transaction financial linkage — backward-compatible with v1–v5)
- [x] Backup restore
- [x] Data wipe with pre-wipe backup
- [x] Snapshot rollback coverage (Owner Wipe — Commit `4d8705b`)

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
| Split Payments | Core implemented (DC-U002 — Commit `839ff78`) | End-User UI — Arabic RTL split payment review and confirmation screen |
| Overpayments/Advances/Refunds | Core implemented (DC-U008 — Commit `59d689f`) | End-User UI — Arabic RTL overpayment/approval/refund workflow screen |
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
- [x] Collection cancellation (CAN-005 — Commit `49878f7`)
- [x] Payment cancellation (CAN-006 — Commit `49878f7`)

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
| 81 | Transaction-level financial Backup/Restore contract remediation | Implementation | ✅ Complete |
| DC-U007 | Negative-balance controls — per-account toggle, balance guard, owner-only policy | Implementation | ✅ Complete |
| CAN-005/006/007 | Atomic financial reversals — collection cancellation, payment cancellation, financial account reversal | Implementation | ✅ Complete |
| DC-U002 Core | Atomic split payments — multi-account allocation, atomic creation, cancellation reversal | Implementation | ✅ Complete |
| DC-U008 Core | Overpayments, advances, refunds — customer/supplier credit, refund documents, owner approval | Implementation | ✅ Complete |
| Owner Wipe | Snapshot coverage gate + transaction rollback safety | Implementation | ✅ Complete (current) |

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

All core financial features are implemented and tested:

**Phases 71–81: Foundation through Backup/Restore — COMPLETED**
1. ✅ Financial account model (treasury, bank, electronic wallet)
2. ✅ Financial ledger (append-only entries, balance derived from ledger)
3. ✅ Transaction integration (all transaction types link to financial accounts)
4. ✅ Internal financial transfers (atomic paired entries)
5. ✅ Account-based financial reports (balance, statement, payment method, transfer)
6. ✅ Backup v6 with transaction-level financial linkage

**DC-U007: Negative-Balance Controls — COMPLETED**
1. ✅ Per-account `allowNegativeBalance` toggle
2. ✅ Balance guard on outflows and transfers
3. ✅ Owner-only policy with audit trail

**CAN-005/006/007: Atomic Financial Reversals — COMPLETED**
1. ✅ Collection cancellation with customer ledger reversal
2. ✅ Payment cancellation with supplier ledger reversal
3. ✅ Financial account reversal with compensating entries

**DC-U002: Split Payments Core — COMPLETED**
1. ✅ Multi-account allocation per invoice
2. ✅ Atomic allocation creation with rollback
3. ✅ Cancellation reversal per allocation

**DC-U008: Overpayments/Advances/Refunds Core — COMPLETED**
1. ✅ Customer/supplier credit tracking
2. ✅ Refund documents with compensating entries
3. ✅ Owner approval with authentic binding

### Then: Financial UI — NEXT

**Split Payments End-User UI** — Arabic RTL split payment review and confirmation screen
**Advances/Overpayments/Refunds End-User UI** — Arabic RTL overpayment/approval/refund workflow screen

### Then: Persistence

1. ✅ Phase 7 — Durable Persistence Architecture Decision (`ADR-001`): SQLite with Drift selected
2. Phase 8A — Durable Persistence Foundation — complete (schema v1, lifecycle,
   transactions, generated code; no business repository migration)
3. Phase 8B — not started
4. Transaction-safe restore
5. Transaction-safe wipe

Phase 7 is documentation and architecture only. It adds no persistence package,
schema, migration, generated code, or production repository implementation.
Phase 8 must satisfy the transition and acceptance gates in
`docs/ADR-001-DURABLE-PERSISTENCE.md`.

> **لا تُستخدم بيانات مالية تشغيلية حقيقية قبل نجاح التخزين الدائم واختبارات crash recovery وBackup/Restore drill.**

### Then: Production Hardening

1. Remaining financial and settlement reports
2. Stock-adjustment PDF + UI/branding/navigation audit
3. Controlled synthetic-data pilot
4. Real Financial Data Pilot (blocked by persistence)
5. Extended owner trial under real conditions
6. Performance optimization
7. Edge case hardening

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
| 2.1 | 2026-07-14 | DC-U007 | Negative-balance controls implemented; 834 tests |
| 2.2 | 2026-07-14 | CAN-005/006/007 | Atomic financial reversals implemented; 838 tests |
| 2.3 | 2026-07-14 | DC-U002 Core | Split payments core implemented; 845 tests |
| 2.4 | 2026-07-14 | DC-U008 Core | Overpayments/advances/refunds core implemented; 858 tests |
| 2.5 | 2026-07-14 | Owner Wipe | Snapshot coverage gate + transaction rollback safety; 862 tests |
| 3.0 | 2026-07-14 | Governance | Governing documentation reconciliation with unified accounting baseline |

---

## Post-Phase 81 Governance Audit

A governance audit was completed after Phase 81. No "Phase 82" or specific next phase number exists in the repository. The audit identified multiple valid candidates (DC-U007, CAN-005/CAN-006, DC-U002, DC-U008) with no explicit ordering.

**All candidates have since been implemented at the Core level:**

- DC-U007 (negative-balance controls) — ✓ Commit `af56ced`, Tag `dc-u007-windows-release-build-verified`
- CAN-005/006/007 (financial reversals) — ✓ Commit `49878f7`, Tag `can-005-006-007-financial-reversals-pass`
- DC-U002 (split payments) Core — ✓ Commit `839ff78`, Tag `dc-u002-split-payments-pass`
- DC-U008 (overpayments/advances/refunds) Core — ✓ Commit `59d689f`, Tag `dc-u008-overpayments-advances-refunds-pass`

**Owner Wipe** completed the unified accounting baseline — ✓ Commit `4d8705b`, Tag `owner-wipe-final-pass`

**Unified baseline:** `4d8705b2cc76b757294a5ddaed44fd8adc83eaec`
**Test count:** 862/862 passing
**Next features:** Split Payments UI, then Advances/Overpayments/Refunds UI

See `docs/POST-PHASE-81-GOVERNANCE-AUDIT.md` for the original pre-implementation analysis (historical snapshot).

---

*This document is the single source of truth for product direction. All planning decisions should reference this file.*
# Phase 8B status

Phase 8A is locked. Phase 8B is limited to durable `ProductRepository` persistence on schema version 2. Remaining repositories are still in-memory unless separately documented; Phase 8C has not started.
