# Phase 107D — Governed Windows Package / Installer Report

## 1. Final Outcome

**Outcome A — FULL SUCCESS.** A current governed Windows installer was built,
inventoried, hashed, verified, installed, launched twice, and uninstalled. Only
R1-003 is closed.

## 2. Objective

Produce a current deliverable Windows installer from the Phase 107C application
baseline and close R1-003 only. No feature development is included.

## 3. Baseline

- Application source baseline: `f521a97946d73829fef19f4f0d30a6d07b9f8051`.
- Baseline outcome: Phase 107C, Outcome A — FULL SUCCESS.
- Starting HEAD matched the baseline and the starting worktree was clean.

## 4. Packaging Technology

Inno Setup 6.7.3 was used because the repository already had an Inno precedent,
it produces a conventional uninstallable Windows executable, supports a per-user
installation without Administrator rights, and requires no runtime dependency on
Flutter, Visual Studio, Git, or the source repository. The installer is unsigned;
certificate procurement and SmartScreen reputation are outside Phase 107D.

## 5. Canonical Build

The canonical route was executed from a clean committed state:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

- Flutter: 3.24.5, stable, framework revision `dec2ee5c1f`.
- Dart: 3.5.4.
- Windows: `10.0.26200.6584`, x64.
- Analyzer exit code: 0.
- Full test exit code: 0.
- Final Windows build exit code: 0.
- Final output: `build/windows/x64/runner/Release`.
- Final executable build timestamp evidence: `2026-08-09T15:09:57Z`.
- CMake emitted one deprecation warning and the linker emitted LNK4078; neither
  was an error and the build completed with `Built ...exe`.

## 6. Release Payload

- Payload file count: 21.
- Payload total bytes: 45,895,436.
- Source: the exact recursive contents of the final Flutter Windows Release
  output; a post-package comparison matched every file, size, and SHA-256.
- Required EXE, Flutter runtime DLL, plugin DLLs, `data/app.so`,
  `data/icudtl.dat`, and `data/flutter_assets/**` are present.

## 7. Manifest Contract

`release-manifest.json` contains `application`, `version`, `platform`,
`sourceCommit`, `packageFormat`, `fileCount`, `totalBytes`, and `files`. Every
file entry has a slash-normalized relative path, byte size, and lowercase
SHA-256. Paths are unique (case-insensitive for Windows) and sorted with
`StringComparer.Ordinal`. No machine path, username, timestamp, or secret forms
part of artifact identity.

Installed `release-manifest.json` and Inno's `unins*.exe` / `unins*.dat` are the
only documented installer-metadata exclusions from runtime-payload comparison.

## 8. Artifact Identity

- Output: `delivery/phase-107d/GrainWarehouseERP-1.0.0-windows-x64.exe`.
- Filename: `GrainWarehouseERP-1.0.0-windows-x64.exe`.
- Size: 14,998,748 bytes.
- SHA-256: `ab67d04e205a78aa2d6e087ffd6f63655a80e5e2de10d7a603f959b073098659`.
- Generation command: `powershell -NoProfile -File scripts/phase-107d/New-GovernedWindowsPackage.ps1 -IsccPath <Inno-Setup-6.7.3-ISCC.exe>`.
- Artifact binary is gitignored and is not committed.

## 9. Manifest Identity

- Output: `delivery/phase-107d/release-manifest.json`.
- Filename: `release-manifest.json`.
- Size: 5,576 bytes.
- SHA-256: `0377d97fd963edb09ea6257569725a04764fe52ba1ef82a6fcf4b52fe8a35dab`.

## 10. Provenance

- Application source baseline: `f521a97946d73829fef19f4f0d30a6d07b9f8051`.
- Packaging-tool commit at final artifact generation:
  `bea4cb98db4a873b36f498a280e3ade50f2a0975`.
- Git state at generation: clean.
- The final Phase 107D commit is an evidence-only amend of that one Phase 107D
  commit; application source, payload, manifest, and artifact are unchanged by
  the report/evidence amend.
- `release-metadata.json` binds artifact hash and size, manifest hash, source
  baseline, packaging-tool commit, package format, and clean Git state.

## 11. Integrity Verification

| Gate | Result |
| --- | --- |
| D1 artifact exists | PASS |
| D2 artifact hash/size matches metadata | PASS |
| D3 manifest exists and hash matches | PASS |
| D4 source commit equals Phase 107C baseline | PASS |
| D5 every payload file exists | PASS |
| D6 every payload size matches | PASS |
| D7 every payload SHA-256 matches | PASS |
| D8 no undeclared payload extras | PASS |
| D9 no textual path/secret leakage | PASS |
| D10 generated from clean committed state | PASS |

