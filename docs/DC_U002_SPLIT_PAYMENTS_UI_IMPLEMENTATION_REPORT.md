# DC-U002 Split Payments End-User UI — Implementation Report

## Scope

End-user UI layer for split payment allocations in the sale form dialog.
The Core layer (commit `839ff78`) was already closed; this phase adds only the
UI surface that collects user input and invokes the existing Core API.

## What Was Built

### Sale Form Dialog (`sales_screen.dart`)

- Payment mode `SegmentedButton` with three options: Cash (كاش), Partial
  (جزئي), Credit (آجل).
- Toggle to enable/disable split payments (enabled by default for Cash and
  Partial, hidden for Credit).
- Dynamic allocation rows: each row has account type dropdown (خزنة/بنك/محفظة),
  account name dropdown (filtered to active accounts of the selected type), and
  an amount field in EGP (ج.م) that is validated as a valid piaster amount.
- Add/remove allocation rows with the "╋ إضافة حساب" button.
- Balance indicator: shows "✓ متوافق" (green) when allocations match the sale
  total, "✗ غير متوافق" (red) otherwise.
- Summary row: shows total, remaining (المتبقي), and paid (المدفوع).
- Double-submit protection: `_isSubmitting` flag disables the save button and
  shows a spinner during submission.

### Controller Extension (`sale_controller.dart`)

- `load()` now also loads `financialAccounts` from
  `AppRepositories.financialAccountRepository.listAccounts()`.
- `List<FinancialAccount> financialAccounts` getter exposed for the UI.

## Architecture Constraints Respected

| Constraint | Status |
|------------|--------|
| No accounting logic in UI | ✓ — UI collects inputs only; Core handles allocation posting |
| No `double` for money | ✓ — all amounts in qirsh (`int`), converted to EGP display only |
| Arabic error messages | ✓ — all labels and messages in Arabic |
| RTL layout | ✓ — verified in widget test |
| No color-only error indicators | ✓ — red/green text accompanied by ✗/✓ symbols |
| Replay protection | ✓ — Core generates stable `operationRequestId` per item |
| Backward compatibility | ✓ — simple cash sale without split works identically |

## Validation Rules Implemented

1. Save button disabled when:
   - No items in the sale
   - Customer not selected (required for submit)
   - Split payments enabled but allocation total ≠ paid amount (for partial)
     or sale total (for cash)
   - Any allocation amount is zero or unparseable
   - Any allocation has no account selected
   - Any allocation row uses a duplicate account (same account in two rows)
2. Balance indicator shows real-time match/mismatch as user types.
3. Allocation rows cannot use the same account as another row (dropdown
   filtering excludes accounts in use by other rows).

## Test Counts and Durations

| Suite | Tests | Duration |
|-------|-------|----------|
| `dc_u002_split_payments_ui_test.dart` | 14 | ~6 s |
| `dc_u002_split_payments_test.dart` (Core) | 7 | ~1 s |
| `sales_test.dart` (regression) | 18 | ~2 s |
| Full repository (sequential) | 876 | 1 min 49 s |

### UI Test Breakdown

| Group | Tests |
|-------|-------|
| Display | 7 — toggle for cash/partial, hidden for credit, allocation row fields, summary, add/delete |
| Validation | 4 — zero amount, no account, total mismatch, balanced indicator |
| Backward Compat | 2 — simple cash sale, credit sale |
| RTL and Arabic | 1 — Arabic labels and RTL layout |

## Analyzer / Build Results

| Check | Result |
|-------|--------|
| `flutter analyze` | No issues found |
| `dart format` | Clean (0 changed) |
| `flutter build windows --release` | Build succeeded (57 s) |

## Files Changed

**Modified files (2):**
- `lib/core/sales/sale_controller.dart` — added `financialAccounts` loading and getter
- `lib/features/sales/sales_screen.dart` — split payments UI in `_SaleFormDialog`

**New files (1):**
- `test/dc_u002_split_payments_ui_test.dart` — 14 widget/integration tests

## Known Limitations

- No dedicated "split payments" preview or summary screen after sale creation;
  allocations are visible in the financial account statements and printable
  sale view.
- Allocation rows are flat (no nesting or sub-allocations).
- Account type filtering in dropdowns is UI-only; the Core layer validates
  account eligibility independently.
