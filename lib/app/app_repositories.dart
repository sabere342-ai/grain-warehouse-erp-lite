import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class AppRepositories {
  AppRepositories._();

  static final LocalProductRepository productRepository =
      LocalProductRepository();

  static final LocalInventoryRepository inventoryRepository =
      LocalInventoryRepository(productRepository: productRepository);

  static final LocalSupplierRepository supplierRepository =
      LocalSupplierRepository();

  static final LocalPurchaseRepository purchaseRepository =
      LocalPurchaseRepository(
    supplierRepository: supplierRepository,
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
  );

  static final LocalSaleRepository saleRepository = LocalSaleRepository(
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
  );
}
