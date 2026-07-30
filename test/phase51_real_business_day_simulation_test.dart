import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/stock_adjustment_report_screen.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 51 real business day simulation', () {
    test('local stock, accounts, reports, and documents stay consistent',
        () async {
      final fixture = await _BusinessDayFixture.create();
      final today = DateTime.now();

      final wheatPurchase = await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(
          productId: fixture.wheat.id,
          quantityKg: 500,
          unitPriceQirshPerKg: 1500,
        ),
      );
      final cornPurchase = await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(
          productId: fixture.corn.id,
          quantityKg: 300,
          unitPriceQirshPerKg: 1200,
        ),
      );

      expect(wheatPurchase.totalAmountPiasters, 750000);
      expect(cornPurchase.totalAmountPiasters, 360000);
      expect(await fixture.inventory.currentStockKg(fixture.wheat.id), 500);
      expect(await fixture.inventory.currentStockKg(fixture.corn.id), 300);
      expect(
          await fixture.supplierAccounts.balanceForSupplier(
            fixture.supplier.id,
          ),
          1110000);

      final creditSale = await fixture.sales.createSale(
        fixture.saleDraft(
          productId: fixture.wheat.id,
          quantityKg: 200,
          priceQirshPerKg: 2200,
          paymentMode: SalePaymentMode.credit,
        ),
      );
      await fixture.customerAccounts.createCreditSaleEntry(
        sale: creditSale,
        customerId: fixture.customer.id,
      );

      final cashSale = await fixture.sales.createSale(
        fixture.saleDraft(
          productId: fixture.corn.id,
          quantityKg: 100,
          priceQirshPerKg: 1800,
          paymentMode: SalePaymentMode.cash,
        ),
      );
      await fixture.customerAccounts.createCashSaleEntry(
        sale: cashSale,
        customerId: fixture.customer.id,
      );

      expect(await fixture.inventory.currentStockKg(fixture.wheat.id), 300);
      expect(await fixture.inventory.currentStockKg(fixture.corn.id), 200);
      expect(
          await fixture.customerAccounts.balanceForCustomer(
            fixture.customer.id,
          ),
          440000);

      final collection = await fixture.customerAccounts.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: today,
          amountQirsh: 200000,
          createdByUserId: _owner.id,
          notes: 'Phase 51 synthetic customer collection',
        ),
      );
      final supplierPayment = await fixture.supplierAccounts.createPayment(
        SupplierPaymentDraft(
          supplierId: fixture.supplier.id,
          date: today,
          amountQirsh: 300000,
          createdByUserId: _owner.id,
          notes: 'Phase 51 synthetic supplier payment',
        ),
      );
      final expense = await fixture.expenses.createExpense(
        ExpenseDraft(
          accountingClassification: ExpenseAccountingClassification.operating,
          date: today,
          category: 'Phase 51 synthetic operating expense',
          amountQirsh: 25000,
          createdByUserId: _owner.id,
          operationRequestId: 'phase51-expense',
        ),
      );

      expect(collection.amountQirsh, 200000);
      expect(supplierPayment.amountQirsh, 300000);
      expect(expense.amountQirsh, 25000);
      expect(
          await fixture.customerAccounts.balanceForCustomer(
            fixture.customer.id,
          ),
          240000);
      expect(
          await fixture.supplierAccounts.balanceForSupplier(
            fixture.supplier.id,
          ),
          810000);

      final inventoryController = InventoryController(
        inventoryRepository: fixture.inventory,
        productRepository: fixture.products,
      );
      await inventoryController.load(_owner);
      final adjusted = await inventoryController.createManualIncrease(
        user: _owner,
        productId: fixture.rice.id,
        quantityKg: 50,
        note: _stockTakeNote,
      );

      expect(adjusted, isTrue);
      expect(await fixture.inventory.currentStockKg(fixture.rice.id), 50);
      expect(
          await fixture.customerAccounts.balanceForCustomer(
            fixture.customer.id,
          ),
          240000);
      expect(
          await fixture.supplierAccounts.balanceForSupplier(
            fixture.supplier.id,
          ),
          810000);

      final movements = await fixture.inventory.listAllMovements();
      expect(
        movements.map((movement) => movement.movementType),
        containsAll([
          StockMovementType.purchaseIntake,
          StockMovementType.sale,
          StockMovementType.manualIncrease,
        ]),
      );
      expect(_movementBalance(movements, fixture.wheat.id), 300);
      expect(_movementBalance(movements, fixture.corn.id), 200);
      expect(_movementBalance(movements, fixture.rice.id), 50);

      final unrelatedMovementCount = movements
          .where((movement) =>
              movement.note == 'Phase 51 synthetic supplier payment' ||
              movement.note == 'Phase 51 synthetic customer collection')
          .length;
      expect(unrelatedMovementCount, 0);

      final report = await fixture.reports.dailyActivityReport(
        selectedDate: today,
      );
      expect(report.totalPurchasedKg, 800);
      expect(report.totalPurchaseAmountQirsh, 1110000);
      expect(report.totalSoldKg, 300);
      expect(report.totalSalesAmountQirsh, 620000);
      expect(report.totalCreditSalesAmountQirsh, 440000);
      expect(report.totalCollectionsAmountQirsh, 200000);
      expect(report.totalOutstandingReceivablesQirsh, 240000);
      expect(report.totalSupplierPaymentsQirsh, 300000);
      expect(report.totalOutstandingSupplierPayablesQirsh, 810000);
      expect(report.totalExpenseAmountQirsh, 25000);
      expect(report.purchaseCount, 2);
      expect(report.saleCount, 2);

      final stockByProduct = {
        for (final balance in report.stockBalances)
          balance.productId: balance.quantityKg,
      };
      expect(stockByProduct[fixture.wheat.id], 300);
      expect(stockByProduct[fixture.corn.id], 200);
      expect(stockByProduct[fixture.rice.id], 50);

      final history = await fixture.documents.listHistory();
      expect(history.map((entry) => entry.id), contains(wheatPurchase.id));
      expect(history.map((entry) => entry.id), contains(cornPurchase.id));
      expect(history.map((entry) => entry.id), contains(creditSale.id));
      expect(history.map((entry) => entry.id), contains(cashSale.id));
      expect(
        history.where((entry) => entry.status == DocumentHistoryStatus.active),
        hasLength(4),
      );

      final customerStatement = await fixture.customerAccounts
          .statementForCustomer(fixture.customer.id);
      expect(customerStatement.finalBalanceQirsh, 240000);
      expect(customerStatement.lines.map((line) => line.runningBalanceQirsh),
          [440000, 440000, 240000]);

      final supplierStatement = await fixture.supplierAccounts
          .statementForSupplier(fixture.supplier.id);
      expect(supplierStatement.finalBalanceQirsh, 810000);
      expect(supplierStatement.lines.map((line) => line.runningBalanceQirsh),
          [750000, 1110000, 810000]);
    });

    testWidgets('stock adjustment report remains read-only', (tester) async {
      final fixture = await _BusinessDayFixture.create();
      final controller = InventoryController(
        inventoryRepository: fixture.inventory,
        productRepository: fixture.products,
      );
      await controller.load(_owner);
      await controller.createManualIncrease(
        user: _owner,
        productId: fixture.rice.id,
        quantityKg: 50,
        note: _stockTakeNote,
      );
      final beforeStock = await fixture.inventory.currentStockKg(
        fixture.rice.id,
      );
      final beforeMovements = await fixture.inventory.listAllMovements();
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: controller),
      );
      await tester.pumpAndSettle();
      await controller.load(_owner);
      await tester.pumpAndSettle();

      expect(
          await fixture.inventory.currentStockKg(fixture.rice.id), beforeStock);
      expect(await fixture.inventory.listAllMovements(), beforeMovements);
    });

    test('Phase 51 documentation states scope, stop conditions, and deferrals',
        () {
      final content = File(
        'docs/PHASE-51-REAL-BUSINESS-DAY-SIMULATION.md',
      ).readAsStringSync();
      final lower = content.toLowerCase();

      expect(content, contains('Phase purpose'));
      expect(content, contains('Baseline'));
      expect(content, contains('Simulation scope'));
      expect(content, contains('Synthetic business-day scenario'));
      expect(content, contains('Expected accounting and stock invariants'));
      expect(content, contains('Stop conditions'));
      expect(content, contains('Deferred items'));
      expect(lower, contains('test-only synthetic data'));
      expect(content, contains('No cloud sync was implemented'));
      expect(content, contains('No mobile app was implemented'));
      expect(content, contains('No multi-device live sync was implemented'));
    });
  });
}

