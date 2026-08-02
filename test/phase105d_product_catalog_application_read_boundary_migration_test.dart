import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

const _phase105dCommit = 'ea804cb';

void main() {
  test('selected boundary depends on the frozen interface only', () async {
    final ProductCatalogReadRepository catalog =
        _CatalogFake([const <ProductCatalogReadModel>[]]);
    final repository = _history(catalog: catalog);

    expect(await repository.listHistory(), isEmpty);

    final source = _read('lib/core/documents/document_history.dart');
    expect(source, contains('ProductCatalogReadRepository'));
    expect(source, contains('listProductCatalog('));
    expect(source, isNot(contains('product_repository.dart')));
    expect(source, isNot(contains('DriftProductCatalogReadRepository')));
  });

  test('successful load maps catalog identity and preserves frozen values',
      () async {
    final product = ProductCatalogReadModel(
      id: 'prd-1722261600000000-41',
      name: 'Wheat',
      code: 'WH-41',
      unit: GrainUnit.ton,
      isActive: false,
      referenceCostPricePiastersPerKg: null,
      defaultSalePricePiastersPerKg: null,
      minimumSalePricePiastersPerKg: null,
      notes: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final catalog = _CatalogFake([
      [product],
    ]);
    final repository = _history(
      catalog: catalog,
      purchases: [_purchase(productId: product.id)],
    );

    final result = await repository.listHistory();

    expect(result.single.productId, product.id);
    expect(result.single.productName, product.name);
    expect(product.code, 'WH-41');
    expect(product.unit, GrainUnit.ton);
    expect(product.isActive, isFalse);
  });

  test('consumer requests inactive products to preserve history names',
      () async {
    final catalog = _CatalogFake([const <ProductCatalogReadModel>[]]);

    await _history(catalog: catalog).listHistory();

    expect(catalog.receivedIncludeInactive, [true]);
  });

  test('empty catalog and empty document stores return empty history',
      () async {
    final repository = _history(
      catalog: _CatalogFake([const <ProductCatalogReadModel>[]]),
    );

    expect(await repository.listHistory(), isEmpty);
  });

  test('existing failure behavior propagates without reads or side effects',
      () async {
    final catalog = _CatalogFake([StateError('catalog unavailable')]);
    final purchases = _Purchases(const []);
    final sales = _Sales(const []);
    final inventory = _Inventory(const []);
    final repository = LocalDocumentHistoryRepository(
      purchaseRepository: purchases,
      saleRepository: sales,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
    );

    await expectLater(repository.listHistory(), throwsStateError);

    expect(purchases.readCount, 0);
    expect(sales.readCount, 0);
    expect(inventory.readCount, 0);
  });

  test('a failed load can be retried without cached or duplicated history',
      () async {
    final product = ProductCatalogReadModel(
      id: 'prd-retry',
      name: 'Retry product',
      code: null,
      unit: GrainUnit.kilogram,
      isActive: true,
      referenceCostPricePiastersPerKg: null,
      defaultSalePricePiastersPerKg: null,
      minimumSalePricePiastersPerKg: null,
      notes: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final catalog = _CatalogFake([
      StateError('first load fails'),
      [product],
    ]);
    final repository = _history(
      catalog: catalog,
      purchases: [_purchase(productId: product.id)],
    );

    await expectLater(repository.listHistory(), throwsStateError);
    final result = await repository.listHistory();

    expect(result, hasLength(1));
    expect(result.single.productName, product.name);
    expect(catalog.receivedIncludeInactive, [true, true]);
  });

  test('catalog ordering is not changed inside the migrated lookup method',
      () async {
    final catalog = _CatalogFake([
      [
        ProductCatalogReadModel(
          id: 'prd-z',
          name: 'Zed',
          code: null,
          unit: GrainUnit.ton,
          isActive: true,
          referenceCostPricePiastersPerKg: null,
          defaultSalePricePiastersPerKg: null,
          minimumSalePricePiastersPerKg: null,
          notes: null,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        ProductCatalogReadModel(
          id: 'prd-a',
          name: 'Alpha',
          code: null,
          unit: GrainUnit.kilogram,
          isActive: true,
          referenceCostPricePiastersPerKg: null,
          defaultSalePricePiastersPerKg: null,
          minimumSalePricePiastersPerKg: null,
          notes: null,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ],
    ]);
    final repository = _history(
      catalog: catalog,
      purchases: [
        _purchase(productId: 'prd-z', id: 'purchase-z'),
        _purchase(productId: 'prd-a', id: 'purchase-a'),
      ],
    );

    final result = await repository.listHistory();

    expect(result.map((entry) => entry.productName).toSet(), {'Zed', 'Alpha'});
    final lookupMethod = _between(
      _read('lib/core/documents/document_history.dart'),
      'Future<Map<String, String>> _productNamesById()',
      'Future<List<DocumentHistoryEntry>> _purchaseEntries',
    );
    expect(lookupMethod, isNot(contains('.sort(')));
  });

  test('migrated boundary has no direct database or concrete adapter import',
      () {
    final source = _read('lib/core/documents/document_history.dart');

    expect(source, isNot(contains("package:drift/drift.dart")));
    expect(source, isNot(contains('FoundationDatabase')));
    expect(source, isNot(contains('DatabaseHelper')));
    expect(
        source, isNot(contains('drift_product_catalog_read_repository.dart')));
    expect(source, isNot(contains('select(')));
  });

  test('no UI source depends on the frozen catalog contract or adapter', () {
    expect(
      Process.runSync(
        'git',
        [
          'grep',
          '-E',
          'ProductCatalogReadRepository|DriftProductCatalogReadRepository',
          _phase105dCommit,
          '--',
          'lib/features',
        ],
        runInShell: false,
      ).exitCode,
      1,
    );
  });

  test('the five-field frozen contract and method remain unchanged', () {
    final source =
        _read('lib/core/catalog/product_catalog_read_repository.dart');

    expect(RegExp(r'final String id;').allMatches(source), hasLength(1));
    expect(RegExp(r'final String name;').allMatches(source), hasLength(1));
    expect(RegExp(r'final String\? code;').allMatches(source), hasLength(1));
    expect(RegExp(r'final GrainUnit unit;').allMatches(source), hasLength(1));
    expect(RegExp(r'final bool isActive;').allMatches(source), hasLength(1));
    expect(
      source,
      contains(
        'Future<List<ProductCatalogReadModel>> listProductCatalog({\n'
        '    required bool includeInactive,\n'
        '  });',
      ),
    );
  });

  test('production composition supplies the Phase 105C Drift adapter',
      () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
      databaseFactory: () async => database,
    );
    addTearDown(AppRepositories.close);

    expect(
      AppRepositories.productCatalogReadRepository,
      isA<DriftProductCatalogReadRepository>(),
    );
    expect(AppRepositories.documentHistoryRepository,
        isA<LocalDocumentHistoryRepository>());
  });
}

LocalDocumentHistoryRepository _history({
  required ProductCatalogReadRepository catalog,
  List<PurchaseIntake> purchases = const [],
}) =>
    LocalDocumentHistoryRepository(
      purchaseRepository: _Purchases(purchases),
      saleRepository: _Sales(const []),
      productCatalogReadRepository: catalog,
      inventoryRepository: _Inventory(const []),
    );

PurchaseIntake _purchase({
  required String productId,
  String id = 'purchase-1',
}) =>
    PurchaseIntake(
      id: id,
      supplierId: 'supplier-1',
      productId: productId,
      quantityKg: 10,
      entryUnit: GrainUnit.kilogram,
      unitPricePiastersPerKg: 100,
      totalAmountPiasters: 1000,
      createdByUserId: 'owner-1',
      createdAt: DateTime.utc(2026, 7, 29),
      stockMovementId: 'movement-$id',
    );

final class _CatalogFake implements ProductCatalogReadRepository {
  _CatalogFake(this._responses);

  final List<Object> _responses;
  final List<bool> receivedIncludeInactive = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    receivedIncludeInactive.add(includeInactive);
    final response = _responses.removeAt(0);
    if (response is Error) throw response;
    if (response is Exception) throw response;
    return response as List<ProductCatalogReadModel>;
  }
}

final class _Purchases implements PurchaseRepository {
  _Purchases(this._values);

  final List<PurchaseIntake> _values;
  int readCount = 0;

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    readCount++;
    return _values;
  }

  @override
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft) =>
      throw UnimplementedError();

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) =>
      throw UnimplementedError();
}

final class _Sales implements SaleRepository {
  _Sales(this._values);

  final List<SaleRecord> _values;
  int readCount = 0;

  @override
  Future<List<SaleRecord>> listSales() async {
    readCount++;
    return _values;
  }

  @override
  Future<SaleRecord> createSale(SaleDraft draft) => throw UnimplementedError();

  @override
  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) =>
      throw UnimplementedError();
}

final class _Inventory implements InventoryRepository {
  _Inventory(this._movements);

  final List<StockMovement> _movements;
  int readCount = 0;

  @override
  Future<List<StockMovement>> listAllMovements() async {
    readCount++;
    return _movements;
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async =>
      const {};

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) =>
      throw UnimplementedError();

  @override
  Future<int> currentStockKg(String productId) async => 0;

  @override
  Future<bool> hasOpeningBalance(String productId) async => false;

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) async =>
      const [];
}

String _read(String path) => File(path).readAsStringSync();

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex);
  if (startIndex < 0 || endIndex < 0) {
    throw StateError('Expected source boundaries were not found.');
  }
  return source.substring(startIndex, endIndex);
}
