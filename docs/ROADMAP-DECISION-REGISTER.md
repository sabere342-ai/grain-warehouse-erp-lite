# Roadmap Decision Register

> **Grain Warehouse ERP Lite**
> **Last Updated:** 2026-07-15 — Phase 7 Durable Persistence Architecture Decision
> **Purpose:** Single source of truth for all project decisions — confirmed, recommended, and unresolved.

---

## Legend

| Status | Meaning |
|--------|---------|
| CONFIRMED | Decision made and implemented or in progress |
| RECOMMENDATION PENDING | Team recommends an approach, awaiting owner approval |
| REQUIRES OWNER DECISION | Awaiting owner input before work can proceed |
| DEFAULT ASSUMED | If no decision is made by deadline, the default applies |

---

## Confirmed Decisions

### DC-025: Durable local persistence technology

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-025 |
| **Question** | Which technology will provide the application's durable local source of truth? |
| **Alternatives** | A) SQLite with Drift, B) direct SQLite bindings, C) JSON live store, D) object store, E) cloud/server-first |
| **Decision** | SQLite with Drift behind existing repository interfaces |
| **Rationale** | Embedded ACID transactions, relational constraints, typed Dart access, versioned migrations, Windows/offline fit, and low operational burden best match the financial and inventory integrity contract. See `docs/ADR-001-DURABLE-PERSISTENCE.md`. |
| **Impact** | Phase 8 will introduce the schema and persistent repositories incrementally with one shared SQL transaction per logical command. JSON remains backup/export; cloud sync remains deferred. |
| **Deadline** | Accepted in Phase 7; implementation is Phase 8 |
| **Status** | CONFIRMED — Phase 8A foundation implemented; repository and business schema migration not started |

---

### DC-001: Windows local app is the primary platform

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-001 |
| **Question** | What is the primary platform for the application? |
| **Alternatives** | A) Windows desktop, B) Web app, C) Cross-platform desktop |
| **Decision** | Windows local app |
| **Rationale** | All delivery packages since Phase 20+ are Windows `.exe` builds. No web or cross-platform builds exist. |
| **Impact** | Simpler deployment for target clients. Limits platform flexibility. Cloud sync (DC-003) can still extend to other platforms. |
| **Deadline** | N/A |
| **Status** | CONFIRMED |

---

### DC-002: Source code is NOT delivered to the client

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-002 |
| **Question** | Is source code part of the deliverable? |
| **Alternatives** | A) Source + binaries, B) Binaries only |
| **Decision** | Source code is NOT delivered |
| **Rationale** | All delivery packages contain only Release binaries and documentation. No source code is included. |
| **Impact** | Client cannot modify code. Fixes and features must go through new releases. Intellectual property is protected. |
| **Deadline** | N/A |
| **Status** | CONFIRMED |

---

### DC-003: Cloud sync is within the project roadmap

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-003 |
| **Question** | Is cloud synchronization planned? |
| **Alternatives** | A) Local only, B) Cloud sync planned, C) Cloud-first |
| **Decision** | Cloud sync is within the roadmap |
| **Rationale** | Phase 53 is titled "cloud migration readiness." PRODUCT-ROADMAP explicitly lists cloud sync as a planned feature. |
| **Impact** | Local-first architecture must be designed to support future cloud synchronization. Schema and models should be cloud-ready. |
| **Deadline** | Implementation deferred — see DC-U010 for hosting decision |
| **Status** | CONFIRMED (but not yet implemented) |

---

### DC-004: Mobile app is within the project roadmap

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-004 |
| **Question** | Is a mobile app planned? |
| **Alternatives** | A) No mobile app, B) Mobile app planned |
| **Decision** | Mobile app is within the roadmap |
| **Rationale** | PRODUCT-ROADMAP doc line 15 explicitly lists mobile app. PROJECT-SCOPE mentions Android. |
| **Impact** | Backend design must anticipate mobile consumption. API design (DC-R002) must serve both desktop and mobile. |
| **Deadline** | Implementation deferred — see DC-U001 for mobile scope |
| **Status** | CONFIRMED (but not yet implemented) |

