import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 35 customer credit UI backing flows', () {
    test('credit mode requires an active customer before posting', () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      await fixture.saleController.load(_owner);

      final created = await fixture.saleController.createSale(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 5000,
        paymentMode: SalePaymentMode.credit,
      );

      expect(created, isFalse);
      expect(fixture.saleController.errorMessage, isNotNull);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 100);
      expect(await fixture.ledger.listEntries(), isEmpty);
      expect(await fixture.sales.listSales(), isEmpty);
    });

    test('cash sale requires registered customer', () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      await fixture.saleController.load(_owner);

      final created = await fixture.saleController.createSale(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 5000,
        paymentMode: SalePaymentMode.cash,
      );

      expect(created, isFalse);
      expect(fixture.saleController.errorMessage, isNotNull);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 100);
      expect(await fixture.ledger.listEntries(), isEmpty);
      expect(await fixture.sales.listSales(), isEmpty);
    });

    test('customer controller displays balance derived from ledger entries',
        () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      final customer = await fixture.createCustomer();
      await fixture.postCreditSale(customer.id);

      await fixture.customerController.loadCustomers(_owner);

      expect(fixture.customerController.customers.single.id, customer.id);
      expect(fixture.customerController.balanceForCustomer(customer.id), 50000);
      expect(
          fixture.customerController.balancesByCustomerId[customer.id], 50000);
    });

    test('collection action reduces derived balance without mutating inventory',
        () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      final customer = await fixture.createCustomer();
      await fixture.postCreditSale(customer.id);
      await fixture.customerController.loadCustomers(_owner);

      final saved = await fixture.customerController.recordCollection(
        user: _owner,
        customerId: customer.id,
        date: DateTime.now(),
        amountQirsh: 20000,
        notes: 'pilot collection',
      );

      expect(saved, isTrue);
      expect(fixture.customerController.balanceForCustomer(customer.id), 30000);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 90);
      expect(
          (await fixture.ledger.listCollections()).single.amountQirsh, 20000);
    });

    test('collection cannot exceed the current customer balance', () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      final customer = await fixture.createCustomer();
      await fixture.postCreditSale(customer.id);
      await fixture.customerController.loadCustomers(_owner);

      final saved = await fixture.customerController.recordCollection(
        user: _owner,
        customerId: customer.id,
        date: DateTime.now(),
        amountQirsh: 50001,
      );

      expect(saved, isFalse);
      expect(fixture.customerController.errorMessage, isNotNull);
      expect(fixture.customerController.balanceForCustomer(customer.id), 50000);
      expect(await fixture.ledger.listCollections(), isEmpty);
    });

    test('statement exposes debit, credit, source ids, and running balance',
        () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      final customer = await fixture.createCustomer();
      await fixture.postCreditSale(customer.id);
      await fixture.customerController.loadCustomers(_owner);
      await fixture.customerController.recordCollection(
        user: _owner,
        customerId: customer.id,
        date: DateTime.now(),
        amountQirsh: 12500,
      );

      final statement = await fixture.customerController.statementForCustomer(
        customer.id,
      );

      expect(statement.lines, hasLength(2));
      expect(statement.lines.first.entry.debitAmountQirsh, 50000);
      expect(statement.lines.first.entry.creditAmountQirsh, 0);
      expect(statement.lines.first.entry.sourceDocumentId, isNotEmpty);
      expect(statement.lines.first.entry.descriptionAr, isNotEmpty);
      expect(statement.lines.first.runningBalanceQirsh, 50000);
      expect(statement.lines.last.entry.debitAmountQirsh, 0);
      expect(statement.lines.last.entry.creditAmountQirsh, 12500);
      expect(statement.lines.last.entry.sourceDocumentId, isNotEmpty);
      expect(statement.lines.last.runningBalanceQirsh, 37500);
      expect(statement.finalBalanceQirsh, 37500);
    });

    test('reports separate credit sales, collections, and receivables totals',
        () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      final customer = await fixture.createCustomer();
      await fixture.postCreditSale(customer.id);
      await fixture.customerController.loadCustomers(_owner);
      await fixture.customerController.recordCollection(
        user: _owner,
        customerId: customer.id,
        date: DateTime.now(),
        amountQirsh: 10000,
      );
      final repository = LocalReportRepository(
        purchaseRepository: const _EmptyPurchaseRepository(),
        saleRepository: fixture.sales,
        inventoryRepository: fixture.inventory,
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(fixture.products),
        customerAccountRepository: fixture.ledger,
      );

      final report = await repository.dailyActivityReport(
        selectedDate: DateTime.now(),
      );

      expect(report.totalSalesAmountQirsh, 50000);
      expect(report.totalCreditSalesAmountQirsh, 50000);
      expect(report.totalCollectionsAmountQirsh, 10000);
      expect(report.totalOutstandingReceivablesQirsh, 40000);
      expect(report.estimatedGrossProfitQirsh, isNot(10000));
    });

    test('customer and report UI source keeps balances derived and visible',
        () {
      final customersSource = File(
        'lib/features/customers/customers_screen.dart',
      ).readAsStringSync();
      final reportsSource = File(
        'lib/features/reports/reports_screen.dart',
      ).readAsStringSync();

      expect(customersSource, contains('balanceForCustomer'));
      expect(customersSource, contains('كشف الحساب'));
      expect(customersSource, contains('تسجيل تحصيل'));
      expect(customersSource, isNot(contains('balanceController')));
      expect(customersSource, isNot(contains('رصيد يدوي')));
      expect(reportsSource, contains('إجمالي البيع الآجل'));
      expect(reportsSource, contains('إجمالي التحصيلات من العملاء'));
      expect(reportsSource, contains('إجمالي أرصدة العملاء المستحقة'));
      expect(reportsSource, contains('لا تُحسب كمبيعات أو ربح جديد'));
    });
  });
}

