import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

const _baseline = 'ad56678ff58334d46b76dfa3757650b1aa718d70';
const _phase106gCommit = '4e9af2034aca1694545027a50336ad15de46f2bf';
const _servicePath = 'lib/core/dashboard/dashboard_service.dart';
const _screenPath = 'lib/features/dashboard/dashboard_screen.dart';

void main() {
  group('Phase 106G migration architecture', () {
    test('DashboardService depends only on the frozen product read contract',
        () {
      final source = File(_servicePath).readAsStringSync();
      final body = _methodBody(source, 'Future<DashboardData> load() async');

      expect(source, contains('product_catalog_read_repository.dart'));
      expect(source, isNot(contains('product_repository.dart')));
      expect(source, isNot(contains('ProductRepository')));
      expect(
        source,
        contains(
          'final ProductCatalogReadRepository _productCatalogReadRepository;',
        ),
      );
      expect(_occurrences(body, '.listProductCatalog('), 1);
      expect(body, contains('includeInactive: true'));
      expect(body, isNot(contains('.listProducts(')));
    });

    test('production dashboard passes only the catalog read repository', () {
      final source = File(_screenPath).readAsStringSync();
      final construction = _constructorCall(source, 'DashboardService(');

      expect(
        construction,
        contains('AppRepositories.productCatalogReadRepository'),
      );
      expect(
        construction,
        isNot(contains('AppRepositories.productRepository')),
      );
      expect(source, contains('_controller.load();'));
    });

    test('prior three consumers remain on the catalog read contract', () {
      final guidance = _classBody(
        File(_screenPath).readAsStringSync(),
        'class DashboardGuidanceState',
      );
      final attention = File(
        'lib/core/inventory/inventory_attention_service.dart',
      ).readAsStringSync();
      final history = File(
        'lib/core/documents/document_history.dart',
      ).readAsStringSync();

      expect(guidance, contains('.listProductCatalog(includeInactive: true)'));
      expect(attention, contains('.listProductCatalog('));
      expect(attention, isNot(contains('ProductRepository')));
      expect(history, contains('.listProductCatalog('));
      expect(history, isNot(contains('ProductRepository')));
    });

    test('production scope is exact and frozen persistence remains unchanged',
        () {
      final changedProduction = _git([
        'diff',
        '--name-only',
        _baseline,
        _phase106gCommit,
        '--',
        'lib',
      ])
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceAll('\\', '/'))
          .toSet();

      expect(changedProduction, {_servicePath, _screenPath});
      for (final path in const [
        'lib/core/catalog/product_catalog_read_repository.dart',
        'lib/core/catalog/drift_product_catalog_read_repository.dart',
        'lib/core/persistence/foundation_database.dart',
        'lib/core/persistence/foundation_database.g.dart',
        'lib/core/inventory/inventory_attention_service.dart',
        'lib/core/documents/document_history.dart',
      ]) {
        expect(
          _gitExitCode([
            'diff',
            '--quiet',
            _baseline,
            _phase106gCommit,
            '--',
            path,
          ]),
          0,
          reason: path,
        );
      }
    });

    test('wheat, stock, hasData, and read-only source shape are unchanged', () {
      final body = _methodBody(
        File(_servicePath).readAsStringSync(),
        'Future<DashboardData> load() async',
      );

      for (final statement in const [
        'p.name.contains(',
        '.toList()',
        'wheatProduct.first.id',
        'balances[wheatProduct.first.id] ?? 0',
        'products.isNotEmpty || allSales.isNotEmpty',
        '_inventoryRepository.allProductBalancesKg()',
        '_inventoryAttentionService.loadAttention()',
      ]) {
        expect(body, contains(statement), reason: statement);
      }
      for (final forbidden in const [
        '.sort(',
        '.toSet(',
        'product.code',
        'createProduct(',
        'updateProduct(',
        'setProductActive(',
        'createMovement(',
        'transaction(',
        'try {',
        'catch (',
        'cache',
        'retry',
      ]) {
        expect(body, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Phase 106G genuine in-memory Drift runtime', () {
    late db.FoundationDatabase database;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
    });

    setUp(() => _clearScenarioRows(database));

    tearDownAll(AppRepositories.close);

    test('production composition supplies the real Drift catalog adapter', () {
      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
    });

    test('inactive first wheat match wins in SQLite order without writes',
        () async {
      await _seedProduct(
        database,
        id: 'inactive-first',
        name: 'wheat inactive',
        isActive: false,
        order: 1,
      );
      await _seedProduct(
        database,
        id: 'active-second',
        name: 'wheat active',
        isActive: true,
        order: 2,
      );
      await _seedProduct(
        database,
        id: 'other',
        name: 'Barley',
        isActive: true,
        order: 3,
      );
      await _seedMovement(database, 'inactive-first', 7, 1);
      await _seedMovement(database, 'active-second', 11, 2);
      await _seedMovement(database, 'other', 20, 3);
      final beforeProducts = await _productSnapshot(database);
      final beforeMovements = await _movementSnapshot(database);

      final data = await _productionService().load();

      expect(data.wheatStockKg, 7);
      expect(data.totalStockKg, 38);
      expect(data.hasData, isTrue);
      expect(data.todaySalesQirsh, 0);
      expect(data.todayExpensesQirsh, 0);
      expect(data.customerReceivablesQirsh, 0);
      expect(data.supplierPayablesQirsh, 0);
      expect(await _productSnapshot(database), beforeProducts);
      expect(await _movementSnapshot(database), beforeMovements);
    });

    test('code and id are not wheat fallbacks and balances are not mixed',
        () async {
      await _seedProduct(
        database,
        id: 'wheat-id',
        name: 'Barley',
        code: 'wheat-code',
        isActive: true,
        order: 1,
      );
      await _seedProduct(
        database,
        id: 'rye',
        name: 'Rye',
        isActive: true,
        order: 2,
      );
      await _seedMovement(database, 'wheat-id', 12, 1);
      await _seedMovement(database, 'rye', 30, 2);

      final data = await _productionService().load();

      expect(data.wheatStockKg, 0);
      expect(data.totalStockKg, 42);
      expect(data.hasData, isTrue);
    });

    test('missing stock, no match, and an empty table preserve zero semantics',
        () async {
      await _seedProduct(
        database,
        id: 'wheat-missing-stock',
        name: 'wheat no balance',
        isActive: true,
        order: 1,
      );
      final missingStock = await _productionService().load();
      expect(missingStock.wheatStockKg, 0);
      expect(missingStock.totalStockKg, 0);
      expect(missingStock.hasData, isTrue);

      await _clearScenarioRows(database);
      await _seedProduct(
        database,
        id: 'only-barley',
        name: 'Barley',
        isActive: false,
        order: 1,
      );
      final noMatch = await _productionService().load();
      expect(noMatch.wheatStockKg, 0);
      expect(noMatch.hasData, isTrue);

      await _clearScenarioRows(database);
      final empty = await _productionService().load();
      expect(empty.wheatStockKg, 0);
      expect(empty.totalStockKg, 0);
      expect(empty.stockAlertCount, 0);
      expect(empty.hasData, isFalse);
    });

    test('each load rereads inserted and updated SQLite rows', () async {
      expect((await _productionService().load()).hasData, isFalse);

      await _seedProduct(
        database,
        id: 'changing',
        name: 'wheat changing',
        isActive: true,
        order: 1,
      );
      await _seedMovement(database, 'changing', 4, 1);
      final inserted = await _productionService().load();
      expect(inserted.wheatStockKg, 4);
      expect(inserted.hasData, isTrue);

      await (database.update(database.products)
            ..where((row) => row.id.equals('changing')))
          .write(
        db.ProductsCompanion(
          name: const Value('Barley'),
          normalizedName: const Value('barley'),
          updatedAt: Value(DateTime.utc(2026, 7, 30, 12)),
        ),
      );
      final updated = await _productionService().load();
      expect(updated.wheatStockKg, 0);
      expect(updated.totalStockKg, 4);
      expect(updated.hasData, isTrue);
    });

    test('catalog and inventory errors propagate once without fallback',
        () async {
      final catalogError = StateError('catalog failure');
      final catalog = _ThrowingCatalog(catalogError);
      await expectLater(
        _service(catalogRepository: catalog).load(),
        throwsA(same(catalogError)),
      );
      expect(catalog.readCount, 1);

      final inventoryError = StateError('inventory failure');
      final inventory = _ThrowingInventory(inventoryError);
      final fixedCatalog = _FixedCatalog([
        _product('wheat', 'wheat controlled', isActive: false),
      ]);
      await expectLater(
        _service(
          catalogRepository: fixedCatalog,
          inventoryRepository: inventory,
        ).load(),
        throwsA(same(inventoryError)),
      );
      expect(fixedCatalog.readCount, 1);
      expect(fixedCatalog.includeInactiveValues, [true]);
      expect(inventory.readCount, 1);
    });
  });
}

DashboardService _productionService() => _service();

DashboardService _service({
  ProductCatalogReadRepository? catalogRepository,
  InventoryRepository? inventoryRepository,
}) =>
    DashboardService(
      saleRepository: AppRepositories.saleRepository,
      inventoryRepository:
          inventoryRepository ?? AppRepositories.inventoryRepository,
      productCatalogReadRepository:
          catalogRepository ?? AppRepositories.productCatalogReadRepository,
      expenseRepository: AppRepositories.expenseRepository,
      customerAccountRepository: AppRepositories.customerAccountRepository,
      financialAccountRepository: AppRepositories.financialAccountRepository,
      supplierAccountRepository: AppRepositories.supplierAccountRepository,
    );

Future<void> _clearScenarioRows(db.FoundationDatabase database) async {
  await database.transaction(() async {
    await database.delete(database.inventoryMovements).go();
    await database.delete(database.products).go();
  });
}

Future<void> _seedProduct(
  db.FoundationDatabase database, {
  required String id,
  required String name,
  required bool isActive,
  required int order,
  String? code,
}) async {
  final timestamp = DateTime.utc(2026, 7, 30, 8, order);
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '$name-$id'.toLowerCase(),
          code: Value(code),
          unit: GrainUnit.kilogram.name,
          isActive: isActive,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
}

Future<void> _seedMovement(
  db.FoundationDatabase database,
  String productId,
  int quantityKg,
  int order,
) async {
  await database.into(database.inventoryMovements).insert(
        db.InventoryMovementsCompanion.insert(
          id: 'movement-$productId',
          productId: productId,
          movementType: StockMovementType.openingBalance.name,
          quantityKg: quantityKg,
          createdByUserId: 'phase-106g',
          createdAt: DateTime.utc(2026, 7, 30, 9, order),
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
      defaultSalePricePiastersPerKg: null,
      minimumSalePricePiastersPerKg: null,
      notes: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

class _FixedCatalog implements ProductCatalogReadRepository {
  _FixedCatalog(this.items);

  final List<ProductCatalogReadModel> items;
  final List<bool> includeInactiveValues = [];
  int readCount = 0;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    readCount++;
    includeInactiveValues.add(includeInactive);
    return List<ProductCatalogReadModel>.unmodifiable(items);
  }
}

final class _ThrowingCatalog implements ProductCatalogReadRepository {
  _ThrowingCatalog(this.error);

  final Object error;
  int readCount = 0;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    readCount++;
    throw error;
  }
}

final class _ThrowingInventory implements InventoryRepository {
  _ThrowingInventory(this.error);

  final Object error;
  int readCount = 0;

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    readCount++;
    throw error;
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

String _git(List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    runInShell: false,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

int _gitExitCode(List<String> arguments) =>
    Process.runSync('git', arguments, runInShell: false).exitCode;

String _classBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  return _bracedBody(source, start);
}

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  return _bracedBody(source, start);
}

String _constructorCall(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing construction: $declaration');
  var depth = 0;
  for (var index = source.indexOf('(', start); index < source.length; index++) {
    if (source[index] == '(') depth++;
    if (source[index] == ')') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing parenthesis: $declaration');
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

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;
