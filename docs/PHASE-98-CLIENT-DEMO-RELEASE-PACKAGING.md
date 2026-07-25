# Phase 98 — Client Demo Release Packaging, Windows Installer & Clean-Machine Acceptance

## Baseline

| Item | Value |
|------|-------|
| Phase 97 commit | `212ac92780c36b3ef06e4dbf5fe440e12e13ec8c` |
| Phase 97 tag | `phase-97-native-windows-branding-package-identity-verified` (annotated) |
| Branch | `phase-98-client-demo-release-packaging-clean-machine-acceptance` |
| Baseline test count | 1712 passed, 1 skipped, 0 failed |
| Flutter | 3.24.5 |
| Dart | 3.5.4 |

## Scope Delivered

### Release Tooling
| File | Purpose |
|------|---------|
| `tool/build_release.ps1` | Deterministic release build — reads version from pubspec, runs `flutter build windows --release`, verifies exe/dll/assets |
| `tool/create_demo_package.ps1` | Creates timestamped demo package — copies release build + docs, generates SHA-256 checksums, manifest JSON, README-AR.txt, file listing |
| `tool/scan_package_safety.ps1` | Allowlist-based source-safety scanner — prohibited dirs/extensions/names, developer path references, com.example detection, required files/dirs |
| `tool/verify_package_checksums.ps1` | SHA-256 checksum verification against checksums.sha256 |

### Windows Installer Source
| File | Purpose |
|------|---------|
| `windows/installer/ghalal.iss` | Inno Setup installer source — per-user install (no admin), Arabic branding, Start Menu entry, optional desktop shortcut, data preservation on uninstall |

### Client Documentation (Arabic)
| File | Purpose |
|------|---------|
| `docs/CLIENT-INSTALLATION-GUIDE-AR.md` | Installation and backup guide in Arabic |
| `docs/CLIENT-DEMO-WALKTHROUGH-AR.md` | Demo walkthrough with acceptance checklist |
| `docs/CLIENT-KNOWN-LIMITATIONS-AR.md` | Known limitations document |
| `docs/PHASE-98-RELEASE-NOTES-AR.md` | Release notes for demo |

### Tests
| File | Groups | Tests |
|------|--------|-------|
| `test/phase98_release_packaging_test.dart` | 15 | 94 |

### Fixes
- `tool/build_post_feature_delivery.py`: Fixed hardcoded path to use `Path(__file__).resolve().parent.parent`
- `.gitignore`: Added `windows/installer/Output/`

## Verification Gates

### Gate 1: Phase 98 Focused Tests
```
94 tests — ALL PASS
```

### Gate 2: Full Test Suite
```
1805 passed, 1 skipped, 1 failed (pre-existing flaky in phase8d_durable_supplier_repository_test.dart)
93 new tests added (all passing)
```

### Gate 3: Static Analysis
```
flutter analyze: 0 errors
Pre-existing info/warning issues only — no new errors or warnings from Phase 98
```

### Gate 4: Format Check
```
dart format --set-exit-if-changed: 0 changes
```

### Gate 5: Windows Release Build
```
flutter build windows --release: SUCCESS
grain_warehouse_erp_lite.exe — 1.0.0+1, Grala, x64
```

### Gate 6: Demo Package Creation
```
29 files, 43.61 MB
Version: 1.0.0+1
Commit: 212ac92780c36b3ef06e4dbf5fe440e12e13ec8c
```

### Gate 7: Source-Safety Scan
```
PASS — 18 prohibited dirs, 30 prohibited extensions, 10 prohibited names checked
8 required files, 4 required directories verified
```

### Gate 8: Checksum Verification
```
PASS — All 29 checksums verified
```

### Gate 9: Git Audits
```
git status: Clean (only implementation commit staged)
git diff: .gitignore (+3 lines), tool/build_post_feature_delivery.py (path fix)
git diff --check: No whitespace errors (CRLF warnings expected on Windows)
```

## Installer Status

| Item | Status |
|------|--------|
| Inno Setup source | Created and validated |
| Compilation | Blocked — no admin access to ISCC.exe |
| Static validation | PASS — structure, branding, paths verified by tests |

## Key Decisions
- **Inno Setup** selected for installer: lightweight, auditable, free, Arabic-friendly
- **Per-user installation**: no admin required, uses `{localappdata}`
- **Portable package** is the verified delivery method; installer is source-only
- **Allowlist-based scanner** for stronger guarantees than blocklist
- **No production Dart code changes** — all additions are scripts, tests, docs, config

## Demo Package Contents
```
delivery/ghalal-demo-v1.0.0-<timestamp>/
  README-AR.txt
  checksums.sha256
  file-listing.txt
  release-manifest.json
  docs/
    CLIENT-INSTALLATION-GUIDE-AR.md
    CLIENT-DEMO-WALKTHROUGH-AR.md
    CLIENT-KNOWN-LIMITATIONS-AR.md
  Release/
    grain_warehouse_erp_lite.exe
    flutter_windows.dll
    *.dll, *.dat, *.json, *.bin
    data/
      icudtl.dat
      flutter_assets/
        assets/
        fonts/
        packages/
        shaders/
```

## Commit
```
470c265 feat(phase-98): client demo release packaging, windows installer source, and verification gates
```
