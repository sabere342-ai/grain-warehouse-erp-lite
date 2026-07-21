import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collections_by_financial_account_report.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collections_by_financial_account_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';

void main() {
  late _Fixture fixture;

  setUp(() => fixture = _Fixture());

  Future<CustomerCollectionsByFinancialAccountReport> report({
    required String accountId,
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
  }) =>
      fixture.service.customerCollectionsByFinancialAccountReport(
        financialAccountId: accountId,
        startDate: startDate ?? DateTime(2026, 4, 1),
        endDate: endDate ?? DateTime(2026, 4, 30),
        customerId: customerId,
      );

  group('CustomerCollectionsByFinancialAccountReportService', () {
    test('requires a non-blank financial account id', () async {
      await expectLater(
        report(accountId: ' '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an end date before the inclusive start date', () async {
      final account = await fixture.createAccount(
        type: FinancialAccountType.bank,
      );
      await expectLater(
        report(
          accountId: account.id,
          startDate: DateTime(2026, 4, 2),
          endDate: DateTime(2026, 4, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a nonexistent account before producing a report', () async {
      await expectLater(
        report(accountId: 'missing-account'),
        throwsA(isA<StateError>()),
      );
    });

    test('includes an inactive existing account as a valid target', () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      final collection = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
      );
      await fixture.accounts.deactivateAccount(account.id, _owner.id);

      final value = await report(accountId: account.id);

      expect(value.financialAccount.id, account.id);
      expect(value.financialAccount.isActive, isFalse);
      expect(value.rows.map((row) => row.collectionId), [collection.id]);
    });

    test('returns an immutable empty report for an account without matches',
        () async {
      final account = await fixture.createAccount();

      final value = await report(accountId: account.id);

      expect(value.rows, isEmpty);
      expect(value.rowCount, 0);
      expect(value.totalAmountQirsh, 0);
      expect(value.startDate, DateTime(2026, 4, 1));
      expect(value.endDate, DateTime(2026, 4, 30));
    });

    test('includes both inclusive period boundaries using local business dates',
        () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      final first = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 1, 23, 59),
        amountQirsh: 100,
      );
      final last = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 30, 1),
        amountQirsh: 200,
      );

      final value = await report(accountId: account.id);

      expect(value.rows.map((row) => row.collectionId), [first.id, last.id]);
      expect(value.rows.first.collectionDate, DateTime(2026, 4, 1));
      expect(value.rows.last.collectionDate, DateTime(2026, 4, 30));
      expect(value.totalAmountQirsh, 300);
    });

    test('excludes collections outside the requested period', () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 3, 31),
      );
      final included = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 15),
      );
      await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 5, 1),
      );

      final value = await report(accountId: account.id);

      expect(value.rows.map((row) => row.collectionId), [included.id]);
    });

    test('excludes collections credited to another financial account',
        () async {
      final selected = await fixture.createAccount(name: 'Treasury');
      final other = await fixture.createAccount(name: 'Bank');
      final customer = await fixture.createCustomer();
      final included = await fixture.record(
        customer: customer,
        account: selected,
        date: DateTime(2026, 4, 10),
      );
      await fixture.record(
        customer: customer,
        account: other,
        date: DateTime(2026, 4, 10),
      );

      final value = await report(accountId: selected.id);

      expect(value.rows.map((row) => row.collectionId), [included.id]);
      expect(value.rows.single.financialAccountId, selected.id);
    });

    test(
        'does not assign a null historical account link to the selected account',
        () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      await fixture.recordWithoutFinancialAccount(
        customer: customer,
        date: DateTime(2026, 4, 10),
      );

      final value = await report(accountId: account.id);

      expect(value.rows, isEmpty);
      expect(value.totalAmountQirsh, 0);
    });

    test('applies the optional customer filter and records it in the summary',
        () async {
      final account = await fixture.createAccount();
      final selectedCustomer = await fixture.createCustomer(name: 'Selected');
      final otherCustomer = await fixture.createCustomer(name: 'Other');
      final included = await fixture.record(
        customer: selectedCustomer,
        account: account,
        date: DateTime(2026, 4, 10),
      );
      await fixture.record(
        customer: otherCustomer,
        account: account,
        date: DateTime(2026, 4, 10),
      );

      final value = await report(
        accountId: account.id,
        customerId: selectedCustomer.id,
      );

      expect(value.customerIdFilter, selectedCustomer.id);
      expect(value.rows.map((row) => row.collectionId), [included.id]);
    });

    test('rejects a nonexistent optional customer before producing a report',
        () async {
      final account = await fixture.createAccount();

      await expectLater(
        report(accountId: account.id, customerId: 'missing-customer'),
        throwsA(isA<StateError>()),
      );
    });

    test('includes an inactive customer and exposes only approved identity',
        () async {
      final account = await fixture.createAccount(
        type: FinancialAccountType.bank,
      );
      final customer = await fixture.createCustomer(name: 'Inactive customer');
      final collection = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
        paymentMethod: PaymentMethod.bankTransfer,
      );
      await fixture.customers.setCustomerActive(
        customerId: customer.id,
        isActive: false,
      );

      final row = (await report(accountId: account.id)).rows.single;

      expect(row.collectionId, collection.id);
      expect(row.customerId, customer.id);
      expect(row.customerName, customer.name);
      expect(row.isCustomerActive, isFalse);
      expect(row.paymentMethod, PaymentMethod.bankTransfer);
    });

    test('preserves a null recorded payment method', () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      await fixture.recordHistorical(
        customer: customer,
        date: DateTime(2026, 4, 10),
        financialAccountId: account.id,
      );

      final value = await report(accountId: account.id);

      expect(value.rows.single.paymentMethod, isNull);
    });

    test('orders rows by collection date then stable collection id', () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      final later = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 11),
      );
      final sameDayFirst = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
      );
      final sameDaySecond = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
      );

      final value = await report(accountId: account.id);
      final sameDayIds = [sameDayFirst.id, sameDaySecond.id]..sort();

      expect(value.rows.map((row) => row.collectionId), [
        ...sameDayIds,
        later.id,
      ]);
    });

    test('reports the canonical row count and total amount', () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
        amountQirsh: 125,
      );
      await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 11),
        amountQirsh: 275,
      );

      final value = await report(accountId: account.id);

      expect(value.rowCount, 2);
      expect(value.totalAmountQirsh, 400);
    });

    test('excludes cancelled collections under the canonical validity rule',
        () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      final cancelled = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
      );
      final valid = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 11),
      );
      await fixture.customerAccounts.cancelCollection(
        user: _owner,
        collectionId: cancelled.id,
        reason: 'Duplicate receipt',
        operationRequestId: 'cancel-${cancelled.id}',
      );

      final value = await report(accountId: account.id);

      expect(value.rows.map((row) => row.collectionId), [valid.id]);
    });

    test('exposes rows through an unmodifiable collection', () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
      );
      final value = await report(accountId: account.id);

      expect(
        () => value.rows.add(value.rows.single),
        throwsUnsupportedError,
      );
      expect(() => value.rows.removeAt(0), throwsUnsupportedError);
      expect(() => value.rows[0] = value.rows[0], throwsUnsupportedError);
    });

    test('performs no repository writes or source-model mutation', () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      final collection = await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
        amountQirsh: 500,
      );
      final beforeCollections =
          await fixture.customerAccounts.listCollections();
      final beforeAccountBalance =
          await fixture.accounts.currentBalanceForAccount(account.id);
      final beforeCustomerBalance =
          await fixture.customerAccounts.balanceForCustomer(customer.id);

      final value = await report(accountId: account.id);

      expect(value.rows.single.collectionId, collection.id);
      expect(
          await fixture.customerAccounts.listCollections(), beforeCollections);
      expect(await fixture.accounts.currentBalanceForAccount(account.id),
          beforeAccountBalance);
      expect(await fixture.customerAccounts.balanceForCustomer(customer.id),
          beforeCustomerBalance);
      expect(
          (await fixture.customerAccounts.listCollections()).single.isCancelled,
          isFalse);
    });

    test('returns equivalent snapshots on repeated reads', () async {
      final account = await fixture.createAccount();
      final customer = await fixture.createCustomer();
      await fixture.record(
        customer: customer,
        account: account,
        date: DateTime(2026, 4, 10),
        amountQirsh: 500,
      );

      final first = await report(accountId: account.id);
      final second = await report(accountId: account.id);

      expect(second.financialAccount.id, first.financialAccount.id);
      expect(second.startDate, first.startDate);
      expect(second.endDate, first.endDate);
      expect(second.totalAmountQirsh, first.totalAmountQirsh);
      expect(second.rows.map((row) => row.collectionId),
          first.rows.map((row) => row.collectionId));
    });
  });
}

