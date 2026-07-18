# BUILD-15 — Safe Read Boundary Owner Decision Packet

## Executive status

**Outcome B — no candidate passes.** BUILD-15 is an architecture decision and scope-freeze review only. It adds no AI action, Action ID, executable contract, tool, reader, model, serializer, export, registry entry, production composition, test, or runtime behavior.

The review reconciled the ten current AI actions and examined the three remaining high-value, non-duplicate report candidates with existing report-shaped APIs. Every candidate fails a hard gate: reusable configured boundary, immutable result contract, frozen input/time scope, or freedom from repository/UI composition. A score cannot override a hard-gate failure.

The smallest legitimate prerequisite is an owner-approved reusable domain report boundary for one narrow report. It must own party identity resolution, expose immutable collections, define its time/filter policy, and use an existing read permission. BUILD-15 does not authorize implementing that prerequisite.

## Baseline and preflight evidence

BUILD-15 started on branch `phase9e-expense-analysis-report` at exactly `26d7e77da58c7ab5acbeb730be7b7830b6235d77` (`BUILD-14: refresh AI action coverage and freeze next scope`).

| Command | Evidence |
| --- | --- |
| `git status --short` | Only the inherited modified protected report screen and untracked `.build-diagnostics/` were present. |
| `git branch --show-current` | `phase9e-expense-analysis-report` |
| `git rev-parse HEAD` | `26d7e77da58c7ab5acbeb730be7b7830b6235d77` |
| `git log -1 --oneline` | `26d7e77 BUILD-14: refresh AI action coverage and freeze next scope` |
| `git diff --check` | No diff error; Git emitted only its pre-existing CRLF notice for the inherited protected file. |

The inherited change is isolated from this document. It was not edited, staged, formatted, or restored.

## Existing ten-action coverage reference

The exported tool IDs are `inventory_attention`, `financial_account_balances`, `financial_account_statement`, `financial_payment_method_summary`, `financial_transfer_summary`, `financial_advances_and_refunds_summary`, `financial_closing_reconciliation_summary`, `financial_inflows_summary`, `financial_outflows_summary`, and `financial_expense_analysis`.

`lib/features/ai_assistant/registry/ai_tool_registry.dart` is an immutable allow-list constructed from a caller-supplied iterable. It rejects blank and duplicate IDs and stores `Map.unmodifiable`; it is not a global registry, singleton, auto-discovery mechanism, or production composition root. `AiExecutionService` is injected with that registry and focused tests construct registries explicitly.

BUILD-14's coverage conclusion remains true: all ten tools are exported from `ai_assistant.dart`; financial readers/adapters in `services/financial_account_balance_report_reader.dart` are consumed by their matching tools; and no orphan tool, reader, model, or export was found. Existing actions already cover the balance, statement, payment-method, transfer, advances/refunds, closing, flow, expense, and inventory-attention boundaries. None may be repackaged as a narrower or renamed action.

## Search methodology

The review read BUILD-14, AI architecture/handoff, BUILD-09, BUILD-12, the master roadmap, Phases 70, 73, 77, 79, 80, and 81, the ten tool contracts, caller injection, financial report service/models/screens, daily report repository/controller/model, permissions, and focused report tests.

Only meaningful operator reports with an existing report-shaped API not covered by the ten actions entered the serious inventory. A candidate fails if it requires AI repository access, UI-private lookup composition, calculation, sorting, grouping, filtering, joining, inference, transformation, or unsafe sensitive-payload exposure. Cloud, mobile, multi-device, and unimplemented roadmap work are excluded.

## Serious candidate inventory and eligibility matrix

