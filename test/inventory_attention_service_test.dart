import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';

void main() {
  test('classifies canonical inventory attention and sorts deterministically',
      () async {
    final products = _Products([
      _product('low-b', 'باء'),
      _product('out-a', 'ألف'),
      _product('low-a', 'ألف'),
      _product('normal', 'عادي'),
    ]);
    final service = InventoryAttentionService(
      productCatalogReadRepository: products,
      inventoryRepository: _Inventory({
        'low-b': 5,
        'out-a': 0,
        'low-a': 3,
        'normal': 6,
      }),
    );

    final items = await service.loadAttention();

    expect(items.map((item) => item.productId), ['out-a', 'low-a', 'low-b']);
    expect(items.map((item) => item.type), [
      InventoryAttentionType.outOfStock,
      InventoryAttentionType.lowStock,
      InventoryAttentionType.lowStock,
    ]);
  });

  test('negative and zero stock are out of stock and minimum price is ignored',
      () async {
    final service = InventoryAttentionService(
      productCatalogReadRepository: _Products([
        _product('negative', 'ناقص'),
        _product('zero', 'صفر'),
      ]),
      inventoryRepository: _Inventory({'negative': -2, 'zero': 0}),
    );

    final items = await service.loadAttention();

    expect(items, hasLength(2));
    expect(
        items.every((item) => item.type == InventoryAttentionType.outOfStock),
        isTrue);
  });

  test('returns an immutable empty result for normal stock', () async {
    final service = InventoryAttentionService(
      productCatalogReadRepository: _Products([_product('normal', 'عادي')]),
      inventoryRepository: _Inventory({'normal': 6}),
    );

    expect(await service.loadAttention(), isEmpty);
  });
}

ProductCatalogReadModel _product(String id, String name) =>
    ProductCatalogReadModel(
      id: id,
      name: name,
      code: null,
      unit: GrainUnit.kilogram,
      isActive: true,
    );

final class _Products implements ProductCatalogReadRepository {
  _Products(this._items);
  final List<ProductCatalogReadModel> _items;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async =>
      List<ProductCatalogReadModel>.unmodifiable(_items);
}

final class _Inventory implements InventoryRepository {
  _Inventory(this._balances);
  final Map<String, int> _balances;

  @override
  Future<Map<String, int>> allProductBalancesKg(
          {bool activeProductsOnly = false}) async =>
      Map<String, int>.unmodifiable(_balances);
  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) =>
      throw UnimplementedError();
  @override
  Future<int> currentStockKg(String productId) => throw UnimplementedError();
  @override
  Future<bool> hasOpeningBalance(String productId) =>
      throw UnimplementedError();
  @override
  Future<List<StockMovement>> listAllMovements() => throw UnimplementedError();
  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) =>
      throw UnimplementedError();
}