class _BusinessDayFixture {
  const _BusinessDayFixture({
    required this.products,
    required this.suppliers,
    required this.customers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.customerAccounts,
    required this.supplierAccounts,
    required this.expenses,
    required this.reports,
    required this.documents,
    required this.wheat,
    required this.corn,
    required this.rice,
    required this.supplier,
    required this.customer,
  });

  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalCustomerRepository customers;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalCustomerAccountRepository customerAccounts;
  final LocalSupplierAccountRepository supplierAccounts;
  final LocalExpenseRepository expenses;
  final LocalReportRepository reports;
  final LocalDocumentHistoryRepository documents;
  final Product wheat;
  final Product corn;
  final Product rice;
  final Supplier supplier;
  final Customer customer;

  static Future<_BusinessDayFixture> create() async {
    final products = LocalProductRepository();
    final suppliers = LocalSupplierRepository();
    final customers = LocalCustomerRepository();
    final inventory = LocalInventoryRepository(productRepository: products);
    final customerAccounts = LocalCustomerAccountRepository(
      customerRepository: customers,
    );
    final supplierAccounts = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
    );
    final purchases = LocalPurchaseRepository(
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
      supplierAccountRepository: supplierAccounts,
    );
    final sales = LocalSaleRepository(
      productRepository: products,
      inventoryRepository: inventory,
    );
    final expenses = LocalExpenseRepository();
    final reports = LocalReportRepository(
      purchaseRepository: purchases,
      saleRepository: sales,
      inventoryRepository: inventory,
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(products),
      expenseRepository: expenses,
      customerAccountRepository: customerAccounts,
      supplierAccountRepository: supplierAccounts,
    );
    final documents = LocalDocumentHistoryRepository(
      purchaseRepository: purchases,
      saleRepository: sales,
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(products),
      inventoryRepository: inventory,
    );