---

### DC-005: Multi-device support is within the project roadmap

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-005 |
| **Question** | Will the system support multiple devices per tenant? |
| **Alternatives** | A) Single device, B) Multi-device planned |
| **Decision** | Multi-device support is within the roadmap |
| **Rationale** | Phase 53 references future multi-device capability. Multiple docs reference multi-device scenarios. |
| **Impact** | Data model must support concurrent access. Conflict resolution strategy required (see DC-R002, DC-R003). |
| **Deadline** | Implementation deferred — see DC-U004 for branch support |
| **Status** | CONFIRMED (but not yet implemented) |

---

### DC-006: Treasury/cashbox, bank accounts, and electronic wallets are within the roadmap

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-006 |
| **Question** | Are treasury, bank accounts, and electronic wallets planned? |
| **Alternatives** | A) Cashbox only, B) Cashbox + bank, C) Cashbox + bank + wallets |
| **Decision** | All three are within the roadmap |
| **Rationale** | PRODUCT-ROADMAP doc lines 11-16 explicitly list treasury/cashbox, bank accounts, and electronic wallets. |
| **Impact** | Financial model must accommodate all account types. See DC-R001 for unified model recommendation. |
| **Deadline** | Implementation deferred — see DC-R001 and DC-U002 |
| **Status** | CONFIRMED (but not yet implemented) |

---

### DC-007: Every visible page must be real and complete

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-007 |
| **Question** | Are placeholder or stub pages allowed? |
| **Alternatives** | A) Allow stubs, B) No hidden pages — every visible page must be real |
| **Decision** | Every visible page must be real and complete |
| **Rationale** | Phase 31 established a strict no-hidden-pages rule. No feature should be visible if it is not functional. |
| **Impact** | UI development is slower but quality is higher. No false promises to the client. |
| **Deadline** | Ongoing |
| **Status** | CONFIRMED |

---

### DC-008: Integer arithmetic for money (Qirsh) and weight (grams)

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-008 |
| **Question** | What numeric type should be used for money and weight? |
| **Alternatives** | A) Integer (Qirsh/grams), B) Decimal, C) Float |
| **Decision** | Integer arithmetic |
| **Rationale** | PROJECT-SCOPE-AR.md mandates this. All models use int types. Eliminates floating-point rounding errors. |
| **Impact** | Precise calculations. Requires careful formatting for display. No rounding errors in financial reports. |
| **Deadline** | Already implemented |
| **Status** | CONFIRMED |

---

### DC-009: Arabic RTL interface

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-009 |
| **Question** | What is the primary UI language and layout direction? |
| **Alternatives** | A) Arabic RTL, B) Bilingual, C) English LTR |
| **Decision** | Arabic RTL interface |
| **Rationale** | All UI code uses Arabic. Amiri font is used throughout. Directionality widget is applied globally. |
| **Impact** | All new UI must follow RTL conventions. Text alignment, navigation flow, and icon placement must be RTL-aware. |
| **Deadline** | Already implemented |
| **Status** | CONFIRMED |

---

### DC-010: Two roles only: owner and employee

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-010 |
| **Question** | What role system should be implemented? |
| **Alternatives** | A) Owner/Employee (2 roles), B) Granular RBAC, C) Admin/Manager/Staff hierarchy |
| **Decision** | Two roles: owner and employee |
| **Rationale** | Defined in `lib/core/auth/user_role.dart` and `permissions.dart`. Simple permission model. |
| **Impact** | Simplified permission checks. Owner has full access. Employee permissions are limited. No need for complex role management UI. |
| **Deadline** | Already implemented |
| **Status** | CONFIRMED |

---

### DC-011: Phase 66 was never executed

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-011 |
| **Question** | Was Phase 66 executed? |
| **Alternatives** | A) Executed, B) Not executed |
| **Decision** | Phase 66 was never executed |
| **Rationale** | No Phase 66 tag exists in version control. PHASE-66 doc explicitly states "not executed." |
| **Impact** | Phase 66 scope remains unimplemented. May be needed in future if its requirements resurface. |
| **Deadline** | N/A |
| **Status** | CONFIRMED |

