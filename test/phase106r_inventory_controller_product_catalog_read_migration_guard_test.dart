import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';

const _controllerPath = 'lib/core/inventory/inventory_controller.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _inventoryScreenPath = 'lib/features/inventory/inventory_screen.dart';
const _stockTakeScreenPath = 'lib/features/inventory/stock_take_screen.dart';
const _stockAdjustmentReportScreenPath =
    'lib/features/inventory/stock_adjustment_report_screen.dart';
const _persistencePath = 'lib/core/persistence';
const _phase106qBaseline = 'f0341e9e070012953bce487c20401bf36eec1b87';
const _phase106rCommit = 'ad03bd0b27109ac2ec97d80ffa32fca22d0f41d9';

const _expectedProductionFiles = {
  'lib/core/inventory/inventory_controller.dart',
  'lib/features/inventory/inventory_screen.dart',
  'lib/features/inventory/stock_take_screen.dart',
  'lib/features/inventory/stock_adjustment_report_screen.dart',
};

const _frozenReadModelFields = {
  'id',
  'name',
  'code',
  'unit',
  'isActive',
  'referenceCostPricePiastersPerKg',
};

const _catalogCallers = {
  'lib/core/catalog/product_controller.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/features/dashboard/dashboard_screen.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
};

void main() {
  group('InventoryController.load product catalog read migration', () {
    test('load reads products through ProductCatalogReadRepository only',
        () async {
      final catalog = _Catalog([
        _model('prd-wheat', 'قمح', isActive: true),
        _model('prd-inactive', 'شعير', isActive: false),
      ]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      expect(catalog.readCalls, 1);
      expect(catalog.includeInactiveValues, [true]);
      expect(fixture.controller.isLoading, isFalse);
      expect(fixture.controller.products, hasLength(2));
      expect(fixture.inventory.listAllMovementsCalls, 1);
      expect(fixture.inventory.balancesCalls, 1);
    });

    test('includeInactive follows the canCreateStockAdjustment permission',
        () async {
      final ownerCatalog = _Catalog([
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'شعير', isActive: false),
      ]);
      final employeeCatalog = _Catalog([
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'شعير', isActive: false),
      ]);
      final ownerFixture = _fixture(catalog: ownerCatalog);
      final employeeFixture = _fixture(catalog: employeeCatalog);

      await ownerFixture.controller.load(_owner);
      await employeeFixture.controller.load(_employee);

      expect(ownerCatalog.includeInactiveValues, [true]);
      expect(employeeCatalog.includeInactiveValues, [false]);
      expect(ownerFixture.controller.products, hasLength(2));
      expect(employeeFixture.controller.products, hasLength(1));
      expect(employeeFixture.controller.products.single.id, 'prd-1');
    });

    test('load exposes id and name from the read model', () async {
      final catalog = _Catalog([
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'شعير', isActive: false),
      ]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      final products = fixture.controller.products;
      expect(products, hasLength(2));
      expect(products[0].id, 'prd-1');
      expect(products[0].name, 'قمح');
      expect(products[1].id, 'prd-2');
      expect(products[1].name, 'شعير');
      expect(fixture.controller.balanceForProduct('prd-1'), 10);
      expect(fixture.controller.hasOpeningBalance('prd-1'), isFalse);
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
      expect(fixture.inventory.writeCalls, 0);
    });

    test('load is read-only and never writes', () async {
      final catalog = _Catalog([_model('prd-1', 'قمح', isActive: true)]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

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

  group('Phase 106R architecture freeze', () {
    test(
        'InventoryController.load no longer depends on the legacy read contract',
        () {
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
      for (final forbidden in const [
        '.transaction(',
        'createProduct(',
        'updateProduct(',
        'setProductActive(',
        'restoreProductsIntoEmpty(',
        'clearForOwnerDataWipe(',
        '_inventoryRepository.createMovement(',
      ]) {
        expect(loadBody, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('migrated controller carries no TODO, placeholder, or shim', () {
      final source = File(_controllerPath).readAsStringSync();

      for (final marker in const ['TODO', 'FIXME', 'placeholder', 'shim']) {
        expect(source.toLowerCase(), isNot(contains(marker.toLowerCase())),
            reason: marker);
      }
    });

    test(
        'ProductCatalogReadModel contract at the 106Q baseline is not '
        'expanded', () {
      final source =
          _git(['show', '$_phase106qBaseline:$_contractPath']).join('\n');
      final modelBody = _bracedBody(
        source,
        source.indexOf('final class ProductCatalogReadModel'),
      );
      final fields = RegExp(r'final\s+(String\??|GrainUnit|bool|int\??)\s+'
              r'(\w+)\s*;')
          .allMatches(modelBody)
          .map((match) => match.group(2)!)
          .toSet();

      expect(fields, _frozenReadModelFields);
    });

    test('ProductCatalogReadRepository contract is not expanded', () {
      final source = _compact(File(_contractPath).readAsStringSync());

      expect(source,
          contains('abstractinterfaceclassProductCatalogReadRepository'));
      expect(source, contains('listProductCatalog('));
      for (final forbidden in const [
        'createProduct(',
        'updateProduct(',
        'setProductActive(',
        'restoreProductsIntoEmpty(',
        'clearForOwnerDataWipe(',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('catalog callers include accepted consumers through Phase 106Z', () {
      final callers = _filesCalling('.listProductCatalog(')..sort();

      expect(callers, _catalogCallers.toList()..sort());
      for (final path in const [
        _inventoryScreenPath,
        _stockTakeScreenPath,
        _stockAdjustmentReportScreenPath,
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
    });

    test('production scope is limited to the migration files', () {
      final diff = _git([
        'diff',
        '--name-only',
        _phase106qBaseline,
        _phase106rCommit,
        '--',
        'lib',
      ]).map((path) => path.trim()).where((path) => path.isNotEmpty).toSet();

      expect(diff, _expectedProductionFiles);
    });

    test('no schema or persistence migration changes', () {
      final persistenceDiff = _git([
        'diff',
        '--name-only',
        _phase106qBaseline,
        _phase106rCommit,
        '--',
        _persistencePath
      ]).map((path) => path.trim()).where((path) => path.isNotEmpty).toList();
      final schema = _compact(File('$_persistencePath/foundation_database.dart')
          .readAsStringSync());

      expect(persistenceDiff, isEmpty);
      expect(schema, contains('schemaVersion=>15'));
    });
  });
}

ProductCatalogReadModel _model(String id, String name,
    {required bool isActive}) {
  return ProductCatalogReadModel(
    id: id,
    name: name,
    code: null,
    unit: GrainUnit.kilogram,
    isActive: isActive,
    referenceCostPricePiastersPerKg: null,
    defaultSalePricePiastersPerKg: null,
    minimumSalePricePiastersPerKg: null,
    notes: null,
  );
}

_Fixture _fixture({required _Catalog catalog}) {
  final inventory = _Inventory();
  final controller = InventoryController(
    inventoryRepository: inventory,
    productCatalogReadRepository: catalog,
  );
  return _Fixture(
    controller: controller,
    catalog: catalog,
    inventory: inventory,
  );
}

final class _Fixture {
  const _Fixture({
    required this.controller,
    required this.catalog,
    required this.inventory,
  });

  final InventoryController controller;
  final _Catalog catalog;
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

final class _Inventory implements InventoryRepository {
  int listAllMovementsCalls = 0;
  int balancesCalls = 0;
  int writeCalls = 0;

  @override
  Future<List<StockMovement>> listAllMovements() async {
    listAllMovementsCalls++;
    return const [];
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    balancesCalls++;
    return const {'prd-1': 10};
  }

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) {
    writeCalls++;
    throw UnsupportedError('Phase 106R fake is read-only.');
  }

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) {
    writeCalls++;
    throw UnsupportedError('Phase 106R fake is read-only.');
  }

  @override
  Future<int> currentStockKg(String productId) {
    writeCalls++;
    throw UnsupportedError('Phase 106R fake is read-only.');
  }

  @override
  Future<bool> hasOpeningBalance(String productId) {
    writeCalls++;
    throw UnsupportedError('Phase 106R fake is read-only.');
  }
}

final DateTime _now = DateTime.utc(2026, 7, 30);

final _owner = AppUser(
  id: 'owner-106r',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _employee = AppUser(
  id: 'employee-106r',
  name: 'موظف',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

List<String> _git(List<String> arguments) {
  final process = Process.runSync('git', arguments);
  if (process.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${process.stderr}');
  }
  return (process.stdout as String).split('\n');
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
