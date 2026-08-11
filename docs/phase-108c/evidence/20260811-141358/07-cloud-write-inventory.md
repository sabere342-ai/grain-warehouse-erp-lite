# Phase 108C — Cloud Write Migration Inventory

| Current write path | Coupled participants / current storage | Required Cloud command | Idempotency required? | Offline first release | Priority |
| --- | --- | --- | --- | --- | --- |
| Create/cancel sale | sale, lines JSON, inventory, valuation/COGS, customer ledger, financial allocations, audit | `PostSale` / `ReverseSale` | Always | Queue provisional | P0 |
| Create/cancel purchase | purchase, inventory, valuation, supplier ledger, financial payment, audit | `PostPurchase` / `ReversePurchase` | Always | Queue provisional | P0 |
| Expense/reclassification | expense, financial entry, approval, audit | `PostExpense` / `ReclassifyExpense` | Always | Queue post; reclass online | P0 |
| Customer collection/cancel | collection, customer ledger, financial entry, audit | `PostCustomerCollection` / reversal | Always | Queue provisional | P0 |
| Supplier payment/cancel | payment, supplier ledger, financial entry, audit | `PostSupplierPayment` / reversal | Always | Queue provisional | P0 |
| Customer/supplier advance/apply/refund/reversal | account payload tables, financial entry, approvals, audit | Specific append/reversal commands | Always | Limited provisional | P0 |
| Transfer/reversal | transfer, two entries, balance approval, audit | `PostTransfer` / `ReverseTransfer` | Always | Online only | P0 |
| Stock adjustment/take | movement, valuation, optional financial entry, audit | `PostStockAdjustment` with base version | Always | Queue observed count | P0 |
| Opening balances | account/customer/supplier/inventory entries | Privileged one-time opening commands | Always | Online only | P0 |
| Close/reopen period | closing snapshot/state and audit | Privileged serialized close/reopen | Always | Online only | P0 |
| Negative-balance request/resolve/consume | requests/transitions, role checks, target command | Server approval workflow | Always | Online only | P0 |
| Product create/update/activate | product row and audit where applicable | Versioned product command | Create/update | Queue low-risk | P1 |
| Customer/supplier create/update/activate | master row and audit | Versioned party command | Create/update | Queue low-risk | P1 |
| Financial account create/policy/deactivate | financial aggregate and audit | Privileged versioned account command | Always | Online only | P1 |
| User/role/device | local auth row/current session | Supabase Auth + membership/device commands | Always | Online only | P0 security |
| Business identity/logo | JSON/file/audit | Versioned settings command + private storage upload | Upload/command | Queue later | P2 |
| Backup restore | whole repository set | Staged import job, validation, reconcile, cutover | Import job and every historic command mapping | Never ordinary outbox | P0 migration |
| Business data wipe | 13 repository clears | Local cache reset or separate privileged business deletion | Always | Cache reset only | P0 terminology |

## Universal critical command envelope

Every critical command must carry a global operation ID, payload version,
canonical fingerprint, authenticated business/actor/device context, client
timestamp metadata, business/effective date, expected versions or dependencies,
and the explicit transaction group. Business scope is derived from the session,
not trusted from the payload alone.

Every result must return accepted/rejected/conflict state, stable result ID,
server time/order, authoritative entity versions and document number, safe error
code, and financial reconciliation totals where applicable.