| Candidate | Existing boundary and current callers | Inputs, ordering, nulls, and immutability | Authorization and tests | Result |
| --- | --- | --- | --- | --- |
| Customer collections by account | `FinancialReportService.getCustomerCollectionsByAccount` in `lib/core/financial_accounts/financial_report_service.dart`; callers are its financial-report screen and tests. | Optional `fromDate`, `toDate`, `accountIdFilter`, `customerIdFilter`; omitted dates mean current-month-to-now. Detail order is account asc, customer asc, timestamp desc, entry ID asc. IDs/references can be null and unresolved identity receives fallback name. Final fields, but three ordinary mutable result lists. | Screen checks `canViewFinancialReports`; service has no authorization and needs constructor-supplied customer lookup. 36 focused domain tests. | **FAIL** |
| Supplier settlements by account | `FinancialReportService.getSupplierSettlementsByAccount`; callers are its financial-report screen and tests. | Optional `fromDate`, `toDate`, `accountIdFilter`, `supplierIdFilter`, `supplierLookup`; omitted dates mean current-month-to-now. Detail order is account asc, supplier asc, timestamp desc, entry ID asc; supplier summaries name then ID. Nullable IDs/references/reversal IDs; unresolved fallback name. Final fields, mutable result lists. | Screen checks `canViewFinancialReports`, but a private UI adapter supplies the lookup. 51 focused domain tests. | **FAIL** |
| Daily activity report | `ReportRepository.dailyActivityReport`, implemented by `LocalReportRepository`; callers use `ReportController`, reports UI, and tests. | Required `selectedDate`; derives day bounds, traverses seven repositories, folds totals, calculates business summary values, applies fallback names, and reverses source movement order. Estimates are nullable with completeness flags; no complete independent ordering contract. | Controller checks `canProceed` and `canViewReports` before repository call. 12 focused tests. | **FAIL** |

| Candidate | Operator value | AI work that would be required if attempted | Security/privacy and accounting risk | Required production change |
| --- | --- | --- | --- | --- |
| Customer collections by account | High: account and customer collection/reversal visibility. | Identity lookup/join and exposure-scope selection; both forbidden. No calculation, sort, group, filter, or transformation is permitted in AI. | Customer identity exposure; a partial lookup could misattribute reversal/collection amounts. | A configured domain-owned lookup/report boundary, immutable collections, and frozen input/identity policy. |
| Supplier settlements by account | High: account and supplier settlement/reversal visibility. | Supplier lookup/join and exposure-scope selection; both forbidden. No AI calculation, sort, group, filter, or transformation is permitted. | Supplier identity exposure; partial reversal linkage could misstate settlement attribution. | A configured domain-owned lookup/report boundary, immutable collections, and frozen input/identity policy. |
| Daily activity report | High: daily operational view across inventory and cash-related activity. | Repository traversal, aggregation, date policy, and output interpretation; all forbidden in AI. | Mixed operational/financial exposure and risk of duplicated totals, cost, or cash semantics. | A dedicated immutable domain report boundary with an owner-approved scope, permission, and ordering contract. |

### Customer collections by account — precise rejection

The service owns financial filtering, qirsh aggregation, reversal treatment, and detail ordering, but is not an AI-safe configured boundary. `CustomerCollectionReportLookup` is optional and the only concrete `_CustomerCollectionLookupAdapter` is private to `customer_collections_report_screen.dart`. It coordinates customer-account, customer, and financial repositories to resolve identities and reversals. Passing no lookup leaves identities unresolved; recreating it in AI violates the no-repository and no-join rules.

The screen exposes date/account filters, the service also accepts a customer filter, and its default period is dynamic. BUILD-15 cannot choose the AI scope or identity policy. Mutable collections are a second hard failure. The AI layer must not transform this result to repair either problem.

### Supplier settlements by account — precise rejection

The service owns its calculations and typed qirsh totals, but requires `SupplierSettlementReportLookup` for resolved identity. The sole concrete `_SupplierSettlementLookupAdapter` is private UI composition in `supplier_settlements_report_screen.dart`, coordinating supplier, supplier-account, and financial repositories. Omitting it produces unresolved fallback data; adding it to an AI reader would be speculative composition and repository access.

Optional dates/account/supplier filters, dynamic defaults, and mutable result lists remain unfrozen. Screen permission proves a potential read permission, not authority to copy a UI adapter into AI.

### Daily activity report — precise rejection

`LocalReportRepository` is repository traversal, not a narrow canonical read service. It loads products, purchases, sales, inventory movements/balances, expenses, customer collections/balances, and supplier payments/balances, then computes sums and derived business-summary values. It has mixed financial/inventory content, required date selection, nullable estimates, completeness flags, fallback labels, and source-order-dependent movement presentation.

Using the controller introduces UI state; using the repository directly breaks the domain-boundary rule. AI must not duplicate or selectively reformat those calculations. A dedicated immutable report boundary, scope/privacy decision, and ordering contract are required first.

## Candidates rejected at discovery

