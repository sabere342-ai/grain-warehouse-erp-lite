# Phase 91 — Printable Document Scaffold Design-System Migration

## Governance Evidence

| Item | Value |
|------|-------|
| Previous phase | Phase 90 — Remaining Push-Route Screens |
| Previous branch | `phase-90-remaining-push-route-screens` |
| Previous expected HEAD | `e6abb5b` |
| Previous actual HEAD | `e6abb5b` ✓ |
| Previous tag | `phase-90-remaining-push-route-screens` |
| Previous tag type | annotated (`tag`) ✓ |
| Previous tag target | `e6abb5b` ✓ |
| Starting tree | clean ✓ |
| Phase 91 reservation check | no branch/tag/doc found ✓ |

## Verified Phase 90 Baseline

| Gate | Result |
|------|--------|
| git status | clean |
| HEAD | `e6abb5b` |
| Phase 90 tag | annotated, points to HEAD |
| flutter analyze | No issues |
| flutter test | 1579 passed, 1 skipped, 0 failed |
| Windows build | SUCCESS |
| dart format | 40 pre-existing files (not Phase 90) |

## Print-Surface Inventory

### Included in scope

| # | File | Type | Migration |
|---|------|------|-----------|
| 1 | `lib/features/prints/printable_document_scaffold.dart` | Shared scaffold shell | **Migrated** |

### 5 child views (no changes needed — delegate to scaffold)

| # | File | Document Type |
|---|------|---------------|
| 1 | `printable_sales_invoice_view.dart` | Sales Invoice |
| 2 | `printable_purchase_invoice_view.dart` | Purchase Invoice |
| 3 | `printable_customer_statement_view.dart` | Customer Statement |
| 4 | `printable_supplier_statement_view.dart` | Supplier Statement |
| 5 | `printable_daily_report_view.dart` | Daily Report |

### Excluded (pure code, no UI)

| # | File | Reason |
|---|------|--------|
| 1-9 | `exports/pdf_*.dart`, `exports/financial_report_*.dart`, `exports/pdf_file_naming.dart` | PDF/CSV builders, no UI |
| 10-19 | `financial_reports/*_screen.dart` (10 screens) | Already migrated to Ghalal |
| 20-21 | `supplier_advance_actions_screen.dart`, `customer_advance_actions_screen.dart` | Legacy AppBar holdouts, deferred |

## Before/After UI Patterns

### Before
```dart
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
// ...
return Directionality(
  textDirection: TextDirection.rtl,
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Container(
      // ...
      style: theme.textTheme.titleMedium?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w900,
      ),
      // ...
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AppColors.mutedText,
      ),
      // ...
      spacing: 12,
      runSpacing: 8,
      // ...
      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(...)),
```

### After
```dart
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
// ...
final theme = Theme.of(context);
final colorScheme = theme.colorScheme;
return SingleChildScrollView(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: Container(
    // ...
    style: theme.textTheme.titleMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w900,
    ),
    // ...
    style: theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
    // ...
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.xs,
    // ...
    SizedBox(width: AppIconSizes.sm, height: AppIconSizes.sm, child: CircularProgressIndicator(...)),
```

## Changes Summary

| Change | Before | After |
|--------|--------|-------|
| Import | `app_colors.dart` | `app_tokens.dart` |
| Wrapper | `Directionality(textDirection: TextDirection.rtl, ...)` | Removed — relies on app-level RTL |
| Text color | `AppColors.text` | `colorScheme.onSurface` |
| Muted text | `AppColors.mutedText` | `colorScheme.onSurfaceVariant` |
| Padding | `EdgeInsets.all(16)` | `AppSpacing.md` |
| Inner spacing | Raw `SizedBox(height: 4/6/8/12)` | `AppSpacing.xxs / .xs / .sm` |
| Button spacing | Raw `spacing: 12, runSpacing: 8` | `AppSpacing.sm / .xs` |
| Loading indicator size | Raw `width: 16, height: 16` | `AppIconSizes.sm` |
| Theme access | Repeated `Theme.of(context)` | Cached `theme` / `colorScheme` |

## Navigation Behavior

