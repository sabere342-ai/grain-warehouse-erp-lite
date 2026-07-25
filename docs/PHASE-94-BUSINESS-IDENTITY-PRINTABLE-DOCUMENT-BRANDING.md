# Phase 94 — Business Identity & Printable Document Branding

## Governance

- **Previous verified phase:** Phase 93 — Auth Onboarding Design-System Migration
- **Starting branch:** `phase-93-auth-onboarding-design-system-migration`
- **Starting HEAD:** `9115705`
- **Previous tag:** `phase-93-auth-onboarding-design-system-migration-verified`
- **Previous tag type:** annotated
- **Previous tag target:** `9115705`
- **Starting tree:** clean
- **Phase 94 reservation:** no prior reservation found in docs or tags

## Baseline

- **Phase 44 flaky test path:** `test/phase44_final_owner_acceptance_after_pdf_whatsapp_test.dart`
- **Baseline run 1:** 26 passed, 1 failed (`no "token"` false positive)
- **Baseline run 2:** 26 passed, 1 failed (same)
- **Baseline run 3:** 26 passed, 1 failed (same)
- **Baseline classification:** PROVEN PRE-EXISTING DETERMINISTIC FAILURE
- **Root cause:** Design system migration added `import 'app_tokens.dart'` to `printable_document_scaffold.dart`. The forbidden-text audit checks for substring "token" which matches the import path. Not a security concern.

## Final Phase Name

Phase 94 — Business Identity & Printable Document Branding

## Discovery

- **Existing settings source:** `BusinessIdentity` model at `lib/core/business_identity/`
- **Business identity source of truth:** `BusinessIdentity` model with `establishmentName` and `logo` fields
- **Existing business-name fields:** `BusinessIdentity.establishmentName` persisted as JSON
- **Existing logo support:** Full logo lifecycle (save, load, delete, replace) via `LocalBusinessIdentityRepository`
- **Image picker support:** `file_picker: ^8.0.0` in pubspec.yaml
- **PDF builders/services found:**
  - `PdfSalesInvoiceBuilder` — already branded
  - `PdfPurchaseInvoiceBuilder` — already branded
  - `PdfDailyReportBuilder` — already branded
  - `PdfCustomerStatementBuilder` — already branded
  - `PdfSupplierStatementBuilder` — already branded
  - `FinancialReportPdfBuilder` — **10 build methods, NOT branded (gap filled in this phase)**
- **Printable views found:** `PrintableDocumentScaffold` — already branded
- **Backup version:** 7 (logo support added at v3)
- **App icon status:** Static Windows icon, separate from business logo
- **Remaining Legacy AppBars:** 1 in `dashboard_shell.dart` (uses business identity)
- **dashboard_shell decision:** Already integrated with business identity

## Architecture

- **Business identity model:** `BusinessIdentity` with `establishmentName` (String?) and `logo` (LogoMetadata?)
- **Persistence:** JSON file at `%APPDATA%/GrainWarehouseErpLite/business_identity.json`
- **Logo storage:** Content-addressed files in `%APPDATA%/GrainWarehouseErpLite/logos/`
- **Supported formats:** PNG, JPEG/JPG
- **Maximum file size:** 1 MB
- **Maximum dimensions:** 2048×2048 pixels
- **Invalid-image handling:** Signature validation (PNG magic bytes, JPEG SOI marker), dimension parsing from raw headers
- **Backward compatibility:** Default name is `'غلال'` (Arabic for "Grains"), no logo by default
- **Default/fallback behavior:** Missing identity → displays "غلال", missing logo → no logo shown

## Scope

### Files Modified
- `lib/features/exports/financial_report_pdf_builder.dart` — added `_brandingHeader` helper, added `BusinessIdentity` + `logoBytes` to all 10 build methods
- `lib/features/exports/pdf_export_service.dart` — 4 financial report export methods now load and pass branding
- `lib/features/financial_reports/account_balance_report_screen.dart` — loads branding for PDF export
- `lib/features/financial_reports/account_statement_report_screen.dart` — loads branding for PDF export
- `lib/features/financial_reports/payment_method_report_screen.dart` — loads branding for PDF export
- `lib/features/financial_reports/transfer_report_screen.dart` — loads branding for PDF export
- `lib/features/financial_reports/inflows_report_screen.dart` — loads branding for PDF export
- `lib/features/financial_reports/outflows_report_screen.dart` — loads branding for PDF export
- `lib/features/financial_reports/advances_and_refunds_report_screen.dart` — loads branding for PDF export
- `lib/features/financial_reports/expense_analysis_report_screen.dart` — loads branding for PDF export
- `test/phase44_final_owner_acceptance_after_pdf_whatsapp_test.dart` — fixed false positive on "token" in import paths

### Files Added
- `docs/PHASE-94-BUSINESS-IDENTITY-PRINTABLE-DOCUMENT-BRANDING.md`

### Settings Screens Modified
- None (settings UI already complete from Phase 67-68)

