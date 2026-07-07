# Phase 31 - Strict No-Hidden-Pages Functional Recovery

## What Phase 31 corrected
Phase 30 hid the Customers, Expenses, and Audit Logs navigation entries because those pages were not ready. Phase 31 corrects that decision under the stricter project rule: visible pages must be real and useful, not hidden to avoid work.

## Pages restored/enabled
- Customers / العملاء
- Expenses / المصروفات
- Audit Logs / سجل التدقيق

## What each page can do

### Customers
- Lists local customers.
- Adds a customer with name, optional phone, optional notes, and active status.
- Edits customer data safely.
- Disables and reactivates customers instead of hard deletion.
- Records audit entries for add, edit, disable, and reactivate actions.

### Expenses
- Lists expenses sorted by date descending.
- Adds an expense with date, category/name, amount, and optional notes.
- Validates amount with integer money parsing: positive only, no negatives, no empty amount, and no invalid decimals.
- Validates category/name as required.
- Includes expenses in daily reports through `totalExpenseAmountQirsh`.
- Does not change inventory movements or stock balances.
- Does not mix expenses with purchase intake records.

### Audit Logs
- Shows recorded audit events in a read-only owner-only page.
- Displays timestamp, action type, Arabic description, and optional reference id.
- Does not expose edit or delete actions.
- Records Phase 31 customer actions, expense creation, and local theme changes.

## Accounting boundaries
- Customers do not invent balances. The page only stores basic customer identity/status notes.
- Expenses are money records only. They do not affect grain stock quantity and are not purchase documents.
- Audit logs are read-only evidence for important local actions, not an editable business ledger.

## Backup/restore impact
- Backup export now includes customers, expenses, and audit logs with counts.
- Restore to empty systems restores customers, expenses, and audit logs.
- Backup preview accepts older backups that do not include Phase 31 lists by treating the missing lists as empty.
- Owner data wipe includes the new Phase 31 data after a successful backup.

## Tests and verification
- `flutter.bat analyze --no-pub` - Passed. No issues found.
- `flutter.bat test test\phase31_functional_recovery_test.dart` - Passed. 5 tests passed.
- `flutter.bat test` - Passed. 246 tests passed.
- `flutter.bat build windows --release` - Pending final run.

## Remaining honest limitations
- Customer balances are intentionally not shown until credit/deferred sales and collection logic exists as a coherent accounting module.
- Expenses currently support creation and reporting, but not editing or cancellation. Corrections should be added in a later accounting phase with audit-safe reversal behavior.
- Audit logging is a local foundation for important actions added in Phase 31; older historical actions before this phase are not backfilled.