---

### DC-012: Firebase is scaffolded but not actively used

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-012 |
| **Question** | Is Firebase actively integrated or just scaffolded? |
| **Alternatives** | A) Fully integrated, B) Scaffolded with graceful fallback, C) Not present |
| **Decision** | Firebase is scaffolded but not actively used |
| **Rationale** | `firebase_bootstrap.dart` exists with graceful fallback logic. No active Firebase features are in use. |
| **Impact** | Firebase dependency exists in codebase. Can be activated or removed depending on cloud strategy (DC-U010). |
| **Deadline** | N/A |
| **Status** | CONFIRMED |

---

### DC-013: Supabase deferred until local product is coherent

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-013 |
| **Question** | When will Supabase be integrated? |
| **Alternatives** | A) Now, B) Deferred until local product is coherent |
| **Decision** | Deferred |
| **Rationale** | SUPABASE-TRANSITION-NOTE.md explicitly states Supabase is deferred until the local product is stable and coherent. |
| **Impact** | Cloud features are blocked. Local-first architecture must be the priority. Supabase remains a candidate for DC-U010. |
| **Deadline** | After local product reaches coherence milestone |
| **Status** | CONFIRMED |

---

## Recommended Decisions (need owner approval)

### DC-R001: Unified financial account model (CASH/BANK/WALLET)

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-R001 |
| **Question** | Should we use one model for all financial accounts? |
| **Alternatives** | A) Unified model with type enum (CASH, BANK, WALLET), B) Separate models per account type |
| **Recommendation** | A) Unified model with type enum |
| **Rationale** | Simpler ledger. Easier transfers between accounts. Unified reporting. Less code duplication. One model handles all three from DC-006. |
| **Impact if A (Unified)** | Simpler codebase. Single transfer mechanism. Easier to extend with new account types. |
| **Impact if B (Separate)** | More code duplication. Complex transfer logic between different models. More tables to maintain. |
| **Deadline** | Before Track B (financial modules) begins |
| **Status** | IMPLEMENTED — Phase 71. `FinancialAccount` model with `FinancialAccountType` enum (treasury/bank/electronicWallet). `lib/core/financial_accounts/financial_account.dart`. Commit merged into baseline `4d8705b`. |

---

### DC-R002: Command-based server API

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-R002 |
| **Question** | Should cloud use command-based API or table sync? |
| **Alternatives** | A) Command API, B) Table sync, C) Event sourcing |
| **Recommendation** | A) Command API with server-side transactions |
| **Rationale** | Atomic operations on server. Proper conflict resolution. Server controls business logic. Aligns with DC-R003 (server-authoritative). |
| **Impact if A (Command API)** | Clean API contract. Server validates everything. Easy to reason about. |
| **Impact if B (Table sync)** | Client must handle conflicts. More complex. Risk of data corruption. |
| **Impact if C (Event sourcing)** | Over-engineered for current scope. Higher complexity. Good audit trail but premature. |
| **Deadline** | Before cloud implementation begins (DC-003) |
| **Status** | RECOMMENDATION PENDING — awaiting owner approval |

---

### DC-R003: Server-authoritative posting

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-R003 |
| **Question** | Should the server validate and authorize all writes? |
| **Alternatives** | A) Server-authoritative, B) Client-authoritative with server sync |
| **Recommendation** | A) Server-authoritative for financial operations |
| **Rationale** | Financial data integrity requires server validation. Prevents conflicts. Aligns with DC-R002 (command API). |
| **Impact if A (Server-authoritative)** | Highest data integrity. Prevents unauthorized or malformed writes. Requires server to be online for writes. |
| **Impact if B (Client-authoritative)** | Risk of inconsistent data across devices. Conflicts harder to resolve. |
| **Deadline** | Before cloud implementation begins (DC-003) |
| **Status** | RECOMMENDATION PENDING — awaiting owner approval |

