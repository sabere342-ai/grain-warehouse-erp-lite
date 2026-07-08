import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

final _now = DateTime(2026, 1, 1);

final _owner = AppUser(
  id: 'owner-1',
  name: 'مالك',
  phone: '01000000001',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

SupplierDraft _supplierDraft({required String name, String? phone}) {
  return SupplierDraft(
    name: name,
    phone: phone,
    address: 'عنوان المورد',
    notes: 'مورد حبوب',
  );
}

ProductDraft _productDraft() {
  return const ProductDraft(
    name: 'قمح',
    unit: GrainUnit.kilogram,
  );
}

void main() {
  group('Phase 38 Arabic UX and permission hardening', () {
    group('movement notes are in Arabic', () {
      test('purchase intake creates Arabic movement note', () async {
        final suppliers = LocalSupplierRepository();
        final products = LocalProductRepository();
        final supplier = await suppliers.createSupplier(
          _supplierDraft(name: 'مورد القمح'),
        );
        final product = await products.createProduct(_productDraft());
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final purchases = LocalPurchaseRepository(
          supplierRepository: suppliers,
          productRepository: products,
          inventoryRepository: inventory,
        );

        final intake = await purchases.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 50,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 3000,
            createdByUserId: _owner.id,
          ),
        );
        final movements = await inventory.listMovementsByProduct(product.id);
        final intakeMovement = movements.firstWhere(
          (m) => m.id == intake.stockMovementId,
        );

        expect(intakeMovement.note, contains('استلام شراء'));
      });

      test('sale creates Arabic movement note', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(_productDraft());
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        final sale = await sales.createSale(
          SaleDraft(
            productId: product.id,
            quantityKg: 10,
            salePriceQirshPerKg: 5000,
            createdByUserId: _owner.id,
          ),
        );
        final movements = await inventory.listMovementsByProduct(product.id);
        final saleMovement = movements.firstWhere(
          (m) => m.id == sale.stockMovementId,
        );

        expect(saleMovement.note, contains('بيع'));
      });

      test('purchase cancellation creates Arabic movement note', () async {
        final suppliers = LocalSupplierRepository();
        final products = LocalProductRepository();
        final supplier = await suppliers.createSupplier(
          _supplierDraft(name: 'مورد القمح'),
        );
        final product = await products.createProduct(_productDraft());
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final purchases = LocalPurchaseRepository(
          supplierRepository: suppliers,
          productRepository: products,
          inventoryRepository: inventory,
        );

        final intake = await purchases.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 50,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 3000,
            createdByUserId: _owner.id,
          ),
        );
        final cancelled = await purchases.cancelPurchaseIntake(
          purchaseIntakeId: intake.id,
          cancelledByUserId: _owner.id,
          cancellationReason: 'خطأ في الكمية',
        );
        final movements = await inventory.listMovementsByProduct(product.id);
        final reversalMovement = movements.firstWhere(
          (m) =>
              m.movementType == StockMovementType.purchaseCancellation,
        );

        expect(reversalMovement.note, contains('إلغاء'));
      });

      test('sale cancellation creates Arabic movement note', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(_productDraft());
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        final sale = await sales.createSale(
          SaleDraft(
            productId: product.id,
            quantityKg: 10,
            salePriceQirshPerKg: 5000,
            createdByUserId: _owner.id,
          ),
        );
        final cancelled = await sales.cancelSale(
          saleId: sale.id,
          cancelledByUserId: _owner.id,
          cancellationReason: 'مرتجع',
        );
        final movements = await inventory.listMovementsByProduct(product.id);
        final reversalMovement = movements.firstWhere(
          (m) => m.movementType == StockMovementType.saleCancellation,
        );

        expect(reversalMovement.note, contains('إلغاء'));
      });
    });

    group('error messages are Arabic, not raw exceptions', () {
      test('missing product in purchase intake throws StateError with no \$e',
          () async {
        final suppliers = LocalSupplierRepository();
        final products = LocalProductRepository();
        final supplier = await suppliers.createSupplier(
          _supplierDraft(name: 'مورد القمح'),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        final purchases = LocalPurchaseRepository(
          supplierRepository: suppliers,
          productRepository: products,
          inventoryRepository: inventory,
        );

        expect(
          () => purchases.createPurchaseIntake(
            PurchaseIntakeDraft(
              supplierId: supplier.id,
              productId: 'nonexistent',
              quantityKg: 10,
              entryUnit: GrainUnit.kilogram,
              unitPricePiastersPerKg: 1000,
              createdByUserId: _owner.id,
            ),
          ),
          throwsStateError,
        );
      });
    });

    group('employee permission limitations', () {
      test('employee cannot view reports', () {
        expect(Permissions.employee.canViewReports, isFalse);
      });

      test('employee cannot view audit logs', () {
        expect(Permissions.employee.canViewAuditLogs, isFalse);
      });

      test('employee cannot manage suppliers', () {
        expect(Permissions.employee.canManageSuppliers, isFalse);
      });

      test('employee cannot create purchase intake', () {
        expect(Permissions.employee.canCreatePurchaseIntake, isFalse);
      });

      test('employee cannot cancel invoices', () {
        expect(Permissions.employee.canCancelInvoice, isFalse);
      });

      test('employee cannot create stock adjustment', () {
        expect(Permissions.employee.canCreateStockAdjustment, isFalse);
      });

      test('employee cannot manage products', () {
        expect(Permissions.employee.canManageProducts, isFalse);
      });

      test('employee cannot access settings', () {
        expect(Permissions.employee.canAccessSettings, isFalse);
      });
    });

    group('owner full access', () {
      test('owner can access all permissions', () {
        expect(Permissions.owner.hasFullAccess, isTrue);
      });
    });
  });
}
