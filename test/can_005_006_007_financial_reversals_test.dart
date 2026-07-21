import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  group('CAN-005/006/007 atomic financial reversals', () {
    test('customer collection reversal preserves history and restores ledgers',
        () async {
      final fixture = await _CustomerFixture.create();
      final collection = await fixture.ledger.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: DateTime(2026, 7, 13),
          amountQirsh: 300,
          createdByUserId: _owner.id,
          financialAccountId: fixture.account.id,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final cancellation = await fixture.ledger.cancelCollection(
        user: _owner,
        collectionId: collection.id,
        reason: 'Duplicate receipt',
        operationRequestId: 'cancel-collection-1',
      );

      final stored = (await fixture.ledger.listCollections()).single;
      expect(stored.isCancelled, isTrue);
      expect(stored.cancellation!.id, cancellation.id);
      expect(stored.cancellation!.originalCollectionId, collection.id);
      expect(
          await fixture.ledger.balanceForCustomer(fixture.customer.id), 1000);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          1000);
      final entries = await fixture.ledger.listEntries();
      expect(
        entries.where((entry) =>
            entry.type == CustomerAccountEntryType.collectionCancellation),
        hasLength(1),
      );
      final statement = await fixture.accounts.statementForAccount(
        fixture.account.id,
      );
      final reversal = statement.lines.last.entry;
      expect(reversal.reversalOf, isNotNull);
      expect(reversal.sourceDocumentId, cancellation.id);
    });

    test('supplier payment reversal preserves history and restores ledgers',
        () async {
      final fixture = await _SupplierFixture.create();
      final payment = await fixture.ledger.createPayment(
        SupplierPaymentDraft(
          supplierId: fixture.supplier.id,
          date: DateTime(2026, 7, 13),
          amountQirsh: 300,
          createdByUserId: _owner.id,
          financialAccountId: fixture.account.id,
          paymentMethod: PaymentMethod.cash,
          operationRequestId: 'payment-1',
        ),
      );

      final cancellation = await fixture.ledger.cancelPayment(
        user: _owner,
        paymentId: payment.id,
        reason: 'Duplicate settlement',
        operationRequestId: 'cancel-payment-1',
      );

      final stored = (await fixture.ledger.listPayments()).single;
      expect(stored.isCancelled, isTrue);
      expect(stored.cancellation!.id, cancellation.id);
      expect(
          await fixture.ledger.balanceForSupplier(fixture.supplier.id), 1000);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          1000);
      expect(
        (await fixture.ledger.listEntries()).where((entry) =>
            entry.type == SupplierAccountEntryType.paymentCancellation),
        hasLength(1),
      );
    });

    test('rejects employee, replay, and concurrent duplicate cancellation',
        () async {
      final fixture = await _CustomerFixture.create();
      final collection = await fixture.ledger.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: DateTime(2026, 7, 13),
          amountQirsh: 300,
          createdByUserId: _owner.id,
          financialAccountId: fixture.account.id,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      await expectLater(
        fixture.ledger.cancelCollection(
          user: _employee,
          collectionId: collection.id,
          reason: 'Not allowed',
          operationRequestId: 'employee-request',
        ),
        throwsA(isA<StateError>()),
      );

      Future<Object> guarded(Future<Object> future) async {
        try {
          return await future;
        } catch (error) {
          return error;
        }
      }

      final results = await Future.wait([
        guarded(fixture.ledger.cancelCollection(
          user: _owner,
          collectionId: collection.id,
          reason: 'Duplicate',
          operationRequestId: 'concurrent-collection-cancel',
        )),
        guarded(fixture.ledger.cancelCollection(
          user: _owner,
          collectionId: collection.id,
          reason: 'Duplicate',
          operationRequestId: 'concurrent-collection-cancel',
        )),
      ]);
      expect(results.whereType<CustomerCollectionCancellation>(), hasLength(1));
      expect(results.whereType<StateError>(), hasLength(1));
      expect(
        (await fixture.ledger.listEntries()).where((entry) =>
            entry.type == CustomerAccountEntryType.collectionCancellation),
        hasLength(1),
      );
    });

    test('audit failure rolls back every collection reversal participant',
        () async {
      final fixture = await _CustomerFixture.create(
        audit: _FailOnActionAudit('customer.collection.reversed'),
      );
      final collection = await fixture.ledger.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: DateTime(2026, 7, 13),
          amountQirsh: 300,
          createdByUserId: _owner.id,
          financialAccountId: fixture.account.id,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      await expectLater(
        fixture.ledger.cancelCollection(
          user: _owner,
          collectionId: collection.id,
          reason: 'Injected failure',
          operationRequestId: 'failing-cancel',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
          (await fixture.ledger.listCollections()).single.isCancelled, isFalse);
      expect(await fixture.ledger.balanceForCustomer(fixture.customer.id), 700);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          1300);
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

final _employee = _owner.copyWith(id: 'employee', role: UserRole.employee);

class _CustomerFixture {
  _CustomerFixture._({
    required this.customer,
    required this.ledger,
    required this.accounts,
    required this.account,
  });

  final Customer customer;
  final LocalCustomerAccountRepository ledger;
  final LocalFinancialAccountRepository accounts;
  final FinancialAccount account;

  static Future<_CustomerFixture> create({AuditLogRepository? audit}) async {
    final auditRepository = audit ?? LocalAuditLogRepository();
    final customers =
        LocalCustomerRepository(auditLogRepository: auditRepository);
    final customer = await customers.createCustomer(
      const CustomerDraft(name: 'Customer A'),
    );
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: auditRepository,
    );
    final account = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Customer cash',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner',
      ),
    );
    await accounts.setOpeningBalance(
      accountId: account.id,
      amountQirsh: 1000,
      effectiveDate: DateTime(2026, 1, 1),
      createdByUserId: 'owner',
    );
    final ledger = LocalCustomerAccountRepository(
      customerRepository: customers,
      auditLogRepository: auditRepository,
      financialAccountRepository: accounts,
    );
    await ledger.createOpeningBalanceEntry(
      customerId: customer.id,
      amountQirsh: 1000,
      createdByUserId: 'owner',
    );
    return _CustomerFixture._(
      customer: customer,
      ledger: ledger,
      accounts: accounts,
      account: account,
    );
  }
}

class _SupplierFixture {
  _SupplierFixture._({
    required this.supplier,
    required this.ledger,
    required this.accounts,
    required this.account,
  });

  final Supplier supplier;
  final LocalSupplierAccountRepository ledger;
  final LocalFinancialAccountRepository accounts;
  final FinancialAccount account;

  static Future<_SupplierFixture> create() async {
    final audit = LocalAuditLogRepository();
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Supplier A'),
    );
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit);
    final account = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Supplier cash',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner',
      ),
    );
    await accounts.setOpeningBalance(
      accountId: account.id,
      amountQirsh: 1000,
      effectiveDate: DateTime(2026, 1, 1),
      createdByUserId: 'owner',
    );
    final ledger = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
    );
    await ledger.createOpeningBalanceEntry(
      supplierId: supplier.id,
      amountQirsh: 1000,
      createdByUserId: 'owner',
    );
    return _SupplierFixture._(
      supplier: supplier,
      ledger: ledger,
      accounts: accounts,
      account: account,
    );
  }
}

class _FailOnActionAudit extends LocalAuditLogRepository {
  _FailOnActionAudit(this.action);

  final String action;

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) {
    if (draft.actionType == action) throw StateError('Injected audit failure.');
    return super.record(draft);
  }
}
