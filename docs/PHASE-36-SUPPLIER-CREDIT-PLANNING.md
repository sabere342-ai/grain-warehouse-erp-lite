# Phase 36 - Supplier Credit Planning

## Purpose
Phase 36 would add supplier credit (ائتمان موردين) as the mirror of the customer credit workflow implemented in Phase 34/35. This would allow recording purchases on credit from suppliers and tracking payable balances.

## Status
**Not started — pending pilot evidence per the Next Phase Decision Gate.**

## Proposed scope
- Supplier account ledger model (mirror of customer accounts): purchase-on-credit debits, payment credits, derived balances.
- Payment to suppliers with validation against outstanding balance.
- Supplier statement with ledger lines.
- Reports: total supplier payables, total payments to suppliers.
- Backup/restore for supplier ledger movements.

## Out of scope
- Opening balances or prepayments.
- Negative supplier balances (overpayment).
- Cloud sync, bank integration, or automated payment.
- Any change to the existing cash purchase flow.

## Prerequisites
- Pilot delivery handoff completed.
- Customer feedback collected and evaluated.
- Decision gate passed.

## Reference
- Phase 34 customer credit model: `lib/features/customer_account/`
- Phase 35 customer credit UI: `lib/features/customers/customers_screen.dart`, `lib/features/sales/`
- Product roadmap item 5: Supplier payment tracking
