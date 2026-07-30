import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

const _servicePath = 'lib/core/inventory/inventory_attention_service.dart';

void main() {
  group('Phase 106E frozen migration structure', () {
    test('selected method uses only the product catalog read contract', () {
      final source = File(_servicePath).readAsStringSync();
      final body = _methodBody(
        source,
        'Future<List<InventoryAttentionItem>> loadAttention() async',
      );

      expect(source, contains('product_catalog_read_repository.dart'));
      expect(
        source,
        contains(
          'final ProductCatalogReadRepository _productCatalogReadRepository;',
        ),
      );
      expect(_occurrences(body, '.listProductCatalog('), 1);
      expect(body, contains('includeInactive: true'));
      expect(source, isNot(contains('product_repository.dart')));
      expect(source, isNot(contains('ProductRepository')));
      expect(body, isNot(contains('.listProducts(')));
    });

    test('merge, classification, ordering, and read-only shape are unchanged',
        () {
      final source = File(_servicePath).readAsStringSync();
      final body = _methodBody(
        source,
        'Future<List<InventoryAttentionItem>> loadAttention() async',
      );

      for (final statement in const [
        '_inventoryRepository.allProductBalancesKg()',
        'balances[product.id] ?? 0',
        'productId: product.id',
        'productName: product.name',
        'isActive: product.isActive',
        'if (type == null) continue',
        'a.type.index.compareTo(b.type.index)',
        'a.quantityKg.compareTo(b.quantityKg)',
        'a.productName.compareTo(b.productName)',
        'a.productId.compareTo(b.productId)',
        'List<InventoryAttentionItem>.unmodifiable(items)',
      ]) {
        expect(body, contains(statement), reason: statement);
      }
      expect(source, contains('static const int lowStockMaximumKg = 5'));
      expect(source, contains('if (quantityKg <= 0)'));
      expect(source, contains('if (quantityKg <= lowStockMaximumKg)'));
      for (final forbidden in const [
        'try {',
        'catch (',
        'createProduct(',
        'updateProduct(',
        'setProductActive(',
        'createMovement(',
        'transaction(',
        'cache',
        'product.code',
        'product.unit',
      ]) {
        expect(body, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('both production dashboard chains receive production catalog wiring',
        () {
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();
      final alerts =
          File('lib/features/dashboard/dashboard_alerts_section.dart')
              .readAsStringSync();
      final service =
          File('lib/core/dashboard/dashboard_service.dart').readAsStringSync();

      expect(
        dashboard,
        contains('AppRepositories.productCatalogReadRepository'),
      );
      expect(alerts, contains('AppRepositories.productCatalogReadRepository'));
      expect(
        service,
        contains(
          'required ProductCatalogReadRepository productCatalogReadRepository',
        ),
      );
      expect(
        service,
        contains(
          'productCatalogReadRepository: productCatalogReadRepository',
        ),
      );
      expect(
        service,
        contains(
          'final ProductCatalogReadRepository _productCatalogReadRepository;',
        ),
      );
      expect(
        service,
        contains('_productCatalogReadRepository.listProductCatalog('),
      );
      expect(service, isNot(contains('_productRepository.listProducts(')));
    });
  });

  group('Phase 106E frozen behavior', () {
    test('includes inactive, defaults missing balance, and preserves ordering',
        () async {
      final catalog = _Catalog([
        _product('low-z', 'Zed', isActive: false),
        _product('normal', 'Normal'),
        _product('out-b', 'Beta'),
        _product('low-a2', 'Alpha'),
        _product('low-a1', 'Alpha'),
        _product('out-a', 'Alpha'),
      ]);
      final inventory = _Inventory({
        'low-z': 5,
        'normal': 6,
        'out-b': 0,
        'low-a2': 1,
        'low-a1': 1,
        'out-a': -2,
      });

      final result = await InventoryAttentionService(
        productCatalogReadRepository: catalog,
        inventoryRepository: inventory,
      ).loadAttention();

      expect(catalog.includeInactive, isTrue);
      expect(result.map((item) => item.productId), [
        'out-a',
        'out-b',
        'low-a1',
        'low-a2',
        'low-z',
      ]);
      expect(result.map((item) => item.quantityKg), [-2, 0, 1, 1, 5]);
      expect(result.last.isActive, isFalse);
      expect(() => result.add(result.first), throwsUnsupportedError);

      catalog.items = [_product('missing', 'Missing', isActive: false)];
      inventory.balances = {};
      final missing = await InventoryAttentionService(
        productCatalogReadRepository: catalog,
        inventoryRepository: inventory,
      ).loadAttention();
      expect(missing.single.quantityKg, 0);
      expect(missing.single.type, InventoryAttentionType.outOfStock);
      expect(missing.single.isActive, isFalse);
    });

    test('every call rereads both sources without a cache', () async {
      final catalog = _Catalog([_product('first', 'First')]);
      final inventory = _Inventory({'first': 6});
      final service = InventoryAttentionService(
        productCatalogReadRepository: catalog,
        inventoryRepository: inventory,
      );

      expect(await service.loadAttention(), isEmpty);
      catalog.items = [_product('second', 'Second')];
      inventory.balances = {'second': 5};
      expect((await service.loadAttention()).single.productId, 'second');
      expect(catalog.readCount, 2);
      expect(inventory.readCount, 2);
    });

    test('catalog errors propagate without retry or inventory fallback',
        () async {
      final error = StateError('catalog failure');
      final catalog = _Catalog(const [], error: error);
      final inventory = _Inventory(const {});
      final service = InventoryAttentionService(
        productCatalogReadRepository: catalog,
        inventoryRepository: inventory,
      );

      await expectLater(service.loadAttention(), throwsA(same(error)));
      expect(catalog.readCount, 1);
      expect(inventory.readCount, 0);
    });
  });

  group('Phase 106E genuine in-memory Drift runtime', () {
    late db.FoundationDatabase database;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
    });

    setUp(() => _clearScenarioRows(database));

    tearDownAll(AppRepositories.close);

    test('production composition reaches the isolated Drift catalog adapter',
        () {
      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
    });

    test('real SQLite rows preserve thresholds, inactivity, and no writes',
        () async {
      await _seedProduct(database, 'out-negative', 'Negative', true, 0);
      await _seedProduct(database, 'out-zero', 'Zero', false, 1);
      await _seedProduct(database, 'low-one', 'One', true, 2);
      await _seedProduct(database, 'low-five', 'Five', true, 3);
      await _seedProduct(database, 'normal-six', 'Six', true, 4);
      await _seedMovement(
        database,
        id: 'movement-negative',
        productId: 'out-negative',
        type: StockMovementType.manualDecrease,
        quantityKg: 2,
      );
      await _seedMovement(
        database,
        id: 'movement-one',
        productId: 'low-one',
        type: StockMovementType.openingBalance,
        quantityKg: 1,
      );
      await _seedMovement(
        database,
        id: 'movement-five',
        productId: 'low-five',
        type: StockMovementType.openingBalance,
        quantityKg: 5,
      );
      await _seedMovement(
        database,
        id: 'movement-six',
        productId: 'normal-six',
        type: StockMovementType.openingBalance,
        quantityKg: 6,
      );
      final beforeProducts = await _productSnapshot(database);
      final beforeMovements = await _movementSnapshot(database);

      final result = await _productionService().loadAttention();

      expect(result.map((item) => item.productId), [
        'out-negative',
        'out-zero',
        'low-one',
        'low-five',
      ]);
      expect(result.map((item) => item.quantityKg), [-2, 0, 1, 5]);
      expect(result[1].isActive, isFalse);
      expect(await _productSnapshot(database), beforeProducts);
      expect(await _movementSnapshot(database), beforeMovements);
    });

    test('a second production load reflects a new SQLite product', () async {
      expect(await _productionService().loadAttention(), isEmpty);

      await _seedProduct(database, 'late-zero', 'Late zero', false, 5);

      final second = await _productionService().loadAttention();
      expect(second.single.productId, 'late-zero');
      expect(second.single.quantityKg, 0);
      expect(second.single.isActive, isFalse);
    });
  });
}

InventoryAttentionService _productionService() => InventoryAttentionService(
      productCatalogReadRepository:
          AppRepositories.productCatalogReadRepository,
      inventoryRepository: AppRepositories.inventoryRepository,
    );

Future<void> _clearScenarioRows(db.FoundationDatabase database) async {
  await database.transaction(() async {
    await database.delete(database.inventoryMovements).go();
    await database.delete(database.products).go();
  });
}

Future<void> _seedProduct(
  db.FoundationDatabase database,
  String id,
  String name,
  bool isActive,
  int order,
) async {
  final timestamp = DateTime.utc(2026, 7, 30, 8, order);
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '$name-$id'.toLowerCase(),
          unit: GrainUnit.kilogram.name,
          isActive: isActive,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
}

Future<void> _seedMovement(
  db.FoundationDatabase database, {
  required String id,
  required String productId,
  required StockMovementType type,
  required int quantityKg,
}) async {
  await database.into(database.inventoryMovements).insert(
        db.InventoryMovementsCompanion.insert(
          id: id,
          productId: productId,
          movementType: type.name,
          quantityKg: quantityKg,
          createdByUserId: 'phase-106e',
          createdAt: DateTime.utc(2026, 7, 30, 9),
        ),
      );
}

Future<List<Object>> _productSnapshot(db.FoundationDatabase database) async {
  final rows = await (database.select(database.products)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  return rows
      .map<Object>(
        (row) => (
          row.id,
          row.name,
          row.code,
          row.unit,
          row.isActive,
          row.createdAt,
          row.updatedAt,
        ),
      )
      .toList(growable: false);
}

Future<List<Object>> _movementSnapshot(db.FoundationDatabase database) async {
  final rows = await (database.select(database.inventoryMovements)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  return rows
      .map<Object>(
        (row) => (
          row.id,
          row.productId,
          row.movementType,
          row.quantityKg,
          row.isVoided,
        ),
      )
      .toList(growable: false);
}

ProductCatalogReadModel _product(
  String id,
  String name, {
  bool isActive = true,
}) =>
    ProductCatalogReadModel(
      id: id,
      name: name,
      code: null,
      unit: GrainUnit.kilogram,
      isActive: isActive,
      referenceCostPricePiastersPerKg: null,
    );

final class _Catalog implements ProductCatalogReadRepository {
  _Catalog(this.items, {this.error});

  List<ProductCatalogReadModel> items;
  final Object? error;
  int readCount = 0;
  bool? includeInactive;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    readCount++;
    this.includeInactive = includeInactive;
    final failure = error;
    if (failure != null) throw failure;
    return List<ProductCatalogReadModel>.unmodifiable(items);
  }
}

final class _Inventory implements InventoryRepository {
  _Inventory(this.balances);

  Map<String, int> balances;
  int readCount = 0;

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    readCount++;
    return Map<String, int>.unmodifiable(balances);
  }

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

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace for $declaration.');
}

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;
