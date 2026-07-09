# Developer Handoff Notes — Grain Warehouse ERP Lite

## Delivery Package

| Item | Path |
|---|---|---|
| Executable | `delivery/grain_warehouse_erp_lite_pilot_20260708-190737/Release/grain_warehouse_erp_lite.exe` |
| Owner Checklist | `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md` |
| Phase 39 Spec | `docs/PHASE-39-CUSTOMER-BOUND-MULTI-ITEM-SALES.md` |
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
- Tests: currently 411, all passing
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

### Sales Model (Phase 39)
- Every sale requires a `customerId` (no anonymous sales)
- Sales support multiple line items via `items` field (`SaleLineItem` / `SaleLineItemDraft`)
- Backward-compat single fields (`productId`, `quantityKg`, `salePriceQirshPerKg`) kept for old backup restore
- Three payment modes: `cash`, `credit`, `partial` (`SalePaymentMode`)
- Cash/partial sales create `cashSale` entries in customer account ledger (debit = total, credit = paid amount)
- `CustomerAccountRepository._validateEntry` allows entries with both debit > 0 and credit > 0 (cash/partial sale entries)
- Customer dropdown always visible in the sale form (required for all modes)
- FAB text: "تسجيل فاتورة بيع", Save button: "حفظ الفاتورة"
- FAB is disabled when no products or no customers are loaded

## Known Limitations

1. **PDF export only, no print engine**: PDFs are saved to Documents/Exports/ and auto-opened. No physical printing. Documented in owner checklist.
2. **Local-only storage**: Data is not synced across devices. Backup/restore is the only transfer mechanism.
3. **Single user session**: Concurrent multi-user not supported.
4. **Single warehouse**: One location only.
5. **No Arabic number formatting**: Uses Western Arabic numerals (0-9). This is acceptable for Egyptian grain warehouse owners accustomed to mixed usage.
6. **Stock movement notes**: Internal movement notes are now in Arabic (fixed in Phase 38).
7. **SaleController.customerRepository is optional**: If not provided, the FAB is disabled and sales form cannot be opened. Tests must pass it explicitly.

## Phase History (Recent)

| Tag | Phase | Summary |
|---|---|---|---|---|
| `phase-37d-operational-readiness-audit` | 37D | Full operational audit, 2 error text leaks fixed |
| `phase-37c-delivery-refresh` | 37C | Dashboard labels, cash flow clarity |
| `phase-37b-customer-opening-balance-finalization` | 37B | Customer opening balance finalization |
| `phase-37a-accounting-continuity-opening-balances` | 37A | Opening balances for customers/suppliers/inventory |
| `phase-38-final-client-pilot-hardening` | 38 | Arabic UX polish, handoff docs, client-ready hardening |
| `phase-38b-final-source-safe-delivery-refresh` | 38B | Final delivery refresh, source-safe package verification |
| `phase-39-customer-bound-multi-item-sales` | 39 | Customer-bound multi-item sales with cash/credit/partial payment modes |
| `phase-40-printable-business-documents-foundation` | 40 | Preview-only printable document views for sales invoice, customer statement, daily report, purchase invoice, supplier statement |
| `phase-40a-post-phase-40-repository-hygiene` | 40A | Repository cleanup — no dirty files, 2 warnings fixed, debug test removal confirmed, docs committed |
| `phase-41-printable-preview-accuracy-qa` | 41 | Preview QA: fixed sales invoice ID leak + missing units, statement subtitle clarification, daily report collections/outstanding rows, 6 edge-case tests, forbidden text audit |
| `phase-42-pdf-export-foundation` | 42 | PDF export foundation: 5 PDF builders with Amiri Arabic font, path_provider save to Exports/, open_filex auto-open, تصدير PDF button on all 5 previews, 24 new tests (411 total) |
| `phase-43-whatsapp-assisted-sharing` | 43 | WhatsApp assisted sharing: phone normalization, message templates, فتح واتساب button on 4 doc types (not daily report), url_launcher integration, 28 new tests (439 total) |

## Backup Version
- Current: v2
- Phase 39: Added `items` (array of SaleLineItem JSON) and `paidAmountQirsh` as optional fields
- Old backups without these fields restore via single-field fallback

## Next Recommended Phase
(Phase 43 complete — next phase TBD)

### Later Roadmap
- (none confirmed)

## Phase 44 — Final Owner Acceptance After PDF and WhatsApp

- Final owner acceptance QA added after PDF export and WhatsApp assisted sharing.
- PDF export remains local.
- WhatsApp behavior is assisted only: open WhatsApp with a prepared message, then the user manually reviews, attaches the PDF, and sends.
- No automatic sending, no WhatsApp API, no tokens, no backend messaging, and no WhatsApp Web automation/scraping.
- Daily report is intentionally excluded from WhatsApp sharing because there is no safe owner/internal recipient setting.
- Phase 44 acceptance tests cover PDF/WhatsApp wording, missing/invalid phone safety, daily report exclusion, and forbidden send/token/API wording.
- Next recommended phase: Phase 45 — Final Source-Safe Delivery Refresh After PDF and WhatsApp Assisted Sharing.

## Phase 45 — Final Source-Safe Delivery Refresh After PDF and WhatsApp

### Delivery Package
- Path: `delivery/grain_warehouse_erp_lite_pilot_20260709-172154/`
- Client README: `README-AR.txt` (Arabic)
- Client docs in `docs/` subfolder

### Source-Safe Scan
- PASSED — no `.git`, `.dart`, `.ps1`, `.yaml` (project-level), `analysis_options`, `pubspec`, `lib/`, `test/`, `tool/`, source maps
- Exception: `native_assets.yaml` in Release/ is a required Flutter build artifact (runtime-required)

### Verification Status
- `git status`: clean
- `flutter analyze --no-pub`: 0 errors, 0 warnings
- `flutter test`: 466/466 passing
- `flutter build windows --release`: succeeded

### Client Doc Updates
- `OWNER-QUICK-START-AR.md`: added PDF export and WhatsApp assisted sharing sections
- `PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md`: added PDF and WhatsApp checklist items
- `PILOT-RELEASE-NOTES-AR.md`: rewritten to cover all features through Phase 45

### Next Recommended Phase
Phase 46 — Client Pilot Smoke on Delivered Package

## Phase 46 — Client Pilot Smoke on Delivered Package

### Package Tested
- Path: `delivery/grain_warehouse_erp_lite_pilot_20260709-172154/`
- Commit: `39a4781`, Tag: `phase-45-final-source-safe-delivery-after-pdf-whatsapp`

### Source-Safe Scan
- PASSED — no source code, no developer-only files in delivery package

### Smoke Result
- **READY FOR CLIENT PILOT** — All areas pass (A-K)
- No placeholders, no under-construction pages, no false claims
- PDF export: saved to Documents/Exports/, SnackBar says "تم حفظ"
- WhatsApp: manual-assisted only, no auto-send, no auto-attach
- Arabic docs match actual behavior accurately

### Verification Status
- `flutter analyze --no-pub`: 0 errors, 0 warnings
- `flutter test`: 466/466 passing
- `git status`: clean

### Next Recommended Phase
Phase 47 — Client Pilot Feedback Collection and Issue Resolution
