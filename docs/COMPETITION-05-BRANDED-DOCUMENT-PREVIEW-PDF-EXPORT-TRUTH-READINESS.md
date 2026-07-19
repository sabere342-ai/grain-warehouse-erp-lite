# COMPETITION-05 — Branded Document Preview and PDF Export Truth Readiness

## Authorization and baseline

Owner-authorized scope: audit and narrowly remediate the existing shared printable-preview/PDF pipeline only. This is not a new invoicing system and does not add document types, printing, messaging, financial calculations, schema, backup, or permission-model changes.

- Starting HEAD: `f0588fefe7770ed36e9181fefb166d59c21167e5`
- Starting branch: `phase9e-expense-analysis-report`
- Starting tracked state: clean; `git diff --stat` and `git diff --check` were empty.
- Only initial untracked path: `.build-diagnostics/`; physical recursive count: 36.

## Supported inventory and truth matrix

The production code establishes five—and only five—existing printable documents. The daily report is included because Phase 42 explicitly registers it in the shared printable/PDF pipeline; it was not intentionally excluded by repository evidence.

| Type / visible title | Genuine entry and canonical source | Identifier/date/party/lines/value source | Branding, preview/PDF, return, and status |
| --- | --- | --- | --- |
| `SaleRecord` / `فاتورة بيع` | Sales list → `PrintableSalesInvoiceView`; immutable `SaleRecord` plus product-name presentation map | `id`, `createdAt`, current referenced customer display fallback, ordered `items` (or legacy single item), qirsh totals, payment mode/method, notes, cancellation | Shared preview and sales builder; saved establishment identity/logo; `maybePop`; cancelled is explicitly `ملغاة — تم عكس الأرصدة`; compliant after remediation. |
| `PurchaseIntake` / `فاتورة شراء` | Supplier purchases → `PrintablePurchaseInvoiceView`; immutable intake | `id`, `createdAt`, stored supplier snapshot where present/route name fallback, product reference presentation, kg/entry unit, stored price/total, payment mode/method, notes, cancellation | Shared preview and purchase builder; identity/logo; `maybePop`; explicit cancellation, not a refund; compliant after remediation. |
| `CustomerStatement` / `كشف حساب عميل` | Customer statement preview; `CustomerAccountRepository.statementForCustomer` snapshot | Generated document date, current route customer identity, ordered statement lines and supplied running/final balances | Shared preview and customer statement builder; identity/logo; `maybePop`; no cancellation reinterpretation; compliant after remediation. |
| `SupplierStatement` / `كشف حساب مورد` | Supplier statement → preview; `SupplierAccountRepository.statementForSupplier` snapshot | Generated document date, route supplier identity, ordered statement lines and supplied running/final balances | Shared preview and supplier statement builder; identity/logo; `maybePop`; no cancellation reinterpretation; compliant after remediation. |
| `DailyActivityReport` / `التقرير اليومي` | Reports → `PrintableDailyReportView`; requested report snapshot | Selected report date and report totals/sections | Shared preview and daily-report builder; identity/logo after remediation; `maybePop`; no party or cancellation fields apply. |

The pipeline does not derive ledger or stock balances, infer missing payment methods/accounts, alter signs, reorder lines, replace stored purchase-party snapshots, or write any business object. Financial-account display names are not part of the existing invoice presentation contract; stored nullable payment methods now remain visibly neutral as `غير محددة` rather than being invented.

Historical identity is therefore preserved as the existing contract permits: purchases retain their optional stored supplier snapshot and sales/statement routes use their existing referenced entity presentation. A missing reference continues to use the established neutral product fallback and does not crash or manufacture an entity.

## Findings and remediation (Outcome A)

1. The shared preview used a hard-coded white document surface, weakening dark-mode readability. It now uses the active theme surface.
2. Long document identifiers and legacy single-item product rows could overflow on narrow layouts. Metadata is vertically responsive and value cells are constrained/wrapped.
3. Sales/Purchase PDF output omitted preview-visible payment method and notes. It now renders the stored payment mode/method (including the neutral null label) and non-empty stored notes.
4. Customer, supplier, and daily PDF builders did not receive the canonical saved establishment identity/logo even though their shared previews did. All five supported PDF builders now receive the single existing identity source and safe optional logo bytes.
5. Single-page PDF builders could fail or clip longer tables. All five use `pw.MultiPage`; table data retains source order.
6. Existing export writes would silently replace a same-name file. The Windows export service now selects `name (2).pdf`, then later numeric suffixes, before writing. Success still follows a completed write; failures remain truthful.

The branding reader is read-only, catches a missing/unreadable managed logo file, uses `BoxFit.contain`, and does not persist settings or machine paths. The bundled Amiri Arabic-font initialization and RTL PDF directionality remain the approved strategy.

## Permission, navigation, parity, and no-mutation evidence

The audited real routes retain their existing authenticated/permission-gated parent flows. Document-history regression coverage proves employees do not receive owner-only cancellation audit details; no permission definition or employee capability was broadened. Preview/export receives already-authorized canonical models and does not issue transaction, ledger, inventory, account, backup, or identity writes.

`PrintableDocumentScaffold` supplies Arabic RTL controls and `Navigator.of(context).maybePop()`. Its controls remain available after its loading state resolves and route-pop creates no replacement root page. The focused COMPETITION-05 widget test verifies an 800×600 dark, long-name/long-ID invoice preview with visible Arabic return/export controls and no overflow. Existing Phase 40/42/43/44 tests cover the genuine printable views and established export/share controls. Phase 81 tests prove the transaction-level financial account/payment-method backup contract remains unchanged.

Preview/PDF parity now includes document title, identity, logo behavior, canonical date/number/party/item quantities and values, cancellation wording, payment mode/method, and notes where those fields exist. Statement/report date remains a generated presentation timestamp/date, not a stored transaction field; export uses one captured timestamp for both its statement content and filename.

## Files changed and exclusions

Production changes are limited to the five existing PDF builders, their existing export service, and the shared/invoice printable widgets. Focused test: `test/competition05_document_preview_pdf_readiness_test.dart`.

Explicitly unchanged: transaction repositories/models, accounting and financial-account services, inventory, document-history semantics, permissions, routes outside existing printable flow, backup/restore/schema, Cloud/mobile/sync, split payments/advances/refunds operations, thermal printing, WhatsApp automation, email, and Windows icon tooling.

## Verification and final state

- Focused PDF + COMPETITION-05 preview: `flutter test test\\phase42_pdf_export_foundation_test.dart test\\competition05_document_preview_pdf_readiness_test.dart --no-pub --reporter compact` — 28 existing Phase 42 tests plus 4 COMPETITION-05 tests passed.
- Printable/branding regression: Phase 40, 43, 44, and 68 suites — 116 passed.
- Navigation/permission and immutable transaction backup regression: document history, Phase 67, and Phase 81 suites — passed.
- Full suite: `flutter test --no-pub --reporter compact` — **1,460 passed**, with **1 existing expected skip**.
- Flutter analyzer: `flutter analyze --no-pub` — no issues.
- Direct Dart analyzer: `C:\\src\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe analyze` — no issues.
- Diff check: clean after the final source/test/document review.
- Windows release: direct Flutter-tool build succeeded; artifact `build\\windows\\x64\\runner\\Release\\grain_warehouse_erp_lite.exe`. The existing Firebase CMake deprecation and MSVCRT `LNK4078` warnings remain non-blocking and are not caused by this phase.

No tag or push is authorized. `.build-diagnostics/` remains untracked, unstaged, and untouched.
