import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

/// Read-only identity for the selected financial account.
final class SupplierPaymentsByFinancialAccountReportAccount {
  const SupplierPaymentsByFinancialAccountReportAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  final String id;
  final String name;
  final FinancialAccountType type;
  final bool isActive;
}

/// One supplier-payment report entry attributed to the selected account.
///
/// A future allocation-aware payment can legitimately contribute multiple rows;
/// callers must not treat [paymentId] as globally unique within a report.
final class SupplierPaymentsByFinancialAccountReportRow {
  const SupplierPaymentsByFinancialAccountReportRow({
    required this.paymentId,
    required this.paymentDate,
    required this.supplierId,
    required this.supplierName,
    required this.isSupplierActive,
    required this.financialAccountId,
    required this.paymentMethod,
    required this.amountQirsh,
  });

  final String paymentId;
  final DateTime paymentDate;
  final String supplierId;
  final String supplierName;
  final bool isSupplierActive;
  final String financialAccountId;
  final PaymentMethod? paymentMethod;
  final int amountQirsh;
}

/// Immutable snapshot of valid supplier payments for one account and period.
final class SupplierPaymentsByFinancialAccountReport {
  SupplierPaymentsByFinancialAccountReport({
    required this.financialAccount,
    required this.startDate,
    required this.endDate,
    required this.supplierIdFilter,
    required Iterable<SupplierPaymentsByFinancialAccountReportRow> rows,
    required this.totalAmountQirsh,
  }) : rows = List<SupplierPaymentsByFinancialAccountReportRow>.unmodifiable(
          rows,
        );

  final SupplierPaymentsByFinancialAccountReportAccount financialAccount;
  final DateTime startDate;
  final DateTime endDate;
  final String? supplierIdFilter;
  final List<SupplierPaymentsByFinancialAccountReportRow> rows;
  final int totalAmountQirsh;

  int get rowCount => rows.length;
}
