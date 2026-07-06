# Developer Handoff Notes

## Current state
- Latest phase: Phase 22 pilot delivery package readiness.
- Previous stable tag before this phase: `phase-21d-final-business-qa-release`.
- Main app path: `C:\dev\multi-pos\grain-warehouse-erp-lite`.
- Windows release exe path: `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`.

## Verification commands
```powershell
flutter.bat test
flutter.bat analyze --no-pub
flutter.bat build windows --release
git diff --check
git status --short
```

## Do not commit
- `build/`
- `.dart_tool/`
- `delivery/`
- `tmp/`
- `*.log`
- `.exe` files or release package folders
- zip/package artifacts unless policy changes explicitly

## Known non-blocking build warnings
- Firebase C++ SDK CMake deprecation warning with newer CMake.
- MSVC `LNK4078` warning about multiple `.voltbl` sections.

## Core business rules
- Money is stored internally as integer piasters/qirsh.
- Normal UI displays جنيه/`ج.م`, not raw qirsh.
- Minimum sale price is enforced before stock or sale mutation.
- Reference cost is optional.
- Estimated profit and stock valuation are incomplete when reference cost is missing.
- Restore remains limited to an empty system under the current safe design.

## Phase 23 pilot acceptance smoke
- Current pilot acceptance phase: Phase 23 pilot acceptance smoke validation.
- Stable tag after this phase: `phase-23-pilot-acceptance-smoke`.
- Rebuild Windows release with: `flutter.bat build windows --release`.
- Recreate the pilot delivery package with: `powershell -NoProfile -ExecutionPolicy Bypass -File tool\create_pilot_delivery_package.ps1`.
- Keep `build/`, `delivery/`, `tmp/`, logs, and generated release artifacts out of Git.
- During the pilot, do not change pricing rules, minimum sale enforcement, restore safety, local storage behavior, Firebase configuration, or backend/cloud behavior unless a new reviewed phase explicitly asks for it.

## Phase 24 pilot field trial feedback loop
- Current stable pilot tag: `phase-23-pilot-acceptance-smoke`.
- Current field trial docs:
  - `docs/PHASE-24-PILOT-FIELD-TRIAL-RUNBOOK-AR.md`
  - `docs/PILOT-FEEDBACK-FORM-AR.md`
  - `docs/PILOT-ISSUE-LOG-TEMPLATE.md`
  - `docs/PILOT-RELEASE-NOTES-AR.md`
- Do not change business logic during pilot feedback collection.
- Classify issues first.
- Separate bugs from feature requests.
- Do not modify backup/restore without a dedicated phase.

## Phase 25 first customer delivery lock
- Current stable customer delivery tag after this phase: `phase-25-first-customer-delivery-lock`.
- Purpose: lock the first customer delivery process so the delivered folder is understandable, safe, traceable, and recoverable.
- New checklist/report/manifest files:
  - `docs/PHASE-25-FIRST-CUSTOMER-DELIVERY-CHECKLIST-AR.md`
  - `docs/CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md`
  - `docs/FIRST-CUSTOMER-DELIVERY-MANIFEST.md`
  - `docs/PHASE-25-FIRST-CUSTOMER-DELIVERY-LOCK-REPORT.md`
- Do not change business logic during customer trial.
- Use the issue log to classify feedback.
- Separate bugs from feature requests.
- Require backup before any restore or troubleshooting.
- Do not promise cloud/mobile/multi-branch in this pilot version.
