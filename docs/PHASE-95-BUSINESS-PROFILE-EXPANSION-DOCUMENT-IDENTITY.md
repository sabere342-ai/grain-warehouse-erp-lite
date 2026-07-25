# Phase 95 — Business Profile Expansion & Document Identity Completion

## Governance

- **Previous verified phase:** Phase 94 — Business Identity & Printable Document Branding
- **Starting branch:** `phase-95-business-profile-expansion-document-identity`
- **Starting HEAD:** `bb8f8ae`
- **Previous tag:** `phase-94-business-identity-printable-document-branding-verified`
- **Previous tag type:** annotated
- **Previous tag target:** `bb8f8aed7aaa1ad074b3f8154365e220bb9380ef`
- **Starting tree:** clean
- **Phase 95 reservation:** no prior reservation found in docs or tags

## Final Phase Name

Phase 95 — Business Profile Expansion & Document Identity Completion

## Discovery

- **Existing business identity system:** `BusinessIdentity` model at `lib/core/business_identity/`
- **Existing fields:** `establishmentName` (String?), `logo` (LogoMetadata?)
- **Existing PDF builders:** 6 builders, all branded with name + logo from Phase 94
  - `PdfSalesInvoiceBuilder` — customer-facing
  - `PdfPurchaseInvoiceBuilder` — supplier-facing
  - `PdfCustomerStatementBuilder` — customer-facing
  - `PdfSupplierStatementBuilder` — supplier-facing
  - `PdfDailyReportBuilder` — internal
  - `FinancialReportPdfBuilder` — internal
- **Existing PrintableDocumentScaffold:** Shows branding on-screen preview
- **Settings UI:** Name editing + logo management already complete from Phase 67-68
- **Backup version:** 7 (JSON identity file, backward compatible)
- **Image picker support:** `file_picker: ^8.0.0` in pubspec.yaml

## Architecture

- **Business identity model:** `BusinessIdentity` with `establishmentName` (String?), `logo` (LogoMetadata?), and new optional fields: `taxNumber` (String?), `address` (String?), `phone` (String?)
- **Persistence:** JSON file at `%APPDATA%/GrainWarehouseErpLite/business_identity.json`
- **Logo storage:** Content-addressed files in `%APPDATA%/GrainWarehouseErpLite/logos/`
- **New fields:** Optional, blank values stored as null, backward compatible
- **Shared branding header:** `PdfBrandingHeader` utility at `lib/features/exports/pdf_branding_header.dart`
- **Profile details visibility:** Customer-facing documents show address/phone/tax; internal documents do not

## Scope

### Files Modified
- `lib/core/business_identity/business_identity.dart` — added `taxNumber`, `address`, `phone` fields; trimmed getters; `hasAddress`/`hasPhone`/`hasTaxNumber` booleans; updated `copyWith`, `toJson`, `fromJson`
- `lib/core/business_identity/business_identity_controller.dart` — added `saveProfileDetails()` method
- `lib/features/settings/settings_screen.dart` — added `_ProfileDetailsSection` widget with three optional fields
- `lib/features/exports/pdf_sales_invoice_builder.dart` — uses shared `PdfBrandingHeader` with `includeProfileDetails: true`
- `lib/features/exports/pdf_purchase_invoice_builder.dart` — uses shared `PdfBrandingHeader` with `includeProfileDetails: true`
- `lib/features/exports/pdf_customer_statement_builder.dart` — uses shared `PdfBrandingHeader` with `includeProfileDetails: true`
- `lib/features/exports/pdf_supplier_statement_builder.dart` — uses shared `PdfBrandingHeader` with `includeProfileDetails: true`
- `lib/features/exports/pdf_daily_report_builder.dart` — uses shared `PdfBrandingHeader` with `includeProfileDetails: false`
- `lib/features/exports/financial_report_pdf_builder.dart` — `_brandingHeader()` delegates to shared `PdfBrandingHeader`
- `lib/features/prints/printable_document_scaffold.dart` — shows address and phone in on-screen preview
- `test/competition05_document_preview_pdf_readiness_test.dart` — updated source contract check

### Files Added
- `lib/features/exports/pdf_branding_header.dart` — shared reusable branding header component
- `test/phase95_business_profile_expansion_test.dart` — 32 focused tests

### Settings Screens Modified
- `settings_screen.dart` — added profile details section (tax number, address, phone)

### Backup/Restore
- `toJson()` includes new fields when non-null; `fromJson()` defaults missing fields to null
- No backup version change needed — backward compatible

### PDF Builders
- All 6 builders migrated to shared `PdfBrandingHeader` component
- Customer-facing docs (sales invoice, purchase invoice, customer statement, supplier statement) include profile details
- Internal docs (daily report, financial reports) do not include profile details

### Printable Views
- `PrintableDocumentScaffold` on-screen preview shows address and phone below business name when present

## Safety

- **Financial calculations changed:** No
- **Document totals changed:** No
- **Document line items changed:** No
- **Document numbers changed:** No
- **PDF filenames changed:** No
- **Sharing behavior changed:** No
- **Authentication changed:** No
- **First-owner rules changed:** No
- **Schema changed:** No
- **Backup versions changed:** No
- **Existing installation behavior changed:** No — all three new fields are optional with null defaults

## Tests

### New Tests
- `test/phase95_business_profile_expansion_test.dart` — 32 tests
  - Model: field defaults, trimming, hasXxx booleans, toJson/fromJson round-trip, backward compat (17 tests)
  - Controller: saveProfileDetails with trimming, null-on-blank normalization (5 tests)
  - Backup/restore: round-trip with new fields, backward compat with old backups (6 tests)
  - Settings UI: field rendering, labels (4 tests)

### Existing Related Tests
- `competition05_document_preview_pdf_readiness_test.dart` — updated and passing

### Full Suite Results
- **Passed:** 1675
- **Skipped:** 1
- **Failed:** 0
- **Flaky tests:** None

## Verification

### dart format
- All modified files formatted, 0 issues remaining

### flutter analyze
- **0 errors**
- **0 warnings from Phase 95** (5 pre-existing in test files phase90/phase91)

### Windows Release Build
- **Exit code:** success
- **Artifact:** `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`
- **No errors in build output**

### git diff --check
- Only CRLF warnings (Windows normal)

### Diff Audit
- No financial calculations changed
- No absolute file paths
- No image bytes in source
- No unintended assets
- No debug prints
- No schema changes
- No backup version changes
- No PDF layout changes outside branding header
- No filename changes
- No content label changes
- No app icon claims

## Git

- **Branch:** `phase-95-business-profile-expansion-document-identity`
- **Implementation commit:** (pending)
- **Closure commit:** (this commit)
- **Tag:** `phase-95-business-profile-expansion-document-identity-verified`
- **Tag type:** annotated
- **Tag target:** (Final HEAD)
- **Final HEAD:** (after closure commit)
- **Working tree:** clean
- **Push performed:** No

## Residual Risks

1. `PdfBrandingHeader.build()` returns `List<pw.Widget>` which requires `...` spread at call sites — if a caller forgets the spread, the header is silently not included; existing integration tests cover all callers
2. Tax number formatting is free-text — no validation or formatting applied; future phases could add formatting rules
3. No dedicated unit tests for individual PDF builder branding output — covered by `competition05` integration tests

## Recommended Next Phase

- Phase 96 — per Roadmap priorities (document validation, advanced backup features, or reporting enhancements)
