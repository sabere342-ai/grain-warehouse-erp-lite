# Phase 102J — Synthetic Persistence, Duplicate, Backup, and Restore Evidence

## Outcome

**PASSED**

| Activity | Actual result |
| --- | --- |
| Pre-import backup | Created before the first import |
| Pre-import backup checksum | `1d5ea733` |
| First import | 12 written, 0 rejected |
| Second identical import | 12 duplicates, 0 written |
| Quantity delta on replay | 0 kg |
| Valuation delta on replay | 0 qirsh |
| Graceful database close/reopen | Passed |
| Products after reopen | 12 |
| Opening movements after reopen | 12 |
| Valuation states/events after reopen | 12 / 12 |
| Activation audit entries after reopen | 1 |
| Synthetic activation after reopen | Preserved |
| Post-activation backup | Created with official backup service |
| Post-activation backup checksum | `9bbe2f89` |
| Restore into a new empty SQLite database | Passed |
| Restored activation state | `syntheticProfitabilityActivatedForTest` |
| Restored movements / valuation events | 14 / 14, including sale and cancellation |

The databases, backups, and JSON runtime evidence are under
`C:\Users\saber\AppData\Local\Temp\phase102j-trial-20260728-1805` and are not
tracked by Git.

## Verification gates

| Check | Result |
| --- | --- |
| Phase 102J focused tests | 5 passed |
| Focused activation/valuation/backup/restore suite | 66 passed |
| Full `flutter test` | 1,910 passed; 1 pre-existing skip |
| `flutter analyze --no-pub` | Passed — no issues |
| Dart format check across `lib`, `test`, `tool` | Passed — 362 files, 0 changed |
| `git diff --check` | Passed |
| Windows release build | Passed |
| Release executable | `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe` |
| Native Windows smoke | Passed; process remained alive for 8 seconds |

The native smoke redirected `APPDATA`, `LOCALAPPDATA`, and `USERPROFILE` to
`C:\Users\saber\AppData\Local\Temp\phase102j-native-smoke-20260728-final` before
launch, then stopped the exact process. It did not use the normal production
data directories.
