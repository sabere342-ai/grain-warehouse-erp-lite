import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payments_by_financial_account_report.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

/// Canonical read boundary for supplier payments attributed to one account.
final class SupplierPaymentsByFinancialAccountReportService {
  const SupplierPaymentsByFinancialAccountReportService({
    required SupplierAccountRepository supplierAccountRepository,
    required SupplierRepository supplierRepository,
    required FinancialAccountRepository financialAccountRepository,
  })  : _supplierAccountRepository = supplierAccountRepository,
        _supplierRepository = supplierRepository,
        _financialAccountRepository = financialAccountRepository;

  final SupplierAccountRepository _supplierAccountRepository;
  final SupplierRepository _supplierRepository;
  final FinancialAccountRepository _financialAccountRepository;

  Future<SupplierPaymentsByFinancialAccountReport>
      supplierPaymentsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? supplierId,
  }) async {
    final accountId = _requiredId(financialAccountId, 'financialAccountId');
    final supplierIdFilter = _optionalId(supplierId, 'supplierId');
    final periodStart = _businessDate(startDate);
    final periodEnd = _businessDate(endDate);
    if (periodEnd.isBefore(periodStart)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'endDate must not be earlier than startDate.',
      );
    }

    final account = await _financialAccountRepository.accountById(accountId);
    final suppliers = await _supplierRepository.listSuppliers(
      includeInactive: true,
    );
    final suppliersById = <String, Supplier>{
      for (final supplier in suppliers) supplier.id: supplier,
    };
    if (supplierIdFilter != null &&
        !suppliersById.containsKey(supplierIdFilter)) {
      throw StateError('Supplier was not found.');
    }

    final rows = <SupplierPaymentsByFinancialAccountReportRow>[];
    for (final payment in await _supplierAccountRepository.listPayments()) {
      if (payment.isCancelled ||
          payment.financialAccountId != accountId ||
          !_isInInclusivePeriod(payment.date, periodStart, periodEnd) ||
          (supplierIdFilter != null &&
              payment.supplierId != supplierIdFilter)) {
        continue;
      }

      final supplier = suppliersById[payment.supplierId];
      if (supplier == null) {
        throw StateError(
            'Supplier payment references an unavailable supplier.');
      }
      rows.add(SupplierPaymentsByFinancialAccountReportRow(
        paymentId: payment.id,
        paymentDate: _businessDate(payment.date),
        supplierId: supplier.id,
        supplierName: supplier.name,
        isSupplierActive: supplier.isActive,
        financialAccountId: accountId,
        paymentMethod: payment.paymentMethod,
        amountQirsh: payment.amountQirsh,
      ));
    }

    var totalAmountQirsh = 0;
    for (final row in rows) {
      totalAmountQirsh += row.amountQirsh;
    }

    return SupplierPaymentsByFinancialAccountReport(
      financialAccount: _reportAccount(account),
      startDate: periodStart,
      endDate: periodEnd,
      supplierIdFilter: supplierIdFilter,
      rows: rows,
      totalAmountQirsh: totalAmountQirsh,
    );
  }

  SupplierPaymentsByFinancialAccountReportAccount _reportAccount(
    FinancialAccount account,
  ) =>
      SupplierPaymentsByFinancialAccountReportAccount(
        id: account.id,
        name: account.name,
        type: account.type,
        isActive: account.isActive,
      );

  bool _isInInclusivePeriod(
    DateTime value,
    DateTime startDate,
    DateTime endDate,
  ) {
    final date = _businessDate(value);
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }

  DateTime _businessDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _requiredId(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, '$name is required.');
    }
    return normalized;
  }

  String? _optionalId(String? value, String name) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, '$name must not be blank.');
    }
    return normalized;
  }
}
