import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

const _repositoryPath = 'lib/core/inventory/drift_inventory_repository.dart';

void main() {
  group('Phase 106M inventory balance enumeration runtime migration', () {
    test(
        'real Drift catalog enumerates exact balances without legacy reads or writes',
        () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final time = DateTime.utc(2026, 7, 30, 8);
      await _seedProduct(
        fixture.database,
        id: 'prd-phase106m-alpha',
        name: 'Alpha wheat',
        isActive: true,
        referenceCost: 12345,
        createdAt: time,
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-phase106m-002-beta',
        name: 'Archived barley',
        isActive: false,
        referenceCost: null,
        createdAt: time.add(const Duration(hours: 1)),
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-phase106m-no-movements',
        name: 'No movements',
        isActive: true,
        referenceCost: null,
        createdAt: time.add(const Duration(hours: 2)),
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-phase106m-zero',
        name: 'Zero balance',
        isActive: true,
        referenceCost: 99999,
        createdAt: time.add(const Duration(hours: 3)),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-alpha-open',
        productId: 'prd-phase106m-alpha',
        type: StockMovementType.openingBalance,
        quantityKg: 10,
        createdAt: time,
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-alpha-sale',
        productId: 'prd-phase106m-alpha',
        type: StockMovementType.sale,
        quantityKg: 3,
        createdAt: time.add(const Duration(minutes: 1)),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-alpha-voided',
        productId: 'prd-phase106m-alpha',
        type: StockMovementType.sale,
        quantityKg: 99,
        createdAt: time.add(const Duration(minutes: 2)),
        isVoided: true,
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-beta-increase',
        productId: 'prd-phase106m-002-beta',
        type: StockMovementType.manualIncrease,
        quantityKg: 4,
        createdAt: time.add(const Duration(hours: 1)),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-zero-increase',
        productId: 'prd-phase106m-zero',
        type: StockMovementType.manualIncrease,
        quantityKg: 5,
        createdAt: time.add(const Duration(hours: 3)),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-zero-decrease',
        productId: 'prd-phase106m-zero',
        type: StockMovementType.manualDecrease,
        quantityKg: 5,
        createdAt: time.add(const Duration(hours: 3, minutes: 1)),
      );
      final productsBefore = await _productSnapshot(fixture.database);
      final movementsBefore = await _movementSnapshot(fixture.database);

      final balances = await fixture.inventory.allProductBalancesKg();

      expect(balances, {
        'prd-phase106m-alpha': 7,
        'prd-phase106m-002-beta': 4,
        'prd-phase106m-no-movements': 0,
        'prd-phase106m-zero': 0,
      });
      expect(balances.keys, [
        'prd-phase106m-alpha',
        'prd-phase106m-002-beta',
        'prd-phase106m-no-movements',
        'prd-phase106m-zero',
      ]);
      expect(fixture.legacyProducts.listProductCalls, 0);
      expect(await _productSnapshot(fixture.database), productsBefore);
      expect(await _movementSnapshot(fixture.database), movementsBefore);
      expect(() => balances['new-id'] = 1, throwsUnsupportedError);
    });

    test('active-only filtering preserves the existing optional semantics',
        () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final time = DateTime.utc(2026, 7, 30, 9);
      await _seedProduct(
        fixture.database,
        id: 'prd-phase106m-active',
        name: 'Active',
        isActive: true,
        referenceCost: null,
        createdAt: time,
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-phase106m-inactive',
        name: 'Inactive',
        isActive: false,
        referenceCost: 12345,
        createdAt: time.add(const Duration(minutes: 1)),
      );

      expect(await fixture.inventory.allProductBalancesKg(), {
        'prd-phase106m-active': 0,
        'prd-phase106m-inactive': 0,
      });
      expect(
        await fixture.inventory.allProductBalancesKg(activeProductsOnly: true),
        {'prd-phase106m-active': 0},
      );
      expect(fixture.legacyProducts.listProductCalls, 0);
    });

    test('a later ledger row is visible on the next uncached read', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final time = DateTime.utc(2026, 7, 30, 10);
      await _seedProduct(
        fixture.database,
        id: 'prd-phase106m-fresh',
        name: 'Fresh balance',
        isActive: true,
        referenceCost: null,
        createdAt: time,
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-fresh-first',
        productId: 'prd-phase106m-fresh',
        type: StockMovementType.manualIncrease,
        quantityKg: 8,
        createdAt: time,
      );

      expect(await fixture.inventory.allProductBalancesKg(), {
        'prd-phase106m-fresh': 8,
      });
      await _seedMovement(
        fixture.database,
        id: 'mov-fresh-second',
        productId: 'prd-phase106m-fresh',
        type: StockMovementType.sale,
        quantityKg: 3,
        createdAt: time.add(const Duration(minutes: 1)),
      );

      expect(await fixture.inventory.allProductBalancesKg(), {
        'prd-phase106m-fresh': 5,
      });
      expect(fixture.legacyProducts.listProductCalls, 0);
    });

    test('an empty SQLite catalog returns an empty immutable map', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final before = await _movementSnapshot(fixture.database);

      final balances = await fixture.inventory.allProductBalancesKg();

      expect(balances, isEmpty);
      expect(() => balances['synthetic'] = 0, throwsUnsupportedError);
      expect(await _movementSnapshot(fixture.database), before);
      expect(fixture.legacyProducts.listProductCalls, 0);
    });
  });

  test('production composition uses the real Drift catalog adapter', () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
      databaseFactory: () async => database,
    );
    addTearDown(AppRepositories.close);
    final time = DateTime.utc(2026, 7, 30, 11);
    await _seedProduct(
      database,
      id: 'prd-phase106m-production',
      name: 'Production composition sentinel',
      isActive: false,
      referenceCost: 12345,
      defaultSalePrice: 3000,
      minimumSalePrice: 2500,
      createdAt: time,
    );

    expect(AppRepositories.database, same(database));
    expect(
      AppRepositories.productCatalogReadRepository,
      isA<DriftProductCatalogReadRepository>(),
    );
    expect(
      AppRepositories.inventoryRepository,
      isA<DriftInventoryRepository>(),
    );
    expect(await AppRepositories.inventoryRepository.allProductBalancesKg(), {
      'prd-phase106m-production': 0,
    });
    final catalog = await AppRepositories.productCatalogReadRepository
        .listProductCatalog(includeInactive: true);
    expect(catalog.single.id, 'prd-phase106m-production');
    expect(catalog.single.defaultSalePricePiastersPerKg, 3000);
    expect(catalog.single.minimumSalePricePiastersPerKg, 2500);
  });

  test('source guard preserves balance enumeration after lookup migration', () {
    final source = File(_repositoryPath).readAsStringSync();
    final balancesBody = _methodBody(
      source,
      'Future<Map<String, int>> allProductBalancesKg(',
    );
    final currentStockBody = _methodBody(
      source,
      'Future<int> currentStockKg(String productId) async',
    );
    final lookupBody = _methodBody(
      source,
      'Future<ProductCatalogReadModel?> _findProductById(String id) async',
    );

    expect(source, isNot(contains('required ProductRepository ')));
    expect(source, isNot(contains('final ProductRepository ')));
    expect(
      source,
      contains('final ProductCatalogReadRepository '
          '_productCatalogReadRepository;'),
    );
    expect(
      balancesBody,
      contains('_productCatalogReadRepository.listProductCatalog('),
    );
    expect(balancesBody, contains('includeInactive: !activeProductsOnly'));
    expect(balancesBody, isNot(contains('_productRepository')));
    expect(balancesBody, isNot(contains('currentStockKg(')));
    expect(balancesBody, isNot(contains('try {')));
    expect(balancesBody, isNot(contains('catch (')));
    expect(currentStockBody, contains('_findProductById(productId)'));
    expect(
      lookupBody,
      contains('_productCatalogReadRepository.listProductCatalog('),
    );
    expect(lookupBody, contains('includeInactive: true'));
    expect(source, isNot(contains('_productRepository')));
  });
}