- Dialog-embedded — no standalone push-route
- Back button calls `Navigator.of(context).maybePop()` to close dialog
- No GhalalPageHeader (inappropriate for dialog context)
- No duplicate AppBar or back control

## Loading/Error Behavior

- Export/WhatsApp buttons show `CircularProgressIndicator` during async operations
- `_isExporting` / `_isSharing` state prevents double-tap
- `mounted` check before setState after async gap
- Business identity loaded via `BusinessIdentityScope.maybeOf(context)`

## Print/Save/Open/Share Actions

- **Export PDF**: Calls `PdfExportService.export*()` — saves to Documents/Exports, opens file
- **WhatsApp**: Calls `WhatsAppAssistedShareService.openWhatsApp()` — launches URL
- **Back**: `Navigator.maybePop()` — closes dialog
- All action callbacks preserved unchanged

## PDF Safety

- No changes to PDF builders
- No changes to file naming
- No changes to export service
- No changes to document content or calculations

## Branding

- `BusinessIdentityScope` used for displayName and logo — preserved
- Logo loading via `AppRepositories.businessIdentityRepository.loadLogoBytes()` — preserved
- Default displayName fallback — preserved

## Responsive Findings

- `SingleChildScrollView` ensures scroll access to all buttons
- No overflow on 360×720 viewport
- `Wrap` layout for action buttons adapts to width

## Tests Added

| # | Test | Coverage |
|---|------|----------|
| 1 | uses theme colorScheme for text | Design token migration |
| 2 | no Directionality wrapper | RTL delegation |
| 3 | shows document date and number | Content preservation |
| 4 | back button pops navigation | Back behavior |
| 5 | no overflow on small viewport | Responsive |
| 6 | export/back buttons accessible by scrolling | Accessibility |
| 7 | sales invoice renders | Child view integration |
| 8 | purchase invoice renders | Child view integration |
| 9 | customer statement renders | Child view integration |
| 10 | supplier statement renders | Child view integration |
| 11 | daily report renders | Child view integration |
| 12 | shows export PDF button | Action preservation |
| 13 | shows export/WhatsApp when callbacks provided | Action preservation |
| 14 | hides export buttons when null | Conditional rendering |
| 15 | displays default business identity | Branding preservation |

## Full-Suite Result

| Metric | Value |
|--------|-------|
| Passed | 1593 |
| Skipped | 1 |
| Failed | 1 (pre-existing flaky `phase8d`) |

## Analyzer Result

| Level | Count | Source |
|-------|-------|--------|
| error | 0 | — |
| warning | 1 | pre-existing Phase 90 test |
| info | 4 | prefer_const_constructors (test file) |

## Windows Build

SUCCESS — `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`

## Diff Review

- 1 file modified in lib: `printable_document_scaffold.dart`
- 1 file added in test: `phase91_printable_document_scaffold_design_system_test.dart`
- No files in docs modified (documentation is this file)
- No financial calculations changed
- No PDF output changed
- No schema changed
- No backup/restore changed

## Production Behavior Statement

All 5 printable document views (sales invoice, purchase invoice, customer statement, supplier statement, daily report) continue to render identically through the shared scaffold. The only visual change is adoption of design-system color tokens and spacing tokens. PDF export, WhatsApp sharing, and file save/open behavior are preserved.

## Schema Statement

No database schema changes.

## Backup/Restore Statement

No backup/restore contract changes.

## Known Residuals

1. 40 pre-existing dart format files (not in Phase 91 scope)
2. 1 pre-existing warning in Phase 90 test (`override_on_non_overriding_member`)
3. 4 info-level lint suggestions in Phase 91 test (`prefer_const_constructors`)
4. 1 flaky test in full suite (`phase8d_durable_supplier_repository_test.dart`) — passes individually
5. `supplier_advance_actions_screen.dart` and `customer_advance_actions_screen.dart` still use legacy AppBar — deferred to future phase

## Next Recommended Phase

- **Phase 92**: Legacy AppBar holdout migration (`supplier_advance_actions_screen.dart`, `customer_advance_actions_screen.dart`)
- **Phase 93**: Login / FirstOwnerSetup screens design-system migration
- Optional: Business Identity & Printable Document Branding (independent scope)
