# Transfer data flow

```text
FinancialTransferDraft + owner
  -> FinancialAccountRepository.createTransfer
  -> request/reference idempotency checks
  -> one FinancialTransfer business document
  -> one source transferOut entry (-amount)
  -> one destination transferIn entry (+amount)
  -> statement/currentBalance signed aggregation
  -> account-specific reports retain the applicable leg
  -> transferReport reads the business document once
  -> all-account inflow/outflow and payment-method reports exclude transfer types
```

Production anchors:

- `financial_account_repository.dart:921-1088` creates the transfer and paired
  entries atomically in the local repository and returns the existing document
  for an identical `clientRequestId` retry.
- `drift_financial_account_repository.dart:175-181` wraps the same operation in
  the durable write boundary.
- `financial_report_service.dart:429-490` declares all four transfer/reversal
  source types and excludes them when the flow report spans all accounts.
- `financial_report_service.dart:334-419` builds the transfer report from
  transfer documents, not by summing both ledger legs.
- `profitability_report_service.dart:46-87` derives revenue/COGS/expenses/profit
  from sales and expenses; it has no financial-transfer dependency.
- `dashboard_service.dart:101-184` derives sales and expenses from their domain
  repositories. Financial accounts are used for balances, not for reclassifying
  transfers as sales or expenses.

Potential duplicate sites audited:

1. ledger entry creation: correct pair, equal and opposite;
2. retry: protected by `clientRequestId` and payload match;
3. balance aggregation: signed amount, so net zero across both accounts;
4. all-account cash flow: transfer source types explicitly excluded;
5. account-specific cash flow: one relevant leg is intentionally visible;
6. transfer report: one row per business document;
7. profit/dashboard: no transfer input path;
8. backup/restore: transfer documents and linked entries are serialized and
   restored as separate typed collections, with uniqueness/link validation;
9. business-data wipe: the financial repository clears entries and transfers
   within the existing atomic wipe orchestration.
