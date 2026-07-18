import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

/// Immutable, read-only projection of the canonical payment-method report.
final class FinancialPaymentMethodSummaryRow {
  const FinancialPaymentMethodSummaryRow({
    required this.paymentMethod,
    required this.displayName,
    required this.operationCount,
    required this.totalInflowsQirsh,
    required this.totalOutflowsQirsh,
    required this.netMovementQirsh,
  });

  final PaymentMethod? paymentMethod;
  final String displayName;
  final int operationCount;
  final int totalInflowsQirsh;
  final int totalOutflowsQirsh;
  final int netMovementQirsh;
}

final class FinancialPaymentMethodSummaryTotals {
  const FinancialPaymentMethodSummaryTotals({
    required this.totalInflowsQirsh,
    required this.totalOutflowsQirsh,
    required this.totalNetMovementQirsh,
  });

  final int totalInflowsQirsh;
  final int totalOutflowsQirsh;
  final int totalNetMovementQirsh;
}

final class FinancialPaymentMethodSummaryResult {
  FinancialPaymentMethodSummaryResult({
    required this.fromDate,
    required this.toDate,
    required List<FinancialPaymentMethodSummaryRow> rows,
    required this.totals,
  })  : rows = List<FinancialPaymentMethodSummaryRow>.unmodifiable(rows),
        isEmpty = rows.isEmpty;

  final DateTime fromDate;
  final DateTime toDate;
  final List<FinancialPaymentMethodSummaryRow> rows;
  final FinancialPaymentMethodSummaryTotals totals;
  final bool isEmpty;
}
