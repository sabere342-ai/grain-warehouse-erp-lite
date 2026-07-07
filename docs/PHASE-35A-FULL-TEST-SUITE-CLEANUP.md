# Phase 35A - Full Test Suite Cleanup: Phase 11 Arabic UX Regression

## What failed
- **File**: `test/phase11_ux_test.dart`
- **Test**: "cancellation confirmation explains stock reversal" (line 111)
- **Expected text**: `تحذير مهم: سيتم إنشاء حركة مخزون عكسية لإلغاء أثر هذا البيع. لن يتم حذف مستند البيع الأصلي أو الحركة الأصلية، وسيظهر الإلغاء في سجل المستندات للمالك.`
- **Actual**: The dialog text was shorter: `سيتم إنشاء حركة مخزون عكسية لإلغاء أثر هذا البيع. لن يتم حذف مستند البيع الأصلي.`

## Why it was unrelated to Phase 35 accounting
The failure was in a Phase 11 Arabic UX test that checks cancellation dialog wording in the Sales UI. Phase 35 added credit sale support to the same `sales_screen.dart` but did not change the cancellation dialog. The mismatch was a pre-existing text discrepancy: the test expected a more complete warning message while the dialog had a shorter version.

## What was fixed
Updated `lib/features/sales/sales_screen.dart` line 209-210: replaced the shorter cancellation dialog text with the more complete Arabic warning that:
- Starts with `تحذير مهم` (important warning) to draw attention
- Explains both the original document and the original movement are preserved
- States that the cancellation will appear in the document history for the owner

## Final full suite result
- `flutter analyze --no-pub` — No issues found
- `flutter test test/phase11_ux_test.dart` — 6/6 passed
- `flutter test` — 262/262 passed (full green)
- `flutter build windows --release` — Build successful
