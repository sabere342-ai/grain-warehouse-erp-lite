# Phase 41 — Printable Preview Accuracy QA

## Goal
Validate and harden all printable preview widgets for data accuracy, Arabic clarity, and business consistency. No PDF export, no printing, no WhatsApp sharing — pure preview QA.

## Changes

### 1. `PrintableSalesInvoiceView`
- **Internal ID fallback**: Replaced raw `productId` display with `"منتج غير معروف"` (unknown product) when `productNames` map lacks an entry. Applies to both single-item and multi-item paths.
- **Quantity unit**: Added `"كجم"` suffix to quantity values (e.g., `"500 كجم"` instead of `"500"`).

### 2. `PrintableCustomerStatementView`
- Added `"جميع الحركات المتاحة"` (all available movements) to the subtitle to honestly reflect that no date filter is applied.

### 3. `PrintableSupplierStatementView`
- Same as customer statement — added `"جميع الحركات المتاحة"` to subtitle.

### 4. `PrintableDailyReportView`
- Added **Collections & Payments** section:
  - "تحصيل من العملاء" (collections from customers)
  - "مدفوعات للموردين" (payments to suppliers)
- Added outstanding balances to Summary section:
  - "المستحق على العملاء" (outstanding receivables)
  - "المستحق للموردين" (outstanding payables)

### 5. No changes needed
- `PrintablePurchaseInvoiceView` — already passes product name directly, no ID leak.
- `PrintableDocumentScaffold` — no print/PDF claims, Arabic hierarchy clean.
- No screen wiring files needed changes.

## Test Coverage (Phase 41 edge cases)
- Unknown product name falls back to "منتج غير معروف" (single-item)
- Multi-item sale with all unknown products shows fallback instead of raw IDs
- Cancelled multi-item sale shows "ملغاة — تم عكس الأرصدة"
- Customer statement shows "جميع الحركات المتاحة"
- Supplier statement shows "جميع الحركات المتاحة"
- Daily report shows collections and outstanding balance rows

## Verification
- `flutter analyze --no-pub`: 0 errors, 0 warnings
- `flutter test`: 387/387 passing (6 new Phase 41 tests)
- All 6 preview widgets audited for forbidden text: no "PDF", "طباعة", "واتساب", "WhatsApp", "قيد التنفيذ", "placeholder", or "TODO"

## Commit
`phase-41-printable-preview-accuracy-qa`
