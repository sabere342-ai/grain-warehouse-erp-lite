# Phase 36G — Pilot UI Clarity & Cancellation Safety Polish

## Purpose

Phase 36G improves clarity and safety of the visible pilot UI based on
observations from pilot recordings. It does not change the core accounting
model, add new features, or weaken existing accounting safety.

## Changes

### 1. Purchase cancellation UI clarity

**Problem**: A purchase with supplier payment activity showed a normal-looking
"إلغاء مستند الاستلام" button, inviting an unsafe action even though the
backend blocks it.

**Fix**: When a purchase's supplier has any recorded payments:
- The cancel button is replaced with a disabled button showing:
  "لا يمكن الإلغاء بعد تسجيل دفعة للمورد"
- A tooltip explains:
  "للحفاظ على الحسابات، لا يتم إلغاء شراء تم تسجيل دفعة عليه."
- If a purchase has no supplier payments, the existing cancel flow remains
  unchanged.
- Backend cancellation safety (`reversePurchaseEntry`) remains unchanged.

**Files**:
- `lib/features/purchases/purchases_screen.dart` — loads `listPayments()`,
  passes `hasPayment` to card, renders disabled button.

### 2. Reports label clarity

**Problem**: Report "صافي الحركة" caption said "مبيعات ناقص مشتريات", which
could confuse document movement with actual cash. Customer and supplier balance
labels lacked clear owner-facing descriptions.

**Fix**:
- Summary card title: "صافي حركة المستندات" (was "صافي الحركة")
- Summary card caption: "إجمالي المبيعات ناقص إجمالي المشتريات، وليس رصيد
  النقدية." (was "مبيعات ناقص مشتريات")
- Customer receivables card caption: "مبالغ لنا عند العملاء."
- Supplier payables card caption: "مبالغ علينا للموردين."
- Customer section helper: "مبالغ لنا عند العملاء. التحصيلات تقلل مديونية
  العملاء فقط ولا تُحسب كمبيعات أو ربح جديد."
- Supplier section helper: "مبالغ علينا للموردين. المدفوعات للموردين تقلل
  الرصيد المستحق فقط ولا تُحسب كمصروفات."

**Files**:
- `lib/features/reports/reports_screen.dart` — updated summary card captions
  and section helpers.

### 3. Dashboard helper clarity

**Problem**: "رصيد النقدية" card had no explanation of how the value was
calculated.

**Fix**: Added subtitle to the cash balance card:
"محسوب من النقد الداخل ناقص المصروفات ومدفوعات الموردين."

**Files**:
- `lib/features/dashboard/dashboard_screen.dart` — added subtitle.

### 4. Supplier statement owner-facing explanations

**Problem**: Statement used accounting terms "مدين / دائن / الرصيد" without
context for a non-technical owner.

**Fix**:
- Added explanation text above the statement lines:
  "المشتريات تزيد المبلغ المستحق للمورد، والدفعات تقلله."
- Changed line labels from "مدين / دائن / الرصيد" to:
  "مشتريات" / "دفعة للمورد" / "المتبقي"

**Files**:
- `lib/features/supplier_accounts/supplier_statement_screen.dart` — added
  explanation, updated line labels.

### 5. Customer statement owner-facing explanations

**Problem**: Customer statement had no explanation of how the balance is
affected by credit sales and collections.

**Fix**: Added explanation text:
"البيع الآجل يزيد رصيد العميل المستحق، والتحصيل يقلله."

**Files**:
- `lib/features/customers/customers_screen.dart` — added explanation in
  `_CustomerStatementScreen`.

## Tests

- **Existing tests remain green** — no numeric values or business logic changed.
- New tests in `test/phase36g_ui_clarity_cancellation_safety_test.dart`:
  - Purchase card shows disabled cancel message after payment.
  - Purchase card shows normal cancel button without payment.
  - Backend still rejects cancellation of paid purchase.
  - Stock and supplier balance unchanged after rejected cancellation.
  - Reports screen contains clarified labels.
  - Supplier statement contains explanation text and updated labels.
  - Customer statement contains explanation text.
  - Dashboard cash card shows subtitle.
  - Existing report tests remain green (no numeric changes).

## Quality gates

- `flutter analyze --no-pub`: info only, no errors/warnings.
- `flutter test`: all tests passed.
- `flutter build windows --release`: succeeded.
- `git diff --check`: no whitespace errors.

## What Phase 36G does NOT do

- Does not open Phase 37.
- Does not add new accounting features.
- Does not add supplier advances or `paidNowQirsh`.
- Does not add per-purchase payment allocation.
- Does not weaken purchase cancellation safety.
- Does not hide pages to bypass issues.
- Does not change any business logic or accounting rules.

## Commit

- Branch: `master`
- Commit hash: (to be filled after commit)
- Tag: `phase-36g-pilot-ui-clarity-cancellation-safety-polish`
