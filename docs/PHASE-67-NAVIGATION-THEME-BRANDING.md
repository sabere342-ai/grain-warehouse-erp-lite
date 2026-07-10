# Phase 67 - Navigation, Theme Controls, and Business Branding

## Phase Goal
Improve client readiness before the real owner trial by adding clearer return navigation, safe owner-controlled theme choices, and simple business identity support for invoices and app branding.

## Baseline
- Baseline commit: `efd0f32` - Document incomplete Phase 66 owner trial.
- Phase 66 owner trial was not executed.
- No Phase 66 completion tag was created.

## Scope Boundaries
- No accounting logic changes.
- No inventory logic changes.
- No sales, purchases, payments, or pricing logic changes.
- No cloud sync.
- No mobile app.
- No multi-device live sync.
- No owner acceptance or owner trial completion is claimed.

## Navigation Audit Summary
Pages checked under `lib/features/`:
- Dashboard shell and dashboard screen.
- Products/catalog.
- Suppliers.
- Supplier purchases.
- Supplier statement and supplier payment dialog.
- Purchases.
- Customers, customer statement, customer collection/opening-balance dialogs.
- Sales and sale invoice preview.
- Expenses.
- Inventory, stock take, stock adjustment report.
- Document history.
- Reports and daily report preview.
- Backup export, restore preview, data wipe.
- Settings.
- Help guide.
- Printable sales/purchase invoices, customer/supplier statements, daily report.

Classification:
- Main shell tabs/pages use the shell navigation and existing dashboard return pattern.
- Sub-pages/detail/report/preview screens require a visible Arabic return path.
- Dialogs already provide clear cancel/close actions where they collect input.

Pages fixed:
- Help guide: added AppBar `رجوع`.
- Supplier purchases: added AppBar `رجوع`.
- Supplier statement: added AppBar `رجوع`.
- Customer statement: added AppBar `رجوع`.
- Shared `PageBackButton`: changed default behavior to `Navigator.maybePop(context)`.

Pages already covered:
- Printable document previews already had `رجوع` with `maybePop`.
- Backup export, restore preview, data wipe, document history, and non-dashboard shell tabs already had return controls.

## Theme / Color Controls
- Existing central theme preset system was retained.
- Owner-facing labels were simplified:
  - `اللون الافتراضي`
  - `أزرق`
  - `بني / قمح`
  - `داكن بسيط`
- Theme selection continues to persist locally through `LocalThemeSettingsRepository`.
- Warning/error/success semantic colors were not remapped to arbitrary owner colors.

## Business Identity
- Added `BusinessIdentity`, `BusinessIdentityRepository`, and `BusinessIdentityController`.
- Added an owner-facing settings section for `اسم المنشأة`.
- The establishment name is persisted locally in `business_identity.json`.
- The app title and dashboard shell title use the establishment name when set.
- Printable sales/purchase invoice previews show the establishment name.
- Exported sales/purchase PDFs show the establishment name.
- Backup export includes optional `settings.businessIdentity`.
- Restore-to-empty restores the establishment name when present.
- Old backups remain compatible because the settings field is optional and backup version remains v2.

## Logo and App Icon Decision
- Invoice logo support: deferred.
- Owner logo upload was not added because the app does not yet have a safe file-picking/copy/validation pipeline for images.
- No placeholder logo upload UI was added.
- Windows app icon research outcome:
  - Flutter Windows app icon is controlled by `windows/runner/resources/app_icon.ico`.
  - Changing it is normally a build-time/package-time action.
  - Runtime app icon changes from inside the app are not promised.
  - Phase 67 deferred app icon replacement to avoid introducing unverified asset/tool changes before the owner trial.

## Tests Added / Updated
- Added `test/phase67_navigation_theme_branding_test.dart`.
- Coverage:
  - Sub-page Arabic back control and safe pop behavior.
  - Theme labels and persistence.
  - Invoice establishment name rendering with unchanged total.
  - Backup export/restore preservation of establishment name.

## Verification Results
- `flutter test test\phase67_navigation_theme_branding_test.dart`: 4/4 passing.
- `flutter test`: 546/546 passing.
- `flutter analyze --no-pub`: attempted twice, timed out without diagnostics.
- `dart analyze`: attempted, timed out without diagnostics.
- `flutter build windows --release`: attempted, timed out before returning output.
- `git diff --check`: pending final verification.

## Explicit Confirmations
- Production code changed: yes.
- Schema changed: no database schema change; backup v2 gained optional `settings.businessIdentity`.
- Accounting logic changed: no.
- Invoice totals changed: no.
- Cloud sync added: no.
- Mobile app added: no.
- Multi-device live sync added: no.
