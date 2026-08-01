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
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

const _phase106fCommit = 'ad56678ff58334d46b76dfa3757650b1aa718d70';
const _phase106gCommit = '4e9af2034aca1694545027a50336ad15de46f2bf';
const _phase106hCommit = '812face11ab3b63f2252402ec0cb8960cc4af563';
const _servicePath = 'lib/core/dashboard/dashboard_service.dart';
const _controllerPath = 'lib/core/dashboard/dashboard_controller.dart';
const _screenPath = 'lib/features/dashboard/dashboard_screen.dart';
const _compositionPath = 'lib/app/app_repositories.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

const _historicalTests = {
  'test/competition04_dashboard_readiness_test.dart',
  'test/phase106e_inventory_attention_product_catalog_read_migration_test.dart',
  'test/phase106f_next_product_read_consumer_target_discovery_freeze_test.dart',
  'test/phase36_supplier_accounts_dashboard_test.dart',
  'test/phase36e_supplier_payment_ui_test.dart',
  'test/phase36g_ui_clarity_cancellation_safety_test.dart',
  'test/phase37c_dashboard_labels_test.dart',
};

void main() {
  group('Phase 106H architecture acceptance and freeze', () {
    test('Phase 106G production scope is exact and Phase 106H changes no lib',
        () {
      expect(_git(['rev-parse', _phase106gCommit]).trim(), _phase106gCommit);
      expect(
        _changedFiles(_phase106fCommit, _phase106gCommit, 'lib'),
        {_servicePath, _screenPath},
      );
      expect(_changedFiles(_phase106gCommit, _phase106hCommit, 'lib'), isEmpty);

      for (final path in const [
        'lib/core/catalog/product_catalog_read_repository.dart',
        _adapterPath,
        'lib/core/persistence/foundation_database.dart',
        'lib/core/persistence/foundation_database.g.dart',
        'lib/core/inventory/inventory_repository.dart',
        'lib/core/sales/sale_repository.dart',
      ]) {
        expect(
          _gitExitCode([
            'diff',
            '--quiet',
            _phase106gCommit,
            _phase106hCommit,
            '--',
            path,
          ]),
          0,
          reason: path,
        );
      }
    });

    test('DashboardService is frozen on the catalog read contract', () {
      final source = File(_servicePath).readAsStringSync();
      final body = _bracedBody(
        source,
        source.indexOf('Future<DashboardData> load() async'),
      );

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

      for (final statement in const [
        "p.name.contains('قمح')",
        "p.name.contains(' Wheat')",
        "p.name.contains('wheat')",
        'wheatProduct.first.id',
        'balances[wheatProduct.first.id] ?? 0',
        '_inventoryRepository.allProductBalancesKg()',
        'products.isNotEmpty || allSales.isNotEmpty',
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

    test('protected production path reaches the real ordered Drift adapter',
        () {
      final screen = File(_screenPath).readAsStringSync();
      final controller = File(_controllerPath).readAsStringSync();
      final composition = File(_compositionPath).readAsStringSync();
      final adapter = File(_adapterPath).readAsStringSync();
      final construction = _constructorCall(screen, 'DashboardService(');

      expect(screen, contains('void didChangeDependencies()'));
      expect(screen, contains('_controller.load();'));
      expect(controller, contains('_loadData = loadData ?? service!.load'));
      expect(controller, contains('_data = await _loadData();'));
      expect(
        construction,
        contains('AppRepositories.productCatalogReadRepository'),
      );
      expect(
        construction,
        isNot(contains('AppRepositories.productRepository')),
      );
      expect(
        composition,
        contains(
          '_productCatalogReadRepository = DriftProductCatalogReadRepository(database)',
        ),
      );
      expect(adapter, contains('OrderingTerm.asc(products.createdAt)'));
      expect(adapter, contains('OrderingTerm.asc(products.id)'));
      expect(adapter, contains('final rows = await query.get();'));
    });

    test('the seven historical tests were not weakened', () {
      final changedExistingTests = _changedFiles(
        _phase106fCommit,
        _phase106gCommit,
        'test',
      )..remove(
          'test/phase106g_genuine_runtime_dashboard_service_product_catalog_read_integration_test.dart',
        );
      expect(changedExistingTests, _historicalTests);

      for (final path in _historicalTests) {
        final before = _git(['show', '$_phase106fCommit:$path']);
        final after = _git(['show', '$_phase106gCommit:$path']);
        expect(
          _testDeclarationCount(after),
          _testDeclarationCount(before),
          reason: path,
        );
        expect(
          _occurrences(after, 'expect('),
          greaterThanOrEqualTo(_occurrences(before, 'expect(')),
          reason: path,
        );
        expect(after, isNot(contains('skip: true')), reason: path);
      }
    });
  });

  group('Phase 106H genuine in-memory Drift acceptance', () {
    late db.FoundationDatabase database;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
    });

    setUp(() => _clearScenarioRows(database));

    tearDownAll(AppRepositories.close);

    test('production composition supplies the real catalog adapter', () {
      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
    });

    test('hasData truth table uses fresh SQLite products and sales only',
        () async {
      final noSales = _FixedSales(const []);
      final oneSale = _FixedSales([_sale('truth-table-sale')]);

      expect((await _service(saleRepository: noSales).load()).hasData, isFalse);

      await _seedProduct(
        database,
        id: 'inactive-product',
        name: 'Barley',
        isActive: false,
        createdAt: DateTime.utc(2026, 7, 30, 8),
      );
      expect((await _service(saleRepository: noSales).load()).hasData, isTrue);

      await database.delete(database.products).go();
      expect((await _service(saleRepository: oneSale).load()).hasData, isTrue);

      await _seedProduct(
        database,
        id: 'active-product',
        name: 'Barley',
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 9),
      );
      expect((await _service(saleRepository: oneSale).load()).hasData, isTrue);
      expect(noSales.readCount, 2);
      expect(oneSale.readCount, 2);
    });

    test('inactive first match, id tie-break, fresh update, and no writes',
        () async {
      final createdAt = DateTime.utc(2026, 7, 30, 10);
      await _seedProduct(
        database,
        id: 'a-inactive-wheat',
        name: 'wheat first',
        isActive: false,
        createdAt: createdAt,
      );
      await _seedProduct(
        database,
        id: 'b-active-wheat',
        name: 'wheat second',
        isActive: true,
        createdAt: createdAt,
      );
      await _seedMovement(database, 'a-inactive-wheat', 7, 1);
      await _seedMovement(database, 'b-active-wheat', 11, 2);

      final beforeFirstLoad = await _databaseSnapshot(database);
      final first =
          await _service(saleRepository: _FixedSales(const [])).load();
      expect(first.wheatStockKg, 7);
      expect(first.totalStockKg, 18);
      expect(first.hasData, isTrue);
      expect(await _databaseSnapshot(database), beforeFirstLoad);

      await (database.update(database.products)
            ..where((row) => row.id.equals('a-inactive-wheat')))
          .write(
        db.ProductsCompanion(
          name: const Value('Barley'),
          normalizedName: const Value('barley-a-inactive-wheat'),
          updatedAt: Value(DateTime.utc(2026, 7, 30, 11)),
        ),
      );
      final beforeSecondLoad = await _databaseSnapshot(database);
      final second =
          await _service(saleRepository: _FixedSales(const [])).load();
      expect(second.wheatStockKg, 11);
      expect(second.totalStockKg, 18);
      expect(await _databaseSnapshot(database), beforeSecondLoad);
    });

    test('missing balance and missing wheat match preserve zero', () async {
      await _seedProduct(
        database,
        id: 'wheat-without-balance',
        name: 'wheat without balance',
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 12),
      );
      final missingBalance =
          await _service(saleRepository: _FixedSales(const [])).load();
      expect(missingBalance.wheatStockKg, 0);
      expect(missingBalance.hasData, isTrue);

      await (database.update(database.products)
            ..where((row) => row.id.equals('wheat-without-balance')))
          .write(
        db.ProductsCompanion(
          name: const Value('Rye'),
          normalizedName: const Value('rye-wheat-without-balance'),
          updatedAt: Value(DateTime.utc(2026, 7, 30, 13)),
        ),
      );
      final noMatch =
          await _service(saleRepository: _FixedSales(const [])).load();
      expect(noMatch.wheatStockKg, 0);
      expect(noMatch.hasData, isTrue);
    });

    test('catalog and inventory errors propagate once without fallback',
        () async {
      final catalogError = StateError('phase 106H catalog failure');
      final catalog = _ThrowingCatalog(catalogError);
      await expectLater(
        _service(
          catalogRepository: catalog,
          saleRepository: _FixedSales(const []),
        ).load(),
        throwsA(same(catalogError)),
      );
      expect(catalog.readCount, 1);
      expect(catalog.includeInactiveValues, [true]);

      final inventoryError = StateError('phase 106H inventory failure');
      final inventory = _ThrowingInventory(inventoryError);
      final fixedCatalog = _FixedCatalog([
        _product('inactive-wheat', 'wheat controlled', isActive: false),
      ]);
      await expectLater(
        _service(
          catalogRepository: fixedCatalog,
          inventoryRepository: inventory,
          saleRepository: _FixedSales(const []),
        ).load(),
        throwsA(same(inventoryError)),
      );
      expect(fixedCatalog.readCount, 1);
      expect(fixedCatalog.includeInactiveValues, [true]);
      expect(inventory.readCount, 1);
    });
  });
}