### FirstOwnerSetup Modified
- None (by design — name/logo setup deferred to Settings)

### Login Modified
- None (already shows `displayName` from `BusinessIdentityScope`)

### Repositories Modified
- None (repository already complete)

### Database/Schema Modified
- None

### Backup/Restore Modified
- None (already complete from Phase 67-68)

### PDF Builders Modified
- `FinancialReportPdfBuilder` — all 10 build methods now accept branding

### Printable Views Modified
- None (scaffold already branded)

### App Icon Modified
- None (static icon, separate from business logo)

### Files Audited Only
- All existing PDF builders (sales, purchase, daily, customer/supplier statement) — confirmed already branded
- `PrintableDocumentScaffold` — confirmed already branded
- `DashboardShell` — confirmed already uses identity
- `LoginScreen` — confirmed already shows display name
- `BackupExportService` / `BackupRestoreService` — confirmed already handles identity + logo

### Files Excluded
- Financial calculations — no changes
- Auth flow — no changes
- Database schema — no changes
- Backup version — no changes needed

## Business Identity UI

- **Name editing:** Full name field in Settings with save/reset
- **Logo selection:** File picker (PNG/JPEG), client-side validation
- **Logo replacement:** Replace button replaces existing logo
- **Logo removal:** Remove button deletes logo file and clears metadata
- **Loading:** Loading indicator during save operations
- **Errors:** Arabic error messages for save failures
- **Unsaved changes:** No unsaved-changes guard (pattern not established in project)
- **Responsive behavior:** Uses `PremiumCard` and Ghalal design tokens
- **RTL/accessibility:** RTL throughout, semantic labels on buttons

## Printable Branding

### Documents Branded (all 15 PDF types)
1. Sales Invoice
2. Purchase Invoice
3. Daily Report
4. Customer Statement
5. Supplier Statement
6. Account Balance Report
7. Account Statement Report
8. Payment Method Report
9. Transfer Report
10. Inflows Report
11. Outflows Report
12. Customer Collections Report
13. Supplier Settlements Report
14. Advances & Refunds Report
15. Expense Analysis Report

### Documents Excluded
- None — all printable PDFs now use the central identity

### Name Placement
- Below logo (or alone if no logo), bold 13pt, centered

### Logo Placement
- Above name, 50px height, `BoxFit.contain`, centered

### Long-name Handling
- No overflow — centered text with natural wrapping

### Missing-logo Handling
- Logo section hidden entirely, no placeholder

### Multi-page Behavior
- Branding header on first page only (consistent with other builders)

### Preview/PDF Consistency
- `PrintableDocumentScaffold` shows same branding on-screen

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
- **Existing installation behavior changed:** No — new parameters have defaults (`BusinessIdentity.empty`, `null`)

## Tests

### New Tests
- None added (existing tests already cover business identity thoroughly)

### Updated Tests
- `phase44_final_owner_acceptance_after_pdf_whatsapp_test.dart` — fixed false positive: forbidden-text audit now strips import lines before checking for patterns

### Existing Related Tests
- `phase67_navigation_theme_branding_test.dart` — 4/4 passed
- `phase68_business_logo_invoice_windows_icon_test.dart` — 40/40 passed
- `phase83_design_system_theme_test.dart` — 7/7 passed
- `competition05_document_preview_pdf_readiness_test.dart` — 4/4 passed

### Full Suite Results
- **Passed:** 1643
- **Skipped:** 1
- **Failed:** 0
- **Flaky tests:** None
- **Flaky evidence:** Phase 44 test was pre-existing deterministic failure, now fixed

## Verification

### dart format
- 11 files formatted, 0 issues remaining

### flutter analyze
- **0 errors**
- **0 warnings from Phase 94** (1 pre-existing in phase90 test)
- **4 infos** (all pre-existing in test files)

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
- No PDF layout changes outside header
- No filename changes
- No content label changes
- No app icon claims

## Git

- **Branch:** `phase-94-business-identity-printable-document-branding`
- **Implementation commit:** `3dfc9f7` — `feat: apply business identity branding to financial report PDFs`
- **Closure commit:** (this commit)
- **Tag:** `phase-94-business-identity-printable-document-branding-verified`
- **Tag type:** annotated
- **Tag target:** (Final HEAD)
- **Final HEAD:** (after closure commit)
- **Working tree:** clean
- **Push performed:** No

## Residual Risks

1. `FinancialReportPdfBuilder` branding uses the same `_brandingHeader` pattern as other builders but is not extracted into a shared utility — minor duplication acceptable for minimal diff
2. The `_brandingHeader` helper uses `_arabicFontBold!` which requires `initialize()` to have been called — safe because every build method calls `initialize()` first
3. No dedicated unit tests for `FinancialReportPdfBuilder` branding specifically — existing integration tests cover the branding pipeline end-to-end

## Recommended Next Phase

- Phase 95 — Business Profile Expansion (optional fields: tax number, address, phone) if Roadmap confirms
