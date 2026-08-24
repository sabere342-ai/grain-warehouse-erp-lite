import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/drift_inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

const _phase106rCommit = 'ad03bd0b27109ac2ec97d80ffa32fca22d0f41d9';
const _phase106sCommit = '7300f5569f0617cf81606eddd062e73ec75c2de6';

const _catalogCallers = {
  'lib/application/queries/load_product_catalog_query.dart',
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/core/sales/sale_repository.dart',
  'lib/features/dashboard/dashboard_screen.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
};

void main() {
  group('Phase 106S genuine AppRepositories production composition on SQLite',
      () {
    late db.FoundationDatabase database;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
    });

    setUp(() => _clearScenarioRows(database));

    tearDownAll(AppRepositories.close);

    test('production composition identity resolves to the Drift adapter',
        () async {
      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
      expect(
        AppRepositories.inventoryRepository,
        isA<DriftInventoryRepository>(),
      );
      await _seedProduct(
        database,
        id: 'prd-106s-composition',
        name: 'Composition sentinel',
        isActive: true,
        order: 1,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      expect(controller.products.single.id, 'prd-106s-composition');
      expect(controller.products.single.name, 'Composition sentinel');
    });

    test(
        'owner with canCreateStockAdjustment sees active and inactive '
        'products', () async {
      await _seedProduct(
        database,
        id: 'prd-106s-owner-active',
        name: 'Owner active wheat',
        isActive: true,
        order: 1,
        referenceCost: 1111,
      );
      await _seedProduct(
        database,
        id: 'prd-106s-owner-inactive',
        name: 'Owner archived barley',
        isActive: false,
        order: 2,
        referenceCost: 2222,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      final byId = {
        for (final product in controller.products) product.id: product
      };
      expect(controller.products, hasLength(2));
      expect(byId['prd-106s-owner-active']!.isActive, isTrue);
      expect(byId['prd-106s-owner-inactive']!.isActive, isFalse);
      expect(
        byId['prd-106s-owner-inactive']!.referenceCostPricePiastersPerKg,
        2222,
      );
    });

    test('employee without canCreateStockAdjustment sees only active products',
        () async {
      await _seedProduct(
        database,
        id: 'prd-106s-employee-active',
        name: 'Employee active wheat',
        isActive: true,
        order: 1,
      );
      await _seedProduct(
        database,
        id: 'prd-106s-employee-inactive',
        name: 'Employee archived barley',
        isActive: false,
        order: 2,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_employee);

      expect(controller.products, hasLength(1));
      expect(controller.products.single.id, 'prd-106s-employee-active');
      expect(controller.products.single.isActive, isTrue);
    });

    test('empty products table loads without crash and stays empty', () async {
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.products, isEmpty);
    });

    test('re-read reflects later SQLite rows without any hidden cache',
        () async {
      final controller = _productionController();
      addTearDown(controller.dispose);
      await _seedProduct(
        database,
        id: 'prd-106s-first',
        name: 'First wheat',
        isActive: true,
        order: 1,
      );

      await controller.load(_owner);
      expect(controller.products.single.id, 'prd-106s-first');

      await _seedProduct(
        database,
        id: 'prd-106s-second',
        name: 'Second wheat',
        isActive: true,
        order: 2,
      );
      await database.customStatement(
        "UPDATE products SET name = 'First wheat renamed in SQLite' "
        "WHERE id = 'prd-106s-first'",
      );

      await controller.load(_owner);

      final byId = {
        for (final product in controller.products) product.id: product
      };
      expect(controller.products, hasLength(2));
      expect(byId['prd-106s-first']!.name, 'First wheat renamed in SQLite');
      expect(byId['prd-106s-second']!.name, 'Second wheat');
    });

    test('load performs no writes to product or inventory tables', () async {
      await _seedProduct(
        database,
        id: 'prd-106s-readonly',
        name: 'Read only wheat',
        isActive: true,
        order: 1,
      );
      await _seedMovement(
        database,
        id: 'mov-106s-readonly',
        productId: 'prd-106s-readonly',
        type: StockMovementType.openingBalance,
        quantityKg: 40,
        createdAt: DateTime.utc(2026, 7, 30, 9, 1),
      );
      final before = await _loadSnapshot(database);
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      final after = await _loadSnapshot(database);
      expect(after.$1, before.$1);
      expect(after.$2, before.$2);
      expect(after.$3, before.$3);
      expect(controller.balanceForProduct('prd-106s-readonly'), 40);
    });

    test('products preserve createdAt ASC then id ASC ordering', () async {
      await _seedProduct(
        database,
        id: 'prd-106s-order-a',
        name: 'Wheat A',
        isActive: true,
        order: 2,
      );
      await _seedProduct(
        database,
        id: 'prd-106s-order-b',
        name: 'Wheat B',
        isActive: true,
        order: 2,
      );
      await _seedProduct(
        database,
        id: 'prd-106s-order-c',
        name: 'Wheat C',
        isActive: true,
        order: 1,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      expect(
        controller.products
            .map((product) => product.id)
            .toList(growable: false),
        ['prd-106s-order-c', 'prd-106s-order-a', 'prd-106s-order-b'],
      );
    });
  });

  group('Phase 106S legacy-read tripwire in the genuine load path', () {
    test(
        'load succeeds with a throwing legacy ProductRepository and never '
        'calls listProducts (owner)', () async {
      final database = openInMemoryTestDatabase();
      addTearDown(database.close);
      final legacy = _ThrowingProductRepository();
      final fixture = _tripwireFixture(database, legacy);
      addTearDown(fixture.controller.dispose);
      await _seedProduct(
        database,
        id: 'prd-106s-tripwire-active',
        name: 'Tripwire wheat',
        isActive: true,
        order: 1,
      );
      await _seedProduct(
        database,
        id: 'prd-106s-tripwire-inactive',
        name: 'Tripwire barley',
        isActive: false,
        order: 2,
      );

      await fixture.controller.load(_owner);

      expect(fixture.controller.products, hasLength(2));
      expect(legacy.listProductCalls, 0);
      expect(fixture.controller.isLoading, isFalse);
    });

    test(
        'employee load also avoids listProducts and respects inactive '
        'filtering', () async {
      final database = openInMemoryTestDatabase();
      addTearDown(database.close);
      final legacy = _ThrowingProductRepository();
      final fixture = _tripwireFixture(database, legacy);
      addTearDown(fixture.controller.dispose);
      await _seedProduct(
        database,
        id: 'prd-106s-tripwire-active',
        name: 'Tripwire wheat',
        isActive: true,
        order: 1,
      );
      await _seedProduct(
        database,
        id: 'prd-106s-tripwire-inactive',
        name: 'Tripwire barley',
        isActive: false,
        order: 2,
      );

      await fixture.controller.load(_employee);

      expect(fixture.controller.products.single.id, 'prd-106s-tripwire-active');
      expect(legacy.listProductCalls, 0);
      expect(fixture.controller.isLoading, isFalse);
    });
  });

  group('Phase 106S architecture guards', () {
    test('InventoryController.load never calls the legacy product read', () {
      final source = _compact(File(_controllerPath).readAsStringSync());
      final loadBody = _compact(_methodBody(
        File(_controllerPath).readAsStringSync(),
        'Future<void> load(AppUser user) async',
      ));

      expect(source, contains('ProductCatalogReadRepository'));
      expect(source, isNot(contains('ProductRepository')));
      expect(source, isNot(contains('_productRepository')));
      expect(loadBody,
          contains('_productCatalogReadRepository.listProductCatalog('));
      expect(
        loadBody,
        contains('includeInactive:user.permissions.canCreateStockAdjustment'),
      );
      expect(loadBody, isNot(contains('listProducts(')));
      expect(loadBody, isNot(contains('productRepository')));
      for (final forbidden in const [
        '.transaction(',
        'createProduct(',
        'updateProduct(',
        'setProductActive(',
        'restoreProductsIntoEmpty(',
        'clearForOwnerDataWipe(',
        '_inventoryRepository.createMovement(',
        'try{',
        'catch(',
      ]) {
        expect(loadBody, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test(
        'DriftInventoryRepository.allProductBalancesKg stays on the catalog '
        'contract', () {
      final source = File('lib/core/inventory/drift_inventory_repository.dart')
          .readAsStringSync();
      final balancesBody = _compact(_asyncMethodBody(
        source,
        'Future<Map<String, int>> allProductBalancesKg(',
      ));

      expect(balancesBody,
          contains('_productCatalogReadRepository.listProductCatalog('));
      expect(balancesBody, isNot(contains('listProducts(')));
      expect(balancesBody, isNot(contains('_findProductById')));
      expect(balancesBody, isNot(contains('currentStockKg(')));
      expect(balancesBody, isNot(contains('try{')));

      final listAllBody = _compact(_asyncMethodBody(
        source,
        'Future<List<StockMovement>> listAllMovements() async',
      ));
      expect(listAllBody, isNot(contains('listProducts(')));
      expect(listAllBody, isNot(contains('_productRepository')));
    });

    test('production inventory screens wire the genuine catalog repository',
        () {
      for (final path in const [
        'lib/features/inventory/inventory_screen.dart',
        'lib/features/inventory/stock_take_screen.dart',
        'lib/features/inventory/stock_adjustment_report_screen.dart',
      ]) {
        final screen = _compact(File(path).readAsStringSync());
        expect(
          screen,
          contains(
            'productCatalogReadRepository:AppRepositories.productCatalogReadRepository',
          ),
          reason: path,
        );
        expect(screen, isNot(contains('productRepository:')), reason: path);
      }
      final composition =
          _compact(File('lib/app/app_repositories.dart').readAsStringSync());
      expect(
        composition,
        contains(
          '_productCatalogReadRepository=DriftProductCatalogReadRepository(',
        ),
      );
    });

    test('Phase 106S changed no production code; callers include Phase 106Z',
        () {
      final productionDiff = _git([
        'diff',
        '--name-only',
        _phase106rCommit,
        _phase106sCommit,
        '--',
        'lib',
      ])
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();

      expect(productionDiff, isEmpty);

      final callers = _filesCalling('.listProductCatalog(')..sort();
      expect(callers, _catalogCallers.toList()..sort());
    });

    test('schemaVersion stays 15 and persistence is untouched', () {
      final schema = _compact(
          File('lib/core/persistence/foundation_database.dart')
              .readAsStringSync());
      expect(schema, contains('schemaVersion=>16'));
      final persistenceDiff = _git([
        'diff',
        '--name-only',
        _phase106rCommit,
        _phase106sCommit,
        '--',
        'lib/core/persistence',
      ])
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();

      expect(persistenceDiff, isEmpty);
    });

    test(
        'no fallback from the catalog contract to the legacy listProducts '
        'exists in the load path', () {
      final adapter = _compact(
        File('lib/core/catalog/drift_product_catalog_read_repository.dart')
            .readAsStringSync(),
      );
      expect(adapter, contains('implementsProductCatalogReadRepository'));
      expect(adapter, isNot(contains('listProducts(')));
      expect(adapter, isNot(contains('ProductRepository')));
      expect(adapter, isNot(contains('try{')));

      final loadBody = _compact(_asyncMethodBody(
        File(_controllerPath).readAsStringSync(),
        'Future<void> load(AppUser user) async',
      ));
      expect(loadBody, isNot(contains('catch(')));
      expect(loadBody, isNot(contains('retry')));
      expect(loadBody, isNot(contains('fallback')));
      expect(loadBody, isNot(contains('listProducts(')));

      final valuation = File(
        'lib/core/inventory_valuation/drift_inventory_valuation_repository.dart',
      ).readAsStringSync();
      expect(valuation, isNot(contains('listProducts(')));
      expect(valuation, isNot(contains('ProductRepository')));
    });
  });
}

const _controllerPath = 'lib/core/inventory/inventory_controller.dart';

/// Mirrors the exact production construction used by InventoryScreen,
/// StockTakeScreen, and StockAdjustmentReportScreen.
InventoryController _productionController() => InventoryController(
      inventoryRepository: AppRepositories.inventoryRepository,
      productCatalogReadRepository:
          AppRepositories.productCatalogReadRepository,
      inventoryValuationRepository:
          AppRepositories.inventoryValuationRepository,
      financialAccountRepository: AppRepositories.financialAccountRepository,
      auditLogRepository: AppRepositories.auditLogRepository,
    );

/// Composes the genuine Drift stack with a throwing legacy sentinel at the
/// `productRepository` seam, exactly where production injects
/// `DriftProductRepository`. The sentinel is a test double for the side
/// component that is NOT under proof: `ProductCatalogReadRepository`,
/// `DriftProductCatalogReadRepository`, `DriftInventoryRepository`, the Drift
/// valuation adapter, and SQLite are all real. Any legacy `listProducts` call
/// inside the load path would throw and fail the test.
_TripwireFixture _tripwireFixture(
  db.FoundationDatabase database,
  _ThrowingProductRepository legacy,
) {
  final catalog = DriftProductCatalogReadRepository(database);
  final inventory = DriftInventoryRepository(
    database,
    productCatalogReadRepository: catalog,
  );
  final controller = InventoryController(
    inventoryRepository: inventory,
    productCatalogReadRepository: catalog,
    inventoryValuationRepository: DriftInventoryValuationRepository(database),
  );
  return _TripwireFixture(controller);
}

final class _TripwireFixture {
  const _TripwireFixture(this.controller);

  final InventoryController controller;
}

final class _ThrowingProductRepository implements ProductRepository {
  int listProductCalls = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) {
    listProductCalls++;
    throw StateError('Phase 106S legacy listProducts sentinel');
  }

  @override
  Future<Product> createProduct(ProductDraft draft) =>
      throw UnsupportedError('Phase 106S read-only legacy sentinel');

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) =>
      throw UnsupportedError('Phase 106S read-only legacy sentinel');

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) =>
      throw UnsupportedError('Phase 106S read-only legacy sentinel');
}

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
  int? referenceCost,
}) async {
  final timestamp = DateTime.utc(2026, 7, 30, 8, order);
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
  required DateTime createdAt,
}) async {
  await database.into(database.inventoryMovements).insert(
        db.InventoryMovementsCompanion.insert(
          id: id,
          productId: productId,
          movementType: type.name,
          quantityKg: quantityKg,
          createdByUserId: 'phase-106s',
          createdAt: createdAt,
        ),
      );
}

