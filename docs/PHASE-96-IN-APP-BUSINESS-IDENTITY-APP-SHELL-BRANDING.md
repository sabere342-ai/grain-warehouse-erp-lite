# Phase 96 — In-App Business Identity & Application-Shell Branding

## Governance

- **Previous verified phase:** Phase 95 — Business Profile Expansion & Document Identity Completion
- **Starting branch:** `phase-95-business-profile-expansion-document-identity`
- **Starting HEAD:** `c2b82e8`
- **Previous tag:** `phase-95-business-profile-expansion-document-identity-verified`
- **Previous tag type:** annotated
- **Previous tag target:** `c2b82e86a258c87eb616c6104cf0918cf14317d0`
- **Starting tree:** clean
- **Phase 96 reservation:** no prior reservation found in docs or tags

## Final Phase Name

Phase 96 — In-App Business Identity & Application-Shell Branding

## Discovery

### Identity Surface Inventory

| Surface | Location | Identity Displayed | Dynamic? | Notes |
|---------|----------|-------------------|----------|-------|
| OS window title | `grain_warehouse_app.dart:96` | `displayName` | ✓ | Already dynamic via `MaterialApp.title` |
| Login heading | `login_screen.dart:61` | `displayName` | ✓ | Fixed warehouse icon (intentional) |
| AppBar title + logo | `dashboard_shell.dart:155` | Logo + `displayName` + section | ✓ | Already dynamic |
| Mobile drawer header | `dashboard_shell.dart:347` | `displayName` + subtitle | ✓ | Hardcoded subtitle "إدارة مخازن الحبوب" |
| Desktop sidebar | `dashboard_shell.dart:281` | **None** | — | **Gap filled in this phase** |
| Dashboard page header | `dashboard_screen.dart:96` | **Hardcoded "غلال"** | ✗ | **Fixed in this phase** |
| Settings identity | `settings_screen.dart:79` | Edit form | ✓ | Full CRUD |
| Settings logo | `settings_screen.dart:150` | Logo upload/preview | ✓ | Full lifecycle |
| Settings profile details | `settings_screen.dart:432` | Tax/addr/phone fields | ✓ | Full CRUD |
| Print document header | `printable_document_scaffold.dart:63` | Logo + name + addr + phone | ✓ | Full identity |
| PDF export header | `pdf_branding_header.dart:8` | Logo + name + details | ✓ | Shared component |

### Architecture Flow

```
BusinessIdentityRepository (JSON persistence)
  → BusinessIdentityController (ChangeNotifier)
    → BusinessIdentityScope (InheritedNotifier)
      → MaterialApp.title (dynamic window title)
      → LoginScreen (dynamic heading)
      → DashboardShell (AppBar logo + name)
      → DesktopNavigationSidebar (NEW: compact identity header)
      → MobileNavigationDrawer (shared component)
      → DashboardScreen (dynamic page header - FIXED)
      → SettingsScreen (CRUD + NEW: preview)
      → PrintableDocumentScaffold (document branding)
      → PdfBrandingHeader (PDF branding)
```

### Design System Tokens Used

- `AppSpacing.xxs/xs/sm/md/lg/xl` — all vertical/horizontal spacing
- `AppIconSizes.md/lg/hero` — logo sizing
- `AppComponentSizes.desktopSidebarWidth` — sidebar width
- `AppRadius.md` — rounded corners
- `AppBreakpoints` — responsive layout decisions

## Scope

### Files Added
- `lib/shared/widgets/business_identity_header.dart` — reusable identity component
- `test/phase96_in_app_business_identity_app_shell_branding_test.dart` — 10 focused tests

### Files Modified
- `lib/features/dashboard/dashboard_shell.dart` — desktop sidebar identity header, mobile drawer uses shared component
- `lib/features/dashboard/dashboard_screen.dart` — dynamic `displayName` replaces hardcoded "غلال"
- `lib/features/settings/settings_screen.dart` — read-only identity preview card

