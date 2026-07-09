import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  test('debug movement lookup', () async {
    final products = LocalProductRepository();
    final product = await products.createProduct(
      const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
    );
    final customers = LocalCustomerRepository();
    final customer = await customers.createCustomer(
      const CustomerDraft(name: 'عميل', isActive: true),
    );
    final inventory = LocalInventoryRepository(productRepository: products);
    await inventory.createMovement(
      StockMovementDraft(
        productId: product.id,
        movementType: StockMovementType.openingBalance,
        quantityKg: 2000,
        createdByUserId: 'owner',
      ),
    );
    final sales = LocalSaleRepository(
      productRepository: products,
      inventoryRepository: inventory,
    );

    final draft = SaleDraft(
      productId: product.id,
      quantityKg: 100,
      salePriceQirshPerKg: 700,
      createdByUserId: 'owner',
      customerId: customer.id,
    );
    print('draft.customerId=${draft.customerId}');

    final sale = await sales.createSale(draft);
    print('sale.id=${sale.id}');
    print('sale.stockMovementId=${sale.stockMovementId}');
    print('sale.items.length=${sale.items.length}');
    print('sale.customerId=${sale.customerId}');

    final allMovements = await inventory.listAllMovements();
    print('Movements after createSale:');
    for (final m in allMovements) {
      print('  m.id=${m.id} m.movementType=${m.movementType}');
    }

    final found = allMovements.where((m) => m.id == sale.stockMovementId);
    print('Found by stockMovementId: ${found.length}');
    if (found.isNotEmpty) {
      print('  found[0].id=${found.first.id}');
    }

    await sales.cancelSale(
      saleId: sale.id,
      cancelledByUserId: 'owner',
      cancellationReason: 'test',
    );

    final allMovements2 = await inventory.listAllMovements();
    print('Movements after cancelSale:');
    for (final m in allMovements2) {
      print('  m.id=${m.id} m.movementType=${m.movementType}');
    }

    final purchases = LocalPurchaseRepository(
      supplierRepository: LocalSupplierRepository(),
      productRepository: products,
      inventoryRepository: inventory,
    );
    final history = LocalDocumentHistoryRepository(
      purchaseRepository: purchases,
      saleRepository: sales,
      productRepository: products,
      inventoryRepository: inventory,
    );

    final entries = await history.listHistory(
      filter: const DocumentHistoryFilter(
        status: DocumentHistoryStatus.cancelled,
      ),
    );
    print('History entries: ${entries.length}');
    for (final e in entries) {
      print('  e.id=${e.id}');
      print('  e.originalMovement=${e.originalMovement}');
      print('  e.originalMovement?.id=${e.originalMovement?.id}');
      print('  e.originalMovement.runtimeType=${e.originalMovement.runtimeType}');
    }

    expect(entries.length, 1);
    final entry = entries.single;
    expect(entry.originalMovement, isNotNull);
    expect(entry.originalMovement!.id, sale.stockMovementId);
  });
}
