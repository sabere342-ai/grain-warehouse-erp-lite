import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collections_by_financial_account_report.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';

/// Canonical read boundary for customer collections credited to one account.
final class CustomerCollectionsByFinancialAccountReportService {
  const CustomerCollectionsByFinancialAccountReportService({
    required CustomerAccountRepository customerAccountRepository,
    required CustomerRepository customerRepository,
    required FinancialAccountRepository financialAccountRepository,
  })  : _customerAccountRepository = customerAccountRepository,
        _customerRepository = customerRepository,
        _financialAccountRepository = financialAccountRepository;

  final CustomerAccountRepository _customerAccountRepository;
  final CustomerRepository _customerRepository;
  final FinancialAccountRepository _financialAccountRepository;

  Future<CustomerCollectionsByFinancialAccountReport>
      customerCollectionsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? customerId,
  }) async {
    final accountId = _requiredId(financialAccountId, 'financialAccountId');
    final customerIdFilter = _optionalId(customerId, 'customerId');
    final periodStart = _businessDate(startDate);
    final periodEnd = _businessDate(endDate);
    if (periodEnd.isBefore(periodStart)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'endDate must not be earlier than startDate.',
      );
    }

    // This validates existence, including an inactive account, before the
    // collection scan begins.
    final account = await _financialAccountRepository.accountById(accountId);
    final customers = await _customerRepository.listCustomers(
      includeInactive: true,
    );
    final customersById = <String, Customer>{
      for (final customer in customers) customer.id: customer,
    };
    if (customerIdFilter != null &&
        !customersById.containsKey(customerIdFilter)) {
      throw StateError('Customer was not found.');
    }

    final rows = <CustomerCollectionsByFinancialAccountReportRow>[];
    for (final collection
        in await _customerAccountRepository.listCollections()) {
      if (collection.isCancelled ||
          collection.financialAccountId != accountId ||
          !_isInInclusivePeriod(collection.date, periodStart, periodEnd) ||
          (customerIdFilter != null &&
              collection.customerId != customerIdFilter)) {
        continue;
      }

      final customer = customersById[collection.customerId];
      if (customer == null) {
        throw StateError(
            'Customer collection references an unavailable customer.');
      }
      rows.add(CustomerCollectionsByFinancialAccountReportRow(
        collectionId: collection.id,
        collectionDate: _businessDate(collection.date),
        customerId: customer.id,
        customerName: customer.name,
        isCustomerActive: customer.isActive,
        financialAccountId: accountId,
        paymentMethod: collection.paymentMethod,
        amountQirsh: collection.amountQirsh,
      ));
    }

    rows.sort((left, right) {
      final byDate = left.collectionDate.compareTo(right.collectionDate);
      if (byDate != 0) return byDate;
      return left.collectionId.compareTo(right.collectionId);
    });

    var totalAmountQirsh = 0;
    for (final row in rows) {
      totalAmountQirsh += row.amountQirsh;
    }

    return CustomerCollectionsByFinancialAccountReport(
      financialAccount: _reportAccount(account),
      startDate: periodStart,
      endDate: periodEnd,
      customerIdFilter: customerIdFilter,
      rows: rows,
      totalAmountQirsh: totalAmountQirsh,
    );
  }

  CustomerCollectionsByFinancialAccountReportAccount _reportAccount(
    FinancialAccount account,
  ) =>
      CustomerCollectionsByFinancialAccountReportAccount(
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