### Files Unchanged
- `lib/app/grain_warehouse_app.dart` — already dynamic (`MaterialApp.title`)
- `lib/features/auth/login_screen.dart` — already uses dynamic `displayName`
- `lib/features/auth/first_owner_setup_screen.dart` — correctly defers to Settings
- `lib/core/business_identity/` — no model changes needed
- `lib/features/exports/` — no PDF changes needed
- `lib/features/prints/` — no print changes needed

## Reusable Component Design

### BusinessIdentityHeader

A `StatelessWidget` accepting:
- `identity` (optional, falls back to `BusinessIdentityScope`)
- `subtitle` (optional, displayed below name)
- `compact` (bool, for sidebar vs drawer)
- `showLogo` (bool, default true)

Two internal modes:
- **`_CompactIdentity`** — horizontal row, logo + single-line name, for sidebar
- **`_StandardIdentity`** — vertical column, logo + name + subtitle, for drawer

Logo loaded via `FutureBuilder` from `AppRepositories.businessIdentityRepository.loadLogoBytes()`.

### Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Shell identity location | AppBar + sidebar header | Consistent with existing AppBar pattern |
| Desktop sidebar identity | Compact header above nav | Minimal space, persistent visibility |
| Mobile drawer identity | Standard header with subtitle | Full branding surface |
| Dashboard header | Dynamic displayName in page header | Fixes hardcoded inconsistency |
| Settings preview | Read-only card between name and logo | Shows current state without clutter |
| Subtitle in shell | "إدارة مخازن الحبوب" (product description) | Not brand name — consistent product descriptor |
| Login screen icon | Fixed warehouse icon (unchanged) | Auth-appropriate, not brand-specific |

## Shell Integration

### Desktop Sidebar
- Added `Column` with `BusinessIdentityHeader(compact: true)` + `Divider` + `Expanded(ListView)`
- Identity header at top with logo + display name
- Subtitle "إدارة مخازن الحبوب" below name
- Navigation list below divider

### Mobile Drawer
- Replaced inline `Column(Icon + Text + Text)` with `BusinessIdentityHeader(subtitle: ...)`
- Same visual result, shared component
- Drawer structure preserved: header → divider → navigation list

### AppBar
- **No changes** — already shows logo + displayName + section name
- `_AppBarLogo` widget kept for AppBar-specific sizing (32h × 80w)

## Dashboard Integration

- Replaced hardcoded `const GhalalPageHeader(title: 'لوحة متابعة غلال', ...)` with `Builder` that reads `BusinessIdentityScope.maybeOf(context)?.identity.displayName`
- Falls back to `BusinessIdentity.defaultDisplayName` when scope unavailable
- Dynamic title updates when name changes (via `AnimatedBuilder` rebuild chain)

## Settings Integration

- Added "معاينة الهوية" (Identity Preview) card between establishment name and logo sections
- Shows `BusinessIdentityHeader(identity: identityController.identity)` in a styled container
- Read-only preview — updates reactively when identity changes
- Uses `surfaceContainerHighest` color for visual distinction

## Authentication/Onboarding Decision

- **Login screen**: No changes — already uses `displayName` dynamically
- **First-owner setup**: No changes — correctly defers identity configuration to Settings
- **Auth gate**: No changes — identity routing unaffected

## Runtime Application-Title Decision

- `MaterialApp.title` already set to `displayName` in `grain_warehouse_app.dart:96`
- Already wrapped in `AnimatedBuilder` — updates live when identity changes
- No changes needed

## Native Application-Icon Decision

- **Out of scope** — documented as separate future phase
- Current Windows icon is static, bundled at build time
- Dynamic icon from user logo would require native platform code, shortcut recreation, OS-specific behavior
- Settings screen already notes: "أيقونة تطبيق Windows تحدد أثناء تجهيز وبناء النسخة ولا تتغير من داخل البرنامج"