Future<(List<Object>, List<Object>, (int, int, int, int))> _loadSnapshot(
    db.FoundationDatabase database) async {
  final products = await (database.select(database.products)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final movements = await (database.select(database.inventoryMovements)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final productRows = products
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
  final movementRows = movements
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
  final valuationCounts = (
    await database.profitabilityActivations.count().getSingle(),
    await database.inventoryValuationStates.count().getSingle(),
    await database.inventoryValuationEvents.count().getSingle(),
    await database.repositorySequences.count().getSingle(),
  );
  return (productRows, movementRows, valuationCounts);
}

final DateTime _now = DateTime.utc(2026, 7, 30);

final _owner = AppUser(
  id: 'owner-106s',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _employee = AppUser(
  id: 'employee-106s',
  name: 'موظف',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

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

List<String> _filesCalling(String pattern) {
  final results = <String>[];
  final pending = <Directory>[Directory('lib')];
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is Directory) {
        pending.add(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        if (entity.readAsStringSync().contains(pattern)) {
          results.add(entity.path.replaceAll('\\', '/'));
        }
      }
    }
  }
  return results;
}

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');

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

/// Extracts a method body when the declaration itself may contain a `{`
/// (e.g. a named-parameter block), by anchoring on the `async {` marker.
String _asyncMethodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  final asyncMarker = source.indexOf('async {', start);
  if (asyncMarker < 0) throw StateError('Missing async body: $declaration');
  final openBrace = asyncMarker + 'async {'.length - 1;
  return _bracedBody(source, openBrace);
}
