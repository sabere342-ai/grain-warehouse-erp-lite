# Phase 79 — Account-Based Financial Reports Implementation

## Summary
- **Commit**: (leave empty, will be filled)
- **Tag**: `phase-79-account-based-financial-reports-implementation`
- **Date**: 2026-07-11
- **Tests**: 774/774 passing (709 baseline + 65 new)

## Scope
Implemented 4 production-grade financial reports with permission-gated access, PDF/CSV export, and comprehensive filtering:

1. **Account Balance Report** — Per-account opening/closing balance with inflow/outflow totals
2. **Account Statement Report** — Per-account entry-level statement with running balance, reversal status
3. **Payment Method Report** — Aggregated by payment method, excluding transfer entries
4. **Transfer Report** — Authoritative transfer register with reversal/reversed tracking

## Architecture
- **FinancialReportService** (core) — Pure aggregation service reading from `FinancialAccountRepository`
- **FinancialReportModels** (core) — Immutable report row/result data classes
- **Financial Report Screens** (feature) — 5 screens: hub + 4 report views
- **FinancialReportPdfBuilder** (exports) — PDF generation for all 4 reports
- **FinancialReportCsvExporter** (exports) — CSV export with UTF-8 BOM

## Production Code Changed
| File | Change |
|------|--------|
| `lib/core/auth/permissions.dart` | Added `canViewFinancialReports`, `canExportFinancialReports` |
| `lib/core/financial_accounts/financial_report_models.dart` | NEW — 6 model classes |
| `lib/core/financial_accounts/financial_report_service.dart` | NEW — 343 lines, 4 report methods |
| `lib/features/financial_reports/financial_reports_screen.dart` | NEW — Hub screen with permission gate |
| `lib/features/financial_reports/account_balance_report_screen.dart` | NEW — Balance report with filters and export |
| `lib/features/financial_reports/account_statement_report_screen.dart` | NEW — Statement with running balance |
| `lib/features/financial_reports/payment_method_report_screen.dart` | NEW — Payment method aggregation |
| `lib/features/financial_reports/transfer_report_screen.dart` | NEW — Transfer register with status tracking |
| `lib/features/exports/financial_report_pdf_builder.dart` | NEW — PDF generation for 4 reports |
| `lib/features/exports/financial_report_csv_exporter.dart` | NEW — CSV export for 4 reports |
| `lib/features/exports/pdf_file_naming.dart` | Added 8 financial report file naming methods |
| `lib/features/exports/pdf_export_service.dart` | Added 8 financial report export methods |
| `lib/features/dashboard/dashboard_shell.dart` | Added "التقارير المالية" navigation entry |

## Tests Changed
| File | Tests |
|------|-------|
| `test/phase79_account_based_financial_reports_test.dart` | NEW — 65 tests |

## Key Design Decisions
- Reports are read-only from existing ledger data (no schema changes)
- Transfers excluded from Payment Method Report via `transferSourceTypes` set filtering
- Reversal treatment: original entries shown, reversal status indicated
- Permission model: two new boolean flags with safe defaults (false)
- Account Balance: opening balance computed from entries before period start
- Statement: deterministic sort by effectiveDate then ID
- Transfer Report: based on authoritative transfer register, not double-parsed entries

## Known Limitations
- PDF export requires platform-level `open_filex` for file opening
- Transfer reversal effectiveDate uses `DateTime.now()` (test timing dependent)

## Next Recommended Phase
Phase 80 — Period Closing / Daily Closing / Reconciliation (depends on backup contract fix)
