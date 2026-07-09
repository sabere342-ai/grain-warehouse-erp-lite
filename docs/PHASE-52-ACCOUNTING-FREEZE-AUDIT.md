# Phase 52 - Accounting Freeze Audit

## Phase purpose
Phase 52 freezes the current accounting and inventory logic for the local Windows pilot. It documents the source of truth for each important stock and financial number before any cloud migration, mobile app, SaaS, sync queue, or multi-device live sync planning resumes.

No cloud sync was implemented in Phase 52.
No mobile app was implemented in Phase 52.
No SaaS or multi-client behavior was implemented in Phase 52.
No multi-device live sync was implemented in Phase 52.

## Baseline
- Starting commit: `2fb20e1`
- Starting tag: `phase-51-real-business-day-simulation`
- Production code changed in this phase: no
- Schema changed in this phase: no
- Tests added: `test/phase52_accounting_freeze_audit_test.dart`
- Production fix required: none

## Accounting source-of-truth map
| Area | Source of truth | Allowed writers | Forbidden writers | Freeze rule | Notes/limitations |
|---|---|---|---|---|---|
| Product stock quantity | `LocalInventoryRepository.currentStockKg()` derived from `StockMovement.signedQuantityKg`; products do not store stock fields | Purchase intake, sale posting, purchase/sale cancellation reversal, opening balance, stock-taking/manual increase/decrease | Reports, read-only views, stock adjustment report, document history, PDF/export, WhatsApp sharing | Stock must be derived from supported movement records only | No hidden product stock column is currently used |
| Inventory movement history | `LocalInventoryRepository.listAllMovements()` and `listMovementsByProduct()` | Supported stock operations that call `createMovement()` | Reports, document history view, PDF/export, WhatsApp sharing | Movements are append-style audit records; reports must read them and not invent data | The model stores movement quantity/type, not reliable before/after stock balances |
| Customer balance | `LocalCustomerAccountRepository.balanceForCustomer()` from customer account entries | Customer-bound cash/partial/credit sale ledger entries, customer collections, opening balance where allowed | Supplier payments, supplier purchases, inventory adjustments, reports, read-only views | Customer balance is the signed sum of customer ledger entries | Sale cancellation stock reversal is supported, but customer-ledger reversal is not a separate general-purpose API in the current model |
| Supplier balance | `LocalSupplierAccountRepository.balanceForSupplier()` from supplier account entries | Purchases, supplier payments, purchase cancellation reversal where allowed, opening balance | Customer collections, customer sales-only operations, inventory reports, read-only views | Supplier balance is the signed sum of supplier ledger entries | Purchase cancellation reversal is blocked after related supplier payments |
| Daily report totals | `LocalReportRepository.dailyActivityReport()` reading purchases, sales, expenses, collections, supplier entries, inventory movements, and product balances | None; report repository reads source repositories | Any report UI, PDF/export, WhatsApp sharing | Daily reports are read-only and must not calculate from mutable UI text | Estimated profit follows existing reference-cost behavior only |
| Stock-taking | `StockTakeScreen`/`InventoryController` using supported manual movements | Owner stock adjustment permission; manual increase/decrease when actual stock differs | Customer/supplier account repositories, reports, document history | Stock-taking may create only supported stock movement types | It must not invent historic before/after balances |
| Stock adjustment report | Existing `manualIncrease` and `manualDecrease` movement records | None while viewing the report | Product repository, inventory write operations, customer/supplier ledgers, document history | Read-only only | PDF/export remains deferred until reliable before/after stock balances exist |
| Document history | `LocalDocumentHistoryRepository` built from posted purchase/sale records and related movements | Purchase/sale posting and supported cancellation metadata | Viewing history, reports, PDF/export, WhatsApp sharing | Posted documents remain auditable and are not silently deleted | Document history viewing must not mutate balances or stock |
| Backup/restore | Backup export JSON and restore-to-empty validation in backup services | Backup export reads; restore writes only into empty repositories after validation | Restore into non-empty data, silent merge of conflicting histories | Restore must not silently merge financial histories | Current restore is intentionally safe only on an empty system |
| PDF/export | Existing printable/PDF builders reading source models | PDF save/export flow only creates files | Accounting repositories, inventory repositories | Exports must not mutate stock or balances | Stock adjustment report PDF/export is not implemented |
| WhatsApp sharing | Assisted message/link flow reading document data | User-assisted open/share flow | Accounting repositories, inventory repositories, automatic send behavior | WhatsApp remains assisted only and must not post accounting changes | No automatic WhatsApp sending or attachment is implemented |

