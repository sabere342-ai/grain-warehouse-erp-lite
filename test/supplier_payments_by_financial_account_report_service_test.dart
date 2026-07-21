import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payments_by_financial_account_report.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payments_by_financial_account_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  late _Fixture fixture;

  setUp(() => fixture = _Fixture());

  Future<SupplierPaymentsByFinancialAccountReport> report({
    required String accountId,
    DateTime? startDate,
    DateTime? endDate,
    String? supplierId,
  }) =>
      fixture.service.supplierPaymentsByFinancialAccountReport(
        financialAccountId: accountId,
        startDate: startDate ?? DateTime(2026, 4, 1),
        endDate: endDate ?? DateTime(2026, 4, 30),
        supplierId: supplierId,
      );

  group('SupplierPaymentsByFinancialAccountReportService', () {
    test('requires a non-blank account id and a valid inclusive interval',
        () async {
      await expectLater(report(accountId: ' '), throwsA(isA<ArgumentError>()));
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

    test('rejects unknown account and supplier identifiers', () async {
      await expectLater(
        report(accountId: 'missing-account'),
        throwsA(isA<StateError>()),
      );
      final account = await fixture.createAccount(
        type: FinancialAccountType.bank,
      );
      await expectLater(
        report(accountId: account.id, supplierId: 'missing-supplier'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        report(accountId: account.id, supplierId: ' '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns selected account identity and an immutable empty report',
        () async {
      final account = await fixture.createAccount();

      final value = await report(accountId: account.id);

      expect(value.financialAccount.id, account.id);
      expect(value.financialAccount.name, account.name);
      expect(value.rows, isEmpty);
      expect(value.rowCount, 0);
      expect(value.totalAmountQirsh, 0);
      expect(value.startDate, DateTime(2026, 4, 1));
      expect(value.endDate, DateTime(2026, 4, 30));
      expect(() => value.rows.add(_row()), throwsUnsupportedError);
    });

    test('includes both inclusive local business-date boundaries', () async {
      final account = await fixture.createAccount();
      final supplier = await fixture.createSupplier();
      final first = await fixture.record(
        supplier: supplier,
        account: account,
        date: DateTime(2026, 4, 1, 23, 59),
        amountQirsh: 100,
      );
      final last = await fixture.record(
        supplier: supplier,
        account: account,
        date: DateTime(2026, 4, 30, 1),
        amountQirsh: 200,
      );

      final value = await report(accountId: account.id);

      expect(value.rows.map((row) => row.paymentId), [first.id, last.id]);
      expect(value.rows.first.paymentDate, DateTime(2026, 4, 1));
      expect(value.rows.last.paymentDate, DateTime(2026, 4, 30));
      expect(value.totalAmountQirsh, 300);
    });

    test('excludes periods, other accounts, null links, and cancelled payments',
        () async {
      final selected = await fixture.createAccount(name: 'Treasury');
      final other = await fixture.createAccount(name: 'Bank');
      final supplier = await fixture.createSupplier();
      await fixture.recordWithoutFinancialAccount(
        supplier: supplier,
        date: DateTime(2026, 4, 10),
      );
      await fixture.record(
        supplier: supplier,
        account: selected,
        date: DateTime(2026, 3, 31),
      );
      final included = await fixture.record(
        supplier: supplier,
        account: selected,
        date: DateTime(2026, 4, 10),
        amountQirsh: 125,
      );
      await fixture.record(
        supplier: supplier,
        account: other,
        date: DateTime(2026, 4, 10),
      );
      final cancelled = await fixture.record(
        supplier: supplier,
        account: selected,
        date: DateTime(2026, 4, 11),
      );
      await fixture.supplierAccounts.cancelPayment(
        user: _owner,
        paymentId: cancelled.id,
        reason: 'Duplicate payment',
        operationRequestId: 'cancel-${cancelled.id}',
      );

      final value = await report(accountId: selected.id);

      expect(value.rows.map((row) => row.paymentId), [included.id]);
      expect(value.rows.single.financialAccountId, selected.id);
      expect(value.totalAmountQirsh, 125);
    });

    test('applies optional supplier filter and preserves inactive suppliers',
        () async {
      final account = await fixture.createAccount(
        type: FinancialAccountType.bank,
      );
      final selected = await fixture.createSupplier(name: 'Selected');
      final other = await fixture.createSupplier(name: 'Other');
      final payment = await fixture.record(
        supplier: selected,
        account: account,
        date: DateTime(2026, 4, 10),
        paymentMethod: PaymentMethod.bankTransfer,
      );
      await fixture.record(
        supplier: other,
        account: account,
        date: DateTime(2026, 4, 10),
        paymentMethod: PaymentMethod.bankTransfer,
      );
      await fixture.suppliers.setSupplierActive(
        supplierId: selected.id,
        isActive: false,
      );

      final value =
          await report(accountId: account.id, supplierId: selected.id);

      expect(value.supplierIdFilter, selected.id);
      expect(value.rows.map((row) => row.paymentId), [payment.id]);
      expect(value.rows.single.supplierName, selected.name);
      expect(value.rows.single.isSupplierActive, isFalse);
      expect(value.rows.single.paymentMethod, PaymentMethod.bankTransfer);
    });

    test('preserves a null payment method and inactive account identity',
        () async {
      final account = await fixture.createAccount();
      final supplier = await fixture.createSupplier();
      await fixture.recordHistorical(
        supplier: supplier,
        date: DateTime(2026, 4, 10),
        financialAccountId: account.id,
      );
      await fixture.accounts.deactivateAccount(account.id, _owner.id);

      final value = await report(accountId: account.id);

      expect(value.financialAccount.isActive, isFalse);
      expect(value.rows.single.paymentMethod, isNull);
    });

    test('preserves canonical payment repository ordering without sorting',
        () async {
      final account = await fixture.createAccount();
      final supplier = await fixture.createSupplier();
      final first = await fixture.record(
        supplier: supplier,
        account: account,
        date: DateTime(2026, 4, 20),
      );
      final second = await fixture.record(
        supplier: supplier,
        account: account,
        date: DateTime(2026, 4, 1),
      );

      final value = await report(accountId: account.id);

      expect(value.rows.map((row) => row.paymentId), [first.id, second.id]);
    });

    test(
        'uses exact qirsh totals and does not require globally unique payment ids',
        () async {
      final duplicateRows = [
        _row(paymentId: 'shared'),
        _row(paymentId: 'shared')
      ];
      final direct = SupplierPaymentsByFinancialAccountReport(
        financialAccount: _account(),
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        supplierIdFilter: null,
        rows: duplicateRows,
        totalAmountQirsh: 250,
      );
      expect(direct.rows, hasLength(2));
      expect(direct.rows.map((row) => row.paymentId), ['shared', 'shared']);

      final account = await fixture.createAccount();
      final supplier = await fixture.createSupplier();
      await fixture.record(
        supplier: supplier,
        account: account,
        date: DateTime(2026, 4, 10),
        amountQirsh: 125,
      );
      await fixture.record(
        supplier: supplier,
        account: account,
        date: DateTime(2026, 4, 11),
        amountQirsh: 275,
      );

      final value = await report(accountId: account.id);
      expect(value.rowCount, 2);
      expect(value.totalAmountQirsh, 400);
      expect(value.totalAmountQirsh, isA<int>());
    });

    test('does not mutate payments, balances, or report source state',
        () async {
      final account = await fixture.createAccount();
      final supplier = await fixture.createSupplier();
      await fixture.record(
        supplier: supplier,
        account: account,
        date: DateTime(2026, 4, 10),
        amountQirsh: 500,
      );
      final paymentsBefore = await fixture.supplierAccounts.listPayments();
      final balanceBefore =
          await fixture.supplierAccounts.balanceForSupplier(supplier.id);

      final value = await report(accountId: account.id);

      expect(value.rows.single.amountQirsh, 500);
      expect(await fixture.supplierAccounts.listPayments(), paymentsBefore);
      expect(await fixture.supplierAccounts.balanceForSupplier(supplier.id),
          balanceBefore);
    });

    test('report contract contains no private supplier or persistence fields',
        () async {
      final row = _row();
      expect(row.supplierId, 'supplier-1');
      expect(row.supplierName, 'Supplier');
      expect(row.amountQirsh, 125);
      expect(row.paymentMethod, isNull);
      final source = await File(
        'lib/core/supplier_accounts/supplier_payments_by_financial_account_report.dart',
      ).readAsString();
      for (final prohibited in [
        'phone',
        'address',
        'notes',
        'balance',
        'password',
        'repository',
        'Map<',
      ]) {
        expect(source.toLowerCase(), isNot(contains(prohibited)));
      }
    });
  });
}

final _owner = AppUser(
  id: 'owner',
  name: 'Owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

SupplierPaymentsByFinancialAccountReportRow _row(
        {String paymentId = 'payment-1'}) =>
    SupplierPaymentsByFinancialAccountReportRow(
      paymentId: paymentId,
      paymentDate: DateTime(2026, 4, 10),
      supplierId: 'supplier-1',
      supplierName: 'Supplier',
      isSupplierActive: true,
      financialAccountId: 'account-1',
      paymentMethod: null,
      amountQirsh: 125,
    );

SupplierPaymentsByFinancialAccountReportAccount _account() =>
    const SupplierPaymentsByFinancialAccountReportAccount(
      id: 'account-1',
      name: 'Account',
      type: FinancialAccountType.treasury,
      isActive: true,
    );

final class _Fixture {
  _Fixture()
      : suppliers = LocalSupplierRepository(),
        accounts = LocalFinancialAccountRepository() {
    supplierAccounts = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      financialAccountRepository: accounts,
    );
    service = SupplierPaymentsByFinancialAccountReportService(
      supplierAccountRepository: supplierAccounts,
      supplierRepository: suppliers,
      financialAccountRepository: accounts,
    );
  }

  final LocalSupplierRepository suppliers;
  final LocalFinancialAccountRepository accounts;
  late LocalSupplierAccountRepository supplierAccounts;
  late SupplierPaymentsByFinancialAccountReportService service;
  final Set<String> _openedSuppliers = <String>{};

  Future<Supplier> createSupplier({String name = 'Supplier'}) =>
      suppliers.createSupplier(SupplierDraft(name: name));

  Future<FinancialAccount> createAccount({
    String name = 'Account',
    FinancialAccountType type = FinancialAccountType.treasury,
  }) async {
    final account = await accounts.createAccount(FinancialAccountDraft(
      name: name,
      type: type,
      createdByUserId: _owner.id,
    ));
    await accounts.setOpeningBalance(
      accountId: account.id,
      amountQirsh: 1000000,
      effectiveDate: DateTime(2026, 1, 1),
      createdByUserId: _owner.id,
    );
    return account;
  }

  Future<SupplierPaymentRecord> record({
    required Supplier supplier,
    required FinancialAccount account,
    required DateTime date,
    int amountQirsh = 100,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  }) async {
    if (_openedSuppliers.add(supplier.id)) {
      await supplierAccounts.createOpeningBalanceEntry(
        supplierId: supplier.id,
        amountQirsh: 100000,
        createdByUserId: _owner.id,
      );
    }
    return supplierAccounts.createPayment(SupplierPaymentDraft(
      supplierId: supplier.id,
      date: date,
      amountQirsh: amountQirsh,
      createdByUserId: _owner.id,
      financialAccountId: account.id,
      paymentMethod: paymentMethod,
    ));
  }

  Future<SupplierPaymentRecord> recordWithoutFinancialAccount({
    required Supplier supplier,
    required DateTime date,
  }) async {
    return recordHistorical(supplier: supplier, date: date);
  }

  Future<SupplierPaymentRecord> recordHistorical({
    required Supplier supplier,
    required DateTime date,
    String? financialAccountId,
    PaymentMethod? paymentMethod,
  }) async {
    final record = SupplierPaymentRecord(
      id: 'historical-${date.microsecondsSinceEpoch}',
      supplierId: supplier.id,
      date: date,
      amountQirsh: 100,
      createdAt: date,
      createdByUserId: _owner.id,
      financialAccountId: financialAccountId,
      paymentMethod: paymentMethod,
    );
    await supplierAccounts.restoreSupplierAccountsIntoEmpty(
      entries: const [],
      payments: [record],
    );
    return record;
  }
}
