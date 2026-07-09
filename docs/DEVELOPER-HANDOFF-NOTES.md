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
- Tests: currently 381, all passing
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

1. **No print engine**: Reports are screen-only. No PDF generation. Documented in owner checklist.
2. **Local-only storage**: Data is not synced across devices. Backup/restore is the only transfer mechanism.
3. **Single user session**: Concurrent multi-user not supported.
4. **Single warehouse**: One location only.
5. **No Arabic number formatting**: Uses Western Arabic numerals (0-9). This is acceptable for Egyptian grain warehouse owners accustomed to mixed usage.
6. **Stock movement notes**: Internal movement notes are now in Arabic (fixed in Phase 38).
7. **SaleController.customerRepository is optional**: If not provided, the FAB is disabled and sales form cannot be opened. Tests must pass it explicitly.

## Phase History (Recent)

| Tag | Phase | Summary |
|---|---|---|---|
| `phase-37d-operational-readiness-audit` | 37D | Full operational audit, 2 error text leaks fixed |
| `phase-37c-delivery-refresh` | 37C | Dashboard labels, cash flow clarity |
| `phase-37b-customer-opening-balance-finalization` | 37B | Customer opening balance finalization |
| `phase-37a-accounting-continuity-opening-balances` | 37A | Opening balances for customers/suppliers/inventory |
| `phase-38-final-client-pilot-hardening` | 38 | Arabic UX polish, handoff docs, client-ready hardening |
| `phase-38b-final-source-safe-delivery-refresh` | 38B | Final delivery refresh, source-safe package verification |
| `phase-39-customer-bound-multi-item-sales` | 39 | Customer-bound multi-item sales with cash/credit/partial payment modes |
| `phase-40-printable-business-documents-foundation` | 40 | Preview-only printable document views for sales invoice, customer statement, daily report, purchase invoice, supplier statement |
| `phase-40a-post-phase-40-repository-hygiene` | 40A | Repository cleanup — no dirty files, 2 warnings fixed, debug test removal confirmed, docs committed |

## Backup Version
- Current: v2
- Phase 39: Added `items` (array of SaleLineItem JSON) and `paidAmountQirsh` as optional fields
- Old backups without these fields restore via single-field fallback

## Next Recommended Phase
Phase 41 — Printable Preview Accuracy & Business Consistency QA

### Later Roadmap
- Phase 42 — PDF Export Foundation
- Phase 43 — WhatsApp Assisted Sharing (opens WhatsApp with prepared message; manual send only; automatic sending out of scope)
