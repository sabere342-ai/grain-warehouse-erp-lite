# BUILD-16 — Customer Collections by Financial Account Domain Report

## Executive status

BUILD-16 completes the owner-authorized canonical, reusable, read-only domain boundary for **Customer Collections by Financial Account**. This is a domain-report implementation, not an AI Action implementation. No Action ID, AI tool, AI reader, AI registry entry, AI export, AI result model, intent route, UI page, or runtime assistant capability was added.

## BUILD-15 continuity and owner decision

BUILD-15 (`88c8cc25cbeee470759cb794d922262c05b17a64`) rejected the former report path because its customer identity lookup was private UI composition and the result lists were mutable. The owner then selected a single-account, required-inclusive-period customer-collections report with an optional customer filter, `canViewFinancialReports` as the protected-consumer permission expectation, restricted identity exposure, deterministic date/ID ordering, and no inferred historical values.

The implemented boundary follows that decision without an all-accounts mode, extra filters, payment-method filter, UI migration, export, ledger calculation, or AI integration.

## Repository trace

| Flow operation | Source evidence | Classification | BUILD-16 disposition |
| --- | --- | --- | --- |
| Existing UI entry | `features/financial_reports/customer_collections_report_screen.dart` creates `_CustomerCollectionLookupAdapter` and `FinancialReportService`. | UI presentation/composition | Not reused. The UI remains unchanged. |
| Collection retrieval | `CustomerAccountRepository.listCollections()` returns immutable source records. | Repository retrieval | Read by the new domain service. |
| Customer lookup | `CustomerRepository.listCustomers(includeInactive: true)`. | Repository retrieval | Used once to validate/filter and expose only ID, name, and active state. |
| Financial-account lookup | `FinancialAccountRepository.accountById`. | Repository retrieval | Validates selected account before the collection scan; inactive existing accounts remain valid. |
| Existing UI aggregation | Old financial report joins financial ledger entries, optional UI lookup, fallback names, and reversal handling. | UI-only aggregation for this purpose | Not copied. |
| Date handling | Customer collections retain `date`; existing repositories treat report dates as local `DateTime` values. | Canonical domain behavior | Normalized to local calendar date with no UTC conversion; both endpoints are inclusive. |
| Cancellation behavior | `CustomerCollectionRecord.isCancelled`; cancellation records a compensating entry and marks the original collection cancelled. | Canonical transaction-validity behavior | Cancelled original collection records are excluded. No reversal row or derived net calculation is invented. |
| Permission enforcement | Financial report UI checks `canViewFinancialReports`. | Protected-consumer authorization | Service is UI- and AI-independent; consumers must check the established permission before calling it. |
| Writes | Customer-account and financial-account repositories expose writes, but the report service invokes only `accountById`, `listCustomers`, and `listCollections`. | Repository capability outside read flow | No write method is reachable from the implementation. |

## Canonical ownership and method

The boundary is normal customer-collections domain code:

- `lib/core/customer_accounts/customer_collections_by_financial_account_report_service.dart`
- `lib/core/customer_accounts/customer_collections_by_financial_account_report.dart`

```dart
Future<CustomerCollectionsByFinancialAccountReport>
customerCollectionsByFinancialAccountReport({
  required String financialAccountId,
  required DateTime startDate,
  required DateTime endDate,
  String? customerId,
})
```

The service is configured with `CustomerAccountRepository`, `CustomerRepository`, and `FinancialAccountRepository`. It has no Flutter, widget, controller, navigation, UI-state, or AI-layer import. It returns a typed domain snapshot and never exposes any repository to callers.

## Exact input contract

- `financialAccountId` is required, trimmed, and must name one existing account. `accountById` runs before collection retrieval; inactive accounts are valid.
- `startDate` and `endDate` are required local business dates, inclusive after date normalization. An earlier end date throws `ArgumentError`.
- `customerId` is optional. A supplied blank value throws `ArgumentError`; a supplied unknown ID throws `StateError` before collection retrieval. Inactive existing customers are valid.
- No account-type, amount, text, employee, cancellation, payment-method, sorting, pagination, multi-account, or all-time input exists.

Typed Dart `DateTime` values are the established input type, so malformed serialized date values cannot enter this domain method. The method makes no UTC conversion and introduces no new timezone policy.

## Exact result contract and immutability

`CustomerCollectionsByFinancialAccountReport` contains only:

- selected financial-account ID, display name, canonical type, and active state;
- normalized requested `startDate` and `endDate`;
- applied optional `customerIdFilter`;
- immutable `rows` and derived `rowCount`;
- `totalAmountQirsh`.

