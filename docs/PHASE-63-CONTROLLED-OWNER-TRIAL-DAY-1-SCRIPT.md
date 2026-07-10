# Phase 63 — Controlled Owner Trial Day-1 Script & Acceptance Evidence Pack

**Date:** 2026-07-10

## Starting Baseline

| Item | Value |
|---|---|
| Phase 62 commit | `d888204` |
| Phase 62 tag | `phase-62-data-wipe-sequential-safety-audit` |
| Working tree | clean |
| Test count | 527 |

## Scope

This phase prepares a structured Day-1 controlled owner trial script and an acceptance evidence pack. It is a trial-preparation and acceptance-evidence documentation phase.

No production code is changed.

## Non-Goals

- No new features.
- No new reports.
- No new UI.
- No new accounting behavior.
- No new schema.
- No new permissions.
- No new roles.
- No cloud sync.
- No Firebase or Supabase.
- No mobile app.
- No online mode.
- No multi-device live sync.
- No API/backend server.
- No restore transaction implementation.
- No new backup engine.
- No new data wipe engine.
- No remote incident logging.
- No automatic evidence capture.
- No SaaS features.
- No source-code exposure.

## Documents Created

| File | Purpose |
|---|---|
| `docs/OWNER-TRIAL-DAY-1-SCRIPT-AR.md` | Arabic Day-1 controlled owner trial script |
| `docs/OWNER-ACCEPTANCE-EVIDENCE-PACK-AR.md` | Arabic acceptance evidence pack with screenshot guidelines |
| `docs/PHASE-63-CONTROLLED-OWNER-TRIAL-DAY-1-SCRIPT.md` | This summary document |

## Day-1 Trial Script Summary

Created `docs/OWNER-TRIAL-DAY-1-SCRIPT-AR.md` containing:

1. **Purpose** — Controlled first-day trial for the Phase 60 production-candidate package.
2. **Before Starting** — Pre-trial checklist (backup, sample data preparation, incident log readiness).
3. **Safety Rules During Trial** — Rules prohibiting repeated failed operations, immediate stop conditions, screenshot requirements.
4. **20 Trial Steps (A–Z)** covering: login, navigation, product creation, supplier creation, customer creation, purchase entry, inventory check, cash sale, customer-linked sale, customer statement, sale cancellation, customer balance after cancellation, inventory after cancellation, customer collection, supplier payment, expense, daily report, supplier statement, backup creation, optional restore test, final owner review.
5. **PASS / FAIL / NEEDS REVIEW Criteria** — Defined for each major workflow.
6. **Stop Conditions** — 10 conditions that require immediate trial halt.
7. **End-of-Day Owner Sign-Off** — Simple sign-off table with owner name, date, trial result (Accepted/Accepted with notes/Not accepted), issue counts, and signature.
8. **Post-Trial Instructions** — Evidence folder setup, incident logging, developer notification.

## Acceptance Evidence Pack Summary

Created `docs/OWNER-ACCEPTANCE-EVIDENCE-PACK-AR.md` containing:

1. **Purpose** — Collect proof that the system behaved correctly.
2. **Evidence Folder Structure** — Suggested `Owner-Trial-Day-1-Evidence/` with 12 subdirectories (01-login through 12-incidents).
3. **Screenshot Naming Convention** — `YYYY-MM-DD_step_result_note.png` format.
4. **Required Evidence Checklist** — 17 evidence items across all major workflows.
5. **Evidence Review Table** — 17-row table with columns for section, image name, result, notes, and follow-up flag.
6. **Acceptance Decision** — Rules: accepted only if no Critical issues; High issues must be reviewed; any stock or balance mismatch blocks acceptance.
7. **Owner Notes Section** — Free-text area for additional observations.

## Connection to Previous Phases

| Phase | Document | Connection |
|---|---|---|
| Phase 60 | `delivery/grain_warehouse_erp_lite_phase60_...` | The trial script targets the Phase 60 production-candidate package. |
| Phase 61 | `docs/OWNER-TRIAL-INCIDENT-LOG-AR.md` | The script instructs owners to log incidents using the Phase 61 incident log. |
| Phase 62 | `docs/DATA-WIPE-SAFETY-GUIDE-AR.md` | The script explicitly prohibits accidental data wipe during Day-1 trial. |

## Production Code Changed

**No.** Phase 63 is documentation-only.

## Schema Changed

**No.**

## Tests Changed

**No.** Test count remains 527.

## Files Added

- `docs/OWNER-TRIAL-DAY-1-SCRIPT-AR.md` — Day-1 owner trial script (Arabic)
- `docs/OWNER-ACCEPTANCE-EVIDENCE-PACK-AR.md` — Acceptance evidence pack (Arabic)
- `docs/PHASE-63-CONTROLLED-OWNER-TRIAL-DAY-1-SCRIPT.md` — This summary document

## Files Modified

- `docs/DEVELOPER-HANDOFF-NOTES.md` — Added Phase 63 section
- `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md` — Added Phase 63 trial preparation items
- `docs/PILOT-RELEASE-NOTES-AR.md` — Added Phase 63 Arabic release note
- `docs/OWNER-QUICK-START-AR.md` — Added pointers to trial script, evidence pack, and incident log
- `docs/OWNER-TRIAL-INCIDENT-LOG-AR.md` — Added note about Day-1 trial evidence linkage

## Verification Results

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | No issues found |
| `flutter test` | 527/527 passed |
| `flutter build windows --release` | Succeeded (usual CMake/MSVCRT warnings only) |
| `git diff --check` | Clean (expected CRLF warnings only) |
| `git status --short` | Clean after commit |

## Remaining Risks or Limitations

- This phase prepares the trial script and evidence pack but does not conduct the trial itself.
- The trial outcome (accepted/rejected) depends on actual owner execution.
- Day-1 script assumes the Phase 60 production-candidate package is used.
- Restore testing is optional and must be done on a test copy only.
- Data wipe safety is documented but the trial script warns against accidental use.

## Recommended Next Phase

- **Phase 64** — Depends on owner feedback from the production-candidate trial. Potential directions:
  - Owner trial feedback review and issue triage.
  - Bug fixes identified during Day-1 trial.
  - Continued trial with additional scripts (Day-2, Day-3, etc.) if Phase 60 is accepted.
  - Persistent on-disk database engine with transaction-safe backup/restore.

## Final Conclusion

Phase 63 prepares the structured Day-1 controlled owner trial script and acceptance evidence pack. The script makes the first real owner trial measurable, repeatable, and safe by defining exact steps, PASS/FAIL criteria, stop conditions, and evidence collection requirements. The evidence pack provides a systematic way to document test results with screenshots and structured review. No production code, schema, or tests were changed. The project remains in the pre-trial preparation state, ready for the owner to execute the Day-1 script using the Phase 60 production-candidate package.
