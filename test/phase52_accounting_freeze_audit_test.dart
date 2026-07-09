import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
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

void main() {
  group('Phase 52 accounting freeze audit documentation', () {
    late final String content;
    late final String lower;

    setUpAll(() {
      content = File('docs/PHASE-52-ACCOUNTING-FREEZE-AUDIT.md')
          .readAsStringSync();
      lower = content.toLowerCase();
    });

    test('documents source-of-truth map and local-only boundaries', () {
      expect(content, contains('Accounting source-of-truth map'));
      expect(lower, contains('source of truth'));
      expect(content, contains('No cloud sync was implemented'));
      expect(content, contains('No mobile app was implemented'));
      expect(content, contains('No multi-device live sync was implemented'));
      expect(content, contains('Product stock quantity'));
      expect(content, contains('Customer balance'));
      expect(content, contains('Supplier balance'));
      expect(content, contains('Daily report totals'));
      expect(content, contains('Stock-taking'));
      expect(content, contains('Stock adjustment report'));
      expect(content, contains('Document history'));
      expect(content, contains('Backup/restore'));
    });

    test('documents read-only and no-go freeze rules', () {
      expect(lower, contains('read-only'));
      expect(lower, contains('reports must not mutate data'));
      expect(lower, contains('stock adjustment report is read-only'));
      expect(lower, contains('does not invent before/after balances'));
      expect(content, contains('Accounting freeze no-go list'));
      expect(content, contains('Phase 53 - Cloud Migration Readiness'));
      expect(content, contains('planning/readiness only'));
    });
  });

  group('Phase 52 accounting freeze invariants', () {
    test('domain operations do not mutate unrelated balances', () async {
      final fixture = await _FreezeFixture.create();
      final purchase = await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(quantityKg: 100, unitPriceQirshPerKg: 1000),
      );
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 100);
      expect(
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        100000,
      );

      final sale = await fixture.sales.createSale(
        fixture.saleDraft(quantityKg: 40, salePriceQirshPerKg: 2000),
      );
      await fixture.customerAccounts.createCreditSaleEntry(
        sale: sale,
        customerId: fixture.customer.id,
      );
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 60);
      expect(
        await fixture.customerAccounts.balanceForCustomer(fixture.customer.id),
        80000,
      );

      final supplierBeforeCollection =
          await fixture.supplierAccounts.balanceForSupplier(
        fixture.supplier.id,
      );
      await fixture.customerAccounts.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: _today,
          amountQirsh: 30000,
          createdByUserId: _owner.id,
        ),
      );
      expect(
        await fixture.customerAccounts.balanceForCustomer(fixture.customer.id),
        50000,
      );
      expect(
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        supplierBeforeCollection,
      );

      final customerBeforeSupplierPayment =
          await fixture.customerAccounts.balanceForCustomer(
        fixture.customer.id,
      );
      await fixture.supplierAccounts.createPayment(
        SupplierPaymentDraft(
          supplierId: fixture.supplier.id,
          date: _today,
          amountQirsh: 25000,
          createdByUserId: _owner.id,
        ),
      );
      expect(
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        75000,
      );
      expect(
        await fixture.customerAccounts.balanceForCustomer(fixture.customer.id),
        customerBeforeSupplierPayment,
      );

      final inventoryController = InventoryController(
        inventoryRepository: fixture.inventory,
        productRepository: fixture.products,
      );
      await inventoryController.load(_owner);
      await inventoryController.createManualIncrease(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 10,
        note: 'Phase 52 stock-taking adjustment',
      );

      expect(await fixture.inventory.currentStockKg(fixture.product.id), 70);
      expect(
        await fixture.customerAccounts.balanceForCustomer(fixture.customer.id),
        50000,
      );
      expect(
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        75000,
      );

      final beforeReportStock =
          await fixture.inventory.currentStockKg(fixture.product.id);
      final beforeReportCustomer =
          await fixture.customerAccounts.balanceForCustomer(fixture.customer.id);
      final beforeReportSupplier =
          await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id);

      final report = await fixture.reports.dailyActivityReport(
        selectedDate: _today,
      );
      expect(report.totalPurchaseAmountQirsh, purchase.totalAmountPiasters);
      expect(report.totalSalesAmountQirsh, sale.totalQirsh);
      expect(report.totalCollectionsAmountQirsh, 30000);
      expect(report.totalSupplierPaymentsQirsh, 25000);
      expect(report.totalOutstandingReceivablesQirsh, beforeReportCustomer);
      expect(report.totalOutstandingSupplierPayablesQirsh, beforeReportSupplier);

      expect(await fixture.inventory.currentStockKg(fixture.product.id),
          beforeReportStock);
      expect(
        await fixture.customerAccounts.balanceForCustomer(fixture.customer.id),
        beforeReportCustomer,
      );
      expect(
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        beforeReportSupplier,
      );
    });

    test('stock movement ledger remains the quantity source of truth',
        () async {
      final fixture = await _FreezeFixture.create();
      final purchase = await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(quantityKg: 120, unitPriceQirshPerKg: 1000),
      );
      final sale = await fixture.sales.createSale(
        fixture.saleDraft(quantityKg: 50, salePriceQirshPerKg: 1800),
      );
      final controller = InventoryController(
        inventoryRepository: fixture.inventory,
        productRepository: fixture.products,
      );
      await controller.load(_owner);
      await controller.createManualDecrease(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 10,
        note: 'Phase 52 stock count variance',
      );

      final movements = await fixture.inventory.listAllMovements();
      expect(
        movements.map((movement) => movement.movementType),
        containsAll([
          StockMovementType.purchaseIntake,
          StockMovementType.sale,
          StockMovementType.manualDecrease,
        ]),
      );
      expect(
        movements.singleWhere((m) => m.id == purchase.stockMovementId)
            .signedQuantityKg,
        120,
      );
      expect(
        movements.singleWhere((m) => m.id == sale.stockMovementId)
            .signedQuantityKg,
        -50,
      );
      expect(_movementBalance(movements, fixture.product.id), 60);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 60);

      final manualAdjustments = movements
          .where((movement) =>
              movement.movementType == StockMovementType.manualIncrease ||
              movement.movementType == StockMovementType.manualDecrease)
          .toList(growable: false);
      expect(manualAdjustments, hasLength(1));
      expect(manualAdjustments.single.note, 'Phase 52 stock count variance');
    });

    test('supported cancellations use reversal stock movements', () async {
      final fixture = await _FreezeFixture.create();
      final purchase = await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(quantityKg: 100, unitPriceQirshPerKg: 1000),
      );
      final sale = await fixture.sales.createSale(
        fixture.saleDraft(quantityKg: 30, salePriceQirshPerKg: 2000),
      );

      final cancelledSale = await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'Phase 52 sale cancellation',
      );
      expect(cancelledSale.isCancelled, isTrue);

      final activePurchase = await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(quantityKg: 10, unitPriceQirshPerKg: 1000),
      );
      final cancelledPurchase = await fixture.purchases.cancelPurchaseIntake(
        purchaseIntakeId: activePurchase.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'Phase 52 purchase cancellation',
      );
      expect(cancelledPurchase.isCancelled, isTrue);

      final movements = await fixture.inventory.listAllMovements();
      expect(
        movements.where((movement) =>
            movement.movementType == StockMovementType.saleCancellation),
        hasLength(1),
      );
      expect(
        movements.where((movement) =>
            movement.movementType == StockMovementType.purchaseCancellation),
        hasLength(1),
      );
      expect(
        movements
            .singleWhere((movement) =>
                movement.movementType == StockMovementType.saleCancellation)
            .reversedMovementId,
        sale.stockMovementId,
      );
      expect(
        movements
            .singleWhere((movement) =>
                movement.movementType ==
                StockMovementType.purchaseCancellation)
            .reversedMovementId,
        activePurchase.stockMovementId,
      );
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 100);
      expect(
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        purchase.totalAmountPiasters,
      );
    });
  });
}