class _Fixture {
  _Fixture()
      : customers = LocalCustomerRepository(
          auditLogRepository: LocalAuditLogRepository(),
        ),
        audit = LocalAuditLogRepository() {
    inventory = LocalInventoryRepository(productRepository: products);
    sales = LocalSaleRepository(
      productRepository: products,
      inventoryRepository: inventory,
    );
    ledger = LocalCustomerAccountRepository(
      customerRepository: customers,
      auditLogRepository: audit,
    );
    saleController = SaleController(
      saleRepository: sales,
      productRepository: products,
      inventoryRepository: inventory,
      customerRepository: customers,
      customerAccountRepository: ledger,
    );
    customerController = CustomerController(
      repository: customers,
      accountRepository: ledger,
    );
  }

  final LocalProductRepository products = LocalProductRepository();
  late final LocalInventoryRepository inventory;
  final LocalCustomerRepository customers;
  final LocalAuditLogRepository audit;
  late final LocalSaleRepository sales;
  late final LocalCustomerAccountRepository ledger;
  late final SaleController saleController;
  late final CustomerController customerController;
  late Product product;

  Future<void> seedProduct() async {
    product = await products.createProduct(
      const ProductDraft(
        name: 'قمح تجريبي',
        unit: GrainUnit.kilogram,
        defaultSalePricePiastersPerKg: 5000,
        minimumSalePricePiastersPerKg: 4500,
        referenceCostPricePiastersPerKg: 3500,
      ),
    );
    await inventory.createMovement(
      StockMovementDraft(
        productId: product.id,
        movementType: StockMovementType.openingBalance,
        quantityKg: 100,
        createdByUserId: _owner.id,
      ),
    );
  }

  Future<Customer> createCustomer() {
    return customers.createCustomer(
      const CustomerDraft(name: 'عميل تجريبي', phone: '01000000001'),
    );
  }

  Future<void> postCreditSale(String customerId) async {
    await saleController.load(_owner);
    final created = await saleController.createSale(
      user: _owner,
      productId: product.id,
      quantityKg: 10,
      salePriceQirshPerKg: 5000,
      paymentMode: SalePaymentMode.credit,
      customerId: customerId,
    );
    expect(created, isTrue);
  }
}

class _EmptyPurchaseRepository implements PurchaseRepository {
  const _EmptyPurchaseRepository();

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    throw UnsupportedError('Phase 35 report test fake is read-only.');
  }

  @override
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft) {
    throw UnsupportedError('Phase 35 report test fake is read-only.');
  }

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    return const [];
  }
}

final _now = DateTime(2026, 7, 8);

final _owner = AppUser(
  id: 'owner-phase35',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
