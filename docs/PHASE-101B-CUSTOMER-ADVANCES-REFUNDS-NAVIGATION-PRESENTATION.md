# Phase 101B — Customer Advances & Refunds Navigation and Presentation Consistency Remediation

## 1. Baseline

| Item | Value |
|------|-------|
| Starting branch | `phase-100-genuine-client-demo-execution-acceptance-evidence` |
| Starting full HEAD | `6a7d86649d31738e5de0aa345c500a9d21d3cd09` |
| Starting tag | `phase-101a-back-navigation-correctness-remediation` |
| Starting working tree | clean |
| Phase 101B branch | `phase-101b-customer-advances-refunds-navigation-presentation` |

## 2. Audit Scope

### Screens Under Audit

1. **`CustomerAdvanceActionsScreen`** — `lib/features/customers/customer_advance_actions_screen.dart`
   - Pushed route from `CustomersScreen._showAdvances()`
   - Tab/Push: Push via `Navigator.of(context).push(MaterialPageRoute(...))`
   - Uses `GhalalPageHeader` with `onBack`
   - Uses `GhalalLoadingState`, `GhalalErrorState`, `GhalalEmptyState`

2. **`AdvancesAndRefundsReportScreen`** — `lib/features/financial_reports/advances_and_refunds_report_screen.dart`
   - Pushed route from `FinancialReportsScreen._navigate()`
   - Tab/Push: Push via `Navigator.of(context).push(MaterialPageRoute(...))`
   - Uses `GhalalPageHeader` with `onBack`
   - Uses `GhalalLoadingState`, `GhalalErrorState`, `GhalalEmptyState`

3. **`SupplierAdvanceActionsScreen`** — `lib/features/suppliers/supplier_advance_actions_screen.dart`
   - Identical structural pattern to CustomerAdvanceActionsScreen
   - Outside strict Phase 101B scope but documented as known similar defect

### Entry Points

| Screen | Opened From | Method |
|--------|------------|--------|
| `CustomerAdvanceActionsScreen` | `CustomersScreen._showAdvances()` | `Navigator.push(MaterialPageRoute)` |
| `AdvancesAndRefundsReportScreen` | `FinancialReportsScreen._navigate()` | `Navigator.push(MaterialPageRoute)` |

## 3. Navigation Matrix

| Context | Page Back | Shell Back | Result |
|---------|-----------|------------|--------|
| `CustomerAdvanceActionsScreen` (pushed) | `GhalalPageHeader.onBack` → `maybePop()` | N/A | Back pops to CustomersScreen |
| `CustomerAdvanceActionsScreen` (in DashboardShell) | Same | `shell-back-button` → returns to Home | Both visible; Shell back returns to Home |
| `AdvancesAndRefundsReportScreen` (pushed) | `GhalalPageHeader.onBack` → `maybePop()` | N/A | Back pops to FinancialReportsScreen |

## 4. Root Causes

### Defect 1 — Customer Advance Actions Screen: Back button missing in loading/error/empty states

**Reproduction:**
1. Open Customers screen
2. Tap a customer → open advances
3. While loading (or on error/empty), the back button is NOT visible

**Root Cause:**
`GhalalPageHeader` was placed INSIDE the `ListView` children (line 147 of original). When `_isLoading` is true, `_errorMessage` is non-null, or `_advances` is empty, the `_buildBody()` method returns early without entering the `ListView` branch. Therefore `GhalalPageHeader` (and its back button) is never rendered.

**Impact:**
- User cannot navigate back during loading state
- User cannot navigate back on error state
- User cannot navigate back on empty state
- User is effectively stuck until data loads successfully

**Fix:**
Moved `GhalalPageHeader` outside the `ListView` into a `Column` wrapper. The header is now rendered in ALL states (loading, error, empty, data). The content is placed in an `Expanded` widget below the header.

### AdvancesAndRefundsReportScreen — No Defect Found

The `GhalalPageHeader` in this screen is already placed OUTSIDE the conditional content blocks. It is always visible in loading, error, empty, and data states. No fix required.

## 5. Changes

| File | Change | Lines |
|------|--------|-------|
| `lib/features/customers/customer_advance_actions_screen.dart` | Extracted `GhalalPageHeader` from `ListView` to a `Column` wrapper; extracted content into `_buildContent()` | +17, -7 |
| `test/phase101b_customer_advances_navigation_test.dart` | New test file with 17 tests covering back button visibility in all states, navigation preservation, viewport safety, RTL, no financial writes | New |

## 6. Presentation Review

- **RTL**: Preserved (`Directionality(textDirection: TextDirection.rtl)` in build)
- **Theme**: Uses `GhalalPageHeader` which uses `theme.colorScheme.primary` for icon, `theme.textTheme.headlineMedium` for title
- **Dark Mode**: No hardcoded colors; all colors derived from theme
- **First viewport**: Back button visible at 360x720 and 640x480
- **Empty/Error/Denied states**: Back button now preserved in all states
- **No mixed language**: All labels Arabic
- **Consistent padding**: Header padded at `EdgeInsets.fromLTRB(16, 16, 16, 0)`

