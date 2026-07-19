# BUILD-18 — Supplier Payments by Financial Account Domain Report Boundary

## Executive status

BUILD-18 implements the owner-authorized canonical, typed, immutable, read-only domain boundary for supplier payments attributable to one selected financial account. It is a domain-only build: it creates no AI action, AI reader, AI tool, registry entry, UI, write behavior, schema change, migration, or backup-format change.

## Continuity and owner authorization

BUILD-16 established the equivalent immutable customer-collections boundary. BUILD-17 then exposed only that existing boundary through its separately authorized AI action. BUILD-18 supplies the corresponding supplier-payment domain boundary without exposing it through AI.

The future AI action name `financial_supplier_payments_by_account` is reserved only. BUILD-19 is not authorized. Any future AI action requires a separate owner decision and must call this boundary unchanged, without AI-layer repository access, recalculation, sorting, or filtering.

## Canonical method

```dart
Future<SupplierPaymentsByFinancialAccountReport>
supplierPaymentsByFinancialAccountReport({
  required String financialAccountId,
  required DateTime startDate,
  required DateTime endDate,
  String? supplierId,
})
```

The implementation is in `lib/core/supplier_accounts/supplier_payments_by_financial_account_report_service.dart`; its immutable report types are in `lib/core/supplier_accounts/supplier_payments_by_financial_account_report.dart`.

## Inputs, date semantics, and read behavior

- `financialAccountId` is required, trimmed, and validated through the canonical financial-account repository. An existing inactive account remains valid.
- `startDate` and `endDate` are normalized to local business dates and are inclusive. An end date earlier than the start date is rejected.
- `supplierId` is optional; a blank or unknown supplied value is rejected. Existing inactive suppliers remain valid.
- The service validates the selected account, reads suppliers including inactive suppliers, and reads payments. It does not write, mutate balances, create ledger entries, alter closing state, or invoke transaction mutations.

## Result, privacy, and accounting contract

`SupplierPaymentsByFinancialAccountReport` contains only selected account ID/name/type/active state, normalized inclusive period, nullable supplier filter, unmodifiable rows, `rowCount`, and `totalAmountQirsh`.

Each row contains only payment ID, normalized payment date, supplier ID/name/active state, selected financial-account ID, nullable recorded `PaymentMethod`, and integer-qirsh amount. Phone, address, notes, supplier/account balances, authentication or authorization data, audit internals, repository entities, raw persistence maps, database data, and unrelated metadata are absent.

The service preserves the canonical `listPayments()` order and performs no secondary sort. It preserves `paymentMethod == null` exactly. Cancelled payments, payments linked to another account, and historical payments with no account link are excluded. Matching no rows is a successful immutable empty report with zero qirsh total and zero row count.

## Future Split-Payments compatibility

Rows are report entries attributed to the selected financial account. The present source naturally contributes one row per valid payment record, but the report contract does not require `paymentId` to be globally unique among rows and does not define `rowCount` as a distinct-payment count. This permits future allocation-derived rows without adding allocation models, split-payment writes, UI, schema, or migration work in BUILD-18.

## Explicit exclusions

BUILD-18 does not modify the prior supplier-settlements ledger report, AI action inventory, AI modules, user interface, repositories, accounting semantics, balances, ledgers, closures, backup/restore, schema, migrations, Cloud Sync, mobile, multi-device support, Split Payments, advances, overpayments, refunds, tags, or push state.

## Verification

- Focused BUILD-18 tests: 11 passed.
- Relevant supplier-payment, financial-account, transaction, backup, BUILD-16, BUILD-17, and supplier UI regressions: 148 passed.
- Full `flutter test`: 1,435 passed, 0 failures, 1 expected skip.
- `flutter analyze --no-pub`: no issues.
- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze`: no issues.
- `git diff --check`: no diff errors; only existing CRLF/toolchain warnings.
- `flutter build windows --release`: exit 0; `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`, 785,408 bytes, modified `2026-07-19 15:00:22` local time. Existing Firebase CMake deprecation and MSVCRT LNK4078 warnings remain non-blocking.

The inherited protected file `lib/features/financial_reports/advances_and_refunds_report_screen.dart` remains modified but untouched and unstaged, with SHA-256 `A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`, Git blob `22800a9ccb08ee5796f0fa69c87bd9995739adbf`, and 32,418 bytes. `.build-diagnostics/` remains untracked and unstaged.

The completion commit message is `BUILD-18: add supplier payments financial account report boundary`. No tag is created and nothing is pushed.
