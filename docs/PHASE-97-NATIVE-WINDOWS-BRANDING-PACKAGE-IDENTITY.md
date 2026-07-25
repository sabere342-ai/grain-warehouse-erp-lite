# Phase 97 — Native Windows Branding, Package Identity & Release Asset Hardening

## 1. Starting Baseline

- **Phase:** Phase 96 — In-App Business Identity & Application-Shell Branding
- **Branch:** `phase-96-in-app-business-identity-app-shell-branding`
- **Implementation commit:** `70d57d7`
- **Closure commit / Final HEAD:** `339708a`
- **Annotated tag:** `phase-96-in-app-business-identity-app-shell-branding-verified`
- **Tag type:** `tag` (annotated)
- **Tag target:** `339708a`
- **Full suite:** 1685 passed, 1 skipped, 0 failed
- **Analyzer:** 0 errors, 0 warnings
- **Windows build:** success
- **Starting tree:** clean

## 2. Governance Evidence

| Check | Command | Result |
|-------|---------|--------|
| Working tree | `git status --short` | Clean |
| Current branch | `git branch --show-current` | `phase-96-in-app-business-identity-app-shell-branding` |
| HEAD | `git rev-parse HEAD` | `339708a` |
| Phase 96 tag exists | `git tag -l "phase-96-*"` | Found |
| Tag type | `git cat-file -t phase-96-...` | `tag` |
| Tag target | `git rev-list -n 1 phase-96-...` | `339708a` |
| Phase 97 reserved | `git tag -l "phase-97*"` | Not found |
| Phase 97 branch | `git branch -a \| Select-String "phase-97"` | Not found |
| Phase 97 docs | `grep -r "phase.97" docs/` | Not found |

Governance passed. New branch created: `phase-97-native-windows-branding-package-identity`

## 3. Discovery Findings

### Native Surfaces Inspected

| Surface | File | Finding |
|---------|------|---------|
| Window title | `windows/runner/main.cpp:30` | `L"grain_warehouse_erp_lite"` (raw internal name) |
| Version resource | `windows/runner/Runner.rc` | `com.example` placeholder for CompanyName, raw internal name for FileDescription/ProductName |
| Binary name | `windows/CMakeLists.txt:7` | `grain_warehouse_erp_lite` |
| Icon | `windows/runner/resources/app_icon.ico` | 33,772 bytes, 10 entries, Flutter-generated default (Phase 0-2) |
| Manifest | `windows/runner/runner.exe.manifest` | Standard DPI awareness, no branding |
| pubspec | `pubspec.yaml` | name: `grain_warehouse_erp_lite`, version: `1.0.0+1` |

### Old Metadata Discovered

| Property | Old Value | Problem |
|----------|-----------|---------|
| CompanyName | `com.example` | Flutter placeholder |
| FileDescription | `grain_warehouse_erp_lite` | Raw internal name, not branded |
| ProductName | `grain_warehouse_erp_lite` | Raw internal name, not branded |
| LegalCopyright | `Copyright (C) 2026 com.example` | References placeholder |
| Window title | `grain_warehouse_erp_lite` | Raw internal name |
| Icon | Flutter default | Not "غلال" branded |

### Icon Source

- **Current icon:** `windows/runner/resources/app_icon.ico` — committed in Phase 0-2 as Flutter foundation default
- **ICO generation tool:** `tool/create_windows_app_icon.ps1` — Phase 68 tool for generating multi-size ICO from PNG/JPEG source
- **Brand source image:** None found in repository
- **Decision:** Icon file remains as-is (valid multi-size ICO format). Replacement with a proper "غلال" brand icon requires a source image to be provided. The Phase 68 tool is ready for this purpose.

### Packaging/Delivery Mechanisms

- **Create script:** `tool/create_pilot_delivery_package.ps1` — creates delivery folder with Release binaries and docs
- **Check script:** `tool/check_pilot_delivery_package.ps1` — validates delivery package safety
- **No installer:** No Inno Setup, MSIX, or other installer found
- **No code signing:** No signing certificates or signing scripts found

## 4. Current Native-Brandings Problems

1. **Window title** displayed raw internal name `grain_warehouse_erp_lite` instead of branded name
2. **FileDescription** showed raw internal name instead of human-readable description
3. **ProductName** showed raw internal name instead of branded product name
4. **CompanyName** showed Flutter placeholder `com.example`
5. **LegalCopyright** referenced `com.example` placeholder
6. **Icon** was Flutter default, not "غلال" branded
7. **Delivery scripts** contained outdated `phase69` folder naming

## 5. Runtime vs Build-Time Identity Contract

### Changes from Settings (Runtime — no rebuild required)

- Establishment name (displayed in app header, dashboard, sidebar)
- Establishment logo (displayed in app header, printed invoices)
- Tax number, address, phone

