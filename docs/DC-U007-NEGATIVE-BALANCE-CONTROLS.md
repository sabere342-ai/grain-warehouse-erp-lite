# DC-U007 — Negative-Balance Controls

## Decision Reference
- **Decision ID:** DC-U007
- **Adopted:** Phase 78 (Financial Owner Decisions Compatibility Audit)
- **Implemented:** Post-Phase 81 (Governance Baseline)
- **Status:** IMPLEMENTED

## Summary
Per-account Boolean `allowNegativeBalance` field controls whether outflow entries are allowed to bring a financial account below zero. Owner-only toggle. Default is `false` (negative balance blocked).

## Behavioral Rules

### Default (allowNegativeBalance = false)
- Outflow entries that would bring the account balance below zero are **blocked** with `StateError`
- Applies to all outflow paths: expenses, supplier payments, purchase payments
- Transfers from the source account are also blocked if balance would go negative
- Inflow entries are always allowed regardless of this setting

### When enabled (allowNegativeBalance = true)
- Outflow entries are allowed even if they bring the balance below zero
- Transfers from the source account are allowed even with insufficient balance
- Each negative-balance operation is recorded in the audit log via the existing entry audit trail
- The owner can toggle this setting on/off at any time

### Owner-only control
- Only users with `UserRole.owner` can toggle `allowNegativeBalance` via `FinancialAccountController.updateNegativeBalancePolicy()`
- Employee users are blocked from this operation with error message: `إدارة الحسابات المالية متاحة للمالك فقط.`

## Implementation Details

### Model changes
- `FinancialAccount.allowNegativeBalance` — new Boolean field, default `false`
- `FinancialAccountDraft.allowNegativeBalance` — new optional Boolean field, default `false`

### Repository changes
- `FinancialAccountRepository.updateAccountPolicy()` — new abstract method
- `LocalFinancialAccountRepository.updateAccountPolicy()` — toggles `allowNegativeBalance` on an account, records audit log
- `LocalFinancialAccountRepository.createEntry()` — now checks projected balance before posting outflows; blocks if balance would go negative and `allowNegativeBalance` is `false`
- `LocalFinancialAccountRepository.createTransfer()` — now skips balance check when source account has `allowNegativeBalance = true`

### Controller changes
- `FinancialAccountController.updateNegativeBalancePolicy()` — owner-only method to toggle `allowNegativeBalance`

### Backup contract
- **Export:** `allowNegativeBalance` is included in financial account JSON (backward-compatible addition)
- **Restore:** Old backups without `allowNegativeBalance` default to `false` on restore
- Backup version remains at `6` (field addition is backward-compatible)

### Affected posting paths
| Path | Repository | Guard location |
|------|-----------|----------------|
| Expense outflow | `ExpenseRepository.createExpense` | `FinancialAccountRepository.createEntry` |
| Supplier payment outflow | `SupplierAccountRepository.createPayment` | `FinancialAccountRepository.createEntry` |
| Purchase payment outflow | `PurchaseRepository` (via entry) | `FinancialAccountRepository.createEntry` |
| Transfer source outflow | `FinancialAccountRepository.createTransfer` | Direct balance check in `createTransfer` |

## Test Coverage
- 28 focused tests in `test/dc_u007_negative_balance_controls_test.dart`
- Covers: model defaults, draft defaults, createAccount passthrough, updateAccountPolicy toggle, balance guard blocking, balance guard allowing, re-disable behavior, inflow unaffected, transfer respects policy, ExpenseRepository integration, SupplierAccountRepository integration, backup roundtrip, controller owner enforcement
- 10 existing tests updated to accommodate new guard behavior

## Audit Trail
- `financial_account.negative_balance_policy.updated` — recorded when owner toggles `allowNegativeBalance`
- Existing entry-level audit (`financial_account.entry.created`) records each outflow that proceeds under negative balance
