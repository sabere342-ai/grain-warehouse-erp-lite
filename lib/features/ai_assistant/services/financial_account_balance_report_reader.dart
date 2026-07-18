import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';

/// Read-only boundary for the existing Financial Account Balance Report.
abstract interface class FinancialAccountBalanceReportReader {
  Future<AccountBalanceReport> loadAccountBalanceReport();
}

final class FinancialReportServiceAccountBalanceReader
    implements FinancialAccountBalanceReportReader {
  const FinancialReportServiceAccountBalanceReader({
    required FinancialReportService service,
  }) : _service = service;

  final FinancialReportService _service;

  @override
  Future<AccountBalanceReport> loadAccountBalanceReport() =>
      _service.accountBalanceReport(includeInactive: true);
}
