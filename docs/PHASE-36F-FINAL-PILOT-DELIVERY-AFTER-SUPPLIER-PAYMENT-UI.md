# Phase 36F — Final Pilot Delivery After Supplier Payment UI

## Purpose

Phase 36F is a delivery refresh only. It does not add new accounting features or business logic.
It prepares the final corrected pilot delivery package based on the Phase 36E codebase
(commit `dd94b4f`, tag `phase-36e-supplier-payment-ui-completion`).

## Why a refresh is needed

- Phase 36E completed the visible supplier payment workflow that was required for pilot testing.
- Phase 36D delivery is now superseded.
- The current delivery must be based on Phase 36E or newer.

## What changed from Phase 36D to Phase 36E (functional baseline)

- Dashboard live data is computed from real repositories (Phase 36A).
- Supplier purchase link stores supplier snapshot fields on each purchase (Phase 36B).
- Supplier accounts ledger with purchase posting, payment validation, cancellation safety (Phase 36C).
- Supplier card balance display: "له علينا: X ج.م" or "لا يوجد رصيد مستحق".
- Supplier payment button ("تسجيل دفعة") on supplier cards and supplier statement screen.
- Supplier payment dialog with amount validation (cannot exceed balance).
- Purchase list shows outstanding supplier balance.
- Reports include supplier payments section and summary cards.
- Dashboard cash balance includes supplier payments as cash outflow.
- Audit log for supplier payments.
- Full test suite: 294/294 green.
- Windows release build succeeds.

## What Phase 36F does

- Refreshes the delivery package with the Phase 36E build.
- Updates Arabic owner acceptance checklist to cover supplier payment flows.
- Updates handoff documentation.
- Verifies delivery package contains no source code.
- Provides manual pilot QA scenario documentation.

## What Phase 36F does NOT do

- Does not open Phase 37.
- Does not add supplier advances or `paidNowQirsh`.
- Does not add per-purchase payment allocation.
- Does not weaken purchase cancellation safety.
- Does not hide supplier/payment/report/dashboard UI.
- Does not expose source code in delivery package.

## Delivery package

- Tool: `tool/create_pilot_delivery_package.ps1`
- Generated path: see delivery folder with timestamp suffix.
- Verified with `tool/check_pilot_delivery_package.ps1`.

## Quality gates

- `flutter analyze --no-pub`: info only, no errors/warnings.
- `flutter test`: 294/294 passed.
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

### A. Dashboard sales
- Cash sale recorded.
- Home dashboard shows increased today sales and cash balance.
- Stock decreased after sale.

### B. Supplier payable
- Supplier created.
- Credit purchase linked to supplier recorded.
- Supplier card shows "له علينا: X ج.م".
- Supplier statement shows purchase as payable.

### C. Supplier payment
- Payment recorded from supplier card or statement.
- Supplier balance decreased.
- Payment appears in supplier statement.
- Home cash balance decreased.
- Reports show supplier payment.

### D. Validation
- Payment amount = 0 is rejected.
- Payment amount > balance is rejected.
- Clear Arabic messages shown for both.

### E. Cancellation safety
- Cancelling purchase with existing supplier payment is blocked.
- Stock and supplier balance remain uncorrupted.

### F. Delivery safety
- No source code files found in delivery folder.

## Commit

- Branch: `master`
- Commit hash: (to be filled after commit)
- Tag: `phase-36f-final-pilot-delivery-after-supplier-payment-ui`
