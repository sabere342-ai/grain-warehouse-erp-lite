# Phase 40 — Printable Business Documents Foundation

## Phase Objective
Add safe, owner-facing printable/preview-ready document layouts for the most important pilot documents, built on the Phase 39 customer-bound multi-item sales flow. This phase introduces clear document previews without corrupting accounting, stock, cash, balances, reports, or backup/restore.

## Baseline
- Commit: `662932e`
- Tag: `phase-39-customer-bound-multi-item-sales`
- Tests: 367/367 passing
- Analyze: 0 errors
- Build: Windows release successful

## Scope
1. Sales invoice printable preview
2. Customer statement printable preview
3. Daily report printable preview
4. Purchase invoice printable preview (if data is complete)
5. Supplier statement printable preview (if data is complete)

## Non-Goals
- Native printer driver integration (deferred — Flutter desktop print is not yet stable/reliable in the current dependency set)
- PDF file export (deferred — requires dependency audit and testing)
- Email/share functionality
- Inventory/product movement statement (deferred — low pilot priority, purchase/sales movement data already visible in daily report)
- Schema changes to existing models

## Existing Document/Report Audit

### Data models available
| Document | Data Source | Complete? |
|---|---|---|
| Sales invoice | `SaleRecord` + `SaleLineItem` + `Customer.name` | Yes — Phase 39 multi-item, customer-bound |
| Customer statement | `CustomerAccountRepository.statementForCustomer()` | Yes — Phase 34-39 |
| Daily report | `ReportRepository.dailyActivityReport()` | Yes — Phase 8, enhanced Phase 36-37 |
| Purchase invoice | `PurchaseIntake` + `Supplier.name` | Single-item only (no multi-item support yet) |
| Supplier statement | `SupplierAccountRepository.statementForSupplier()` | Yes — Phase 36 |
| Inventory statement | `InventoryRepository.listAllMovements()` | Deferred — low priority |

### Decision on deferred documents
**Purchase invoice**: supported as single-item (current model). Multi-item purchase is not yet implemented and is out of scope.

**Supplier statement**: supported — complete data model exists.

**Inventory/product movement**: deferred. The daily report already includes stock movement information. A standalone movement statement adds low value for pilot.

### Print/export assessment
- Flutter desktop `printing` package: not currently in `pubspec.yaml`. Adding it risks dependency issues. Deferred.
- Native Windows print dialog: not available through Flutter without platform channel or `printing` package.
- **Decision**: Preview-only. All views use "معاينة" / "عرض" wording. No "طباعة" or "تصدير" buttons.
- Owner-facing note on each preview: "يمكن مراجعة هذا المستند من الشاشة أو تصويره/حفظه حسب المتاح حاليًا."

## Implementation Approach

### Widgets added under `lib/features/prints/`
- `PrintableDocumentScaffold` — shared wrapper with white background, header, print-note footer
- `PrintableSalesInvoiceView` — sale invoice details
- `PrintableCustomerStatementView` — customer account statement
- `PrintableDailyReportView` — daily activity report
- `PrintablePurchaseInvoiceView` — purchase intake details
- `PrintableSupplierStatementView` — supplier account statement

### UI entry points
| Screen | Button | Target View |
|---|---|---|
| Sales list / Sale card | "معاينة الفاتورة" | `PrintableSalesInvoiceView` |
| Customer details / list | "عرض كشف الحساب" | `PrintableCustomerStatementView` |
| Report screen | "معاينة التقرير" | `PrintableDailyReportView` |
| Purchase list / card | "معاينة الفاتورة" | `PrintablePurchaseInvoiceView` |
| Supplier details / list | "عرض كشف الحساب" | `PrintableSupplierStatementView` |

### Accounting consistency rules
- Printable invoice total = stored sale total (`sale.totalQirsh`)
- Customer statement running balance = `CustomerAccountRepository.statementForCustomer()` result
- Daily report totals = `ReportRepository.dailyActivityReport()` result
- Cash sales appear in customer statement even if net balance impact is zero
- Collections are labeled "تحصيل من العميل", not merged into sales
- No missing data is invented; no fake totals

## Repository Hygiene

### Decision on `test/debug_movement_test.dart`
This file was created during Phase 39 development to debug the `reversedMovementId` issue in `cancelSale`. Its coverage is now fully included in:
- `test/phase39_customer_bound_multi_item_sales_test.dart` (17 tests covering multi-item cancellation with reversal verification)
- `test/document_history_test.dart` (linked movement and reversal tests)

The debug test file is **removed**. It was temporary debugging code that should not remain in the permanent test suite under a "debug" name.

## UI/UX Rules Applied
- Arabic-first labels
- No raw internal IDs except owner-facing document numbers
- No technical terms, developer info, or exceptions
- Clean white background suitable for screenshot/manual sharing
- Consistent with existing RTL theme

## Tests Added
- `test/phase40_printable_business_documents_test.dart` — 15 tests

## Commands Run
```powershell
cd C:\dev\multi-pos\grain-warehouse-erp-lite
flutter analyze --no-pub
flutter test
flutter build windows --release
git diff --check
git status --short
```

## Final Verdict
PASS — Preview-only printable document foundation delivered. All quality gates pass.

## Residual Risks
1. Print engine not yet implemented — native printing deferred to future phase
2. No PDF export — owner must screenshot or use screen capture for sharing
3. Purchase invoices are single-item only — multi-item purchase not yet supported
4. No inventory/product movement standalone statement — deferred
