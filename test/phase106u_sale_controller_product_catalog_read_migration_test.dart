import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

const _controllerPath = 'lib/core/sales/sale_controller.dart';

void main() {
  group('SaleController.load product catalog read migration', () {
    test('load reads products through ProductCatalogReadRepository only',
        () async {
      final catalog = _Catalog([
        _model('prd-wheat', 'قمح', isActive: true),
        _model('prd-barley', 'شعير', isActive: true),
      ]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      expect(catalog.readCalls, 1);
      expect(catalog.includeInactiveValues, [false]);
      expect(fixture.controller.isLoading, isFalse);
      expect(fixture.controller.products, hasLength(2));
      expect(fixture.sales.readCalls, 1);
      expect(fixture.inventory.balancesCalls, 1);
    });

    test('includeInactive is fixed to false and filters inactive products',
        () async {
      final catalog = _Catalog([
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'شعير', isActive: false),
        _model('prd-3', 'ذرة', isActive: true),
      ]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      expect(catalog.includeInactiveValues, [false]);
      expect(fixture.controller.products, hasLength(2));
      expect(
        fixture.controller.products.map((product) => product.id).toList(),
        ['prd-1', 'prd-3'],
      );
    });

    test('load exposes id, name, and both sale prices from the read model',
        () async {
      final catalog = _Catalog([
        _model('prd-1', 'قمح',
            isActive: true, defaultSalePrice: 3000, minimumSalePrice: 2500),
        _model('prd-2', 'شعير',
            isActive: true, defaultSalePrice: null, minimumSalePrice: null),
      ]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      final products = fixture.controller.products;
      expect(products, hasLength(2));
      expect(products[0].id, 'prd-1');
      expect(products[0].name, 'قمح');
      expect(products[0].defaultSalePricePiastersPerKg, 3000);
      expect(products[0].minimumSalePricePiastersPerKg, 2500);
      expect(products[1].id, 'prd-2');
      expect(products[1].defaultSalePricePiastersPerKg, isNull);
      expect(products[1].minimumSalePricePiastersPerKg, isNull);
      expect(fixture.controller.productName('prd-1'), 'قمح');
      expect(fixture.controller.productName('missing'), 'صنف غير معروف');
    });

    test('empty catalog list loads without crash and stays empty', () async {
      final catalog = _Catalog(const []);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      expect(fixture.controller.isLoading, isFalse);
      expect(fixture.controller.products, isEmpty);
      expect(catalog.readCalls, 1);
    });

    test('catalog error preserves the current error propagation', () async {
      final catalog =
          _Catalog(const [], error: StateError('catalog read failed'));
      final fixture = _fixture(catalog: catalog);

      await expectLater(
        fixture.controller.load(_owner),
        throwsA(
          isA<StateError>().having(
              (error) => error.message, 'message', 'catalog read failed'),
        ),
      );

      expect(fixture.controller.errorMessage, isNull);
      expect(fixture.sales.writeCalls, 0);
      expect(fixture.inventory.writeCalls, 0);
    });

    test('load is read-only and never writes', () async {
      final catalog = _Catalog([_model('prd-1', 'قمح', isActive: true)]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      expect(fixture.sales.writeCalls, 0);
      expect(fixture.inventory.writeCalls, 0);
      expect(catalog.readCalls, 1);
    });

    test('reload reads the catalog again without cache', () async {
      final catalog = _Catalog([_model('prd-1', 'قمح', isActive: true)]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);
      catalog.items = [
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'ذرة', isActive: true),
      ];
      await fixture.controller.load(_owner);

      expect(catalog.readCalls, 2);
      expect(fixture.controller.products, hasLength(2));
    });
  });

  test('SaleController.load no longer depends on the legacy read contract', () {
    final source = File(_controllerPath).readAsStringSync();
    final loadBody = _methodBody(
      source,
      'Future<void> load(AppUser user) async',
    );

    expect(source, contains('ProductCatalogReadRepository'));
    expect(source, isNot(contains('ProductRepository')));
    expect(source, isNot(contains('_productRepository')));
    expect(
      loadBody,
      contains('_productCatalogReadRepository.listProductCatalog('),
    );
    expect(loadBody, contains('includeInactive: false'));
    expect(loadBody, isNot(contains('listProducts(')));
    for (final forbidden in const [
      '.transaction(',
      'createProduct(',
      'updateProduct(',
      'setProductActive(',
      'restoreProductsIntoEmpty(',
      'clearForOwnerDataWipe(',
      'createSale(',
      'cancelSale(',
    ]) {
      expect(loadBody, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

ProductCatalogReadModel _model(
  String id,
  String name, {
  required bool isActive,
  int? defaultSalePrice,
  int? minimumSalePrice,
}) {
  return ProductCatalogReadModel(
    id: id,
    name: name,
    code: null,
    unit: GrainUnit.kilogram,
    isActive: isActive,
    referenceCostPricePiastersPerKg: null,
    defaultSalePricePiastersPerKg: defaultSalePrice,
    minimumSalePricePiastersPerKg: minimumSalePrice,
    notes: null,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

_Fixture _fixture({required _Catalog catalog}) {
  final sales = _Sales(const []);
  final inventory = _Inventory(const {});
  final controller = SaleController(
    saleRepository: sales,
    productCatalogReadRepository: catalog,
    inventoryRepository: inventory,
  );
  return _Fixture(
    controller: controller,
    catalog: catalog,
    sales: sales,
    inventory: inventory,
  );
}

final class _Fixture {
  const _Fixture({
    required this.controller,
    required this.catalog,
    required this.sales,
    required this.inventory,
  });

  final SaleController controller;
  final _Catalog catalog;
  final _Sales sales;
  final _Inventory inventory;
}

final class _Catalog implements ProductCatalogReadRepository {
  _Catalog(this.items, {this.error});

  List<ProductCatalogReadModel> items;
  final Object? error;
  int readCalls = 0;
  final List<bool> includeInactiveValues = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    readCalls++;
    includeInactiveValues.add(includeInactive);
    final failure = error;
    if (failure != null) throw failure;
    final result = includeInactive
        ? items
        : items.where((product) => product.isActive).toList(growable: false);
    return List<ProductCatalogReadModel>.unmodifiable(result);
  }
}

final class _Sales implements SaleRepository {
  _Sales(this.items);

  final List<SaleRecord> items;
  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<List<SaleRecord>> listSales() async {
    readCalls++;
    return List<SaleRecord>.unmodifiable(items);
  }

  @override
  Future<SaleRecord> createSale(SaleDraft draft) {
    writeCalls++;
    throw UnsupportedError('Phase 106U fake is read-only.');
  }

  @override
  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    writeCalls++;
    throw UnsupportedError('Phase 106U fake is read-only.');
  }
}

final class _Inventory implements InventoryRepository {
  _Inventory(this.balances);

  final Map<String, int> balances;
  int balancesCalls = 0;
  int writeCalls = 0;

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    balancesCalls++;
    return Map<String, int>.unmodifiable(balances);
  }

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) {
    writeCalls++;
    throw UnsupportedError('Phase 106U fake is read-only.');
  }

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) {
    writeCalls++;
    throw UnsupportedError('Phase 106U fake is read-only.');
  }

  @override
  Future<List<StockMovement>> listAllMovements() {
    writeCalls++;
    throw UnsupportedError('Phase 106U fake is read-only.');
  }

  @override
  Future<int> currentStockKg(String productId) {
    writeCalls++;
    throw UnsupportedError('Phase 106U fake is read-only.');
  }

  @override
  Future<bool> hasOpeningBalance(String productId) {
    writeCalls++;
    throw UnsupportedError('Phase 106U fake is read-only.');
  }
}

final DateTime _now = DateTime.utc(2026, 7, 30);

final _owner = AppUser(
  id: 'owner-106u',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  return _bracedBody(source, start);
}

String _bracedBody(String source, int start) {
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace.');
}