DashboardService _service({
  ProductCatalogReadRepository? catalogRepository,
  InventoryRepository? inventoryRepository,
  SaleRepository? saleRepository,
}) =>
    DashboardService(
      saleRepository: saleRepository ?? AppRepositories.saleRepository,
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
    await database.delete(database.sales).go();
    await database.delete(database.inventoryMovements).go();
    await database.delete(database.products).go();
  });
}

Future<void> _seedProduct(
  db.FoundationDatabase database, {
  required String id,
  required String name,
  required bool isActive,
  required DateTime createdAt,
}) async {
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '$name-$id'.toLowerCase(),
          unit: GrainUnit.kilogram.name,
          isActive: isActive,
          createdAt: createdAt,
          updatedAt: createdAt,
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
          createdByUserId: 'phase-106h',
          createdAt: DateTime.utc(2026, 7, 30, 14, order),
        ),
      );
}

Future<List<Object>> _databaseSnapshot(db.FoundationDatabase database) async {
  final products = await (database.select(database.products)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final movements = await (database.select(database.inventoryMovements)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final sales = await (database.select(database.sales)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  return [
    products
        .map((row) => (
              row.id,
              row.name,
              row.code,
              row.unit,
              row.isActive,
              row.createdAt,
              row.updatedAt,
            ))
        .toList(growable: false),
    movements
        .map((row) => (
              row.id,
              row.productId,
              row.movementType,
              row.quantityKg,
              row.isVoided,
            ))
        .toList(growable: false),
    sales
        .map((row) => (
              row.id,
              row.productId,
              row.quantityKg,
              row.totalQirsh,
              row.cancelledAt,
            ))
        .toList(growable: false),
  ];
}

SaleRecord _sale(String id) => SaleRecord(
      id: id,
      productId: 'sale-product',
      quantityKg: 1,
      salePriceQirshPerKg: 10,
      totalQirsh: 10,
      createdByUserId: 'phase-106h',
      createdAt: DateTime.utc(2026, 7, 30, 15),
      stockMovementId: 'sale-movement',
    );

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
    );

final class _FixedSales implements SaleRepository {
  _FixedSales(this.items);

  final List<SaleRecord> items;
  int readCount = 0;

  @override
  Future<List<SaleRecord>> listSales() async {
    readCount++;
    return List<SaleRecord>.unmodifiable(items);
  }

  @override
  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) =>
      throw UnimplementedError();

  @override
  Future<SaleRecord> createSale(SaleDraft draft) => throw UnimplementedError();
}

final class _FixedCatalog implements ProductCatalogReadRepository {
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
  final List<bool> includeInactiveValues = [];
  int readCount = 0;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    readCount++;
    includeInactiveValues.add(includeInactive);
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

Set<String> _changedFiles(String from, String? to, String path) {
  final arguments = ['diff', '--name-only', from];
  if (to != null) arguments.add(to);
  arguments.addAll(['--', path]);
  return _git(arguments)
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .map((line) => line.replaceAll('\\', '/'))
      .toSet();
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

int _testDeclarationCount(String source) =>
    RegExp(r'\btest(?:Widgets)?\s*\(').allMatches(source).length;

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;

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
  if (start < 0) throw StateError('Missing declaration.');
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace.');
}