## Frozen formulas and invariants
### Inventory
- Final stock quantity must equal the result of supported stock-affecting operations.
- Purchase intake increases stock through `StockMovementType.purchaseIntake`.
- Sale posting decreases stock through `StockMovementType.sale`.
- Sale cancellation/reversal restores stock through supported reversal movement behavior.
- Purchase cancellation/reversal reduces stock through supported reversal movement behavior when stock remains available.
- Stock-taking differences create supported `manualIncrease` or `manualDecrease` movement types only.
- Read-only reports never change stock.

### Customer balances
- Customer-bound credit sale increases receivable.
- Cash sale creates the supported customer account impact with debit and matching credit, so it does not create receivable balance.
- Partial sale uses the existing paid amount behavior.
- Customer collection reduces receivable.
- Supplier operations must not affect customer balances.
- Inventory-only adjustments must not affect customer balances.

### Supplier balances
- Purchase increases supplier payable.
- Supplier payment reduces payable.
- Purchase cancellation reversal reduces payable only through the supported supplier ledger reversal behavior.
- Customer operations must not affect supplier balances.
- Inventory-only adjustments must not affect supplier balances.

### Reports
- Daily report totals must match source records: purchases, sales, customer collections, supplier payment entries, expenses, and inventory movements.
- Reports are read-only.
- Reports must not mutate data.
- Reports must not invent unsupported profit or balances.
- Estimated profit and stock valuation must follow existing reference-cost behavior only; if reference cost is incomplete, the existing incomplete-cost behavior must remain honest.

### Documents
- Posted documents must remain auditable.
- Cancellation should use reversal behavior where currently supported.
- Document history must not mutate balances or stock when viewed.

### Stock adjustment report
- The stock adjustment report is read-only.
- It uses manual increase/decrease movements only.
- It does not invent before/after balances.
- It does not promise PDF/export until the data model supports reliable before/after balances.

## Known limitations to preserve honestly
- No cloud sync in the current version.
- No mobile app in the current version.
- No multi-device live sync in the current version.
- No automatic WhatsApp sending unless actually implemented.
- No stock adjustment report PDF/export yet.
- No reliable historical before/after stock balance for old stock movements unless the model stores it.
- Backup restore is safe only into an empty system; it must not silently merge or overwrite live financial histories.
- The current local pilot is one-client, local-only, and in-memory for the active session.
- Estimated profit depends on reference cost data and must stay marked incomplete when reference costs are missing.

## Accounting freeze no-go list
Future cloud/mobile work must not proceed until:
- The frozen source-of-truth map is accepted.
- Every balance-changing operation has duplicate-prevention and idempotency planning.
- Every stock-changing operation has conflict rules.
- Restore/import behavior with cloud data is decided.
- Tenant/client isolation rules are decided.
- Device/actor tracking rules are decided.
- Offline queue rules are decided.
- Reversal/cancellation rules are documented.
- No visible page is fake, incomplete, misleading, or placeholder.

## Result table
| Audit area | Current result | Freeze status | Notes |
|---|---|---|---|
| Inventory quantity | Derived from signed inventory movements | Frozen | No direct product stock field |
| Customer balance | Derived from customer account entries | Frozen | Collections reduce receivables |
| Supplier balance | Derived from supplier account entries | Frozen | Supplier payments reduce payables |
| Daily reports | Read source repositories | Frozen | Read-only; no UI-text totals |
| Stock-taking | Creates supported manual movements | Frozen | Owner-only flow already tested |
| Stock adjustment report | Reads manual movement records | Frozen | Read-only; no invented before/after stock |
| Document history | Reads purchase/sale documents and movements | Frozen | Viewing history does not mutate |
| Backup/restore | Restore only into empty validated system | Frozen | No silent merge of histories |
| PDF/export | Reads documents/reports and writes files | Frozen | No accounting mutation |
| WhatsApp sharing | Assisted sharing only | Frozen | No automatic send or accounting mutation |
| Cloud/mobile | Not implemented | Frozen as absent | Planning may resume later only after accepting this audit |

## Next phase recommendation
Recommended next phase: Phase 53 - Cloud Migration Readiness.

Phase 53 should still be planning/readiness only. It should not implement cloud sync, mobile support, SaaS behavior, API keys, backend services, sync queues, or multi-device live sync.