class _FreezeFixture {
  const _FreezeFixture({
    required this.products,
    required this.suppliers,
    required this.customers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.customerAccounts,
    required this.supplierAccounts,
    required this.reports,
    required this.product,
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
  final LocalReportRepository reports;
  final Product product;
  final Supplier supplier;
  final Customer customer;

  static Future<_FreezeFixture> create() async {
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
    final reports = LocalReportRepository(
      purchaseRepository: purchases,
      saleRepository: sales,
      inventoryRepository: inventory,
      productRepository: products,
      expenseRepository: LocalExpenseRepository(),
      customerAccountRepository: customerAccounts,
      supplierAccountRepository: supplierAccounts,
    );

    final product = await products.createProduct(
      const ProductDraft(
        name: 'Phase 52 wheat',
        unit: GrainUnit.kilogram,
        referenceCostPricePiastersPerKg: 1000,
      ),
    );
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Phase 52 supplier'),
    );
    final customer = await customers.createCustomer(
      const CustomerDraft(name: 'Phase 52 customer', isActive: true),
    );

    return _FreezeFixture(
      products: products,
      suppliers: suppliers,
      customers: customers,
      inventory: inventory,
      purchases: purchases,
      sales: sales,
      customerAccounts: customerAccounts,
      supplierAccounts: supplierAccounts,
      reports: reports,
      product: product,
      supplier: supplier,
      customer: customer,
    );
  }

  PurchaseIntakeDraft purchaseDraft({
    required int quantityKg,
    required int unitPriceQirshPerKg,
  }) {
    return PurchaseIntakeDraft(
      supplierId: supplier.id,
      productId: product.id,
      quantityKg: quantityKg,
      entryUnit: GrainUnit.kilogram,
      unitPricePiastersPerKg: unitPriceQirshPerKg,
      createdByUserId: _owner.id,
    );
  }

  SaleDraft saleDraft({
    required int quantityKg,
    required int salePriceQirshPerKg,
  }) {
    return SaleDraft(
      productId: product.id,
      quantityKg: quantityKg,
      salePriceQirshPerKg: salePriceQirshPerKg,
      createdByUserId: _owner.id,
      createdByUserName: _owner.name,
      paymentMode: SalePaymentMode.credit,
      customerId: customer.id,
    );
  }
}

int _movementBalance(List<StockMovement> movements, String productId) {
  return movements
      .where((movement) => movement.productId == productId)
      .fold<int>(0, (total, movement) => total + movement.signedQuantityKg);
}

final _today = DateTime.now();
final _now = DateTime(2026, 1, 1);

final _owner = AppUser(
  id: 'owner-test',
  name: 'Owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
