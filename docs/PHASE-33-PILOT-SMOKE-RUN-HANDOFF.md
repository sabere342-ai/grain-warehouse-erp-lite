# Phase 33 Pilot Smoke Run And Handoff Finalization

## Purpose
Phase 33 proves the current local Windows pilot delivery package is safe and clear enough to hand to the current client for real testing. This phase does not add business modules and does not expose source code.

## Baseline Checked
- Starting working tree was clean.
- Starting HEAD was `09a5a34 Phase 32 pilot delivery hardening`.
- Existing Phase 3x tags included `phase-30-strict-visible-pages-ui-readiness`, `phase-31-strict-no-hidden-pages-functional-recovery`, and `phase-32-pilot-delivery-hardening`.
- `build/` and `delivery/` remained ignored.

## What Changed
- Updated `tool/create_pilot_delivery_package.ps1` so each generated delivery package includes client-safe `README-AR.txt`.
- Added `tool/check_pilot_delivery_package.ps1` to validate delivery package safety without deleting anything.
- Fixed the Phase 32 acceptance test expectations to use Dart Unicode escapes for Arabic phrases that must remain encoding-safe.
- Updated developer handoff notes for Phase 33.

## Commands Run And Results
| Command | Result |
| --- | --- |
| `git status --short` | Passed; clean at start. |
| `git log --oneline -5` | Passed; HEAD was Phase 32 at start. |
| `git tag --list "phase-3*"` | Passed; Phase 30/31/32 tags present. |
| `git status --short --ignored build delivery` | Passed; `build/` and `delivery/` ignored. |
| `flutter.bat analyze --no-pub` | Passed; no issues found. |
| `flutter.bat test` | Passed after a narrow test expectation encoding fix; 250 tests passed. |
| `flutter.bat build windows --release` | Passed; built `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tool\create_pilot_delivery_package.ps1` | Passed. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tool\check_pilot_delivery_package.ps1 -PackagePath delivery\grain_warehouse_erp_lite_pilot_20260707-155622` | Passed. |
| Packaged exe launch smoke | Passed; launched and stayed running for 5 seconds, then stopped by process ID. |

## Delivery Package Created
`C:\dev\multi-pos\grain-warehouse-erp-lite\delivery\grain_warehouse_erp_lite_pilot_20260707-155622`

## Safe Files And Folders Included
Top-level package contents:
- `README-AR.txt`
- `Release/`
- `docs/`

`Release/` contains the Flutter Windows runtime files required to run the app:
- `grain_warehouse_erp_lite.exe`
- `flutter_windows.dll`
- `firebase_core_plugin.lib`
- `grain_warehouse_erp_lite.exp`
- `grain_warehouse_erp_lite.lib`
- `native_assets.yaml`
- `data/`

`docs/` contains selected owner-facing documents:
- `CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md`
- `CUSTOMER-TRIAL-DAILY-LOG-AR.md`
- `OWNER-QUICK-START-AR.md`
- `PHASE-22-PILOT-DELIVERY-CHECKLIST.md`
- `PHASE-24-PILOT-FIELD-TRIAL-RUNBOOK-AR.md`
- `PHASE-26-FIRST-CUSTOMER-TRIAL-START-CHECKLIST-AR.md`
- `PILOT-FEEDBACK-FORM-AR.md`
- `PILOT-ISSUE-LOG.md`
- `PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md`
- `PILOT-RELEASE-NOTES-AR.md`
- `RELEASE-NOTES-AR.md`

## Blocked Categories Checked
The safety script fails if the package includes these source/dev directories:
- `.git`
- `lib`
- `test`
- `android`
- `ios`
- `macos`
- `linux`
- `web`
- `windows`
- `.dart_tool`
- `.idea`
- `.vscode`

The safety script fails if the package includes these files or extensions:
- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- `*.log`
- `*.tmp`
- `*.dart`
- `*.ps1`

The safety script also blocks internal/developer document names matching:
- `*DEVELOPER*`
- `*INTERNAL*`
- `*HANDOFF-NOTES*`
- `*PHASE-33-PILOT-SMOKE-RUN-HANDOFF.md`

## Smoke Scenario
- Confirmed `README-AR.txt` is included.
- Confirmed `docs\PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md` is included.
- Confirmed backup/restore owner notes are included through `docs\CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md` and related release/checklist docs.
- Confirmed no source/dev files matched the blocked categories checked by the safety script.
- Launched the packaged release executable from the delivery package and confirmed it stayed running for the smoke window.

## Known Non-Blocking Warnings
The Windows build still emits the existing non-blocking warnings already tracked in handoff notes:
- Firebase C++ SDK CMake deprecation warning.
- MSVC `LNK4078` warning about multiple `.voltbl` sections.

## Remaining Honest Risks
- This package is still a local Windows pilot, not an installer with signed setup UX.
- The smoke launch confirms startup stability for a few seconds, not a full manual owner walkthrough on the client machine.
- Restore remains intentionally limited to an empty system.
- Customer balances, customer debt, collections, expense reversal, cloud sync, and multi-client operation remain outside this phase.

## Final Handoff Recommendation
The package `delivery\grain_warehouse_erp_lite_pilot_20260707-155622` is safe to hand to the current client for pilot testing. Hand off the generated delivery package only, not the repository or source code.
