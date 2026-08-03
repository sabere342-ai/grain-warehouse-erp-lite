import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/purchases/drift_purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/drift_supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';

const _baseline = '7acac87799fc8345671f356cce273d345c38b565';
const _subject = 'PHASE 106AJ: migrate drift purchase product validation reads';
const _branch =
    'codex/phase-106aj-migrate-drift-purchase-product-validation-reads';
const _targetPath = 'lib/core/purchases/drift_purchase_repository.dart';
const _compositionPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _reportPath =
    'docs/PHASE-106AJ-MIGRATE-DRIFT-PURCHASE-PRODUCT-VALIDATION-READS.md';

void main() {
  test('PRC-109 uses only the existing catalog read contract', () {
    final source = File(_targetPath).readAsStringSync();
    final createValidation = _methodBody(
      source,
      'Future<ProductCatalogReadModel> _validateProduct(String id) async',
    );
    final restoreValidation = _methodBody(
      source,
      'Future<void> _validateProductExists(String id) async',
    );

    expect(source, contains('ProductCatalogReadRepository'));
    expect(source, isNot(contains('product_repository.dart')));
    expect(source, isNot(contains('ProductRepository')));
    expect(source, isNot(contains('.listProducts(')));
    expect(_occurrences(source, '.listProductCatalog('), 2);
    expect(
      _occurrences(
          '$createValidation\n$restoreValidation', 'includeInactive: true'),
      2,
    );
    expect(
      _compact(createValidation),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true',
      ),
    );
    expect(
      createValidation,
      contains('products.where((value) => value.id == id).firstOrNull'),
    );
    expect(createValidation, contains("StateError('Product was not found.')"));
    expect(
      createValidation,
      contains("StateError('Inactive product cannot be used.')"),
    );
    expect(
      _compact(restoreValidation),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true',
      ),
    );
    expect(
      restoreValidation,
      contains('values.any((value) => value.id == id)'),
    );
    expect(restoreValidation, isNot(contains('isActive')));

    final contract = File(_contractPath).readAsStringSync();
    expect(contract, contains('final String id;'));
    expect(contract, contains('final bool isActive;'));
    expect(_git(['diff', _baseline, '--', _contractPath]).trim(), isEmpty);
  });

  test('production composition injects the catalog repository', () {
    final source = File(_compositionPath).readAsStringSync();
    final construction = _construction(source, 'DriftPurchaseRepository(');
    expect(
      construction,
      contains(
        'productCatalogReadRepository: productCatalogReadRepository',
      ),
    );
    expect(construction, isNot(contains('productRepository:')));
  });

  test('active exact product preserves successful create behavior', () async {
    final catalog = _CatalogSpy((_, __) => [_model('target')]);
    final fixture = await _Fixture.open(catalog);
    addTearDown(fixture.close);

    final purchase = await fixture.repository.createPurchaseIntake(
      fixture.draft(productId: 'target'),
    );

    expect(purchase.productId, 'target');
    expect(catalog.includeInactiveValues, [true]);
    expect(await fixture.repository.listPurchaseIntakes(), hasLength(1));
    expect(await fixture.inventory.listAllMovements(), hasLength(1));
  });

  test('first exact catalog match still controls active validation', () async {
    final activeFirst = _CatalogSpy(
      (_, __) => [_model('target'), _model('target', isActive: false)],
    );
    final activeFixture = await _Fixture.open(activeFirst);
    addTearDown(activeFixture.close);
    await activeFixture.repository.createPurchaseIntake(
      activeFixture.draft(productId: 'target'),
    );

    final inactiveFirst = _CatalogSpy(
      (_, __) => [_model('target', isActive: false), _model('target')],
    );
    final inactiveFixture = await _Fixture.open(inactiveFirst);
    addTearDown(inactiveFixture.close);
    await expectLater(
      inactiveFixture.repository.createPurchaseIntake(
        inactiveFixture.draft(productId: 'target'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Inactive product cannot be used.',
        ),
      ),
    );
    expect(await inactiveFixture.repository.listPurchaseIntakes(), isEmpty);
    expect(await inactiveFixture.inventory.listAllMovements(), isEmpty);
  });

  test('inactive create keeps the exact error and performs no writes',
      () async {
    final catalog = _CatalogSpy(
      (_, __) => [_model('target', isActive: false)],
    );
    final fixture = await _Fixture.open(catalog);
    addTearDown(fixture.close);

    await expectLater(
      fixture.repository.createPurchaseIntake(
        fixture.draft(productId: 'target'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Inactive product cannot be used.',
        ),
      ),
    );
    expect(catalog.includeInactiveValues, [true]);
    expect(await fixture.repository.listPurchaseIntakes(), isEmpty);
    expect(await fixture.inventory.listAllMovements(), isEmpty);
  });

  test('missing create keeps the exact error and performs no writes', () async {
    final catalog = _CatalogSpy((_, __) => const []);
    final fixture = await _Fixture.open(catalog);
    addTearDown(fixture.close);

    await expectLater(
      fixture.repository.createPurchaseIntake(
        fixture.draft(productId: 'missing'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Product was not found.',
        ),
      ),
    );
    expect(catalog.includeInactiveValues, [true]);
    expect(await fixture.repository.listPurchaseIntakes(), isEmpty);
    expect(await fixture.inventory.listAllMovements(), isEmpty);
  });

  test('restore still accepts an inactive historical product', () async {
    final catalog = _CatalogSpy(
      (_, __) => [_model('historical', isActive: false)],
    );
    final fixture = await _Fixture.open(catalog);
    addTearDown(fixture.close);

    await fixture.repository.restorePurchaseIntakesIntoEmpty([
      fixture.intake(id: 'pin-history-1', productId: 'historical'),
    ]);

    expect(catalog.includeInactiveValues, [true]);
    expect(
      (await fixture.repository.listPurchaseIntakes()).single.productId,
      'historical',
    );
    expect(await fixture.inventory.listAllMovements(), isEmpty);
  });

  test('restore validates every row before inserts and rolls back on missing',
      () async {
    final catalog = _CatalogSpy(
      (call, _) => call == 1 ? [_model('valid')] : const [],
    );
    final fixture = await _Fixture.open(catalog);
    addTearDown(fixture.close);

    await expectLater(
      fixture.repository.restorePurchaseIntakesIntoEmpty([
        fixture.intake(id: 'pin-restore-1', productId: 'valid'),
        fixture.intake(id: 'pin-restore-2', productId: 'missing'),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Product was not found.',
        ),
      ),
    );

    expect(catalog.includeInactiveValues, [true, true]);
    expect(await fixture.repository.listPurchaseIntakes(), isEmpty);
  });

  test('catalog read errors propagate once and cause no side effects',
      () async {
    final failure = StateError('catalog sentinel');
    final catalog = _CatalogSpy((_, __) => throw failure);
    final fixture = await _Fixture.open(catalog);
    addTearDown(fixture.close);

    await expectLater(
      fixture.repository.createPurchaseIntake(
        fixture.draft(productId: 'target'),
      ),
      throwsA(same(failure)),
    );
    expect(catalog.calls, 1);
    expect(catalog.includeInactiveValues, [true]);
    expect(await fixture.repository.listPurchaseIntakes(), isEmpty);
    expect(await fixture.inventory.listAllMovements(), isEmpty);
  });

  test('inventory and production scope move only PRC-109', () {
    final sources = _dartSources();
    final joined = sources.values.join('\n');
    expect(_occurrences(joined, '.listProducts('), 9);
    expect(_occurrences(joined, '.listProductCatalog('), 17);

    final changedProduction = _git([
      'diff',
      '--name-only',
      _baseline,
      '--',
      'lib',
    ]).trim().split(RegExp(r'\r?\n')).where((path) => path.isNotEmpty).toSet();
    expect(changedProduction, {_targetPath, _compositionPath});
    for (final path in changedProduction) {
      expect(path, isNot(contains('.g.dart')));
      expect(path, isNot(contains('migration')));
    }
    expect(File(_reportPath).existsSync(), isTrue);
  });

  test('lineage is the baseline or its single exact Phase 106AJ child', () {
    expect(_git(['branch', '--show-current']).trim(), _branch);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head == _baseline) return;
    expect(_git(['rev-parse', 'HEAD^']).trim(), _baseline);
    expect(_git(['log', '-1', '--format=%s', 'HEAD']).trim(), _subject);
    expect(_git(['rev-list', '--count', '$_baseline..HEAD']).trim(), '1');
  });
}