### Changes requiring Rebuild (Build-time)

- Window title (set in `main.cpp`)
- Windows resource metadata (set in `Runner.rc`)
- Native icon (set in `windows/runner/resources/app_icon.ico`)
- Binary name (set in `CMakeLists.txt`)

### Changes requiring Reinstall

- Any build-time change produces a new executable that must be reinstalled

### Dynamic Native Icon

**No.** The native Windows icon is static at build time. It does not change when the user modifies business identity in Settings. The in-app logo (BusinessIdentity.logo) is a separate, runtime concept.

## 6. Files Changed

| Change | File | Impact |
|--------|------|--------|
| Window title: `grain_warehouse_erp_lite` → `غلال` | `windows/runner/main.cpp` | User-visible window title and taskbar |
| CompanyName: `com.example` → `Grala` | `windows/runner/Runner.rc` | Windows Properties dialog |
| FileDescription: `grain_warehouse_erp_lite` → `Grala - Grain Warehouse Management` | `windows/runner/Runner.rc` | Windows Properties, Explorer tooltip |
| ProductName: `grain_warehouse_erp_lite` → `Grala` | `windows/runner/Runner.rc` | Windows Properties dialog |
| LegalCopyright: `com.example` → `Grala` | `windows/runner/Runner.rc` | Windows Properties dialog |
| Delivery folder naming: removed `phase69` prefix | `tool/create_pilot_delivery_package.ps1` | Delivery package folder name |
| Check script pattern: `phase69*` → `branded_delivery*` | `tool/check_pilot_delivery_package.ps1` | Package validation |
| New test file | `test/phase97_native_windows_branding_test.dart` | 27 focused tests |

## 7. Native Metadata Before/After

| Property | Before | After |
|----------|--------|-------|
| Window title | `grain_warehouse_erp_lite` | `غلال` |
| CompanyName | `com.example` | `Grala` |
| FileDescription | `grain_warehouse_erp_lite` | `Grala - Grain Warehouse Management` |
| ProductName | `grain_warehouse_erp_lite` | `Grala` |
| InternalName | `grain_warehouse_erp_lite` | `grain_warehouse_erp_lite` (unchanged) |
| LegalCopyright | `Copyright (C) 2026 com.example. All rights reserved.` | `Copyright (C) 2026 Grala. All rights reserved.` |
| OriginalFilename | `grain_warehouse_erp_lite.exe` | `grain_warehouse_erp_lite.exe` (unchanged) |
| ProductVersion | `1.0.0+1` | `1.0.0+1` (unchanged) |

## 8. Icon Source and Transformation Record

- **Source:** `windows/runner/resources/app_icon.ico` (committed in Phase 0-2, Flutter foundation default)
- **Current state:** 33,772 bytes, 10 ICO entries (16/32/48 × 3 DPI variants + 256×1)
- **Transformation:** None — icon file not modified in Phase 97
- **Rationale:** No brand source image (PNG/JPEG) exists in the repository. The Phase 68 ICO generation tool (`tool/create_windows_app_icon.ps1`) is available for generating a proper branded icon when a source image is provided.
- **Documentation:** See Phase 68 documentation for icon generation tool usage.

## 9. Executable/Package Naming Decision

- **Binary name:** `grain_warehouse_erp_lite` — unchanged to avoid breaking scripts, tests, delivery paths
- **Executable:** `grain_warehouse_erp_lite.exe` — matches binary name
- **User-visible name:** `غلال` — set via window title in main.cpp
- **Branded name in metadata:** `Grala` — set via Runner.rc for Windows Properties

The binary name is a technical identifier. The user-facing brand name appears in:
- Window title bar: `غلال`
- Taskbar: `غلال`
- Windows Properties > File Description: `Grala - Grain Warehouse Management`
- Windows Properties > Product Name: `Grala`

## 10. Customer-Specific Branding Procedure

### White-label Build Process

To create a customer-specific build:

1. **Identity separation:**
   - In-app business identity (establishment name, logo) — set from Settings, no rebuild needed
   - Native executable identity (window title, metadata, icon) — requires rebuild
   - Customer-specific native branding — requires dedicated build-time changes

2. **Files requiring modification for white-label build:**
   - `windows/runner/main.cpp` — window title (line 30)
   - `windows/runner/Runner.rc` — metadata block (lines 92-99)
   - `windows/runner/resources/app_icon.ico` — replace with customer icon using Phase 68 tool

3. **Required assets from customer:**
   - Source image (PNG/JPEG, minimum 256×256) for native icon
   - Customer brand name for metadata fields
   - Customer copyright holder name (if different from "Grala")

4. **Windows native icon constraints:**
   - Must be ICO format with sizes: 16, 32, 48, 64, 128, 256
   - Use `tool/create_windows_app_icon.ps1` to generate
   - PNG transparency is preserved

