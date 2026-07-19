# BUILD-19 — Supplier Payments by Financial Account AI Read Action

## Status and authorization

BUILD-19 implements the owner-authorized read-only AI action `financial_supplier_payments_by_account` over the BUILD-18 canonical supplier-payments report. BUILD-18 baseline was verified at `948c85a1173d91541165d71de12a196921410934`.

| Contract | Value |
| --- | --- |
| Execution mode | `AiExecutionMode.readOnly` |
| Confirmation | None |
| Permission | Existing `canViewFinancialReports` |
| Inputs | `financialAccountId`, `startDate`, `endDate`, optional `supplierId` |
| Canonical source | `supplierPaymentsByFinancialAccountReport(...)` |
| AI inventory | 11 before; 12 in caller-supplied registries after BUILD-19. |

## Architecture and safety

`SupplierPaymentsByFinancialAccountTool` validates the exact input shape and local `YYYY-MM-DD` dates, requires read-only mode, then checks the active caller's `canViewFinancialReports` permission before reader invocation. Permission, validation, and mode failure tests prove the reader is never called.

The reader interface and adapter in `services/supplier_payments_by_financial_account_report_reader.dart` depend only on the BUILD-18 report service and delegate once. The reader and tool import no repository and do not calculate, sort, filter, aggregate, deduplicate payment IDs, enrich identities, format qirsh, or mutate anything.

The exact immutable BUILD-18 report instance is returned as `AiToolResult.data`. Account identity, inclusive period, supplier filter, canonical order, rows, duplicate payment IDs, nullable payment methods, row count, and integer-qirsh total therefore remain unchanged. No phone, address, notes, balances, credentials, authorization/audit data, raw persistence data, or unrelated identity is added.

The barrel export is explicit. `AiToolRegistry` remains caller-supplied, immutable, and duplicate-safe; no global registry, singleton, static mutable state, or auto-registration is introduced.

## Explicit exclusions

BUILD-19 does not change BUILD-18 calculations, supplier-payment repositories, accounting/ledger behavior, UI, schema, migrations, backup format, closing behavior, Split Payments, advances, overpayments, refunds, Cloud Sync, mobile, multi-device support, or financial writes. BUILD-20 is not authorized.

## Verification

- Focused BUILD-19 suite: 8 passed.
- Related AI, BUILD-16/17/18, financial, transaction, and backup regressions: 195 passed.
- Full `flutter test`: 1,443 passed, 0 failures, 1 expected skip.
- `flutter analyze --no-pub`: no issues.
- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze`: no issues.
- `git diff --check`: no diff errors; only inherited CRLF/toolchain notices.
- `flutter build windows --release`: exit 0; `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`, 785,408 bytes, modified `2026-07-19 15:16:23` local time. Firebase CMake deprecation and MSVCRT LNK4078 remain non-blocking.

The inherited protected path remains unchanged and unstaged: SHA-256 `A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`, Git blob `22800a9ccb08ee5796f0fa69c87bd9995739adbf`, 32,418 bytes. `.build-diagnostics/` remains untracked and unstaged.

Commit message: `BUILD-19: add supplier payments financial account AI action`. No tag is created and nothing is pushed.
