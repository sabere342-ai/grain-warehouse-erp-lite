import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

void main() {
  test('implements the frozen repository contract through its interface',
      () async {
    final fixture = _fixture();
    final ProductCatalogReadRepository repository = fixture.repository;

    final Future<List<ProductCatalogReadModel>> future =
        repository.listProductCatalog(includeInactive: false);

    expect(await future, isEmpty);
  });

  test('active-only query excludes every inactive product', () async {
    final fixture = _fixture();
    await _seed(fixture.database, [
      _product(id: 'prd-3-3', name: 'Active', isActive: true),
      _product(id: 'prd-2-2', name: 'Inactive', isActive: false),
    ]);

    final result =
        await fixture.repository.listProductCatalog(includeInactive: false);

    expect(result.map((product) => product.id), ['prd-3-3']);
    expect(result.every((product) => product.isActive), isTrue);
  });

  test('include-inactive query returns both stored activity states', () async {
    final fixture = _fixture();
    await _seed(fixture.database, [
      _product(id: 'prd-1-1', name: 'Active', isActive: true),
      _product(id: 'prd-2-2', name: 'Inactive', isActive: false),
    ]);

    final result =
        await fixture.repository.listProductCatalog(includeInactive: true);

    expect(result, hasLength(2));
    expect(result.map((product) => product.isActive), [true, false]);
  });

  test('maps all frozen fields losslessly including null code and units',
      () async {
    final fixture = _fixture();
    await _seed(fixture.database, [
      _product(
        id: 'prd-1722261600000000-41',
        name: 'Wheat',
        code: 'WH-41',
        unit: GrainUnit.ton,
        isActive: true,
      ),
      _product(
        id: 'prd-1722261600000000-42',
        name: 'Corn',
        unit: GrainUnit.kilogram,
        isActive: false,
      ),
    ]);

    final result =
        await fixture.repository.listProductCatalog(includeInactive: true);

    expect(result[0].id, 'prd-1722261600000000-41');
    expect(result[0].name, 'Wheat');
    expect(result[0].code, 'WH-41');
    expect(result[0].unit, GrainUnit.ton);
    expect(result[0].isActive, isTrue);
    expect(result[1].id, 'prd-1722261600000000-42');
    expect(result[1].name, 'Corn');
    expect(result[1].code, isNull);
    expect(result[1].unit, GrainUnit.kilogram);
    expect(result[1].isActive, isFalse);
  });

  test('orders by createdAt ascending then id ascending for ties', () async {
    final fixture = _fixture();
    final older = DateTime.utc(2026, 7, 27);
    final tied = DateTime.utc(2026, 7, 28);
    final newer = DateTime.utc(2026, 7, 29);
    await _seed(fixture.database, [
      _product(id: 'prd-newer', name: 'Newer', createdAt: newer),
      _product(id: 'prd-tied-z', name: 'Tie Z', createdAt: tied),
      _product(id: 'prd-older', name: 'Older', createdAt: older),
      _product(id: 'prd-tied-a', name: 'Tie A', createdAt: tied),
    ]);

    final result =
        await fixture.repository.listProductCatalog(includeInactive: true);

    expect(result.map((product) => product.id), [
      'prd-older',
      'prd-tied-a',
      'prd-tied-z',
      'prd-newer',
    ]);
  });

  test('empty database returns an empty typed snapshot', () async {
    final fixture = _fixture();

    final result =
        await fixture.repository.listProductCatalog(includeInactive: true);

    expect(result, isA<List<ProductCatalogReadModel>>());
    expect(result, isEmpty);
  });

  test('read leaves products, timestamps, activity, and other tables unchanged',
      () async {
    final fixture = _fixture();
    await _seed(fixture.database, [
      _product(
        id: 'prd-read-only',
        name: 'Read only',
        code: 'RO',
        isActive: false,
        createdAt: DateTime.utc(2026, 7, 20),
      ),
    ]);
    await fixture.database.writeProbe('phase105c', 'unchanged');
    final productsBefore =
        await fixture.database.select(fixture.database.products).get();
    final sequenceBefore = await fixture.database
        .select(fixture.database.repositorySequences)
        .get();

    await fixture.repository.listProductCatalog(includeInactive: true);

    final productsAfter =
        await fixture.database.select(fixture.database.products).get();
    final sequenceAfter = await fixture.database
        .select(fixture.database.repositorySequences)
        .get();
    expect(productsAfter, productsBefore);
    expect(sequenceAfter, sequenceBefore);
    expect(await fixture.database.readProbe('phase105c'), 'unchanged');
  });

  test('adapter is wired only in composition and stays isolated from UI/cloud',
      () {
    const adapterPath =
        'lib/core/catalog/drift_product_catalog_read_repository.dart';
    final adapter = _read(adapterPath);
    final productionReferences = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => _relative(file.path) != adapterPath)
        .where((file) => file
            .readAsStringSync()
            .contains('DriftProductCatalogReadRepository'))
        .map((file) => _relative(file.path))
        .toList();

    expect(productionReferences, ['lib/app/app_repositories.dart']);
    expect(adapter, contains('_database.selectOnly(products)'));
    expect(adapter, isNot(contains('.transaction(')));
    expect(adapter, isNot(contains('.into(')));
    expect(adapter, isNot(contains('.update(')));
    expect(adapter, isNot(contains('.delete(')));
    expect(adapter, isNot(contains('firebase')));
    expect(adapter, isNot(contains('cloud')));
    expect(adapter, isNot(matches(RegExp(r'\bsync\b'))));
  });

  test('unknown stored unit fails explicitly instead of inventing a fallback',
      () async {
    final fixture = _fixture();
    final timestamp = DateTime.utc(2026, 7, 29);
    await fixture.database.into(fixture.database.products).insert(
          db.ProductsCompanion.insert(
            id: 'prd-invalid-unit',
            name: 'Invalid unit',
            normalizedName: 'invalid unit',
            unit: 'bag',
            isActive: true,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );

    await expectLater(
      fixture.repository.listProductCatalog(includeInactive: true),
      throwsArgumentError,
    );
  });
}

({
  db.FoundationDatabase database,
  DriftProductCatalogReadRepository repository,
}) _fixture() {
  final database = openInMemoryTestDatabase();
  addTearDown(database.close);
  return (
    database: database,
    repository: DriftProductCatalogReadRepository(database),
  );
}

Future<void> _seed(db.FoundationDatabase database, List<Product> products) =>
    DriftProductRepository(database).restoreProductsIntoEmpty(products);

Product _product({
  required String id,
  required String name,
  String? code,
  GrainUnit unit = GrainUnit.kilogram,
  bool isActive = true,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 7, 28);
  return Product(
    id: id,
    name: name,
    code: code,
    unit: unit,
    isActive: isActive,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

String _read(String path) => File(path).readAsStringSync();

String _relative(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  final normalizedRoot = Directory.current.path.replaceAll('\\', '/');
  return normalizedPath.replaceFirst('$normalizedRoot/', '');
}