final class _Fixture {
  _Fixture._(
    this.database,
    this.legacyProducts,
    this.inventory,
  );

  factory _Fixture.open() {
    final database = openInMemoryTestDatabase();
    final legacyProducts = _ThrowingProductRepository();
    return _Fixture._(
      database,
      legacyProducts,
      DriftInventoryRepository(
        database,
        productCatalogReadRepository:
            DriftProductCatalogReadRepository(database),
      ),
    );
  }

  final db.FoundationDatabase database;
  final _ThrowingProductRepository legacyProducts;
  final DriftInventoryRepository inventory;

  Future<void> close() => database.close();
}

final class _ThrowingProductRepository implements ProductRepository {
  int listProductCalls = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) {
    listProductCalls++;
    throw StateError('Phase 106M legacy listProducts sentinel');
  }

  @override
  Future<Product> createProduct(ProductDraft draft) =>
      throw UnsupportedError('Phase 106M read-only legacy sentinel');

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) =>
      throw UnsupportedError('Phase 106M read-only legacy sentinel');

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) =>
      throw UnsupportedError('Phase 106M read-only legacy sentinel');
}

Future<void> _seedProduct(
  db.FoundationDatabase database, {
  required String id,
  required String name,
  required bool isActive,
  required int? referenceCost,
  required DateTime createdAt,
  int? defaultSalePrice,
  int? minimumSalePrice,
}) async {
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '$name-$id'.toLowerCase(),
          code: Value('code-$id'),
          normalizedCode: Value('code-$id'.toLowerCase()),
          unit: GrainUnit.kilogram.name,
          isActive: isActive,
          referenceCostPricePiastersPerKg: Value(referenceCost),
          defaultSalePricePiastersPerKg: Value(defaultSalePrice),
          minimumSalePricePiastersPerKg: Value(minimumSalePrice),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
}

Future<void> _seedMovement(
  db.FoundationDatabase database, {
  required String id,
  required String productId,
  required StockMovementType type,
  required int quantityKg,
  required DateTime createdAt,
  bool isVoided = false,
}) async {
  await database.into(database.inventoryMovements).insert(
        db.InventoryMovementsCompanion.insert(
          id: id,
          productId: productId,
          movementType: type.name,
          quantityKg: quantityKg,
          createdByUserId: 'phase-106m',
          createdAt: createdAt,
          isVoided: Value(isVoided),
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
          row.normalizedName,
          row.code,
          row.normalizedCode,
          row.unit,
          row.isActive,
          row.defaultSalePricePiastersPerKg,
          row.minimumSalePricePiastersPerKg,
          row.referenceCostPricePiastersPerKg,
          row.notes,
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
          row.createdByUserId,
          row.createdAt,
          row.note,
          row.isVoided,
          row.reversedMovementId,
          row.originalDocumentId,
        ),
      )
      .toList(growable: false);
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) throw StateError('Missing method: $signature');
  final asyncMarker = source.indexOf('async {', start);
  if (asyncMarker < 0) throw StateError('Missing async body: $signature');
  final openBrace = asyncMarker + 'async '.length;
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace for $signature');
}
