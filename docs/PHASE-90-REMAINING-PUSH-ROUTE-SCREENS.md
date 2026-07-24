# Phase 90 — Remaining Push-Route Screens Design System Migration

**Status:** COMPLETE
**Date:** 2026-07-24
**Branch:** `phase-90-remaining-push-route-screens`

## Scope

Migrate the final 4 remaining push-route screens to the Ghalal Design System, completing all non-auth non-print screen migrations.

### Screens Migrated

| Screen | File | Before | After |
|--------|------|--------|-------|
| FinancialAccountStatementScreen | `lib/features/financial_accounts/financial_account_statement_screen.dart` | AppBar + AppBarBackButton, raw EdgeInsets, AppColors.mutedText, CircularProgressIndicator | GhalalPageHeader, AppSpacing, GhalalLoadingState/EmptyState/ErrorState, onSurfaceVariant |
| FinancialTransfersScreen | `lib/features/financial_accounts/financial_transfers_screen.dart` | AppBar + AppBarBackButton, raw EdgeInsets, CircularProgressIndicator | GhalalPageHeader, AppSpacing, GhalalLoadingState |
| DocumentHistoryScreen | `lib/features/documents/document_history_screen.dart` | PageBackButton + manual title, raw EdgeInsets, AppColors.mutedText, CircularProgressIndicator | GhalalPageHeader, AppSpacing, GhalalLoadingState/EmptyState, onSurfaceVariant |
| SupplierPurchasesScreen | `lib/features/purchases/supplier_purchases_screen.dart` | AppBar + AppBarBackButton, raw EdgeInsets, AppColors.mutedText, CircularProgressIndicator | GhalalPageHeader, AppSpacing, GhalalLoadingState/EmptyState, onSurfaceVariant |

### Changes Per Screen

**FinancialAccountStatementScreen:**
- Removed AppBar, added GhalalPageHeader with `icon: Icons.account_balance_rounded`
- Replaced raw EdgeInsets/SizedBox values with AppSpacing tokens
- Replaced CircularProgressIndicator → GhalalLoadingState
- Replaced PremiumCard error → GhalalErrorState with retry
- Replaced PremiumCard empty → GhalalEmptyState with icon
- Replaced AppColors.mutedText → Theme.of(context).colorScheme.onSurfaceVariant (4 occurrences)
- Replaced BorderRadius.circular(8) → AppRadius.sm

**FinancialTransfersScreen:**
- Removed AppBar (both owner and non-owner scaffolds), added GhalalPageHeader with `icon: Icons.swap_horiz_rounded`
- Added GhalalPageHeader to non-owner guard scaffold
- Replaced CircularProgressIndicator → GhalalLoadingState
- Replaced raw EdgeInsets/SizedBox values with AppSpacing tokens

**DocumentHistoryScreen:**
- Replaced PageBackButton + manual Text title/subtitle with GhalalPageHeader (icon: `Icons.history_rounded`)
- Removed AppColors import and page_back_button import
- Replaced CircularProgressIndicator → GhalalLoadingState
- Replaced PremiumCard empty → GhalalEmptyState with `Icons.search_off_rounded`
- Replaced raw EdgeInsets/SizedBox values with AppSpacing tokens

**SupplierPurchasesScreen:**
- Removed AppBar + AppBarBackButton, added GhalalPageHeader with `icon: Icons.shopping_cart_rounded`
- Replaced CircularProgressIndicator → GhalalLoadingState
- Replaced PremiumCard empty → GhalalEmptyState wrapped in ListView with header
- Replaced AppColors.mutedText → Theme.of(context).colorScheme.onSurfaceVariant
- Replaced raw EdgeInsets/SizedBox values with AppSpacing tokens
- Kept AppColors.text import (still used for positive balance highlighting)

### Test Changes

- `phase11_ux_test.dart`: Updated DocumentHistoryScreen empty state assertion from full text to GhalalEmptyState title
- New: `phase90_push_route_screens_design_system_test.dart` — 6 focused tests covering DocumentHistoryScreen GhalalPageHeader, back button navigation, empty state, header subtitle, and shared patterns

## Verification

```
flutter analyze                           → No issues found
flutter test                              → 1579 passed, 1 skipped, 0 failed
flutter build windows --release           → Built successfully
git diff --check                          → No whitespace issues
```

## Commits

| Type | Hash | Message |
|------|------|---------|
| Implementation | `6c1fcf1` | Phase 90: migrate remaining push-route screens to Ghalal Design System |

## Migration Complete

All non-auth non-print push-route screens are now migrated to the Ghalal Design System. The only remaining unmigrated screens are:
- Login/FirstOwnerSetup (auth — excluded by design)
- Print views (Wave 5 — deferred)
- ReportsScreen (embedded in hub — low priority, uses GhalalPageHeader already)
