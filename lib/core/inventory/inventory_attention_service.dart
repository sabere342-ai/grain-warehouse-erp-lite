import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';

/// Read-only canonical classification for products requiring stock attention.
enum InventoryAttentionType { outOfStock, lowStock }

abstract interface class InventoryAttentionReader {
  Future<List<InventoryAttentionItem>> loadAttention();
}

final class InventoryAttentionItem {
  const InventoryAttentionItem({
    required this.productId,
    required this.productName,
    required this.quantityKg,
    required this.isActive,
    required this.type,
  });

  final String productId;
  final String productName;
  final int quantityKg;
  final bool isActive;
  final InventoryAttentionType type;
}

/// Uses the authoritative inventory balance source without changing stock.
final class InventoryAttentionService implements InventoryAttentionReader {
  InventoryAttentionService({
    required ProductCatalogReadRepository productCatalogReadRepository,
    required InventoryRepository inventoryRepository,
  })  : _productCatalogReadRepository = productCatalogReadRepository,
        _inventoryRepository = inventoryRepository;

  static const int lowStockMaximumKg = 5;

  final ProductCatalogReadRepository _productCatalogReadRepository;
  final InventoryRepository _inventoryRepository;

  @override
  Future<List<InventoryAttentionItem>> loadAttention() async {
    final products = await _productCatalogReadRepository.listProductCatalog(
      includeInactive: true,
    );
    final balances = await _inventoryRepository.allProductBalancesKg();
    final items = <InventoryAttentionItem>[];

    for (final product in products) {
      final quantityKg = balances[product.id] ?? 0;
      final type = _classify(quantityKg);
      if (type == null) continue;
      items.add(InventoryAttentionItem(
        productId: product.id,
        productName: product.name,
        quantityKg: quantityKg,
        isActive: product.isActive,
        type: type,
      ));
    }

    items.sort((a, b) {
      final type = a.type.index.compareTo(b.type.index);
      if (type != 0) return type;
      final quantity = a.quantityKg.compareTo(b.quantityKg);
      if (quantity != 0) return quantity;
      final name = a.productName.compareTo(b.productName);
      if (name != 0) return name;
      return a.productId.compareTo(b.productId);
    });
    return List<InventoryAttentionItem>.unmodifiable(items);
  }

  InventoryAttentionType? _classify(int quantityKg) {
    if (quantityKg <= 0) return InventoryAttentionType.outOfStock;
    if (quantityKg <= lowStockMaximumKg) {
      return InventoryAttentionType.lowStock;
    }
    return null;
  }
}