---

### DC-R004: Client-generated UUID + idempotency key

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-R004 |
| **Question** | How should IDs work for offline-first? |
| **Alternatives** | A) Client UUID + idempotency key, B) Server-assigned IDs |
| **Recommendation** | A) Client UUID + idempotency key |
| **Rationale** | Enables offline writes. Idempotency prevents duplicate processing. Standard pattern for offline-first apps. |
| **Impact if A (Client UUID)** | Works offline. No waiting for server. Idempotency prevents duplicates on retry. |
| **Impact if B (Server IDs)** | Cannot write offline. Requires online connectivity. Simpler but less resilient. |
| **Deadline** | Before cloud implementation begins (DC-003) |
| **Status** | RECOMMENDATION PENDING — awaiting owner approval |

---

### DC-R005: Cancellation/reversal instead of destructive delete

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-R005 |
| **Question** | Should all corrections use reversal entries? |
| **Alternatives** | A) Reversal entries, B) Soft delete, C) Edit in place |
| **Recommendation** | A) Reversal entries (already implemented for stock/customer/supplier) |
| **Rationale** | Already implemented for stock, customer, and supplier corrections. Provides full audit trail. Maintains accounting integrity. Reversible operations are safer. |
| **Impact if A (Reversal)** | Full audit trail. Accounting integrity preserved. Consistent with existing implementation. |
| **Impact if B (Soft delete)** | Records hidden but not corrected. Ledger may show inconsistent balances. |
| **Impact if C (Edit in place)** | No audit trail. Historical data is lost. Dangerous for financial records. |
| **Deadline** | Ongoing — extend pattern to all modules |
| **Status** | RECOMMENDATION PENDING — awaiting owner approval |

---

## Unresolved Owner Decisions

### DC-U001: Mobile app scope

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U001 |
| **Question** | What should the mobile app do? |
| **Alternatives** | A) Read-only dashboard, B) Field collections/payments only, C) Full operations |
| **Recommendation** | None yet — depends on business requirements |
| **Impact if A (Read-only)** | Lowest effort. Minimal cloud requirements. Useful for owner monitoring. |
| **Impact if B (Field collections)** | Medium effort. Requires cloud sync. Enables field staff to record collections/payments. |
| **Impact if C (Full operations)** | Highest effort. Full cloud backend required. Complex conflict resolution. Essentially a second app. |
| **Deadline** | Before Track H begins |
| **Status** | REQUIRES OWNER DECISION |

---

### DC-U002: Split payment support

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U002 |
| **Question** | Should one invoice be payable from multiple accounts? |
| **Alternatives** | A) Yes (split payment), B) No (single account only) |
| **Recommendation** | A (split payment) — adopted Phase 78 |
| **Impact if A (Yes)** | Higher UI complexity. Ledger must track partial payments across accounts. More flexible for clients. |
| **Impact if B (No)** | Simpler UI and ledger. Less flexible. May not match real-world business practices. |
| **Deadline** | Before Track B begins |
| **Owner decision** | Max 3–5 payment methods per invoice; per-account owner configuration; partial payments allowed; no new financial-account creation during split payment; single-account fallback for full payments. |
| **Status** | IMPLEMENTED Core — Commit `839ff78`, Tag `dc-u002-split-payments-pass`. End-User UI: OPEN. |

---

### DC-U003: Multi-currency support

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U003 |
| **Question** | Should the system support multiple currencies? |
| **Alternatives** | A) Yes, B) No (Qirsh only) |
| **Recommendation** | None yet |
| **Default** | B) Qirsh only (no multi-currency) |
| **Impact if A (Yes)** | Ledger must store currency per transaction. Conversion rates needed. Display formatting per currency. |
| **Impact if B (No)** | Simpler ledger. No conversion logic. Sufficient if all transactions are in Qirsh. |
| **Deadline** | Before Track B begins |
| **Status** | REQUIRES OWNER DECISION — default is Qirsh only |

