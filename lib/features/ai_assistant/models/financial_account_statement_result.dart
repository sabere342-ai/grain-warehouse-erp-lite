import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

/// Immutable, read-only projection of a canonical account statement report.
final class FinancialAccountStatementEntryItem {
  const FinancialAccountStatementEntryItem({
    required this.entryId,
    required this.effectiveDate,
    required this.sourceType,
    required this.direction,
    required this.amountQirsh,
    required this.sourceDocumentId,
    required this.runningBalanceQirsh,
    this.sourceDocumentNumber,
    this.reference,
    this.note,
    this.reversalOf,
    this.paymentMethod,
  });

  final String entryId;
  final DateTime effectiveDate;
  final FinancialAccountEntrySource sourceType;
  final FinancialAccountEntryDirection direction;
  final int amountQirsh;
  final String sourceDocumentId;
  final String? sourceDocumentNumber;
  final String? reference;
  final String? note;
  final String? reversalOf;
  final PaymentMethod? paymentMethod;
  final int runningBalanceQirsh;
}

final class FinancialAccountStatementResult {
  FinancialAccountStatementResult({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.isActive,
    required this.fromDate,
    required this.toDate,
    required this.openingBalanceQirsh,
    required this.closingBalanceQirsh,
    required List<FinancialAccountStatementEntryItem> entries,
  })  : entries =
            List<FinancialAccountStatementEntryItem>.unmodifiable(entries),
        isEmpty = entries.isEmpty;

  final String accountId;
  final String accountName;
  final FinancialAccountType accountType;
  final bool isActive;
  final DateTime fromDate;
  final DateTime toDate;
  final int openingBalanceQirsh;
  final int closingBalanceQirsh;
  final List<FinancialAccountStatementEntryItem> entries;
  final bool isEmpty;
}
