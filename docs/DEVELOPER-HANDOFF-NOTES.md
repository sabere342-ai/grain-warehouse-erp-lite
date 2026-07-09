# Developer Handoff Notes — Grain Warehouse ERP Lite

## Delivery Package

| Item | Path |
|---|---|
| Executable | `delivery/grain_warehouse_erp_lite_pilot_20260708-190737/Release/grain_warehouse_erp_lite.exe` |
| Owner Checklist | `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md` |
| Phase 38 Audit Doc | `docs/PHASE-38-FINAL-CLIENT-PILOT-HARDENING.md` |
| Phase 38B Audit Doc | `docs/PHASE-38B-FINAL-DELIVERY-REFRESH-SOURCE-SAFE.md` |
| This File | `docs/DEVELOPER-HANDOFF-NOTES.md` |

## Build Process

```powershell
cd C:\dev\multi-pos\grain-warehouse-erp-lite
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`

Required runtime files:
- `grain_warehouse_erp_lite.exe`
- `flutter_windows.dll`
- `data/` (full directory)

## Quality Gates

Run before each delivery:
```powershell
flutter analyze --no-pub
flutter test
flutter build windows --release
```

- Analyze: must be 0 errors, 0 warnings
- Tests: currently 335, all passing
- Build: must succeed

## Architecture Notes

### State Management
- Custom `InheritedWidget` scopes: `AuthScope`, `ThemeScope`
- Controllers extend `ChangeNotifier`
- Screens use `AnimatedBuilder` for reactive updates

### Storage
- All data is local (in-memory `List` repositories)
- Data persists only for session lifetime
- Backup export saves full state as JSON
- Restore requires empty system (validated at repository level)

### Permission Model
- 16 boolean flags in `Permissions` class
- Two roles: `owner` (full access), `employee` (limited)
- Controllers check permissions at action time, not just UI gating

### Arabic Text Convention
- All user-facing strings in Arabic (literal text, no Unicode escapes)
- Error messages must use fixed Arabic text — never `$e` or `e.toString()`
- "أدخل" with Hamza (not "ادخل")

## Known Limitations

1. **No print engine**: Reports are screen-only. No PDF generation. Documented in owner checklist.
2. **Local-only storage**: Data is not synced across devices. Backup/restore is the only transfer mechanism.
3. **Single user session**: Concurrent multi-user not supported.
4. **Single warehouse**: One location only.
5. **No Arabic number formatting**: Uses Western Arabic numerals (0-9). This is acceptable for Egyptian grain warehouse owners accustomed to mixed usage.
6. **Stock movement notes**: Internal movement notes are now in Arabic (fixed in Phase 38).

## Phase History (Recent)

| Tag | Phase | Summary |
|---|---|---|
| `phase-37d-operational-readiness-audit` | 37D | Full operational audit, 2 error text leaks fixed |
| `phase-37c-delivery-refresh` | 37C | Dashboard labels, cash flow clarity |
| `phase-37b-customer-opening-balance-finalization` | 37B | Customer opening balance finalization |
| `phase-37a-accounting-continuity-opening-balances` | 37A | Opening balances for customers/suppliers/inventory |
| `phase-38-final-client-pilot-hardening` | 38 | Arabic UX polish, handoff docs, client-ready hardening |
| `phase-38b-final-source-safe-delivery-refresh` | 38B | Final delivery refresh, source-safe package verification |

## Backup Version
- Current: v2
- No changes to backup schema required for Phase 38

## Next Recommended Phase
Phase 39: Post-pilot feedback implementation or next feature milestone based on client trial results.