---

### DC-U004: Branch/multi-location support

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U004 |
| **Question** | Will there be multiple warehouse locations? |
| **Alternatives** | A) Yes (multi-branch), B) No (single location) |
| **Recommendation** | None yet |
| **Impact if A (Yes)** | Tenant model needed. Inventory must be isolated per location. Cross-location transfers required. Reporting per location and consolidated. |
| **Impact if B (No)** | Simpler data model. No location isolation. Single inventory scope. |
| **Deadline** | Before Track B begins |
| **Status** | REQUIRES OWNER DECISION |

---

### DC-U005: Number of cash registers/tills

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U005 |
| **Question** | How many cash registers will operate simultaneously? |
| **Alternatives** | A) One, B) Multiple |
| **Recommendation** | None yet |
| **Impact if A (One)** | Simple treasury model. Single daily closing. |
| **Impact if B (Multiple)** | Each register needs its own till. Daily closing per register. More complex treasury model. |
| **Deadline** | Before Track B begins |
| **Status** | REQUIRES OWNER DECISION |

---

### DC-U006: Daily closing level

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U006 |
| **Question** | What level of daily cash closing is required? |
| **Alternatives** | A) Full closing with physical count, B) Summary only, C) Not required |
| **Recommendation** | None yet |
| **Impact if A (Full closing)** | Most accurate. Requires physical cash count workflow. More UI and logic. |
| **Impact if B (Summary)** | Simpler. Shows totals without physical count. Less accurate. |
| **Impact if C (Not required)** | Simplest. No closing workflow. Risk of unaccounted differences. |
| **Deadline** | Before Track B begins |
| **Status** | OWNER DECISION ADOPTED — Phase 78. IMPLEMENTATION PENDING. No hard daily close, accounting-period lock, posting lock, automatic carry-forward, irreversible close, or backdated-entry restriction shall be implemented until the implementation phase is executed. |

---

### DC-U007: Negative account balance policy

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U007 |
| **Question** | Should customer accounts be allowed to go negative (credit)? |
| **Alternatives** | A) Allow negative, B) Prevent negative, C) Allow with approval |
| **Recommendation** | C (Allow with approval) — adopted Phase 78 |
| **Impact if A (Allow)** | Customers can owe money. Requires credit limit logic. More realistic for B2B. |
| **Impact if B (Prevent)** | Sales blocked when balance is zero. Simpler. May not match real business practices. |
| **Impact if C (With approval)** | Middle ground. Owner must approve credit. Adds workflow step. |
| **Deadline** | Before Track B begins |
| **Owner decision** | Per-account Boolean `allowNegativeBalance`; owner-only toggle; owner approval required for each negative-balance operation; non-owner operations blocked when balance insufficient; owner can override with audit trail. |
| **Status** | IMPLEMENTED — Commit `af56ced`, Tag `dc-u007-windows-release-build-verified`. |

---

### DC-U008: Overpayment/collection policy

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U008 |
| **Question** | Can a customer pay more than owed? Can a supplier receive more than due? |
| **Alternatives** | A) Allow, B) Prevent, C) Allow with owner approval |
| **Recommendation** | C (Allow with owner approval) — adopted Phase 78 |
| **Impact if A (Allow)** | Overpayments create credit balances. Requires credit/refund workflow. More flexible. |
| **Impact if B (Prevent)** | Exact amounts only. Simpler but less flexible. |
| **Impact if C (With approval)** | Middle ground. Owner must approve overpayments. Adds workflow step. |
| **Deadline** | Before Track B begins |
| **Owner decision** | Owner approval per overpayment operation; recorded as customer/supplier credit or advance; no editing of original collection/payment document; refund via separate compensating entry from same account. |
| **Status** | IMPLEMENTED Core — Commit `59d689f`, Tag `dc-u008-overpayments-advances-refunds-pass`. End-User UI: OPEN. |

---

