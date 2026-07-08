# Phase 37C — Reports Truthfulness: Cash Flow & Daily Cash Reconciliation

## Purpose

Phase 37C fixes dashboard card labels and calculations so every visible number is truthful and nothing mixes cash sales, credit sales, collections, supplier payments, expenses, or opening balances. It also adds a dedicated daily cash flow section to the daily report.

## What was fixed

### 37C.1 — Dashboard cards clarified

| Before | After |
|---|---|
| "مبيعات اليوم" (no breakdown) | "مبيعات اليوم" with subtitle showing cash/credit split |
| "رصيد النقدية" (ambiguous) | "رصيد النقدية التراكمي" with longer explanation |
| No "نقد داخل اليوم" card | New card showing cash sales + collections with breakdown |
| No "المستحق على العملاء" card | New card showing all-time customer receivables (positive balances only) |
| No "المستحق للموردين" card | New card showing all-time supplier payables (positive balances only) |

Total cards: 4 → 7 (within reasonable density per the "لا تجعل الداشبورد مزدحمًا" constraint).

### 37C.2 — DashboardData model additions (`dashboard_service.dart`)

New fields:
- `todayCollectionsQirsh` — customer collections filtered to today's date
- `todaySupplierPaymentsQirsh` — supplier payments filtered to today's date
- `todayExpensesQirsh` — expenses filtered to today's date
- `customerReceivablesQirsh` — positive customer balances only (all-time)
- `supplierPayablesQirsh` — positive supplier balances only (all-time)

New computed getters:
- `todayCashInQirsh` = `todayCashSalesQirsh + todayCollectionsQirsh`
- `todayCashOutQirsh` = `todaySupplierPaymentsQirsh + todayExpensesQirsh`
- `todayNetCashQirsh` = `todayCashInQirsh - todayCashOutQirsh`

The existing `cashBalanceQirsh` (all-time cash position) is preserved and relabeled as "رصيد النقدية التراكمي" with a full explanation.

### 37C.3 — DailyActivityReport cash flow getters (`daily_activity_report.dart`)

New computed getters:
- `cashSalesAmountQirsh` = `totalSalesAmountQirsh - totalCreditSalesAmountQirsh`
- `cashInQirsh` = `cashSalesAmountQirsh + totalCollectionsAmountQirsh`
- `cashOutQirsh` = `totalSupplierPaymentsQirsh + totalExpenseAmountQirsh`
- `netCashQirsh` = `cashInQirsh - cashOutQirsh`

### 37C.4 — Report cash flow section (`reports_screen.dart`)

New "حركة النقد اليوم" section under the report body showing:
- نقد داخل اليوم (cash sales + collections)
- مبيعات نقدية
- تحصيلات من العملاء
- نقد خارج اليوم (supplier payments + expenses)
- مدفوعات الموردين
- مصروفات
- صافي حركة النقد اليوم

Summary grid adds 3 new cards:
- "نقد داخل اليوم" — caption: "مبيعات نقدية + تحصيلات"
- "نقد خارج اليوم" — caption: "مدفوعات موردين + مصروفات"
- "صافي حركة النقد" — caption: "نقد داخل ناقص نقد خارج"

The existing "صافي حركة المستندات" caption is shortened but still disclaims it is not cash balance.

### 37C.5 — Key accounting rules enforced

- `todayCollectionsQirsh` filters by collection **date**, not creation timestamp — same approach as the report repository.
- `todaySupplierPaymentsQirsh` filters by payment **date**.
- `todayExpensesQirsh` filters by expense **date**.
- `customerReceivablesQirsh` sums **positive** balances only (negative = we owe the customer, excluded).
- `supplierPayablesQirsh` sums **positive** balances only.
- No schema changes → backup version stays at v2.

## Files changed

| File | Change |
|---|---|
| `lib/core/dashboard/dashboard_service.dart` | DashboardData: 5 new fields + 3 getters. Service load: 6 new computations |
| `lib/core/reports/daily_activity_report.dart` | 4 new cash flow getters |
| `lib/features/dashboard/dashboard_screen.dart` | 3 new metric cards, relabeled cash balance card, subtitles on all cards |
| `lib/features/reports/reports_screen.dart` | New cash flow section (8 metric lines), 3 new summary cards, updated captions |
| `test/phase36g_ui_clarity_cancellation_safety_test.dart` | Updated subtitle assertion for renamed cash balance card |
| `test/phase37c_dashboard_labels_test.dart` | New file: 14 tests |

## Test coverage (14 new)

- DashboardData model: empty defaults, getter arithmetic
- DashboardService: today collections/payments/expenses date filtering, customer/supplier positive-only balances, out-of-range exclusion
- DailyActivityReport: all 4 cash flow getters
- Dashboard UI: all 7 cards appear
- Report UI: cash flow section labels appear

## Quality gates

- `flutter analyze --no-pub`: 0 errors, 0 warnings
- `flutter test`: 335/335 passed (321 + 14 new)
- `flutter build windows --release`: successful
- `git diff --check`: clean
