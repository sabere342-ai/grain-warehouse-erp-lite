# Phase 47 — Client Pilot Feedback Collection and Issue Resolution

**Date:** 2026-07-09

## Current Baseline

- **Commit:** `f30fed1`
- **Tag:** `phase-46-client-pilot-smoke-delivered-package`
- **Tested package:** `delivery/grain_warehouse_erp_lite_pilot_20260709-172154/`
- **Phase 46 recommendation:** READY FOR CLIENT PILOT

## Purpose

Phase 47 creates a structured Arabic feedback collection and issue-resolution system for the real client pilot. No production code is modified in this phase. The delivered package from Phase 45/46 remains stable and unchanged.

The goal is to:
- Provide the pilot owner with clear Arabic forms for reporting observations.
- Classify issues so the development team can triage correctly.
- Define when a Phase 47A hotfix is warranted vs. deferring to a later phase.
- Keep the pilot focused on real usage without feature creep.

## Feedback Collection Rules

1. The pilot owner tests the delivered package from `delivery/grain_warehouse_erp_lite_pilot_20260709-172154/`.
2. All observations must be recorded in the issue log before any code change.
3. No production code change is allowed without a logged issue.
4. Issues are classified by severity (P0–P4) before resolution.
5. The development team reviews logged issues and decides on action.

## What the Client Should Test During Pilot

| Area | Description |
|------|-------------|
| Login / open app | Open the app, create owner account or log in. |
| Dashboard | Check metric cards, guidance, navigation. |
| Products | Add grain products with prices and costs. |
| Suppliers | Add suppliers with names and optional phone numbers. |
| Purchases | Record purchase intake, confirm stock increase. |
| Customers | Add customers with names and optional phone numbers. |
| Sales | Record sales (cash/credit/partial) with one or more items. |
| Customer statement | View customer account, confirm debits/credits/balances. |
| Supplier statement | View supplier account, confirm entries. |
| Document history | Search and filter documents by type/date/status. |
| PDF export | Export invoices, statements, and daily report. |
| WhatsApp assisted sharing | Open WhatsApp with prepared message for valid-phone customers/suppliers. |
| Backup / restore | Create backup JSON, preview restore, understand restore-to-empty requirement. |

## What the Client Should NOT Do Without Guidance

- Perform destructive restore on real data without first creating a backup.
- Manually delete or rename files in the `Release/` or `data/` folders.
- Edit app/runtime files (EXE, DLLs, YAML, asset files).
- Share the package publicly or with other businesses (this is a single-client pilot).
- Expose internal files or source code if any are accidentally found.

## Issue Classification

| Severity | Label | Definition | Action |
|----------|-------|------------|--------|
| P0 | مانع تشغيل | App cannot open, data loss, impossible to complete sale/purchase. | Immediate Phase 47A hotfix required. |
| P1 | خطأ محاسبي | Wrong stock, wrong balance, wrong totals, wrong statement. | Immediate Phase 47A hotfix required. |
| P2 | مشكلة استخدام | Feature exists but is confusing or blocks normal use. | May be fixed if low-risk; otherwise deferred. |
| P3 | مشكلة توثيق | Documentation mismatches actual behavior. | Documentation-only update; no code change needed. |
| P4 | طلب تحسين | Useful but not required for pilot acceptance. | Deferred unless owner explicitly approves. |

## Resolution Policy

- **P0/P1:** Require immediate Phase 47A. The defect must be fixed, tested, and the delivery package rebuilt and re-verified.
- **P2:** May be fixed in Phase 47A if the fix is low-risk and does not change accounting rules. Otherwise deferred to a later phase.
- **P3:** Documentation-only update. No code change. Can be applied without a Phase 47A.
- **P4:** Deferred. Recorded for future consideration. Applied only if the pilot owner explicitly requests it and approves the scope.

## Resolution Workflow

1. Issue logged in `CLIENT-PILOT-ISSUE-LOG-AR.md` by owner or developer.
2. Developer reviews severity classification.
3. If P0/P1 → Phase 47A branch created. Fix applied with tests. Build re-run. Delivery package rebuilt.
4. If P2 → Decision made: fix now or defer.
5. If P3 → Documentation updated.
6. If P4 → Recorded and deferred.
7. After fix or doc update, issue status set to `تم الحل` and verified.

## Final Recommendation Format

After Phase 47, the recommendation shall be one of:
- **PILOT ONGOING** — No blocking issues found; pilot continues.
- **PILOT ONGOING WITH MINOR ISSUES** — Non-blocking issues logged; pilot continues while fixes are queued.
- **PILOT BLOCKED** — P0/P1 issue found; Phase 47A required before pilot can continue.
- **PILOT ACCEPTED** — Owner confirms pilot is satisfactory; ready for transition to production or delivery archive.