### DC-U009: iOS support

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U009 |
| **Question** | Should the mobile app support iOS in addition to Android? |
| **Alternatives** | A) Android only, B) Android + iOS |
| **Recommendation** | None yet |
| **Impact if A (Android only)** | Lower effort. Single platform to test and deploy. Matches likely client device landscape. |
| **Impact if B (Android + iOS)** | Higher effort. Two platforms. Broader reach. Cross-platform framework needed (Flutter already in use). |
| **Deadline** | Before Track H begins |
| **Status** | REQUIRES OWNER DECISION |

---

### DC-U010: Hosting provider

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U010 |
| **Question** | Which cloud provider for backend? |
| **Alternatives** | A) Supabase, B) Firebase, C) Custom backend, D) AWS/GCP |
| **Recommendation** | None yet |
| **Impact if A (Supabase)** | Already scaffolded (DC-013). PostgreSQL-based. Good for Flutter. Deferred but ready. |
| **Impact if B (Firebase)** | Already scaffolded (DC-012). Google ecosystem. Good for Flutter. May have vendor lock-in. |
| **Impact if C (Custom backend)** | Full control. Higher effort. More maintenance. No vendor lock-in. |
| **Impact if D (AWS/GCP)** | Industry standard. Wide service range. Higher complexity and cost. |
| **Deadline** | Before cloud implementation begins (DC-003) |
| **Status** | REQUIRES OWNER DECISION |

---

### DC-U011: Subscription/licensing model

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U011 |
| **Question** | How will the SaaS product be monetized? |
| **Alternatives** | A) Per-device, B) Per-tenant, C) Per-user, D) Flat rate |
| **Recommendation** | None yet |
| **Impact if A (Per-device)** | Revenue scales with usage. Simple billing. May discourage multi-device. |
| **Impact if B (Per-tenant)** | Revenue per business. Standard SaaS model. Predictable. |
| **Impact if C (Per-user)** | Revenue per employee. May discourage adding users. Complex user management. |
| **Impact if D (Flat rate)** | Simple pricing. Predictable revenue. May not scale with value. |
| **Deadline** | Deferred until cloud is built |
| **Status** | REQUIRES OWNER DECISION (deferred until cloud is built) |

---

### DC-U012: iOS support for mobile

| Field | Detail |
|-------|--------|
| **Decision ID** | DC-U012 |
| **Question** | Is iOS support needed? |
| **Alternatives** | A) Android only, B) Android + iOS |
| **Recommendation** | None yet |
| **Impact if A (Android only)** | Lower effort. Single platform. Matches likely client device landscape. |
| **Impact if B (Android + iOS)** | Higher effort. Two platforms. Broader reach. Cross-platform framework needed. |
| **Deadline** | Before Track H begins |
| **Status** | REQUIRES OWNER DECISION |

> **Note:** DC-U012 is a duplicate of DC-U009. Consider consolidating into a single decision.

---

## Phase 74 — Internal Financial Transfer Decisions

All decisions in this section are linked to Phase 74 and `ACC-011`. All have been implemented in Phase 76 (Commit merged into baseline `4d8705b`). See DC-U014 through DC-U024 below.

### DC-U013: Transfer fees

| Field | Detail |
|---|---|
| **Decision ID** | DC-U013 |
| **Question** | Does the first transfer implementation support explicit fees, and if so how are they posted? |
| **Alternatives** | A) No fees in the first implementation; B) explicit separate fee posting with its own approved accounting treatment. |
| **Recommendation** | A — avoids inventing expense, source-account, or net/gross rules before an owner decision. |
| **Impact** | Fees cannot be silently absorbed into the transfer pair. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | No transfer fees in the first release. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U014: Insufficient source balance

| Field | Detail |
|---|---|
| **Decision ID** | DC-U014 |
| **Question** | Block transfer when the source balance is insufficient, allow a negative balance, or vary by account type? |
| **Alternatives** | A) Block; B) allow negative; C) type-specific policy. |
| **Recommendation** | A for the first transfer scope; current generic entry creation permits negative balances, so this must be explicitly decided rather than assumed. |
| **Impact** | Determines transfer validation and whether a new balance guard is required. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Block a new transfer when the source account has insufficient balance. This applies to new transfers only and does not automatically change legacy financial-operation rules. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U015: Inactive accounts

