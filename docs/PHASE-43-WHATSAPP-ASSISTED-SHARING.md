# Phase 43 — WhatsApp Assisted Sharing

## Scope
Add safe, assisted WhatsApp sharing after PDF export for printable business documents. No automatic sending, no WhatsApp Business API, no backend messaging, no scraping.

## Packages Added

| Package | Version | Reason |
|---------|---------|--------|
| `url_launcher` | ^6.3.1 | Opens `https://wa.me/` URLs on desktop and mobile to launch WhatsApp with a prepared message. |

## Design Decisions

### Assisted (Not Automatic) Sharing
- The app opens WhatsApp with a pre-filled Arabic message.
- The user must manually attach the PDF file from the `Documents/Exports/` folder before sending.
- The SnackBar instruction explicitly tells the user to review the message, attach the PDF, and tap send manually.
- No claim of "تم الإرسال" (sent) or automatic attachment.

### Phone Number Handling
- Egyptian mobile numbers only (010, 011, 012, 015 prefixes).
- `PhoneNumberNormalizer.normalize()` strips spaces, dashes, parentheses, `+`, `002`, and leading `0`, then prepends `20`.
- Returns `null` for invalid/empty numbers — the WhatsApp button is hidden.
- `_showNoPhoneError` / `_showNoPhoneErrorSupplier` SnackBars shown if number is expected but invalid.

### Documents with WhatsApp Button
| Document | Phone Param | Recipient |
|----------|-------------|-----------|
| Sales Invoice | `customerPhone` | Customer |
| Customer Statement | `customerPhone` | Customer |
| Purchase Invoice | `supplierPhone` | Supplier |
| Supplier Statement | `supplierPhone` | Supplier |
| Daily Report | (none) | Excluded — no owner phone setting exists |

### WhatsApp URL Strategy
1. Primary: `https://wa.me/{normalized}?text={encoded}` via `LaunchMode.externalApplication` (opens WhatsApp app).
2. Fallback: `https://web.whatsapp.com/send?phone={phone}&text={text}` (opens WhatsApp Web).
3. If both fail, show error SnackBar: "تعذر فتح واتساب. تأكد من تثبيت واتساب أو افتح واتساب ويب يدويًا."

## File Structure

```
lib/core/sharing/
  phone_number_normalizer.dart       # Egyptian phone validation and normalization
  whatsapp_message_templates.dart    # Arabic message builders for 4 document types
  whatsapp_assisted_share_service.dart  # WhatsApp URL launch + user feedback
```

## UI Integration

- `PrintableDocumentScaffold` has a new `onOpenWhatsApp` callback.
- When provided with a valid phone, a "فتح واتساب" button appears next to "تصدير PDF".
- Buttons use `Wrap` for responsive side-by-side layout.
- When phone is null/empty, the WhatsApp button is hidden.
- Daily report has no WhatsApp button (phone param not available).

## Test Coverage (28 new tests)

- **Phone normalization (12 tests)**: 010, +2010, 002010, 2010 formats; 011/012/015 prefixes; empty/null/whitespace; landline rejection; too-short; spaces/dashes; parentheses.
- **Message templates (5 tests)**: each template contains name, doc number, date, "مرفق" keyword; no "تم الإرسال" or "أرسلنا".
- **Button visibility (10 tests)**: each of the 4 document types shows/hides WhatsApp button based on phone presence; daily report hides it unconditionally.
- **Forbidden text (2 tests)**: no auto-send claims, placeholder, TODO, or "قيد التنفيذ" in all 8 sharing-related source files.

## Verification

- `flutter analyze --no-pub`: 0 errors, 0 warnings
- `flutter test`: 439/439 passing (411 existing + 28 new)
- `git diff --check`: no whitespace errors

## Out of Scope (Intentionally)

- Automatic WhatsApp sending (user must manually tap send)
- WhatsApp Business API
- Backend messaging or web scraping
- Cloud attachment upload
- QR code scanning for phone numbers
- Daily report WhatsApp sharing (no phone setting available)
- "إرسال" button text — always "فتح واتساب" (open WhatsApp)

## Manual QA Instructions

1. Build the app: `flutter build windows --release`
2. Open a printable document that has a valid customer/supplier phone number saved.
3. Tap "تصدير PDF" first to export the PDF.
4. Tap "فتح واتساب" — WhatsApp should open with a pre-filled message.
5. Verify the message says "مرفق" (attached) — not "تم الإرسال".
6. Close WhatsApp and return to the app.
7. Verify the SnackBar instruction is visible for 8 seconds.
8. For a contact without a phone number, verify no WhatsApp button appears.
9. For daily report, verify no WhatsApp button appears.
