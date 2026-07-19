import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payments_by_financial_account_report.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payments_by_financial_account_report_service.dart';

/// Read-only boundary for the canonical supplier-payments account report.
abstract interface class SupplierPaymentsByFinancialAccountReportReader {
  Future<SupplierPaymentsByFinancialAccountReport>
      loadSupplierPaymentsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? supplierId,
  });
}

final class SupplierPaymentsByFinancialAccountReportServiceReader
    implements SupplierPaymentsByFinancialAccountReportReader {
  const SupplierPaymentsByFinancialAccountReportServiceReader({
    required SupplierPaymentsByFinancialAccountReportService service,
  }) : _service = service;

  final SupplierPaymentsByFinancialAccountReportService _service;

  @override
  Future<SupplierPaymentsByFinancialAccountReport>
      loadSupplierPaymentsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? supplierId,
  }) =>
          _service.supplierPaymentsByFinancialAccountReport(
            financialAccountId: financialAccountId,
            startDate: startDate,
            endDate: endDate,
            supplierId: supplierId,
          );
}
