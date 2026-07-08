# Phase 36D — Pilot Delivery Refresh After Supplier Accounts

> **Superseded by Phase 36E.** The Phase 36E delivery package includes the
> supplier payment UI completion (buttons, dialogs, balance display, reports).
> Use the Phase 36E delivery package instead.

## Purpose

Phase 36D is a delivery refresh only. It does not add new accounting features.
It prepares a corrected pilot delivery package based on the Phase 36 codebase
(commit `521d54f`, tag `phase-36-supplier-accounts-dashboard-live-data`).

## Why a refresh is needed

The Phase 35 delivery package (`delivery/grain_warehouse_erp_lite_pilot_20260708-020333`)
was based on commit `e4699ec`. After that delivery was built, two critical pilot blockers
were discovered from screen recording of the pilot environment:

1. **Dashboard/Home showed fake data** — the metrics (today sales, cash balance, stock)
   were hardcoded placeholders, not connected to live repository data.
2. **Suppliers had no functional connection** — purchases existed but were not linked to
   supplier accounts. There was no supplier ledger, no supplier payment, no statement,
   and cancellation safety did not account for supplier payments.

Phase 36 (three sub-phases) fixed both blockers:

- **Phase 36A**: Dashboard now reads live data from SaleRepository, InventoryRepository,
  ProductRepository, ExpenseRepository, CustomerAccountRepository, and SupplierAccountRepository.
- **Phase 36B**: Purchase intakes capture supplier name/phone/address snapshots.
  Purchases are linked to their supplier. Backup/restore includes snapshot fields.
- **Phase 36C**: Full supplier accounts ledger — entries, payments, statements,
  cancellation safety (prevents cancelling a paid purchase), cash balance integration
  (supplier payments reduce dashboard cash), backup/restore/wipe integration.

## What Phase 36D changes

| Area | Change |
|------|--------|
| Documentation | Supersedes the Phase 35 delivery. All references updated to point to Phase 36. |
| Acceptance checklist | Expanded to include supplier account steps and dashboard verification. |
| Delivery README | Updated to reflect supplier accounts are now included. |
| Delivery package | Freshly built from `521d54f` with verified release binary. |

## What Phase 36D does NOT change

- No new accounting feature (no advances, no bank, no multi-client, no cloud).
- No changes to supplier account logic, cancellation safety, or dashboard data flow.
- No weakening of existing tests or safety checks.

## Verification

- `flutter analyze --no-pub` — clean
- `flutter test` — 282/282 pass
- `flutter build windows --release` — successful
- `git diff --check` — no whitespace errors
- Delivery safety check — source code excluded

## Supersedes

Previous delivery:
- `delivery/grain_warehouse_erp_lite_pilot_20260708-020333` (Phase 35A)
- Commit `e4699ec` tagged `phase-35a-full-test-suite-cleanup`

Current delivery:
- Commit `521d54f` tagged `phase-36-supplier-accounts-dashboard-live-data`
- This Phase 36D refresh
