# Phase 34 – Customer Credit & Collections

## Accounting model

- Customer balance is derived from the ledger, not a manual editable balance field.
- Balance formula: total debit entries minus total credit entries.
- Credit sales create a debit entry.
- Collections create a credit entry.
- Collections never change inventory or create new sales revenue/profit.

## Credit sale behavior

- Cash sales create no customer receivable.
- Credit sales require an active customer.
- Disabled customers are rejected for new credit sales.
- A successful credit sale creates exactly one ledger debit entry for the sale total.

## Collection behavior

- Collections are only allowed when the customer has an outstanding positive balance.
- Collections cannot exceed the current balance.
- Zero and negative collections are rejected.
- Collections create a credit ledger entry and an audit log entry.

## Statement behavior

- Customer statements are built from real ledger entries.
- Each line shows the transaction, its debit/credit impact, and the running balance.
- The final statement balance is the net ledger balance.
- There is no fake opening balance in Phase 34.

## Reports impact

- Daily activity reports include separate totals for credit sales and collections.
- Outstanding receivables are derived from positive customer balances in the ledger.
- Collections are not counted as sales revenue or profit.
- Existing missing-cost warnings remain unchanged.

## Backup and restore impact

- Backup export includes customer ledger entries and customer collections.
- Backup export also includes sale payment mode and sale customer ID.
- Restore supports missing Phase 34 lists as empty and missing sale payment mode/customer ID as defaults.
- Restored balances are recalculated from ledger entries rather than stored balances.

## Validation rules

- Credit sales require a customer ID and an active customer.
- Minimum sale price validation remains enforced.
- Collection amounts must be positive and cannot exceed the outstanding balance.

## Remaining limitations

- Phase 34 focuses on ledger-based receivables and collections only.
- UI work is intentionally limited to wiring the core accounting path and keeping the existing navigation intact.
