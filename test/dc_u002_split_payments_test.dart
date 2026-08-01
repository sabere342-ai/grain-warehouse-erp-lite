import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('DC-U002 atomic split payments', () {
    late _Fixture fixture;

    setUp(() async {
      fixture = await _Fixture.create();
    });

    test('posts one allocation as one financial movement', () async {
      final created = await fixture.createSale(
        allocations: [
          SalePaymentAllocation(
            financialAccountId: fixture.accountA.id,
            amountQirsh: 1000,
            paymentMethod: PaymentMethod.cash,
          ),
        ],
      );

      expect(created, isTrue);
      final sale = fixture.controller.sales.single;
      expect(sale.paymentAllocations, hasLength(1));
      expect(sale.effectivePaidAmountQirsh, 1000);
      expect(await fixture.balance(fixture.accountA.id), 1000);
    });

    test('posts two and three allocations without rounding loss', () async {
      final first = await fixture.createSale(
        allocations: [
          SalePaymentAllocation(
            financialAccountId: fixture.accountA.id,
            amountQirsh: 333,
            paymentMethod: PaymentMethod.cash,
          ),
          SalePaymentAllocation(
            financialAccountId: fixture.accountB.id,
            amountQirsh: 667,
            paymentMethod: PaymentMethod.bankTransfer,
          ),
        ],
      );
      expect(first, isTrue);

      final third = await fixture.createSale(
        allocations: [
          SalePaymentAllocation(
            financialAccountId: fixture.accountA.id,
            amountQirsh: 200,
            paymentMethod: PaymentMethod.cash,
          ),
          SalePaymentAllocation(
            financialAccountId: fixture.accountB.id,
            amountQirsh: 300,
            paymentMethod: PaymentMethod.bankTransfer,
          ),
          SalePaymentAllocation(
            financialAccountId: fixture.accountC.id,
            amountQirsh: 500,
            paymentMethod: PaymentMethod.mobileWallet,
          ),
        ],
      );
      expect(third, isTrue);

      expect(await fixture.balance(fixture.accountA.id), 533);
      expect(await fixture.balance(fixture.accountB.id), 967);
      expect(await fixture.balance(fixture.accountC.id), 500);
      final sales = fixture.controller.sales;
      expect(sales, hasLength(2));
      expect(
          sales.first.paymentAllocations
              .map((a) => a.amountQirsh)
              .reduce((a, b) => a + b),
          1000);
    });

    test(
        'rejects invalid allocation totals, zero values, duplicates, and inactive accounts',
        () async {
      await fixture.accounts.deactivateAccount(
        fixture.accountC.id,
        _owner.id,
      );
      for (final allocations in [
        <SalePaymentAllocation>[
          SalePaymentAllocation(
            financialAccountId: fixture.accountA.id,
            amountQirsh: 999,
            paymentMethod: PaymentMethod.cash,
          ),
        ],
        <SalePaymentAllocation>[
          SalePaymentAllocation(
            financialAccountId: fixture.accountA.id,
            amountQirsh: 0,
            paymentMethod: PaymentMethod.cash,
          ),
          SalePaymentAllocation(
            financialAccountId: fixture.accountB.id,
            amountQirsh: 1000,
            paymentMethod: PaymentMethod.bankTransfer,
          ),
        ],
        <SalePaymentAllocation>[
          SalePaymentAllocation(
            financialAccountId: fixture.accountA.id,
            amountQirsh: 500,
            paymentMethod: PaymentMethod.cash,
          ),
          SalePaymentAllocation(
            financialAccountId: fixture.accountA.id,
            amountQirsh: 500,
            paymentMethod: PaymentMethod.bankTransfer,
          ),
        ],
        <SalePaymentAllocation>[
          SalePaymentAllocation(
            financialAccountId: fixture.accountC.id,
            amountQirsh: 1000,
            paymentMethod: PaymentMethod.cash,
          ),
        ],
      ]) {
        expect(await fixture.createSale(allocations: allocations), isFalse);
      }

      expect(fixture.controller.sales, isEmpty);
      expect(await fixture.inventory.listAllMovements(), hasLength(1));
      expect(await fixture.ledger.listEntries(), isEmpty);
      expect(await fixture.balance(fixture.accountA.id), 0);
      expect(await fixture.balance(fixture.accountB.id), 0);
    });

    test('rejects replay and concurrent requests with the same operation id',
        () async {
      final results = await Future.wait([
        fixture.createSale(
          operationRequestId: 'split-sale-request-1',
          allocations: fixture.twoWay(400, 600),
        ),
        fixture.createSale(
          operationRequestId: 'split-sale-request-1',
          allocations: fixture.twoWay(400, 600),
        ),
      ]);

      expect(results.where((result) => result), hasLength(1));
      expect(fixture.controller.sales, hasLength(1));
      expect(await fixture.balance(fixture.accountA.id), 400);
      expect(await fixture.balance(fixture.accountB.id), 600);
    });

    test(
        'rolls back document, stock, customer ledger, and first allocation when a later allocation fails',
        () async {
      await fixture.accounts.deactivateAccount(fixture.accountB.id, _owner.id);

      final created = await fixture.createSale(
        allocations: fixture.twoWay(500, 500),
      );

      expect(created, isFalse);
      expect(fixture.controller.sales, isEmpty);
      expect(await fixture.inventory.listAllMovements(), hasLength(1));
      expect(await fixture.ledger.listEntries(), isEmpty);
      expect(await fixture.balance(fixture.accountA.id), 0);
      expect(await fixture.balance(fixture.accountB.id), 0);
    });

    test(
        'reverses every split allocation atomically and links each reversal to its original movement',
        () async {
      expect(await fixture.createSale(allocations: fixture.twoWay(450, 550)),
          isTrue);
      final sale = fixture.controller.sales.single;

      expect(
        await fixture.controller.cancelSale(
          user: _owner,
          saleId: sale.id,
          cancellationReason: 'اختبار عكس الدفع المقسم',
        ),
        isTrue,
      );

      for (final accountId in [fixture.accountA.id, fixture.accountB.id]) {
        final lines =
            (await fixture.accounts.statementForAccount(accountId)).lines;
        expect(lines, hasLength(2));
        final original = lines
            .singleWhere(
              (line) =>
                  line.entry.sourceType ==
                  FinancialAccountEntrySource.salePayment,
            )
            .entry;
        final reversal = lines
            .singleWhere(
              (line) =>
                  line.entry.sourceType ==
                  FinancialAccountEntrySource.cancellationReversal,
            )
            .entry;
        expect(reversal.reversalOf, original.id);
        expect(await fixture.balance(accountId), 0);
      }
    });

    test('rolls back a split reversal when one account cannot be reversed',
        () async {
      expect(await fixture.createSale(allocations: fixture.twoWay(450, 550)),
          isTrue);
      final sale = fixture.controller.sales.single;
      await fixture.accounts.deactivateAccount(fixture.accountB.id, _owner.id);

      expect(
        await fixture.controller.cancelSale(
          user: _owner,
          saleId: sale.id,
          cancellationReason: 'فشل مقصود',
        ),
        isFalse,
      );

      expect(fixture.controller.sales.single.isCancelled, isFalse);
      expect(await fixture.inventory.listAllMovements(), hasLength(2));
      expect(
        (await fixture.accounts.statementForAccount(fixture.accountA.id)).lines,
        hasLength(1),
      );
      expect(
        (await fixture.accounts.statementForAccount(fixture.accountB.id)).lines,
        hasLength(1),
      );
    });
  });
}

