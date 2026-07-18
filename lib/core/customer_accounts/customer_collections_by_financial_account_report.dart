import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

/// Read-only identity for the selected financial account.
final class CustomerCollectionsByFinancialAccountReportAccount {
  const CustomerCollectionsByFinancialAccountReportAccount({
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

/// One valid customer collection credited to the selected financial account.
final class CustomerCollectionsByFinancialAccountReportRow {
  const CustomerCollectionsByFinancialAccountReportRow({
    required this.collectionId,
    required this.collectionDate,
    required this.customerId,
    required this.customerName,
    required this.isCustomerActive,
    required this.financialAccountId,
    required this.paymentMethod,
    required this.amountQirsh,
  });

  final String collectionId;
  final DateTime collectionDate;
  final String customerId;
  final String customerName;
  final bool isCustomerActive;
  final String financialAccountId;
  final PaymentMethod? paymentMethod;
  final int amountQirsh;
}

/// Immutable snapshot of valid customer collections for one account and period.
final class CustomerCollectionsByFinancialAccountReport {
  CustomerCollectionsByFinancialAccountReport({
    required this.financialAccount,
    required this.startDate,
    required this.endDate,
    required this.customerIdFilter,
    required Iterable<CustomerCollectionsByFinancialAccountReportRow> rows,
    required this.totalAmountQirsh,
  }) : rows = List<CustomerCollectionsByFinancialAccountReportRow>.unmodifiable(
          rows,
        );

  final CustomerCollectionsByFinancialAccountReportAccount financialAccount;
  final DateTime startDate;
  final DateTime endDate;
  final String? customerIdFilter;
  final List<CustomerCollectionsByFinancialAccountReportRow> rows;
  final int totalAmountQirsh;

  int get rowCount => rows.length;
}
