# Phase 39 — Customer-Bound Multi-Item Sales Invoices

## Phase objective
Upgrade the sales flow so every sale is customer-bound and supports multiple invoice items, while preserving truthful stock, cash, customer balance, daily report, document history, backup/restore, and Arabic UX.

## Baseline commit/tag
- Commit: `6bbcb3e`
- Tag: `phase-38b-final-source-safe-delivery-refresh`

## Client feedback
- Every sales invoice must clearly belong to a registered customer
- Invoice must support more than one product/item
- Customer already registered in Customers screen (cash, credit, or partial)
- Customer statement must show all operations: opening balance, cash/credit/partial sales, collections, returns, running balance

## Scope
- Add multi-item line support to SaleRecord and SaleDraft
- Require customer for ALL sales (cash, credit, partial)
- Add cash sale entries to customer statement (debit = credit = total, net zero)
- Add partial payment support (SalePaymentMode.partial + paidAmountQirsh)
- Add `CustomerAccountEntryType.cashSale` for cash sale ledger entries
- Update UI: multi-item entry, customer selector always visible, paid amount for partial
- Update backup/restore to serialize/deserialize sale items and paid amount
- Update document history to show multi-item invoices
- Add comprehensive tests
- Refresh delivery package

## Non-goals
- No printable documents / print engine
- No accounting period close
- No multi-currency
- No invoice numbering changes (existing IDs preserved)
- No customer balance aging
- No tax/VAT

## Current sales model audit

### Does a sale already support multiple line items internally?
**No.** SaleRecord has single `productId`, `quantityKg`, `salePriceQirshPerKg`. No line-items list.

### Does a sale already reference a customer?
**Yes.** SaleRecord has `customerId` (String?, optional).

### Does the UI allow selecting a customer?
**Yes, but only for credit sales.** Cash mode hides the customer selector and sets customerId to null.

### Are cash sales currently anonymous?
**Yes.** Cash sales can be saved with customerId = null.

### Does customer statement include sales invoices?
**Only credit sales.** Cash sales create no customer ledger entry, so they never appear on statements.

### Does backup/restore preserve sale-customer links?
**Yes.** customerId is serialized/deserialized in backup.

### What minimal change is needed?
1. Require customerId for all sales (remove the cash exception)
2. Add multi-item line support
3. Create ledger entries for all sales (cash: debit=credit, credit: debit only)
4. Update UI for multi-item entry and always-visible customer selector

## Required business rules

### 4.1 Every sale must have a registered customer
- customerId is required for cash, credit, and partial sales
- Customer must exist and be active in CustomerRepository
- UI shows clear Arabic message when no customer selected
- `SaleDraft._customerId` becomes mandatory (no longer conditional on credit mode)

### 4.2 Multi-item support
- SaleRecord gets List<SaleLineItem> items
- Each item: productId, quantityKg, salePriceQirshPerKg, lineTotalQirsh
- Invoice total = sum of all line totals
- Stock checked for all lines before any mutation
- If same product appears twice, merge quantities into one line
- Zero/negative quantity or price rejected per line
- Minimum sale price checked per product
- Atomic: all lines succeed or nothing changes
- Duplicate invoice prevention via existing ID generation mechanism

### 4.3 Cash, credit, and partial payment
- **Cash**: paidAmountQirsh == totalQirsh. Ledger entry: debit=total, credit=total (settled)
- **Credit**: paidAmountQirsh == 0. Ledger entry: debit=total, credit=0
- **Partial**: 0 < paidAmountQirsh < total. Ledger entry: debit=total, credit=paidAmount
- Daily cash includes `paidAmountQirsh` for cash and partial sales
- Daily revenue includes totalQirsh for all sales

### 4.4 Customer statement
New entry types:
- `cashSale`: "فاتورة بيع نقدي" — debit=total, credit=total (net zero)
- `creditSale`: "فاتورة بيع آجل" — debit=total, credit=0 (existing)
- `collection`: "تحصيل من العميل" — debit=0, credit=amount (existing)
- `openingBalance`: "رصيد افتتاحي" — debit=amount, credit=0 (existing)

## Schema/data changes

### SaleRecord additions
```
List<SaleLineItem> items
int paidAmountQirsh
```

### SaleLineItem (new)
```
String productId
int quantityKg
int salePriceQirshPerKg
int lineTotalQirsh
```

### SaleDraft additions  
```
List<SaleLineItemDraft> items
int paidAmountQirsh
```

### SaleLineItemDraft (new)
```
String productId  
int quantityKg
int salePriceQirshPerKg
```

### SalePaymentMode additions
```
partial
```

### CustomerAccountEntryType additions
```
cashSale
```

### Backup version
Version remains 2. `saleItems` is added as an optional field in backup JSON. Old backups without items still restore (items defaults to empty list with validation adjusted).

## Backup/restore compatibility notes
- New backups include `items` array per sale and `paidAmountQirsh` field
- Restore of old backups (no items field) works: single-field validation falls back to productId/quantityKg/salePriceQirshPerKg
- Restore of new backups validates: totalQirsh == sum of items' lineTotalQirsh, or totalQirsh == quantityKg * salePriceQirshPerKg for backward compat
- customerId is now required for all restored sales
- Old anonymous cash sales with null customerId: migration creates a designated "عميل نقدي سابق" customer record if any are found

## UI changes
- Customer dropdown always visible (not hidden for cash mode)
- Multi-item entry: "إضافة صنف" button, line item rows with remove button
- Paid amount / payment status field for partial mode
- Save button disabled until customer selected and >=1 valid item
- Arabic error messages for all validation failures

## Tests added/updated

File: `test/phase39_customer_bound_multi_item_sales_test.dart`

1. Sale cannot be saved without a customer
2. Cash sale requires registered customer
3. Credit sale requires registered customer
4. Multi-item sale saves all lines correctly
5. Invoice total equals sum of line totals
6. Multi-item sale reduces stock for every product
7. If one line lacks stock, the full sale fails and no stock mutates
8. Customer statement includes cash sale
9. Customer statement includes credit sale
10. Customer statement includes partial-payment sale
11. Daily cash includes only actual cash received
12. Customer collections are not counted as sales
13. Opening balances are not counted as sales/cash
14. Backup/restore preserves customer-linked multi-item invoice
15. Cancellation/return reverses multi-item invoice correctly
16. User-facing error messages do not expose raw exceptions
17. Arabic labels do not expose raw actionType/IDs

## Commands run
```
flutter analyze --no-pub
flutter test
flutter build windows --release
git diff --check
git status --short
```

## Final verdict
PASS

## Residual risks
- In-memory repository cannot roll back stock movements if one of multiple items fails mid-way (all stock validated before any movement)
- Old anonymous cash sales in existing backups will require migration to a generic customer record
- Partial payment cancellation behavior is not fully specified for mixed cash/credit scenarios