## Logo Loading and Fallback

- `BusinessIdentityHeader` uses `_IdentityLogo` widget with `FutureBuilder`
- Loads bytes from `AppRepositories.businessIdentityRepository.loadLogoBytes(managedFileName)`
- Returns `SizedBox.shrink()` on null/error — never crashes
- Same pattern as existing `_AppBarLogo` and `_LogoPreview` widgets
- No caching beyond Flutter's default image cache — acceptable for small logo files

## Reactive Profile-Update Behavior

- `BusinessIdentityController` extends `ChangeNotifier`
- `BusinessIdentityScope` is `InheritedNotifier` — rebuilds dependent widgets on notification
- `GrainWarehouseApp` wraps `MaterialApp` in `AnimatedBuilder` listening to controller
- Shell reads identity via `BusinessIdentityScope.maybeOf(context)` — rebuilds on change
- Settings preview uses same controller — updates immediately on save
- Dashboard header uses `Builder` + `BusinessIdentityScope.maybeOf(context)` — updates on rebuild

## Accessibility and RTL

- All UI is Arabic RTL (`Directionality(TextDirection.rtl)` wraps `MaterialApp`)
- `BusinessIdentityHeader` does not set directionality — inherits from ancestor
- Text overflow handled via `TextOverflow.ellipsis` and `maxLines: 1` in compact mode
- Long names wrap naturally in standard mode
- Semantic labels inherited from parent widgets

## Tests

### New Tests (10)
- `BusinessIdentityHeader`: name+logo, name-only, fallback, subtitle, compact, long name overflow, narrow width, scope read (8 tests)
- Dashboard identity: dynamic brand name, default name fallback (2 tests)

### Existing Regression
- Phase 95 business profile: 32/32 passed
- Competition05 document preview: 4/4 passed

### Full Suite
- **Passed:** 1685
- **Skipped:** 1
- **Failed:** 0

## Verification

### dart format
- All modified files formatted, 0 issues remaining

### flutter analyze
- **0 errors**
- **0 warnings from Phase 96** (9 pre-existing infos in test files)

### Windows Release Build
- **Exit code:** success
- **Artifact:** `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`
- **Pre-existing warnings only** (CMake deprecation, LNK4078)

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
- No PDF layout changes
- No filename changes
- No content label changes
- No app icon changes
- No authentication changes
- No accounting changes

## Git

- **Branch:** `phase-96-in-app-business-identity-app-shell-branding`
- **Implementation commit:** (pending)
- **Closure commit:** (this document)
- **Tag:** `phase-96-in-app-business-identity-app-shell-branding-verified`
- **Tag type:** annotated
- **Tag target:** (Final HEAD)
- **Final HEAD:** (after closure commit)
- **Working tree:** clean
- **Push performed:** No

## Out of Scope

- Dynamic user-selected Windows executable icons
- Runtime taskbar icon generation
- Android or iOS launcher icon replacement
- Installer branding overhaul
- Multi-establishment support
- Cloud storage
- User accounts redesign
- Authentication redesign
- Login security changes
- PDF redesign
- Backup-version changes
- Database migrations
- Tax authority integration
- Electronic invoicing
- QR-code compliance
- Receipt-printer support
- New financial reports
- Accounting changes
- Stock or transaction changes
- Dashboard card redesign
- Theme-builder redesign
- Arbitrary accent-color customization

## Residual Risks

1. `BusinessIdentityHeader` logo loading uses `FutureBuilder` without explicit caching — acceptable for small logo files in shell context
2. Desktop sidebar identity header adds ~48px height to sidebar — minimal impact on navigation space
3. Dashboard `Builder` widget adds one extra widget layer — negligible performance impact

## Recommended Next Phase

- Phase 97 — per Roadmap priorities (document validation, advanced backup features, reporting enhancements, or native icon feasibility study)