The final build directory and packaged payload also matched exactly: 21 files,
45,895,436 bytes, and every per-file SHA-256.

## 12. Negative Controls

- Tamper A, one payload byte changed: verification failed as required.
- Tamper B, manifest hash changed: verification failed as required.
- Tamper C, payload file removed: verification failed as required.
- Only isolated temporary copies were modified; the official artifact and
  payload were not used for tamper experiments.

## 13. Install Acceptance

PASS. The per-user installer completed without Administrator rights. All 21
installed runtime files matched manifest size and SHA-256, and there were no
undeclared files beyond the documented manifest/uninstaller metadata.

## 14. First Launch

PASS. The application was launched from the installed directory, not the build
directory, and presented a top-level window titled `غلال`.

## 15. Second Launch

PASS. After a controlled close, the installed executable launched again and
presented the `غلال` top-level window.

## 16. Uninstall

PASS. Inno's uninstaller completed successfully and removed the installed
application executable and installer-owned binaries.

## 17. User Data Safety

PASS. Four files present in the isolated user profile after launch, including
the production SQLite database and a safety sentinel, remained present with
identical SHA-256 values after uninstall.

The actual storage contracts are outside the install directory:

- SQLite: application-support directory under `%APPDATA%`, product namespace
  `com.example/grain_warehouse_erp_lite`, file `grain_warehouse_erp.sqlite3`.
- Theme, business identity, and managed logos: `%APPDATA%/GrainWarehouseErpLite`.
- Operator backups: `%USERPROFILE%/Documents/grain-warehouse-erp-lite-backups`.
- User-selected PDF/CSV exports use the Windows documents location.

The installer has no `[UninstallDelete]` rule and does not target these paths.

## 18. Leak Scan

PASS. Manifest, release metadata, installer definition, scripts, report, and
installer binary were scanned. No developer-root literal, developer username,
private-key marker, or tested credential/path leakage was found.

## 19. Formatting

PASS. `dart format --output=none --set-exit-if-changed .` checked 422 files and
changed 0 files.

## 20. Analyze

PASS. `flutter analyze` reported `No issues found` and exit code 0.

## 21. Tests

PASS. Full suite: **2,381 passed, 1 skipped, 0 failed**. The four initial
failures were historical branch-name lineage guards; their allowlists were
mechanically extended for the Phase 107D branch, after which 35 focused tests
and the full suite passed. No behavioral assertion was weakened. Phase 107C
checksum/restore tests remain green within the full suite.

## 22. Windows Release Build

PASS. `flutter build windows --release` exited 0 and produced
`grain_warehouse_erp_lite.exe`. The governed payload was regenerated after this
final build and then matched that output exactly.

## 23. Production Diff

None. No file under `lib/` changed. The only Dart changes are four historical
test lineage allowlists that admit the Phase 107D branch. Packaging additions
are confined to `installer/phase-107d/`, `scripts/phase-107d/`, and
`docs/phase-107d/`.

## 24. Schema Diff

None.

## 25. Dependency Diff

None. `pubspec.yaml` and `pubspec.lock` are unchanged.

## 26. UI Diff

None.

## 27. Git State

- Branch: `codex/phase-107d-governed-windows-package-installer`.
- Parent/baseline: `f521a97946d73829fef19f4f0d30a6d07b9f8051`.
- Commits after baseline: 1.
- Commit subject: `PHASE 107D: govern Windows release package`.
- Final worktree: clean after the evidence-only amend.
- Push/tag/merge/rebase: none.

## 28. Risk Register

- Before: R0 = 0, R1 = 4 open, R2 = 7, R3 = 7.
- After: R0 = 0, R1 = 3 open, R2 = 7, R3 = 7.
- R1-003: **CLOSED**.
- R1-004, R1-005, and R1-006 remain open and unchanged.
- No other risk was reclassified or closed.

## 29. R1-003 Closure Decision

**CLOSED.** The gap required a current governed artifact or installer with
hash/manifest provenance. The current installer exists, carries the complete
verified Windows payload, is independently verifiable, rejects isolated
tampering, installs without an SDK or Administrator rights, launches twice,
uninstalls, and preserves user data. This directly satisfies R1-003 and does not
claim clean-profile business-workflow acceptance under R1-004.

## 30. Recommended Next Atomic Phase

**Phase 107E — Fresh-Profile Runtime Acceptance (R1-004 only).** On a clean
Windows user/VM, execute owner setup, restart, roles, one minimal sale and
purchase, backup/restore, and explicit evidence capture. Do not begin it as part
of Phase 107D.
