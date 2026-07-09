# Phase 42 — PDF Export Foundation

## Scope
Add safe, local, Arabic PDF export for all 5 validated printable business documents. No printing, no WhatsApp sharing, no automatic sending, no cloud dependencies.

## Packages Added

| Package | Version | Reason |
|---------|---------|--------|
| `pdf` | ^3.11.2 | Core PDF document generation library (pure Dart). Builds documents programmatically with tables, text, fonts, and layout. |
| `printing` | ^5.13.4 | Provides `PdfPageFormat` constants and `ThemeData` for the `pdf` package. (Share/print features not used.) |
| `path_provider` | ^2.1.5 | Gets the application documents directory for the default export folder. |
| `open_filex` | ^4.6.0 | Opens the generated PDF file in the system's default PDF viewer after saving. |

## Arabic Font Strategy

- **Font**: Amiri (SIL Open Font License) — an elegant, open-source Arabic font designed for clear text rendering.
- **Files bundled**: `assets/fonts/Amiri-Regular.ttf` (431 KB) and `assets/fonts/Amiri-Bold.ttf` (413 KB).
- **Loading**: Fonts are loaded at runtime via `rootBundle.load()` and passed to the `pdf` package as `pw.Font.ttf()`.
- **Why bundled**: The `pdf` package generates raw PDF bytes independently of Flutter's text engine, so it needs embedded TrueType font data. A bundled Arabic font ensures text renders correctly without internet access.

## Export Location

- PDFs are saved to `{Documents}/Exports/`.
- The path is determined by `path_provider`'s `getApplicationDocumentsDirectory()`.
- After saving, the file is opened with the system's default PDF viewer via `open_filex`.
- A success SnackBar shows the file path. On failure, a clear Arabic error message is shown.
- No internet required. No silent saves to obscure paths.

## Documents Supported

| Document | Builder | File Name Pattern |
|----------|---------|-------------------|
| Sales Invoice | `PdfSalesInvoiceBuilder` | `فاتورة-بيع-{saleId}-{date}.pdf` |
| Customer Statement | `PdfCustomerStatementBuilder` | `كشف-حساب-عميل-{name}-{date}.pdf` |
| Daily Report | `PdfDailyReportBuilder` | `تقرير-يومي-{date}.pdf` |
| Purchase Invoice | `PdfPurchaseInvoiceBuilder` | `فاتورة-شراء-{purchaseId}-{date}.pdf` |
| Supplier Statement | `PdfSupplierStatementBuilder` | `كشف-حساب-مورد-{name}-{date}.pdf` |

## PDF Content Safety

- No internal IDs (productId, customerId, supplierId) are exposed.
- Sales invoice uses "منتج غير معروف" fallback instead of raw productId.
- No cost/reference-cost leak in sales invoice.
- No placeholder/TODO/under-construction text.
- No claims of automatic sending, printing, or WhatsApp delivery.

## File Structure

```
lib/features/exports/
  pdf_export_service.dart              # Main export service (font init, save, notify)
  pdf_file_naming.dart                 # Windows-safe filename generation
  pdf_sales_invoice_builder.dart       # Sales invoice PDF builder
  pdf_customer_statement_builder.dart  # Customer statement PDF builder
  pdf_daily_report_builder.dart        # Daily report PDF builder
  pdf_purchase_invoice_builder.dart    # Purchase invoice PDF builder
  pdf_supplier_statement_builder.dart  # Supplier statement PDF builder
```

## UI Integration

Each printable preview widget (`PrintableDocumentScaffold`) shows a "تصدير PDF" button below the document content. The button triggers `PdfExportService` with a loading indicator while the PDF is being generated.

## Test Coverage (24 new tests)

- **File naming (8 tests)**: forbidden chars sanitized, correct patterns, no raw IDs, no excessive length.
- **PDF generation (9 tests)**: all 5 document types produce valid `%PDF-...` bytes; cancelled invoices include cancellation notice; multi-item sales work.
- **Button visibility (5 tests)**: each preview widget shows a "تصدير PDF" button.
- **Forbidden text (3 tests)**: no "إرسال واتساب", "placeholder", "TODO", "قيد التنفيذ", "طباعة", "مشاركة" in source.

## Verification

- `flutter analyze --no-pub`: 0 errors, 0 warnings
- `flutter test`: 411/411 passing (387 existing + 24 new)
- `git diff --check`: no whitespace errors

## Out of Scope (Intentionally)

- Actual printing (no "طباعة" claims)
- WhatsApp sharing (no "واتساب" or "إرسال")
- Automatic sending
- Cloud upload
- Backend messaging
- Native save dialog (files save to Documents/Exports/; user can move/copy)

## Manual QA Instructions

1. Build the app: `flutter build windows --release`
2. Navigate to each screen with a printable document (Sales, Customers, Reports, Purchases, Supplier Statement).
3. Open the preview, then tap "تصدير PDF".
4. Verify:
   - The PDF opens in the default viewer.
   - Arabic text is clear and correctly shaped.
   - All content matches the screen preview.
   - No raw IDs or cost data visible.
5. Check `Documents/Exports/` folder for the saved PDF files.

## Next Roadmap

- Phase 43 — WhatsApp Assisted Sharing (opens WhatsApp with prepared message; manual send only; automatic sending out of scope)
