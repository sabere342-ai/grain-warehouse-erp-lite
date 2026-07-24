# Phase 89 — Settings & Utilities Wave 4 Design-System Migration

## Status

- Phase 89 is **CLOSED** on `phase-89-settings-utilities-design-system-migration`.
- Implementation commit: `92cf11f`.
- Closure commit: the commit containing this document.
- Annotated tag: `phase-89-settings-utilities-design-system-migration-verified` pointing at the remediation commit (this document).
- Closure date: 2026-07-24.

## Governance

- Previous verified baseline: Phase 88 — `phase-88-complex-financial-reports-design-system-migration-verified` on commit `cc6dd08`.
- Starting branch: `phase-89-settings-utilities-design-system-migration` (HEAD at `cc6dd08`).
- Starting HEAD: `cc6dd081d3f0278550528743930a7ad29d82a158`.
- Previous tag type: `tag` (annotated).
- Previous tag target: `cc6dd08` = HEAD at start.
- Phase 89 number was available: not reserved anywhere in the repository.
- Roadmap evidence: Phase 83 roadmap wave 4 lists settings, backup/restore, data wipe, audit logs, help.

## Scope rationale

Phase 83 roadmap wave 4 lists: "الإعدادات — Settings, restore, audit."

Phase 89 migrates the remaining settings and utility screens to the Ghalal design system. All 6 screens in scope have been migrated: SettingsScreen (embedded in shell), BackupExportScreen, BackupRestorePreviewScreen, DataWipeScreen, AuditLogsScreen (embedded in shell), and HelpGuideScreen.

### Wave 4 items — final status

| Item | Status after Phase 89 |
|---|---|
| SettingsScreen | **Migrated (Phase 89)** |
| BackupExportScreen | **Migrated (Phase 89)** |
| BackupRestorePreviewScreen | **Migrated (Phase 89)** |
| DataWipeScreen | **Migrated (Phase 89)** |
| AuditLogsScreen | **Migrated (Phase 89)** |
| HelpGuideScreen | **Migrated (Phase 89)** |

**Wave 4 settings & utilities is now COMPLETE (6/6 screens).**

### Remaining roadmap items

- Wave 5: Invoice/statement/report printing and preview redesign.
- Daily report: separate wave item, deferred.
- Business identity editor: deferred to separate wave.

## Screen-by-screen audit

### SettingsScreen

- File: `lib/features/settings/settings_screen.dart`
- Pre-migration state: Manual title/subtitle, `AppColors.mutedText` for subtitle, raw spacing numbers
- Embedded in: DashboardShell (no own Scaffold)
- Migration: Added `GhalalPageHeader(title: 'الإعدادات', subtitle: ..., icon: Icons.settings_rounded)` — no `onBack` (correct for embedded). Replaced magic spacing numbers with `AppSpacing` tokens.
- Business sensitivity: Low (read/write settings, theme selection, identity name)
- Write actions: Theme changes, establishment name save

### BackupExportScreen

- File: `lib/features/backup/backup_export_screen.dart`
- Pre-migration state: `PageBackButton` + manual title + `AppColors.mutedText` subtitle
- Pushed as: MaterialPageRoute from DashboardScreen
- Migration: `GhalalPageHeader(title: 'النسخ الاحتياطي', ..., icon: Icons.backup_rounded, onBack: () => Navigator.of(context).maybePop())`. Removed `PageBackButton` import. Replaced spacing with `AppSpacing` tokens.
- Business sensitivity: Medium (backup export, data wipe)
- Write actions: Export backup, navigate to restore/wipe

### BackupRestorePreviewScreen

- File: `lib/features/backup/backup_restore_preview_screen.dart`
- Pre-migration state: `PageBackButton` + manual title + `AppColors.mutedText` subtitle
- Pushed as: MaterialPageRoute from BackupExportScreen
- Migration: Same pattern as BackupExportScreen. `GhalalPageHeader` with `onBack`.
- Business sensitivity: High (restore preview)
- Write actions: Restore confirmation

### DataWipeScreen

- File: `lib/features/backup/data_wipe_screen.dart`
- Pre-migration state: `PageBackButton` + manual title + error-colored subtitle
- Pushed as: MaterialPageRoute from BackupExportScreen
- Migration: `GhalalPageHeader` with `onBack`. Subtitle error styling (colorScheme.error, fontWeight: w800) removed — danger is now conveyed by icon (delete_forever_rounded) and screen's own warning text. `AppColors.olive` still used for wipe status indicator.
- Business sensitivity: **CRITICAL** (data destruction)
- Write actions: Business data wipe with confirmation

### AuditLogsScreen

- File: `lib/features/audit/audit_logs_screen.dart`
- Pre-migration state: Manual title/subtitle with `AppColors.mutedText`, manual error/loading/empty states
- Embedded in: DashboardShell (no own Scaffold)
- Migration: `GhalalPageHeader(title: 'سجل التدقيق', ...)` — no `onBack`. Loading → `GhalalLoadingState()`, Empty → `GhalalEmptyState(title: 'لا توجد أحداث تدقيق مسجلة بعد.')`, Error → `GhalalErrorState(message: ..., onRetry: ...)`. Removed unused `textTheme` variable. Removed `AppColors.mutedText` usage.
- Business sensitivity: Medium (read-only audit log)
- Write actions: None