Each `CustomerCollectionsByFinancialAccountReportRow` contains only stable collection ID, normalized collection date, customer ID/name/active state, financial-account ID, nullable recorded `PaymentMethod`, and canonical `amountQirsh`. It deliberately does not expose phone, address, notes, creator, employee identity, audit data, backup data, raw models, or database metadata.

All report and nested-row fields are final. The report constructor copies rows with `List.unmodifiable`, exposes no map, and uses immutable scalar/enum/`DateTime` values. Focused tests prove callers cannot add, remove, or replace rows; nested rows have no mutable public state.

## Period, filtering, ordering, and null semantics

The service normalizes each endpoint and collection `date` to `DateTime(year, month, day)`. A collection is included when that local calendar date is greater than or equal to `startDate` and less than or equal to `endDate`.

Rows are sorted exactly by collection date ascending, then stable collection ID ascending. No caller sort option or localized-display sort exists.

`paymentMethod` passes through unchanged, including `null`. The report uses collection ID as its canonical source identifier; no separate source reference exists in the collection model, so none is invented. A null historical `financialAccountId` never matches the selected account. Missing customers cause a data-integrity error rather than a fabricated identity. Empty matching sets return a valid immutable report with zero rows, zero count, zero qirsh total, and the requested account/period intact.

## Identity, inactive entities, permission, and accounting safety

The report exposes exactly the owner-approved account/customer/collection identity fields described above. `listCustomers(includeInactive: true)` ensures historical rows keep existing inactive customers, while `accountById` permits inactive existing accounts. Neither entity is reactivated or otherwise changed.

Protected consumers must enforce `Permissions.canViewFinancialReports` before invoking the boundary. The boundary remains a reusable domain read service rather than an authorization/UI/AI service.

Amounts come directly from `CustomerCollectionRecord.amountQirsh`; the summary total is the integer-qirsh sum of returned rows. The service does not read customer balances, financial balances, ledger entries, closing records, or formatted values. It calculates no opening/closing/running balance, debt, average, percentage, subtotal, or forecast. Cancelled collections are excluded because the existing collection domain marks the original invalid and records its compensating reversal separately.

## Repository read behavior and proof of no writes

The read sequence is account validation, full customer lookup, optional customer validation, then collection retrieval/filter/sort/sum. It never calls create, update, deactivate/reactivate, cancellation, restore, ledger-entry, balance-mutation, backup, or audit methods.

Focused tests snapshot collection records and customer/financial balances before and after a report call. They prove unchanged source data and balances, alongside repeated-read equivalence.

## Tests added and UI/AI status

Added `test/customer_collections_by_financial_account_report_service_test.dart` with 19 focused tests covering required IDs/dates, invalid range, unknown/inactive account, optional/unknown/inactive customer, empty result, inclusive dates, period/account/customer exclusions, null account link, null payment method, date/ID ordering, totals, cancellation semantics, immutable rows, no writes, and repeated reads.

The existing UI is intentionally unchanged. It retains its separate legacy financial-ledger report behavior; BUILD-16 does not migrate or alter it. The AI action count remains exactly 10, and no AI source file changed.

## Protected state and verification

The inherited protected path is `lib/features/financial_reports/advances_and_refunds_report_screen.dart`. BUILD-16 preserves its recorded SHA-256 `A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`, Git blob `22800a9ccb08ee5796f0fa69c87bd9995739adbf`, and size `32418` bytes. `.build-diagnostics/` remains untracked and unstaged.

Verification completed successfully before staging:

- Focused BUILD-16 test file: **19 passed**.
- Relevant regression command covering customer collections, financial reversals,
  transaction integration, financial reports, closing, backup compatibility,
  and AI execution: **165 passed**.
- Full `flutter test`: **1,415 passed**, **0 failures**, and **1 expected skip**.
- `flutter analyze --no-pub`: no issues.
- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze`: no issues.
- `git diff --check`: no diff errors. Git printed only CRLF notices for the
  inherited protected file and generated Windows plugin files; generated files
  were not modified in `git status`.
- `flutter build windows --release`: exit 0; produced
  `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
  (785,408 bytes; modified `2026-07-19 01:22:55` local time). The only build
  warnings were the existing Firebase CMake deprecation and MSVCRT LNK4078.
- Post-build protected-file verification matched the SHA-256, Git blob, and
  byte size stated above.

The final staged audit, commit reference, no-tag confirmation, and no-push
confirmation are recorded in the BUILD-16 closure report. No AI integration
occurred.

## Remaining work before possible future AI exposure

This canonical boundary alone does not authorize AI exposure. A later owner-authorized build must separately decide an Action ID, exact AI input/result schema, authorization enforcement, execution mode, confirmation policy, registry composition, safe error behavior, response contract, and dedicated AI tests.
