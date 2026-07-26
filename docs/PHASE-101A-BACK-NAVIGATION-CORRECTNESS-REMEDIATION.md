# Phase 101A — Back Navigation Correctness Remediation

## Status

**APPROVED — COMMIT PENDING**

## Summary

Phase 101A corrects two back-navigation defects discovered in Phase 100 demo rehearsal:

1. **Double back button in DashboardShell tabs**: StockTake and StockAdjustmentReport rendered their own `GhalalPageHeader` back button while the parent `DashboardShell` also rendered `shell-back-button`, producing duplicate navigation controls.
2. **Back button hidden below fold in printable previews**: In `PrintableDocumentScaffold`, the back button was the first child inside `SingleChildScrollView`, pushing it below the initial viewport on smaller screens.

---

## Scope

- Conditional `onBack` in `StockTakeScreen` and `StockAdjustmentReportScreen` via `Navigator.of(context).canPop()`
- Relocation of back button in `PrintableDocumentScaffold` from inside scrollable area to a fixed `Column` header above `Expanded(SingleChildScrollView(...))`
- New test cases covering tab-context and push-context navigation for both inventory screens, plus back-button visibility/overflow tests for `PrintableDocumentScaffold`

## Explicitly Out of Scope

- Accounting, inventory writes, backup, DB schema changes
- Permission or role changes
- PDF/CSV export data contracts
- `Employee` / `UserAccount` models
- Any new features or phases beyond 101A

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `Navigator.of(context).canPop()` for conditional `onBack` | Follows existing pattern in `NegativeBalanceApprovalRequestsScreen`; safe in both tab and push contexts |
| `PageBackButton` with explicit `onPressed: () => Navigator.of(context).maybePop()` in `PrintableDocumentScaffold` | Ensures button is visible even when `canPop()` is false; `maybePop()` is a no-op if no route to pop |
| Remove bottom "رجوع" button from `PrintableDocumentScaffold` | Redundant with new top-level `PageBackButton`; eliminates scrolling requirement |

---

## Files Changed

### Production Code

| File | Change |
|------|--------|
| `lib/features/inventory/stock_take_screen.dart` | +2 lines: conditional `onBack` via `canPop()` |
| `lib/features/inventory/stock_adjustment_report_screen.dart` | +2 lines: conditional `onBack` via `canPop()` |
| `lib/features/prints/printable_document_scaffold.dart` | +284 lines: `PageBackButton` import, back button moved outside scroll, bottom button removed |

### Tests

| File | Tests Added |
|------|-------------|
| `test/phase49a_stock_take_test.dart` | +53 lines: 2 new tab-context back-button tests |
| `test/phase49b_stock_adjustment_report_test.dart` | +57 lines: 2 new tab-context back-button tests |
| `test/phase91_printable_document_scaffold_design_system_test.dart` | +109 lines: 4 new back-button-positioning tests |

---

## Verification Gates

### Gate 1 — Analyzer Baseline

Baseline at `cc8700d`: **31 issues** (30 info + 1 warning)
Modified state: **31 issues** (0 new issues introduced)

### Gate 2 — Full Test Suite

```
flutter test → 1814 passed, 1 skipped
```

### Gate 3 — Windows Build

```
flutter build windows --release → grain_warehouse_erp_lite.exe (784,384 bytes)
```

### Gate 4 — Format & Whitespace

```
dart format --set-exit-if-changed <6 files> → 0 changes
git diff --check → CRLF warnings only (expected)
```

---

## Manual Behavior Review

| # | Scenario | Expected | Result |
|---|----------|----------|--------|
| 1 | StockTake in DashboardShell tab (tab index != 0) | Own back button hidden; `shell-back-button` handles navigation | ✅ |
| 2 | StockTake pushed from Inventory screen | Own back button visible; `maybePop()` pops the push route | ✅ |
| 3 | StockAdjustmentReport in DashboardShell tab (tab index != 0) | Own back button hidden; `shell-back-button` handles navigation | ✅ |
| 4 | StockAdjustmentReport pushed from Inventory screen | Own back button visible; `maybePop()` pops the push route | ✅ |
| 5 | PrintableDocumentScaffold preview (360x720 viewport) | Back button visible in first viewport without scrolling | ✅ |

---

## Git Evidence

| Item | Value |
|------|-------|
| Commit | Pending |
| Tag | `phase-101a-back-navigation-correctness-remediation` |
| Tag type | Annotated |
| Branch | `phase-100-genuine-client-demo-execution-acceptance-evidence` |
| Push | **NOT performed** — requires owner authorization |

---

*Created: 2026-07-26*
