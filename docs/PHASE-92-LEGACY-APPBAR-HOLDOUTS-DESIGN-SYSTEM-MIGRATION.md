# Phase 92 — Legacy AppBar Holdouts Design-System Migration

## Governance Evidence

| Item | Value |
|------|-------|
| Previous phase | Phase 91 — Printable Document Scaffold |
| Previous branch | `phase-91-printable-document-scaffold-design-system-migration` |
| Previous expected HEAD | `acd3a47` |
| Previous actual HEAD | `acd3a47` ✓ |
| Previous tag | `phase-91-printable-document-scaffold-verified` |
| Previous tag type | annotated (`tag`) ✓ |
| Previous tag target | `acd3a47` ✓ |
| Starting tree | clean ✓ |

## Phase 92 Inventory

### Included (migrated)

| # | File | Migration |
|---|------|-----------|
| 1 | `lib/features/suppliers/supplier_advance_actions_screen.dart` | AppBar → GhalalPageHeader |
| 2 | `lib/features/customers/customer_advance_actions_screen.dart` | AppBar → GhalalPageHeader |

### Excluded

| # | File | Reason |
|---|------|--------|
| 1 | `lib/features/dashboard/dashboard_shell.dart` | Main navigation shell, not a page screen |
| 2 | `lib/features/auth/login_screen.dart` | No AppBar, excluded per spec |
| 3 | `lib/features/auth/first_owner_setup_screen.dart` | No AppBar, excluded per spec |

## Changes

Both screens received identical migration:
- Removed `appBar: AppBar(leadingWidth: 112, leading: AppBarBackButton(), title: Text(...))` from Scaffold
- Removed unused `page_back_button.dart` import
- Replaced content-level `GhalalPageHeader` with page-level header including `onBack: () => Navigator.of(context).maybePop()` and entity name as title
- Zero financial logic changes

## Tests Added

20 focused tests across both screens:

| # | Test | Screen |
|---|------|--------|
| 1 | GhalalPageHeader present | Supplier |
| 2 | No AppBar present | Supplier |
| 3 | Back button exists | Supplier |
| 4 | Back button tooltip matches | Supplier |
| 5 | Back button pops navigation | Supplier |
| 6 | Title shows supplier name | Supplier |
| 7 | Main action button visible | Supplier |
| 8 | No overflow on compact viewport | Supplier |
| 9 | Scroll reveals list content | Supplier |
| 10 | RTL text direction preserved | Supplier |
| 11 | GhalalPageHeader present | Customer |
| 12 | No AppBar present | Customer |
| 13 | Back button exists | Customer |
| 14 | Back button tooltip matches | Customer |
| 15 | Back button pops navigation | Customer |
| 16 | Title shows customer name | Customer |
| 17 | Main action button visible | Customer |
| 18 | No overflow on compact viewport | Customer |
| 19 | Loading state renders | Customer |
| 20 | Empty state renders | Customer |

## Full-Suite Result

| Metric | Value |
|--------|-------|
| Passed | 1613 |
| Skipped | 1 |
| Failed | 1 (pre-existing `phase8d` flaky) |

## Analyzer Result

| Level | Count | Source |
|-------|-------|--------|
| error | 0 | — |
| warning | 5 | pre-existing Phase 90/91 test files |

## Windows Build

SUCCESS — `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`

## Diff Review

- 2 files modified in lib: supplier + customer advance actions screens
- 1 file added in test: `phase92_legacy_appbar_holdouts_design_system_test.dart`
- No financial calculations changed
- No schema changed
- No backup/restore changed

## Production Behavior Statement

Both supplier advance actions and customer advance actions screens now use the Ghalal design-system page header instead of the legacy AppBar. The back button behavior, entity name display, and all financial action functionality are preserved. Visual change is limited to header styling matching the design system.

## Schema Statement

No database schema changes.

## Backup/Restore Statement

No backup/restore contract changes.

## Known Residuals

1. 5 pre-existing analyzer warnings from Phase 90/91 test files
2. 1 flaky test in full suite (`phase8d_durable_supplier_repository_test.dart`) — passes individually
3. `dashboard_shell.dart` remains with legacy AppBar (main navigation shell, intentionally excluded)

## Remaining Legacy AppBar

After Phase 92, the only remaining legacy AppBar is `dashboard_shell.dart` (main navigation shell).

## Next Recommended Phase

- **Phase 93**: Login / FirstOwnerSetup screens design-system migration (if needed — currently no AppBar present)
- Optional: Business Identity & Printable Document Branding