| Candidate | Precise reason |
| --- | --- |
| Document history | `DocumentHistoryRepository.listHistory` returns an unmodifiable list, but traverses sales and purchase repositories, constructs records, and applies UI-shaped filters/search; no AI privacy/scope decision exists. |
| Audit-log history | `AuditLogRepository.listLogs` is raw audit data containing actor identities and internal reasons; retention, filtering, and authorization policy are not frozen. |
| Backup validation/preview | `BackupRestorePreviewService.preview` requires raw backup content; AI exposure has unresolved privacy and retention policy. |
| Stock movements; sales/purchase summaries | Sources are raw repositories plus screen/controller aggregation; no immutable report DTO/service or settled read-report permission exists. |

These exclusions preserve BUILD-14's conclusion without inventing additional candidates or treating repository/UI traversal as a canonical domain API.

## Authorization, ordering, and prohibited transformations

No candidate has an authorized future action name. Any later boundary must be read-only and domain-owned, return its immutable existing result directly, and receive authorization before invocation.

Current visible-source evidence supports `canViewFinancialReports` for party reports and `canProceed` plus `canViewReports` for daily activity. No new permission is proposed. The owner must decide whether those permissions are sufficient for AI exposure of identity-rich or mixed content once a safe boundary exists.

AI must preserve qirsh values, totals, reversals, ordering, nullable IDs/references/estimates, fallback labels, errors, and empty results. It must not calculate, sort, group, filter, join, resolve identities, select dates, access repositories, create a lookup, reinterpret missing values, or change financial meaning.

## Required owner decisions

1. Choose one business report, if any, for a separately authorized domain prerequisite; BUILD-15 makes no recommendation because none is eligible.
2. Freeze its exact time/default and filter policy, including whether the dynamic current-month default is acceptable.
3. For party reports, decide whether customer/supplier identity and reversal linkage may be exposed under `canViewFinancialReports`, including unresolved identity behavior.
4. Require configured identity resolution and immutable result collections from the domain owner; AI must receive only that configured boundary.
5. For daily activity, decide whether mixed financial/inventory and estimated-cost content merits a dedicated boundary and whether `canViewReports` is sufficient. BUILD-15 authorizes none of that work.

Only after owner approval and a separately delivered prerequisite may another scope-freeze review consider a non-binding action name. BUILD-16 could be implementation only after that approval; BUILD-15 is not one.

## Explicit BUILD-15 non-goals

BUILD-15 changes no production Dart, UI, schema, migration, backup format, accounting, inventory, permission, test, runtime behavior, registry, tool, reader, model, serializer, export, Action ID, or executable contract. It does not modify the protected screen, stage `.build-diagnostics/`, create a tag, or push.

## Protected-file verification

Protected path: `lib/features/financial_reports/advances_and_refunds_report_screen.dart`

| Check | Required value |
| --- | --- |
| SHA-256 | `A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C` |
| Git blob | `22800a9ccb08ee5796f0fa69c87bd9995739adbf` |
| Size | `32418` bytes |

Preflight matched all three values. BUILD-15 never writes this file; final verification follows documentation-only gates.

## Verification evidence and final delivery

This document is the only intended BUILD-15 change. Before commit, BUILD-15 runs `git diff --check`, the full Flutter test suite, `flutter analyze --no-pub`, the direct bundled Dart SDK analyzer, and a Windows Release build. Flutter SDK commands run outside the restricted sandbox because the SDK cache lockfile is not writable there. BUILD-15 does not run `flutter clean` or delete generated artifacts.

Verification completed successfully before staging:

- `git diff --check` completed without diff errors. Git printed only CRLF
  notices for the inherited protected file and generated Windows plugin files;
  the latter were not modified in `git status`.
- `flutter test` outside the sandbox passed **1,396** tests with **0**
  failures and **1** expected skip.
- `flutter analyze --no-pub` outside the sandbox reported no issues.
- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze` reported no
  issues.
- `flutter build windows --release` outside the sandbox exited **0** and
  produced `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
  (785,408 bytes; modified `2026-07-19 00:38:37` local time). The only build
  warnings were the existing Firebase CMake deprecation and MSVCRT LNK4078.
- The protected file recheck matched the SHA-256, Git blob, and size above.
- Before staging, `git status --short` contained only the inherited protected
  modification, untracked `.build-diagnostics/`, and this document.

No production implementation occurred. `.build-diagnostics/` is excluded from
staging. BUILD-15 creates no tag and does not push.
