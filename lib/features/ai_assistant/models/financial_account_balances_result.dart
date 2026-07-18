import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';

/// Immutable, read-only projection of the financial account balance report.
final class FinancialAccountBalanceItem {
  const FinancialAccountBalanceItem({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.isActive,
    required this.openingBalanceQirsh,
    required this.totalInflowsQirsh,
    required this.totalOutflowsQirsh,
    required this.currentBalanceQirsh,
  });

  final String accountId;
  final String accountName;
  final FinancialAccountType accountType;
  final bool isActive;
  final int openingBalanceQirsh;
  final int totalInflowsQirsh;
  final int totalOutflowsQirsh;
  final int currentBalanceQirsh;
}

final class FinancialAccountBalanceTotals {
  const FinancialAccountBalanceTotals({
    required this.openingBalanceQirsh,
    required this.totalInflowsQirsh,
    required this.totalOutflowsQirsh,
    required this.currentBalanceQirsh,
  });

  final int openingBalanceQirsh;
  final int totalInflowsQirsh;
  final int totalOutflowsQirsh;
  final int currentBalanceQirsh;
}

final class FinancialAccountBalancesResult {
  FinancialAccountBalancesResult({
    required List<FinancialAccountBalanceItem> accounts,
    required this.totals,
  })  : accounts = List<FinancialAccountBalanceItem>.unmodifiable(accounts),
        isEmpty = accounts.isEmpty;

  final List<FinancialAccountBalanceItem> accounts;
  final FinancialAccountBalanceTotals totals;
  final bool isEmpty;
}
