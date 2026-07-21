import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/features/supplier_accounts/supplier_payment_dialog.dart';

void main() {
  group('payment routing policy', () {
    test('maps cash, bank transfer, and wallet to the exact account type', () {
      expect(
        PaymentRoutingPolicy.isCompatible(
          paymentMethod: PaymentMethod.cash,
          accountType: FinancialAccountType.treasury,
        ),
        isTrue,
      );
      expect(
        PaymentRoutingPolicy.isCompatible(
          paymentMethod: PaymentMethod.cash,
          accountType: FinancialAccountType.bank,
        ),
        isFalse,
      );
      expect(
        PaymentRoutingPolicy.isCompatible(
          paymentMethod: PaymentMethod.bankTransfer,
          accountType: FinancialAccountType.bank,
        ),
        isTrue,
      );
      expect(
        PaymentRoutingPolicy.isCompatible(
          paymentMethod: PaymentMethod.mobileWallet,
          accountType: FinancialAccountType.electronicWallet,
        ),
        isTrue,
      );
      expect(
        PaymentRoutingPolicy.isCompatible(
          paymentMethod: PaymentMethod.check,
          accountType: FinancialAccountType.bank,
        ),
        isFalse,
      );
    });
  });

  group('customer collection routing', () {
    late _CollectionFixture fixture;

    setUp(() async {
      fixture = await _CollectionFixture.create();
    });

    test('rejects missing payment method before any mutation', () async {
      final beforeDebt = await fixture.ledger.balanceForCustomer(
        fixture.customer.id,
      );
      final beforeCash = await fixture.accounts.currentBalanceForAccount(
        fixture.treasury.id,
      );

      await expectLater(
        fixture.ledger.createCollection(
          CustomerCollectionDraft(
            customerId: fixture.customer.id,
            date: DateTime(2026, 7, 21),
            amountQirsh: 2000,
            createdByUserId: 'employee-1',
            financialAccountId: fixture.treasury.id,
          ),
        ),
        throwsStateError,
      );

      expect(await fixture.ledger.listCollections(), isEmpty);
      expect(
        await fixture.ledger.balanceForCustomer(fixture.customer.id),
        beforeDebt,
      );
      expect(
        await fixture.accounts.currentBalanceForAccount(fixture.treasury.id),
        beforeCash,
      );
    });

    test('rejects missing account and rejects cash routed to a bank', () async {
      await expectLater(
        fixture.ledger.createCollection(
          CustomerCollectionDraft(
            customerId: fixture.customer.id,
            date: DateTime(2026, 7, 21),
            amountQirsh: 1000,
            createdByUserId: 'employee-1',
            paymentMethod: PaymentMethod.cash,
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        fixture.ledger.createCollection(
          CustomerCollectionDraft(
            customerId: fixture.customer.id,
            date: DateTime(2026, 7, 21),
            amountQirsh: 1000,
            createdByUserId: 'employee-1',
            financialAccountId: fixture.bank.id,
            paymentMethod: PaymentMethod.cash,
          ),
        ),
        throwsStateError,
      );
      expect(await fixture.ledger.listCollections(), isEmpty);
    });

    test('rejects inactive and unknown accounts before any mutation', () async {
      final beforeDebt = await fixture.ledger.balanceForCustomer(
        fixture.customer.id,
      );
      await fixture.accounts.deactivateAccount(
        fixture.treasury.id,
        'owner-1',
      );

      for (final accountId in [fixture.treasury.id, 'missing-account']) {
        await expectLater(
          fixture.ledger.createCollection(
            CustomerCollectionDraft(
              customerId: fixture.customer.id,
              date: DateTime(2026, 7, 21),
              amountQirsh: 1000,
              createdByUserId: 'employee-1',
              financialAccountId: accountId,
              paymentMethod: PaymentMethod.cash,
            ),
          ),
          throwsStateError,
        );
      }

      expect(await fixture.ledger.listCollections(), isEmpty);
      expect(
        await fixture.ledger.balanceForCustomer(fixture.customer.id),
        beforeDebt,
      );
      expect(
        await fixture.accounts.currentBalanceForAccount(fixture.treasury.id),
        0,
      );
    });

    test('cash increases treasury; bank transfer increases bank only',
        () async {
      await fixture.ledger.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: DateTime(2026, 7, 21),
          amountQirsh: 2000,
          createdByUserId: 'employee-1',
          financialAccountId: fixture.treasury.id,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      await fixture.ledger.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: DateTime(2026, 7, 21),
          amountQirsh: 3000,
          createdByUserId: 'employee-1',
          financialAccountId: fixture.bank.id,
          paymentMethod: PaymentMethod.bankTransfer,
        ),
      );

      expect(
        await fixture.accounts.currentBalanceForAccount(fixture.treasury.id),
        2000,
      );
      expect(
        await fixture.accounts.currentBalanceForAccount(fixture.bank.id),
        3000,
      );
      expect(
        await fixture.ledger.balanceForCustomer(fixture.customer.id),
        5000,
      );
    });

    test('mid-operation failure rolls back collection, ledgers, and balance',
        () async {
      final failing = await _CollectionFixture.create(
        audit: _FailingAuditRepository('customer.collection.recorded'),
      );
      await expectLater(
        failing.ledger.createCollection(
          CustomerCollectionDraft(
            customerId: failing.customer.id,
            date: DateTime(2026, 7, 21),
            amountQirsh: 2000,
            createdByUserId: 'employee-1',
            financialAccountId: failing.treasury.id,
            paymentMethod: PaymentMethod.cash,
          ),
        ),
        throwsStateError,
      );

      expect(await failing.ledger.listCollections(), isEmpty);
      expect(
        await failing.ledger.balanceForCustomer(failing.customer.id),
        10000,
      );
      expect(
        await failing.accounts.currentBalanceForAccount(failing.treasury.id),
        0,
      );
    });
  });

  group('supplier payment and expense routing', () {
    late LocalFinancialAccountRepository accounts;
    late FinancialAccount treasury;
    late LocalSupplierRepository suppliers;
    late Supplier supplier;
    late LocalSupplierAccountRepository supplierLedger;

    setUp(() async {
      accounts = LocalFinancialAccountRepository();
      treasury = await accounts.createAccount(
        const FinancialAccountDraft(
          name: 'الخزينة الرئيسية',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner-1',
        ),
      );
      await accounts.setOpeningBalance(
        accountId: treasury.id,
        amountQirsh: 20000,
        effectiveDate: DateTime(2026, 7, 1),
        createdByUserId: 'owner-1',
      );
      suppliers = LocalSupplierRepository();
      supplier = await suppliers.createSupplier(
        const SupplierDraft(name: 'مورد الاختبار'),
      );
      supplierLedger = LocalSupplierAccountRepository(
        supplierRepository: suppliers,
        financialAccountRepository: accounts,
      );
      await supplierLedger.createPurchaseEntry(
        purchase: PurchaseIntake(
          id: 'purchase-1',
          supplierId: supplier.id,
          productId: 'product-1',
          quantityKg: 10,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 1000,
          totalAmountPiasters: 10000,
          createdByUserId: 'owner-1',
          createdAt: DateTime(2026, 7, 20),
          stockMovementId: 'movement-1',
        ),
      );
    });

    test('supplier payment requires method and decreases selected treasury',
        () async {
      await expectLater(
        supplierLedger.createPayment(
          SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime(2026, 7, 21),
            amountQirsh: 1000,
            createdByUserId: 'owner-1',
            financialAccountId: treasury.id,
          ),
        ),
        throwsStateError,
      );
      expect(await supplierLedger.listPayments(), isEmpty);

      await supplierLedger.createPayment(
        SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 7, 21),
          amountQirsh: 4000,
          createdByUserId: 'owner-1',
          financialAccountId: treasury.id,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      expect(await accounts.currentBalanceForAccount(treasury.id), 16000);
      expect(await supplierLedger.balanceForSupplier(supplier.id), 6000);
    });

    test('cash expense decreases treasury and missing account is rejected',
        () async {
      final expenses = LocalExpenseRepository(
        financialAccountRepository: accounts,
      );
      await expectLater(
        expenses.createExpense(
          ExpenseDraft(
            date: DateTime(2026, 7, 21),
            category: 'نقل',
            amountQirsh: 1000,
            paymentMethod: PaymentMethod.cash,
          ),
        ),
        throwsStateError,
      );
      expect(await expenses.listExpenses(), isEmpty);

      await expenses.createExpense(
        ExpenseDraft(
          date: DateTime(2026, 7, 21),
          category: 'نقل',
          amountQirsh: 2500,
          financialAccountId: treasury.id,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      expect(await accounts.currentBalanceForAccount(treasury.id), 17500);
    });
  });

  testWidgets(
      'supplier payment UI requires route, filters accounts, and clears an incompatible selection',
      (tester) async {
    final treasury = _account(
      id: 'cash-1',
      name: 'الخزينة',
      type: FinancialAccountType.treasury,
    );
    final bank = _account(
      id: 'bank-1',
      name: 'البنك',
      type: FinancialAccountType.bank,
    );
    SupplierPaymentResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<SupplierPaymentResult>(
                  context: context,
                  builder: (_) => SupplierPaymentDialog(
                    supplier: Supplier(
                      id: 'supplier-1',
                      name: 'المورد',
                      isActive: true,
                      createdAt: DateTime(2026),
                      updatedAt: DateTime(2026),
                    ),
                    balanceQirsh: 10000,
                    userId: 'owner-1',
                    financialAccounts: [treasury, bank],
                  ),
                );
              },
              child: const Text('فتح'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(find.text('طريقة الدفع *'), findsOneWidget);
    expect(find.text('الحساب المالي *'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '50');

    final paymentMethodField =
        find.byType(DropdownButtonFormField<PaymentMethod>);
    final accountField = find.byType(DropdownButtonFormField<String>);
    await tester.tap(paymentMethodField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('نقدي').last);
    await tester.pumpAndSettle();
    await tester.tap(accountField);
    await tester.pumpAndSettle();
    expect(find.textContaining('الخزينة'), findsWidgets);
    expect(find.textContaining('البنك'), findsNothing);
    await tester.tap(find.textContaining('الخزينة').last);
    await tester.pumpAndSettle();

    await tester.tap(paymentMethodField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تحويل بنكي').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الدفع'));
    await tester.pump();
    expect(find.text('اختر الحساب المالي للسداد.'), findsOneWidget);

    await tester.tap(accountField);
    await tester.pumpAndSettle();
    expect(find.textContaining('البنك'), findsWidgets);
    expect(find.textContaining('الخزينة'), findsNothing);
    await tester.tap(find.textContaining('البنك').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الدفع'));
    await tester.pumpAndSettle();

    expect(result?.financialAccountId, bank.id);
    expect(result?.paymentMethod, PaymentMethod.bankTransfer);
  });
}

class _CollectionFixture {
  _CollectionFixture({
    required this.accounts,
    required this.ledger,
    required this.customer,
    required this.treasury,
    required this.bank,
  });

  final LocalFinancialAccountRepository accounts;
  final LocalCustomerAccountRepository ledger;
  final Customer customer;
  final FinancialAccount treasury;
  final FinancialAccount bank;

  static Future<_CollectionFixture> create({AuditLogRepository? audit}) async {
    final customers = LocalCustomerRepository();
    final customer = await customers.createCustomer(
      const CustomerDraft(name: 'عميل الاختبار', isActive: true),
    );
    final accounts = LocalFinancialAccountRepository();
    final treasury = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'الخزينة',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner-1',
      ),
    );
    final bank = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'البنك',
        type: FinancialAccountType.bank,
        createdByUserId: 'owner-1',
      ),
    );
    final ledger = LocalCustomerAccountRepository(
      customerRepository: customers,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
    );
    await ledger.createCreditSaleEntry(
      sale: SaleRecord(
        id: 'sale-credit-1',
        productId: 'product-1',
        quantityKg: 10,
        salePriceQirshPerKg: 1000,
        totalQirsh: 10000,
        createdByUserId: 'owner-1',
        createdAt: DateTime(2026, 7, 20),
        stockMovementId: 'movement-1',
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      ),
      customerId: customer.id,
    );
    return _CollectionFixture(
      accounts: accounts,
      ledger: ledger,
      customer: customer,
      treasury: treasury,
      bank: bank,
    );
  }
}

class _FailingAuditRepository extends LocalAuditLogRepository {
  _FailingAuditRepository(this.actionType);

  final String actionType;

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) {
    if (draft.actionType == actionType) {
      throw StateError('injected audit failure');
    }
    return super.record(draft);
  }
}

FinancialAccount _account({
  required String id,
  required String name,
  required FinancialAccountType type,
}) {
  return FinancialAccount(
    id: id,
    name: name,
    type: type,
    createdByUserId: 'owner-1',
    createdAt: DateTime(2026),
  );
}
