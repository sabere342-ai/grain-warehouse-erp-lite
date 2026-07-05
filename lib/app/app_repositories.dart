import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';

class AppRepositories {
  AppRepositories._();

  static final LocalProductRepository productRepository =
      LocalProductRepository();

  static final LocalInventoryRepository inventoryRepository =
      LocalInventoryRepository(productRepository: productRepository);
}