final _owner = AppUser(
  id: 'owner-1',
  name: 'المالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _Fixture {
  _Fixture._();

  late final LocalProductRepository products;
  late final LocalInventoryRepository inventory;
  late final LocalCustomerRepository customers;
  late final LocalAuditLogRepository audit;
  late final LocalFinancialAccountRepository accounts;
  late final LocalCustomerAccountRepository ledger;
  late final LocalSaleRepository sales;
  late final SaleController controller;
  late final Product product;
  late final Customer customer;
  late final FinancialAccount accountA;
  late final FinancialAccount accountB;
  late final FinancialAccount accountC;
  var _requestCounter = 0;

  static Future<_Fixture> create() async {
    final fixture = _Fixture._();
    fixture.products = LocalProductRepository();
    fixture.inventory = LocalInventoryRepository(
      productRepository: fixture.products,
    );
    fixture.audit = LocalAuditLogRepository();
    fixture.customers = LocalCustomerRepository(
      auditLogRepository: fixture.audit,
    );
    fixture.accounts = LocalFinancialAccountRepository(
      auditLogRepository: fixture.audit,
    );
    fixture.ledger = LocalCustomerAccountRepository(
      customerRepository: fixture.customers,
      auditLogRepository: fixture.audit,
      financialAccountRepository: fixture.accounts,
    );
    fixture.sales = LocalSaleRepository(
      productRepository: fixture.products,
      inventoryRepository: fixture.inventory,
    );
    fixture.controller = SaleController(
      saleRepository: fixture.sales,
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(fixture.products),
      inventoryRepository: fixture.inventory,
      customerRepository: fixture.customers,
      customerAccountRepository: fixture.ledger,
      financialAccountRepository: fixture.accounts,
    );
    fixture.product = await fixture.products.createProduct(
      const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
    );
    fixture.customer = await fixture.customers.createCustomer(
      const CustomerDraft(name: 'عميل اختبار'),
    );
    await fixture.inventory.createMovement(
      StockMovementDraft(
        productId: fixture.product.id,
        movementType: StockMovementType.openingBalance,
        quantityKg: 100,
        createdByUserId: _owner.id,
      ),
    );
    fixture.accountA = await fixture._account(
      'خزينة',
      FinancialAccountType.treasury,
    );
    fixture.accountB = await fixture._account(
      'بنك',
      FinancialAccountType.bank,
    );
    fixture.accountC = await fixture._account(
      'محفظة',
      FinancialAccountType.electronicWallet,
    );
    await fixture.controller.load(_owner);
    return fixture;
  }

  Future<FinancialAccount> _account(
    String name,
    FinancialAccountType type,
  ) =>
      accounts.createAccount(
        FinancialAccountDraft(
          name: name,
          type: type,
          createdByUserId: _owner.id,
        ),
      );

  List<SalePaymentAllocation> twoWay(int first, int second) => [
        SalePaymentAllocation(
          financialAccountId: accountA.id,
          amountQirsh: first,
          paymentMethod: PaymentMethod.cash,
        ),
        SalePaymentAllocation(
          financialAccountId: accountB.id,
          amountQirsh: second,
          paymentMethod: PaymentMethod.bankTransfer,
        ),
      ];

  Future<bool> createSale({
    required List<SalePaymentAllocation> allocations,
    String? operationRequestId,
  }) =>
      controller.createSale(
        user: _owner,
        productId: product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 100,
        customerId: customer.id,
        paymentMode: SalePaymentMode.cash,
        paymentAllocations: allocations,
        operationRequestId:
            operationRequestId ?? 'split-request-${++_requestCounter}',
      );

  Future<int> balance(String accountId) =>
      accounts.currentBalanceForAccount(accountId);
}
