# Phase 71 — Unified Financial Accounts Foundation

## Date
2026-07-10

## Summary
Created a unified local financial accounts system: account model (treasury, bank, electronic wallet), append-only ledger, opening balances with corrections, activate/deactivate, backup v4, and comprehensive tests.

## Scope
- Financial account model with type enum
- Append-only financial ledger
- Opening balance (set once, corrections via entries)
- Activate/deactivate accounts (owner-only)
- Account statement with date filtering
- Backup v4 with financial data (backward-compatible v1/v2/v3)
- Dashboard navigation (owner-only)

## Out of Scope
- Account selection in transactions (Phase 72)
- Payment method tracking (Phase 72)
- Internal transfers (Phase 73)
- Daily cash closing (Phase 73)
- Financial reports (Phase 73)
- Cloud, Mobile, Multi-device

## Files Created

### Models
- `lib/core/financial_accounts/financial_account.dart` — FinancialAccount, FinancialAccountType enum, FinancialAccountDraft
- `lib/core/financial_accounts/financial_account_entry.dart` — FinancialAccountEntry, FinancialAccountEntryDirection, FinancialAccountEntrySource, FinancialAccountStatement, FinancialAccountBalanceSummary, OpeningBalanceCorrectionDraft

### Repository & Controller
- `lib/core/financial_accounts/financial_account_repository.dart` — Abstract FinancialAccountRepository + LocalFinancialAccountRepository
- `lib/core/financial_accounts/financial_account_controller.dart` — ChangeNotifier controller

### UI
- `lib/features/financial_accounts/financial_accounts_screen.dart` — Account list screen
- `lib/features/financial_accounts/financial_account_statement_screen.dart` — Statement screen with date filtering

### Tests
- `test/phase71_unified_financial_accounts_foundation_test.dart` — 44 tests

## Files Updated
1. `lib/app/app_repositories.dart` — added financialAccountRepository
2. `lib/features/dashboard/dashboard_shell.dart` — added financial accounts nav item
3. `lib/core/backup/backup_export.dart` — v4, financial accounts sections
4. `lib/core/backup/backup_restore_service.dart` — v4 restore support
5. `lib/core/backup/backup_restore_preview.dart` — v4 preview support
6. `lib/core/backup/business_data_wipe_service.dart` — financial accounts wipe

## Documentation Updated
1. `docs/MASTER-PRODUCT-ROADMAP.md` — Phase 71 completed
2. `docs/REQUIREMENTS-TRACEABILITY-MATRIX.md` — ACC-007, ACC-008 implemented
3. `docs/ROADMAP-DECISION-REGISTER.md` — DC-R001 implemented
4. `docs/DEVELOPER-HANDOFF-NOTES.md` — Phase 71 section added

## Tests Updated (backup version 3→4)
1. `test/phase13_backup_export_test.dart`
2. `test/phase14_backup_file_save_test.dart`
3. `test/phase15_restore_preview_test.dart`
4. `test/phase37a_opening_balances_test.dart`
5. `test/phase68_business_logo_invoice_windows_icon_test.dart`

## Key Design Decisions

### Balance Calculation
Balance = `account.openingBalanceQirsh` (metadata) + `sum(entries.signedAmountQirsh)`.
Opening balance is account metadata; entries are actual financial movements.
`currentBalanceForAccount()` sums ledger entries; `account.openingBalanceQirsh` provides starting context.

### Opening Balance Correction
Append-only correction entries. Original entry reversed via outflow; new entry created via inflow. Both linked by `correctionGroup` ID. Requires reason. Owner-only.

### Backup Version
Upgraded to v4 with optional `financialAccounts` and `financialAccountEntries` sections.
v1/v2/v3 restore still works (backward-compatible).

### Navigation
Owner-only dashboard destination using `_ShellDestination` with `requiresFinancialAccounts` flag.

## Verification
- `flutter analyze`: 0 errors, 0 warnings
- `flutter test`: 630/630 passing (44 new)
- `flutter build windows --release`: succeeded

## Git
- Commit: pending
- Tag: `phase-71-unified-financial-accounts-foundation`