### HelpGuideScreen

- File: `lib/features/help/help_guide_screen.dart`
- Pre-migration state: `Scaffold(appBar: AppBar(leading: AppBarBackButton(), title: Text('دليل الاستخدام')))`
- Pushed as: MaterialPageRoute from DashboardScreen
- Migration: Scaffold retained (tests rely on Scaffold-based scroll behavior for `scrollUntilVisible`). AppBar removed. `GhalalPageHeader(title: 'دليل الاستخدام', subtitle: ..., icon: Icons.help_outline_rounded, onBack: ...)` placed inside Scaffold body as `ListView` child. All `_GuideSection` data preserved with raw Arabic text.
- Business sensitivity: Low (help documentation)
- Write actions: None

## Explicit exclusions

- No business logic changed
- No write actions changed or simplified
- No confirmation dialog flows changed
- No data wipe behavior changed
- No backup/restore contract changed
- No schema or migrations changed
- No permissions or business validation changed
- No shared widgets modified
- No navigation routing changed (embedded screens stay embedded, pushed routes stay pushed)
- DataWipeScreen subtitle error styling removed (conveyed by icon + content instead)

## Shared components changed

None. All Ghalal components used (`GhalalPageHeader`, `GhalalLoadingState`, `GhalalErrorState`, `GhalalEmptyState`, `PremiumCard`, `AppSpacing`) are consumed, not modified.

## Production files changed

- `lib/features/settings/settings_screen.dart`
- `lib/features/backup/backup_export_screen.dart`
- `lib/features/backup/backup_restore_preview_screen.dart`
- `lib/features/backup/data_wipe_screen.dart`
- `lib/features/audit/audit_logs_screen.dart`
- `lib/features/help/help_guide_screen.dart`

## Test files changed

- `test/competition04_dashboard_readiness_test.dart` — back-button finder fix (`find.text` → `find.byTooltip`)
- `test/phase12_help_guidance_test.dart` — reordered assertion to prevent off-screen disposal
- `test/phase67_navigation_theme_branding_test.dart` — back-button finder fix
- `test/phase89_settings_utilities_design_system_test.dart` — **new** 11 focused tests

## Remediation

After the initial implementation, 3 pre-existing test failures surfaced that were caused by the design-system migration:

1. **`competition04` line 158**: `find.text('رجوع')` failed because `GhalalPageHeader` renders an `IconButton(tooltip: 'رجوع')` not a `Text` widget. Fix: `find.byTooltip('رجوع')`.
2. **`phase67` lines 58/60**: Same root cause as above. Fix: `find.byTooltip('رجوع')`.
3. **`phase12` line 60**: `textContaining('حركة عكسية')` found 0 widgets because after scrolling to the last section, the "خطوات_WORK اليومية" section was scrolled far off-screen and Flutter's ListView disposed its widgets. Fix: moved the `textContaining` assertion to earlier in the test (before scrolling past the section).

Additionally, the unused `PageBackButton` import in `competition04` was removed to fix an analyzer warning.

All fixes are test-only except the help_guide_screen.dart Arabic text was confirmed to use raw Arabic (not Unicode escapes) matching codebase convention.

## Verification

### Baseline (on starting HEAD `cc6dd08`)

- Full test suite: 1562 passed, 1 skipped (pre-existing intentional skip in `phase8c`), 0 failed.
- Analyzer: `No issues found!`
- `git diff --check`: passed (CRLF warnings only)
- Working tree: clean

### Post-implementation

- Full test suite: 1573 passed, 1 skipped, 0 failed.
- Analyzer: `No issues found!`
- `git diff --check`: passed (CRLF warnings only)
- `dart format`: all files formatted

### Diff review

- 6 production files in scope modified
- 3 pre-existing test files fixed (test-only changes)
- 1 new test file added (11 focused tests)
- No secrets or sensitive paths introduced
- No out-of-scope files touched
- Schema remains at current version. Backup contract unchanged.
- Diff: 116 insertions, 129 deletions across 9 files (implementation commit); +434 insertions / +129 deletions (implementation commit including test file)

### Windows release build

- Build command: `flutter build windows --release`
- Build result: **SUCCESS**
- Build duration: ~103 seconds
- EXE path: `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Build warnings: `LNK4078: multiple '.voltbl' sections` (pre-existing, benign)
- Exit code: 0

## Implementation commit

- Commit: `92cf11f`
- Message: "Phase 89: settings & utilities wave 4 design-system migration"
- Files: 10 changed, 434 insertions, 129 deletions

## Closure commit

- Commit: the commit containing this document.
- Message: "Close Phase 89 settings & utilities design-system migration"

## Tag evidence

- Tag name: `phase-89-settings-utilities-design-system-migration-verified`
- Tag type: `tag` (annotated)
- Tag target: closure commit = HEAD
- Push performed: No

## Roadmap conclusion

Wave 4 (Settings & Utilities) is now **COMPLETE**. All 6 screens have been migrated to the Ghalal design system. The remaining roadmap items are:
- Wave 5: Printing and preview
- Daily report: separate wave item
- Business identity editor: deferred to separate wave