| Field | Detail |
|---|---|
| **Decision ID** | DC-U015 |
| **Question** | May an inactive account be selected as transfer source or destination? |
| **Alternatives** | A) Active accounts only; B) allow selected inactive-account cases. |
| **Recommendation** | A — retain historical visibility in statements but prohibit new postings to inactive accounts. |
| **Impact** | Affects account selection and repository validation. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | New transfers use active accounts only. Inactive accounts remain visible in historical statements and records. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U016: Transfer date and backdating

| Field | Detail |
|---|---|
| **Decision ID** | DC-U016 |
| **Question** | Today only, or allow an effective date in the past? |
| **Alternatives** | A) Today only; B) allow backdating with an auditable effective date. |
| **Recommendation** | B only if the owner accepts it; current entries already have effective dates and no close lock, but no transfer policy exists. |
| **Impact** | Affects statement order and future relationship to `DC-U006`. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Allow auditable past effective dates, prohibit future dates, and retain actual creation time separately. Revisit only after `DC-U006` closing policy is decided. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U017: Cancellation and reversal

| Field | Detail |
|---|---|
| **Decision ID** | DC-U017 |
| **Question** | No cancellation in the first release, or an auditable reversal with a reason? |
| **Alternatives** | A) No cancellation; B) documented paired reversal requiring reason. |
| **Recommendation** | B, consistent with the existing non-destructive reversal direction, but implementation remains unauthorized. |
| **Impact** | Determines reversal linkage, permissions, and duplicate-reversal prevention. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Support documented paired reversal with mandatory reason. Original transfer is neither deleted nor edited; repeated reversal is prohibited. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U018: Transfer permissions

| Field | Detail |
|---|---|
| **Decision ID** | DC-U018 |
| **Question** | Who may create or reverse a transfer? |
| **Alternatives** | A) owner only; B) owner and employee; C) future dedicated permission. |
| **Recommendation** | A until a dedicated permission is deliberately designed; the current roles are only owner and employee. |
| **Impact** | Requires matching UI and repository authorization. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Owner only may create and reverse transfers in the first release. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U019: Transfer idempotency

| Field | Detail |
|---|---|
| **Decision ID** | DC-U019 |
| **Question** | Use a client request ID, a unique transfer reference, or both to protect retries? |
| **Alternatives** | A) request ID; B) reference; C) both. |
| **Recommendation** | C for a future durable implementation; no current financial-transfer idempotency convention exists. |
| **Impact** | Prevents duplicate paired movements during retry. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Use both client request ID and unique transfer reference to protect retries. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U020: Transfer numbering

| Field | Detail |
|---|---|
| **Decision ID** | DC-U020 |
| **Question** | Use a transfer-specific sequence, internal UUID plus display number, or an existing numbering scheme? |
| **Alternatives** | A) sequence; B) UUID plus display number; C) existing compatible scheme. |
| **Recommendation** | B if a display identifier is needed; current entry IDs are generated locally and no transfer document numbering exists. |
| **Impact** | Defines the shared human-facing reference. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Use stable internal UUID with a clear sequential display number. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U021: Notes and reasons

| Field | Detail |
|---|---|
| **Decision ID** | DC-U021 |
| **Question** | Are transfer notes optional, required, or selected from a reason list? |
| **Alternatives** | A) optional; B) required; C) reason list plus note. |
| **Recommendation** | A for ordinary transfers, with a mandatory reason if reversal is later approved. |
| **Impact** | Affects data validation and audit detail. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Normal transfer note is optional; a reversal reason is mandatory. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U022: Allowed account types

