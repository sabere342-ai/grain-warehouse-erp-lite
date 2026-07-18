import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';

void main() {
  test('classifies canonical inventory attention and sorts deterministically',
      () async {
    final products = _Products([
      _product('low-b', 'باء', minimumSalePrice: 1),
      _product('out-a', 'ألف'),
      _product('low-a', 'ألف'),
      _product('normal', 'عادي'),
    ]);
    final service = InventoryAttentionService(
      productRepository: products,
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
      productRepository: _Products([
        _product('negative', 'ناقص', minimumSalePrice: 9),
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
      productRepository: _Products([_product('normal', 'عادي')]),
      inventoryRepository: _Inventory({'normal': 6}),
    );

    expect(await service.loadAttention(), isEmpty);
  });
}

Product _product(String id, String name, {int? minimumSalePrice}) => Product(
      id: id,
      name: name,
      unit: GrainUnit.kilogram,
      isActive: true,
      minimumSalePricePiastersPerKg: minimumSalePrice,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

final class _Products implements ProductRepository {
  _Products(this._items);
  final List<Product> _items;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) async =>
      List<Product>.unmodifiable(_items);

  @override
  Future<Product> createProduct(ProductDraft draft) =>
      throw UnimplementedError();
  @override
  Future<Product> setProductActive(
          {required String productId, required bool isActive}) =>
      throw UnimplementedError();
  @override
  Future<Product> updateProduct(
          {required String productId, required ProductDraft draft}) =>
      throw UnimplementedError();
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