final _owner = AppUser(
  id: 'owner',
  name: 'Owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final class _Fixture {
  _Fixture()
      : customers = LocalCustomerRepository(),
        accounts = LocalFinancialAccountRepository() {
    customerAccounts = LocalCustomerAccountRepository(
      customerRepository: customers,
      financialAccountRepository: accounts,
    );
    service = CustomerCollectionsByFinancialAccountReportService(
      customerAccountRepository: customerAccounts,
      customerRepository: customers,
      financialAccountRepository: accounts,
    );
  }

  final LocalCustomerRepository customers;
  final LocalFinancialAccountRepository accounts;
  late LocalCustomerAccountRepository customerAccounts;
  late CustomerCollectionsByFinancialAccountReportService service;
  final Set<String> _openedCustomers = <String>{};

  Future<Customer> createCustomer({
    String name = 'Customer',
  }) =>
      customers.createCustomer(CustomerDraft(name: name));

  Future<FinancialAccount> createAccount({
    String name = 'Account',
    FinancialAccountType type = FinancialAccountType.treasury,
  }) =>
      accounts.createAccount(FinancialAccountDraft(
        name: name,
        type: type,
        createdByUserId: _owner.id,
      ));

  Future<CustomerCollectionRecord> record({
    required Customer customer,
    required FinancialAccount account,
    required DateTime date,
    int amountQirsh = 100,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  }) async {
    if (_openedCustomers.add(customer.id)) {
      await customerAccounts.createOpeningBalanceEntry(
        customerId: customer.id,
        amountQirsh: 100000,
        createdByUserId: _owner.id,
      );
    }
    return customerAccounts.createCollection(CustomerCollectionDraft(
      customerId: customer.id,
      date: date,
      amountQirsh: amountQirsh,
      createdByUserId: _owner.id,
      financialAccountId: account.id,
      paymentMethod: paymentMethod,
    ));
  }

  Future<CustomerCollectionRecord> recordWithoutFinancialAccount({
    required Customer customer,
    required DateTime date,
    int amountQirsh = 100,
  }) async {
    return recordHistorical(
      customer: customer,
      date: date,
      amountQirsh: amountQirsh,
    );
  }

  Future<CustomerCollectionRecord> recordHistorical({
    required Customer customer,
    required DateTime date,
    int amountQirsh = 100,
    String? financialAccountId,
    PaymentMethod? paymentMethod,
  }) async {
    final record = CustomerCollectionRecord(
      id: 'historical-${date.microsecondsSinceEpoch}',
      customerId: customer.id,
      date: date,
      amountQirsh: amountQirsh,
      createdAt: date,
      createdByUserId: _owner.id,
      financialAccountId: financialAccountId,
      paymentMethod: paymentMethod,
    );
    await customerAccounts.restoreCustomerAccountsIntoEmpty(
      entries: const [],
      collections: [record],
    );
    return record;
  }
}