| Field | Detail |
|---|---|
| **Decision ID** | DC-U022 |
| **Question** | Allow all active financial accounts or restrict transfers by account type? |
| **Alternatives** | A) all active accounts; B) selected type pairs; C) prohibit same-type transfers. |
| **Recommendation** | A, subject to the inactive-account decision; the current unified model treats treasury, bank, and wallet as financial accounts. |
| **Impact** | Defines eligible source/destination combinations. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Allow all active financial accounts, including treasury, bank, wallet, and distinct accounts of the same type. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U023: Edit policy

| Field | Detail |
|---|---|
| **Decision ID** | DC-U023 |
| **Question** | Can a saved transfer be edited, or must correction be reversal plus a new transfer? |
| **Alternatives** | A) immutable after save; B) drafts only before posting; C) reversal then new transfer. |
| **Recommendation** | A/C — no silent historical edit; if a correction is needed, use an approved reversal and new transfer. |
| **Impact** | Protects audit history and statement consistency. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Saved transfer is immutable; correction is documented reversal followed by a new transfer. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

### DC-U024: Owner confirmation UX

| Field | Detail |
|---|---|
| **Decision ID** | DC-U024 |
| **Question** | Use one confirmation, a review screen, or an additional confirmation for high amounts? |
| **Alternatives** | A) one confirmation; B) review screen; C) threshold-based extra confirmation. |
| **Recommendation** | B — clear review without inventing an amount threshold. |
| **Impact** | Affects future Arabic RTL flow and error prevention. |
| **Deadline** | Before internal-transfer implementation |
| **Owner decision** | Show full review of source, destination, amount, date, note, and both balances, then one final confirmation. No large-amount threshold is adopted. |
| **Status** | IMPLEMENTED — Phase 76; Commit merged into baseline `4d8705b` |

---

## Decision Dependencies

```
DC-003 (Cloud sync)
├── DC-U010 (Hosting provider) — must decide before cloud implementation
├── DC-R002 (Command API) — must decide API strategy
├── DC-R003 (Server-authoritative) — must decide write strategy
└── DC-R004 (Client UUID) — must decide ID strategy

DC-004 (Mobile app)
├── DC-U001 (Mobile scope) — must decide before Track H
├── DC-U009 / DC-U012 (iOS support) — must decide before Track H
└── DC-U010 (Hosting provider) — mobile needs cloud backend

DC-006 (Treasury/bank/wallets)
├── DC-R001 (Unified account model) — IMPLEMENTED (Phase 71)
├── DC-U002 (Split payment) — IMPLEMENTED Core; UI OPEN
├── DC-U003 (Multi-currency) — REQUIRES OWNER DECISION
├── DC-U005 (Cash registers) — REQUIRES OWNER DECISION
├── DC-U006 (Daily closing) — REQUIRES OWNER DECISION — OPEN
├── DC-U007 (Negative balance) — IMPLEMENTED (Commit `af56ced`)
└── DC-U008 (Overpayment) — IMPLEMENTED Core; UI OPEN

DC-005 (Multi-device)
├── DC-U004 (Branch support) — must decide before Track B
└── DC-003 (Cloud sync) — multi-device requires cloud
```

---

## Phase Deadlines

| Deadline | Decisions Due |
|----------|---------------|
| Before Track B begins | DC-R001, DC-U002, DC-U003, DC-U004, DC-U005, DC-U006, DC-U008 |
| Before Track H begins | DC-U001, DC-U009, DC-U012 |
| Before cloud implementation | DC-U010, DC-R002, DC-R003, DC-R004 |
| Deferred | DC-U011 (after cloud is built) |
# Phase 8B decision

# Phase 8C decision

Adopt schema version 3 and `DriftCustomerRepository` for the production customer profile store only. Reuse `repository_sequences` with the independent `customers` namespace. Preserve customer-ID references from sales, collections, ledgers, advances/refunds, and reports without migrating those repositories or storing derived balances in `customers`. Phase 8A and 8B remain locked; Phase 8D and deployment are not started.

Adopt a Drift-backed production `ProductRepository` as the first business vertical slice, using schema version 2 and a transactional durable sequence. Preserve in-memory injection for tests. Do not migrate other repositories or begin Phase 8C.
