# Phase 81 — Transaction-Level Financial Backup/Restore Contract Remediation

## Governance

Phase 81 was explicitly adopted by the owner after the post-Phase-80 Next Roadmap Scope Governance Audit. The official completion tag is `phase-81-transaction-level-financial-backup-restore-contract-remediation`.

## Scope

Backup and restore now preserve the original `financialAccountId` and `paymentMethod` on:

- Sales
- Purchases
- Customer collections
- Supplier payments
- Expenses

Split Payments (`DC-U002`), negative-balance controls (`DC-U007`), overpayments/refunds (`DC-U008`), transaction cancellation, Cloud Sync, multi-device, mobile, SaaS, licensing, and unrelated UI are explicitly excluded.

## Contract and accounting behavior

- The transaction keeps the exact financial-account ID and `PaymentMethod` enum name recorded before export.
- Restore accepts only known payment-method names and validates that each non-null transaction account reference exists in the restored financial-account set.
- Missing fields in v1–v5 restore as `null`; no account or payment method is inferred or fabricated.
- Export and restore do not create ledger entries, balancing entries, stock movements, or accounting corrections.
- Financial-account balances remain derived from the restored ledger. Phase 79 reports and Phase 80 closing/reconciliation calculations are unchanged.
- Invalid account references fail during parse/validation before repository writes begin.

## Persistence and compatibility

The JSON format changes from v5 to v6 because transaction records gain two persisted fields. `BackupRestorePreviewService` accepts v1–v6. Existing v1–v5 backups remain valid, with safe `null` defaults for the new fields.

No database or schema migration exists because the application persists through in-memory repositories plus JSON backup/restore.

## Production files

- `lib/core/backup/backup_export.dart`
- `lib/core/backup/backup_restore_service.dart`
- `lib/core/backup/backup_restore_preview.dart`

## Tests

`test/phase81_transaction_financial_backup_contract_test.dart` provides real service-level coverage for:

1. v6 JSON export for all five transaction types.
2. Full export/restore round trip preserving account and payment method.
3. Unchanged stock and financial-account balance after round trip.
4. v5 records without the new fields restoring `null` without invention.
5. Corrupt account references rejected before writes.
6. v1–v5 compatibility.

Existing backup-version assertions were updated to v6 without weakening their behavior checks.

## Verification

- Focused Phase 81 tests: 5/5 passing.
- Analyzer: no issues in both final runs.
- Full suite: 784/784 passing in both final runs.
- Windows release build: passing.
- `git diff --check`: passing.

## Known risks

The existing restore architecture writes sequentially after complete parsing, validation, and an empty-system guard; Phase 81 does not introduce repository transaction/rollback infrastructure. This phase ensures corrupt transaction financial references fail before those writes.
