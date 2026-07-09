# Phase 49 — Controlled Post-Acceptance Feature Intake and Impact Audit

**Date:** 2026-07-09

## Baseline

- **Commit:** `025d644`
- **Tag:** `phase-48-final-client-delivery-archive`
- **Accepted final package:** `delivery/grain_warehouse_erp_lite_final_client_delivery_20260709-175124/`
- **Pilot status:** ACCEPTED — READY FOR FINAL CLIENT HANDOFF

## Requested Feature

**No explicit feature request was provided.** This audit creates a controlled post-acceptance backlog and recommends the safest next feature for Phase 49A.

## Post-Acceptance Backlog

All items below are derived from known limitations in `docs/DEVELOPER-HANDOFF-NOTES.md`, gaps found during Phase 46–48 smoke testing, and the deferred roadmap items.

### HIGH Priority

| # | Feature | Classification | Risk Level | Why |
|---|---------|---------------|------------|-----|
| H1 | Stock-taking / جرد workflow | Workflow feature | LOW | UI wrapper on existing manual movements; no data model change; backup-compatible. |
| H2 | Expense edit and delete | Workflow / accounting | MEDIUM | Edits affect historical reports; needs audit trail and permission gating. |
| H3 | Physical printer support | Document/export | LOW | No accounting impact; pure output enhancement. |
| H4 | Monthly / periodic financial reports | Reporting | MEDIUM | New calculation over existing data; no model change if report-only. |

### MEDIUM Priority

| # | Feature | Classification | Risk Level | Why |
|---|---------|---------------|------------|-----|
| M1 | Employee/user management screen | UX/help | MEDIUM | Changes auth model; needs password management, role creation UI. |
| M2 | Expense categories (predefined) | Workflow | LOW | Free-text → dropdown; no accounting change. |
| M3 | Expense printable/PDF view | Document/export | LOW | No accounting impact; new print view only. |
| M4 | Stock adjustment variance report | Reporting | LOW | Comparison only; no data writes. |
| M5 | Bank account / e-wallet tracking | Accounting | HIGH | New account model; debit/credit impact; backup schema change. |

### LOW Priority

| # | Feature | Classification | Risk Level | Why |
|---|---------|---------------|------------|-----|
| L1 | Eastern Arabic numeral formatting | UX/help | NONE | Pure display change; no data impact. |
| L2 | Excel/CSV export | Document/export | LOW | Additional export format; no model change. |
| L3 | Net profit in daily report (gross − expenses) | Reporting | LOW | Read-only calculation addition. |
| L4 | Dead code cleanup (PlaceholderFeatureScreen) | Delivery/security | NONE | Remove unused file; no behavior change. |

## Recommended Safest Next Feature

### Feature: Stock-Taking Workflow (جرد المخزون)

**Classification:** Workflow feature

**Business goal:** Provide a dedicated stock-taking screen where the owner can record physical counts per product and let the system calculate variance from the system balance, then apply adjustments in bulk.

**Why this is the safest next feature:**
- Uses only existing `manualDecrease` / `manualIncrease` movement types internally — no new movement type.
- Does not change any existing data models or repositories.
- Does not affect backup/restore schema (v2 remains compatible).
- Does not change sales, purchases, expenses, or payment logic.
- Does not affect customer/supplier statements or balances.
- Does not affect PDF export or WhatsApp sharing.
- Does not affect existing document history.
- Clear business value for any grain warehouse (periodic physical inventory is mandatory).

### Affected Screens

| Screen | Change |
|--------|--------|
| `lib/features/inventory/inventory_screen.dart` | Add entry point / button for stock-taking. No existing behavior changed. |
| New: `lib/features/inventory/stock_take_screen.dart` | New screen for physical count entry and variance display. |

### Affected Data / Repositories

| Repository | Change |
|------------|--------|
| `lib/core/inventory/inventory_repository.dart` | No change. Uses existing `addMovement` with `manualDecrease`/`manualIncrease`. |
| `lib/core/inventory/inventory_controller.dart` | No change. Existing methods sufficient. |
| `lib/core/inventory/stock_movement.dart` | No change. Uses existing `StockMovementType.manualDecrease` and `manualIncrease`. |

### Accounting Impact

**None.** Stock-taking adjusts inventory quantity only. It uses the same manual movement types already available. No monetary values are changed. No customer/supplier balances are affected. No invoices are changed.

### Backup/Restore Impact

**None.** Stock movements are already serialized in backup v2 schema. No schema change needed.

### Document History Impact

**None.** Existing document history tracks stock movements already. No new document type needed.

### PDF/WhatsApp Impact

**None.** No new printable view or WhatsApp sharing is proposed. The existing daily report PDF already reflects adjusted stock balances.

### Risks

- User could misuse stock-taking to zero out legitimate inventory discrepancies without investigation.
- **Mitigation:** The stock-taking screen will show variance clearly before applying adjustments. Each adjustment creates an individual movement record with a reason reference to the stock-take ID.

### Required Tests

- Stock-take screen renders with product list and system balances.
- User can enter physical counts.
- Variance is calculated correctly (system − physical).
- Applying adjustments creates correct manual movements.
- Zero-variance products are skipped or logged.
- Cancel/back does not apply any changes.
- Permission-gated: owner only (consistent with inventory management).

### Required Documentation Updates

- `docs/OWNER-QUICK-START-AR.md`: Add section explaining stock-taking workflow.
- `docs/PILOT-RELEASE-NOTES-AR.md`: Add stock-taking to feature list.
- `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md`: Add stock-taking checklist items.

## Second-Safest Feature (Alternative)

### Feature: Eastern Arabic Numeral Formatting (أرقام شرقية)

If the stock-taking workflow is considered too large, this is the absolute lowest-risk enhancement:

- Pure display change in `lib/core/money/money_utils.dart` and `lib/core/weight/weight_utils.dart`.
- Add an option in settings to switch between Western (0-9) and Eastern (٠-٩) numerals.
- Zero accounting risk. No data model changes. No backup impact.
- However, low business value — the existing Western numerals are acceptable.

## Decision

**Proceed to Phase 49A — Stock-Taking Workflow (جرد المخزون)**

Rationale:
- Safest next feature (lowest risk-to-value ratio).
- No accounting impact.
- No data model or backup schema change.
- High business value for a grain warehouse.
- Can be implemented as a pure UI addition on top of existing repositories.

If the stock-taking feature is considered too large for a single phase, split into:
- Phase 49A: Stock-taking UI and core workflow.
- Phase 49B: Stock-taking variance report and printable view.

---

**Deferred features** (to be evaluated after Phase 49A):
- Expense edit/delete (needs audit trail design)
- Physical printer support (needs SDK evaluation)
- Monthly financial reports (needs P&L design)
