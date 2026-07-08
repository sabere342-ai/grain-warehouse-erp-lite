# Phase 36H — Delivery Refresh After UI Clarity Polish

## Purpose

Phase 36H is a delivery refresh only. It does not add new accounting features or business logic.
It prepares the updated pilot delivery package based on the Phase 36G codebase
(commit `944c6f3`, tag `phase-36g-analyze-cleanup`).

## Why a refresh is needed

- Phase 36G improved pilot UI clarity (dashboard subtitle, report labels, statement explanations, cancellation safety UI).
- Phase 36G analyze cleanup eliminated all warnings.
- Phase 36F delivery is now superseded.
- The current delivery must be based on `944c6f3` or newer.

## What changed from Phase 36F to Phase 36G (functional baseline)

- **Dashboard cash subtitle**: "محسوب من النقد الداخل ناقص المصروفات ومدفوعات الموردين." explains cash balance formula.
- **Report labels**: summary card → "صافي حركة المستندات" with caption distinguishing it from cash balance.
- **Customer receivables card**: caption "مبالغ لنا عند العملاء." with explanation that collections reduce receivable.
- **Supplier payables card**: caption "مبالغ علينا للموردين." with explanation that payments reduce payable.
- **Supplier statement**: uses "مشتريات / دفعة للمورد / المتبقي" labels with explanation text.
- **Customer statement**: shows explanation that credit sales increase balance, collections decrease it.
- **Purchase cancellation UI**: purchase with supplier payment shows disabled button with clear Arabic message "لا يمكن الإلغاء بعد تسجيل دفعة للمورد".
- **Dashboard overflow fix**: `_MetricCard` subtitle max lines + ellipsis to prevent RenderFlex overflow.
- **Analyze cleanup**: 0 warnings, 0 errors (25 pre-existing info-only hints).

## What Phase 36H does

- Refreshes the delivery package with the Phase 36G build.
- Updates Arabic owner acceptance checklist to cover Phase 36G clarity items.
- Updates handoff documentation.
- Verifies delivery package contains no source code.
- Provides manual pilot QA scenario documentation.

## What Phase 36H does NOT do

- Does not open Phase 37.
- Does not add supplier advances or `paidNowQirsh`.
- Does not add per-purchase payment allocation.
- Does not weaken purchase cancellation safety.
- Does not hide supplier/payment/report/dashboard UI.
- Does not expose source code in delivery package.

## Delivery package

- Tool: `tool/create_pilot_delivery_package.ps1`
- Generated path: `delivery/grain_warehouse_erp_lite_pilot_20260708-163949/`
- Verified with `tool/check_pilot_delivery_package.ps1`.

## Quality gates

- `flutter analyze --no-pub`: 0 errors, 0 warnings, 25 info-only (all pre-existing).
- `flutter test`: 300/300 passed.
- `flutter build windows --release`: succeeded.
- `git diff --check`: no whitespace errors.

## Delivery safety

Source code safety check passed. The delivery package contains only:
- `Release/` (compiled Windows binary and runtime DLLs)
- `docs/` (owner-facing documentation)
- `README-AR.txt` (Arabic startup instructions)

The delivery package does NOT contain:
- `.git/`
- `lib/`
- `test/`
- `tool/`
- `android/`
- `windows/`
- Build source intermediates
- `.dart` files
- `.ps1` files
- Developer-only docs

## Manual QA scenario

See `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md` for the full Arabic owner acceptance checklist.
The following key scenarios were verified:

### A. Dashboard
- Cash sale recorded.
- Home dashboard shows increased today sales and cash balance.
- Cash balance subtitle shows calculation formula.
- Stock decreased after sale.

### B. Supplier
- Supplier created.
- Credit purchase linked to supplier recorded.
- Supplier card shows "له علينا: X ج.م".
- Supplier payment registered from card or statement.
- Supplier balance decreases.
- Supplier statement shows payment with "دفعة للمورد" label and explanation text.

### C. Cancellation safety
- Purchase with supplier payment shows disabled cancel button with clear Arabic explanation.
- Backend blocks cancellation if supplier payments exist.
- Stock and supplier balance remain uncorrupted.

### D. Reports
- Reports distinguish "صافي حركة المستندات" from cash balance.
- Customer and supplier sections show separate receivables/payables with explanatory captions.

### E. Customer statement
- Customer statement shows explanation that credit sales increase balance, collections decrease it.

### F. Delivery safety
- No source code files found in delivery folder.

## Commit

- Branch: `master`
- Tag: `phase-36h-delivery-refresh-after-ui-clarity-polish`
