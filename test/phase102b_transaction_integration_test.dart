import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 102B transaction integration', () {
    test('purchase value posts atomically and direct cancellation is guarded',
        () async {
      final fixture = await _fixture();
      final purchases = LocalPurchaseRepository(
        supplierRepository: fixture.suppliers,
        productRepository: fixture.products,
        inventoryRepository: fixture.inventory,
        inventoryValuationRepository: fixture.valuation,
      );
      final purchase = await purchases.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: fixture.supplierId,
          productId: fixture.productId,
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 700,
          createdByUserId: _owner.id,
        ),
      );
      var state = await fixture.valuation.stateForProduct(fixture.productId);
      expect(state!.quantityKg, 200);
      expect(state.totalValueQirsh, 120000);

      await purchases.cancelPurchaseIntake(
        purchaseIntakeId: purchase.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'TEST FIXTURE — untouched purchase',
      );
      state = await fixture.valuation.stateForProduct(fixture.productId);
      expect(state!.quantityKg, 100);
      expect(state.totalValueQirsh, 50000);

      final mixedPurchase = await purchases.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: fixture.supplierId,
          productId: fixture.productId,
          quantityKg: 50,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 800,
          createdByUserId: _owner.id,
        ),
      );
      final sales = LocalSaleRepository(
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(fixture.products),
        inventoryRepository: fixture.inventory,
        inventoryValuationRepository: fixture.valuation,
      );
      await sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 1,
        salePriceQirshPerKg: 900,
        createdByUserId: _owner.id,
        customerId: 'TEST-CUSTOMER-FIXTURE',
      ));
      final stockBefore =
          await fixture.inventory.currentStockKg(fixture.productId);
      await expectLater(
        purchases.cancelPurchaseIntake(
          purchaseIntakeId: mixedPurchase.id,
          cancelledByUserId: _owner.id,
          cancellationReason: 'TEST FIXTURE — must fail',
        ),
        throwsStateError,
      );
      expect(await fixture.inventory.currentStockKg(fixture.productId),
          stockBefore);
    });

    test(
        'stocktake surplus requires trusted cost and shortage consumes average',
        () async {
      final fixture = await _fixture();
      final audit = LocalAuditLogRepository();
      final controller = InventoryController(
        inventoryRepository: fixture.inventory,
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(fixture.products),
        inventoryValuationRepository: fixture.valuation,
        auditLogRepository: audit,
      );

      expect(
        await controller.createManualIncrease(
          user: _owner,
          productId: fixture.productId,
          quantityKg: 10,
          note: 'TEST FIXTURE — stocktake surplus',
          isStocktake: true,
        ),
        isFalse,
      );
      expect(await fixture.inventory.currentStockKg(fixture.productId), 100);

      expect(
        await controller.createManualIncrease(
          user: _owner,
          productId: fixture.productId,
          quantityKg: 10,
          note: 'TEST FIXTURE — stocktake surplus',
          unitCostQirshPerKg: 600,
          evidenceReference: 'TEST FIXTURE — signed count sheet',
          isStocktake: true,
        ),
        isTrue,
      );
      expect(
        await controller.createManualDecrease(
          user: _owner,
          productId: fixture.productId,
          quantityKg: 5,
          note: 'TEST FIXTURE — stocktake shortage',
          isStocktake: true,
        ),
        isTrue,
      );
      final events = await fixture.valuation.listEvents();
      expect(events[1].type, InventoryValuationEventType.stocktakeSurplus);
      expect(events[2].type, InventoryValuationEventType.stocktakeShortage);
      expect(await audit.exportStoredAuditLogs(), hasLength(2));
    });

    test(
        'expense classification is mandatory and historical edit is owner-only',
        () async {
      final audit = LocalAuditLogRepository();
      final expenses = LocalExpenseRepository(auditLogRepository: audit);
      final expense = await expenses.createExpense(ExpenseDraft(
        date: DateTime.now(),
        category: 'TEST FIXTURE EXPENSE',
        amountQirsh: 1000,
        createdByUserId: _owner.id,
        operationRequestId: 'TEST-EXPENSE-CLASSIFICATION',
        accountingClassification: ExpenseAccountingClassification.capital,
      ));
      expect(expense.affectsOperatingProfit, isFalse);
      await expectLater(
        expenses.reclassifyExpense(
          user: _employee,
          expenseId: expense.id,
          classification: ExpenseAccountingClassification.operating,
          reason: 'TEST FIXTURE',
        ),
        throwsStateError,
      );
      final updated = await expenses.reclassifyExpense(
        user: _owner,
        expenseId: expense.id,
        classification: ExpenseAccountingClassification.operating,
        reason: 'TEST FIXTURE — owner approved correction',
      );
      expect(updated.affectsOperatingProfit, isTrue);
      expect(
        (await audit.exportStoredAuditLogs()).map((entry) => entry.actionType),
        contains('expense.accountingClassification.changed'),
      );
    });
  });
}

Future<_Fixture> _fixture() async {
  final products = LocalProductRepository();
  final product = await products.createProduct(const ProductDraft(
    name: 'TEST PRODUCT FIXTURE',
    unit: GrainUnit.kilogram,
  ));
  final suppliers = LocalSupplierRepository();
  final supplier = await suppliers.createSupplier(
    const SupplierDraft(name: 'TEST SUPPLIER FIXTURE'),
  );
  final inventory = LocalInventoryRepository(productRepository: products);
  await inventory.createMovement(StockMovementDraft(
    productId: product.id,
    movementType: StockMovementType.openingBalance,
    quantityKg: 100,
    createdByUserId: _owner.id,
  ));
  final valuation = LocalInventoryValuationRepository();
  await valuation.activate(
    activationDate: DateTime.now().subtract(const Duration(days: 1)),
    approvedByUserId: _owner.id,
    evidenceNote: 'TEST FIXTURE ONLY — physical count',
    openings: [
      OpeningValuationInput(
        productId: product.id,
        quantityKg: 100,
        unitCostQirshPerKg: 500,
        evidenceReference: 'TEST FIXTURE ONLY — trusted invoice',
      ),
    ],
  );
  return _Fixture(
    products: products,
    suppliers: suppliers,
    inventory: inventory,
    valuation: valuation,
    productId: product.id,
    supplierId: supplier.id,
  );
}

class _Fixture {
  const _Fixture({
    required this.products,
    required this.suppliers,
    required this.inventory,
    required this.valuation,
    required this.productId,
    required this.supplierId,
  });
  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalInventoryRepository inventory;
  final LocalInventoryValuationRepository valuation;
  final String productId;
  final String supplierId;
}

final _owner = AppUser(
  id: 'TEST-OWNER-FIXTURE',
  name: 'Test Owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _employee = AppUser(
  id: 'TEST-EMPLOYEE-FIXTURE',
  name: 'Test Employee',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