final class _Fixture {
  _Fixture._(
    this.database,
    this.supplier,
    this.inventory,
    this.repository,
  );

  static Future<_Fixture> open(ProductCatalogReadRepository catalog) async {
    final database = openInMemoryTestDatabase();
    final supplierRepository = DriftSupplierRepository(database);
    final supplier = await supplierRepository.createSupplier(
      const SupplierDraft(name: 'Supplier'),
    );
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: _CatalogSpy(
        (_, __) => [_model('target')],
      ),
    );
    final repository = DriftPurchaseRepository(
      database,
      supplierRepository: supplierRepository,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
    );
    return _Fixture._(database, supplier, inventory, repository);
  }

  final db.FoundationDatabase database;
  final Supplier supplier;
  final DriftInventoryRepository inventory;
  final DriftPurchaseRepository repository;

  PurchaseIntakeDraft draft({required String productId}) => PurchaseIntakeDraft(
        supplierId: supplier.id,
        productId: productId,
        quantityKg: 2,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 100,
        createdByUserId: 'owner',
      );

  PurchaseIntake intake({required String id, required String productId}) =>
      PurchaseIntake(
        id: id,
        supplierId: supplier.id,
        productId: productId,
        quantityKg: 2,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 100,
        totalAmountPiasters: 200,
        createdByUserId: 'owner',
        createdAt: DateTime.utc(2026, 8, 3),
        stockMovementId: 'historical-movement',
      );

  Future<void> close() => database.close();
}

final class _CatalogSpy implements ProductCatalogReadRepository {
  _CatalogSpy(this._read);

  final List<ProductCatalogReadModel> Function(int call, bool includeInactive)
      _read;
  final List<bool> includeInactiveValues = [];
  int calls = 0;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    calls++;
    includeInactiveValues.add(includeInactive);
    return _read(calls, includeInactive);
  }
}

ProductCatalogReadModel _model(String id, {bool isActive = true}) {
  final timestamp = DateTime.utc(2026, 8, 3);
  return ProductCatalogReadModel(
    id: id,
    name: '',
    code: null,
    unit: GrainUnit.kilogram,
    isActive: isActive,
    referenceCostPricePiastersPerKg: null,
    defaultSalePricePiastersPerKg: null,
    minimumSalePricePiastersPerKg: null,
    notes: null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Map<String, String> _dartSources() {
  final sources = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    sources[entity.path.replaceAll('\\', '/')] = entity.readAsStringSync();
  }
  return sources;
}

String _construction(String source, String constructor) {
  final start = source.indexOf(constructor);
  if (start < 0) throw StateError('Missing constructor: $constructor');
  final end = source.indexOf(');', start);
  if (end < 0) throw StateError('Missing constructor terminator: $constructor');
  return source.substring(start, end + 2);
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
  throw StateError('Missing closing brace: $declaration');
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

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
