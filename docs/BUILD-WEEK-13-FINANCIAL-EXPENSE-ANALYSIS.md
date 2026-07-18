# BUILD-13 — Financial Expense Analysis AI Action

## Goal

BUILD-13 adds the explicit, read-only AI action
`financial_expense_analysis`. It exposes the existing canonical expense
analysis through the configured financial-report service; it does not create a
global registry, production composition, UI wiring, or a new domain API.

## Execution contract

- Action ID: `financial_expense_analysis`.
- Execution mode: `AiExecutionMode.readOnly` only.
- Confirmation: not required.
- The action has no writes, mutations, side effects, networking, exports, or
  tool chaining.
- Authorization requires a non-null active caller with
  `canViewFinancialReports`. Validation and authorization complete before the
  reader is invoked. Owner role is not used as a substitute for this
  permission.

## Input contract

The payload is the existing typed object input to `AiIntent`; `{}` is valid.
It accepts only these optional keys:

```json
{
  "accountId": "optional non-blank string",
  "paymentMethod": "cash | bankTransfer | mobileWallet | check",
  "category": "optional non-blank string"
}
```

`accountId` and `category` reject null, non-string, blank, and whitespace-only
values. Both are forwarded unchanged: the action does not trim or look up an
account. `paymentMethod` rejects null, non-string, and every non-canonical
name; exact enum names are converted with `PaymentMethod.values.byName`.
There are no aliases or capitalization normalization.

Every extra key is rejected, including a null extra value. This explicitly
includes date keys (`startDate`, `endDate`, `date`, `month`, `year`, `from`,
`to`), sorting keys (`sort`, `sortBy`, `order`), pagination keys (`page`,
`pageSize`, `offset`, `limit`), and all other unlisted keys.

## Reader and domain boundary

`FinancialExpenseAnalysisReportReader` is the narrow read-only boundary. Its
`FinancialReportServiceExpenseAnalysisReader` adapter depends only on an
already configured `FinancialReportService` and delegates directly to:

```dart
service.expenseAnalysisReport(
  accountIdFilter: accountIdFilter,
  paymentMethodFilter: paymentMethodFilter,
  categoryFilter: categoryFilter,
)
```

No date parameters are passed. Therefore the existing service remains the
sole owner of the current-month default, clock use, data access, filtering
semantics, grouping, totals, percentages, and canonical ordering.

The action returns the exact `ExpenseAnalysisReport` instance as `data`. It
does not build a DTO, map, table, copy, sorted list, or recalculated total. It
preserves rows, details, zero values, qirsh signs, nullable notes, labels,
counts, `double percentageOfTotal`, and empty-report behavior exactly as the
domain service supplied them. The tool and reader have no repository,
database, storage, or service-locator dependency.

## Files

Added:

- `lib/features/ai_assistant/tools/financial_expense_analysis_tool.dart`
- `test/financial_expense_analysis_tool_test.dart`
- `docs/BUILD-WEEK-13-FINANCIAL-EXPENSE-ANALYSIS.md`

Modified:

- `lib/features/ai_assistant/services/financial_account_balance_report_reader.dart`
- `lib/features/ai_assistant/ai_assistant.dart`

The protected
`lib/features/financial_reports/advances_and_refunds_report_screen.dart` and
untracked `.build-diagnostics/` remain outside BUILD-13 and staging.

## Verification

The focused BUILD-13 test exercises the explicit export and registry use,
read-only metadata, every allowed filter combination, rejected values and
keys, permission-before-reader behavior, safe reader failure handling, exact
report identity, and direct-service-delegation source checks. Final command
results, protected-file proof, release-build details, and Git delivery status
are recorded in the BUILD-13 delivery report after verification.

No tag or push is created by BUILD-13.
