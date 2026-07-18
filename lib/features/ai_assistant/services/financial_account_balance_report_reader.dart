import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';

/// Read-only boundary for the existing Financial Account Balance Report.
abstract interface class FinancialAccountBalanceReportReader {
  Future<AccountBalanceReport> loadAccountBalanceReport();
}

/// Read-only boundary for the existing Financial Account Statement Report.
abstract interface class FinancialAccountStatementReportReader {
  Future<AccountStatementReport> loadAccountStatementReport({
    required String financialAccountId,
  });
}

/// Read-only boundary for the existing payment-method financial report.
abstract interface class FinancialPaymentMethodReportReader {
  Future<PaymentMethodReport> loadPaymentMethodReport();
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

final class FinancialReportServiceAccountStatementReader
    implements FinancialAccountStatementReportReader {
  const FinancialReportServiceAccountStatementReader({
    required FinancialReportService service,
  }) : _service = service;

  final FinancialReportService _service;

  @override
  Future<AccountStatementReport> loadAccountStatementReport({
    required String financialAccountId,
  }) =>
      _service.accountStatementReport(accountId: financialAccountId);
}

final class FinancialReportServicePaymentMethodReader
    implements FinancialPaymentMethodReportReader {
  const FinancialReportServicePaymentMethodReader({
    required FinancialReportService service,
  }) : _service = service;

  final FinancialReportService _service;

  @override
  Future<PaymentMethodReport> loadPaymentMethodReport() =>
      _service.paymentMethodReport();
}