    final wheat = await products.createProduct(
      const ProductDraft(
        name: '\u0642\u0645\u062d \u0628\u0644\u062f\u064a',
        unit: GrainUnit.kilogram,
        referenceCostPricePiastersPerKg: 1500,
      ),
    );
    final corn = await products.createProduct(
      const ProductDraft(
        name: '\u0630\u0631\u0629 \u0635\u0641\u0631\u0627\u0621',
        unit: GrainUnit.kilogram,
        referenceCostPricePiastersPerKg: 1200,
      ),
    );
    final rice = await products.createProduct(
      const ProductDraft(
        name: '\u0623\u0631\u0632 \u0623\u0628\u064a\u0636',
        unit: GrainUnit.kilogram,
        referenceCostPricePiastersPerKg: 1800,
      ),
    );
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(
        name:
            '\u0645\u0648\u0631\u062f \u0627\u062e\u062a\u0628\u0627\u0631 \u0627\u0644\u064a\u0648\u0645',
      ),
    );
    final customer = await customers.createCustomer(
      const CustomerDraft(
        name:
            '\u0639\u0645\u064a\u0644 \u0627\u062e\u062a\u0628\u0627\u0631 \u0627\u0644\u064a\u0648\u0645',
        isActive: true,
      ),
    );

    return _BusinessDayFixture(
      products: products,
      suppliers: suppliers,
      customers: customers,
      inventory: inventory,
      purchases: purchases,
      sales: sales,
      customerAccounts: customerAccounts,
      supplierAccounts: supplierAccounts,
      expenses: expenses,
      reports: reports,
      documents: documents,
      wheat: wheat,
      corn: corn,
      rice: rice,
      supplier: supplier,
      customer: customer,
    );
  }

  PurchaseIntakeDraft purchaseDraft({
    required String productId,
    required int quantityKg,
    required int unitPriceQirshPerKg,
  }) {
    return PurchaseIntakeDraft(
      supplierId: supplier.id,
      productId: productId,
      quantityKg: quantityKg,
      entryUnit: GrainUnit.kilogram,
      unitPricePiastersPerKg: unitPriceQirshPerKg,
      createdByUserId: _owner.id,
      notes: 'Phase 51 synthetic purchase intake',
    );
  }

  SaleDraft saleDraft({
    required String productId,
    required int quantityKg,
    required int priceQirshPerKg,
    required SalePaymentMode paymentMode,
  }) {
    return SaleDraft(
      productId: productId,
      quantityKg: quantityKg,
      salePriceQirshPerKg: priceQirshPerKg,
      createdByUserId: _owner.id,
      createdByUserName: _owner.name,
      paymentMode: paymentMode,
      customerId: customer.id,
      notes: 'Phase 51 synthetic sale',
    );
  }
}

Widget _reportHarness({
  required AuthController auth,
  required InventoryController controller,
}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: StockAdjustmentReportScreen(controller: controller),
      ),
    ),
  );
}

Future<AuthController> _signedInController({
  required String phone,
  required String password,
}) async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: phone, password: password);
  return controller;
}

int _movementBalance(List<StockMovement> movements, String productId) {
  return movements
      .where((movement) => movement.productId == productId)
      .fold<int>(0, (total, movement) => total + movement.signedQuantityKg);
}

const _stockTakeNote =
    '\u062a\u0633\u0648\u064a\u0629 \u062c\u0631\u062f \u0627\u0644\u0645\u062e\u0632\u0648\u0646';

final _now = DateTime(2026, 1, 1);

final _owner = AppUser(
  id: 'owner-test',
  name: '\u0645\u0627\u0644\u0643',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
