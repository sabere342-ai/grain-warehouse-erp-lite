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

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 53 cloud migration readiness documentation', () {
    late final String content;
    late final String lower;

    setUpAll(() {
      content =
          File('docs/PHASE-53-CLOUD-MIGRATION-READINESS.md').readAsStringSync();
      lower = content.toLowerCase();
    });

    test('states planning-only scope and explicit non-implementation', () {
      expect(content, contains('Phase 53 - Cloud Migration Readiness'));
      expect(content,
          contains('Phase 53 is a planning, readiness, and audit phase only'));
      expect(content, contains('No cloud sync was implemented in Phase 53'));
      expect(content, contains('No mobile app was implemented in Phase 53'));
      expect(content,
          contains('No multi-device live sync was implemented in Phase 53'));
      expect(content,
          contains('No production code or schema change was required'));
      expect(content, contains('Phase 53 does not add Firebase, Supabase'));
      expect(
          content, contains('Phase 53 does not create a new delivery package'));
    });

    test('documents cloud risks, minimum requirements, and migration path', () {
      for (final phrase in [
        'Duplicate sales from retry/unstable internet',
        'Same product sold from two devices at once',
        'Purchase and sale ordering conflict',
        'Customer collection entered on two devices',
        'Supplier payment entered on two devices',
        'Manual stock adjustment conflict',
        'Backup restored over non-empty cloud data',
        'Device clock differences',
        'Owner/admin/cashier permission drift',
        'Partial sync causing reports to mismatch',
        'Code exposure risk in client delivery',
        'Step A - Owner identity and tenant model design',
        'Step B - Append-only sync contract',
        'Step C - Conflict policy for inventory/customer/supplier ledgers',
        'Step D - Server-side validation',
        'Step E - Read-only reporting projections',
        'Step F - Staged pilot with one owner account and one device first',
      ]) {
        expect(content, contains(phrase));
      }

      expect(lower, contains('idempotency key'));
      expect(lower, contains('tenant isolation'));
      expect(lower, contains('server-side validation'));
      expect(lower, contains('restore-to-empty'));
      expect(lower, contains('not a cloud merge'));
    });

    test('treats accounting-critical events as future sync events', () {
      for (final phrase in [
        'sales',
        'purchases',
        'payments',
        'collections',
        'stock adjustments',
        'cancellations',
        'opening balances',
      ]) {
        expect(lower, contains(phrase));
      }
    });
  });

  group('Phase 53 current local invariants for future cloud migration', () {
    test(
        'inventory, customer, and supplier balances keep separate sources of truth',
        () async {
      final fixture = await _ReadinessFixture.create();
      final purchase = await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(quantityKg: 100, unitPriceQirshPerKg: 1000),
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
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        purchase.totalAmountPiasters,
      );
      expect(
        await fixture.customerAccounts.balanceForCustomer(fixture.customer.id),
        sale.totalQirsh,
      );

      await fixture.customerAccounts.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: _today,
          amountQirsh: 30000,
          createdByUserId: _owner.id,
        ),
      );
      await fixture.supplierAccounts.createPayment(
        SupplierPaymentDraft(
          supplierId: fixture.supplier.id,
          date: _today,
          amountQirsh: 25000,
          createdByUserId: _owner.id,
        ),
      );

      final controller = InventoryController(
        inventoryRepository: fixture.inventory,
        productRepository: fixture.products,
      );
      await controller.load(_owner);
      await controller.createManualIncrease(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 5,
        note: 'Phase 53 stock-taking readiness adjustment',
      );

      expect(await fixture.inventory.currentStockKg(fixture.product.id), 65);
      expect(
        await fixture.customerAccounts.balanceForCustomer(fixture.customer.id),
        50000,
      );
      expect(
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        75000,
      );

      final movements = await fixture.inventory.listAllMovements();
      expect(_movementBalance(movements, fixture.product.id), 65);
      expect(
        movements.map((movement) => movement.movementType),
        containsAll([
          StockMovementType.purchaseIntake,
          StockMovementType.sale,
          StockMovementType.manualIncrease,
        ]),
      );
    });

    test('read-only daily reports do not mutate ledger state', () async {
      final fixture = await _ReadinessFixture.create();
      await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(quantityKg: 80, unitPriceQirshPerKg: 1000),
      );
      final sale = await fixture.sales.createSale(
        fixture.saleDraft(quantityKg: 30, salePriceQirshPerKg: 2000),
      );
      await fixture.customerAccounts.createCreditSaleEntry(
        sale: sale,
        customerId: fixture.customer.id,
      );
      await fixture.customerAccounts.createCollection(
        CustomerCollectionDraft(
          customerId: fixture.customer.id,
          date: _today,
          amountQirsh: 10000,
          createdByUserId: _owner.id,
        ),
      );

      final stockBefore =
          await fixture.inventory.currentStockKg(fixture.product.id);
      final customerBefore = await fixture.customerAccounts
          .balanceForCustomer(fixture.customer.id);
      final supplierBefore = await fixture.supplierAccounts
          .balanceForSupplier(fixture.supplier.id);
      final movementsBefore = await fixture.inventory.listAllMovements();

      final report = await fixture.reports.dailyActivityReport(
        selectedDate: _today,
      );

      expect(report.totalSalesAmountQirsh, sale.totalQirsh);
      expect(report.totalOutstandingReceivablesQirsh, customerBefore);
      expect(report.totalOutstandingSupplierPayablesQirsh, supplierBefore);
      expect(await fixture.inventory.currentStockKg(fixture.product.id),
          stockBefore);
      expect(
        await fixture.customerAccounts.balanceForCustomer(fixture.customer.id),
        customerBefore,
      );
      expect(
        await fixture.supplierAccounts.balanceForSupplier(fixture.supplier.id),
        supplierBefore,
      );
      expect(await fixture.inventory.listAllMovements(), movementsBefore);
    });

    test('cancellation keeps documents and adds reversal audit movements',
        () async {
      final fixture = await _ReadinessFixture.create();
      final purchase = await fixture.purchases.createPurchaseIntake(
        fixture.purchaseDraft(quantityKg: 100, unitPriceQirshPerKg: 1000),
      );
      final sale = await fixture.sales.createSale(
        fixture.saleDraft(quantityKg: 30, salePriceQirshPerKg: 2000),
      );

      final cancelledSale = await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'Phase 53 sale cancellation readiness',
      );
      final cancelledPurchase = await fixture.purchases.cancelPurchaseIntake(
        purchaseIntakeId: purchase.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'Phase 53 purchase cancellation readiness',
      );

      expect(cancelledSale.isCancelled, isTrue);
      expect(cancelledPurchase.isCancelled, isTrue);
      expect(await fixture.sales.listSales(), hasLength(1));
      expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
      expect((await fixture.sales.listSales()).single.id, sale.id);
      expect((await fixture.purchases.listPurchaseIntakes()).single.id,
          purchase.id);

      final movements = await fixture.inventory.listAllMovements();
      expect(
        movements.map((movement) => movement.movementType),
        containsAll([
          StockMovementType.purchaseIntake,
          StockMovementType.sale,
          StockMovementType.saleCancellation,
          StockMovementType.purchaseCancellation,
        ]),
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
                movement.movementType == StockMovementType.purchaseCancellation)
            .reversedMovementId,
        purchase.stockMovementId,
      );
    });

    test('backup and restore assumptions remain local-first in readiness docs',
        () {
      final content =
          File('docs/PHASE-53-CLOUD-MIGRATION-READINESS.md').readAsStringSync();
      expect(content, contains('Current backup export is local JSON'));
      expect(
          content, contains('Current restore is local restore-to-empty only'));
      expect(content, contains('Current restore is not a cloud merge'));
      expect(
        content,
        contains(
            'Current restore is not safe to run over non-empty cloud tenant data'),
      );
    });
  });
}

class _ReadinessFixture {
  const _ReadinessFixture({
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

  static Future<_ReadinessFixture> create() async {
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
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(products),
      expenseRepository: LocalExpenseRepository(),
      customerAccountRepository: customerAccounts,
      supplierAccountRepository: supplierAccounts,
    );

    final product = await products.createProduct(
      const ProductDraft(
        name: 'Phase 53 wheat',
        unit: GrainUnit.kilogram,
        referenceCostPricePiastersPerKg: 1000,
      ),
    );
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Phase 53 supplier'),
    );
    final customer = await customers.createCustomer(
      const CustomerDraft(name: 'Phase 53 customer', isActive: true),
    );

    return _ReadinessFixture(
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
