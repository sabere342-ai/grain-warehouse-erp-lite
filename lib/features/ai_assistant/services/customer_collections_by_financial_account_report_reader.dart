import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collections_by_financial_account_report.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collections_by_financial_account_report_service.dart';

/// Read-only boundary for the canonical customer-collections account report.
abstract interface class CustomerCollectionsByFinancialAccountReportReader {
  Future<CustomerCollectionsByFinancialAccountReport>
      loadCustomerCollectionsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? customerId,
  });
}

final class CustomerCollectionsByFinancialAccountReportServiceReader
    implements CustomerCollectionsByFinancialAccountReportReader {
  const CustomerCollectionsByFinancialAccountReportServiceReader({
    required CustomerCollectionsByFinancialAccountReportService service,
  }) : _service = service;

  final CustomerCollectionsByFinancialAccountReportService _service;

  @override
  Future<CustomerCollectionsByFinancialAccountReport>
      loadCustomerCollectionsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? customerId,
  }) =>
          _service.customerCollectionsByFinancialAccountReport(
            financialAccountId: financialAccountId,
            startDate: startDate,
            endDate: endDate,
            customerId: customerId,
          );
}