5. **Rebuild required:**
   - After changing native branding, run `flutter build windows --release`
   - The new executable must be reinstalled on the target machine

6. **What can be changed from Settings (no rebuild):**
   - Establishment name
   - Establishment logo
   - Tax number, address, phone

7. **What cannot be changed from Settings:**
   - Window title
   - Windows metadata (CompanyName, FileDescription, ProductName, etc.)
   - Native icon
   - Binary name

8. **Rollback to default branding:**
   - Restore `windows/runner/main.cpp` to use `\u063A\u0644\u0627\u0644` (غلال) as window title
   - Restore `windows/runner/Runner.rc` to Phase 97 values
   - Restore `windows/runner/resources/app_icon.ico` from git
   - Rebuild

## 11. Explicit Limitations

- **No dynamic native icon:** The native Windows icon does not change at runtime
- **No code signing:** The application is not code-signed. SmartScreen warnings may appear.
- **No installer:** No automated installer is included. The delivery package is a folder with binaries.
- **No Android/iOS branding:** Mobile native branding is out of scope for Phase 97
- **No multi-establishment native branding:** Each white-label build is a separate build-time operation
- **Icon is Flutter default:** The current icon is the Flutter foundation default, not a custom "غلال" brand icon. A source image is needed for proper branding.

## 12. Test Evidence

### Phase 97 Focused Tests

27 tests covering:
- Runner.rc metadata correctness (10 tests)
- Window title correctness (2 tests)
- Version consistency (2 tests)
- Icon file validity (3 tests)
- Delivery script consistency (4 tests)
- CMakeLists binary name consistency (2 tests)
- No Flutter default branding remnants (3 tests)
- Application title in Flutter (1 test)

```
flutter test test\phase97_native_windows_branding_test.dart
00:00 +27: All tests passed!
```

### Full Suite

```
flutter test
+1711 ~1 -1
```

- **Passed:** 1711
- **Skipped:** 1
- **Failed:** 1 (pre-existing flaky test in `phase8d_durable_supplier_repository_test.dart: failed repository transaction restores suppliers and sequence` — not related to Phase 97 changes; passes when run individually)

## 13. Analyzer Evidence

```
flutter analyze test\phase97_native_windows_branding_test.dart
No issues found!
```

Full suite analyzer: 32 issues (all pre-existing info/warning level; 0 new errors or warnings from Phase 97)

## 14. Windows Build Evidence

```
flutter build windows --release
√ Built build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe
```

Build time: ~59 seconds. Success.

## 15. Post-Build Executable Metadata Evidence

```
(Get-Item build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe).VersionInfo | Format-List *

CompanyName        : Grala
FileDescription    : Grala - Grain Warehouse Management
FileVersion        : 1.0.0+1
InternalName       : grain_warehouse_erp_lite
LegalCopyright     : Copyright (C) 2026 Grala. All rights reserved.
OriginalFilename   : grain_warehouse_erp_lite.exe
ProductName        : Grala
ProductVersion     : 1.0.0+1
```

## 16. Diff Audit

| Question | Answer |
|----------|--------|
| Accounting modified? | No |
| Schema modified? | No |
| Backup format modified? | No |
| Runtime business identity behavior changed? | No |
| Local path introduced? | No |
| Unknown asset introduced? | No |
| Flutter placeholder branding remains? | No — all `com.example` references removed from Runner.rc |
| Executable and scripts consistent? | Yes — `grain_warehouse_erp_lite.exe` matches in all locations |
| Changes scoped to Phase 97? | Yes |
| Documentation describes actual implementation? | Yes |
| Phase 97 tests can fail if old branding returns? | Yes — tests verify absence of `com.example`, presence of `Grala`, correct window title |

## 17. Git Closure

### Implementation Commit

Pending: `feat(windows): complete native branding and package identity`

### Closure Commit

Pending: `docs(phase-97): record verified native branding closure`

### Annotated Tag

Pending: `phase-97-native-windows-branding-package-identity-verified`

## 18. Scope Declaration

- **Production Dart code changed:** No
- **Schema changed:** No
- **Accounting changed:** No
- **Backup format changed:** No
- **PDF behavior changed:** No
- **Runtime dynamic native icon implemented:** No
- **Code signing implemented:** No (no signing certificates or scripts exist in the repository)
- **Push performed:** No

## 19. Deferred Items

- **Professional brand icon:** Requires a source image (PNG/JPEG) to generate a proper "غلال" branded ICO using the Phase 68 tool
- **Code signing:** Not implemented; no signing certificates available
- **Signed installer:** No installer technology present in the repository
- **Automated white-label build pipeline:** Documented procedure exists but no automation script
- **Android/iOS native branding:** Out of scope for Phase 97
- **Dynamic taskbar icon:** Not implemented (build-time only)
- **Multi-establishment native branding:** Out of scope