## 7. Financial and Permission Safety

Confirmed unchanged:
- ✅ Advances calculation
- ✅ Refund calculation
- ✅ Ledger directions
- ✅ Customer balances
- ✅ Financial account balances
- ✅ Payment methods
- ✅ Permission contracts
- ✅ Domain services
- ✅ Backup/Restore
- ✅ Schema
- ✅ No mutations on navigation or back press
- ✅ No financial writes during loading/error/empty states

## 8. Tests

### New Tests (Phase 101B) — 17 tests

| # | Test | Status |
|---|------|--------|
| 1 | back button visible during loading state | ✅ passed |
| 2 | back button visible during error state | ✅ passed |
| 3 | back button visible during empty state | ✅ passed |
| 4 | back button visible when data is loaded | ✅ passed |
| 5 | only one back button control exists in any state | ✅ passed |
| 6 | tapping back button pops the pushed route | ✅ passed |
| 7 | tapping back does not invoke any financial write | ✅ passed |
| 8 | back button is visible in first viewport at 360x720 | ✅ passed |
| 9 | back button visible in first viewport at 640x480 | ✅ passed |
| 10 | no overflow on compact viewport | ✅ passed |
| 11 | RTL layout is preserved | ✅ passed |
| 12 | empty state preserves navigation | ✅ passed |
| 13 | error state preserves navigation | ✅ passed |
| 14 | loading state preserves navigation | ✅ passed |
| 15 | header title shows customer name in all states | ✅ passed |
| 16 | header title persists across retry from error to data | ✅ passed |
| 17 | advance data rows remain unchanged | ✅ passed |

### Focused Regression

| File | Passed | Skipped | Exit Code |
|------|--------|---------|-----------|
| `phase101b_customer_advances_navigation_test.dart` | 17 | 0 | 0 |
| `phase92_legacy_appbar_holdouts_design_system_test.dart` | 20 | 0 | 0 |
| `phase83_shell_navigation_responsive_test.dart` | 6 | 0 | 0 |
| `phase4_customer_advance_actions_ui_test.dart` | 27 | 0 | 0 |
| `advances_and_refunds_report_screen_test.dart` | 3 | 0 | 0 |
| `phase90_push_route_screens_design_system_test.dart` | 6 | 0 | 0 |

### Full Suite

| Metric | Value |
|--------|-------|
| Passed | 1831 |
| Skipped | 1 |
| Failed | 0 |
| Exit Code | 0 |

## 9. Analyzer Comparison

| Metric | Value |
|--------|-------|
| Baseline (Phase 101A) issues | 31 |
| Modified (Phase 101B) issues | 0 |
| New issues introduced | 0 |

## 10. Format & Whitespace

- `dart format`: 0 files need format
- `git diff --check`: CRLF warnings only (pre-existing, not new)

## 11. Windows Release Build

| Item | Value |
|------|-------|
| Result | PASS |
| EXE path | `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| Size | 784,384 bytes |
| Build time | 68.9s |

## 12. Manual Scenario Review

### Scenario 1 — Push from Customers

- Open customer advances via push
- Back button visible immediately
- Tap back → returns to CustomersScreen once
- No duplicate back buttons
- No financial mutations

### Scenario 2 — Loading State

- Open customer advances
- During loading, back button visible in header
- Tap back → returns to previous screen
- No data loaded, no mutations

### Scenario 3 — Error State

- Force error load
- Back button visible in header
- Error state displayed below header
- Tap back → returns to previous screen
- Retry button works; header persists

### Scenario 4 — Empty State

- Open customer with no advances
- Back button visible in header
- Empty state displayed below header
- Tap back → returns to previous screen

### Scenario 5 — Long Content

- Multiple advances create scrollable list
- Header stays at top outside scroll
- Back button always visible
- No overflow on 360x720

## 13. Git Closure

### Pre-Commit State

| Item | Value |
|------|-------|
| Branch | `phase-101b-customer-advances-refunds-navigation-presentation` |
| Modified files | `lib/features/customers/customer_advance_actions_screen.dart` |
| New files | `test/phase101b_customer_advances_navigation_test.dart` |

### Commit

```
Phase 101B: fix customer advances and refunds navigation
```

### Tag

```
phase-101b-customer-advances-refunds-navigation-presentation
```

### Push Status

`PUSH NOT PERFORMED — OWNER AUTHORIZATION REQUIRED`

## 14. Known Similar Defect (Out of Scope)

`SupplierAdvanceActionsScreen` has the identical structural defect — `GhalalPageHeader` is inside the `ListView`. This is noted but NOT fixed in Phase 101B because the supplier screen is outside the strict scope of this phase. It should be addressed in a future phase with proper scope declaration.
