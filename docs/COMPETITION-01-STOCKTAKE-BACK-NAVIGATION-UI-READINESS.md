# COMPETITION-01 — Stocktake Back Navigation and Competition UI Readiness

## Owner authorization and purpose

COMPETITION-01 is the first narrowly scoped competition-readiness remediation.
The owner authorized a visible return control on the stocktake screen, focused
navigation/UI coverage, same-screen contrast correction only where evidence
confirmed it, this record, verification, and one limited commit. It adds no
business feature and is not the final competition package; a later separately
authorized competition-packaging step is still required.

The AI Build Week remains closed at BUILD-21. The AI inventory remains 12
caller-supplied actions. COMPETITION-01 adds no AI action, does not alter AI
composition, and does not implement Split Payments.

## Verified baseline and protected state

- Baseline: `6c092507f47177cfc09cc5ee8abed5b6b7f53b30` —
  `BUILD-21: freeze AI action discovery and caller composition`.
- Preflight had only inherited modified
  `lib/features/financial_reports/advances_and_refunds_report_screen.dart`
  and untracked `.build-diagnostics/`.
- Protected file SHA-256:
  `A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`; working
  tree Git blob: `22800a9ccb08ee5796f0fa69c87bd9995739adbf`; size: 32,418
  bytes; inherited modified and unstaged.

## Observed defect and route evidence

The owner screenshot showed `جرد المخزون` with the real no-active-products
state, but without an on-screen return control. The screen is
`lib/features/inventory/stock_take_screen.dart`. `InventoryScreen` opens it
through `Navigator.of(context).push(MaterialPageRoute(...))`, passing the
existing inventory controller. The prior screen is therefore the immediate
inventory context and the correct return is a single pop, not a new inventory
route or a dashboard reset.

The stocktake screen had a header inside a `ListView` but no local navigation
control. Its empty, loading, validation-error, and populated branches appear
below that header, explaining why no visible control existed in the owner's
empty state. Dashboard-shell stocktake selection has its separate shell-level
return pattern; this remediation addresses the pushed inventory route.

## Implementation

The stocktake header now uses the established shared `PageBackButton`, wrapped
in the Arabic `رجوع` tooltip. The shared control uses `Navigator.maybePop`, so
it pops only the current stocktake route when entered from Inventory and does
not clear history, make a duplicate Inventory screen, or close the app.

The button is before the title in the unconditionally built header, so it does
not depend on products, form fields, repository results, validation state, or
the apply operation. Its existing arrow icon is direction-aware
(`matchTextDirection`), and the Arabic button label plus tooltip provide a
visible accessibility name in RTL.

## Empty state, unsaved data, contrast, and safety

The existing empty-state message remains unchanged and the active-product rule
is unchanged. The screen has editable actual-count text fields but no existing
dirty-state/leave-confirmation contract or route interception. System back
therefore already pops the pushed route; the visible control intentionally
uses the identical `maybePop` behavior and does not save, discard, or write.

Inspection confirmed the subtitle used the light-only global
`AppColors.mutedText`, which has inadequate contrast against the dark preset.
Only this header was corrected: title uses the active theme's `onSurface` and
subtitle uses its `onSurfaceVariant`. No global theme, preference, or other
screen was changed.

No stocktake calculation, variance, product activation rule, inventory write,
ledger behavior, permission, transaction, audit log, financial-account,
backup, schema, or migration behavior changed.

## Files and test coverage

- `lib/features/inventory/stock_take_screen.dart` — header-only visible return
  control and theme-semantic title/subtitle colors.
- `test/phase49a_stock_take_test.dart` — real Inventory-to-StockTake route
  coverage for empty and populated states, Arabic tooltip, RTL-aware icon,
  one-route pop, no duplicate inventory route, no navigation-caused write,
  validation-state visibility, and dark-preset header colors.
- This document.

Existing Phase 49A validation/calculation/write tests and Phase 67 navigation
coverage remain part of the regression verification.

## Verification and closure

Focused verification passed:

- `flutter test test\\phase49a_stock_take_test.dart --reporter compact` — 21
  tests passed.
- `flutter test test\\inventory_test.dart test\\product_catalog_test.dart
  test\\phase49b_stock_adjustment_report_test.dart
  test\\phase67_navigation_theme_branding_test.dart --reporter compact` — 59
  tests passed.

Required regression verification passed:

- `flutter test --reporter compact` — 1,447 tests passed with 1 existing
  expected skip.
- `flutter analyze --no-pub` — no issues.
- `C:\\src\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe analyze` — no issues.
- `git diff --check` — no errors.
- Windows release command:
  `C:\\src\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe C:\\src\\flutter\\packages\\flutter_tools\\bin\\flutter_tools.dart build windows --release`.
  It exited 0 and produced
  `C:\\dev\\multi-pos\\grain-warehouse-erp-lite\\build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe`
  (785,408 bytes; 2026-07-19 17:15:36 local time). The existing Firebase CMake
  deprecation and MSVCRT `LNK4078` warnings were non-blocking.

The closure commit is `COMPETITION-01: restore stocktake back navigation`.
Only the stocktake screen, its focused test file, and this record are staged.
The protected report screen remains unchanged and unstaged; `.build-diagnostics/`
remains untracked and untouched. No tag or push is authorized or created.
